#if DEBUG
import Foundation

/// Generates a small homebrew Virtual Boy cartridge, so tests need no commercial game and no Nintendo material.
/// Hand-assembled V810. The VIP's drawing engine stays off: the program writes the left and right frame
/// buffers itself, which the display then shows. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What the program does:
/// - Four vertical bands of the four VIP shades, from black to full red.
/// - Sixteen key cells along rows 192 to 207, four to a band. Cells 0 to 13 invert while that pad bit is held:
///   A, B, R, L, right pad Up, right pad Right, left pad Right, Left, Down, Up, Start, Select, right pad Left,
///   right pad Down. Cell 14 is the toggle cell.
/// - VSU channel 1 plays a square wave at about 630 Hz.
/// - Cartridge RAM: "GAGA" at `sramMagicOffset` and a boot counter after it, incremented once per boot.
/// - Pressing A and B together flips the toggle cell. The flag lives in work RAM.
enum VBTestROM {
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramMagicOffset = 0x10
    static let sramCounterOffset = 0x14
    static let size = 0x2000

    // Hardware: VIP frame buffers and registers, VSU, the game pad, work RAM and cartridge RAM.
    private static let leftFB: UInt32 = 0x0000_0000, rightFB: UInt32 = 0x0001_0000
    private static let vipRegisters: UInt32 = 0x0005_F800, vsu: UInt32 = 0x0100_0000
    private static let pad: UInt32 = 0x0200_0000, workRAM: UInt32 = 0x0500_0000, cartRAM: UInt32 = 0x0600_0000
    private static let romBase: UInt32 = 0x0700_0000

    /// A frame buffer column is 64 bytes, four 2-bit pixels to a byte, so a byte of shade s is s * 0x55.
    private static func shadeWord(_ shade: Int) -> UInt32 { UInt32(shade) * 0x5555_5555 }

