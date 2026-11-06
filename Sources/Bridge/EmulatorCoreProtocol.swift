import Foundation
import Combine
import CoreGraphics

// MARK: - Core Errors

public enum EmulatorCoreError: LocalizedError {
    case instanceCreationFailed
    case romLoadFailed(String)
    case saveStateFailed(String)
    case loadStateFailed(String)
    case coreNotLoaded
    case invalidPixelFormat(UInt32)

    public var errorDescription: String? {
        switch self {
        case .instanceCreationFailed:
            return "Failed to allocate emulator core instance."
        case .romLoadFailed(let path):
            return "Failed to load ROM at \(path)."
        case .saveStateFailed(let path):
            return "Failed to save state to \(path)."
        case .loadStateFailed(let path):
            return "Failed to load state from \(path)."
        case .coreNotLoaded:
            return "No emulator core instance is currently loaded."
        case .invalidPixelFormat(let fmt):
            return "Unsupported pixel format ID: \(fmt)."
        }
    }
}

// MARK: - Video Frame Structure

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
    func stop()
    func step(inputs: [GagaInputState])

    func setInput(player: Int, state: GagaInputState)
    func saveState(to path: String) async throws
    func loadState(from path: String) async throws
    func applyCheat(index: UInt32, enabled: Bool, code: String)
    func attachMetalLayer(_ caMetalLayer: UnsafeMutableRawPointer) -> Bool

    var onVideoFrame: ((VideoFrame) -> Void)? { get set }
    var onAudioPacket: ((AudioPacket) -> Void)? { get set }
}

// MARK: - GagaCoreWrapper Implementation

public final class GagaCoreWrapper: ObservableObject, EmulatorCoreProtocol {
    private let coreInterface: GagaCoreInterface
    private var instance: OpaquePointer?
    private let systemDirectory: String
    private let saveDirectory: String

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isLoaded: Bool = false

    public var onVideoFrame: ((VideoFrame) -> Void)?
    public var onAudioPacket: ((AudioPacket) -> Void)?

    private var playerInputs: [GagaInputState] = Array(repeating: GagaInputState(), count: 4)
    private let inputLock = NSLock()

    private let executionQueue = DispatchQueue(label: "com.zenithblue.gagaemu.core.execution", qos: .userInteractive)
    private var frameTimer: DispatchSourceTimer?
    private var isStepping: Bool = false

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

    // MARK: - Initialization

    public init(interface: GagaCoreInterface, systemDirectory: String? = nil, saveDirectory: String? = nil) {
        self.coreInterface = interface

        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("GagaEmu")

        self.systemDirectory = systemDirectory ?? baseDir.appendingPathComponent("System").path
        self.saveDirectory = saveDirectory ?? baseDir.appendingPathComponent("Saves").path

        try? fileManager.createDirectory(atPath: self.systemDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(atPath: self.saveDirectory, withIntermediateDirectories: true)

        setupInstance()
    }

    deinit {
        stop()
        if let inst = instance {
            coreInterface.destroy(inst)
            instance = nil
        }
    }

    private func setupInstance() {
        guard let createFn = coreInterface.create else { return }

        let instPtr = self.systemDirectory.withCString { sysC in
            self.saveDirectory.withCString { saveC in
                createFn(sysC, saveC)
            }
        }

        guard let validInst = instPtr else { return }
        self.instance = validInst

        // Register Video Callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        coreInterface.set_video_callback(validInst, { rawFrame, userdata in
            guard let rawFrame = rawFrame, let userdata = userdata else { return }
            let wrapper = Unmanaged<GagaCoreWrapper>.fromOpaque(userdata).takeUnretainedValue()

            let rawFmt = rawFrame.pointee.pixel_format
            let fmt = GagaPixelFormat(rawValue: rawFmt)
            let frame = VideoFrame(
                pixelData: rawFrame.pointee.pixel_data,
                width: Int(rawFrame.pointee.width),
                height: Int(rawFrame.pointee.height),
                pitch: rawFrame.pointee.pitch,
                pixelFormat: fmt
            )
            wrapper.onVideoFrame?(frame)
        }, selfPtr)

