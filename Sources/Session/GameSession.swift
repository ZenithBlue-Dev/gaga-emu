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
    case gpuBelowFloor

    var errorDescription: String? {
        switch self {
        case .noCore: return "No core is available for this type of file."
        case .coreNotBuilt(let name): return "\(name) is not part of this build yet."
        case .romMissing(let file): return "The game file \(file) is missing. Try adding the game again."
        case .metalUnavailable: return "This device could not start the video renderer."
        case .gpuBelowFloor: return GPUFloor.layerPathMessage
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
        var audioUnderruns: Int
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
    /// Whole frames per tick. 1 is normal speed.
    @Published private(set) var fastForward = 1
    /// What the touch button switches to. The pause menu sets it.
    private var fastForwardChoice = 2
    @Published private(set) var cheats: [CheatEntry] = []
    /// A message for the player that does not end the session.
    @Published var notice: String?
    let saves: SaveStore
    /// Off unless the player chose it and may use it. The owner of the session supplies both checks.
    var autoSaveEnabled: @MainActor () -> Bool = { false }

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
    private let entitlements: @MainActor () -> StoreKitManager.Entitlements

    private var core: GagaCoreWrapper?
    private var hasRun = false
    private var menuPairHeld = false
    private var displayLink: CADisplayLink?
    private var observers: [NSObjectProtocol] = []
    private var runningSince: CFTimeInterval?
    private var touchMask: UInt32 = 0
    private var accessibilityMask: UInt32 = 0
    private var pointer: (x: Int16, y: Int16)?
    /// The view the device's own picture is drawn in. Not the external screen's: fingers are not there.
    weak var pictureView: UIView?
    /// A layer-path core presents to a CAMetalLayer itself (docs/05 section 2.3). The renderer, the ring
    /// and host shaders are unused.
    let drawsOwnPicture: Bool
    /// The layer the core presents to, with its drawable size. Kept until the core exists.
    private var layerTarget: (layer: CAMetalLayer, width: Int, height: Int, scale: CGFloat)?

    #if DEBUG
    private let log = Logger(subsystem: "com.zenithblue.gagaemu", category: "session")
    private var ticks = 0
    private var loggedButtons: UInt32 = 0
    #endif

    init(game: GameItem, interface: GagaCoreInterface, romPath: String, audio: AudioEngineManager = .shared,
         controllers: ControllerManager, skins: TouchSkinEngine, bindings: [TriggerProManager.Binding],
         shaderID: String, respectSilentMode: Bool, saveDirectory: URL? = nil,
         entitlements: @escaping @MainActor () -> StoreKitManager.Entitlements = { .effective(.free) }) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let renderer = MetalRenderer(device: device) else {
            throw GameLaunchError.metalUnavailable
        }
        drawsOwnPicture = interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue != 0
        guard !drawsOwnPicture || GPUFloor.supportsLayerPathCores(device) else { throw GameLaunchError.gpuBelowFloor }
        self.saves = saveDirectory.map(SaveStore.init(directory:)) ?? SaveStore(romPath: romPath)
        self.entitlements = entitlements
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
                     audioUnderruns: audioStats.underruns, audioEngineRunning: audioStats.engineRunning)
    }

    // MARK: - Lifecycle

    /// Validates the core, creates it and loads the game, off the main thread. Throws a message for the player.
    func prepare() async throws {
        guard phase == .idle else { return }
        let interface = self.interface
        let saveDirectory = saves.directory.path
        let core = try await Task.detached(priority: .userInitiated) {
            try GagaCoreWrapper(interface: interface, saveDirectory: saveDirectory)
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
        if let target = layerTarget { attachLayer(target.layer, width: target.width, height: target.height, scale: target.scale) }
        cheats = saves.cheats()
        if core.supportsCheats {
            // shortcut: a stored code this core now refuses stays listed but does nothing. It was valid when added, so this needs a core change; show it in the list if that ever happens.
            for cheat in cheats { try? core.addCheat(id: cheat.id, code: cheat.code, enabled: cheat.enabled) }
        }
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
        #if DEBUG
        var audioPackets = 0
        var audioPeak: Int16 = 0
        core.onAudioPacket = { [audio, log] packet in
            audioPeak = max(audioPeak, packet.samples.max() ?? 0)
            audioPackets += 1
            if audioPackets % 240 == 0 {
                log.notice("audio peak=\(audioPeak, privacy: .public) packets=\(audioPackets, privacy: .public)")
                audioPeak = 0
            }
            audio.writeAudioPacket(packet)
        }
        #else
        core.onAudioPacket = { [audio] packet in audio.writeAudioPacket(packet) }
        #endif
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
        hasRun = true
        UIApplication.shared.isIdleTimerDisabled = true
        observeSystem()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        onStarted?()
        if notice != nil { pause(.menu) } // A failed resume: let the player read it before the game moves on.
    }

    func pause(_ reason: PauseReason) {
        guard phase == .running || phase == .paused else { return }
        pauseReasons.insert(reason)
        if reason == .menu { clearTouches() }
        updateDisplayLink()
        guard phase == .running else { return }
        core?.pause()
        audio.pause()
        flushPlayTime()
        phase = .paused
    }

    func resume(_ reason: PauseReason) {
        pauseReasons.remove(reason)
        updateDisplayLink()
        guard phase == .paused, pauseReasons.isEmpty else { return }
        audio.start(respectSilentMode: respectSilentMode)
        pushInputs()
        core?.resume()
        runningSince = CACurrentMediaTime()
        phase = .running
    }

    /// It keeps ticking behind the menu, so a controller can close what it opened.
    private func updateDisplayLink() {
        displayLink?.isPaused = pauseReasons.contains(.background) || pauseReasons.contains(.interruption)
    }

    /// Ends the session. Safe from any state and safe to call twice.
    func stop(message: String? = nil) {
        guard phase != .stopped else { return }
        // A session ending on an error may be why it ended, so it must not replace a good auto save.
        if message == nil { saveAuto() }
        phase = .stopped
        #if DEBUG
        CodeGenCheck.report("session stop, \(game.title)")
        #endif
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

    // MARK: - Layer path

    /// Call on every drawable size change, such as a rotation from landscape left to landscape right.
    func attachLayer(_ layer: CAMetalLayer, width: Int, height: Int, scale: CGFloat) {
        guard drawsOwnPicture, width > 0, height > 0 else { return }
        layerTarget = (layer, width, height, scale)
        if let core, !core.attachMetalLayer(layer, width: width, height: height, scale: scale) {
            stop(message: "The 3D renderer could not start on this screen.")
        }
    }

    /// Only the layer attached last, so a picture moving to the external screen is not cut off by the old one.
    func detachLayer(_ layer: CAMetalLayer) {
        guard layerTarget?.layer === layer else { return }
        layerTarget = nil
        core?.detachMetalLayer()
    }

    private func flushPlayTime() {
        guard let start = runningSince else { return }
        runningSince = nil
        onPlayTime?(CACurrentMediaTime() - start)
    }

    // MARK: - Save states

    var supportsSaveStates: Bool { core?.supportsSaveStates ?? false }

    @discardableResult
    func saveState() throws -> SaveSlot {
        guard let core else { throw EmulatorCoreError.coreNotLoaded }
        let allowed = entitlements()
        let count = saves.manualCount
        guard allowed.canAddSaveState(current: count) else { throw SaveStateError.limitReached(allowed.maxSaveStates) }
        return try writeState(core, auto: false)
    }

    private func writeState(_ core: GagaCoreWrapper, auto: Bool) throws -> SaveSlot {
        let file = SaveStateFile.encode(payload: try core.saveState(), coreID: core.coreID, stateVersion: core.stateVersion)
        return try saves.writeState(file, thumbnail: thumbnail(core), auto: auto)
    }

    private func thumbnail(_ core: GagaCoreWrapper) -> Data? {
        guard drawsOwnPicture else {
            let ring = self.ring
            return core.betweenFrames { ring.latestFramePNG() }
        }
        guard let frame = core.readLayerPixels() else { return nil }
        return MetalTextureRing.png(frame.pixels, width: frame.width, height: frame.height,
                                    bytesPerRow: frame.width * 4, pixelFormat: .bgra8Unorm)
    }

    /// Every check runs before the core is touched, and the core keeps its game on any failure.
    func loadState(_ slot: SaveSlot) throws {
        guard let core else { throw EmulatorCoreError.coreNotLoaded }
        let file = try Data(contentsOf: slot.url, options: .mappedIfSafe)
        try core.loadState(SaveStateFile.decode(file, coreID: core.coreID, stateVersion: core.stateVersion))
    }

    private func saveAuto() {
        guard hasRun, autoSaveEnabled(), let core, core.supportsSaveStates else { return }
        do {
            try writeState(core, auto: true)
        } catch {
            // Nobody is looking at the screen on the way out, and the last auto save is still whole.
            #if DEBUG
            log.error("auto save failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Fast-forward

    /// Speeds this player may pick, slowest first. 1 is off.
    var fastForwardSpeeds: [Int] { [1, 2, 3, 5].filter { Double($0) <= entitlements().maxFastForward } }

    /// Clamped here, so a caller cannot run past `maxFastForward`.
    func setFastForward(_ speed: Int) {
        let allowed = fastForwardSpeeds.last { $0 <= speed } ?? 1
        fastForward = allowed
        if allowed > 1 { fastForwardChoice = allowed }
        core?.setSpeed(allowed)
    }

    func toggleFastForward() { setFastForward(fastForward == 1 ? fastForwardChoice : 1) }

    // MARK: - Cheats

    var supportsCheats: Bool { core?.supportsCheats ?? false }
    var canAddCheat: Bool { entitlements().canAddCheat(current: cheats.count) }

    /// The core judges the code. Nothing is stored unless it accepts.
    func addCheat(name: String, code: String) throws {
        guard let core else { throw EmulatorCoreError.coreNotLoaded }
        guard canAddCheat else {
            let limit = entitlements().maxCheats
            throw EmulatorCoreError.cheatRejected("You have \(limit) cheats, the most without Gaga Plus. Remove one to add another.")
        }
        let entry = CheatEntry(id: (cheats.map(\.id).max() ?? 0) + 1, name: name, code: code, enabled: true)
        try core.addCheat(id: entry.id, code: code, enabled: true)
        do {
            try saves.saveCheats(cheats + [entry])
        } catch {
            core.removeCheat(id: entry.id)
            throw error
        }
        cheats.append(entry)
    }

    func removeCheat(_ cheat: CheatEntry) throws {
        let remaining = cheats.filter { $0.id != cheat.id }
        try saves.saveCheats(remaining)
        core?.removeCheat(id: cheat.id)
        cheats = remaining
    }

    func setCheat(_ cheat: CheatEntry, enabled: Bool) throws {
        var updated = cheats
        guard let index = updated.firstIndex(where: { $0.id == cheat.id }) else { return }
        updated[index].enabled = enabled
        try saves.saveCheats(updated)
        core?.setCheat(id: cheat.id, enabled: enabled)
        cheats = updated
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
        // The app can be killed from here with no further warning.
        observe(UIApplication.didEnterBackgroundNotification) { session, _ in
            session.core?.flushBatterySave()
            session.saveAuto()
        }
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

    #if DEBUG
    /// Benchmark hooks. Call between `prepare` and `run`. Both closures run on the core's queue.
    func attachBenchmark(script: @escaping (Int) -> UInt32, timing: @escaping (UInt64, UInt64, UInt64) -> Void) {
        core?.playerOneFilter = { state, frame in
            var scripted = state
            scripted.buttons = script(frame)
            return scripted
        }
        core?.onFrameTimed = timing
    }
    #endif

    // MARK: - Input

    /// `points` are normalized in the touch canvas. `windowPoints` are the same fingers in window
    /// coordinates: the first one on the picture is the pointer, for a core with a touch screen.
    func setTouches(_ points: [CGPoint], windowPoints: [CGPoint] = []) {
        touchMask = skins.setTouches(points)
        pointer = windowPoints.lazy.compactMap { [self] point -> (x: Int16, y: Int16)? in
            guard let view = pictureView, let content = renderer.contentSize else { return nil }
            return Self.libretroPointer(view.convert(point, from: nil), bounds: view.bounds.size, content: content)
        }.first
        pushInputs()
    }

    func clearTouches() {
        skins.releaseAll()
        touchMask = 0
        pointer = nil
        pushInputs()
    }

    /// libretro's pointer scale, -32767 to 32767 across the frame as the renderer fits it in `bounds`.
    /// Nil off the picture, in the letterbox.
    static func libretroPointer(_ point: CGPoint, bounds: CGSize, content: CGSize) -> (x: Int16, y: Int16)? {
        let fit = MetalRenderer.fittedViewport(contentWidth: Int(content.width), contentHeight: Int(content.height), drawable: bounds)
        guard fit.width > 0, fit.height > 0 else { return nil }
        let u = (Double(point.x) - fit.originX) / fit.width, v = (Double(point.y) - fit.originY) / fit.height
        guard (0..<1).contains(u), (0..<1).contains(v) else { return nil }
        return (Int16((u * 65534 - 32767).rounded()), Int16((v * 65534 - 32767).rounded()))
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

    /// Platforms whose core takes the hardware keyboard key by key (GagaInputState.keys).
    static let typingPlatforms: Set<String> = ["dos"]

    private func pushInputs() {
        guard let core else { return }
        var states = controllers.sample()
        menuPair(held: states.contains(where: \.openMenu))
        if controllers.touchOwnsPlayerOne { states[0].buttons |= touchMask | accessibilityMask }
        // A DOS program reads the keys themselves, so the keyboard does not also press pad buttons there.
        let typing = Self.typingPlatforms.contains(game.platformID)
        if !typing { states[0].buttons |= controllers.keyboardButtons() }
        for (slot, state) in states.enumerated() {
            var input = GagaInputState(state)
            if slot == 0, typing {
                let keys = controllers.keyboardKeys()
                withUnsafeMutableBytes(of: &input.keys) { $0.copyBytes(from: keys) }
            }
            if slot == 0, let pointer {
                input.pointer_x = pointer.x
                input.pointer_y = pointer.y
                input.pointer_down = true
            }
            core.setInput(player: slot, state: input)
        }
        #if DEBUG
        if states[0].buttons != loggedButtons {
            loggedButtons = states[0].buttons
            log.notice("input p1 buttons=0x\(String(self.loggedButtons, radix: 16), privacy: .public)")
        }
        #endif
    }

    /// Opens the menu on the press, or closes it again, so holding the pair does not flicker.
    func menuPair(held: Bool) {
        defer { menuPairHeld = held }
        guard held, !menuPairHeld, phase == .running || phase == .paused else { return }
        if menuOpen { resume(.menu) } else { pause(.menu) }
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
