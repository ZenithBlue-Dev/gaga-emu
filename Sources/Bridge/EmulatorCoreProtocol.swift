import Foundation
import CoreGraphics
import QuartzCore

// MARK: - Core Errors

public enum EmulatorCoreError: LocalizedError {
    case instanceCreationFailed
    case abiMismatch(found: UInt32, expected: UInt32)
    case selfTestFailed(String)
    case romLoadFailed(String)
    case saveStateFailed(String)
    case loadStateFailed(String)
    case cheatRejected(String)
    case coreNotLoaded
    case invalidPixelFormat(UInt32)
    case invalidFrame(width: Int, height: Int, pitch: Int)

    public var errorDescription: String? {
        switch self {
        case .instanceCreationFailed:
            return "The emulator core could not start."
        case .abiMismatch(let found, let expected):
            return "This core was built for bridge version \(found), but the app needs version \(expected)."
        case .selfTestFailed(let reason):
            return reason
        case .romLoadFailed(let reason):
            return reason
        case .saveStateFailed(let reason):
            return reason
        case .loadStateFailed(let reason):
            return reason
        case .cheatRejected(let reason):
            return reason
        case .coreNotLoaded:
            return "No emulator core instance is currently loaded."
        case .invalidPixelFormat(let fmt):
            return "The core sent an unsupported pixel format (\(fmt))."
        case .invalidFrame(let width, let height, let pitch):
            return "The core sent an invalid frame (\(width) by \(height), pitch \(pitch))."
        }
    }
}

// MARK: - Video Frame Structure

/// `pixelData` is valid only during the callback.
public struct VideoFrame {
    public let pixelData: UnsafeRawPointer?
    public let width: Int
    public let height: Int
    public let pitch: Int
    public let pixelFormat: GagaPixelFormat
}

// MARK: - Audio Sample Packet

public struct AudioPacket {
    public let samples: [Int16]
    public let frames: Int
    public let sampleRate: UInt32
    public let channels: UInt8
}

// MARK: - Emulator Core Protocol

public protocol EmulatorCoreProtocol: AnyObject {
    var coreID: String { get }
    var name: String { get }
    var version: String { get }
    var supportedExtensions: [String] { get }
    var targetFPS: Double { get }
    var nativeSampleRate: UInt32 { get }
    var isRunning: Bool { get }
    var isLoaded: Bool { get }

    func loadROM(path: String, data: Data?) async throws
    func reset()
    func start()
    func pause()
    func resume()
    func stop()
    func step(inputs: [GagaInputState])

    func setInput(player: Int, state: GagaInputState)
    func saveState() throws -> Data
    func loadState(_ state: Data) throws
    func flushBatterySave()
    func addCheat(id: UInt32, code: String, enabled: Bool) throws
    func removeCheat(id: UInt32)
    func setCheat(id: UInt32, enabled: Bool)
    func setSpeed(_ multiplier: Int)
    var usesMetalLayer: Bool { get }
    func attachMetalLayer(_ layer: CAMetalLayer, width: Int, height: Int, scale: CGFloat) -> Bool
    func detachMetalLayer()
    func readLayerPixels() -> (pixels: Data, width: Int, height: Int)?

    var onVideoFrame: ((VideoFrame) -> Void)? { get set }
    var onAudioPacket: ((AudioPacket) -> Void)? { get set }
}

// MARK: - GagaCoreWrapper Implementation

/// Owns one core instance. Every call into the core runs on `executionQueue`, so `executionQueue.sync`
/// is a barrier: when it returns, no frame is in flight. Control methods are for one thread at a time
/// (the main actor in the app) and must never run on `executionQueue`, or the barrier deadlocks.
///
/// Lifetime: callbacks hold this object unretained. They fire only on the queue during a core call, and
/// every block on the queue retains `self`, so `self` outlives them. `stop` is the normal teardown; the
/// frame timer retains `self` until then.
public final class GagaCoreWrapper: EmulatorCoreProtocol {
    public typealias Event = (severity: GagaEventSeverity, code: Int32, message: String)

    private let coreInterface: GagaCoreInterface
    private var instance: OpaquePointer?
    private let systemDirectory: String
    private let saveDirectory: String

