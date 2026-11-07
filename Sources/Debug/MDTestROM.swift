#if DEBUG
import Foundation

/// Generates a small homebrew Mega Drive / Genesis ROM, so tests need no commercial game, no Sega BIOS and no
/// TMSS logo. Hand-assembled 68000, 64 KB, with a valid header and checksum. It uses no interrupts: the CPU
/// polls the VDP's VBlank flag. `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - H40 by V28 (320 by 224), plane A: four horizontal bands of solid tiles, 7 tile rows each, in `colors`.
/// - Twelve cells on tile row 1, from tile column 4, in `keyOrder`: white while that button is held, else the
///   band colour. Port 1 is read as a six-button pad, so X, Y, Z and Mode count too.
/// - A square wave on PSG channel 0 at `toneHertz`, at full volume.
/// - Battery SRAM, 8 KB on odd bytes from $200001: "GAGA" at offset 0 and a boot counter at offset 4,
///   incremented once per boot.
/// - Toggle cell, tile column 0 of row 1: pressing A and B together flips it. The flag lives only in register
///   D7, so it proves a save state restored the CPU.
/// - Cheat cell, column 1: lit while the RAM word at `cheatAddress`, cleared at boot, reads non-zero.
/// - Genie cell, column 2: lit while the ROM word at `genieAddress`, normally zero, reads non-zero.
enum MDTestROM {
    static let width = 320
    static let height = 224
    static let sramSize = 8192
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramBootCounterOffset = 4
    /// The PSG's clock, 53693175 Hz / 15, over 32 times the period register.
    static let tonePeriod: UInt16 = 254
    static let toneHertz = 53_693_175.0 / 15 / (32 * Double(tonePeriod))
    static let cheatAddress: UInt32 = 0xFF0000
    static let genieAddress: UInt32 = 0x008000
    /// Mega Drive colour words, 0000 BBB0 GGG0 RRR0: red, green, blue, white. Index 0 is the black backdrop.
    static let colors: [UInt16] = [0x000E, 0x00E0, 0x0E00, 0x0EEE]
    /// The cells' buttons, left to right, as the pad names them.
    static let keyOrder = ["Up", "Down", "Left", "Right", "A", "B", "C", "Start", "X", "Y", "Z", "Mode"]

    private static let keyColumn = 4
    private static let bandRows = 7
    private static let romSize = 0x10000
    private static let origin: UInt32 = 0x200
    private static let vdpData: UInt32 = 0xC00000
    private static let vdpControl: UInt32 = 0xC00004
    private static let psg: UInt32 = 0xC00011
    private static let pad: UInt32 = 0xA10003
    private static let sram: UInt32 = 0x200001

    /// The shade at a pixel, with `keys` as a mask in `keyOrder`: bit 0 is Up.
    static func expectedShade(x: Int, y: Int, keys: UInt32, toggle: Bool = false, cheat: Bool = false, genie: Bool = false) -> Int {
        let column = x / 8, row = y / 8
        if row == 1 {
            if (keyColumn..<(keyColumn + keyOrder.count)).contains(column), keys & (1 << UInt32(column - keyColumn)) != 0 { return 3 }
            if (column == 0 && toggle) || (column == 1 && cheat) || (column == 2 && genie) { return 3 }
        }
        return row / bandRows
    }

