#if DEBUG
import Foundation

/// Generates a small homebrew Game Boy ROM, so tests need no commercial game and no Nintendo material.
/// Hand-assembled SM83, with a valid header checksum and an empty logo area: the core must skip the boot.
/// `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - Four horizontal bands of background tiles, in shades 0 to 3. In colour mode shades use `colors`.
/// - Eight cells on tile row 1, from tile column 4: shade 3 while that joypad bit is held, else the band.
/// - Waits on the VBlank interrupt with HALT, so it hangs if interrupts do not work.
/// - Channel 1 plays a steady square tone at about 440 Hz.
/// - Cartridge RAM: "GAGA" at offset 0, and a boot counter at offset 4, incremented once per boot.
/// - Toggle cell, tile column 0 of row 1: pressing A and B together flips it. The flag lives only in
///   register E, so it proves a save state restored the CPU.
/// - Cheat cell, column 1: lit for a frame after anything writes a non-zero byte to `cheatAddress`, which
///   the program clears each frame, so a GameShark code shows while it is on and stops when it is off.
/// - Genie cell, column 2: lit while the ROM byte at `genieAddress`, normally zero, reads non-zero.
enum GBTestROM {
    static let width = 160
    static let height = 144
    static let cartRAMSize = 8192
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramBootCounterOffset = 4
    static let toneHertz = 131072.0 / Double(2048 - 1750)
    static let cheatAddress: UInt16 = 0xC000
    static let genieAddress: UInt16 = 0x0400
    /// BGR555: red, green, blue, white. Colour mode only.
    static let colors: [UInt16] = [0x001F, 0x03E0, 0x7C00, 0x7FFF]
    static let chord: UInt32 = 0x03 // A and B, in joypad order.

    private static let keyColumn = 4
    private static let keyCount = 8
    private static let tileTable: UInt16 = 0x0410
    private static let tileMap: UInt16 = 0x9800
    private static let bandRows = [4, 4, 4, 6]

    /// The shade at a pixel, with `keys` as a joypad-order mask: A, B, Select, Start, Right, Left, Up, Down.
    static func expectedShade(x: Int, y: Int, keys: UInt32, toggle: Bool = false, cheat: Bool = false, genie: Bool = false) -> Int {
        let column = x / 8, row = y / 8
        if row == 1 {
            if (keyColumn..<(keyColumn + keyCount)).contains(column), keys & (1 << UInt32(column - keyColumn)) != 0 { return 3 }
            if (column == 0 && toggle) || (column == 1 && cheat) || (column == 2 && genie) { return 3 }
        }
        return row < 12 ? row / 4 : 3
    }

