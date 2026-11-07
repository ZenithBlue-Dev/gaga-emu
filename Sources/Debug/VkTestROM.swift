#if DEBUG
import Foundation

/// The file the layer-path test core (Cores/vktest/VkTestCore.c) loads: a magic and one flags byte.
/// What it draws is in the core: a 320 by 240 clear and one flat triangle the D-pad moves 2 pixels a frame.
enum VkTestROM {
    static let width = 320, height = 240
    /// Bytes as `read_layer_pixels` returns them: B, G, R, A.
    static let clearBGRA: [UInt8] = [128, 64, 0, 255]
    static let triangleBGRA: [UInt8] = [0, 64, 255, 255]
    static let stepPixels = 2

    struct Flags: OptionSet {
        let rawValue: UInt8
        /// The core offers no negotiation interface, so the adapter makes the device.
        static let noNegotiation = Flags(rawValue: 1)
        /// The core hands its command buffers to `set_command_buffers` instead of submitting them.
        static let frontendSubmit = Flags(rawValue: 2)
    }

    static func build(_ flags: Flags = []) -> Data { Data("GAGAVK1".utf8) + [flags.rawValue] }
}
#endif
