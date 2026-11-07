#if DEBUG
import Foundation

/// Generates a homebrew Amiga floppy (`.adf`, 880 KB) with a bootable bootblock, so tests need no commercial game.
/// It boots on any Kickstart, including upstream's built-in AROS replacement, so tests need no Commodore ROM.
/// Hand-assembled 68000. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What the program does, once the Kickstart runs the bootblock:
/// - Turns off interrupts and DMA, so the whole picture is the background colour (COLOR00, RGB 4-4-4).
/// - COLOR00 is `color(...)` from joystick port 2 (JOY1DAT, fire on CIA-A PRA bit 7) and the keyboard (CIA-A serial
///   port, with the handshake the keyboard waits for), rewritten in a loop.
/// - Paula channel 0 loops an 8-byte square wave from chip RAM at $60000.
enum AmigaTestROM {
    static let size = 901_120

    /// COLOR00 for the inputs. Green $040 at rest; each input sets its own bit.
    static func color(up: Bool, down: Bool, left: Bool, right: Bool, fire: Bool, keyDown: Bool) -> UInt16 {
        0x040 | (down ? 0x001 : 0) | (right ? 0x002 : 0) | (up ? 0x100 : 0) | (left ? 0x200 : 0)
            | (fire ? 0x400 : 0) | (keyDown ? 0x800 : 0)
    }

    static func adf() -> Data {
        let words: [UInt16] = [
            0x4BF9, 0x00DF, 0xF000,                 // lea $dff000,a5
            0x3B7C, 0x7FFF, 0x009A,                 // INTENA: all off
            0x3B7C, 0x7FFF, 0x0096,                 // DMACON: all off
            0x3B7C, 0x7FFF, 0x009C,                 // INTREQ: clear
            0x41F9, 0x0006, 0x0000,                 // lea $60000,a0
            0x20FC, 0x7F7F, 0x7F7F,                 // move.l #$7f7f7f7f,(a0)+
            0x20BC, 0x8181, 0x8181,                 // move.l #$81818181,(a0)
            0x2B7C, 0x0006, 0x0000, 0x00A0,         // AUD0LC = $60000
            0x3B7C, 0x0004, 0x00A4,                 // AUD0LEN = 4 words
            0x3B7C, 0x0190, 0x00A6,                 // AUD0PER = 400
            0x3B7C, 0x0040, 0x00A8,                 // AUD0VOL = 64
            0x3B7C, 0x8201, 0x0096,                 // DMACON: DMAEN | AUD0EN
            0x7E00,                                 // moveq #0,d7 (key down)
            // loop (+76):
            0x302D, 0x000C,                         // move.w JOY1DAT(a5),d0
            0x3200, 0xE249, 0xB141,                 // move.w d0,d1; lsr.w #1,d1; eor.w d0,d1
            0x0241, 0x0101,                         // and.w #$0101,d1 (bit 0 down, bit 8 up)
            0x0240, 0x0202,                         // and.w #$0202,d0 (bit 1 right, bit 9 left)
            0x8041,                                 // or.w d1,d0
            0x0839, 0x0007, 0x00BF, 0xE001,         // btst #7,$bfe001 (fire, active low)
            0x6604,                                 // bne.s +4
            0x0040, 0x0400,                         // or.w #$400,d0
            0x0040, 0x0040,                         // or.w #$040,d0
            0x0839, 0x0003, 0x00BF, 0xED01,         // btst #3,$bfed01 (CIA-A ICR: serial byte in)
            0x672C,                                 // beq.s nokey
            0x1439, 0x00BF, 0xEC01,                 // move.b $bfec01,d2 (SDR)
            0x4602, 0xE21A,                         // not.b d2; ror.b #1,d2 (bit 7 set: key up)
            0x0039, 0x0040, 0x00BF, 0xEE01,         // or.b #$40,$bfee01 (handshake: SP output)
            0x363C, 0x00C8, 0x51CB, 0xFFFE,         // move.w #200,d3; wait: dbf d3,wait
            0x0239, 0x00BF, 0x00BF, 0xEE01,         // and.b #$bf,$bfee01 (SP input)
            0x7E00,                                 // moveq #0,d7
            0x0802, 0x0007,                         // btst #7,d2
            0x6602,                                 // bne.s nokey
            0x7E01,                                 // moveq #1,d7
            // nokey (+168):
            0x4A07, 0x6704,                         // tst.b d7; beq.s +4
            0x0040, 0x0800,                         // or.w #$800,d0
            0x3B40, 0x0180,                         // move.w d0,COLOR00(a5)
            0x6096,                                 // bra.s loop
        ]
        var disk = [UInt8](repeating: 0, count: size)
        disk.replaceSubrange(0..<4, with: [UInt8]("DOS".utf8) + [0])
        disk.replaceSubrange(8..<12, with: [0, 0, 0x03, 0x70]) // root block 880
        for (i, word) in words.enumerated() {
            disk[12 + i * 2] = UInt8(word >> 8)
            disk[13 + i * 2] = UInt8(word & 0xFF)
        }
        // Bootblock checksum: the complement of the 1024-byte sum of longwords with end-around carry.
        var sum: UInt32 = 0
        for i in stride(from: 0, to: 1024, by: 4) {
            let long = UInt32(disk[i]) << 24 | UInt32(disk[i + 1]) << 16 | UInt32(disk[i + 2]) << 8 | UInt32(disk[i + 3])
            let (total, carry) = sum.addingReportingOverflow(long)
            sum = total &+ (carry ? 1 : 0)
        }
        let checksum = ~sum
        disk.replaceSubrange(4..<8, with: [UInt8(checksum >> 24), UInt8(checksum >> 16 & 0xFF),
                                           UInt8(checksum >> 8 & 0xFF), UInt8(checksum & 0xFF)])
        return Data(disk)
    }
}
#endif