    static func build() -> Data {
        var a = V810Assembler()
        let (r1, r2, r3, r5, r10, r11, r12, r13) = (1, 2, 3, 5, 10, 11, 12, 13)
        let (vsuReg, vipReg, ramReg, padReg, wramReg, previous) = (20, 21, 22, 23, 25, 24)

        // Sound: wave 0 is a square wave, channel 1 plays it at full volume with no envelope.
        a.load32(vsu, vsuReg)
        a.movea(0x3F, plus: 0, r1)
        for sample in 0..<32 { a.store(.byte, sample < 16 ? r1 : 0, Int16(sample * 4), vsuReg) }
        for (offset, value) in [(0x404, 0xFF), (0x408, 1800 & 0xFF), (0x40C, 1800 >> 8), (0x410, 0xF0), (0x414, 0),
                                (0x418, 0), (0x400, 0x80)] {
            a.movea(Int16(value), plus: 0, r1)
            a.store(.byte, r1, Int16(offset), vsuReg)
        }

        // Shades 1 to 3 at BRTA 32, BRTB 64 and BRTC 32: a quarter, a half and full. The display is on.
        a.load32(vipRegisters, vipReg)
        for (offset, value) in [(0x24, 32), (0x26, 64), (0x28, 32), (0x22, 2)] {
            a.movea(Int16(value), plus: 0, r1)
            a.store(.half, r1, Int16(offset), vipReg)
        }

        // Boot counter in cartridge RAM, after "GAGA", which a new cartridge RAM gets first.
        a.load32(cartRAM, ramReg)
        var mismatches: [Int] = []
        for (index, byte) in sramMagic.enumerated() {
            a.load(.byte, Int16(sramMagicOffset + index), ramReg, r1)
            a.movea(Int16(byte), plus: 0, r2)
            a.cmp(r2, r1)
            mismatches.append(a.branch(.ne))
        }
        let counted = a.branch(.always)
        let fresh = a.here
        for index in mismatches { a.patch(index, to: fresh) }
        for (index, byte) in sramMagic.enumerated() {
            a.movea(Int16(byte), plus: 0, r1)
            a.store(.byte, r1, Int16(sramMagicOffset + index), ramReg)
        }
        a.store(.byte, 0, Int16(sramCounterOffset), ramReg)
        a.patch(counted, to: a.here)
        a.load(.byte, Int16(sramCounterOffset), ramReg, r1)
        a.addImmediate(1, r1)
        a.store(.byte, r1, Int16(sramCounterOffset), ramReg)

        // Bands: 96 columns of 16 words each, in both eyes.
        for eye in [leftFB, rightFB] {
            a.load32(eye, r10)
            for shade in 0..<4 {
                a.load32(shadeWord(shade), r12)
                a.movea(96 * 16, plus: 0, r13)
                let loop = a.here
                a.store(.word, r12, 0, r10)
                a.addImmediate(4, r10)
                a.addImmediate(-1, r13)
                a.patch(a.branch(.ne), to: loop)
            }
        }

        a.load32(pad, padReg)
        a.load32(workRAM, wramReg)
        a.mov(0, previous)
        let main = a.here
        // The pad, in bits 2 to 15: A, B, R, L, then the rest in the order the cells list them. A hardware
        // read starts from SCR and is done when its SI_STAT bit clears, as on the console.
        a.movea(4, plus: 0, r2)
        a.store(.byte, r2, 0x28, padReg)
        let reading = a.here
        a.load(.byte, 0x28, padReg, r2)
        a.andi(2, r2, r2)
        a.patch(a.branch(.ne), to: reading)
        a.load(.byte, 0x10, padReg, r1)
        a.andi(0xFF, r1, r1)
        a.load(.byte, 0x14, padReg, r2)
        a.andi(0xFF, r2, r2)
        a.shlImmediate(8, r2)
        a.or(r2, r1)

        // A and B flip the toggle once per press.
        a.andi(0x0C, r1, r3)
        a.cmpImmediate(0x0C, r3)
        let notChord = a.branch(.ne)
        a.cmpImmediate(0, previous)
        let held = a.branch(.ne)
        a.load(.word, 0, wramReg, r3)
        a.xori(1, r3, r3)
        a.store(.word, r3, 0, wramReg)
        a.patch(held, to: a.here)
        a.movImmediate(1, previous)
        let chordDone = a.branch(.always)
        a.patch(notChord, to: a.here)
        a.mov(0, previous)
        a.patch(chordDone, to: a.here)

        // Cells: 12 columns wide, from column 6 of each band, 24 apart, rows 192 to 207 (bytes 48 to 51).
        for cell in 0..<15 {
            let band = cell / 4, column = band * 96 + 6 + (cell % 4) * 24
            if cell < 14 {
                a.andi(UInt16(1 << (cell + 2)), r1, r3)
            } else {
                a.load(.word, 0, wramReg, r3)
                a.andi(1, r3, r3)
            }
            a.load32(shadeWord(band), r5)
            let off = a.branch(.eq)
            a.not(r5, r5)
            a.patch(off, to: a.here)
            a.load32(leftFB + UInt32(column * 64 + 48), r10)
            a.movhi(1, r10, r11) // The right eye, 0x10000 on.
            for step in 0..<12 {
                a.store(.word, r5, Int16(step * 64), r10)
                a.store(.word, r5, Int16(step * 64), r11)
            }
        }
        a.jump(to: main)

        // Reset enters at 0xFFFFFFF0, the last 16 bytes of the ROM's mirror.
        var reset = V810Assembler()
        reset.load32(romBase, r1)
        reset.jmp(r1)
        precondition(a.bytes.count <= size - 0x220, "the program reached the cartridge header")
        var rom = a.bytes + [UInt8](repeating: 0xFF, count: size - a.bytes.count)
        let title = Array("GAGAEMU TEST".utf8)
        rom.replaceSubrange((size - 0x220)..<(size - 0x220 + title.count), with: title)
        rom.replaceSubrange((size - 16)..<(size - 16 + reset.bytes.count), with: reset.bytes)
        return Data(rom)
    }
}

/// Just enough V810 for the test cartridge. Instructions are little-endian halfwords, opcode first.
struct V810Assembler {
    enum Width { case byte, half, word }
    enum Condition: UInt16 { case eq = 2, always = 5, ne = 10 }

    private(set) var bytes: [UInt8] = []
    var here: Int { bytes.count }

