#if DEBUG
import Foundation

/// Generates a small homebrew Nintendo DS ROM, so tests and the benchmark need no commercial game and no
/// Nintendo material. Hand-assembled ARM for both CPUs, with no logo and no secure area: the core must boot
/// it directly with its free BIOS. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What the program does:
/// - Top screen (engine A, VRAM display mode): four horizontal bands 48 rows tall, in `topBandColors`.
///   Twelve 16 by 8 key cells on rows 8 to 15 from x = 40, white while that key is held, else black: the ten
///   KEYINPUT keys, then X and Y, which only the ARM7 can read.
/// - Toggle cell, x 0 to 15 on the same rows: pressing L and R together flips it between white and the band
///   colour. The flag lives only in an ARM9 register, so it proves a save state restored the CPU.
/// - Cheat cell, x 16 to 31: white for a frame after anything writes a non-zero byte to `cheatAddress`, which
///   the ARM9 clears each frame. Action Replay codes run on the ARM7's VBlank interrupt, so that is enabled.
/// - Bottom screen (engine B, direct-colour bitmap): four vertical bands 64 pixels wide, in
///   `bottomBandColors`, and a black 8 by 8 marker on the 8-pixel cell under the stylus.
/// - The ARM7 reads the touch screen controller over SPI and EXTKEYIN each frame, and passes both to the
///   ARM9 in one word of main RAM at `sharedAddress`.
/// - PSG channel 8 plays a steady square tone at `toneHertz`.
/// - EEPROM (8 KB, as melonDS gives a game code it does not know): "GAGA" at offset 0, and a boot counter
///   at offset 4, incremented once per boot.
enum NDSTestROM {
    static let screenWidth = 256
    static let screenHeight = 192
    /// The frame with melonDS DS's left-right layout: top screen left, touch screen right.
    static let frameWidth = screenWidth * 2
    static let bandHeight = 48
    static let topBandColors: [UInt16] = [0x001F, 0x03E0, 0x7C00, 0x03FF] // BGR555: red, green, blue, yellow.
    static let bottomBandWidth = 64
    static let bottomBandColors: [UInt16] = [0x7C1F, 0x7FE0, 0x7FFF, 0x3DEF] // Magenta, cyan, white, grey.
    static let cellOriginX = 40
    static let cellOriginY = 8
    static let cellWidth = 16
    static let cellHeight = 8
    static let keyCount = 12 // KEYINPUT order, then X and Y.
    static let markerSize = 8
    static let toneTimer: UInt32 = 0xED68
    /// The PSG steps 8 duty positions, each one timer period of the 16.76 MHz sound clock.
    static let toneHertz = 33_513_982.0 / 2 / (Double(0x10000 - toneTimer) * 8)
    static let eepromMagic: [UInt8] = Array("GAGA".utf8)
    static let eepromBootCounterOffset = 4
    static let saveSize = 8192
    static let cheatAddress: UInt32 = 0x02200000
    static let sharedAddress: UInt32 = 0x02300000
    static let toggleChord: UInt32 = 0x300 // L and R, in KEYINPUT order.
    static let gameCode = "GGTD" // Not in melonDS's ROM list, so it gets the default save chip.

    private static let arm9Address: UInt32 = 0x02000000
    private static let arm7Address: UInt32 = 0x03800000 // ARM7 WRAM.
    private static let arm9Offset = 0x8000 // Past 0x7FFF, so melonDS looks for no secure area.
    private static let arm9Entry = 0x20 // After the decrypted-dump marker and the colour table.
    private static let arm7Offset = 0x9000
    private static let romSize = 0x10000

    /// Expected BGR555 at a frame pixel. `keys` is a mask of held keys in `keyCount` order, `touch` the
    /// stylus position on the lower screen.
    static func expectedColor(x: Int, y: Int, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false,
                              touch: (x: Int, y: Int)? = nil) -> UInt16 {
        if x >= screenWidth {
            let bx = x - screenWidth
            if let touch, bx / markerSize == touch.x / markerSize, y / markerSize == touch.y / markerSize { return 0 }
            return bottomBandColors[bx / bottomBandWidth]
        }
        if (cellOriginY..<(cellOriginY + cellHeight)).contains(y) {
            if (cellOriginX..<(cellOriginX + cellWidth * keyCount)).contains(x) {
                return keys & (1 << UInt32((x - cellOriginX) / cellWidth)) != 0 ? 0x7FFF : 0
            }
            if toggle, x < cellWidth { return 0x7FFF }
            if cheat, (cellWidth..<cellWidth * 2).contains(x) { return 0x7FFF }
        }
        return topBandColors[y / bandHeight]
    }

