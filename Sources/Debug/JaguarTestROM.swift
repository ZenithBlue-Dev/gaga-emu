#if DEBUG
import Foundation

/// Generates a homebrew Atari Jaguar cartridge: 128 KB, entry address at $800404, hand-assembled 68000 at $802000.
/// Tests need no commercial game and no boot ROM: Virtual Jaguar starts carts by HLE. `scripts/make-test-rom.sh`
/// writes the same bytes to a file.
///
/// What the program does:
/// - Points the Object Processor at a lone STOP object and turns on video with BGEN, so the whole picture is the
///   background colour (BG, RGB16: red 15-11, blue 10-6, green 5-0).
/// - BG is `color(directions:a:b:)` from joypad 1 (row 0 for the directions and A, row 1 for B), rewritten in a loop.
/// - Writes a square wave to the DAC (LTXD and RTXD), flipping every 64 loops.
enum JaguarTestROM {
    static let size = 0x20000

    /// BG for the active-high direction nibble (bit 0 Up, 1 Down, 2 Left, 3 Right) and buttons A and B.
    static func color(directions: UInt16, a: Bool, b: Bool) -> UInt16 {
        directions << 12 | 0x0210 | (a ? 0x0020 : 0) | (b ? 0x0400 : 0)
    }

    static func build() -> Data {
        var rom = [UInt8](repeating: 0, count: size)
        rom.replaceSubrange(0x404..<0x408, with: [0x00, 0x80, 0x20, 0x00]) // entry $802000
        var code: [UInt8] = []
        func words(_ values: UInt16...) { for v in values { code += [UInt8(v >> 8), UInt8(v & 0xFF)] } }

        words(0x46FC, 0x2700)                                 // move.w #$2700,sr
        words(0x42B9, 0x0000, 0x1000)                         // clr.l $1000: STOP object, high long
        words(0x23FC, 0x0000, 0x0004, 0x0000, 0x1004)         // move.l #4,$1004: type 4, STOP
        words(0x23FC, 0x1000, 0x0000, 0x00F0, 0x0020)         // OLP = $1000, written word-swapped
        words(0x33FC, 0x06C7, 0x00F0, 0x0028)                 // VMODE: video on, RGB16, BGEN
        let loop = 0x802000 + code.count
        words(0x33FC, 0x81FE, 0x00F1, 0x4000)                 // JOYSTICK: audio on, port 1 row 0
        words(0x3039, 0x00F1, 0x4000)                         // move.w JOYSTICK,d0 (J8-J11 directions)
        words(0x3239, 0x00F1, 0x4002)                         // move.w JOYBUTS,d1 (B1 = A)
        words(0x33FC, 0x81FD, 0x00F1, 0x4000)                 // row 1
        words(0x3439, 0x00F1, 0x4002)                         // move.w JOYBUTS,d2 (B1 = B)
        words(0x4640, 0xE048, 0x0240, 0x000F)                 // not.w d0; lsr.w #8,d0; andi.w #$F,d0
        words(0x760C, 0xE768, 0x0040, 0x0210)                 // moveq #12,d3; lsl.w d3,d0; ori.w #$0210,d0
        words(0x0801, 0x0001, 0x6604, 0x0040, 0x0020)         // btst #1,d1; bne +4; ori.w #$0020,d0 (A)
        words(0x0802, 0x0001, 0x6604, 0x0040, 0x0400)         // btst #1,d2; bne +4; ori.w #$0400,d0 (B)
        words(0x33C0, 0x00F0, 0x0058)                         // move.w d0,BG
        words(0x5245, 0x3C05, 0x0246, 0x0040)                 // addq.w #1,d5; move.w d5,d6; andi.w #$40,d6
        words(0x6706, 0x3E3C, 0x3000, 0x6004, 0x3E3C, 0xD000) // beq +6; move.w #$3000,d7; bra +4; move.w #-$3000,d7
        words(0x33C7, 0x00F1, 0xA14A)                         // move.w d7,LTXD
        words(0x33C7, 0x00F1, 0xA14E)                         // move.w d7,RTXD
        words(0x4EF9, UInt16(loop >> 16), UInt16(loop & 0xFFFF)) // jmp loop
        rom.replaceSubrange(0x2000..<(0x2000 + code.count), with: code)
        return Data(rom)
    }
}
#endif
