#if DEBUG
import Foundation

/// Generates a small homebrew GBA ROM, so tests and the benchmark need no commercial game and no
/// Nintendo material. Hand-assembled ARM7TDMI, with no boot logo: the core must skip the BIOS boot.
/// `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - Mode 3 bitmap: four horizontal bands 40 rows tall, in `bandColors`. The last band's colour comes
///   from a BIOS division (SWI 6), so the picture is wrong if the HLE BIOS is.
/// - Ten 16 by 8 cells on rows 8 to 15, from x = 40: white while that KEYINPUT bit is held, else black.
/// - Waits on VBlankIntrWait (SWI 5) each frame, so it hangs if BIOS interrupt handling does not work.
/// - PSG channel 1 plays a steady square tone at about 440 Hz.
/// - SRAM: "GAGA" at offset 0, and a boot counter at offset 4, incremented once per boot.
enum GBATestROM {
    static let width = 240
    static let height = 160
    static let bandHeight = 40
    /// BGR555: red, green, blue, then 0x7FFE / 2 from the BIOS.
    static let bandColors: [UInt16] = [0x001F, 0x03E0, 0x7C00, 0x3FFF]
    static let cellOriginX = 40
    static let cellOriginY = 8
    static let cellWidth = 16
    static let cellHeight = 8
    static let keyCount = 10
    static let toneHertz = 131072.0 / Double(2048 - 1750)
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramBootCounterOffset = 4

    /// mGBA widens BGR555 to 8 bits per channel by repeating the top bits.
    static func rgb8(_ bgr555: UInt16) -> (r: UInt8, g: UInt8, b: UInt8) {
        func widen(_ five: UInt16) -> UInt8 { UInt8((five << 3) | (five >> 2)) }
        return (widen(bgr555 & 0x1F), widen((bgr555 >> 5) & 0x1F), widen((bgr555 >> 10) & 0x1F))
    }

    /// Expected BGR555 at a pixel, with `keys` as a KEYINPUT-order mask of held keys.
    static func expectedColor(x: Int, y: Int, keys: UInt32) -> UInt16 {
        let cellRange = cellOriginX..<(cellOriginX + cellWidth * keyCount)
        if (cellOriginY..<(cellOriginY + cellHeight)).contains(y), cellRange.contains(x) {
            return keys & (1 << UInt32((x - cellOriginX) / cellWidth)) != 0 ? 0x7FFF : 0
        }
        return bandColors[y / bandHeight]
    }

