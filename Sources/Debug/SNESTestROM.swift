#if DEBUG
import Foundation

/// Generates a small homebrew Super Famicom ROM, so tests need no commercial game, no Nintendo material and
/// no coprocessor firmware. Hand-assembled 65816 and SPC700, LoROM, 32 KB, with a valid internal header
/// and checksum. `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - Mode 0, BG1: four horizontal bands of solid tiles, 7 tile rows each, in `colors`.
/// - Twelve cells on tile row 1, from tile column 4, in `keyOrder`: white while that button is held, else
///   the band colour.
/// - Waits for each frame on the VBlank NMI with WAI, so it hangs if NMI does not work, and reads the pad
///   through auto-joypad read.
/// - Uploads a 281-byte SPC700 program through the sound CPU's boot protocol. It plays a looping square
///   wave of BRR samples on DSP voice 0, at `toneHertz`.
/// - Battery SRAM at $70:0000: "GAGA" at offset 0, and a boot counter at offset 4, incremented once per boot.
/// - Toggle cell, tile column 0 of row 1: pressing A and B together flips it. The flag lives only in
///   register Y, so it proves a save state restored the CPU.
/// - Cheat cell, column 1: lit while the WRAM byte at `cheatAddress`, cleared at boot, reads non-zero. bsnes
///   writes a code's value every frame and puts the old byte back when it is turned off. The program never
///   writes the byte again, so turning a code off checks that the old byte came back.
/// - Genie cell, column 2: lit while the ROM byte at `genieAddress`, normally zero, reads non-zero.
enum SNESTestROM {
    static let width = 256
    static let height = 224
    static let sramSize = 8192
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramBootCounterOffset = 4
    /// The DSP's 32 kHz times pitch 0x0400 / 0x1000, over the 16 samples of one period.
    static let toneHertz = 32000.0 * Double(0x0400) / 4096 / 16
    static let cheatAddress: UInt32 = 0x7E0000
    static let genieAddress: UInt32 = 0x00F000
    /// BGR555: red, green, blue, white.
    static let colors: [UInt16] = [0x001F, 0x03E0, 0x7C00, 0x7FFF]
    /// The cells' buttons, left to right, as the joypad registers name them.
    static let keyOrder = ["B", "Y", "Select", "Start", "Up", "Down", "Left", "Right", "A", "X", "L", "R"]

    private static let keyColumn = 4
    private static let bandRows = 7
    private static let tileMap: UInt16 = 0x0400 // VRAM word address.
    private static let spcData: UInt16 = 0xC000 // ROM file offset 0x4000.
    private static let spcLoad: UInt16 = 0x0200

    /// The shade at a pixel, with `keys` as a mask in `keyOrder`: bit 0 is B.
    static func expectedShade(x: Int, y: Int, keys: UInt32, toggle: Bool = false, cheat: Bool = false, genie: Bool = false) -> Int {
        let column = x / 8, row = y / 8
        if row == 1 {
            if (keyColumn..<(keyColumn + keyOrder.count)).contains(column), keys & (1 << UInt32(column - keyColumn)) != 0 { return 3 }
            if (column == 0 && toggle) || (column == 1 && cheat) || (column == 2 && genie) { return 3 }
        }
        return row / bandRows
    }

