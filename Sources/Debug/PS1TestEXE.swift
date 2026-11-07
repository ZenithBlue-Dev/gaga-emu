#if DEBUG
import Foundation

/// Generates a small homebrew PlayStation program, so tests need no commercial disc and no Sony BIOS.
/// Hand-assembled R3000A that talks to the hardware directly and calls no BIOS function, so the core's HLE
/// BIOS only has to start it. `build()` is a PS-EXE, which PCSX-ReARMed boots by its `.exe` name; `disc()`
/// puts the same program on a one-track ISO9660 disc behind a SYSTEM.CNF. `scripts/make-test-rom.sh` writes
/// either to a file.
///
/// What the program does:
/// - Four horizontal bands, 60 lines each, through GPU fill commands: red, green, blue, white.
/// - Key cells, 16 by 16 from x 32 on line 16: white while that pad bit is held, else the band. Pad bits are
///   read over SIO0 with the controller protocol, in the pad's own order (below).
/// - Toggle cell, x 0 on line 16: pressing Cross and Circle together flips it. The flag lives only in a CPU
///   register, so it proves a save state restored the CPU.
/// - Cheat cell, x 16 on line 16: white for a frame after anything writes a non-zero byte to `cheatAddress`,
///   which the program clears each frame, so a GameShark code shows while it is on and stops when it is off.
/// - Counter cells, from x 32 on line 40: the memory card boot counter, one bit per cell.
/// - SPU voice 0 loops a two-block ADPCM square wave at `toneHertz`.
/// - Memory card 1, sector `cardSector`: "GAGA" at offset 0 and a boot counter at offset 4, read and written
///   once per boot with the card protocol.
/// - Waits for VBlank by polling I_STAT with every interrupt masked, so no BIOS handler runs.
enum PS1TestEXE {
    static let width = 320
    static let height = 240
    static let bandHeight = 60
    static let cellSize = 16
    static let keyRow = 16
    static let counterRow = 40
    static let cellColumn = 32
    static let cardSize = 128 * 1024
    static let cardSector = 0x3FF
    static let cardMagic: [UInt8] = Array("GAGA".utf8)
    static let cardCounterOffset = 4
    /// Sample rate 0x0800 (22050 Hz) over a 56-sample period.
    static let toneHertz = 44100.0 * 0x0800 / 0x1000 / 56
    static let cheatAddress: UInt32 = 0x800F_0000
    // Pad bit order: Select, L3, R3, Start, Up, Right, Down, Left, L2, R2, L1, R1, Triangle, Circle, Cross, Square.
    static let chord: UInt32 = 0x6000 // Circle and Cross, in pad order.
    /// GP0 colours, 0xBBGGRR: red, green, blue, white. The cells are white or the band's colour.
    static let bandColors: [UInt32] = [0x0000FF, 0x00FF00, 0xFF0000, 0xFFFFFF]
    static let white = 3

    /// The band index (0 red, 1 green, 2 blue, 3 white) at a pixel. `keys` is in pad order.
    static func expectedColor(x: Int, y: Int, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, counter: Int = 1) -> Int {
        let band = y / bandHeight
        func cell(_ row: Int) -> Bool { (row..<(row + cellSize)).contains(y) }
        let column = (x - cellColumn) / cellSize
        let inBits = x >= cellColumn && column < 16
        if cell(keyRow) {
            if inBits && keys & (1 << UInt32(column)) != 0 { return white }
            if x < cellSize && toggle { return white }
            if x >= cellSize && x < cellColumn && cheat { return white }
        }
        if cell(counterRow) && inBits && counter & (1 << column) != 0 { return white }
        return band
    }

    static func build() -> Data {
        exe(code: program())
    }

    // MARK: - Program

    private static let textAddress: UInt32 = 0x8001_0000
    private static let cardBuffer: UInt32 = 0x8010_0000