    public private(set) var isRunning: Bool = false
    public private(set) var isLoaded: Bool = false

    /// Set these before `start`. All three run on `executionQueue`.
    public var onVideoFrame: ((VideoFrame) -> Void)?
    public var onAudioPacket: ((AudioPacket) -> Void)?
    public var onEvent: ((Event) -> Void)?
    /// Last chance to change player 1's input for this frame (TriggerPro). Gets the frame number.
    public var playerOneFilter: ((GagaInputState, Int) -> GagaInputState)?
    /// Play Nearby (`Sources/Netplay`). Queue only: set it inside `betweenFrames`. Gets player 1's input for the
    /// next frame and returns every port's input for it, or nil to hold the frame until the other phone's
    /// input arrives. While set, each tick runs one frame: no fast-forward, no rewind.
    var lockstep: ((GagaInputState) -> [GagaInputState]?)?
    #if DEBUG
    /// Benchmark timing for each timed frame: start time, wall time and this thread's CPU time, in ns.
    public var onFrameTimed: ((UInt64, UInt64, UInt64) -> Void)?
    #endif

    private let inputLock = NSLock()
    private var playerInputs: [GagaInputState] = Array(repeating: GagaInputState(), count: 4)
    private var framesStepped = 0
    private var lastButtons: UInt32 = 0

    private let executionQueue = DispatchQueue(label: "com.zenithblue.gagaemu.core.execution", qos: .userInteractive)
    private var frameTimer: DispatchSourceTimer?
    private var hasPaused = false
    private var speed = 1 // Guarded by inputLock.
    // Queue only.
    private var stepping = false
    private var lastFatalMessage: String?
    private var presentVideo = true
    private var playAudio = true
    /// Queue only. Present while rewind is on and the core has not been ruled out.
    private var rewindTrack: RewindTrack?
    private var rewindHeld = false // Guarded by inputLock.
    /// Called once on the queue: nil when rewind works on this core, otherwise why it does not.
    public var onRewindVerdict: ((String?) -> Void)?

    private final class RewindTrack {
        let policy: RewindPolicy
        let buffer: RewindBuffer
        var state = Data() // Save and load scratch, as large as the largest state so far.
        var samples: [UInt64] = []
        var decided = false
        var frames = 0

        init(policy: RewindPolicy) {
            self.policy = policy
            buffer = RewindBuffer(budget: policy.budgetBytes)
        }
    }

    // MARK: - Metadata Accessors

    public var coreID: String {
        return String(cString: coreInterface.core_id)
    }

    public var name: String {
        return String(cString: coreInterface.core_name)
    }

    public var version: String {
        return String(cString: coreInterface.core_version)
    }

    public var supportedExtensions: [String] {
        let raw = String(cString: coreInterface.supported_extensions)
        return raw.split(separator: "|").map { String($0) }
    }

    public var targetFPS: Double {
        return coreInterface.target_fps > 0 ? coreInterface.target_fps : 60.0
    }

    public var nativeSampleRate: UInt32 {
        return coreInterface.native_sample_rate > 0 ? coreInterface.native_sample_rate : 44100
    }

    public var stateVersion: UInt32 { coreInterface.state_version }
    public var supportsSaveStates: Bool { coreInterface.state_size != nil }
    public var supportsCheats: Bool { coreInterface.cheat_add != nil }

    /// Frames stepped so far and the player 1 buttons the core last saw, after any filter.
    public var stats: (frames: Int, buttons: UInt32) {
        inputLock.lock()
        defer { inputLock.unlock() }
        return (framesStepped, lastButtons)
    }

    // MARK: - Initialization