    static func build() -> Data {
        var a = Assembler()

        a.emit(0x78, 0x18, 0xFB) // sei; clc; xce: native mode.
        a.emit(0xC2, 0x30) // rep #$30
        a.emit(0xA9, 0x00, 0x00) // lda #$0000: B, the accumulator's top byte, stays 0 from here.
        a.emit(0xA2, 0xFF, 0x1F, 0x9A) // ldx #$1FFF; txs
        a.emit(0xA0, 0x00, 0x00) // ldy #0: bit 0 the toggle, bit 1 the chord held last frame.
        a.emit(0xE2, 0x20) // sep #$20: 8-bit A, 16-bit X and Y.
        a.store(0x2100, 0x80) // INIDISP: forced blank.
        for register: UInt16 in [0x4200, 0x2101, 0x2105, 0x2106, 0x210B, 0x2123, 0x2124, 0x2125, 0x212D,
                                 0x212E, 0x212F, 0x2130, 0x2131, 0x2133] {
            a.emit16(0x9C, register) // stz: NMI off, mode 0, no mosaic, windows, colour maths or subscreen.
        }
        a.store(0x2107, UInt8(tileMap >> 8)) // BG1SC: map at word 0x0400, 32 by 32.
        a.store(0x212C, 0x01) // TM: BG1 only.
        a.emit16(0x9C, 0x210D)
        a.emit16(0x9C, 0x210D) // BG1HOFS = 0
        a.store(0x210E, 0xFF)
        a.store(0x210E, 0x03) // BG1VOFS = -1: the first line shown is tile row 0's first line.

        a.emit16(0x9C, 0x2121) // CGADD = 0
        for color in colors {
            a.store(0x2122, UInt8(color & 0xFF))
            a.store(0x2122, UInt8(color >> 8))
        }

        // Four solid 2bpp tiles at VRAM word 0: tile n is colour n on every pixel.
        a.store(0x2115, 0x80) // VMAIN: step after the high byte.
        a.emit16(0x9C, 0x2116)
        a.emit16(0x9C, 0x2117)
        for tile in 0..<4 {
            for _ in 0..<8 {
                a.store(0x2118, tile & 1 != 0 ? 0xFF : 0x00)
                a.store(0x2119, tile & 2 != 0 ? 0xFF : 0x00)
            }
        }

        // The bands: tile n, palette 0, on 7 rows of 32 each.
        a.setVRAMAddress(tileMap)
        for shade in 0..<4 {
            a.emit(0xA2, UInt8(bandRows * 32), 0x00) // ldx #224
            let fill = a.here
            a.store(0x2118, UInt8(shade))
            a.emit16(0x9C, 0x2119)
            a.emit(0xCA) // dex
            a.branch(0xD0, to: fill) // bne
        }

        uploadSound(&a)

        // SRAM. A first boot has no magic, whatever the erased bytes hold.
        a.emitLong(0xAF, 0x700000) // lda $700000
        a.emit(0xC9, sramMagic[0]) // cmp #'G'
        let have = a.forward(0xF0) // beq have
        a.emit(0xA9, 0x00) // lda #0
        let store = a.forward(0x80) // bra store
        a.resolve(have)
        a.emitLong(0xAF, 0x700000 + UInt32(sramBootCounterOffset)) // lda counter
        a.resolve(store)
        a.emit(0x1A) // inc a
        a.emitLong(0x8F, 0x700000 + UInt32(sramBootCounterOffset)) // sta counter
        for (offset, byte) in sramMagic.enumerated() {
            a.emit(0xA9, byte)
            a.emitLong(0x8F, 0x700000 + UInt32(offset))
        }

        a.emit(0xA9, 0x00)
        a.emitLong(0x8F, cheatAddress) // WRAM starts with noise.
        a.store(0x2100, 0x0F) // INIDISP: on, full brightness.
        a.store(0x4200, 0x81) // NMITIMEN: NMI and auto-joypad read.

        let frame = a.here
        a.emit(0xCB) // wai
        // The auto-joypad read starts a few dots after NMI, so wait for it to start, then to finish.
        let joypadStart = a.here
        a.emit16(0xAD, 0x4212) // lda HVBJOY
        a.emit(0x29, 0x01) // and #1: auto-joypad read busy.
        a.branch(0xF0, to: joypadStart)
        let joypadEnd = a.here
        a.emit16(0xAD, 0x4212)
        a.emit(0x29, 0x01)
        a.branch(0xD0, to: joypadEnd)

        // Flip the toggle on the press of the chord only.
        a.emit16(0xAD, 0x4218) // lda JOY1L: A X L R
        a.emit16(0x2D, 0x4219) // and JOY1H: B Y Select Start Up Down Left Right
        a.emit(0x29, 0x80) // and #$80: A and B both held.
        let released = a.forward(0xF0) // beq released
        a.emit(0x98, 0x89, 0x02) // tya; bit #2
        let held = a.forward(0xD0) // bne held: it was down last frame too.
        a.emit(0x49, 0x03, 0xA8) // eor #3; tay: flip, and mark held.
        let done = a.forward(0x80) // bra done
        a.resolve(released)
        a.emit(0x98, 0x29, 0x01, 0xA8) // tya; and #1; tay
        a.resolve(held)
        a.resolve(done)

        // Row 1 from column 0, left to right: toggle, cheat, genie, a band cell, then the keys.
        a.setVRAMAddress(tileMap + 32)
        a.emit(0x98, 0x29, 0x01) // tya; and #1
        a.cell()
        a.emitLong(0xAF, cheatAddress) // lda cheat byte
        a.cell()
        a.emitLong(0xAF, genieAddress) // lda ROM byte
        a.cell()
        a.emit(0xA9, 0x00)
        a.cell()
        let masks: [(UInt16, UInt8)] = [(0x4219, 0x80), (0x4219, 0x40), (0x4219, 0x20), (0x4219, 0x10),
                                        (0x4219, 0x08), (0x4219, 0x04), (0x4219, 0x02), (0x4219, 0x01),
                                        (0x4218, 0x80), (0x4218, 0x40), (0x4218, 0x20), (0x4218, 0x10)]
        for (register, mask) in masks {
            a.emit16(0xAD, register)
            a.emit(0x29, mask)
            a.cell()
        }
        a.emit16(0x4C, frame) // jmp frame

        let interrupt = a.here
        a.emit(0x40) // rti

        return image(code: a.bytes, interrupt: interrupt)
    }