    private static func program() -> [UInt32] {
        var a = Assembler(origin: textAddress)
        a.lui(.s1, 0x1F80) // s1: the I/O base for the whole program.
        a.sw(.zero, 0x1074, .s1) // I_MASK: no interrupt reaches the CPU.
        a.mtc0(.zero, 12) // SR: interrupts off.
        a.li(.sp, 0x801F_FFF0)

        // GPU: reset, 320x240 NTSC 15-bit, the display at VRAM 0,0, drawing over the whole screen.
        for command: UInt32 in [0x0000_0000, 0x0800_0001, 0x0500_0000, 0x06C6_0260, 0x0704_0010] {
            a.li(.t0, command)
            a.sw(.t0, 0x1814, .s1)
        }
        for command: UInt32 in [0xE100_0400, 0xE300_0000, 0xE403_BD3F, 0xE500_0000] {
            a.li(.t0, command)
            a.sw(.t0, 0x1810, .s1)
        }
        for (band, color) in bandColors.enumerated() {
            a.li(.a0, color)
            a.li(.a1, UInt32(band * bandHeight) << 16)
            a.li(.a2, UInt32(bandHeight) << 16 | UInt32(width))
            a.jal("fill")
        }
        a.li(.t0, 0x0300_0000) // Display on.
        a.sw(.t0, 0x1814, .s1)

        // SPU: on, full volume, no reverb. Two ADPCM blocks at 0x1000: 28 samples high, then 28 low, looping.
        a.halfword(0xC000, at: 0x1DAA)
        a.halfword(0x3FFF, at: 0x1D80)
        a.halfword(0x3FFF, at: 0x1D82)
        a.halfword(0, at: 0x1D84)
        a.halfword(0, at: 0x1D86)
        a.halfword(0x0200, at: 0x1DA6) // Transfer address, in 8-byte units.
        let blocks: [UInt8] = [0x00, 0x04] + [UInt8](repeating: 0x77, count: 14) + [0x00, 0x03] + [UInt8](repeating: 0x88, count: 14)
        for index in stride(from: 0, to: blocks.count, by: 2) {
            a.halfword(UInt16(blocks[index]) | UInt16(blocks[index + 1]) << 8, at: 0x1DA8)
        }
        a.halfword(0x3FFF, at: 0x1C00) // Voice 0 volume, left and right.
        a.halfword(0x3FFF, at: 0x1C02)
        a.halfword(0x0800, at: 0x1C04) // Sample rate: 22050 Hz.
        a.halfword(0x0200, at: 0x1C06) // Start address.
        a.halfword(0x000F, at: 0x1C08) // ADSR: fastest attack, sustain at the top.
        a.halfword(0x0000, at: 0x1C0A)
        a.halfword(0x0200, at: 0x1C0E) // Repeat address.
        a.halfword(0x0001, at: 0x1D88) // Key on voice 0.

        // Memory card: read the sector, count this boot, write it back.
        a.cardCommand(0x52)
        a.li(.s4, cardBuffer)
        a.li(.s5, 134) // 5C 5D, the address, 128 data bytes, checksum, 47.
        a.label("read")
        a.li(.a0, 0)
        a.jal("xchg")
        a.sb(.v0, 0, .s4)
        a.addiu(.s4, .s4, 1)
        a.addiu(.s5, .s5, -1)
        a.bne(.s5, .zero, "read")
        a.sh(.zero, 0x104A, .s1)
        a.li(.s4, cardBuffer + 4) // The sector's data.
        a.lw(.t0, 0, .s4)
        a.li(.t1, UInt32(cardMagic[0]) | UInt32(cardMagic[1]) << 8 | UInt32(cardMagic[2]) << 16 | UInt32(cardMagic[3]) << 24)
        a.li(.s3, 0) // s3: the boot counter.
        a.bne(.t0, .t1, "fresh")
        a.lbu(.s3, UInt16(cardCounterOffset), .s4)
        a.label("fresh")
        a.addiu(.s3, .s3, 1)
        a.andi(.s3, .s3, 0xFF)
        a.sw(.t1, 0, .s4)
        a.sb(.s3, UInt16(cardCounterOffset), .s4)
        a.cardCommand(0x57)
        a.li(.s6, 0x03 ^ 0xFF) // The checksum starts with the address bytes.
        a.li(.s5, 128)
        a.label("write")
        a.lbu(.a0, 0, .s4)
        a.xor(.s6, .s6, .a0)
        a.jal("xchg")
        a.addiu(.s4, .s4, 1)
        a.addiu(.s5, .s5, -1)
        a.bne(.s5, .zero, "write")
        a.or(.a0, .s6, .zero)
        a.jal("xchg")
        for _ in 0..<3 {
            a.li(.a0, 0)
            a.jal("xchg")
        }
        a.sh(.zero, 0x104A, .s1)
        a.li(.s0, 0) // s0 bit 0: the toggle. Bit 1: the chord was held last frame.

        a.label("frame")
        a.lw(.t0, 0x1070, .s1) // I_STAT: wait for VBlank, then acknowledge it.
        a.andi(.t0, .t0, 1)
        a.beq(.t0, .zero, "frame")
        a.li(.t0, 0xFFFF_FFFE)
        a.sw(.t0, 0x1070, .s1)

        // Pad 1, active low, into s2.
        a.li(.t0, 0x0003)
        a.sh(.t0, 0x104A, .s1)
        for byte: UInt32 in [0x01, 0x42, 0x00] {
            a.li(.a0, byte)
            a.jal("xchg")
        }
        a.li(.a0, 0)
        a.jal("xchg")
        a.or(.s2, .v0, .zero)
        a.li(.a0, 0)
        a.jal("xchg")
        a.sll(.v0, .v0, 8)
        a.or(.s2, .s2, .v0)
        a.nor(.s2, .s2, .zero)
        a.andi(.s2, .s2, 0xFFFF)
        a.sh(.zero, 0x104A, .s1)

        a.or(.a3, .s2, .zero)
        a.lui(.v1, UInt16(keyRow))
        a.jal("row")
        a.or(.a3, .s3, .zero)
        a.lui(.v1, UInt16(counterRow))
        a.jal("row")

        // Flip the toggle on the press of the chord only.
        a.andi(.t2, .s2, UInt16(chord))
        a.xori(.t2, .t2, UInt16(chord))
        a.sltiu(.t2, .t2, 1)
        a.sll(.t2, .t2, 1) // Held now, in bit 1.
        a.andi(.t3, .s0, 2)
        a.nor(.t3, .t3, .zero)
        a.and(.t3, .t3, .t2)
        a.srl(.t3, .t3, 1) // Pressed this frame.
        a.xor(.s0, .s0, .t3)
        a.andi(.s0, .s0, 1)
        a.or(.s0, .s0, .t2)
        a.andi(.t2, .s0, 1)
        a.li(.a1, UInt32(keyRow) << 16)
        a.jal("cell")

        a.li(.t4, cheatAddress)
        a.lbu(.t2, 0, .t4)
        a.sb(.zero, 0, .t4)
        a.sltu(.t2, .zero, .t2)
        a.li(.a1, UInt32(keyRow) << 16 | UInt32(cellSize))
        a.jal("cell")
        a.j("frame")

        // fill: a0 colour, a1 y << 16 | x, a2 height << 16 | width.
        a.label("fill")
        a.lui(.t0, 0x0200)
        a.or(.t0, .t0, .a0)
        a.sw(.t0, 0x1810, .s1)
        a.sw(.a1, 0x1810, .s1)
        a.sw(.a2, 0x1810, .s1)
        a.jr(.ra)

        // cell: one cell at a1, white when t2 is not zero, else red. Ends in fill.
        a.label("cell")
        a.li(.a0, bandColors[0])
        a.beq(.t2, .zero, "cell-draw")
        a.li(.a0, bandColors[white])
        a.label("cell-draw")
        a.li(.a2, UInt32(cellSize) << 16 | UInt32(cellSize))
        a.j("fill")

        // row: 16 cells from x 32 on line v1 >> 16, one per bit of a3. Uses s4, s5 and s7.
        a.label("row")
        a.or(.s7, .ra, .zero)
        a.li(.s4, 0)
        a.li(.s5, UInt32(cellColumn))
        a.label("row-next")
        a.srlv(.t2, .a3, .s4)
        a.andi(.t2, .t2, 1)
        a.or(.a1, .v1, .s5)
        a.jal("cell")
        a.addiu(.s4, .s4, 1)
        a.addiu(.s5, .s5, Int16(cellSize))
        a.sltiu(.t2, .s4, 16)
        a.bne(.t2, .zero, "row-next")
        a.jr(.s7)

        // xchg: sends a0 on SIO0 and returns the byte that came back in v0, waiting at most 4096 polls.
        a.label("xchg")
        a.sb(.a0, 0x1040, .s1)
        a.li(.t1, 0x1000)
        a.label("xchg-wait")
        a.lhu(.t0, 0x1044, .s1)
        a.andi(.t0, .t0, 2) // RX not empty.
        a.bne(.t0, .zero, "xchg-ready")
        a.addiu(.t1, .t1, -1)
        a.bne(.t1, .zero, "xchg-wait")
        a.label("xchg-ready")
        a.lbu(.v0, 0x1040, .s1)
        a.jr(.ra)
        return a.finish()
    }