    static func build() -> Data {
        var a = Assembler()
        let r0 = 0, r1 = 1, r2 = 2, r3 = 3, r4 = 4, r5 = 5, r6 = 6, r7 = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11, r12 = 12

        // IRQ handler, called from the BIOS with r0 = 0x04000000. Sets the BIOS flag and acknowledges VBlank.
        let handler = a.here
        a.mov(r1, 1)
        a.load32(r2, 0x03007FF8)
        a.strh(r1, r2, 0)
        a.add(r2, r0, 0x200)
        a.strh(r1, r2, 2)
        a.word(0xE12FFF1E) // bx lr

        let start = a.here
        a.mov(r4, 0x04000000)
        a.load32(r1, 0x0403) // DISPCNT: mode 3, BG2 on.
        a.strh(r1, r4, 0)

        a.mov(r1, 0x80) // SOUNDCNT_X first: PSG writes are ignored while sound is off.
        a.strh(r1, r4, 0x84)
        a.load32(r1, 0x1177) // SOUNDCNT_L: full volume, channel 1 left and right.
        a.strh(r1, r4, 0x80)
        a.mov(r1, 2) // SOUNDCNT_H: PSG at 100%.
        a.strh(r1, r4, 0x82)
        a.mov(r1, 8) // SOUND1CNT_L: no sweep.
        a.strh(r1, r4, 0x60)
        a.load32(r1, 0xF080) // SOUND1CNT_H: volume 15, 50% duty.
        a.strh(r1, r4, 0x62)
        a.load32(r1, 0x8000 | 1750) // SOUND1CNT_X: start, rate 1750 is 131072 / 298 Hz.
        a.strh(r1, r4, 0x64)

        a.mov(r2, 0x0E000000) // SRAM is on an 8-bit bus.
        for (offset, byte) in sramMagic.enumerated() {
            a.mov(r1, UInt32(byte))
            a.strb(r1, r2, offset)
        }
        a.ldrb(r1, r2, sramBootCounterOffset)
        a.cmp(r1, 0xFF)
        a.mov(r1, 0, cond: .eq) // Erased SRAM reads 0xFF.
        a.add(r1, r1, 1)
        a.strb(r1, r2, sramBootCounterOffset)

        a.mov(r6, 0x06000000) // Bands, in VRAM order.
        for (index, color) in bandColors.enumerated() {
            if index == bandColors.count - 1 {
                a.load32(r0, 0x7FFE)
                a.mov(r1, 2)
                a.swi(0x060000) // Div: r0 = r0 / r1.
                a.movReg(r1, r0)
            } else {
                a.load32(r1, UInt32(color))
            }
            a.load32(r2, UInt32(width * bandHeight))
            let pixel = a.here
            a.strhPost(r1, r6, 2)
            a.subs(r2, r2, 1)
            a.branch(to: pixel, cond: .ne)
        }

        // Interrupts last, once the handler and the picture are ready.
        a.load32(r2, 0x03007FFC)
        a.load32(r1, 0x08000000 + UInt32(handler))
        a.str(r1, r2, 0)
        a.mov(r1, 8) // DISPSTAT: VBlank IRQ on.
        a.strh(r1, r4, 4)
        a.add(r2, r4, 0x200)
        a.mov(r1, 1)
        a.strh(r1, r2, 0) // IE: VBlank.
        a.strh(r1, r2, 8) // IME.

        a.load32(r10, 0x7FFF)
        a.mov(r11, 0)
        a.add(r5, r4, 0x100)
        let row = 0x06000000 + UInt32((cellOriginY * width + cellOriginX) * 2)

        let frame = a.here
        a.swi(0x050000) // VBlankIntrWait.
        a.ldrh(r7, r5, 0x30) // KEYINPUT, active low.
        a.load32(r9, row)
        a.mov(r8, 0)
        let cell = a.here
        a.word(0xE1A01000 | UInt32(r8) << 8 | 0x30 | UInt32(r7)) // mov r1, r7, lsr r8
        a.tst(r1, 1)
        a.movReg(r1, r10, cond: .eq)
        a.movReg(r1, r11, cond: .ne)
        a.movReg(r3, r9)
        a.mov(r2, UInt32(cellHeight))
        let rowStart = a.here
        a.mov(r12, UInt32(cellWidth))
        let cellPixel = a.here
        a.strhPost(r1, r3, 2)
        a.subs(r12, r12, 1)
        a.branch(to: cellPixel, cond: .ne)
        a.add(r3, r3, UInt32((width - cellWidth) * 2))
        a.subs(r2, r2, 1)
        a.branch(to: rowStart, cond: .ne)
        a.add(r9, r9, UInt32(cellWidth * 2))
        a.add(r8, r8, 1)
        a.cmp(r8, UInt32(keyCount))
        a.branch(to: cell, cond: .ne)
        a.branch(to: frame)

        return image(code: a.bytes, start: start)
    }

    /// Cartridge header, then code at 0xC0, padded to a power of two. The logo area stays zero on purpose.
    private static func image(code: [UInt8], start: Int) -> Data {
        var rom = [UInt8](repeating: 0, count: 0xC0)
        // ARM branch at the reset vector. Offsets count from the instruction plus 8.
        let entry = UInt32(0xEA00_0000) | UInt32((start - 8) / 4)
        rom.replaceSubrange(0..<4, with: withUnsafeBytes(of: entry.littleEndian, Array.init))
        rom.replaceSubrange(0xA0..<0xAC, with: Array("GAGATESTROM ".utf8))
        rom.replaceSubrange(0xAC..<0xB0, with: Array("GGTE".utf8))
        rom.replaceSubrange(0xB0..<0xB2, with: Array("00".utf8))
        rom[0xB2] = 0x96
        rom[0xBD] = headerChecksum(rom)
        rom += code
        var size = 0x1000
        while size < rom.count { size *= 2 }
        rom += [UInt8](repeating: 0, count: size - rom.count)
        return Data(rom)
    }