    /// The boot protocol of the sound CPU's own boot program: one block to `spcLoad`, then run it.
    private static func uploadSound(_ a: inout Assembler) {
        let program = spcProgram()
        let end = UInt8((program.count + 2) & 0xFF)
        precondition(end != 0 && program.count < 0x10000, "the run command needs a non-zero index two past the last")

        let ready = a.here
        a.emit16(0xAD, 0x2140) // lda APUIO0
        a.emit(0xC9, 0xAA) // cmp #$AA
        a.branch(0xD0, to: ready)
        let ready2 = a.here
        a.emit16(0xAD, 0x2141)
        a.emit(0xC9, 0xBB) // cmp #$BB
        a.branch(0xD0, to: ready2)
        a.store(0x2142, UInt8(spcLoad & 0xFF))
        a.store(0x2143, UInt8(spcLoad >> 8))
        a.store(0x2141, 0x01) // A block follows.
        a.store(0x2140, 0xCC)
        let kick = a.here
        a.emit16(0xCD, 0x2140) // cmp APUIO0
        a.branch(0xD0, to: kick)

        a.emit(0xA2, 0x00, 0x00) // ldx #0
        let byte = a.here
        a.emit16(0xBD, spcData) // lda data,x
        a.emit16(0x8D, 0x2141)
        a.emit(0x8A) // txa: the index's low byte.
        a.emit16(0x8D, 0x2140)
        let echo = a.here
        a.emit16(0xCD, 0x2140)
        a.branch(0xD0, to: echo)
        a.emit(0xE8) // inx
        a.emit16(0xE0, UInt16(program.count)) // cpx #count
        a.branch(0xD0, to: byte)

        a.store(0x2142, UInt8(spcLoad & 0xFF))
        a.store(0x2143, UInt8(spcLoad >> 8))
        a.emit16(0x9C, 0x2141) // No more blocks: run from the address.
        a.store(0x2140, end)
        let run = a.here
        a.emit16(0xCD, 0x2140)
        a.branch(0xD0, to: run)
    }

    /// SPC700 code at $0200, the sample directory at $0300, and one BRR block at $0310.
    static func spcProgram() -> [UInt8] {
        var code: [UInt8] = []
        let dsp: [(UInt8, UInt8)] = [
            (0x6C, 0x20), // FLG: unmuted, echo writes off.
            (0x0C, 0x7F), (0x1C, 0x7F), // Main volume.
            (0x2C, 0x00), (0x3C, 0x00), (0x4D, 0x00), (0x3D, 0x00), (0x2D, 0x00), // No echo, noise or modulation.
            (0x5D, 0x03), // DIR: page 3.
            (0x00, 0x7F), (0x01, 0x7F), // Voice 0 volume.
            (0x02, 0x00), (0x03, 0x04), // Pitch 0x0400.
            (0x04, 0x00), // Sample 0.
            (0x05, 0x00), (0x07, 0x7F), // GAIN mode, direct, full.
            (0x5C, 0x00), (0x4C, 0x01), // Key on voice 0.
        ]
        for (register, value) in dsp {
            code += [0x8F, register, 0xF2, 0x8F, value, 0xF3] // mov $F2,#reg; mov $F3,#value
        }
        code += [0x2F, 0xFE] // bra self
        var image = [UInt8](repeating: 0, count: 0x119)
        image.replaceSubrange(0..<code.count, with: code)
        image.replaceSubrange(0x100..<0x104, with: [0x10, 0x03, 0x10, 0x03]) // Start and loop at $0310.
        // Range 10, filter 0, loop and end: eight samples at +7, then eight at -8. At range 12 the DSP's
        // interpolation overflows on the negative half and the wave wraps.
        image.replaceSubrange(0x110..<0x119, with: [0xA3,0x77, 0x77, 0x77, 0x77, 0x88, 0x88, 0x88, 0x88])
        return image
    }