    static func build() -> Data {
        var a = Assembler(origin: origin)

        a.w(0x46FC, 0x2700) // move.w #$2700,sr: supervisor, every interrupt masked.
        // VDP: mode 5, display on, no interrupts or DMA, H40, plane A at $C000, plane B at $E000, sprites at
        // $F000, horizontal scroll at $FC00, 64 by 32 planes, step 2, no window.
        for register: UInt16 in [0x8004, 0x8144, 0x8230, 0x8300, 0x8407, 0x8578, 0x8600, 0x8700, 0x8800, 0x8900,
                                 0x8AFF, 0x8B00, 0x8C81, 0x8D3F, 0x8E00, 0x8F02, 0x9001, 0x9100, 0x9200] {
            a.moveW(register, to: vdpControl)
        }
        a.moveL(0xC000_0000, to: vdpControl) // CRAM write, address 0.
        for color in [0x0000] + colors { a.moveW(color, to: vdpData) }

        // Four solid tiles from VRAM $0020: tile n is colour n on every pixel. Tile 0 stays clear.
        a.moveL(0x4020_0000, to: vdpControl)
        for tile: UInt32 in 1...4 {
            a.w(0x203C) // move.l #fill,d0
            a.l(0x1111_1111 * tile)
            a.moveq(7, 1)
            let row = a.here
            a.w(0x23C0) // move.l d0,(data).l
            a.l(vdpData)
            a.dbra(1, to: row)
        }

        // The bands on plane A at $C000: tile n on 7 rows of 64 cells each.
        a.moveL(0x4000_0003, to: vdpControl)
        for tile: UInt16 in 1...4 {
            a.w(0x303C, tile) // move.w #tile,d0
            a.w(0x323C, UInt16(bandRows * 64 - 1)) // move.w #count,d1
            let cell = a.here
            a.w(0x33C0) // move.w d0,(data).l
            a.l(vdpData)
            a.dbra(1, to: cell)
        }

        // PSG: mute all four channels, then channel 0's period and full volume.
        for byte: UInt8 in [0x9F, 0xBF, 0xDF, 0xFF, 0x80 | UInt8(tonePeriod & 0x0F), UInt8(tonePeriod >> 4), 0x90] {
            a.moveB(byte, to: psg)
        }

        // SRAM. A first boot has no magic, whatever the blank bytes hold.
        a.moveB(0x01, to: 0xA130F1) // Map SRAM.
        a.w(0x1039) // move.b sram,d0
        a.l(sram)
        a.w(0x0C00, UInt16(sramMagic[0])) // cmpi.b #'G',d0
        let have = a.forward(0x7) // beq have
        a.moveq(0, 0)
        let store = a.forward(0x0) // bra store
        a.resolve(have)
        a.w(0x1039) // move.b counter,d0
        a.l(sram + UInt32(sramBootCounterOffset) * 2)
        a.resolve(store)
        a.w(0x5200) // addq.b #1,d0
        a.w(0x13C0) // move.b d0,counter
        a.l(sram + UInt32(sramBootCounterOffset) * 2)
        for (offset, byte) in sramMagic.enumerated() { a.moveB(byte, to: sram + UInt32(offset) * 2) }

        a.w(0x4279) // clr.w cheat word: work RAM starts with noise on hardware.
        a.l(cheatAddress)
        a.moveB(0x40, to: 0xA10009) // Port 1: TH is an output.
        a.moveB(0x40, to: pad)
        a.moveq(0, 7) // d7: bit 0 the toggle, bit 1 the chord held last frame.

        let frame = a.here
        // Wait for the end of this VBlank, then the start of the next.
        let inBlank = a.here
        a.w(0x3039) // move.w control,d0
        a.l(vdpControl)
        a.w(0x0800, 3) // btst #3,d0: VBlank.
        a.branch(0x6, to: inBlank) // bne
        let active = a.here
        a.w(0x3039)
        a.l(vdpControl)
        a.w(0x0800, 3)
        a.branch(0x7, to: active) // beq

        // Six-button read. Each rise of TH steps the pad: the first two give the three-button halves, the
        // fourth gives Mode, X, Y and Z. It returns to the start about 1.5 ms after the last rise.
        a.readPad(th: 0x40, into: 1) // d1: C B Right Left Down Up
        a.readPad(th: 0x00, into: 2) // d2: Start A
        for th: UInt8 in [0x40, 0x00, 0x40, 0x00] { a.moveB(th, to: pad) }
        a.readPad(th: 0x40, into: 3) // d3: Mode X Y Z
        a.moveB(0x00, to: pad)
        a.moveB(0x40, to: pad)
        a.w(0x4601, 0x4602, 0x4603) // not.b d1; not.b d2; not.b d3: pressed is now 1.

        // Flip the toggle on the press of the chord only.
        a.w(0x1001, 0xC002) // move.b d1,d0; and.b d2,d0
        a.w(0x0800, 4) // btst #4,d0: B in d1 and A in d2.
        let released = a.forward(0x7) // beq released
        a.w(0x0807, 1) // btst #1,d7
        let held = a.forward(0x6) // bne held: it was down last frame too.
        a.w(0x0A07, 3) // eori.b #3,d7: flip, and mark held.
        let done = a.forward(0x0) // bra done
        a.resolve(released)
        a.w(0x0207, 1) // andi.b #1,d7
        a.resolve(held)
        a.resolve(done)

        // Row 1 from column 0, left to right: toggle, cheat, genie, a band cell, then the keys.
        a.moveL(0x4080_0003, to: vdpControl) // VRAM write at $C080.
        a.cell { $0.w(0x0807, 0) } // btst #0,d7
        a.cell { $0.w(0x4A79); $0.l(cheatAddress) } // tst.w cheat
        a.cell { $0.w(0x4A79); $0.l(genieAddress) } // tst.w genie
        a.cell(nil)
        let bits: [(UInt16, UInt16)] = [(1, 0), (1, 1), (1, 2), (1, 3), (2, 4), (1, 4), (1, 5), (2, 5),
                                        (3, 2), (3, 1), (3, 0), (3, 3)]
        for (register, bit) in bits { a.cell { $0.w(0x0800 | register, bit) } } // btst #bit,dn
        a.branch(0x0, to: frame) // bra frame

        let interrupt = a.here
        a.w(0x4E73) // rte
        return image(code: a.bytes, interrupt: interrupt)
    }

