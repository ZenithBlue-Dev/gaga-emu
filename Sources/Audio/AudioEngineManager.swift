import Foundation
import AVFoundation

public final class AudioEngineManager: ObservableObject {
    public static let shared = AudioEngineManager()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchUnit = AVAudioUnitTimePitch()

    private let outputFormat: AVAudioFormat
    private var sourceSampleRate: Double = 44100.0

    @Published public private(set) var isRunning: Bool = false
    @Published public var volume: Float = 1.0 {
        didSet {
            playerNode.volume = volume
        }
    }

    @Published public var playbackSpeed: Float = 1.0 {
        didSet {
            timePitchUnit.rate = max(0.25, min(playbackSpeed, 4.0))
        }
    }

    @Published public var pitchShift: Float = 0.0 {
        didSet {
            timePitchUnit.pitch = pitchShift // Cents (-2400 to 2400)
        }
    }

    // Thread-safe ring buffer for incoming 16-bit stereo PCM
    private let ringCapacity = 65536 // In frames (1 frame = 2 samples for stereo)
    private var ringBuffer: [Int16]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var availableFrames: Int = 0
    private let bufferLock = NSLock()

    private let chunkFrames: Int = 1024
    private let audioQueue = DispatchQueue(label: "com.zenithblue.gagaemu.audio.scheduler", qos: .userInteractive)
    private var isScheduling: Bool = false

    public init(outputSampleRate: Double = 44100.0) {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: outputSampleRate, channels: 2)!
        self.outputFormat = fmt
        self.sourceSampleRate = outputSampleRate
        self.ringBuffer = [Int16](repeating: 0, count: ringCapacity * 2)

        setupEngine()
    }

    deinit {
        stop()
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitchUnit)

        engine.connect(playerNode, to: timePitchUnit, format: outputFormat)
        engine.connect(timePitchUnit, to: engine.mainMixerNode, format: outputFormat)

        configureAudioSession()
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .gameChat, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    public func start() {
        guard !isRunning else { return }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.play()
            isRunning = true
            isScheduling = true
            scheduleNextBuffers()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }

    public func pause() {
        guard isRunning else { return }
        isRunning = false
        isScheduling = false
        playerNode.pause()
    }

    public func stop() {
        isRunning = false
        isScheduling = false
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        reset()
    }

    public func reset() {
        bufferLock.lock()
        readIndex = 0
        writeIndex = 0
        availableFrames = 0
        bufferLock.unlock()
    }

    public func setSourceSampleRate(_ rate: UInt32) {
        if rate > 0 {
            self.sourceSampleRate = Double(rate)
        }
    }

    // MARK: - Ingestion from Core Interpreter

    public func writeAudioPacket(_ packet: AudioPacket) {
        setSourceSampleRate(packet.sampleRate)
        packet.samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                writeSamples(base, frames: packet.frames, channels: Int(packet.channels))
            }
        }
    }

    public func writeSamples(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int) {
        guard frames > 0 else { return }

        bufferLock.lock()
        defer { bufferLock.unlock() }

        for i in 0..<frames {
            let left: Int16
            let right: Int16

            if channels >= 2 {
                left = samples[i * channels + 0]
                right = samples[i * channels + 1]
            } else {
                left = samples[i]
                right = samples[i]
            }

            let writeOffset = (writeIndex % ringCapacity) * 2
            ringBuffer[writeOffset + 0] = left
            ringBuffer[writeOffset + 1] = right

            writeIndex = (writeIndex + 1) % ringCapacity

            if availableFrames < ringCapacity {
                availableFrames += 1
            } else {
                // Buffer overflow: drop oldest frame to maintain low latency
                readIndex = (readIndex + 1) % ringCapacity
            }
        }
    }

    // MARK: - Audio Scheduling Loop

    private func scheduleNextBuffers() {
        audioQueue.async { [weak self] in
            guard let self = self, self.isScheduling else { return }

            self.pumpAudio()

            // Re-schedule when running
            if self.isScheduling {
                self.audioQueue.asyncAfter(deadline: .now() + .milliseconds(15)) { [weak self] in
                    self?.scheduleNextBuffers()
                }
            }
        }
    }

    private func pumpAudio() {
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(chunkFrames)) else {
            return
        }
        pcmBuffer.frameLength = AVAudioFrameCount(chunkFrames)

        guard let channelData = pcmBuffer.floatChannelData else { return }
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]

        bufferLock.lock()
        let framesToRead = min(availableFrames, chunkFrames)
        let sampleRateRatio = sourceSampleRate / outputFormat.sampleRate

        if framesToRead > 0 {
            for i in 0..<chunkFrames {
                if i < framesToRead {
                    let offset = (readIndex % ringCapacity) * 2
                    let rawL = Float(ringBuffer[offset + 0]) / 32768.0
                    let rawR = Float(ringBuffer[offset + 1]) / 32768.0

                    leftChannel[i] = rawL
                    rightChannel[i] = rawR
                    readIndex = (readIndex + 1) % ringCapacity
                    availableFrames -= 1
                } else {
                    // Underrun pad with silence
                    leftChannel[i] = 0.0
                    rightChannel[i] = 0.0
                }
            }
        } else {
            // No samples available, fill with silence to prevent pop
            memset(leftChannel, 0, chunkFrames * MemoryLayout<Float>.size)
            memset(rightChannel, 0, chunkFrames * MemoryLayout<Float>.size)
        }
        bufferLock.unlock()

        _ = sampleRateRatio // preserved for variable resampler step

        playerNode.scheduleBuffer(pcmBuffer, at: nil, options: [])
    }
}