    /// 32 KB LoROM with 8 KB of battery SRAM. Code from $8000, sound data at $C000, vectors at $FFE0.
    private static func image(code: [UInt8], interrupt: UInt16) -> Data {
        var rom = [UInt8](repeating: 0, count: 0x8000)
        precondition(code.count <= Int(spcData) - 0x8000, "the program ran into its data")
        rom.replaceSubrange(0..<code.count, with: code)
        let sound = spcProgram()
        rom.replaceSubrange(Int(spcData - 0x8000)..<(Int(spcData - 0x8000) + sound.count), with: sound)
        precondition(rom[Int(genieAddress) - 0x8000] == 0)

        let header = 0x7FC0
        rom.replaceSubrange(header..<(header + 21), with: Array("GAGA TEST SNES".utf8) + [UInt8](repeating: 0x20, count: 7))
        rom[0x7FD5] = 0x20 // LoROM, slow ROM.
        rom[0x7FD6] = 0x02 // ROM, RAM and battery.
        rom[0x7FD7] = 0x05 // 32 KB.
        rom[0x7FD8] = 0x03 // 8 KB.
        rom[0x7FD9] = 0x01 // North America: NTSC.
        for vector in [0x7FE4, 0x7FE6, 0x7FE8, 0x7FEA, 0x7FEE, 0x7FF4, 0x7FF8, 0x7FFA, 0x7FFE] {
            rom[vector] = UInt8(interrupt & 0xFF) // COP, BRK, ABORT, NMI, IRQ, then the emulation-mode ones.
            rom[vector + 1] = UInt8(interrupt >> 8)
        }
        rom[0x7FFC] = 0x00 // RESET: $8000.
        rom[0x7FFD] = 0x80

        rom.replaceSubrange(0x7FDC..<0x7FE0, with: [0xFF, 0xFF, 0x00, 0x00])
        let sum = rom.reduce(UInt16(0)) { $0 &+ UInt16($1) }
        rom.replaceSubrange(0x7FDC..<0x7FE0, with: [UInt8(~sum & 0xFF), UInt8(~sum >> 8), UInt8(sum & 0xFF), UInt8(sum >> 8)])
        return Data(rom)
    }

    /// Just enough of a 65816 assembler, for 8-bit A and 16-bit X and Y. Addresses are bank 0 bus addresses.
    private struct Assembler {
        private(set) var bytes: [UInt8] = []
        var here: UInt16 { 0x8000 + UInt16(bytes.count) }

        mutating func emit(_ values: UInt8...) { bytes += values }

        /// An opcode and a little-endian 16-bit operand.
        mutating func emit16(_ opcode: UInt8, _ value: UInt16) {
            bytes += [opcode, UInt8(value & 0xFF), UInt8(value >> 8)]
        }

        /// An opcode and a 24-bit operand.
        mutating func emitLong(_ opcode: UInt8, _ address: UInt32) {
            bytes += [opcode, UInt8(address & 0xFF), UInt8((address >> 8) & 0xFF), UInt8(address >> 16)]
        }

        /// lda #value; sta register
        mutating func store(_ register: UInt16, _ value: UInt8) {
            emit(0xA9, value)
            emit16(0x8D, register)
        }

        mutating func setVRAMAddress(_ word: UInt16) {
            store(0x2116, UInt8(word & 0xFF))
            store(0x2117, UInt8(word >> 8))
        }

        /// Writes the next map cell: tile 3 if A is non-zero, else tile 0. VRAM steps on the high byte.
        mutating func cell() {
            emit(0xF0, 0x02, 0xA9, 0x03) // beq +2; lda #3
            emit16(0x8D, 0x2118)
            emit16(0x9C, 0x2119)
        }

        mutating func branch(_ opcode: UInt8, to target: UInt16) {
            let delta = Int(target) - (Int(here) + 2)
            precondition((-128...127).contains(delta), "branch out of range")
            bytes += [opcode, UInt8(bitPattern: Int8(delta))]
        }

        /// A branch whose target comes later. Returns where its offset goes.
        mutating func forward(_ opcode: UInt8) -> Int {
            bytes += [opcode, 0]
            return bytes.count - 1
        }

        mutating func resolve(_ patch: Int) {
            let delta = bytes.count - (patch + 1)
            precondition(delta <= 127, "branch out of range")
            bytes[patch] = UInt8(delta)
        }
    }
}
#endif
