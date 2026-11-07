#if DEBUG
import Foundation

/// Generates a homebrew Atari Lynx program, so tests need no commercial game and no boot ROM. Hand-assembled 65C02
/// in the "BS93" homebrew format, which Handy loads straight into RAM; Handy tells formats apart by their bytes, so
/// the file is named `.lnx`. A retail-style `.lnx` needs a loader signed with Atari's key, which this does not use.
/// `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What the program does:
/// - Sets up the display timers and DMA the boot ROM would, over a framebuffer that RAM clearing leaves at zero, so
///   the whole picture is palette entry 0.
/// - Palette entry 0 is `color(joystick:)`, rewritten in a loop.
/// - Audio channel 0 plays a steady square tone (feedback tap 0, reload `toneBackup`, 1 MHz clock).
enum LynxTestROM {
    static let loadAddress = 0x0400
    static let toneBackup: UInt8 = 0x40

    /// (GREEN0, BLUERED0) for Suzy's JOYSTICK byte (active high: bit 0 A, 1 B, 4 Left, 5 Right, 6 Up, 7 Down).
    /// Directions set the green level; A raises blue and B raises red from a 5/5 base.
    static func color(joystick: UInt8) -> (green: UInt8, blueRed: UInt8) {
        (joystick >> 4, 0x55 | (joystick & 1 != 0 ? 0xA0 : 0) | (joystick & 2 != 0 ? 0x0A : 0))
    }

    static func build() -> Data {
        var code: [UInt8] = []
        func emit(_ bytes: UInt8...) { code += bytes }
        func store(_ value: UInt8, _ address: Int) { emit(0xA9, value, 0x8D, UInt8(address & 0xFF), UInt8(address >> 8)) }

        emit(0x78, 0xD8, 0xA2, 0xFF, 0x9A)  // sei; cld; ldx #$FF; txs
        emit(0x9C, 0xF9, 0xFF)              // stz MAPCTL: Suzy, Mikey, ROM and vectors visible
        store(158, 0xFD00); store(0x18, 0xFD01) // timer 0 (line): 159 us, reload and count, 1 MHz
        store(104, 0xFD08); store(0x1F, 0xFD09) // timer 2 (frame): 105 lines, linked to timer 0
        store(41, 0xFD93)                   // PBKUP
        store(0x00, 0xFD94); store(0xA0, 0xFD95) // DISPADR = $A000 (zeroed RAM)
        store(0x0D, 0xFD92)                 // DISPCTL: colour, 4 bits, DMA on
        store(0x7F, 0xFD20)                 // channel 0 volume
        store(0x01, 0xFD21)                 // feedback: tap bit 0
        store(0x01, 0xFD23)                 // shift register
        store(toneBackup, 0xFD24)           // reload
        store(0x18, 0xFD25)                 // reload and count, 1 MHz
        emit(0x9C, 0x50, 0xFD)              // stz MSTEREO: both sides on
        let loop = loadAddress + code.count
        emit(0xAD, 0xB0, 0xFC, 0xA8)        // lda JOYSTICK; tay
        emit(0x4A, 0x4A, 0x4A, 0x4A)        // lsr x4: directions to the low nibble
        emit(0x8D, 0xA0, 0xFD)              // sta GREEN0
        emit(0xA9, 0x55, 0x85, 0x00)        // lda #$55; sta $00
        emit(0x98, 0x29, 0x01, 0xF0, 0x06, 0xA5, 0x00, 0x09, 0xA0, 0x85, 0x00) // A held: $00 |= $A0
        emit(0x98, 0x29, 0x02, 0xF0, 0x06, 0xA5, 0x00, 0x09, 0x0A, 0x85, 0x00) // B held: $00 |= $0A
        emit(0xA5, 0x00, 0x8D, 0xB0, 0xFD)  // sta BLUERED0
        emit(0x4C, UInt8(loop & 0xFF), UInt8(loop >> 8)) // jmp loop

        // BS93 header. Handy copies the whole file to load - 10 and starts there: "bra +8" steps over the rest.
        let size = 10 + code.count
        let header: [UInt8] = [0x80, 0x08, UInt8(loadAddress >> 8), UInt8(loadAddress & 0xFF),
                               UInt8(size >> 8), UInt8(size & 0xFF)] + Array("BS93".utf8)
        return Data(header + code)
    }
}
#endif
