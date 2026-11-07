#if DEBUG
import Foundation

/// Generates a homebrew Atari 7800 cartridge: a 128-byte .a78 header and 32 KB of hand-assembled 6502 at $8000, so
/// tests need no commercial game and no BIOS. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What the program does:
/// - MARIA DMA runs over a display list list whose lists are all empty, so every line is the background colour.
/// - The background (BACKGRND) is `color(swcha:button1:button2:)` from the left joystick, rewritten in a loop.
/// - The TIA plays a steady pure tone on channel 0 (AUDC0 4, AUDF0 `toneDivider`, full volume).
/// - CTLSWB bit 2 is set, so the joystick is in two-button mode and both buttons read separately.
enum Atari7800TestROM {
    static let romSize = 0x8000
    static let toneDivider: UInt8 = 31

    /// BACKGRND for SWCHA (active low: bit 4 Up, 5 Down, 6 Left, 7 Right) and the two buttons. Grey at rest; each
    /// direction makes its own hue, and the buttons raise the luminance by different steps.
    static func color(swcha: UInt8, button1: Bool, button2: Bool) -> UInt8 {
        ((swcha & 0xF0) ^ 0xF0) | 0x04 | (button1 ? 0x02 : 0) | (button2 ? 0x08 : 0)
    }

    static func header() -> [UInt8] {
        var h = [UInt8](repeating: 0, count: 128)
        h[0] = 3
        h.replaceSubrange(1..<10, with: Array("ATARI7800".utf8))
        h.replaceSubrange(17..<26, with: Array("GAGA TEST".utf8))
        h.replaceSubrange(49..<53, with: [0x00, 0x00, UInt8(romSize >> 8), 0x00]) // size, big endian
        h[55] = 1 // left controller: joystick
        h[56] = 1 // right controller: joystick
        h[57] = 0 // NTSC
        h.replaceSubrange(100..<128, with: Array("ACTUAL CART DATA STARTS HERE".utf8))
        return h
    }

    static func build() -> Data {
        var rom = [UInt8](repeating: 0xFF, count: romSize)
        let dll = 0x8100, displayList = 0x8200, rti = 0x8300
        var pc = 0
        func emit(_ bytes: UInt8...) { for b in bytes { rom[pc] = b; pc += 1 } }

        emit(0x78, 0xD8, 0xA2, 0xFF, 0x9A)           // sei; cld; ldx #$FF; txs
        emit(0xA9, 0x07, 0x85, 0x01)                 // INPTCTRL = 7: lock 7800 mode
        emit(0xA9, 0x14, 0x8D, 0x83, 0x02)           // CTLSWB = $14: two-button joysticks
        emit(0xA9, UInt8(dll >> 8), 0x85, 0x2C)      // DPPH
        emit(0xA9, UInt8(dll & 0xFF), 0x85, 0x30)    // DPPL
        emit(0xA9, 0x40, 0x85, 0x3C)                 // CTRL = $40: DMA on, 160-wide mode
        emit(0xA9, 0x04, 0x85, 0x15)                 // AUDC0 = 4: pure tone
        emit(0xA9, toneDivider, 0x85, 0x17)          // AUDF0
        emit(0xA9, 0x0F, 0x85, 0x19)                 // AUDV0 = 15
        let loop = 0x8000 + pc
        emit(0xAD, 0x80, 0x02, 0x29, 0xF0, 0x49, 0xF0, 0x09, 0x04) // lda SWCHA; and #$F0; eor #$F0; ora #4
        emit(0xA4, 0x09, 0x10, 0x02, 0x09, 0x02)     // ldy INPT1; bpl +2; ora #2 (button 1 held)
        emit(0xA4, 0x08, 0x10, 0x02, 0x09, 0x08)     // ldy INPT0; bpl +2; ora #8 (button 2 held)
        emit(0x85, 0x20)                             // sta BACKGRND
        emit(0x4C, UInt8(loop & 0xFF), UInt8(loop >> 8)) // jmp loop

        // 20 zones of 16 lines, more than the 243-line display; each points at the same empty display list.
        for zone in 0..<20 {
            let at = dll - 0x8000 + zone * 3
            rom.replaceSubrange(at..<(at + 3), with: [0x0F, UInt8(displayList >> 8), UInt8(displayList & 0xFF)])
        }
        rom.replaceSubrange((displayList - 0x8000)..<(displayList - 0x8000 + 2), with: [0x00, 0x00]) // end of list
        rom[rti - 0x8000] = 0x40 // rti
        // NMI goes to the rti; RESET and IRQ to the start.
        rom.replaceSubrange((romSize - 6)..<romSize, with: [0x00, 0x83, 0x00, 0x80, 0x00, 0x80])
        return Data(header() + rom)
    }
}
#endif