    private static var baseDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GagaEmu")
    }

    /// The folder every core gets as `system_dir`, and the one Settings > BIOS Files lists.
    public static var systemDirectory: URL {
        migrateBIOSFolder(base: baseDirectory)
    }

    /// Settings once listed `GagaEmu/BIOS` while cores read `GagaEmu/System`. Moves each file from the old
    /// folder into System. A name already in System is left where it is, so nothing is overwritten or lost,
    /// and the old folder goes only once it is empty.
    @discardableResult
    static func migrateBIOSFolder(base: URL) -> URL {
        let fileManager = FileManager.default
        let system = base.appendingPathComponent("System", isDirectory: true)
        let old = base.appendingPathComponent("BIOS", isDirectory: true)
        try? fileManager.createDirectory(at: system, withIntermediateDirectories: true)
        guard let names = try? fileManager.contentsOfDirectory(atPath: old.path) else { return system }
        for name in names where !fileManager.fileExists(atPath: system.appendingPathComponent(name).path) {
            try? fileManager.moveItem(at: old.appendingPathComponent(name), to: system.appendingPathComponent(name))
        }
        if (try? fileManager.contentsOfDirectory(atPath: old.path))?.isEmpty == true {
            try? fileManager.removeItem(at: old)
        }
        return system
    }

    /// One folder per game, named after the ROM file rather than a Library ID, so a save survives
    /// removing a game from the Library and adding it back. A disc set in its own folder under ROMs is keyed
    /// by folder too, as "Saves/Game 2/Game.cue", because two different sets may share a descriptor name.
    public static func saveDirectory(forROM romPath: String) -> String {
        let url = URL(fileURLWithPath: romPath), folder = url.deletingLastPathComponent()
        let saves = baseDirectory.appendingPathComponent("Saves")
        let base = folder.deletingLastPathComponent().lastPathComponent == "ROMs" ? saves.appendingPathComponent(folder.lastPathComponent) : saves
        return base.appendingPathComponent(url.lastPathComponent).path
    }

    /// Refuses a core with the wrong ABI or a failing self-test before creating anything.
    public init(interface: GagaCoreInterface, systemDirectory: String? = nil, saveDirectory: String? = nil) throws {
        guard interface.abi_version == GAGA_BRIDGE_ABI_VERSION else {
            throw EmulatorCoreError.abiMismatch(found: interface.abi_version, expected: GAGA_BRIDGE_ABI_VERSION)
        }
        if let selfTest = interface.self_test {
            var error = [CChar](repeating: 0, count: 256)
            guard selfTest(&error, error.count) else {
                let reason = String(cString: error)
                throw EmulatorCoreError.selfTestFailed(reason.isEmpty ? "The core failed its self-test." : reason)
            }
        }

        self.coreInterface = interface

        let fileManager = FileManager.default
        let baseDir = Self.baseDirectory

        self.systemDirectory = systemDirectory ?? Self.systemDirectory.path
        self.saveDirectory = saveDirectory ?? baseDir.appendingPathComponent("Saves").path

        try? fileManager.createDirectory(atPath: self.systemDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(atPath: self.saveDirectory, withIntermediateDirectories: true)

        try setupInstance()
    }

    deinit {
        // Nothing can be running: every queued block and the frame timer retain self.
        destroyInstance()
    }

    private func setupInstance() throws {
        guard let createFn = coreInterface.create else { throw EmulatorCoreError.instanceCreationFailed }

        let instPtr = self.systemDirectory.withCString { sysC in
            self.saveDirectory.withCString { saveC in
                createFn(sysC, saveC)
            }
        }

        guard let validInst = instPtr else { throw EmulatorCoreError.instanceCreationFailed }
        self.instance = validInst

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        coreInterface.set_video_callback(validInst, { rawFrame, userdata in
            guard let rawFrame = rawFrame, let userdata = userdata else { return }
            let wrapper = Unmanaged<GagaCoreWrapper>.fromOpaque(userdata).takeUnretainedValue()
            guard wrapper.presentVideo else { return }

            let frame = VideoFrame(
                pixelData: rawFrame.pointee.pixel_data,
                width: Int(rawFrame.pointee.width),
                height: Int(rawFrame.pointee.height),
                pitch: rawFrame.pointee.pitch,
                pixelFormat: GagaPixelFormat(rawValue: rawFrame.pointee.pixel_format)
            )
            wrapper.onVideoFrame?(frame)
        }, selfPtr)

        coreInterface.set_audio_callback(validInst, { rawAudio, userdata in
            guard let rawAudio = rawAudio, let userdata = userdata else { return }
            let wrapper = Unmanaged<GagaCoreWrapper>.fromOpaque(userdata).takeUnretainedValue()
            guard wrapper.playAudio else { return }

            let totalSamples = rawAudio.pointee.frames * Int(rawAudio.pointee.channels)
            var sampleArray: [Int16] = []
            if let pcm = rawAudio.pointee.pcm_samples, totalSamples > 0 {
                sampleArray = Array(UnsafeBufferPointer(start: pcm, count: totalSamples))
            }

            let packet = AudioPacket(
                samples: sampleArray,
                frames: rawAudio.pointee.frames,
                sampleRate: rawAudio.pointee.sample_rate,
                channels: rawAudio.pointee.channels
            )
            wrapper.onAudioPacket?(packet)
        }, selfPtr)

        coreInterface.set_event_callback?(validInst, { severity, code, message, userdata in
            guard let userdata = userdata else { return }
            let wrapper = Unmanaged<GagaCoreWrapper>.fromOpaque(userdata).takeUnretainedValue()
            let text = message.map { String(cString: $0) } ?? ""
            if severity == GAGA_EVENT_FATAL { wrapper.lastFatalMessage = text }
            wrapper.onEvent?((severity, code, text))
        }, selfPtr)
    }

    /// Clears the callbacks first: the wrapper may be in deinit, and a late callback must not reach it.
    private func destroyInstance() {
        guard let inst = instance else { return }
        coreInterface.set_video_callback(inst, nil, nil)
        coreInterface.set_audio_callback(inst, nil, nil)
        coreInterface.set_event_callback?(inst, nil, nil)
        coreInterface.destroy(inst)
        instance = nil
    }

    // MARK: - Lifecycle Controls

    public func loadROM(path: String, data: Data? = nil) async throws {
        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            executionQueue.async { [self] in
                guard let inst = instance, let loadFn = coreInterface.load_rom else {
                    continuation.resume(throwing: EmulatorCoreError.instanceCreationFailed)
                    return
                }
                lastFatalMessage = nil
                let ok: Bool
                if let data = data {
                    ok = data.withUnsafeBytes { rawBuffer in
                        path.withCString { pathC in
                            loadFn(inst, pathC, rawBuffer.baseAddress, rawBuffer.count)
                        }
                    }
                } else {
                    ok = path.withCString { pathC in
                        loadFn(inst, pathC, nil, 0)
                    }
                }
                continuation.resume(returning: ok)
            }
        }

        if !success {
            let reason = executionQueue.sync { lastFatalMessage }
            throw EmulatorCoreError.romLoadFailed(reason ?? "The core could not load this game file.")
        }

        isLoaded = true
    }

    public func reset() {
        executionQueue.sync {
            if let inst = instance { coreInterface.reset?(inst) }
        }
    }

    public func start() {
        guard isLoaded, !isRunning else { return }
        isRunning = true
        executionQueue.sync { stepping = true }

        // The timer holds its cadence from the deadline, so the rate does not drift, and a slow frame
        // merges missed fires rather than bursting to catch up.
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: executionQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / targetFPS, leeway: .milliseconds(1))
        timer.setEventHandler { [self] in tickFrame() }
        frameTimer = timer
        timer.resume()
    }

    /// Returns with no frame in flight.
    public func pause() {
        guard isRunning else { return }
        isRunning = false
        hasPaused = true
        frameTimer?.cancel()
        frameTimer = nil
        executionQueue.sync {
            stepping = false
            if let inst = instance {
                coreInterface.pause?(inst)
                coreInterface.flush_battery_save?(inst)
            }
        }
    }

    public func resume() {
        guard isLoaded, !isRunning, hasPaused else { return }
        executionQueue.sync {
            if let inst = instance { coreInterface.resume?(inst) }
        }
        start()
    }

    /// Stops and destroys the instance. Safe to call twice. The wrapper is finished afterwards.
    public func stop() {
        isRunning = false
        isLoaded = false
        frameTimer?.cancel()
        frameTimer = nil
        executionQueue.sync {
            stepping = false
            if let inst = instance { coreInterface.flush_battery_save?(inst) }
            destroyInstance()
            rewindTrack = nil
            onRewindVerdict = nil
            onVideoFrame = nil
            onAudioPacket = nil
            onEvent = nil
            playerOneFilter = nil
            lockstep = nil
            #if DEBUG
            onFrameTimed = nil
            #endif
        }
    }

    /// One frame on the queue, for tests and frame stepping. Not for use while the timer runs.
    public func step(inputs: [GagaInputState]) {
        executionQueue.sync {
            // After a fatal event the core may hold freed state (PPSSPP runs a null JIT after a failed boot).
            guard lastFatalMessage == nil, let inst = instance, let stepFn = coreInterface.step_frame else { return }
            presentVideo = true
            playAudio = true
            var inArray = inputs
            while inArray.count < 4 {
                inArray.append(GagaInputState())
            }
            recordRewind(inst)
            stepFn(inst, inArray, UInt32(min(inputs.count, 4)))
        }
    }

    /// Fast-forward runs `speed` whole frames per tick, so the timer's cadence and pausing stay the same.
    /// Only the last one is drawn, and audio is dropped until normal speed, so neither ring can back up.
    /// Held rewind replaces the tick with one step back.
    private func tickFrame() {
        guard stepping, lastFatalMessage == nil, let inst = instance, let stepFn = coreInterface.step_frame else { return }
        inputLock.lock()
        let steps = lockstep == nil ? speed : 1
        let back = rewindHeld && lockstep == nil
        inputLock.unlock()
        if back, rewindTrack?.decided == true {
            rewindOnce(inst, stepFn)
            return
        }
        playAudio = steps == 1
        for step in 1...steps {
            presentVideo = step == steps
            stepOnce(inst, stepFn)
        }
    }

    private typealias StepFunction = @convention(c) (OpaquePointer?, UnsafePointer<GagaInputState>?, UInt32) -> Void

    private func stepOnce(_ inst: OpaquePointer, _ stepFn: StepFunction, record: Bool = true) {
        inputLock.lock()
        var currentInputs = playerInputs
        let frame = framesStepped
        inputLock.unlock()

        if let filter = playerOneFilter { currentInputs[0] = filter(currentInputs[0], frame) }
        if let lockstep {
            guard let all = lockstep(currentInputs[0]) else { return } // Held: the other phone's input is not here yet.
            currentInputs = Array((all + currentInputs).prefix(4))
        } else if record {
            recordRewind(inst)
        }
        // A layer-path core presents itself, so it must hear which frames fast-forward drops.
        currentInputs[0].skip_present = !presentVideo
        #if DEBUG
        let wallStart = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let cpuStart = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        stepFn(inst, currentInputs, 4)
        onFrameTimed?(wallStart, clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - wallStart,
                      clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - cpuStart)
        #else
        stepFn(inst, currentInputs, 4)
        #endif

        inputLock.lock()
        framesStepped += 1
        lastButtons = currentInputs[0].buttons
        inputLock.unlock()
    }

    public func setInput(player: Int, state: GagaInputState) {
        guard player >= 0 && player < 4 else { return }
        inputLock.lock()
        playerInputs[player] = state
        inputLock.unlock()
    }

    /// `multiplier` whole frames per timer tick. Audio is dropped above 1.
    public func setSpeed(_ multiplier: Int) {
        inputLock.lock()
        speed = max(multiplier, 1)
        inputLock.unlock()
    }

    /// Runs `work` between frames.
    func betweenFrames<T>(_ work: () -> T) -> T { executionQueue.sync(execute: work) }

    // MARK: - Rewind

    /// Starts taking snapshots before frames. `onRewindVerdict` reports, after the first few, whether the
    /// core qualifies under `policy`; one that does not stops being snapshotted at once.
    func enableRewind(policy: RewindPolicy = .standard) {
        executionQueue.sync {
            guard coreInterface.state_size != nil, coreInterface.save_state != nil, coreInterface.load_state != nil else {
                onRewindVerdict?(policy.refusal(stateSize: 0, serializeNanos: 0))
                return
            }
            rewindTrack = RewindTrack(policy: policy)
        }
    }

    /// While held, each tick steps back one snapshot instead of forward, with no sound.
    public func setRewinding(_ held: Bool) {
        inputLock.lock()
        rewindHeld = held
        inputLock.unlock()
    }

    /// One step back on the queue, for tests. Not for use while the timer runs. False when nothing is left.
    @discardableResult
    public func stepBackward() -> Bool {
        executionQueue.sync {
            guard let inst = instance, let stepFn = coreInterface.step_frame else { return false }
            return rewindOnce(inst, stepFn)
        }
    }

    /// Snapshots held, for tests.
    var rewindSnapshotCount: Int { executionQueue.sync { rewindTrack?.buffer.count ?? 0 } }

    // Queue only. Takes the snapshot before the frame runs, so loading it and stepping redraws that frame.
    private func recordRewind(_ inst: OpaquePointer) {
        guard let track = rewindTrack else { return }
        track.frames += 1
        guard track.frames % max(track.policy.interval, 1) == 0 else { return }
        guard let sizeFn = coreInterface.state_size, let saveFn = coreInterface.save_state else { return }
        let size = sizeFn(inst)
        if let reason = track.policy.refusal(stateSize: size, serializeNanos: 0) { return endRewind(reason) }
        if track.state.count < size { track.state = Data(count: size) }
        let start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let saved = track.state.withUnsafeMutableBytes { saveFn(inst, $0.baseAddress, size) }
        let elapsed = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start
        guard saved else { return endRewind("This core could not save its state, so it cannot rewind.") }
        if !track.decided {
            track.samples.append(elapsed)
            guard track.samples.count >= track.policy.probeCount else {
                track.state.withUnsafeBytes { track.buffer.push(UnsafeRawBufferPointer(rebasing: $0.prefix(size))) }
                return
            }
            // The median, so one cold first save does not rule a core out.
            let median = track.samples.sorted()[track.samples.count / 2]
            if let reason = track.policy.refusal(stateSize: size, serializeNanos: median) { return endRewind(reason) }
            track.decided = true
            onRewindVerdict?(nil)
        }
        track.state.withUnsafeBytes { track.buffer.push(UnsafeRawBufferPointer(rebasing: $0.prefix(size))) }
    }

    // Queue only.
    private func endRewind(_ reason: String) {
        rewindTrack = nil
        onRewindVerdict?(reason)
    }

    // Queue only. Loads the newest snapshot and steps once from it, so the picture shows where play now is.
    @discardableResult
    private func rewindOnce(_ inst: OpaquePointer, _ stepFn: StepFunction) -> Bool {
        guard let track = rewindTrack, track.decided, let loadFn = coreInterface.load_state else { return false }
        guard let size = track.state.withUnsafeMutableBytes({ track.buffer.popLatest(into: $0) }) else { return false }
        guard track.state.withUnsafeBytes({ loadFn(inst, $0.baseAddress, size, nil, 0) }) else { return false }
        presentVideo = true
        playAudio = false
        stepOnce(inst, stepFn, record: false)
        return true
    }

    // MARK: - Save States

    /// The core's own state bytes, with no frame in flight. `SaveStateFile` wraps them for disk.
    public func saveState() throws -> Data {
        try executionQueue.sync { try captureState() }
    }

    // Queue only. Internal for Play Nearby's state checks, which run inside `lockstep`.
    func captureState() throws -> Data {
        guard let inst = instance, let sizeFn = coreInterface.state_size, let saveFn = coreInterface.save_state else {
            throw EmulatorCoreError.saveStateFailed("This core has no save states.")
        }
        let size = sizeFn(inst)
        var state = Data(count: size)
        let saved = size > 0 && state.withUnsafeMutableBytes { saveFn(inst, $0.baseAddress, size) }
        guard saved else { throw EmulatorCoreError.saveStateFailed("The core could not save its state.") }
        return state
    }

    /// A refused state leaves the game as it was. A core that fails partway through is put back from a
    /// snapshot taken first, so that promise does not rest on every core's own checks.
    public func loadState(_ state: Data) throws {
        try executionQueue.sync { try restoreState(state) }
    }

    // Queue only. Internal for Play Nearby's resync, which runs inside `lockstep`.
    func restoreState(_ state: Data) throws {
        guard let inst = instance, let loadFn = coreInterface.load_state else {
            throw EmulatorCoreError.loadStateFailed("This core has no save states.")
        }
        let snapshot = try? captureState()
        var error = [CChar](repeating: 0, count: 256)
        let loaded = state.withUnsafeBytes { loadFn(inst, $0.baseAddress, state.count, &error, error.count) }
        guard loaded else {
            _ = snapshot?.withUnsafeBytes { loadFn(inst, $0.baseAddress, $0.count, nil, 0) }
            let reason = String(cString: error)
            throw EmulatorCoreError.loadStateFailed(reason.isEmpty ? "The core could not load this save state." : reason)
        }
    }

    public func flushBatterySave() {
        executionQueue.sync {
            if let inst = instance { coreInterface.flush_battery_save?(inst) }
        }
    }

    // MARK: - Cheats & Metal Layer

    public func addCheat(id: UInt32, code: String, enabled: Bool) throws {
        try executionQueue.sync {
            guard let inst = instance, let addFn = coreInterface.cheat_add else {
                throw EmulatorCoreError.cheatRejected("This core has no cheats.")
            }
            var error = [CChar](repeating: 0, count: 256)
            guard addFn(inst, id, code, enabled, &error, error.count) else {
                let reason = String(cString: error)
                throw EmulatorCoreError.cheatRejected(reason.isEmpty ? "The core did not accept this code." : reason)
            }
        }
    }

    public func removeCheat(id: UInt32) {
        executionQueue.sync {
            if let inst = instance { coreInterface.cheat_remove?(inst, id) }
        }
    }

    public func setCheat(id: UInt32, enabled: Bool) {
        executionQueue.sync {
            if let inst = instance { coreInterface.cheat_set_enabled?(inst, id, enabled) }
        }
    }

    /// True for a layer-path core: it presents to a CAMetalLayer itself, so host shaders do not run.
    public var usesMetalLayer: Bool { coreInterface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue != 0 }

    /// Call again with the new size whenever the layer's drawable size changes. The layer must outlive
    /// the attachment: detach before releasing it.
    public func attachMetalLayer(_ layer: CAMetalLayer, width: Int, height: Int, scale: CGFloat) -> Bool {
        executionQueue.sync {
            guard let inst = instance, let attachFn = coreInterface.attach_metal_layer else { return false }
            return attachFn(inst, Unmanaged.passUnretained(layer).toOpaque(), UInt32(width), UInt32(height), Float(scale))
        }
    }

    /// The output-texture path (docs/05 section 2.4): the core renders off-screen and sends each frame as a
    /// `GAGA_PIXEL_FORMAT_METAL_TEXTURE` frame, so host shaders run. Ended by `detachMetalLayer`.
    public func attachOutputTexture() -> Bool {
        executionQueue.sync {
            guard let inst = instance, coreInterface.capabilities & GAGA_CORE_CAP_OUTPUT_TEXTURE.rawValue != 0,
                  let attachFn = coreInterface.attach_metal_layer else { return false }
            return attachFn(inst, nil, 1, 1, 1)
        }
    }

    public func detachMetalLayer() {
        executionQueue.sync {
            if let inst = instance { coreInterface.detach_metal_layer?(inst) }
        }
    }

    /// The frame a layer-path core last presented, as BGRA8 rows of `width * 4` bytes.
    public func readLayerPixels() -> (pixels: Data, width: Int, height: Int)? {
        executionQueue.sync {
            guard let inst = instance, let readFn = coreInterface.read_layer_pixels else { return nil }
            var width: UInt32 = 0, height: UInt32 = 0
            _ = readFn(inst, nil, 0, &width, &height) // Asks the size.
            guard width > 0, height > 0 else { return nil }
            var pixels = Data(count: Int(width) * Int(height) * 4)
            let read = pixels.withUnsafeMutableBytes { readFn(inst, $0.baseAddress, $0.count, &width, &height) }
            return read ? (pixels, Int(width), Int(height)) : nil
        }
    }
}