        // Register Audio Callback
        coreInterface.set_audio_callback(validInst, { rawAudio, userdata in
            guard let rawAudio = rawAudio, let userdata = userdata else { return }
            let wrapper = Unmanaged<GagaCoreWrapper>.fromOpaque(userdata).takeUnretainedValue()

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
    }

    // MARK: - Lifecycle Controls

    public func loadROM(path: String, data: Data? = nil) async throws {
        guard let inst = instance, let loadFn = coreInterface.load_rom else {
            throw EmulatorCoreError.instanceCreationFailed
        }

        let success: Bool
        if let data = data {
            success = data.withUnsafeBytes { rawBuffer in
                path.withCString { pathC in
                    loadFn(inst, pathC, rawBuffer.baseAddress, rawBuffer.count)
                }
            }
        } else {
            success = path.withCString { pathC in
                loadFn(inst, pathC, nil, 0)
            }
        }

        if !success {
            throw EmulatorCoreError.romLoadFailed(path)
        }

        await MainActor.run {
            self.isLoaded = true
        }
    }

    public func reset() {
        guard let inst = instance, let resetFn = coreInterface.reset else { return }
        executionQueue.sync {
            resetFn(inst)
        }
    }

    public func start() {
        guard isLoaded, !isRunning else { return }
        isRunning = true

        let interval = 1.0 / targetFPS
        let timer = DispatchSource.makeTimerSource(queue: executionQueue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.tickFrame()
        }
        self.frameTimer = timer
        timer.resume()
    }

    public func pause() {
        guard isRunning else { return }
        isRunning = false
        frameTimer?.cancel()
        frameTimer = nil
    }

    public func stop() {
        pause()
        isLoaded = false
    }

    public func step(inputs: [GagaInputState]) {
        guard let inst = instance, let stepFn = coreInterface.step_frame else { return }
        var inArray = inputs
        while inArray.count < 4 {
            inArray.append(GagaInputState())
        }
        stepFn(inst, &inArray, UInt32(min(inputs.count, 4)))
    }

    private func tickFrame() {
        guard isRunning, let inst = instance, let stepFn = coreInterface.step_frame else { return }
        var currentInputs: [GagaInputState]
        inputLock.lock()
        currentInputs = playerInputs
        inputLock.unlock()

        stepFn(inst, &currentInputs, 4)
    }

    public func setInput(player: Int, state: GagaInputState) {
        guard player >= 0 && player < 4 else { return }
        inputLock.lock()
        playerInputs[player] = state
        inputLock.unlock()
    }

private struct UncheckedInstance: @unchecked Sendable {
    let pointer: OpaquePointer
}

    // MARK: - Save States

    public func saveState(to path: String) async throws {
        guard let inst = instance, let saveFn = coreInterface.save_state_file else {
            throw EmulatorCoreError.coreNotLoaded
        }

        let sendableInst = UncheckedInstance(pointer: inst)
        let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            executionQueue.async {
                let ok = path.withCString { pathC in
                    saveFn(sendableInst.pointer, pathC)
                }
                continuation.resume(returning: ok)
            }
        }

        if !success {
            throw EmulatorCoreError.saveStateFailed(path)
        }
    }

    public func loadState(from path: String) async throws {
        guard let inst = instance, let loadFn = coreInterface.load_state_file else {
            throw EmulatorCoreError.coreNotLoaded
        }

        let sendableInst = UncheckedInstance(pointer: inst)
        let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            executionQueue.async {
                let ok = path.withCString { pathC in
                    loadFn(sendableInst.pointer, pathC)
                }
                continuation.resume(returning: ok)
            }
        }

        if !success {
            throw EmulatorCoreError.loadStateFailed(path)
        }
    }

    // MARK: - Cheats & Metal Layer

    public func applyCheat(index: UInt32, enabled: Bool, code: String) {
        guard let inst = instance, let cheatFn = coreInterface.apply_cheat else { return }
        code.withCString { codeC in
            cheatFn(inst, index, enabled, codeC)
        }
    }

    public func attachMetalLayer(_ caMetalLayer: UnsafeMutableRawPointer) -> Bool {
        guard let inst = instance, let attachFn = coreInterface.attach_metal_layer else { return false }
        return attachFn(inst, caMetalLayer)
    }
}
