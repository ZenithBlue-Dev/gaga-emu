import AVFoundation
import Metal
import QuartzCore
import UIKit
import os

enum GameLaunchError: LocalizedError {
    case noCore
    case coreNotBuilt(String)
    case romMissing(String)
    case metalUnavailable

    var errorDescription: String? {
        switch self {
        case .noCore: return "No core is available for this type of file."
        case .coreNotBuilt(let name): return "\(name) is not part of this build yet."
        case .romMissing(let file): return "The game file \(file) is missing. Try adding the game again."
        case .metalUnavailable: return "This device could not start the video renderer."
        }
    }
}

extension GagaInputState {
    init(_ state: ControllerManager.InputState) {
        self.init()
        buttons = state.buttons
        left_x = state.leftX
        left_y = state.leftY
        right_x = state.rightX
        right_y = state.rightY
        trigger_l = state.triggerL
        trigger_r = state.triggerR
    }
}

/// Runs one game: core, video, audio and input, from load to teardown. A session is used once.
///
/// Threads: this class is main-actor only. `GagaCoreWrapper` steps the core on its own queue. The video
/// and audio closures below run there and capture only the ring, renderer and audio manager, which are
/// safe from that queue. Input crosses through the wrapper's lock. `core.pause` and `core.stop` are
/// barriers, so nothing writes to the ring or audio after they return. Order on the way down: core
/// first, then audio.
@MainActor
final class GameSession: NSObject, ObservableObject, Identifiable {
    enum Phase: Equatable { case idle, prepared, running, paused, stopped }
    enum PauseReason: Hashable { case menu, background, interruption }

    struct Stats {
        var frames: Int
        var buttons: UInt32
        var videoWritten: Int
        var videoDropped: Int
        var audioWritten: Int
        var audioRendered: Int
        var audioEngineRunning: Bool
    }

    let id = UUID()
    let game: GameItem
    let renderer: MetalRenderer
    let ring: MetalTextureRing

    @Published private(set) var phase: Phase = .idle
    /// Empty means running. Play resumes only when every reason has cleared.
    @Published private(set) var pauseReasons: Set<PauseReason> = []
    var menuOpen: Bool { pauseReasons.contains(.menu) }
    private(set) var targetFPS: Double = 60

    var onStarted: (() -> Void)?
    /// Seconds actually played since the last call. Called on pause and on stop, so a kill loses little.
    var onPlayTime: ((TimeInterval) -> Void)?
    /// Called once, when the session ends. A message means it ended on an error.
    var onFinish: ((String?) -> Void)?

    private let interface: GagaCoreInterface
    private let romPath: String
    private let audio: AudioEngineManager
    private let controllers: ControllerManager
    private let skins: TouchSkinEngine
    private let bindings: [TriggerProManager.Binding]
    private let respectSilentMode: Bool

    private var core: GagaCoreWrapper?
    private var displayLink: CADisplayLink?
    private var observers: [NSObjectProtocol] = []
    private var runningSince: CFTimeInterval?
    private var touchMask: UInt32 = 0
    private var accessibilityMask: UInt32 = 0

    #if DEBUG
    private let log = Logger(subsystem: "com.zenithblue.gagaemu", category: "session")
    private var ticks = 0
    private var loggedButtons: UInt32 = 0
    #endif

