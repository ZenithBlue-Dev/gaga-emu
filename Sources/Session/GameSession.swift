import AVFoundation
import Metal
import MetalKit
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
    var fastForwardChoice = 2
    @Published private(set) var cheats: [CheatEntry] = []
    /// A signed-in player's achievements. Set by the owner before `prepare`; nil costs nothing.
    var achievements: RetroAchievements?
    /// The game has an achievement set running, so the pause menu lists it.
    @Published private(set) var achievementsLoaded = false
    /// A game is running under RetroAchievements hardcore rules: no state load, cheats or rewind.
    @Published private(set) var hardcoreActive = false
    /// A state was loaded before the set arrived; hardcore must then start from a reset.
    private var stateLoadedBeforeSet = false
    /// A message for the player that does not end the session.
    @Published var notice: String?
    /// The core's options as the running game holds them. Nil for a core that takes none.
    @Published private(set) var coreOptions: CoreOptionSet?
    /// Options changed in play that the running game did not take: they apply after a restart.
    @Published private(set) var optionsNeedRestart: [String] = []
    /// The player's values the core gets before the game loads. Set before `prepare`.
    var coreOptionValues: [String: String] = [:]
    /// The core's declaration once the game is loaded, and whether a running game took each changed key.
    var onCoreOptions: ((CoreOptionSet) -> Void)?
    var onOptionLearned: ((String, Bool) -> Void)?
    /// Changed keys and the value each should reach, checked once play resumes.
    private var pendingOptions: [String: String] = [:]
    let saves: SaveStore
    /// Off unless the player chose it and may use it. The owner of the session supplies both checks.
    var autoSaveEnabled: @MainActor () -> Bool = { false }

    enum RewindStatus: Equatable {
        case off, checking, ready
        case unavailable(String)
    }
    /// The Rewind setting. Read once, in `prepare`.
    var rewindEnabled = false
    @Published private(set) var rewindStatus: RewindStatus = .off
    @Published private(set) var rewinding = false
    private var rewindTouchHeld = false

    // MARK: Control options, set by the owner before `run`
    /// Turbo and macros, stepped per emulated frame, one per port. Made in `wire`.
    private(set) var processors = (0..<ControllerManager.slotCount).map { _ in FrameInputProcessor() }
    /// Player 1's: touch, recording and the pause menu's macro list act there.
    var processor: FrameInputProcessor { processors[0] }
    var turboHertz = 15.0
    /// The saved macros, looked up when one is pressed, so an edit in the pause menu applies at once.
    var macros: () -> [Macro] = { [] }
    /// A finished recording, as steps.
    var onMacroRecorded: (([Macro.Step]) -> Void)?
    /// The quick save slot changed, for the owner to keep.
    var onQuickSlotChange: ((Int) -> Void)?
    /// Players this system takes (`CoreCatalog.maxPlayers`), with its multiplayer adapter unless that is Off.
    /// Controllers past it reach no port.
    var maxPlayers = 4
    /// Multitap On: every port is in use, so the adapter stays in. Auto plugs it in once a controller sits past the
    /// console's own ports (`CoreCatalog.multitap`).
    var multitapAlwaysOn = false
    /// The app actions held last time inputs were read, per port, to act on presses and releases only.
    private var heldActions = Array(repeating: Set<ControlAction>(), count: ControllerManager.slotCount)
    private var heldApps: Set<ControlAction> = []
    private var fastForwardHeld = false
    /// Turbo toggled on, per port. Player 1's is `turboToggled`, which the touch controls show.
    private var toggledTurbo = Array(repeating: UInt32(0), count: ControllerManager.slotCount)
    @Published private(set) var turboToggled: UInt32 = 0
    @Published private(set) var muted = false
    @Published private(set) var recordingMacro = false
    @Published private(set) var runningMacros: Set<UUID> = []
    @Published var quickSlot = 1
    /// A short line over the game, such as "Saved to slot 2". Clears itself.
    @Published private(set) var flash: String?
    /// The device is upright. The game view sets it; the owner swaps the screen settings for the orientation.
    @Published private(set) var portrait = false
    /// The screen settings for an orientation, from the owner's store.
    var screenForOrientation: ((Bool) -> ScreenSettings)?

    var onStarted: (() -> Void)?
    /// Seconds actually played since the last call. Called on pause and on stop, so a kill loses little.
    var onPlayTime: ((TimeInterval) -> Void)?
    /// Called once, when the session ends. A message means it ended on an error.
    var onFinish: ((String?) -> Void)?
    /// Running seconds a started game may go without a single frame before it is stopped with a message, so a
    /// core stuck in its load never leaves a silent black screen (device run 13).
    var firstFrameTimeout: TimeInterval = 30

    private let interface: GagaCoreInterface
    private let romPath: String
    private let audio: AudioEngineManager
    private let controllers: ControllerManager
    private let skins: TouchSkinEngine
    private let bindings: [TriggerProManager.Binding]
    private let respectSilentMode: Bool
    private let entitlements: @MainActor () -> StoreKitManager.Entitlements
    /// The game's rumble. Nil plays none.
    let rumble: RumbleManager?

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
    /// A layer-path core whose frames go through the renderer and the filter chain instead (docs/05 section 2.4):
    /// a filter is chosen, or the system has two screens for the host to place (section 2.6), and the core can
    /// render off-screen. Otherwise it presents directly, at no cost. Turns false, and the layer picture takes
    /// over, if the core refuses.
    @Published private(set) var filtersLayerCore: Bool
    /// The renderer draws the core's frames, so screen layouts and filters reach them.
    var hostDrawsPicture: Bool { !drawsOwnPicture || filtersLayerCore }
    /// Scaling and, on a two-screen system, the layout. The owner saves each change through `onScreenChange`.
    @Published var screen = ScreenSettings() {
        didSet {
            syncScreen()
            if screen != oldValue { onScreenChange?(screen) }
        }
    }
    var onScreenChange: ((ScreenSettings) -> Void)?
    /// The core's frame size, for the layer picture to place itself. Updated each display frame.
    @Published private(set) var frameSize: CGSize?
    /// The pause menu and Settings offer the two-screen options only when the host places the screens.
    var isDualScreen: Bool { hostDrawsPicture && ScreenLayout.isDual(game.platformID) }
    /// The touch screen is not drawn, so touch input is off.
    var touchScreenHidden: Bool { isDualScreen && deviceScreens == nil && !ScreenLayout.showsTouchScreen(screen) }
    /// The layer the core presents to, with its drawable size. Kept until the core exists.
    private var layerTarget: (layer: CAMetalLayer, width: Int, height: Int, scale: CGFloat)?

    #if DEBUG
    private let log = Logger(subsystem: "com.zenithblue.gagaemu", category: "session")
    private var ticks = 0
    private var loggedButtons: UInt32 = 0
    /// Set by `attachBenchmark`: the script is the only input, so no touch or controller app function acts.
    private var benchmarkScripted = false
    #endif

    init(game: GameItem, interface: GagaCoreInterface, romPath: String, audio: AudioEngineManager = .shared,
         controllers: ControllerManager, skins: TouchSkinEngine, bindings: [TriggerProManager.Binding],
         shaderID: String, respectSilentMode: Bool, saveDirectory: URL? = nil, rumble: RumbleManager? = nil,
         entitlements: @escaping @MainActor () -> StoreKitManager.Entitlements = { .effective(.free) }) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let renderer = MetalRenderer(device: device) else {
            throw GameLaunchError.metalUnavailable
        }
        drawsOwnPicture = interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue != 0
        guard !drawsOwnPicture || GPUFloor.supportsLayerPathCores(device) else { throw GameLaunchError.gpuBelowFloor }
        // A two-screen system always goes through the renderer, so a layout change in the pause menu needs no
        // switch between the two paths mid-game. The cost is one copy of a small frame.
        filtersLayerCore = drawsOwnPicture && (CoreCatalog.isFilter(shaderID) || ScreenLayout.isDual(game.platformID))
            && interface.capabilities & GAGA_CORE_CAP_OUTPUT_TEXTURE.rawValue != 0
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
        self.rumble = rumble
        self.renderer = renderer
        self.ring = MetalTextureRing(device: device, width: 256, height: 224)
        super.init()
        renderer.textureRing = ring
        renderer.activePreset = ShaderPreset.from(id: shaderID)
        syncScreen()
    }

    /// A device skin's two screen places in the picture view (`TouchSkinEngine.DeviceArt.screenPlaces`), which replace
    /// the two-screen layout while it shows. Nil otherwise. Not saved: the player's own layout stays as it was.
    var deviceScreens: [CGRect]? {
        didSet { if deviceScreens != oldValue { syncScreen() } }
    }

    private func syncScreen() {
        var placed = screen
        if let places = deviceScreens, places.count == 2 {
            placed.preset = .custom
            placed.customTop = places[0]; placed.customBottom = places[1]
            placed.swapped = false; placed.showTop = true; placed.showBottom = true; placed.rotation = .none
        }
        renderer.setScreen(placed, platformID: hostDrawsPicture ? game.platformID : "")
    }

    /// The quick toggle: exchanges the screens, or picks the other one in One Screen.
    func swapScreens() {
        guard isDualScreen else { return }
        screen.swapped.toggle()
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
        for (key, value) in coreOptionValues { core.setOption(key, value) } // Before the game, which reads them as it loads.
        setenv("GAGA_USERNAME", PlayerName.effective, 1) // RETRO_ENVIRONMENT_GET_USERNAME and Azahar's 3DS profile.
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
        coreOptions = core.options()
        if let coreOptions { onCoreOptions?(coreOptions) }
        if rewindEnabled {
            rewindStatus = .checking
            core.onRewindVerdict = { [weak self] reason in
                Task { @MainActor in self?.rewindStatus = reason.map(RewindStatus.unavailable) ?? .ready }
            }
            core.enableRewind()
        }
        if filtersLayerCore, !core.attachOutputTexture() {
            filtersLayerCore = false
            syncScreen()
        }
        if let target = layerTarget { attachLayer(target.layer, width: target.width, height: target.height, scale: target.scale) }
        cheats = saves.cheats()
        if core.supportsCheats {
            // shortcut: a stored code this core now refuses stays listed but does nothing. It was valid when added, so this needs a core change; show it in the list if that ever happens.
            for cheat in cheats { try? core.addCheat(id: cheat.id, code: cheat.code, enabled: cheat.enabled) }
        }
        startAchievements(core)
        phase = .prepared
    }

    private func startAchievements(_ core: GagaCoreWrapper) {
        guard let achievements, let console = RetroAchievements.consoleID(platform: game.platformID),
              core.prepareAchievementMemory(consoleID: console) else {
            achievements = nil
            return
        }
        core.onFrameStepped = { [weak achievements] in achievements?.doFrame() }
        achievements.onEvent = { [weak self] event in self?.handleAchievement(event) }
        achievements.startGame(path: romPath, console: console) { [weak self] loaded in
            guard let self else { return }
            achievementsLoaded = loaded
            updateHardcoreGate()
            if hardcoreActive, stateLoadedBeforeSet {
                stateLoadedBeforeSet = false
                self.core?.reset()
                achievements.reset()
            }
        }
    }

    private func handleAchievement(_ event: RetroAchievements.Event) {
        switch event {
        case .unlocked(let title, let points): announce("Achievement unlocked: \(title), \(points) points.")
        case .offline: show("Offline. Unlocks will be sent when the connection returns.")
        case .reconnected: show("Reconnected. Unlocks sent.")
        case .serverError(let message): show(message)
        case .reset:
            // Hardcore was just switched on: the rules require a fresh start.
            core?.reset()
            achievements?.reset()
        }
    }

    /// The toast, read out by VoiceOver as well.
    private func announce(_ line: String) {
        show(line)
        UIAccessibility.post(notification: .announcement, argument: line)
    }

    func setHardcore(_ on: Bool) {
        achievements?.setHardcore(on)
        updateHardcoreGate()
    }

    private func updateHardcoreGate() {
        let on = achievementsLoaded && achievements?.hardcore == true
        guard on != hardcoreActive else { return }
        hardcoreActive = on
        if on {
            rewindTouchHeld = false
            updateRewinding(controllerHeld: false)
        }
        // Enabled cheats stop reaching the core under hardcore and come back after it, without changing the saved list.
        for cheat in cheats where cheat.enabled { core?.setCheat(id: cheat.id, enabled: !on) }
    }

    /// RetroAchievements' list for the pause menu.
    func achievementList() -> [AchievementInfo] { achievements?.achievements() ?? [] }

    private func wire(_ core: GagaCoreWrapper) {
        // Queue only. Stops a bad core from raising the same error every frame.
        var reportedBadFrame = false
        core.onVideoFrame = { [ring, renderer, weak self] frame in
            if frame.pixelFormat == GAGA_PIXEL_FORMAT_METAL_TEXTURE, let shared = frame.pixelData {
                renderer.receive(shared.load(as: GagaMetalTextureFrame.self), ring: ring)
                return
            }
            guard let pixels = frame.pixelData else {
                // A layer-path core's size-only frame, sent for each presented frame. Its size places a finger on the picture.
                if frame.width > 0, frame.height > 0 {
                    renderer.setPresentedSize(width: frame.width, height: frame.height)
                    ring.noteLayerFrame()
                }
                return
            }
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
        core.onEvent = { [weak self, rumble] event in
            if event.severity == GAGA_EVENT_RUMBLE { rumble?.receive(RumbleManager.Change(code: event.code)) }
            guard event.severity == GAGA_EVENT_FATAL else { return }
            // A fatal during load surfaces through the error prepare() throws, so fatal() ignores it here.
            Task { @MainActor in self?.fatal(event.message) }
        }
        // TriggerPro, turbo and macros per port, each with its own state, on this phone's ports only: the filter runs
        // before Play Nearby's lockstep merges the other phone's.
        let fps = core.targetFPS
        let triggers: [TriggerProManager]? = bindings.isEmpty ? nil : (0..<ControllerManager.slotCount).map { _ in
            let trigger = TriggerProManager()
            trigger.bindings = bindings
            return trigger
        }
        let processors = (0..<ControllerManager.slotCount).map { _ in FrameInputProcessor(hertz: turboHertz, frameRate: fps) }
        self.processors = processors
        core.portFilter = { port, state, frame in
            guard processors.indices.contains(port) else { return state }
            var result = state
            if let trigger = triggers?[port] {
                var raw = ControllerManager.InputState()
                raw.buttons = state.buttons
                result.buttons = trigger.process(raw, frame: frame, frameRate: fps).buttons
            }
            result.buttons = processors[port].process(result.buttons, frame: frame)
            return result
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
        controllers.reserveSystemGestures(true)
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        onStarted?()
        watchFirstFrame()
        if notice != nil { pause(.menu) } // A failed resume: let the player read it before the game moves on.
    }

    /// Counts running time only, so a game paused in the menu before its first frame is not stopped for it.
    private func watchFirstFrame() {
        let limit = firstFrameTimeout, step = 0.25
        Task { [weak self] in
            var waited: TimeInterval = 0
            while waited < limit {
                try? await Task.sleep(for: .seconds(step))
                guard let self, phase == .running || phase == .paused else { return }
                let video = ring.stats
                if video.written + video.dropped > 0 { return }
                if phase == .running { waited += step }
            }
            self?.stop(message: "The game showed no picture for \(Int(limit)) seconds, so it was stopped.")
        }
    }

    func pause(_ reason: PauseReason) {
        guard phase == .running || phase == .paused else { return }
        // Hardcore limits how often the game may pause. A forced stop still pauses.
        if reason == .menu, hardcoreActive, phase == .running, achievements?.canPause() == false {
            return show("Hardcore: pausing again in a moment.")
        }
        pauseReasons.insert(reason)
        rewindTouchHeld = false // The button may vanish under the finger, and its release with it.
        processors.forEach { $0.cancelMacros() }
        runningMacros = []
        if reason == .menu { clearTouches() }
        updateDisplayLink()
        guard phase == .running else { return }
        core?.pause()
        rumble?.pause()
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
        rumble?.resume()
        runningSince = CACurrentMediaTime()
        phase = .running
        if !pendingOptions.isEmpty { checkOptionsSoon() }
    }

    // MARK: - Core options

    /// Hands the running core a new value, or the default for nil. The core reads it once play resumes. False when the
    /// core refuses it.
    @discardableResult
    func setCoreOption(_ key: String, _ value: String?) -> Bool {
        guard let core, core.setOption(key, value) else { return false }
        coreOptions = core.options()
        guard let option = coreOptions?.option(key) else { return true }
        if option.restart == true {
            if !optionsNeedRestart.contains(option.label) { optionsNeedRestart.append(option.label) }
        } else if option.restart == nil, let expected = value ?? option.default {
            pendingOptions[key] = expected
        }
        return true
    }

    /// Whether the core read each changed value in its first half second of play. One it did not read needs a restart.
    private func checkOptionsSoon() {
        let pending = pendingOptions
        pendingOptions = [:]
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, let core, phase == .running || phase == .paused else { return }
            let now = core.options()
            coreOptions = now
            for (key, expected) in pending {
                guard let option = now?.option(key) else { continue }
                let live = option.served == expected
                onOptionLearned?(key, live)
                if !live, !optionsNeedRestart.contains(option.label) { optionsNeedRestart.append(option.label) }
            }
            if !optionsNeedRestart.isEmpty { show("Restart the game to apply core options. Pause, then Core Options.") }
        }
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
        achievements?.onEvent = nil
        achievements?.endGame() // Before the core goes: the address map points into it.
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
        rumble?.pause() // After the core: it sends no more.
        audio.stop()
        clearTouches()
        controllers.reserveSystemGestures(false)
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
    /// Play Nearby's hook (`Sources/Netplay`): the running core, for its lockstep and state checks.
    var netplayCore: GagaCoreWrapper? { core }
    /// Players on this phone for Play Nearby: up to the highest controller slot taken, at least 1 (touch).
    var netplayLocalPlayers: Int { min(max((controllers.devices.compactMap(\.slot).max() ?? 0) + 1, 1), max(maxPlayers, 1)) }

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
        if hardcoreActive { throw RetroAchievementsError.hardcoreBlocks("Loading a state") }
        let file = try Data(contentsOf: slot.url, options: .mappedIfSafe)
        try core.loadState(SaveStateFile.decode(file, coreID: core.coreID, stateVersion: core.stateVersion))
        if achievementsLoaded { achievements?.stateChanged() } else { stateLoadedBeforeSet = true }
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

    // MARK: - Rewind

    /// The touch button. A controller holds an input mapped to Rewind (Hold) instead.
    func setRewindHeld(_ held: Bool) {
        rewindTouchHeld = held
        pushInputs()
    }

    /// VoiceOver has no press and hold: its action rewinds for one second.
    func rewindForAccessibility() {
        setRewindHeld(true)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.setRewindHeld(false)
        }
    }

    private func updateRewinding(controllerHeld: Bool) {
        let held = rewindStatus == .ready && !hardcoreActive && (rewindTouchHeld || controllerHeld)
        guard held != rewinding else { return }
        rewinding = held
        core?.setRewinding(held)
        if !held { achievements?.stateChanged() }
    }

    // MARK: - Cheats

    var supportsCheats: Bool { core?.supportsCheats ?? false }
    var canAddCheat: Bool { entitlements().canAddCheat(current: cheats.count) }
    /// The formats this core reads, for the cheat sheet, or why it has none, for the pause menu.
    var cheatHint: String { CheatFormat.hint(coreID: core?.coreID ?? "") }
    var coreID: String { core?.coreID ?? "" }
    var noCheatsNote: String? {
        guard let core, !core.supportsCheats else { return nil }
        return CheatFormat.unsupported(coreName: core.name)
    }

    /// The core judges the code. Nothing is stored unless it accepts.
    func addCheat(name: String, code: String, enabled: Bool = true) throws {
        guard let core else { throw EmulatorCoreError.coreNotLoaded }
        if hardcoreActive { throw RetroAchievementsError.hardcoreBlocks("Cheats") }
        guard canAddCheat else {
            let limit = entitlements().maxCheats
            throw EmulatorCoreError.cheatRejected("You have \(limit) cheats, the most without Gaga Plus. Remove one to add another.")
        }
        let entry = CheatEntry(id: (cheats.map(\.id).max() ?? 0) + 1, name: name, code: code, enabled: enabled)
        try core.addCheat(id: entry.id, code: code, enabled: enabled)
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
        if hardcoreActive { throw RetroAchievementsError.hardcoreBlocks("Cheats") }
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
            // Without shouldResume the system expects the player to choose, so the menu takes over. iOS may send an
            // end with no begin; that one paused nothing, so it opens no menu.
            #if DEBUG
            print("[gaga-audio] interruption ended, began seen \(pauseReasons.contains(.interruption)), shouldResume \(options.contains(.shouldResume))")
            #endif
            if !options.contains(.shouldResume), pauseReasons.contains(.interruption) { pause(.menu) }
            resume(.interruption)
        @unknown default:
            break
        }
    }

    #if DEBUG
    /// Benchmark hooks. Call between `prepare` and `run`. Both closures run on the core's queue.
    func attachBenchmark(script: @escaping (Int) -> UInt32, timing: @escaping (UInt64, UInt64, UInt64) -> Void) {
        benchmarkScripted = true
        core?.portFilter = { port, state, frame in
            guard port == 0 else { return state }
            var scripted = state
            scripted.buttons = script(frame)
            return scripted
        }
        core?.onFrameTimed = timing
    }

    /// The picture on screen as a PNG, read back from the layer for a layer-path core.
    func benchmarkScreenshot() -> Data? { core.flatMap(thumbnail) }

    /// Pixels not black, of all, in the frame a layer-path core last presented: on the output-texture path, the
    /// texture the screen shows. Nil for a core the host draws.
    func benchmarkLitPixels() -> (lit: Int, total: Int)? {
        guard drawsOwnPicture, let frame = core?.readLayerPixels() else { return nil }
        let lit = frame.pixels.withUnsafeBytes { raw in
            stride(from: 0, to: raw.count - 3, by: 4).reduce(0) { $0 + (raw[$1] | raw[$1 + 1] | raw[$1 + 2] != 0 ? 1 : 0) }
        }
        return (lit, frame.width * frame.height)
    }
    #endif

    // MARK: - Input

    /// `points` are normalized in the touch canvas. `windowPoints` are the same fingers in window
    /// coordinates: the first one on the picture is the pointer, for a core with a touch screen.
    func setTouches(_ points: [CGPoint], windowPoints: [CGPoint] = []) {
        touchMask = skins.setTouches(points)
        pointer = nil
        if let view = pictureView, !windowPoints.isEmpty, view.bounds.width > 0 {
            // The renderer places screens in pixels, so Whole Pixels lands the same for a finger.
            let scale = (view as? MTKView).map { $0.drawableSize.width / view.bounds.width } ?? view.traitCollection.displayScale
            let placements = renderer.placements(canvas: CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale))
            pointer = windowPoints.lazy.compactMap { point -> (x: Int16, y: Int16)? in
                let local = view.convert(point, from: nil)
                return ScreenLayout.pointer(at: CGPoint(x: local.x * scale, y: local.y * scale), placements: placements)
            }.first
        }
        pushInputs()
    }

    func clearTouches() {
        skins.releaseAll()
        touchMask = 0
        pointer = nil
        pushInputs()
    }

    /// libretro's pointer scale, -32767 to 32767 across the frame as the renderer fits it whole in `bounds`.
    /// Nil off the picture, in the letterbox.
    static func libretroPointer(_ point: CGPoint, bounds: CGSize, content: CGSize) -> (x: Int16, y: Int16)? {
        ScreenLayout.pointer(at: point, placements: ScreenLayout.placements(frame: content, canvas: bounds, platformID: "",
                                                                            settings: ScreenSettings()))
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

    /// The touch controls stay on with a controller connected, when the player chose that.
    var touchWithController = false
    /// Touch input reaches player 1: no controller has taken it, or the player keeps both.
    var touchActive: Bool { controllers.touchOwnsPlayerOne || touchWithController }
    private var accessibilityActions: Set<ControlAction> = []
    private var accessibilityStick: (right: Bool, x: Int16, y: Int16)?

    /// VoiceOver's activate on an app, turbo or macro element: a short press, so presses and toggles act once.
    func tapActionForAccessibility(_ action: ControlAction) {
        accessibilityActions.insert(action)
        pushInputs()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self else { return }
            self.accessibilityActions.remove(action)
            self.pushInputs()
        }
    }

    /// VoiceOver's named stick actions push the stick fully one way for half a second.
    func pushStickForAccessibility(right: Bool, x: Int16, y: Int16) {
        accessibilityStick = (right, x, y)
        pushInputs()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            self.accessibilityStick = nil
            self.pushInputs()
        }
    }

    /// Platforms whose core takes the hardware keyboard key by key (GagaInputState.keys).
    static let typingPlatforms: Set<String> = ["dos", "atari8bit", "c64", "amiga"]

    /// Players past the system's count get nothing, so a fifth pad or a two-player system's third does not reach
    /// a port the core never reads, or one it reads for something else.
    static func capped(_ states: [ControllerManager.InputState], maxPlayers: Int) -> [ControllerManager.InputState] {
        states.enumerated().map { $0.offset < max(maxPlayers, 1) ? $0.element : .zero }
    }

    /// Players and the multiplayer adapter for `mode` (Controls > Players). Applies from the next frame.
    func setMultitap(_ mode: MultitapMode) {
        let coreID = String(cString: interface.core_id)
        maxPlayers = CoreCatalog.maxPlayers(game.platformID, coreID: coreID, multitap: mode)
        multitapAlwaysOn = mode == .on && CoreCatalog.multitap["\(game.platformID):\(coreID)"] != nil
    }

    /// Ports in use, the core's player_count: up to the highest player with a controller (touch is player 1), or every
    /// port with Multitap On. A core with a multiplayer adapter plugs it in past its own ports.
    static func portCount(highestSlot: Int?, maxPlayers: Int, multitapOn: Bool) -> Int {
        let most = max(maxPlayers, 1)
        return multitapOn ? most : min(max((highestSlot ?? 0) + 1, 1), most)
    }

    private func pushInputs() {
        guard let core else { return }
        var states = Self.capped(controllers.sample(), maxPlayers: maxPlayers)
        if applyMenuHold(startHeld: states[0].buttons & ControllerManager.Button.start != 0,
                         seconds: { controllers.menuHoldSeconds() }, now: ProcessInfo.processInfo.systemUptime) {
            states[0].buttons &= ~ControllerManager.Button.start // The hold fired: release Start so it is not stuck.
        }
        if touchActive {
            states[0].buttons |= touchMask | accessibilityMask
            states[0].actions.formUnion(skins.heldActions.union(accessibilityActions))
            if let stick = accessibilityStick {
                if stick.right { states[0].rightX = stick.x; states[0].rightY = stick.y } else { states[0].leftX = stick.x; states[0].leftY = stick.y }
            }
            if states[0].leftX == 0, states[0].leftY == 0 { states[0].leftX = skins.analog.lx; states[0].leftY = skins.analog.ly }
            if states[0].rightX == 0, states[0].rightY == 0 { states[0].rightX = skins.analog.rx; states[0].rightY = skins.analog.ry }
        }
        // The keyboard plays as player 1 through its mapping. A DOS program reads the keys themselves, so with
        // pass-through on a computer core gets them as typed and the mapping does nothing.
        let held = controllers.keyboardHeld()
        let passThrough = Self.typingPlatforms.contains(game.platformID) && controllers.keyProfile().passThrough
        if !passThrough, !held.isEmpty {
            let keyboard = controllers.sampleKeyboard(held)
            states[0].buttons |= keyboard.buttons
            states[0].actions.formUnion(keyboard.actions)
        }
        // Each port's turbo and macros are its own (`wire`); app functions act from any player.
        var actions = states.map(\.actions)
        #if DEBUG
        if benchmarkScripted { actions = [] } // Device run 15: a menu opened mid-run. Core input only.
        #endif
        applyActions(perPort: actions)
        core.setPlayerCount(Self.portCount(highestSlot: controllers.devices.compactMap(\.slot).max(), maxPlayers: maxPlayers,
                                           multitapOn: multitapAlwaysOn))
        for (slot, state) in states.enumerated() {
            var input = GagaInputState(state)
            if slot == 0, passThrough {
                let keys = ControllerManager.keyBits(held)
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

    private var menuHold = MenuHold()

    /// Hold Menu (Start) opens the pause menu. Start reaches the core until the hold fires; true means keep it
    /// from the core until released. The benchmark is core input only, so it never holds.
    func applyMenuHold(startHeld: Bool, seconds: () -> Double, now: TimeInterval) -> Bool {
        #if DEBUG
        guard !benchmarkScripted else { return false }
        #endif
        let wait = startHeld && !menuHold.fired ? seconds() : 0
        let fire = menuHold.update(held: startHeld, seconds: wait, now: now)
        let withheld = menuHold.fired // Read before pause: it clears touches and pushes inputs, which samples again.
        if fire, phase == .running { pause(.menu) }
        return withheld
    }

    /// Opens the menu on the press, or closes it again, so holding the pair does not flicker.
    func menuPair(held: Bool) {
        defer { menuPairHeld = held }
        guard held, !menuPairHeld, phase == .running || phase == .paused else { return }
        #if DEBUG
        print("[gaga-input] menu \(menuOpen ? "closed" : "opened") by an app binding")
        #endif
        if menuOpen { resume(.menu) } else { pause(.menu) }
    }

    // MARK: - App actions

    /// Player 1's actions alone.
    func applyActions(_ actions: Set<ControlAction>) { applyActions(perPort: [actions]) }

    /// Acts on presses and releases of app functions, turbo and macros, from touch and controllers alike, one set per
    /// port. App functions act from any port; turbo and macros run on the port that pressed them.
    /// Holds follow the held set every time; one-shot functions fire on the press, and only while playing.
    func applyActions(perPort: [Set<ControlAction>]) {
        let apps = perPort.reduce(into: Set<ControlAction>()) { $0.formUnion($1.filter { $0.app != nil }) }
        let pressedApps = apps.subtracting(heldApps)
        heldApps = apps
        menuPair(held: apps.contains(.app(.pauseMenu)))
        updateRewinding(controllerHeld: apps.contains(.app(.rewindHold)))
        let ffHeld = apps.contains(.app(.fastForwardHold)) && phase == .running
        if ffHeld != fastForwardHeld {
            fastForwardHeld = ffHeld
            setFastForward(ffHeld ? fastForwardChoice : 1)
        }
        for case .app(let function) in pressedApps where phase == .running { perform(function) }
        for port in processors.indices {
            let actions: Set<ControlAction> = port < perPort.count ? perPort[port].filter { $0.app == nil } : []
            let pressed = actions.subtracting(heldActions[port])
            heldActions[port] = actions
            var turbo: UInt32 = 0
            for case .turbo(let mask, false) in actions { turbo |= mask }
            for action in pressed where phase == .running {
                switch action {
                case .turbo(let mask, true): toggledTurbo[port] ^= mask
                case .macro(let id): if let macro = macros().first(where: { $0.id == id }) { processors[port].toggle(macro) }
                default: break
                }
            }
            processors[port].setTurbo(turbo | toggledTurbo[port], hertz: turboHertz)
        }
        if turboToggled != toggledTurbo[0] { turboToggled = toggledTurbo[0] }
        let running = processors[0].runningMacros
        if running != runningMacros { runningMacros = running }
    }

    /// One-shot app functions. Holds and the menu are handled in `applyActions`.
    func perform(_ function: AppFunction) {
        switch function {
        case .quickSave: quickSave()
        case .quickLoad: quickLoad()
        case .fastForwardToggle: toggleFastForward()
        case .swapScreens: swapScreens()
        case .screenshot: takeScreenshot()
        case .mute: toggleMute()
        case .nextSlot: setQuickSlot(quickSlot + 1)
        case .previousSlot: setQuickSlot(quickSlot - 1)
        case .reset:
            core?.reset()
            achievements?.reset()
            show("Game reset.")
        case .pauseMenu, .fastForwardHold, .rewindHold: break // `applyActions` handles these.
        }
    }

    /// Wraps round the quick slots.
    func setQuickSlot(_ slot: Int) {
        let range = ControlsStore.quickSlots
        quickSlot = slot > range.upperBound ? range.lowerBound : slot < range.lowerBound ? range.upperBound : slot
        onQuickSlotChange?(quickSlot)
        show("Quick slot \(quickSlot).")
    }

    func quickSave() {
        guard let core, core.supportsSaveStates else { return show("This system cannot save states.") }
        let exists = saves.quickSlot(quickSlot) != nil
        let allowed = entitlements()
        guard exists || allowed.canAddSaveState(current: saves.manualCount) else {
            return show(SaveStateError.limitReached(allowed.maxSaveStates).localizedDescription)
        }
        do {
            let file = SaveStateFile.encode(payload: try core.saveState(), coreID: core.coreID, stateVersion: core.stateVersion)
            try saves.writeState(file, thumbnail: thumbnail(core), quick: quickSlot)
            show("Saved to quick slot \(quickSlot).")
        } catch {
            show(error.localizedDescription)
        }
    }

    func quickLoad() {
        guard let slot = saves.quickSlot(quickSlot) else { return show("Quick slot \(quickSlot) is empty.") }
        do {
            try loadState(slot)
            show("Loaded quick slot \(quickSlot).")
        } catch {
            show(error.localizedDescription)
        }
    }

    func toggleMute() {
        muted.toggle()
        audio.volume = muted ? 0 : 1
        show(muted ? "Sound off." : "Sound on.")
    }

    /// The picture as a PNG in Documents/Screenshots, which the Files app shows.
    func takeScreenshot() {
        guard let core, let png = thumbnail(core) else { return show("No picture to save yet.") }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Screenshots", isDirectory: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: "-")
        let name = game.title.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try AtomicFile.write(png, to: folder.appendingPathComponent("\(name) \(stamp).png"))
            show("Screenshot saved in Files.")
        } catch {
            show(error.localizedDescription)
        }
    }

    func show(_ line: String) {
        flash = line
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.flash == line { self?.flash = nil }
        }
    }

    /// Records player 1's buttons per frame until `stopRecordingMacro`.
    func startRecordingMacro() {
        processor.startRecording()
        recordingMacro = true
    }

    func stopRecordingMacro() {
        recordingMacro = false
        guard let frames = processor.stopRecording() else { return }
        let steps = Macro.steps(recorded: frames)
        guard !steps.isEmpty else { return show("Nothing was pressed, so no macro was saved.") }
        onMacroRecorded?(steps)
        show("Macro saved.")
    }

    // MARK: - Orientation

    /// Re-lays the game for the device's new orientation without touching the core: the touch layout and the screen
    /// settings change, and the picture views resize their drawables on their next layout pass.
    func setPortrait(_ upright: Bool) {
        guard upright != portrait else { return }
        portrait = upright
        skins.portrait = upright
        clearTouches()
        if let settings = screenForOrientation?(upright) {
            let save = onScreenChange
            onScreenChange = nil // Loaded, not chosen: nothing to save.
            screen = settings
            onScreenChange = save
        }
    }

    /// Controllers have no change callback worth trusting per button, so read them once per display frame.
    @objc private func tick() {
        pushInputs()
        let size = renderer.contentSize
        if size != frameSize { frameSize = size }
        #if DEBUG
        ticks += 1
        if ticks % 120 == 0 {
            let s = stats
            log.notice("stats frames=\(s.frames, privacy: .public) buttons=0x\(String(s.buttons, radix: 16), privacy: .public) video=\(s.videoWritten, privacy: .public) dropped=\(s.videoDropped, privacy: .public) audioIn=\(s.audioWritten, privacy: .public) audioOut=\(s.audioRendered, privacy: .public) engine=\(s.audioEngineRunning, privacy: .public)")
        }
        #endif
    }
}
