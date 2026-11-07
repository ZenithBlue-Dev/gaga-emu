#if DEBUG
import Foundation

/// Generates a small homebrew NES ROM, so tests need no commercial game and no Nintendo material.
/// Hand-assembled 6502 in an iNES 1.0 image: mapper 0, 16 KB PRG at 0xC000, 8 KB CHR, no trainer.
/// `battery: true` only sets the header's battery flag, which gives the cartridge 8 KB of battery RAM at
/// 0x6000. Without it those writes go nowhere. `scripts/make-test-rom.sh` writes the battery image.
///
/// What the program does, in the 256 x 224 picture the core shows (8 lines cropped top and bottom):
/// - Four horizontal bands of background tiles, in palette colours 0 to 3 (`palette`).
/// - Eight cells on tile row 2, from tile column 4: colour 3 while that joypad bit is held, else the band.
/// - Waits for the NMI each frame, so it hangs if VBlank interrupts do not work.
/// - Pulse channel 1 plays a steady square tone at about 440 Hz.
/// - Battery RAM: "GAGA" at offset 0, and a boot counter at offset 4, incremented once per boot.
/// - Toggle cell, column 0 of row 2: pressing A and B together flips it. The flag lives only in register
///   Y, so it proves a save state restored the CPU.
/// - Cheat cell, column 1: lit for a frame after anything writes a non-zero byte to `cheatAddress`, which
///   the program clears each frame, so a RAM code shows while it is on and stops when it is off.
/// - Genie cell, column 2: lit while the ROM byte at `genieAddress`, normally zero, reads non-zero.
enum NESTestROM {
    static let width = 256
    static let height = 224
    static let sramSize = 8192
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramBootCounterOffset = 4
    /// NES palette entries for colours 0 to 3: black, red, green, white.
    static let palette: [UInt8] = [0x0F, 0x16, 0x1A, 0x30]
    private static let toneTimer: UInt16 = 253
    static let toneHertz = 236_250_000.0 / 132 / 16 / Double(toneTimer + 1)
    static let cheatAddress: UInt16 = 0x0300
    static let genieAddress: UInt16 = 0xE000
    static let chord: UInt32 = 0x03 // A and B, in joypad order.

    private static let keyColumn = 4
    private static let keyCount = 8
    private static let cellRow = 2
    private static let cropTop = 8
    private static let origin: UInt16 = 0xC000
    private static let bands: [(tile: UInt8, tiles: Int)] = [(0, 256), (1, 256), (2, 256), (3, 192)]

    /// The palette colour (0 to 3) at a pixel, with `keys` as a joypad-order mask: A, B, Select, Start,
    /// Up, Down, Left, Right.
    static func expectedColor(x: Int, y: Int, keys: UInt32, toggle: Bool = false, cheat: Bool = false, genie: Bool = false) -> Int {
        let column = x / 8, row = (y + cropTop) / 8
        if row == cellRow {
            if (keyColumn..<(keyColumn + keyCount)).contains(column), keys & (1 << UInt32(column - keyColumn)) != 0 { return 3 }
            if (column == 0 && toggle) || (column == 1 && cheat) || (column == 2 && genie) { return 3 }
        }
        return min(row / 8, 3)
    }