    /// The header's complement check, as a real cartridge carries it.
    static func headerChecksum(_ rom: [UInt8]) -> UInt8 {
        let sum = rom[0xA0...0xBC].reduce(0) { $0 &+ Int($1) }
        return UInt8(truncatingIfNeeded: -(sum + 0x19))
    }

    /// Just enough of an ARM assembler. Addresses are byte offsets in the ROM.
    private struct Assembler {
        enum Cond: UInt32 { case eq = 0x0, ne = 0x1, always = 0xE }

        private(set) var bytes: [UInt8] = []
        var here: Int { 0xC0 + bytes.count }

        mutating func word(_ value: UInt32) {
            bytes += withUnsafeBytes(of: value.littleEndian, Array.init)
        }

        /// ARM immediates are 8 bits rotated right by an even amount.
        private static func immediate(_ value: UInt32) -> UInt32 {
            for rotate in 0..<16 {
                let unrotated = (value << UInt32(rotate * 2)) | (rotate == 0 ? 0 : value >> (32 - UInt32(rotate * 2)))
                if unrotated <= 0xFF { return UInt32(rotate) << 8 | unrotated }
            }
            preconditionFailure("no ARM immediate for \(value)")
        }

        private mutating func alu(_ opcode: UInt32, rd: Int, rn: Int, _ value: UInt32, cond: Cond = .always) {
            word(cond.rawValue << 28 | 0x02000000 | opcode << 20 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.immediate(value))
        }

        mutating func mov(_ rd: Int, _ value: UInt32, cond: Cond = .always) { alu(0x1A, rd: rd, rn: 0, value, cond: cond) }
        mutating func add(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x08, rd: rd, rn: rn, value) }
        mutating func subs(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x05, rd: rd, rn: rn, value) }
        mutating func cmp(_ rn: Int, _ value: UInt32) { alu(0x15, rd: 0, rn: rn, value) }
        mutating func tst(_ rn: Int, _ value: UInt32) { alu(0x11, rd: 0, rn: rn, value) }
        private mutating func orr(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x18, rd: rd, rn: rn, value) }

        /// mov and orr, one byte at a time. ARMv4 has no movw, and this avoids a literal pool.
        mutating func load32(_ rd: Int, _ value: UInt32) {
            var pending = (0..<4).map { value & (0xFF << UInt32($0 * 8)) }.filter { $0 != 0 }
            mov(rd, pending.isEmpty ? 0 : pending.removeFirst())
            for part in pending { orr(rd, rd, part) }
        }

        mutating func movReg(_ rd: Int, _ rm: Int, cond: Cond = .always) {
            word(cond.rawValue << 28 | 0x01A00000 | UInt32(rd) << 12 | UInt32(rm))
        }

        private static func halfwordOffset(_ offset: Int) -> UInt32 {
            UInt32(offset >> 4) << 8 | UInt32(offset & 0xF)
        }

        mutating func strh(_ rd: Int, _ rn: Int, _ offset: Int) {
            word(0xE1C000B0 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.halfwordOffset(offset))
        }

        mutating func strhPost(_ rd: Int, _ rn: Int, _ offset: Int) {
            word(0xE0C000B0 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.halfwordOffset(offset))
        }

        mutating func ldrh(_ rd: Int, _ rn: Int, _ offset: Int) {
            word(0xE1D000B0 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.halfwordOffset(offset))
        }

        mutating func str(_ rd: Int, _ rn: Int, _ offset: Int) {
            word(0xE5800000 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(offset))
        }

        mutating func strb(_ rd: Int, _ rn: Int, _ offset: Int) {
            word(0xE5C00000 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(offset))
        }

        mutating func ldrb(_ rd: Int, _ rn: Int, _ offset: Int) {
            word(0xE5D00000 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(offset))
        }

        mutating func swi(_ comment: UInt32) { word(0xEF000000 | comment) }

        mutating func branch(to target: Int, cond: Cond = .always) {
            let delta = (target - (here + 8)) / 4
            word(cond.rawValue << 28 | 0x0A000000 | UInt32(truncatingIfNeeded: delta) & 0xFFFFFF)
        }
    }
}
#endif