    init(game: GameItem, interface: GagaCoreInterface, romPath: String, audio: AudioEngineManager = .shared,
         controllers: ControllerManager, skins: TouchSkinEngine, bindings: [TriggerProManager.Binding],
         shaderID: String, respectSilentMode: Bool) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let renderer = MetalRenderer(device: device) else {
            throw GameLaunchError.metalUnavailable
        }
        self.game = game
        self.interface = interface
        self.romPath = romPath
        self.audio = audio
        self.controllers = controllers
        self.skins = skins
        self.bindings = bindings
        self.respectSilentMode = respectSilentMode
        self.renderer = renderer
        self.ring = MetalTextureRing(device: device, width: 256, height: 224)
        super.init()
        renderer.textureRing = ring
        renderer.activePreset = ShaderPreset.from(id: shaderID)
    }

    #if DEBUG
    deinit { Logger(subsystem: "com.zenithblue.gagaemu", category: "session").notice("session deinit") }
    #endif

    var stats: Stats {
        let coreStats = core?.stats ?? (frames: 0, buttons: 0)
        let ringStats = ring.stats
        let audioStats = audio.stats
        return Stats(frames: coreStats.frames, buttons: coreStats.buttons,
                     videoWritten: ringStats.written, videoDropped: ringStats.dropped,
                     audioWritten: audioStats.written, audioRendered: audioStats.rendered,
                     audioEngineRunning: audioStats.engineRunning)
    }

    // MARK: - Lifecycle

    /// Validates the core, creates it and loads the game, off the main thread. Throws a message for the player.
    func prepare() async throws {
        guard phase == .idle else { return }
        let interface = self.interface
        let core = try await Task.detached(priority: .userInitiated) {
            try GagaCoreWrapper(interface: interface)
        }.value

        targetFPS = core.targetFPS
        wire(core)
        do {
            try await core.loadROM(path: romPath)
        } catch {
            core.stop()
            throw error
        }
        guard phase == .idle else {
            core.stop()
            return
        }
        self.core = core
        phase = .prepared
    }

    private func wire(_ core: GagaCoreWrapper) {
        // Queue only. Stops a bad core from raising the same error every frame.
        var reportedBadFrame = false
        core.onVideoFrame = { [ring, renderer, weak self] frame in
            guard let pixels = frame.pixelData else { return }
            guard let format = MetalTextureRing.metalFormat(for: frame.pixelFormat),
                  (1...8192).contains(frame.width), (1...8192).contains(frame.height),
                  frame.pitch >= frame.width * MetalTextureRing.bytesPerPixel(format) else {
                if !reportedBadFrame {
                    reportedBadFrame = true
                    let error: EmulatorCoreError = MetalTextureRing.metalFormat(for: frame.pixelFormat) == nil
                        ? .invalidPixelFormat(frame.pixelFormat.rawValue)
                        : .invalidFrame(width: frame.width, height: frame.height, pitch: frame.pitch)
                    Task { @MainActor in self?.stop(message: error.localizedDescription) }
                }
                return
            }
            if let texture = ring.writeFrame(pixelData: pixels, width: frame.width, height: frame.height,
                                             pitch: frame.pitch, pixelFormat: format) {
                renderer.setTexture(texture)
            }
        }
        core.onAudioPacket = { [audio] packet in audio.writeAudioPacket(packet) }
        core.onEvent = { [weak self] event in
            guard event.severity == GAGA_EVENT_FATAL else { return }
            // A fatal during load surfaces through the error prepare() throws, so fatal() ignores it here.
            Task { @MainActor in self?.fatal(event.message) }
        }
        if !bindings.isEmpty {
            // shortcut: TriggerPro applies to player 1 only, because bindings have no player field; give them one if local multiplayer needs it.
            let trigger = TriggerProManager()
            trigger.bindings = bindings
            let fps = core.targetFPS
            core.playerOneFilter = { state, frame in
                var raw = ControllerManager.InputState()
                raw.buttons = state.buttons
                var result = state
                result.buttons = trigger.process(raw, frame: frame, frameRate: fps).buttons
                return result
            }
        }
    }

    private func fatal(_ message: String) {
        guard phase == .running || phase == .paused else { return }
        stop(message: message)
    }

    /// Starts the frame loop. Called when the game view appears.
    func run() {
        guard phase == .prepared, let core else { return }
        audio.start(respectSilentMode: respectSilentMode)
        pushInputs()
        core.start()
        runningSince = CACurrentMediaTime()
        phase = .running
        UIApplication.shared.isIdleTimerDisabled = true
        observeSystem()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        onStarted?()
    }

    func pause(_ reason: PauseReason) {
        guard phase == .running || phase == .paused else { return }
        pauseReasons.insert(reason)
        if reason == .menu { clearTouches() }
        guard phase == .running else { return }
        core?.pause()
        audio.pause()
        displayLink?.isPaused = true
        flushPlayTime()
        phase = .paused
    }

    func resume(_ reason: PauseReason) {
        pauseReasons.remove(reason)
        guard phase == .paused, pauseReasons.isEmpty else { return }
        audio.start(respectSilentMode: respectSilentMode)
        pushInputs()
        core?.resume()
        displayLink?.isPaused = false
        runningSince = CACurrentMediaTime()
        phase = .running
    }

    /// Ends the session. Safe from any state and safe to call twice.
    func stop(message: String? = nil) {
        guard phase != .stopped else { return }
        phase = .stopped
        pauseReasons = []
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        displayLink?.invalidate()
        displayLink = nil
        core?.stop()
        core = nil
        audio.stop()
        clearTouches()
        flushPlayTime()
        UIApplication.shared.isIdleTimerDisabled = false
        let finish = onFinish
        onStarted = nil
        onPlayTime = nil
        onFinish = nil
        finish?(message)
    }

    private func flushPlayTime() {
        guard let start = runningSince else { return }
        runningSince = nil
        onPlayTime?(CACurrentMediaTime() - start)
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        func observe(_ name: Notification.Name, _ handler: @escaping @MainActor (GameSession, Notification) -> Void) {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    if let self { handler(self, note) }
                }
            })
        }
        // GPU work is not allowed in the background, so stop before it starts.
        observe(UIApplication.willResignActiveNotification) { session, _ in session.pause(.background) }
        observe(UIApplication.didBecomeActiveNotification) { session, _ in session.resume(.background) }
        observe(AVAudioSession.interruptionNotification) { session, note in session.handleInterruption(note) }
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            pause(.interruption)
        case .ended:
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            // Without shouldResume the system expects the player to choose, so the menu takes over.
            if !options.contains(.shouldResume) { pause(.menu) }
            resume(.interruption)
        @unknown default:
            break
        }
    }

    // MARK: - Input

    /// `points` are normalized in the touch canvas.
    func setTouches(_ points: [CGPoint]) {
        touchMask = skins.setTouches(points)
        pushInputs()
    }

    func clearTouches() {
        skins.releaseAll()
        touchMask = 0
        pushInputs()
    }

    /// VoiceOver has no press and hold, so its activate action holds the button long enough for a core to see it.
    func tapForAccessibility(_ mask: UInt32) {
        accessibilityMask |= mask
        pushInputs()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self else { return }
            self.accessibilityMask &= ~mask
            self.pushInputs()
        }
    }

    private func pushInputs() {
        guard let core else { return }
        var states = controllers.sample()
        if controllers.touchOwnsPlayerOne { states[0].buttons |= touchMask | accessibilityMask }
        for (slot, state) in states.enumerated() {
            core.setInput(player: slot, state: GagaInputState(state))
        }
        #if DEBUG
        if states[0].buttons != loggedButtons {
            loggedButtons = states[0].buttons
            log.notice("input p1 buttons=0x\(String(self.loggedButtons, radix: 16), privacy: .public)")
        }
        #endif
    }

    /// Controllers have no change callback worth trusting per button, so read them once per display frame.
    @objc private func tick() {
        pushInputs()
        #if DEBUG
        ticks += 1
        if ticks % 120 == 0 {
            let s = stats
            log.notice("stats frames=\(s.frames, privacy: .public) buttons=0x\(String(s.buttons, radix: 16), privacy: .public) video=\(s.videoWritten, privacy: .public) dropped=\(s.videoDropped, privacy: .public) audioIn=\(s.audioWritten, privacy: .public) audioOut=\(s.audioRendered, privacy: .public) engine=\(s.audioEngineRunning, privacy: .public)")
        }
        #endif
    }
}
