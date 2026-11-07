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
/// - Toggle cell, x 0 to 15 on the same rows: pressing L and R together flips it between white and the
///   band colour. The flag lives only in a CPU register, so it proves a save state restored the CPU.
/// - Cheat cell, x 16 to 31: white for a frame after anything writes a non-zero byte to `cheatAddress`,
///   which the program clears each frame, so a cheat shows while it is on and stops when it is off.
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
    static let cheatAddress: UInt32 = 0x02000000
    static let toggleChord: UInt32 = 0x300 // L and R, in KEYINPUT order.

    /// mGBA widens BGR555 to 8 bits per channel by repeating the top bits.
    static func rgb8(_ bgr555: UInt16) -> (r: UInt8, g: UInt8, b: UInt8) {
        func widen(_ five: UInt16) -> UInt8 { UInt8((five << 3) | (five >> 2)) }
        return (widen(bgr555 & 0x1F), widen((bgr555 >> 5) & 0x1F), widen((bgr555 >> 10) & 0x1F))
    }

    /// Expected BGR555 at a pixel, with `keys` as a KEYINPUT-order mask of held keys.
    static func expectedColor(x: Int, y: Int, keys: UInt32, toggle: Bool = false, cheat: Bool = false) -> UInt16 {
        let cellRange = cellOriginX..<(cellOriginX + cellWidth * keyCount)
        if (cellOriginY..<(cellOriginY + cellHeight)).contains(y) {
            if cellRange.contains(x) { return keys & (1 << UInt32((x - cellOriginX) / cellWidth)) != 0 ? 0x7FFF : 0 }
            if toggle, x < cellWidth { return 0x7FFF }
            if cheat, (cellWidth..<cellWidth * 2).contains(x) { return 0x7FFF }
        }
        return bandColors[y / bandHeight]
    }

    static func build() -> Data {
        var a = ARMAssembler(origin: 0xC0)
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
        a.mov(r6, 0) // Bit 0: the toggle. Bit 1: the chord was held last frame.
        let row = 0x06000000 + UInt32((cellOriginY * width + cellOriginX) * 2)

        // Fills one cell at r9 with r1. Uses r2, r3 and r12.
        func drawCell() {
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
        }

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
        drawCell()
        a.add(r9, r9, UInt32(cellWidth * 2))
        a.add(r8, r8, 1)
        a.cmp(r8, UInt32(keyCount))
        a.branch(to: cell, cond: .ne)

        // Flip the toggle on the press of the chord only.
        a.ands(r1, r7, toggleChord)
        a.mov(r1, 2, cond: .eq)
        a.mov(r1, 0, cond: .ne)
        a.bicReg(r2, r1, r6)
        a.tst(r2, 2)
        a.eor(r6, r6, 1, cond: .ne)
        a.and(r6, r6, 1)
        a.orrReg(r6, r6, r1)

        a.load32(r9, 0x06000000 + UInt32(cellOriginY * width * 2))
        a.load32(r1, UInt32(bandColors[0]))
        a.tst(r6, 1)
        a.movReg(r1, r10, cond: .ne)
        drawCell()

        a.add(r9, r9, UInt32(cellWidth * 2))
        a.load32(r3, cheatAddress)
        a.ldrb(r2, r3, 0)
        a.strb(r11, r3, 0)
        a.load32(r1, UInt32(bandColors[0]))
        a.cmp(r2, 0)
        a.movReg(r1, r10, cond: .ne)
        drawCell()
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
}
#endif
