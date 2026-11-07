#if DEBUG
import Foundation

/// Generates a small homebrew Master System ROM, so tests need no commercial game and no Sega BIOS.
/// Hand-assembled Z80 with a "TMR SEGA" header, which only the BIOS reads. `scripts/make-test-rom.sh` writes
/// the same bytes to a file for import tests.
///
/// What the program does:
/// - Clears VRAM, so every tile is blank and the whole picture is background colour 0 (CRAM 0).
/// - Each frame, after the VDP's frame flag, writes CRAM 0 from the joypad: `color(joypad:)`.
/// - Channel 0 of the SN76489 plays a steady square tone at `toneHertz`.
/// - Cartridge RAM (Sega mapper, 0xFFFC bit 3): "GAGA" at offset 0 and a boot counter at offset 4.
/// - A frame counter at 0xC000 in work RAM, so states taken at different frames differ.
enum SMSTestROM {
    /// 64 KB: Gearsystem gives a ROM of 48 KB or less no mapper, and so no cartridge RAM.
    static let size = 0x10000
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramBootCounterOffset = 4
    static let toneDivider = 254
    static let toneHertz = 3579545.0 / Double(32 * toneDivider)

    /// CRAM 0 (--BBGGRR) for a port 0xDC value, active low: bit 0 Up, 1 Down, 2 Left, 3 Right, 4 button 1, 5 button 2.
    /// Blue at rest; each held line flips its own bit of the colour.
    static func color(joypad: UInt8) -> UInt8 { (~joypad & 0x3F) ^ 0x30 }

    static func build() -> Data {
        var rom = [UInt8](repeating: 0, count: size)
        var pc = 0
        func emit(_ bytes: UInt8...) { for b in bytes { rom[pc] = b; pc += 1 } }
        func jr(_ opcode: UInt8, to target: Int) { emit(opcode, UInt8(bitPattern: Int8(target - (pc + 2)))) }

        emit(0xF3)                   // di
        emit(0xED, 0x56)             // im 1
        emit(0x31, 0xF0, 0xDF)       // ld sp, 0xDFF0
        emit(0xC3, 0x00, 0x01)       // jp 0x0100
        pc = 0x66
        emit(0xED, 0x45)             // retn: the Pause button's NMI does nothing.

        pc = 0x0100
        emit(0x3E, 0x08, 0x32, 0xFC, 0xFF)               // ld a, 8; ld (0xFFFC), a: cartridge RAM at 0x8000
        emit(0x3A, 0x04, 0x80, 0x3C, 0x32, 0x04, 0x80)   // inc (0x8004): the boot counter
        emit(0x21, 0x00, 0x80)                           // ld hl, 0x8000
        for (i, byte) in sramMagic.enumerated() {
            emit(0x36, byte)                             // ld (hl), byte
            if i < sramMagic.count - 1 { emit(0x23) }    // inc hl
        }
        let tableFixup = pc + 1
        emit(0x21, 0, 0)                                 // ld hl, vdpTable
        emit(0x06, UInt8(vdpTable.count), 0x0E, 0xBF, 0xED, 0xB3) // ld b, n; ld c, 0xBF; otir
        emit(0xAF, 0xD3, 0xBF, 0x3E, 0x40, 0xD3, 0xBF)   // VRAM write address 0
        emit(0x01, 0x00, 0x40)                           // ld bc, 0x4000
        let clear = pc
        emit(0xAF, 0xD3, 0xBE, 0x0B, 0x78, 0xB1)         // xor a; out (0xBE), a; dec bc; ld a, b; or c
        jr(0x20, to: clear)                              // jr nz, clear
        let psg: [UInt8] = [0x80 | UInt8(toneDivider & 0x0F), UInt8(toneDivider >> 4), 0x90, 0xBF, 0xDF, 0xFF]
        for byte in psg { emit(0x3E, byte, 0xD3, 0x7F) } // ld a, byte; out (0x7F), a
        emit(0x3E, 0xC0, 0xD3, 0xBF, 0x3E, 0x81, 0xD3, 0xBF) // register 1 = 0xC0: display on, no interrupts
        let frame = pc
        emit(0xDB, 0xBF, 0xE6, 0x80)                     // in a, (0xBF); and 0x80: the frame flag
        jr(0x28, to: frame)                              // jr z, frame
        emit(0xDB, 0xDC, 0x2F, 0xE6, 0x3F, 0xEE, 0x30, 0x57) // in a, (0xDC); cpl; and 0x3F; xor 0x30; ld d, a
        emit(0xAF, 0xD3, 0xBF, 0x3E, 0xC0, 0xD3, 0xBF)   // CRAM write address 0
        emit(0x7A, 0xD3, 0xBE)                           // ld a, d; out (0xBE), a
        emit(0x21, 0x00, 0xC0, 0x34)                     // ld hl, 0xC000; inc (hl)
        emit(0xC3, UInt8(frame & 0xFF), UInt8(frame >> 8)) // jp frame
        rom[tableFixup] = UInt8(pc & 0xFF)
        rom[tableFixup + 1] = UInt8(pc >> 8)
        for byte in vdpTable { emit(byte) }

        // Header at 0x7FF0: "TMR SEGA", reserved, checksum of 0x0000-0x7FEF, product, version, region 4 (export), size 0xC (32 KB).
        let header = 0x7FF0
        rom.replaceSubrange(header..<(header + 8), with: Array("TMR SEGA".utf8))
        let sum = rom[0..<header].reduce(UInt16(0)) { $0 &+ UInt16($1) }
        rom[header + 0x0A] = UInt8(sum & 0xFF)
        rom[header + 0x0B] = UInt8(sum >> 8)
        rom[header + 0x0F] = 0x4C
        return Data(rom)
    }

    /// Value, then 0x80 | register: mode 4 with no left-column blanking, display off, name table at 0x3800,
    /// sprite table at 0x3F00, sprite tiles at 0x0000, backdrop 0, no scroll, no line interrupt.
    private static let vdpTable: [UInt8] = [
        0x06, 0x80, 0x80, 0x81, 0xFF, 0x82, 0xFF, 0x83, 0xFF, 0x84, 0xFF, 0x85,
        0xFB, 0x86, 0x00, 0x87, 0x00, 0x88, 0x00, 0x89, 0xFF, 0x8A,
    ]
}
#endif
