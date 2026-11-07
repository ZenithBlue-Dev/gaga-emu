/// Converts interleaved 16-bit PCM at a core's rate to stereo at the output rate, keeping pitch.
/// State carries across packets, so chunking does not change the result. Writer thread only.
/// shortcut: linear interpolation aliases near the input's Nyquist, swap for a windowed sinc if a core sounds harsh.
struct LinearResampler {
    var inputRate: Double
    let outputRate: Double
    /// Stream index 0 is the last frame of the previous packet; the new packet is 1...frames.
    private var last: (left: Int16, right: Int16) = (0, 0)
    private var position: Double = 0

    init(inputRate: Double, outputRate: Double) {
        self.inputRate = inputRate
        self.outputRate = outputRate
    }

    /// Appends interleaved stereo to `output`. Mono is duplicated; channels past the second are dropped.
    mutating func process(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int, into output: inout [Int16]) {
        guard frames > 0, channels > 0, inputRate > 0, outputRate > 0 else { return }
        let rightOffset = channels >= 2 ? 1 : 0
        let step = inputRate / outputRate

        while position < Double(frames) {
            let index = Int(position)
            let fraction = Float(position - Double(index))
            let a: (left: Int16, right: Int16) = index == 0
                ? last
                : (samples[(index - 1) * channels], samples[(index - 1) * channels + rightOffset])
            let bLeft = samples[index * channels]
            let bRight = samples[index * channels + rightOffset]
            output.append(Self.mix(a.left, bLeft, fraction))
            output.append(Self.mix(a.right, bRight, fraction))
            position += step
        }

        position -= Double(frames)
        last = (samples[(frames - 1) * channels], samples[(frames - 1) * channels + rightOffset])
    }

    mutating func reset() {
        last = (0, 0)
        position = 0
    }

    private static func mix(_ a: Int16, _ b: Int16, _ t: Float) -> Int16 {
        Int16((Float(a) + (Float(b) - Float(a)) * t).rounded())
    }
}