    /// The 2048-byte PS-EXE header, then the program padded to whole sectors. No region marker text.
    private static func exe(code: [UInt32]) -> Data {
        var text = code.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> ($0 * 8)) } }
        text += [UInt8](repeating: 0, count: (2048 - text.count % 2048) % 2048)
        var header = [UInt8](repeating: 0, count: 2048)
        header.replaceSubrange(0..<8, with: Array("PS-X EXE".utf8))
        func put(_ value: UInt32, at offset: Int) {
            for byte in 0..<4 { header[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8)) }
        }
        put(textAddress, at: 0x10) // pc0
        put(textAddress, at: 0x18) // t_addr
        put(UInt32(text.count), at: 0x1C) // t_size
        put(0x801F_FFF0, at: 0x30) // s_addr
        return Data(header + text)
    }

    // MARK: - Disc

    /// A MODE2/2352 image whose ISO9660 root holds SYSTEM.CNF, booting cdrom:\PSX.EXE;1, and the program.
    /// `label` goes in the volume ID. No licence sector, so the core assumes an American disc.
    static func disc(label: String = "GAGATEST") -> (bin: Data, cue: (String) -> String) {
        let exe = [UInt8](build())
        let cnf = [UInt8]("BOOT = cdrom:\\PSX.EXE;1\r\nTCB = 4\r\nEVENT = 16\r\nSTACK = 801FFFF0\r\n".utf8)
        let rootSector = 18, cnfSector = 20, exeSector = 21
        let total = exeSector + exe.count / 2048 + 2
        var sectors = [[UInt8]](repeating: [UInt8](repeating: 0, count: 2048), count: total)

        func record(_ name: String, sector: Int, size: Int, directory: Bool) -> [UInt8] {
            let id = [UInt8](name.utf8)
            var entry = [UInt8](repeating: 0, count: 33 + id.count + (id.count % 2 == 0 ? 1 : 0))
            entry[0] = UInt8(entry.count)
            both32(&entry, 2, UInt32(sector))
            both32(&entry, 10, UInt32(size))
            entry[25] = directory ? 0x02 : 0x00
            entry[28] = 1 // Volume sequence number, both-endian 16.
            entry[31] = 1
            entry[32] = UInt8(id.count)
            entry.replaceSubrange(33..<(33 + id.count), with: id)
            return entry
        }
        let root = record("\u{0}", sector: rootSector, size: 4096, directory: true)

        var pvd = [UInt8](repeating: 0, count: 2048)
        pvd[0] = 1
        pvd.replaceSubrange(1..<6, with: Array("CD001".utf8))
        pvd[6] = 1
        let volume = [UInt8](label.utf8.prefix(32)) + [UInt8](repeating: 0x20, count: 32 - min(32, label.utf8.count))
        pvd.replaceSubrange(40..<72, with: volume)
        both32(&pvd, 80, UInt32(total))
        pvd[120] = 1; pvd[123] = 1 // Volume set size.
        pvd[124] = 1; pvd[127] = 1 // Volume sequence number.
        pvd[128] = 0x00; pvd[129] = 0x08; pvd[130] = 0x08; pvd[131] = 0x00 // Block size 2048, both-endian.
        pvd.replaceSubrange(156..<(156 + root.count), with: root)
        pvd[881] = 1
        sectors[16] = pvd
        var terminator = [UInt8](repeating: 0, count: 2048)
        terminator[0] = 0xFF
        terminator.replaceSubrange(1..<6, with: Array("CD001".utf8))
        terminator[6] = 1
        sectors[17] = terminator

        var directory = record("\u{0}", sector: rootSector, size: 4096, directory: true)
        directory += record("\u{1}", sector: rootSector, size: 4096, directory: true)
        directory += record("SYSTEM.CNF;1", sector: cnfSector, size: cnf.count, directory: false)
        directory += record("PSX.EXE;1", sector: exeSector, size: exe.count, directory: false)
        sectors[rootSector].replaceSubrange(0..<directory.count, with: directory)
        sectors[cnfSector].replaceSubrange(0..<cnf.count, with: cnf)
        for (index, start) in stride(from: 0, to: exe.count, by: 2048).enumerated() {
            sectors[exeSector + index] = Array(exe[start..<(start + 2048)])
        }

        var bin = Data(capacity: total * 2352)
        for (lba, data) in sectors.enumerated() {
            var raw = [UInt8](repeating: 0, count: 2352)
            raw.replaceSubrange(1..<11, with: [UInt8](repeating: 0xFF, count: 10)) // Sync.
            let address = lba + 150
            raw[12] = bcd(address / 4500)
            raw[13] = bcd(address / 75 % 60)
            raw[14] = bcd(address % 75)
            raw[15] = 2 // Mode 2.
            let submode: UInt8 = lba == total - 1 ? 0x89 : 0x08 // Data; the last one also ends the file.
            raw.replaceSubrange(16..<24, with: [0, 0, submode, 0, 0, 0, submode, 0])
            raw.replaceSubrange(24..<(24 + 2048), with: data)
            bin.append(contentsOf: raw) // No EDC or ECC: the core does not check them.
        }
        let cue = { (binName: String) in "FILE \"\(binName)\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n" }
        return (bin, cue)
    }

    private static func both32(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt32) {
        for byte in 0..<4 {
            bytes[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8))
            bytes[offset + 7 - byte] = UInt8(truncatingIfNeeded: value >> (byte * 8))
        }
    }

    private static func bcd(_ value: Int) -> UInt8 { UInt8((value / 10) << 4 | value % 10) }

    // MARK: - Assembler

    private enum Reg: UInt32 {
        case zero = 0, v0 = 2, v1 = 3, a0 = 4, a1 = 5, a2 = 6, a3 = 7, t0 = 8, t1 = 9, t2 = 10, t3 = 11, t4 = 12
        case s0 = 16, s1, s2, s3, s4, s5, s6, s7, sp = 29, ra = 31
    }

    /// Just enough of a MIPS I assembler. Every branch and jump gets a nop in its delay slot, and every load a
    /// nop after it, so no instruction depends on delay-slot rules.
    private struct Assembler {
        let origin: UInt32
        private var words: [UInt32] = []
        private var labels: [String: Int] = [:]
        private var fixups: [(index: Int, label: String, jump: Bool)] = []

        init(origin: UInt32) { self.origin = origin }

        mutating func label(_ name: String) {
            precondition(labels[name] == nil, "label \(name) twice")
            labels[name] = words.count
        }

        private mutating func emit(_ word: UInt32) { words.append(word) }
        private mutating func nop() { emit(0) }

        private mutating func special(_ funct: UInt32, rd: Reg, rs: Reg = .zero, rt: Reg = .zero, shift: UInt32 = 0) {
            emit(rs.rawValue << 21 | rt.rawValue << 16 | rd.rawValue << 11 | shift << 6 | funct)
        }

        private mutating func immediate(_ op: UInt32, _ rt: Reg, _ rs: Reg, _ value: UInt16) {
            emit(op << 26 | rs.rawValue << 21 | rt.rawValue << 16 | UInt32(value))
        }

        mutating func lui(_ rt: Reg, _ value: UInt16) { immediate(0x0F, rt, .zero, value) }
        mutating func ori(_ rt: Reg, _ rs: Reg, _ value: UInt16) { immediate(0x0D, rt, rs, value) }
        mutating func andi(_ rt: Reg, _ rs: Reg, _ value: UInt16) { immediate(0x0C, rt, rs, value) }
        mutating func xori(_ rt: Reg, _ rs: Reg, _ value: UInt16) { immediate(0x0E, rt, rs, value) }
        mutating func sltiu(_ rt: Reg, _ rs: Reg, _ value: UInt16) { immediate(0x0B, rt, rs, value) }
        mutating func addiu(_ rt: Reg, _ rs: Reg, _ value: Int16) { immediate(0x09, rt, rs, UInt16(bitPattern: value)) }
        mutating func sw(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x2B, rt, base, offset) }
        mutating func sh(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x29, rt, base, offset) }
        mutating func sb(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x28, rt, base, offset) }
        mutating func lw(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x23, rt, base, offset); nop() }
        mutating func lhu(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x25, rt, base, offset); nop() }
        mutating func lbu(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x24, rt, base, offset); nop() }
        mutating func or(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x25, rd: rd, rs: rs, rt: rt) }
        mutating func and(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x24, rd: rd, rs: rs, rt: rt) }
        mutating func xor(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x26, rd: rd, rs: rs, rt: rt) }
        mutating func nor(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x27, rd: rd, rs: rs, rt: rt) }
        mutating func sltu(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x2B, rd: rd, rs: rs, rt: rt) }
        mutating func sll(_ rd: Reg, _ rt: Reg, _ shift: UInt32) { special(0x00, rd: rd, rt: rt, shift: shift) }
        mutating func srl(_ rd: Reg, _ rt: Reg, _ shift: UInt32) { special(0x02, rd: rd, rt: rt, shift: shift) }
        mutating func srlv(_ rd: Reg, _ rt: Reg, _ rs: Reg) { special(0x06, rd: rd, rs: rs, rt: rt) }
        mutating func jr(_ rs: Reg) { special(0x08, rd: .zero, rs: rs); nop() }
        mutating func mtc0(_ rt: Reg, _ rd: UInt32) { emit(0x10 << 26 | 0x04 << 21 | rt.rawValue << 16 | rd << 11) }

        mutating func li(_ rt: Reg, _ value: UInt32) {
            if value >> 16 == 0 { return ori(rt, .zero, UInt16(value)) }
            lui(rt, UInt16(value >> 16))
            if value & 0xFFFF != 0 { ori(rt, rt, UInt16(value & 0xFFFF)) }
        }

        /// sh value to the I/O register at s1 + offset.
        mutating func halfword(_ value: UInt16, at offset: UInt16) {
            li(.t0, UInt32(value))
            sh(.t0, offset, .s1)
        }

        /// Selects card 1 and sends 81, the command, 00 00, then sector `cardSector`'s address.
        mutating func cardCommand(_ command: UInt32) {
            li(.t0, 0x0003)
            sh(.t0, 0x104A, .s1)
            for byte in [0x81, command, 0, 0, UInt32(cardSector >> 8), UInt32(cardSector & 0xFF)] {
                li(.a0, byte)
                jal("xchg")
            }
        }

        private mutating func branch(_ op: UInt32, _ rs: Reg, _ rt: Reg, _ label: String) {
            fixups.append((words.count, label, false))
            emit(op << 26 | rs.rawValue << 21 | rt.rawValue << 16)
            nop()
        }

        mutating func beq(_ rs: Reg, _ rt: Reg, _ label: String) { branch(0x04, rs, rt, label) }
        mutating func bne(_ rs: Reg, _ rt: Reg, _ label: String) { branch(0x05, rs, rt, label) }

        private mutating func jump(_ op: UInt32, _ label: String) {
            fixups.append((words.count, label, true))
            emit(op << 26)
            nop()
        }

        mutating func j(_ label: String) { jump(0x02, label) }
        mutating func jal(_ label: String) { jump(0x03, label) }

        func finish() -> [UInt32] {
            var out = words
            for fixup in fixups {
                guard let target = labels[fixup.label] else { preconditionFailure("no label \(fixup.label)") }
                if fixup.jump {
                    out[fixup.index] |= (origin + UInt32(target) * 4) >> 2 & 0x03FF_FFFF
                } else {
                    let delta = target - (fixup.index + 1)
                    precondition((-32768...32767).contains(delta), "branch out of range")
                    out[fixup.index] |= UInt32(UInt16(bitPattern: Int16(delta)))
                }
            }
            return out
        }
    }
}
#endif
