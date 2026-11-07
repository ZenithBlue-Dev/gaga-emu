#if DEBUG
import Foundation

/// Generates a homebrew Commodore 64 cartridge (`.crt`, Ultimax mode), so tests need no commercial game. In Ultimax
/// mode the cartridge's 8 KB sits at $E000-$FFFF in place of the KERNAL and supplies the reset vector, so the
/// program runs without any Commodore code. Hand-assembled 6502. `scripts/make-test-rom.sh` writes the same bytes.
///
/// What the program does:
/// - Blanks the screen ($D011 = $0B), so the whole picture is the border colour ($D020).
/// - The border is `color(joystick:keyDown:)` from joystick port 2 and the keyboard matrix, rewritten in a loop.
/// - SID voice 1 plays a steady sawtooth.
///
/// VICE still loads its KERNAL, BASIC and character ROM files at start, so tests put `standInSystemFiles` (all
/// zeros, GagaEmu's own) in the system folder. They are never executed: the cartridge covers the KERNAL.
enum C64TestROM {
    /// File names VICE looks for (c64rom.h), with their sizes.
    static let standInSystemFiles: [(name: String, size: Int)] = [
        ("kernal-901227-03.bin", 0x2000), ("basic-901226-01.bin", 0x2000), ("chargen-901225-01.bin", 0x1000),
    ]

    /// Border colour index for the active-high joystick bits (0 Up, 1 Down, 2 Left, 3 Right, 4 Fire). A key held
    /// anywhere on the keyboard wins.
    static func color(joystick: UInt8, keyDown: Bool) -> UInt8 {
        keyDown ? 3 : table[Int(joystick & 0x1F)]
    }

    /// Dark grey at rest, then red, green, blue, yellow and white for one input each.
    private static let table: [UInt8] = (0..<32).map { [0: 11, 1: 2, 2: 5, 4: 6, 8: 7, 16: 1][$0] ?? 0 }

    static func crt() -> Data {
        var rom = [UInt8](repeating: 0xEA, count: 0x2000)
        let code: [UInt8] = [
            0x78, 0xD8, 0xA2, 0xFF, 0x9A,           // sei; cld; ldx #$ff; txs
            0xA9, 0x0B, 0x8D, 0x11, 0xD0,           // lda #$0b; sta $d011 (screen off)
            0xA9, 0xFF, 0x8D, 0x02, 0xDC,           // lda #$ff; sta $dc02 (CIA1 port A out)
            0xA9, 0x00, 0x8D, 0x03, 0xDC,           // lda #$00; sta $dc03 (port B in)
            0xA9, 0x0F, 0x8D, 0x18, 0xD4,           // volume 15
            0xA9, 0x00, 0x8D, 0x05, 0xD4,           // attack/decay 0
            0xA9, 0xF0, 0x8D, 0x06, 0xD4,           // sustain 15, release 0
            0xA9, 0xD6, 0x8D, 0x00, 0xD4,           // frequency $1cd6
            0xA9, 0x1C, 0x8D, 0x01, 0xD4,
            0xA9, 0x21, 0x8D, 0x04, 0xD4,           // sawtooth, gate
            // loop ($e032):
            0xA9, 0xFF, 0x8D, 0x00, 0xDC,           // lda #$ff; sta $dc00 (no column)
            0xAD, 0x00, 0xDC,                       // lda $dc00 (joystick 2, active low)
            0x49, 0xFF, 0x29, 0x1F, 0xAA,           // eor #$ff; and #$1f; tax
            0xBD, 0x60, 0xE0,                       // lda table,x
            0xA8,                                   // tay
            0xA9, 0x00, 0x8D, 0x00, 0xDC,           // lda #$00; sta $dc00 (every column)
            0xAD, 0x01, 0xDC,                       // lda $dc01 (rows)
            0xC9, 0xFF, 0xF0, 0x02,                 // cmp #$ff; beq +2
            0xA0, 0x03,                             // ldy #3 (a key is down)
            0x8C, 0x20, 0xD0,                       // sty $d020
            0x4C, 0x32, 0xE0,                       // jmp loop
            0x40,                                   // $e057: rti (NMI and IRQ)
        ]
        rom.replaceSubrange(0..<code.count, with: code)
        rom.replaceSubrange(0x60..<0x80, with: table)
        rom.replaceSubrange(0x1FFA..<0x2000, with: [0x57, 0xE0, 0x00, 0xE0, 0x57, 0xE0])

        var file = [UInt8]("C64 CARTRIDGE   ".utf8)
        file += [0, 0, 0, 0x40, 0x01, 0x00, 0x00, 0x00] // header length, version 1.0, type 0 (normal)
        file += [1, 0]                                   // EXROM high, GAME low: Ultimax
        file += [UInt8](repeating: 0, count: 6)
        file += [UInt8]("GAGAEMU TEST".utf8) + [UInt8](repeating: 0, count: 32 - 12)
        file += [UInt8]("CHIP".utf8) + [0, 0, 0x20, 0x10] // packet length $2010
        file += [0, 0, 0, 0, 0xE0, 0x00, 0x20, 0x00]     // ROM, bank 0, at $e000, $2000 bytes
        file += rom
        return Data(file)
    }
}
#endif