    static func build() -> Data {
        let arm9 = buildARM9(), arm7 = buildARM7()
        precondition(arm9Offset + arm9.count <= arm7Offset && arm7Offset + arm7.count <= romSize)
        var rom = [UInt8](repeating: 0, count: romSize)
        func put(_ offset: Int, _ value: UInt32) {
            rom.replaceSubrange(offset..<offset + 4, with: withUnsafeBytes(of: value.littleEndian, Array.init))
        }
        rom.replaceSubrange(0x00..<0x0C, with: Array("GAGATESTNDS ".utf8))
        rom.replaceSubrange(0x0C..<0x10, with: Array(gameCode.utf8))
        rom.replaceSubrange(0x10..<0x12, with: Array("00".utf8))
        put(0x20, UInt32(arm9Offset)); put(0x24, arm9Address + UInt32(arm9Entry)); put(0x28, arm9Address); put(0x2C, UInt32(arm9.count))
        put(0x30, UInt32(arm7Offset)); put(0x34, arm7Address + 0x10); put(0x38, arm7Address); put(0x3C, UInt32(arm7.count))
        put(0x60, 0x00586000); put(0x64, 0x001808F8) // Normal and KEY1 ROM control, as retail headers carry.
        put(0x80, UInt32(arm7Offset + arm7.count)); put(0x84, 0x4000)
        rom[0x15C] = 0x56; rom[0x15D] = 0xCF // Logo CRC. The logo itself stays zero on purpose.
        let crc = crc16(rom[0..<0x15E])
        rom[0x15E] = UInt8(crc & 0xFF); rom[0x15F] = UInt8(crc >> 8)
        rom.replaceSubrange(arm9Offset..<arm9Offset + arm9.count, with: arm9)
        rom.replaceSubrange(arm7Offset..<arm7Offset + arm7.count, with: arm7)
        return Data(rom)
    }