    static func build(battery: Bool = true) -> Data {
        var a = Assembler()
        let paletteTable: UInt16 = 0xD000

        a.emit(0x78, 0xD8) // sei; cld
        a.emit(0xA2, 0xFF, 0x9A, 0xE8) // ldx #$FF; txs; inx
        a.abs(0x8E, 0x2000) // stx PPUCTRL: no NMI yet.
        a.abs(0x8E, 0x2001) // stx PPUMASK: rendering off.
        a.abs(0x8E, 0x4010) // stx DMC: no IRQ.
        a.emit(0xA9, 0x40)
        a.abs(0x8D, 0x4017) // APU frame counter: no IRQ.
        a.abs(0x2C, 0x2002) // bit PPUSTATUS: clear the VBlank flag.
        a.waitVBlank()

        a.emit(0xA9, 0x00) // lda #0. X is 0.
        let clear = a.here
        for page in 0..<8 { a.abs(0x9D, UInt16(page) << 8) } // sta page,x
        a.emit(0xE8) // inx
        a.branch(0xD0, clear) // bne
        a.waitVBlank() // The PPU takes writes after its second VBlank.

        a.ppuAddress(0x3F00)
        a.emit(0xA2, 0x00) // ldx #0
        let colors = a.here
        a.abs(0xBD, paletteTable) // lda table,x
        a.abs(0x8D, 0x2007)
        a.emit(0xE8, 0xE0, 32) // inx; cpx #32
        a.branch(0xD0, colors)

        a.ppuAddress(0x2000)
        for band in bands + [(tile: 0, tiles: 64)] { // The last 64 bytes are the attributes: palette 0.
            a.emit(0xA9, band.tile, 0xA2, UInt8(band.tiles & 0xFF)) // lda #tile; ldx #count (0 is 256)
            let fill = a.here
            a.abs(0x8D, 0x2007)
            a.emit(0xCA) // dex
            a.branch(0xD0, fill)
        }

        a.store(0x4015, 0x01) // Pulse 1 on.
        a.store(0x4000, 0xBF) // 50% duty, length counter halted, constant volume 15.
        a.store(0x4001, 0x08) // No sweep.
        a.store(0x4002, UInt8(toneTimer & 0xFF))
        a.store(0x4003, UInt8(toneTimer >> 8)) // Starts the note.

        // Battery RAM. A first boot has no magic, whatever the erased bytes hold.
        a.emit(0xA2, 0x00) // ldx #0
        a.abs(0xAD, 0x6000) // lda $6000
        a.emit(0xC9, sramMagic[0], 0xD0, 3) // cmp #'G'; bne +3
        a.abs(0xAE, 0x6000 + UInt16(sramBootCounterOffset)) // ldx counter
        a.emit(0xE8) // inx
        a.abs(0x8E, 0x6000 + UInt16(sramBootCounterOffset)) // stx counter
        for (offset, byte) in sramMagic.enumerated() { a.store(0x6000 + UInt16(offset), byte) }

        a.waitVBlank()
        a.scrollHome()
        a.store(0x2001, 0x0A) // Background on, including the left 8 pixels.
        a.emit(0xA0, 0x00) // ldy #0. Bit 0: the toggle. Bit 1: the chord was held last frame.

        let frame = a.here
        a.emit(0xA9, 0x00, 0x85, 0x10) // lda #0; sta $10
        let wait = a.here
        a.emit(0xA5, 0x10) // lda $10: the NMI sets it.
        a.branch(0xF0, wait) // beq

        // Joypad 1 into $11, A in bit 0.
        a.store(0x4016, 0x01)
        a.store(0x4016, 0x00)
        a.emit(0xA2, 0x08) // ldx #8
        let read = a.here
        a.abs(0xAD, 0x4016)
        a.emit(0x4A, 0x66, 0x11, 0xCA) // lsr a; ror $11; dex
        a.branch(0xD0, read)

        // The key cells. Band 0 is colour 0, so an unlit cell is tile 0.
        a.ppuAddress(0x2000 + UInt16(cellRow * 32 + keyColumn))
        a.emit(0xA5, 0x11, 0x85, 0x12, 0xA2, UInt8(keyCount)) // lda $11; sta $12; ldx #count
        let cell = a.here
        a.emit(0xA9, 0x00, 0x46, 0x12, 0x90, 0x02, 0xA9, 0x03) // lda #0; lsr $12; bcc +2; lda #3
        a.abs(0x8D, 0x2007)
        a.emit(0xCA) // dex
        a.branch(0xD0, cell)

        // Flip the toggle on the press of the chord only.
        a.emit(0xA2, 0x00, 0xA5, 0x11, 0x29, UInt8(chord), 0xC9, UInt8(chord)) // ldx #0; lda $11; and; cmp
        a.emit(0xD0, 0x02, 0xA2, 0x02, 0x86, 0x13) // bne +2; ldx #2; stx $13: held now, in bit 1.
        a.emit(0x98, 0x29, 0x02, 0x49, 0x02, 0x25, 0x13) // tya; and #2; eor #2; and $13: pressed this frame.
        a.emit(0xF0, 0x04, 0x98, 0x49, 0x01, 0xA8) // beq +4; tya; eor #1; tay
        a.emit(0x98, 0x29, 0x01, 0x05, 0x13, 0xA8) // tya; and #1; ora $13; tay

        a.ppuAddress(0x2000 + UInt16(cellRow * 32))
        a.emit(0x98, 0x29, 0x01, 0xF0, 0x02, 0xA9, 0x03) // tya; and #1; beq +2; lda #3
        a.abs(0x8D, 0x2007) // Toggle cell.
        a.abs(0xAE, cheatAddress) // ldx cheat byte
        a.emit(0xA9, 0x00)
        a.abs(0x8D, cheatAddress) // Cleared, so only a code that keeps writing it keeps the cell lit.
        a.emit(0x8A, 0xF0, 0x02, 0xA9, 0x03) // txa; beq +2; lda #3
        a.abs(0x8D, 0x2007) // Cheat cell.
        a.abs(0xAD, genieAddress)
        a.emit(0xF0, 0x02, 0xA9, 0x03) // beq +2; lda #3
        a.abs(0x8D, 0x2007) // Genie cell.

        a.scrollHome() // PPUADDR writes moved the scroll.
        a.abs(0x4C, frame) // jmp frame

        let nmi = a.here
        a.emit(0xE6, 0x10, 0x40) // inc $10; rti
        let irq = a.here
        a.emit(0x40) // rti

        var prg = [UInt8](repeating: 0, count: 0x4000)
        precondition(a.bytes.count <= Int(paletteTable - origin), "the program ran into its data")
        prg.replaceSubrange(0..<a.bytes.count, with: a.bytes)
        // Background palette 0, and black everywhere else: 0x3F10 mirrors 0x3F00, so it must match.
        let table = palette + [UInt8](repeating: palette[0], count: 28)
        prg.replaceSubrange(Int(paletteTable - origin)..<(Int(paletteTable - origin) + 32), with: table)
        for (offset, vector) in [nmi, origin, irq].enumerated() {
            prg[0x3FFA + offset * 2] = UInt8(vector & 0xFF)
            prg[0x3FFB + offset * 2] = UInt8(vector >> 8)
        }

        // Tile n is solid colour n: bit plane 0 then bit plane 1.
        var chr = [UInt8](repeating: 0, count: 0x2000)
        for tile in 0..<4 {
            for row in 0..<8 {
                chr[tile * 16 + row] = tile & 1 != 0 ? 0xFF : 0
                chr[tile * 16 + 8 + row] = tile & 2 != 0 ? 0xFF : 0
            }
        }

        var header = [UInt8](repeating: 0, count: 16)
        header.replaceSubrange(0..<4, with: [0x4E, 0x45, 0x53, 0x1A]) // "NES" EOF
        header[4] = 1 // 16 KB units of PRG ROM.
        header[5] = 1 // 8 KB units of CHR ROM.
        header[6] = battery ? 0x02 : 0x00 // Mapper 0, horizontal mirroring, battery flag.
        return Data(header + prg + chr)
    }