    static func build(color: Bool = false) -> Data {
        var a = Assembler()

        a.emit(0xF3) // di
        a.emit(0x31, 0xFE, 0xFF) // ld sp, 0xFFFE
        let wait = a.here
        a.emit(0xF0, 0x44) // ldh a, (LY)
        a.emit(0xFE, 144) // cp 144
        a.jrNZ(wait)
        a.emit(0xAF) // xor a
        a.emit(0xE0, 0x40) // LCDC off, which is safe only in VBlank.
        a.register(0x47, 0xE4) // BGP: shade n shows colour n.
        if color {
            a.register(0x68, 0x80) // BCPS: palette 0, auto increment.
            for value in colors {
                a.register(0x69, UInt8(value & 0xFF))
                a.register(0x69, UInt8(value >> 8))
            }
        }

        // Four solid tiles, from the two bytes per row in `tileTable`.
        a.emit16(0x11, tileTable) // ld de, table
        a.emit16(0x21, 0x8000) // ld hl, tiles
        a.emit(0x0E, 4) // ld c, 4
        let tile = a.here
        a.emit(0x06, 8) // ld b, 8
        let tileRow = a.here
        a.emit(0x1A, 0x22, 0x13, 0x1A, 0x22, 0x1B) // ld a,(de); ld (hl+),a; inc de; ld a,(de); ld (hl+),a; dec de
        a.emit(0x05) // dec b
        a.jrNZ(tileRow)
        a.emit(0x13, 0x13) // inc de; inc de
        a.emit(0x0D) // dec c
        a.jrNZ(tile)

        // The bands.
        a.emit16(0x21, tileMap) // ld hl, map
        for (shade, rows) in bandRows.enumerated() {
            a.emit(0x3E, UInt8(shade)) // ld a, shade
            a.emit(0x06, UInt8(rows * 32)) // ld b, tiles
            let fill = a.here
            a.emit(0x22, 0x05) // ld (hl+),a; dec b
            a.jrNZ(fill)
        }

        // Sound: on first, because the other registers ignore writes while it is off.
        a.register(0x26, 0x80) // NR52
        a.register(0x24, 0x77) // NR50: full volume.
        a.register(0x25, 0x11) // NR51: channel 1, left and right.
        a.register(0x10, 0x00) // NR10: no sweep.
        a.register(0x11, 0x80) // NR11: 50% duty.
        a.register(0x12, 0xF0) // NR12: volume 15, no envelope.
        a.register(0x13, UInt8(1750 & 0xFF)) // NR13
        a.register(0x14, UInt8(0x80 | 1750 >> 8)) // NR14: start.

        // Cartridge RAM. A first boot has no magic, whatever the erased bytes hold.
        a.emit(0x3E, 0x0A) // ld a, 0x0A
        a.emit16(0xEA, 0x0000) // ld (0x0000), a: RAM enable.
        a.emit16(0xFA, 0xA000) // ld a, (0xA000)
        a.emit(0xFE, sramMagic[0]) // cp 'G'
        a.emit(0x06, 0) // ld b, 0
        a.emit(0x20, 4) // jr nz, +4
        a.emit16(0xFA, 0xA000 + UInt16(sramBootCounterOffset)) // ld a, (counter)
        a.emit(0x47) // ld b, a
        a.emit(0x04, 0x78) // inc b; ld a, b
        a.emit16(0xEA, 0xA000 + UInt16(sramBootCounterOffset)) // ld (counter), a
        for (offset, byte) in sramMagic.enumerated() {
            a.emit(0x3E, byte) // ld a, byte
            a.emit16(0xEA, 0xA000 + UInt16(offset)) // ld (RAM), a
        }
        a.emit(0xAF) // xor a
        a.emit16(0xEA, 0x0000) // ld (0x0000), a: RAM disable.

        a.register(0x40, 0x91) // LCDC: on, tiles at 0x8000, map at 0x9800, background on.
        a.register(0xFF, 0x01) // IE: VBlank.
        a.register(0x0F, 0x00) // IF
        a.emit(0xFB) // ei
        a.emit(0x1E, 0) // ld e, 0. Bit 0: the toggle. Bit 1: the chord was held last frame.

        let frame = a.here
        a.emit(0x76, 0x00) // halt; nop

        // Joypad, active low, into D: A, B, Select, Start, Right, Left, Up, Down.
        a.register(0x00, 0x20) // Directions.
        a.emit(0xF0, 0x00, 0x2F, 0xE6, 0x0F) // ldh a,(P1); cpl; and 0x0F
        a.emit(0xCB, 0x37, 0x57) // swap a; ld d, a
        a.register(0x00, 0x10) // Buttons.
        a.emit(0xF0, 0x00, 0x2F, 0xE6, 0x0F) // ldh a,(P1); cpl; and 0x0F
        a.emit(0xB2, 0x57) // or d; ld d, a
        a.register(0x00, 0x30) // Neither.

        // The key cells. Band 0 is shade 0, so an unlit cell is tile 0.
        a.emit16(0x21, tileMap + 32 + UInt16(keyColumn)) // ld hl, first cell
        a.emit(0x4A) // ld c, d
        a.emit(0x06, UInt8(keyCount)) // ld b, count
        let cell = a.here
        a.emit(0x3E, 0) // ld a, 0
        a.emit(0xCB, 0x39) // srl c
        a.emit(0x30, 2) // jr nc, +2
        a.emit(0x3E, 3) // ld a, 3
        a.emit(0x22, 0x05) // ld (hl+),a; dec b
        a.jrNZ(cell)

        // Flip the toggle on the press of the chord only.
        a.emit(0x7A, 0xE6, UInt8(chord), 0xFE, UInt8(chord)) // ld a,d; and chord; cp chord
        a.emit(0x3E, 0) // ld a, 0
        a.emit(0x20, 2) // jr nz, +2
        a.emit(0x3E, 2) // ld a, 2
        a.emit(0x4F) // ld c, a: held now, in bit 1.
        a.emit(0x7B, 0xE6, 2, 0x2F, 0xA1) // ld a,e; and 2; cpl; and c: pressed this frame.
        a.emit(0x28, 4) // jr z, +4
        a.emit(0x7B, 0xEE, 1, 0x5F) // ld a,e; xor 1; ld e,a
        a.emit(0x7B, 0xE6, 1, 0xB1, 0x5F) // ld a,e; and 1; or c; ld e,a

        a.emit(0x7B, 0xE6, 1) // ld a,e; and 1
        a.emit(0x28, 2, 0x3E, 3) // jr z,+2; ld a,3
        a.emit16(0xEA, tileMap + 32) // ld (toggle cell), a

        a.emit16(0x21, cheatAddress) // ld hl, cheat byte
        a.emit(0x7E, 0x36, 0x00, 0xB7) // ld a,(hl); ld (hl),0; or a
        a.emit(0x28, 2, 0x3E, 3) // jr z,+2; ld a,3
        a.emit16(0xEA, tileMap + 33) // ld (cheat cell), a

        a.emit16(0xFA, genieAddress) // ld a, (ROM byte)
        a.emit(0xB7) // or a
        a.emit(0x28, 2, 0x3E, 3) // jr z,+2; ld a,3
        a.emit16(0xEA, tileMap + 34) // ld (genie cell), a

        a.emit16(0xC3, frame) // jp frame

        return image(code: a.bytes, color: color)
    }

