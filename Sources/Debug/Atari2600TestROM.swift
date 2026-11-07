#if DEBUG
import Foundation

/// Generates a 4 KB homebrew Atari 2600 cartridge, so tests need no commercial game. Hand-assembled 6502
/// with a standard 262-line NTSC frame. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What the program does:
/// - The background colour (COLUBK) is `color(swcha:fire:)` from the left joystick, set in each VBLANK.
/// - Channel 0 plays a steady pure tone (AUDC0 4, AUDF0 `toneDivider`, full volume).
/// - Nothing else is drawn, so the whole picture is the background colour.
enum Atari2600TestROM {
    static let size = 0x1000
    static let toneDivider: UInt8 = 31

    /// COLUBK for SWCHA (active low: bit 4 Up, 5 Down, 6 Left, 7 Right) and the fire button. Hue 8 (blue) at rest;
    /// each direction makes its own hue, and fire raises the luminance.
    static func color(swcha: UInt8, fire: Bool) -> UInt8 {
        (((swcha & 0xF0) ^ 0x70) | 0x04) | (fire ? 0x0A : 0)
    }

    static func build() -> Data {
        var rom = [UInt8](repeating: 0xFF, count: size)
        var pc = 0
        func emit(_ bytes: UInt8...) { for b in bytes { rom[pc] = b; pc += 1 } }
        func lines(_ count: UInt8) { // ldx #count; loop: sta WSYNC; dex; bne loop
            emit(0xA2, count, 0x85, 0x02, 0xCA, 0xD0, 0xFB)
        }

        emit(0x78, 0xD8, 0xA2, 0x00, 0x8A)           // sei; cld; ldx #0; txa
        emit(0xCA, 0x9A, 0x48, 0xD0, 0xFB)           // clear: dex; txs; pha; bne clear (zero page, TIA and RAM)
        emit(0xA9, 0x04, 0x85, 0x15)                 // AUDC0 = 4: pure tone
        emit(0xA9, toneDivider, 0x85, 0x17)          // AUDF0
        emit(0xA9, 0x0F, 0x85, 0x19)                 // AUDV0 = 15
        let frame = 0xF000 + pc
        emit(0xA9, 0x02, 0x85, 0x01, 0x85, 0x00)     // VBLANK on, VSYNC on
        emit(0x85, 0x02, 0x85, 0x02, 0x85, 0x02)     // three lines of VSYNC
        emit(0xA9, 0x00, 0x85, 0x00)                 // VSYNC off
        lines(37)                                    // vertical blank
        emit(0xAD, 0x80, 0x02, 0x29, 0xF0, 0x49, 0x70, 0x09, 0x04) // lda SWCHA; and #$F0; eor #$70; ora #4
        emit(0xA4, 0x0C, 0x30, 0x02, 0x09, 0x0A)     // ldy INPT4; bmi +2; ora #$0A (fire held)
        emit(0x85, 0x09)                             // sta COLUBK
        emit(0xA9, 0x00, 0x85, 0x01)                 // VBLANK off
        lines(192)                                   // picture
        emit(0xA9, 0x02, 0x85, 0x01)                 // VBLANK on
        lines(30)                                    // overscan
        emit(0x4C, UInt8(frame & 0xFF), UInt8(frame >> 8)) // jmp frame
        // NMI, RESET and IRQ vectors all point at the start.
        rom.replaceSubrange((size - 6)..<size, with: [0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0])
        return Data(rom)
    }
}
#endif
