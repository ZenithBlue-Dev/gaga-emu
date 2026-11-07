#if DEBUG
import Foundation

/// Generates homebrew programs for Atari800, so tests need no commercial game and no Atari ROM: Atari800 boots
/// them on its bundled AltirraOS. Hand-assembled 6502. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// Both programs turn off ANTIC DMA and NMIs, so the whole picture is the background colour (COLBK), and play a
/// steady pure tone on POKEY channel 1 (AUDC1 $AF, AUDF1 `toneDivider`).
/// - `xex()`: an 8-bit binary load file. COLBK is `color(porta:trigger:)` from joystick 1, rewritten in a loop;
///   while a key is down it is the key's KBCODE instead.
/// - `a52()`: a 32 KB 5200 cartridge. Once a frame it reads the analog stick (POT0, POT1) and the lower button
///   (TRIG0) and writes COLBK = `color5200(x:y:trigger:)`.
enum Atari800TestROM {
    static let toneDivider: UInt8 = 31

    /// COLBK for PORTA's low nibble (active low: bit 0 Up, 1 Down, 2 Left, 3 Right) and TRIG0 (0 when held).
    static func color(porta: UInt8, trigger: Bool) -> UInt8 {
        ((porta & 0x0F) ^ 0x0F) << 4 | 0x04 | (trigger ? 0x0A : 0)
    }

    /// COLBK for a 5200 stick read as three zones per axis (0 low, 1 centre, 2 high).
    static func color5200(x: Int, y: Int, trigger: Bool) -> UInt8 {
        UInt8((x * 3 + y) << 4) | 0x04 | (trigger ? 0x0A : 0)
    }

    static func xex() -> Data {
        let start = 0x2000
        var code: [UInt8] = [
            0x78,                                     // sei
            0xA9, 0x00, 0x8D, 0x0E, 0xD4,             // NMIEN = 0
            0x8D, 0x00, 0xD4,                         // DMACTL = 0
            0x8D, 0x08, 0xD2,                         // AUDCTL = 0
            0xA9, 0x03, 0x8D, 0x0F, 0xD2,             // SKCTL = 3
            0xA9, toneDivider, 0x8D, 0x00, 0xD2,      // AUDF1
            0xA9, 0xAF, 0x8D, 0x01, 0xD2,             // AUDC1 = $AF: pure tone, volume 15
        ]
        let loop = start + code.count
        code += [
            0xAD, 0x00, 0xD3, 0x29, 0x0F, 0x49, 0x0F, // lda PORTA; and #$0F; eor #$0F
            0x0A, 0x0A, 0x0A, 0x0A, 0x09, 0x04,       // asl x4; ora #4
            0xAE, 0x10, 0xD0, 0xD0, 0x02, 0x09, 0x0A, // ldx TRIG0; bne +2; ora #$0A
            0xA8, 0xAD, 0x0F, 0xD2, 0x29, 0x04,       // tay; lda SKSTAT; and #4 (0 while a key is down)
            0xD0, 0x03, 0xAC, 0x09, 0xD2, 0x98,       // bne +3; ldy KBCODE; tya
            0x8D, 0x1A, 0xD0,                         // sta COLBK
            0x4C, UInt8(loop & 0xFF), UInt8(loop >> 8),
        ]
        let end = start + code.count - 1
        var file: [UInt8] = [0xFF, 0xFF, UInt8(start & 0xFF), UInt8(start >> 8), UInt8(end & 0xFF), UInt8(end >> 8)]
        file += code
        file += [0xE0, 0x02, 0xE1, 0x02, UInt8(start & 0xFF), UInt8(start >> 8)] // RUNAD
        return Data(file)
    }

    static func a52() -> Data {
        var rom = [UInt8](repeating: 0xFF, count: 0x8000) // $4000-$BFFF
        func zone(_ pot: UInt16, _ store: UInt8) -> [UInt8] { // three zones of a pot into zero page `store`
            [0xA2, 0x01, 0xAD, UInt8(pot & 0xFF), UInt8(pot >> 8), // ldx #1; lda pot
             0xC9, 0x40, 0xB0, 0x02, 0xA2, 0x00,                   // cmp #64; bcs +2; ldx #0
             0xC9, 0xA1, 0x90, 0x02, 0xA2, 0x02,                   // cmp #161; bcc +2; ldx #2
             0x86, store]                                          // stx store
        }
        var code: [UInt8] = [
            0x78, 0xD8, 0xA2, 0xFF, 0x9A,             // sei; cld; ldx #$FF; txs
            0xA9, 0x00, 0x8D, 0x0E, 0xD4,             // NMIEN = 0
            0x8D, 0x00, 0xD4,                         // DMACTL = 0
            0x8D, 0x08, 0xE8,                         // AUDCTL = 0
            0xA9, 0x04, 0x8D, 0x1F, 0xC0,             // CONSOL = 4: stick pots on
            0xA9, 0x03, 0x8D, 0x0F, 0xE8,             // SKCTL = 3
            0xA9, toneDivider, 0x8D, 0x00, 0xE8,      // AUDF1
            0xA9, 0xAF, 0x8D, 0x01, 0xE8,             // AUDC1 = $AF
            0x8D, 0x0B, 0xE8,                         // POTGO
        ]
        let loop = 0x4000 + code.count
        code += zone(0xE800, 0x80) + zone(0xE801, 0x81)
        code += [
            0xA5, 0x80, 0x0A, 0x65, 0x80, 0x65, 0x81, // x * 3 + y
            0x0A, 0x0A, 0x0A, 0x0A, 0x09, 0x04,       // asl x4; ora #4
            0xAE, 0x10, 0xC0, 0xD0, 0x02, 0x09, 0x0A, // ldx TRIG0; bne +2; ora #$0A
            0x8D, 0x1A, 0xC0,                         // sta COLBK
            0x8D, 0x0B, 0xE8,                         // POTGO: next scan
            0xAD, 0x0B, 0xD4, 0xC9, 0x64, 0xD0, 0xF9, // wait: lda VCOUNT; cmp #100; bne wait
            0xAD, 0x0B, 0xD4, 0xC9, 0x64, 0xF0, 0xF9, // wait while VCOUNT = 100
            0x4C, UInt8(loop & 0xFF), UInt8(loop >> 8),
        ]
        rom.replaceSubrange(0..<code.count, with: code)
        rom.replaceSubrange(0x7FFD..<0x8000, with: [0xFF, 0x00, 0x40]) // skip the title screen; start at $4000
        return Data(rom)
    }
}
#endif