    /// 32 KB, no banking. MBC1 with 8 KB of battery RAM. The logo area stays zero on purpose.
    private static func image(code: [UInt8], color: Bool) -> Data {
        var rom = [UInt8](repeating: 0, count: 0x8000)
        rom[0x40] = 0xD9 // reti: the VBlank vector.
        rom.replaceSubrange(0x100..<0x104, with: [0x00, 0xC3, 0x50, 0x01]) // nop; jp 0x0150
        rom.replaceSubrange(0x134..<0x13E, with: Array("GAGATESTGB".utf8))
        rom[0x143] = color ? 0x80 : 0x00 // Colour and mono, or mono only.
        rom[0x147] = 0x03 // MBC1 + RAM + battery.
        rom[0x148] = 0x00 // 32 KB.
        rom[0x149] = 0x02 // 8 KB.
        rom[0x14A] = 0x01 // Not Japan.
        rom.replaceSubrange(0x150..<(0x150 + code.count), with: code)
        precondition(0x150 + code.count <= Int(genieAddress), "the program ran into its data")
        rom.replaceSubrange(Int(tileTable)..<(Int(tileTable) + 8), with: [0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0xFF])
        rom[0x14D] = headerChecksum(rom)
        let sum = rom.reduce(0) { $0 &+ UInt16($1) }
        rom[0x14E] = UInt8(sum >> 8)
        rom[0x14F] = UInt8(sum & 0xFF)
        return Data(rom)
    }

    /// The header's complement check, as a real cartridge carries it.
    static func headerChecksum(_ rom: [UInt8]) -> UInt8 {
        rom[0x134...0x14C].reduce(UInt8(0)) { $0 &- $1 &- 1 }
    }

    /// Just enough of an SM83 assembler. Addresses are ROM addresses.
    private struct Assembler {
        private(set) var bytes: [UInt8] = []
        var here: UInt16 { 0x150 + UInt16(bytes.count) }

        mutating func emit(_ values: UInt8...) { bytes += values }

        /// An opcode and a little-endian operand.
        mutating func emit16(_ opcode: UInt8, _ value: UInt16) {
            bytes += [opcode, UInt8(value & 0xFF), UInt8(value >> 8)]
        }

        /// ld a, value; ldh (0xFF00 + register), a
        mutating func register(_ register: UInt8, _ value: UInt8) {
            bytes += [0x3E, value, 0xE0, register]
        }

        mutating func jrNZ(_ target: UInt16) {
            let delta = Int(target) - (Int(here) + 2)
            precondition((-128...127).contains(delta), "jr out of range")
            bytes += [0x20, UInt8(bitPattern: Int8(delta))]
        }
    }
}
#endif
