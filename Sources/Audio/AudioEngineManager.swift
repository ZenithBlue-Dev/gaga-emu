import Foundation
import AVFoundation
import os

/// Core audio arrives on the emulation queue, is resampled to the output rate, and waits in a ring
/// that the engine's render thread drains. Control methods run on the main actor.
public final class AudioEngineManager: ObservableObject {
    public static let shared = AudioEngineManager()

    private let engine = AVAudioEngine()
    private let timePitchUnit = AVAudioUnitTimePitch()
    private var sourceNode: AVAudioSourceNode!
    private var configurationObserver: NSObjectProtocol?
    private let sessionQueue = DispatchQueue(label: "com.zenithblue.gagaemu.audio.session", qos: .userInitiated)

    private let outputFormat: AVAudioFormat

    @Published public private(set) var isRunning: Bool = false
    @Published public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    @Published public var playbackSpeed: Float = 1.0 {
        didSet {
            timePitchUnit.rate = max(0.25, min(playbackSpeed, 4.0))
            updateBypass()
        }
    }

    @Published public var pitchShift: Float = 0.0 {
        didSet {
            timePitchUnit.pitch = pitchShift // Cents (-2400 to 2400)
            updateBypass()
        }
    }

    // Ring of interleaved stereo, guarded by `lock`: held only for a copy, because the render thread takes it.
    private let ringCapacity = 8192 // In frames, about 170 ms at 48 kHz. A longer backlog drops the oldest.
    private let primeFrames = 2048  // After running dry, wait for this much, so playback does not stutter.
    private let ring: UnsafeMutablePointer<Int16>
    private var readIndex: Int = 0
    private var availableFrames: Int = 0
    private var primed = false
    private var writtenFrames = 0
    private var renderedFrames = 0
    private var underruns = 0
    private let lock = OSAllocatedUnfairLock()

    // Emulation queue only, or while it is stopped.
    private var resampler: LinearResampler
    private var scratch: [Int16] = []

    public var outputSampleRate: Double { outputFormat.sampleRate }

    /// Frames accepted after resampling, frames played, times playback ran dry, and whether the engine is running.
    public var stats: (written: Int, rendered: Int, underruns: Int, engineRunning: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (writtenFrames, renderedFrames, underruns, engine.isRunning)
    }

    public init(outputSampleRate: Double = 48000.0) {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: outputSampleRate, channels: 2)!
        self.outputFormat = fmt
        self.ring = UnsafeMutablePointer<Int16>.allocate(capacity: ringCapacity * 2)
        self.ring.initialize(repeating: 0, count: ringCapacity * 2)
        self.resampler = LinearResampler(inputRate: outputSampleRate, outputRate: outputSampleRate)

        setupEngine()
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        engine.stop()
        ring.deallocate()
    }

    private func setupEngine() {
        sourceNode = AVAudioSourceNode(format: outputFormat) { [unowned self] _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            self.render(left: left, right: right, frames: Int(frameCount))
            return noErr
        }

        engine.attach(sourceNode)
        engine.attach(timePitchUnit)
        engine.connect(sourceNode, to: timePitchUnit, format: outputFormat)
        engine.connect(timePitchUnit, to: engine.mainMixerNode, format: outputFormat)
        updateBypass()

        // A route change stops the engine.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            try? self.engine.start()
        }
    }

    /// The time-pitch unit adds latency, so it stays out of the path at normal speed.
    private func updateBypass() {
        timePitchUnit.bypass = playbackSpeed == 1.0 && pitchShift == 0.0
    }

    /// `ambient` obeys the silent switch. `playback` plays through it.
    static func sessionCategory(respectSilentMode: Bool) -> AVAudioSession.Category {
        respectSilentMode ? .ambient : .playback
    }

    /// Waits for any deactivation still queued, so a quick relaunch cannot be switched off by the last stop.
    private func configureAudioSession(respectSilentMode: Bool) {
        sessionQueue.sync {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(Self.sessionCategory(respectSilentMode: respectSilentMode), mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
            } catch {
                print("Failed to configure AVAudioSession: \(error)")
            }
        }
    }

    /// A failure here leaves the game running without sound.
    public func start(respectSilentMode: Bool = false) {
        guard !isRunning else { return }
        configureAudioSession(respectSilentMode: respectSilentMode)
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }

    public func pause() {
        guard isRunning else { return }
        isRunning = false
        engine.pause()
        reset()
    }

    public func stop() {
        isRunning = false
        engine.stop()
        reset()
        // Deactivating can take a moment, and the player is waiting on the Library.
        sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Call only while the emulation queue is not writing.
    public func reset() {
        resampler.reset()
        lock.lock()
        readIndex = 0
        availableFrames = 0
        primed = false
        lock.unlock()
    }

    // MARK: - Ingestion from Core Interpreter

    public func writeAudioPacket(_ packet: AudioPacket) {
        if packet.sampleRate > 0 { resampler.inputRate = Double(packet.sampleRate) }
        packet.samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                writeSamples(base, frames: packet.frames, channels: Int(packet.channels))
            }
        }
    }

    public func writeSamples(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int) {
        scratch.removeAll(keepingCapacity: true)
        resampler.process(samples, frames: frames, channels: channels, into: &scratch)
        let count = scratch.count / 2
        guard count > 0 else { return }

        lock.lock()
        defer { lock.unlock() }
        scratch.withUnsafeBufferPointer { source in
            // Only the newest frames fit when the packet is larger than the ring.
            let skip = max(count - ringCapacity, 0)
            var writeIndex = (readIndex + availableFrames) % ringCapacity
            for frame in skip..<count {
                ring[writeIndex * 2] = source[frame * 2]
                ring[writeIndex * 2 + 1] = source[frame * 2 + 1]
                writeIndex = (writeIndex + 1) % ringCapacity
            }
            let kept = count - skip
            let overflow = max(availableFrames + kept - ringCapacity, 0)
            readIndex = (readIndex + overflow) % ringCapacity
            availableFrames += kept - overflow
        }
        writtenFrames += count
    }

    // MARK: - Render Thread

    /// shortcut: no rate control, so clock drift shows as a rare dropped or re-primed moment; nudge the resampler ratio if it is audible on a device.
    func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        lock.lock()
        defer { lock.unlock() }

        if !primed && availableFrames >= primeFrames { primed = true }
        let count = primed ? min(availableFrames, frames) : 0
        for i in 0..<count {
            left[i] = Float(ring[readIndex * 2]) / 32768.0
            right[i] = Float(ring[readIndex * 2 + 1]) / 32768.0
            readIndex = (readIndex + 1) % ringCapacity
        }
        availableFrames -= count
        renderedFrames += count

        if count < frames {
            (left + count).update(repeating: 0, count: frames - count)
            (right + count).update(repeating: 0, count: frames - count)
            if primed { underruns += 1 }
            primed = false
        }
    }
}