    private mutating func half(_ value: UInt16) { bytes += [UInt8(value & 0xFF), UInt8(value >> 8)] }
    private mutating func format1(_ op: UInt16, _ reg1: Int, _ reg2: Int) { half(op << 10 | UInt16(reg2) << 5 | UInt16(reg1)) }
    private mutating func format5(_ op: UInt16, _ reg1: Int, _ reg2: Int, _ imm: UInt16) {
        format1(op, reg1, reg2)
        half(imm)
    }

    /// reg2 = reg1 (Format I and II register first, then destination, as the V810 manual writes them).
    mutating func mov(_ reg1: Int, _ reg2: Int) { format1(0x00, reg1, reg2) }
    mutating func cmp(_ reg1: Int, _ reg2: Int) { format1(0x03, reg1, reg2) }
    mutating func jmp(_ reg1: Int) { format1(0x06, reg1, 0) }
    mutating func or(_ reg1: Int, _ reg2: Int) { format1(0x0C, reg1, reg2) }
    mutating func not(_ reg1: Int, _ reg2: Int) { format1(0x0F, reg1, reg2) }
    mutating func movImmediate(_ imm: Int, _ reg2: Int) { format1(0x10, Int(UInt16(bitPattern: Int16(imm)) & 0x1F), reg2) }
    mutating func addImmediate(_ imm: Int, _ reg2: Int) { format1(0x11, Int(UInt16(bitPattern: Int16(imm)) & 0x1F), reg2) }
    mutating func cmpImmediate(_ imm: Int, _ reg2: Int) { format1(0x13, Int(UInt16(bitPattern: Int16(imm)) & 0x1F), reg2) }
    mutating func shlImmediate(_ imm: Int, _ reg2: Int) { format1(0x14, imm & 0x1F, reg2) }
    /// reg2 = reg1 + sign-extended imm.
    mutating func movea(_ imm: Int16, plus reg1: Int, _ reg2: Int) { format5(0x28, reg1, reg2, UInt16(bitPattern: imm)) }
    mutating func andi(_ imm: UInt16, _ reg1: Int, _ reg2: Int) { format5(0x2D, reg1, reg2, imm) }
    mutating func xori(_ imm: UInt16, _ reg1: Int, _ reg2: Int) { format5(0x2E, reg1, reg2, imm) }
    /// reg2 = reg1 + imm << 16.
    mutating func movhi(_ imm: UInt16, _ reg1: Int, _ reg2: Int) { format5(0x2F, reg1, reg2, imm) }

    mutating func load32(_ value: UInt32, _ reg: Int) {
        movhi(UInt16(truncatingIfNeeded: (value &+ 0x8000) >> 16), 0, reg)
        movea(Int16(bitPattern: UInt16(value & 0xFFFF)), plus: reg, reg)
    }

    /// reg2 = [reg1 + disp], sign-extended.
    mutating func load(_ width: Width, _ disp: Int16, _ reg1: Int, _ reg2: Int) {
        format5([.byte: 0x30, .half: 0x31, .word: 0x33][width]!, reg1, reg2, UInt16(bitPattern: disp))
    }

    /// [reg1 + disp] = reg2.
    mutating func store(_ width: Width, _ reg2: Int, _ disp: Int16, _ reg1: Int) {
        format5([.byte: 0x34, .half: 0x35, .word: 0x37][width]!, reg1, reg2, UInt16(bitPattern: disp))
    }

    /// A Format III branch with its displacement left for `patch`. Returns where it is.
    mutating func branch(_ condition: Condition) -> Int {
        let at = here
        half(0x8000 | condition.rawValue << 9)
        return at
    }

    mutating func patch(_ at: Int, to target: Int) {
        let disp = target - at
        precondition(disp % 2 == 0 && disp >= -256 && disp < 256, "branch out of range")
        bytes[at] = UInt8(UInt16(bitPattern: Int16(disp)) & 0xFF)
        bytes[at + 1] = (bytes[at + 1] & 0xFE) | UInt8((UInt16(bitPattern: Int16(disp)) >> 8) & 1)
    }

    /// JR, relative over the whole address space.
    mutating func jump(to target: Int) {
        let disp = UInt32(bitPattern: Int32(target - here)) & 0x3FF_FFFF
        half(0x2A << 10 | UInt16(disp >> 16))
        half(UInt16(disp & 0xFFFF))
    }
}
#endif