    private static func image(code: [UInt8], interrupt: UInt32) -> Data {
        var rom = [UInt8](repeating: 0, count: romSize)
        precondition(Int(origin) + code.count <= Int(genieAddress), "the program ran into the genie word")
        rom.replaceSubrange(Int(origin)..<(Int(origin) + code.count), with: code)

        func put32(_ offset: Int, _ value: UInt32) {
            rom.replaceSubrange(offset..<(offset + 4), with: [24, 16, 8, 0].map { UInt8((value >> $0) & 0xFF) })
        }
        func text(_ offset: Int, _ string: String, _ length: Int) {
            let bytes = Array(string.utf8)
            rom.replaceSubrange(offset..<(offset + length), with: bytes + [UInt8](repeating: 0x20, count: length - bytes.count))
        }
        put32(0x000, 0x00FF_FE00) // Initial stack pointer.
        put32(0x004, origin) // Reset.
        for vector in stride(from: 0x008, to: 0x100, by: 4) { put32(vector, interrupt) }

        text(0x100, "SEGA MEGA DRIVE", 16)
        text(0x110, "(C)GAGA 2026.NOV", 16)
        text(0x120, "GAGA TEST MD", 48)
        text(0x150, "GAGA TEST MD", 48)
        text(0x180, "GM 00000000-00", 14)
        text(0x190, "J6", 16) // Three- and six-button pads.
        put32(0x1A0, 0)
        put32(0x1A4, UInt32(romSize - 1))
        put32(0x1A8, 0x00FF_0000)
        put32(0x1AC, 0x00FF_FFFF)
        rom.replaceSubrange(0x1B0..<0x1B4, with: [0x52, 0x41, 0xF8, 0x20]) // "RA", battery, odd bytes.
        put32(0x1B4, sram)
        put32(0x1B8, sram + UInt32(sramSize - 1) * 2)
        text(0x1BC, "", 12)
        text(0x1C8, "", 40)
        text(0x1F0, "JUE", 16)

        // The header checksum: the sum of every big-endian word after the header.
        let sum = stride(from: 0x200, to: romSize, by: 2).reduce(UInt16(0)) { $0 &+ (UInt16(rom[$1]) << 8 | UInt16(rom[$1 + 1])) }
        rom[0x18E] = UInt8(sum >> 8)
        rom[0x18F] = UInt8(sum & 0xFF)
        return Data(rom)
    }

    /// Just enough of a 68000 assembler. Operands are absolute long addresses and data registers.
    private struct Assembler {
        let origin: UInt32
        private(set) var bytes: [UInt8] = []
        var here: UInt32 { origin + UInt32(bytes.count) }

        mutating func w(_ words: UInt16...) {
            for word in words { bytes += [UInt8(word >> 8), UInt8(word & 0xFF)] }
        }

        mutating func l(_ value: UInt32) { w(UInt16(value >> 16), UInt16(value & 0xFFFF)) }

        mutating func moveB(_ value: UInt8, to address: UInt32) { w(0x13FC, UInt16(value)); l(address) }
        mutating func moveW(_ value: UInt16, to address: UInt32) { w(0x33FC, value); l(address) }
        mutating func moveL(_ value: UInt32, to address: UInt32) { w(0x23FC); l(value); l(address) }
        mutating func moveq(_ value: Int8, _ register: UInt16) { w(0x7000 | register << 9 | UInt16(UInt8(bitPattern: value))) }

        /// Sets TH, waits two instructions for the pins to settle, then reads the port into a data register.
        mutating func readPad(th: UInt8, into register: UInt16) {
            moveB(th, to: MDTestROM.pad)
            w(0x4E71, 0x4E71) // nop; nop
            w(0x1039 | register << 9) // move.b pad,dn
            l(MDTestROM.pad)
        }

        /// The next map cell: tile 4 (white) if `test` clears Z, else tile 1 (the row's band). With no test,
        /// always the band.
        mutating func cell(_ test: ((inout Assembler) -> Void)?) {
            moveq(1, 0)
            if let test {
                test(&self)
                w(0x6702) // beq.s +2
                moveq(4, 0)
            }
            w(0x33C0) // move.w d0,(data).l
            l(MDTestROM.vdpData)
        }

        mutating func dbra(_ register: UInt16, to target: UInt32) {
            w(0x51C8 | register)
            w(UInt16(bitPattern: Int16(Int(target) - Int(here))))
        }

        /// Bcc.w, PC-relative to the word after the opcode. 0 is bra, 6 bne, 7 beq.
        mutating func branch(_ condition: UInt16, to target: UInt32) {
            w(0x6000 | condition << 8)
            w(UInt16(bitPattern: Int16(Int(target) - Int(here))))
        }

        /// A Bcc.w whose target comes later. Returns where its displacement goes.
        mutating func forward(_ condition: UInt16) -> Int {
            w(0x6000 | condition << 8, 0)
            return bytes.count - 2
        }

        mutating func resolve(_ patch: Int) {
            let delta = UInt16(bytes.count - patch)
            bytes[patch] = UInt8(delta >> 8)
            bytes[patch + 1] = UInt8(delta & 0xFF)
        }
    }
}
#endif