    /// Just enough of a 6502 assembler. Addresses are CPU addresses from 0xC000.
    private struct Assembler {
        private(set) var bytes: [UInt8] = []
        var here: UInt16 { NESTestROM.origin + UInt16(bytes.count) }

        mutating func emit(_ values: UInt8...) { bytes += values }

        /// An opcode with an absolute, little-endian operand.
        mutating func abs(_ opcode: UInt8, _ address: UInt16) {
            bytes += [opcode, UInt8(address & 0xFF), UInt8(address >> 8)]
        }

        /// lda #value; sta address
        mutating func store(_ address: UInt16, _ value: UInt8) {
            emit(0xA9, value)
            abs(0x8D, address)
        }

        mutating func ppuAddress(_ address: UInt16) {
            store(0x2006, UInt8(address >> 8))
            store(0x2006, UInt8(address & 0xFF))
        }

        /// Scroll to the top left of nametable 0x2000, NMI on.
        mutating func scrollHome() {
            store(0x2005, 0)
            abs(0x8D, 0x2005)
            store(0x2000, 0x80)
        }

        mutating func waitVBlank() {
            let wait = here
            abs(0x2C, 0x2002) // bit PPUSTATUS
            branch(0x10, wait) // bpl
        }

        mutating func branch(_ opcode: UInt8, _ target: UInt16) {
            let delta = Int(target) - (Int(here) + 2)
            precondition((-128...127).contains(delta), "branch out of range")
            bytes += [opcode, UInt8(bitPattern: Int8(delta))]
        }
    }
}
#endif