    /// The header check a real DS runs: CRC-16, polynomial 0xA001, from 0xFFFF.
    static func crc16(_ bytes: ArraySlice<UInt8>) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 { crc = crc & 1 != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
        }
        return crc
    }

    private static func padded(_ bytes: [UInt8]) -> [UInt8] { bytes + [UInt8](repeating: 0, count: (4 - bytes.count % 4) % 4) }

    // Direct boot leaves caches and the MPU off, so the two CPUs share main RAM freely.
    private static func buildARM9() -> [UInt8] {
        var a = ARMAssembler(origin: Int(arm9Address))
        let r0 = 0, r1 = 1, r2 = 2, r3 = 3, r4 = 4, r5 = 5, r6 = 6, r7 = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11
        let r12 = 12, r13 = 13, r14 = 14 // No stack and no interrupts here, so sp and lr are free.
        // A decrypted retail dump starts with this word. Without it melonDS DS takes a ROM that is not homebrew
        // to be encrypted, and asks for Nintendo's BIOS.
        a.word(0xE7FFDEFF); a.word(0); a.word(0); a.word(0)
        let table = a.here
        for color in bottomBandColors { a.word(UInt32(color) | 0x8000) } // Bit 15 marks a bitmap pixel opaque.
        precondition(a.here == Int(arm9Address) + arm9Entry)

        a.mov(r4, 0x04000000)
        a.add(r5, r4, 0x100)
        a.mov(r1, 0x80) // VRAM A to the LCDC, which engine A shows in VRAM display mode.
        a.strb(r1, r4, 0x240)
        a.mov(r1, 0x84) // VRAM C to engine B's background, 0x06200000.
        a.strb(r1, r4, 0x242)
        a.mov(r1, 0x20000) // DISPCNT A: VRAM display, bank A.
        a.str(r1, r4, 0)
        a.load32(r6, 0x04001000)
        a.load32(r1, 0x00010805) // DISPCNT B: normal display, mode 5, BG3 on.
        a.str(r1, r6, 0)
        a.load32(r1, 0x4084) // BG3CNT B: 256 by 256 direct-colour bitmap at the start of VRAM.
        a.strh(r1, r6, 0x0E)
        a.mov(r1, 0x100) // BG3PA and BG3PD: scale 1.
        a.strh(r1, r6, 0x30)
        a.strh(r1, r6, 0x36)
        a.load32(r13, sharedAddress)
        a.mov(r1, 0x7F0000) // No ARM7 report yet: X, Y and the pen up.
        a.str(r1, r13, 0)

        a.load32(r6, 0x06800000)
        for color in topBandColors {
            a.load32(r1, UInt32(color))
            a.load32(r2, UInt32(screenWidth * bandHeight))
            let pixel = a.here
            a.strhPost(r1, r6, 2)
            a.subs(r2, r2, 1)
            a.branch(to: pixel, cond: .ne)
        }
        a.load32(r6, 0x06200000)
        a.mov(r8, UInt32(screenHeight))
        let bottomRow = a.here
        for color in bottomBandColors {
            a.load32(r1, UInt32(color) | 0x8000)
            a.mov(r2, UInt32(bottomBandWidth))
            let pixel = a.here
            a.strhPost(r1, r6, 2)
            a.subs(r2, r2, 1)
            a.branch(to: pixel, cond: .ne)
        }
        a.subs(r8, r8, 1)
        a.branch(to: bottomRow, cond: .ne)

        // The marker starts on row 200 of the bitmap, which the screen never shows.
        let hidden = 0x06200000 + UInt32(200 * screenWidth * 2)
        a.load32(r0, hidden)
        a.load32(r10, 0x7FFF)
        a.mov(r11, 0)
        a.mov(r6, 0) // Bit 0: the toggle. Bit 1: the chord was held last frame.
        a.load32(r14, UInt32(table))

        // Fills a cell at r9 with r1. Uses r2, r3 and r12.
        func drawCell(width: Int, height: Int) {
            a.movReg(r3, r9)
            a.mov(r2, UInt32(height))
            let rowStart = a.here
            a.mov(r12, UInt32(width))
            let cellPixel = a.here
            a.strhPost(r1, r3, 2)
            a.subs(r12, r12, 1)
            a.branch(to: cellPixel, cond: .ne)
            a.add(r3, r3, UInt32((screenWidth - width) * 2))
            a.subs(r2, r2, 1)
            a.branch(to: rowStart, cond: .ne)
        }

        let frame = a.here
        a.ldrh(r1, r4, 6) // VCOUNT: once per frame, at the start of VBlank.
        a.cmp(r1, UInt32(screenHeight))
        a.branch(to: frame, cond: .ne)

        a.ldrh(r7, r5, 0x30) // KEYINPUT, active low.
        a.ldr(r2, r13, 0)
        a.lsr(r2, r2, 16)
        a.and(r2, r2, 3) // EXTKEYIN X and Y, active low.
        a.orrReg(r7, r7, r2, lsl: 10)
        a.load32(r9, 0x06800000 + UInt32((cellOriginY * screenWidth + cellOriginX) * 2))
        a.mov(r8, 0)
        let cell = a.here
        a.word(0xE1A01000 | UInt32(r8) << 8 | 0x30 | UInt32(r7)) // mov r1, r7, lsr r8
        a.tst(r1, 1)
        a.movReg(r1, r10, cond: .eq)
        a.movReg(r1, r11, cond: .ne)
        drawCell(width: cellWidth, height: cellHeight)
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

        a.load32(r9, 0x06800000 + UInt32(cellOriginY * screenWidth * 2))
        a.load32(r1, UInt32(topBandColors[0]))
        a.tst(r6, 1)
        a.movReg(r1, r10, cond: .ne)
        drawCell(width: cellWidth, height: cellHeight)

        a.add(r9, r9, UInt32(cellWidth * 2))
        a.load32(r3, cheatAddress)
        a.ldrb(r2, r3, 0)
        a.strb(r11, r3, 0)
        a.load32(r1, UInt32(topBandColors[0]))
        a.cmp(r2, 0)
        a.movReg(r1, r10, cond: .ne)
        drawCell(width: cellWidth, height: cellHeight)

        // Restore last frame's marker cell, then draw this frame's, or hide it while the pen is up.
        a.ldr(r1, r13, 4)
        a.movReg(r9, r0)
        drawCell(width: markerSize, height: markerSize)
        a.ldr(r2, r13, 0)
        a.and(r1, r2, 0xFF)
        a.lsr(r3, r2, 8)
        a.and(r3, r3, 0xFF)
        a.bic(r1, r1, UInt32(markerSize - 1))
        a.bic(r3, r3, UInt32(markerSize - 1))
        a.load32(r9, 0x06200000)
        a.addReg(r9, r9, r3, lsl: 9) // y * 256 pixels * 2 bytes.
        a.addReg(r9, r9, r1, lsl: 1)
        a.lsr(r12, r1, 6)
        a.ldrIndexed(r12, r14, r12) // The band colour under the cell.
        a.str(r12, r13, 4)
        a.load32(r3, hidden)
        a.tst(r2, 0x400000) // EXTKEYIN bit 6: pen up.
        a.movReg(r9, r3, cond: .ne)
        a.movReg(r0, r9)
        a.mov(r1, 0x8000)
        drawCell(width: markerSize, height: markerSize)

        let rest = a.here
        a.ldrh(r1, r4, 6)
        a.cmp(r1, UInt32(screenHeight))
        a.branch(to: rest, cond: .eq)
        a.branch(to: frame)
        return padded(a.bytes)
    }

    private static func buildARM7() -> [UInt8] {
        var a = ARMAssembler(origin: Int(arm7Address))
        let r0 = 0, r1 = 1, r2 = 2, r3 = 3, r4 = 4, r5 = 5, r6 = 6, r7 = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11

        // VBlank handler, called by the BIOS, which saves r0 to r3. Only acknowledges: the interrupt is
        // there because Action Replay codes run when the ARM7 takes one.
        let handler = a.here
        a.mov(r0, 0x04000000)
        a.mov(r1, 1)
        a.str(r1, r0, 0x214) // IF.
        a.word(0xE12FFF1E) // bx lr
        precondition(a.here == Int(arm7Address) + 16)

        a.mov(r4, 0x04000000)
        a.load32(r5, 0x04000500)
        a.load32(r1, 0x807F) // SOUNDCNT: on, full volume.
        a.strh(r1, r5, 0)
        a.load32(r5, 0x04000480) // Channel 8, the first PSG channel.
        a.load32(r1, toneTimer)
        a.strh(r1, r5, 8)
        a.load32(r1, 0xE340_007F) // Start, PSG, 50% duty, centre, full volume.
        a.str(r1, r5, 0)

        // EEPROM over AUXSPI, which direct boot gives to the ARM7 (EXMEMCNT bit 11). Returns the byte in r2.
        a.load32(r6, 0x040001A0)
        func aux(_ value: UInt32? = nil, register: Int? = nil, hold: Bool = true) {
            a.load32(r1, hold ? 0xA040 : 0xA000) // On, SPI mode, and chip select held until the last byte.
            a.strh(r1, r6, 0)
            if let register { a.movReg(r1, register) } else { a.mov(r1, value ?? 0) }
            a.strh(r1, r6, 2)
            let busy = a.here
            a.ldrh(r1, r6, 0)
            a.tst(r1, 0x80)
            a.branch(to: busy, cond: .ne)
            a.ldrh(r2, r6, 2)
        }
        aux(0x03); aux(0); aux(UInt32(eepromBootCounterOffset)); aux(0, hold: false)
        a.and(r8, r2, 0xFF)
        a.cmp(r8, 0xFF)
        a.mov(r8, 0, cond: .eq) // Erased EEPROM reads 0xFF.
        a.add(r8, r8, 1)
        a.and(r8, r8, 0xFF)
        aux(0x06, hold: false) // Write enable.
        aux(0x02); aux(0); aux(0)
        for byte in eepromMagic { aux(UInt32(byte)) }
        aux(register: r8, hold: false)

        a.load32(r2, 0x0380FFFC) // The BIOS calls the address here on an interrupt.
        a.load32(r1, UInt32(handler))
        a.str(r1, r2, 0)
        a.mov(r1, 8) // DISPSTAT: VBlank IRQ on.
        a.strh(r1, r4, 4)
        a.add(r2, r4, 0x200)
        a.mov(r1, 1)
        a.str(r1, r2, 0x10) // IE: VBlank.
        a.str(r1, r2, 0x08) // IME.
        a.msrControl(0x1F) // System mode, interrupts on.

        a.load32(r9, 0x040001C0)
        a.add(r10, r4, 0x100)
        a.load32(r11, sharedAddress)

        // One touch screen controller conversion: command, then the 12-bit result in two bytes. Pixel in rd.
        func touch(_ command: UInt32, into rd: Int) {
            func transfer(_ value: UInt32) {
                a.mov(r1, value)
                a.strh(r1, r9, 2)
                let busy = a.here
                a.ldrh(r1, r9, 0)
                a.tst(r1, 0x80)
                a.branch(to: busy, cond: .ne)
            }
            a.load32(r1, 0x8A01) // SPICNT: on, touch screen, chip select held, 2 MHz.
            a.strh(r1, r9, 0)
            transfer(command)
            transfer(0)
            a.ldrh(r2, r9, 2) // Result bits 11 to 5.
            a.load32(r1, 0x8201) // Release after the last byte.
            a.strh(r1, r9, 0)
            transfer(0)
            a.ldrh(r3, r9, 2) // Result bits 4 to 0, then zeros.
            a.lsr(r3, r3, 7)
            a.orrReg(rd, r3, r2, lsl: 1) // The result is the pixel times 16.
            a.and(rd, rd, 0xFF)
        }

        let frame = a.here
        a.ldrh(r1, r4, 6) // VCOUNT: once per frame, mid-picture.
        a.cmp(r1, 96)
        a.branch(to: frame, cond: .ne)
        touch(0xD0, into: r7) // X.
        touch(0x90, into: r8) // Y.
        a.ldrh(r2, r10, 0x36) // EXTKEYIN.
        a.orrReg(r1, r7, r8, lsl: 8)
        a.orrReg(r1, r1, r2, lsl: 16)
        a.str(r1, r11, 0)
        let rest = a.here
        a.ldrh(r1, r4, 6)
        a.cmp(r1, 96)
        a.branch(to: rest, cond: .eq)
        a.branch(to: frame)
        return padded(a.bytes)
    }
}
#endif
