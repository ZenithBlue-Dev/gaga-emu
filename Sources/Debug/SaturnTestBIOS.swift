#if DEBUG
import Foundation

/// Generates a stand-in Saturn system ROM and a data disc, so Beetle Saturn tests need no Sega BIOS and no
/// commercial disc. The ROM is GagaEmu's own SH-2 program, 512 KiB like the real chip so the core accepts it,
/// and the disc carries only a "SEGA SEGASATURN" header. Neither holds any Sega code or data. Tests write the
/// ROM under the name the core opens (`fileName`) in a temporary system folder only; it is never imported.
///
/// What the program does, on the master SH-2 straight from reset, with interrupts masked:
/// - Adds one to backup RAM byte 0 (the battery save's first byte), once per boot.
/// - Sets the VDP2 back screen to `backColor` and turns the display on, 320 by 224, with no layer enabled, so
///   every pixel of the picture is the back colour.
/// - Spins in a branch loop. It never touches the CD block, the sound CPU, the SMPC or the slave SH-2: no input,
///   and silence. Beetle Saturn applies cheats only when a game takes the VBlank-In interrupt, which this does
///   not, so cheats need a real game too.
enum SaturnTestBIOS {
    static let fileName = "mpr-17933.bin"
    static let size = 512 * 1024
    /// RGB555 with the MSB set, blue in bits 10 to 14 and red in 0 to 4: pure red.
    static let backColor: UInt16 = 0x801F
    /// 8-bit RGB the core shows for `backColor`: Mednafen widens 5 bits by a shift, so 31 is 248.
    static let backRGB: [UInt8] = [248, 0, 0]
    /// The backup RAM's size, which is the battery save's size.
    static let backupSize = 32 * 1024

    private static let start = 0x100

    static func build() -> Data {
        var rom = [UInt8](repeating: 0, count: size)
        func put32(_ value: UInt32, at offset: Int) {
            for i in 0..<4 { rom[offset + i] = UInt8(truncatingIfNeeded: value >> (24 - 8 * UInt32(i))) }
        }
        // Power-on and manual reset vectors: PC, then SP at the top of high work RAM.
        for vector in [0, 8] {
            put32(UInt32(start), at: vector)
            put32(0x0610_0000, at: vector + 4)
        }
        let code = program()
        rom.replaceSubrange(start..<(start + code.count), with: code)
        return Data(rom)
    }

    /// One Mode 1 data sector of 2352 bytes whose data opens with the Saturn system ID, then empty sectors.
    static func disc() -> (bin: Data, cue: (String) -> String) {
        var bin = [UInt8](repeating: 0, count: 2352 * 300)
        bin.replaceSubrange(0..<12, with: [0x00] + [UInt8](repeating: 0xFF, count: 10) + [0x00]) // Sync pattern.
        bin[15] = 1 // Mode 1.
        let id = Array("SEGA SEGASATURN ".utf8)
        bin.replaceSubrange(16..<(16 + id.count), with: id)
        return (Data(bin), { name in "FILE \"\(name)\" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n" })
    }

    /// SH-2 machine code, big endian. Each `mov.l @(disp,PC),Rn` loads from a pool after the code.
    private static func program() -> [UInt8] {
        var words: [UInt16] = []
        var pool: [UInt32] = []
        var loads: [(index: Int, slot: Int)] = []
        func load(_ value: UInt32, into rn: UInt16) {
            let slot = pool.firstIndex(of: value) ?? { pool.append(value); return pool.count - 1 }()
            loads.append((words.count, slot))
            words.append(0xD000 | rn << 8)
        }
        load(0x2018_0001, into: 1)          // r1 = backup RAM byte 0 (odd address, cache-through)
        words += [0x6010, 0x7001, 0x2100]   // mov.b @r1,r0; add #1,r0; mov.b r0,@r1
        load(0x25E0_0000, into: 1)          // r1 = VDP2 VRAM
        load(UInt32(backColor), into: 2)    // r2 = back colour
        words += [0x2121]                   // mov.w r2,@r1: the back colour at VRAM address 0
        load(0x25F8_00AC, into: 1)          // r1 = BKTAU
        words += [0xE200, 0x2121, 0x7102, 0x2121] // mov #0,r2; BKTAU = 0; add #2,r1; BKTAL = 0: one colour
        load(0x25F8_0000, into: 1)          // r1 = TVMD
        load(0x0000_8000, into: 2)          // r2 = DISP
        words += [0x2121]                   // mov.w r2,@r1: display on, 320 by 224
        words += [0xAFFE, 0x0009]           // bra . (spin); nop in the delay slot

        let poolAddress = (start + words.count * 2 + 3) & ~3
        for load in loads {
            let pc = start + load.index * 2
            let disp = (poolAddress + load.slot * 4 - ((pc & ~3) + 4)) / 4
            precondition((0..<256).contains(disp))
            words[load.index] |= UInt16(disp)
        }
        var out = words.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
        out += [UInt8](repeating: 0, count: poolAddress - start - out.count)
        return out + pool.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - 8 * UInt32($0))) } }
    }
}
#endif
