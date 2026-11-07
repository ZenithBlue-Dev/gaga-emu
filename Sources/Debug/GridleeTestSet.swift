#if DEBUG
import Foundation

/// Generates a homebrew ROM set for MAME's `gridlee` machine (Videa Gridlee hardware), so tests need no arcade
/// ROM. Every file has the name and size MAME's ROM definition gives it, holds bytes written here, and is
/// stored uncompressed in a zip that must be named `gridlee.zip`. MAME finds the files by name, warns that the
/// checksums are not the dumped ones, and runs them. `scripts/make-test-rom.sh` writes the same zip.
///
/// Hand-assembled 6809 at 0xA000. What the program does, in the 256 x 240 picture:
/// - Four bands of 60 lines in `colors` 1 to 4 (red, green, blue, white), drawn once at boot.
/// - Three 32 x 16 cells on lines 16 to 31, at x 32, 96 and 160: yellow while button 1, then start 1, is
///   held, else black. The third is the toggle: pressing both together flips it. The flag lives only in
///   register U, so it proves a save state restored the CPU.
/// - Waits for VBlank on the input port each frame, so it hangs if the screen does not run.
/// - The custom tone generator plays a square wave at `toneHertz`.
/// - NVRAM at 0x9C00: "GAGA" at offset 0, and a boot counter at offset 4, incremented once per boot.
enum GridleeTestSet {
    static let machine = "gridlee"
    static let width = 256
    static let height = 240
    static let nvramSize = 256
    static let nvramMagic: [UInt8] = Array("GAGA".utf8)
    static let nvramBootCounterOffset = 4
    private static let toneStep: UInt8 = 88
    /// The tone register times 5, by upstream's gridlee_a.cpp.
    static let toneHertz = Double(toneStep) * 5
    /// Colour PROM values, 4 bits each: black, red, green, blue, white, yellow.
    static let colors: [(r: UInt8, g: UInt8, b: UInt8)] = [(0, 0, 0), (15, 0, 0), (0, 15, 0), (0, 0, 15), (15, 15, 15), (15, 15, 0)]
    /// Left edges of the button 1, start 1 and toggle cells.
    static let cellColumns = [32, 96, 160]

    private static let cellTop = 16
    private static let cellSize = (width: 32, height: 16)
    private static let bandHeight = 60
    private static let lit = 5

    /// The colour index at a pixel. `keys`: bit 0 is button 1, bit 1 is start 1.
    static func expectedColor(x: Int, y: Int, keys: UInt32, toggle: Bool = false) -> Int {
        if (cellTop..<(cellTop + cellSize.height)).contains(y) {
            for (index, left) in cellColumns.enumerated() where (left..<(left + cellSize.width)).contains(x) {
                let on = index == 2 ? toggle : keys & (1 << UInt32(index)) != 0
                return on ? lit : 0
            }
        }
        return 1 + y / bandHeight
    }

    /// The file names and sizes of upstream's ROM_START( gridlee ), with the bytes this generator puts in them.
    static func files() -> [(name: String, data: Data)] {
        let program = assemble()
        var main = [UInt8](repeating: 0, count: 0x6000) // 0xA000 to 0xFFFF.
        main.replaceSubrange(0..<program.code.count, with: program.code)
        for (index, vector) in program.vectors.enumerated() { // SWI3, SWI2, FIRQ, IRQ, SWI, NMI, RESET.
            main[0x5FF2 + index * 2] = UInt8(vector >> 8)
            main[0x5FF3 + index * 2] = UInt8(vector & 0xFF)
        }
        var result: [(name: String, data: Data)] = "abcdef".enumerated().map { index, letter in
            (name: "gridfnl\(letter).bin", data: Data(main[(index * 0x1000)..<((index + 1) * 0x1000)]))
        }
        // Sprite images: all transparent, so the 32 sprites never cover the picture.
        result += (0..<4).map { (name: "gridpix\($0).bin", data: Data(count: 0x1000)) }
        // Red, green and blue PROMs. The picture uses palette entries 16 to 31 (bank 0, pens + 16).
        for (name, channel) in [("grdrprom.bin", 0), ("grdgprom.bin", 1), ("grdbprom.bin", 2)] {
            var prom = [UInt8](repeating: 0, count: 0x800)
            for (index, color) in colors.enumerated() { prom[16 + index] = [color.r, color.g, color.b][channel] }
            result.append((name: name, data: Data(prom)))
        }
        return result
    }

    static func build() -> Data { zip(files()) }

    /// A zip of stored (uncompressed) entries, which MAME's unzip reads.
    static func zip(_ entries: [(name: String, data: Data)]) -> Data {
        var out = Data(), directory = Data()
        func u16(_ value: Int, into data: inout Data) { data += [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)] }
        func u32(_ value: UInt32, into data: inout Data) { for shift in stride(from: 0, to: 32, by: 8) { data.append(UInt8(value >> UInt32(shift) & 0xFF)) } }
        for entry in entries {
            let name = Data(entry.name.utf8), crc = RomPatcher.crc32(entry.data), offset = UInt32(out.count)
            // Version 2.0, no flags, stored, 1980-01-01 00:00.
            let fields: (inout Data) -> Void = { data in
                u16(20, into: &data); u16(0, into: &data); u16(0, into: &data); u16(0, into: &data); u16(0x21, into: &data)
                u32(crc, into: &data); u32(UInt32(entry.data.count), into: &data); u32(UInt32(entry.data.count), into: &data)
                u16(name.count, into: &data); u16(0, into: &data)
            }
            u32(0x0403_4B50, into: &out)
            fields(&out)
            out += name + entry.data
            u32(0x0201_4B50, into: &directory)
            u16(20, into: &directory) // Made by version 2.0.
            fields(&directory)
            u16(0, into: &directory); u16(0, into: &directory); u16(0, into: &directory) // Comment, disk, internal attributes.
            u32(0, into: &directory); u32(offset, into: &directory)
            directory += name
        }
        let start = UInt32(out.count)
        out += directory
        u32(0x0605_4B50, into: &out)
        u16(0, into: &out); u16(0, into: &out); u16(entries.count, into: &out); u16(entries.count, into: &out)
        u32(UInt32(directory.count), into: &out); u32(start, into: &out); u16(0, into: &out)
        return out
    }

    // MARK: - Program

    private static func assemble() -> (code: [UInt8], vectors: [UInt16]) {
        var a = Assembler()
        let keys: UInt16 = 0x0100, held: UInt16 = 0x0101 // Work RAM above the 32 sprites.
        func cellAddress(_ column: Int) -> UInt16 { UInt16(0x0800 + cellTop * 128 + column / 2) }

        /// Fills a cell yellow when the Z flag is clear, else black.
        func drawCell(_ column: Int) {
            let off = a.newLabel(), go = a.newLabel()
            a.branch(0x27, off) // beq off
            a.emit(0xCC, 0x55, 0x55) // ldd #$5555: colour 5 in all four pixels.
            a.branch(0x20, go) // bra go
            a.label(off)
            a.emit(0xCC, 0x00, 0x00) // ldd #0
            a.label(go)
            a.ext(0x8E, cellAddress(column)) // ldx #cell
            a.jump(0xBD, "fillcell") // jsr fillcell
        }

        a.label("reset")
        a.emit(0x1A, 0x50) // orcc #$50: IRQ and FIRQ stay masked.
        a.emit(0x10, 0xCE, 0x08, 0x00) // lds #$0800
        a.emit(0xCE, 0x00, 0x00) // ldu #0: the toggle.
        a.emit(0x4F) // clra
        for address: UInt16 in [0x9070, 0x9200, held, keys] { a.ext(0xB7, address) } // No cocktail flip, palette bank 0.
        a.emit(0x86, toneStep); a.ext(0xB7, 0x9838) // Tone frequency.
        a.emit(0x86, 0xFF); a.ext(0xB7, 0x9839) // Tone volume.

        // NVRAM. A first boot has no magic.
        let first = a.newLabel()
        a.emit(0x5F) // clrb
        a.ext(0xB6, 0x9C00) // lda $9C00
        a.emit(0x81, nvramMagic[0]) // cmpa #'G'
        a.branch(0x26, first) // bne first
        a.ext(0xF6, 0x9C00 + UInt16(nvramBootCounterOffset)) // ldb counter
        a.label(first)
        a.emit(0x5C) // incb
        a.ext(0xF7, 0x9C00 + UInt16(nvramBootCounterOffset)) // stb counter
        a.emit(0xCC, nvramMagic[0], nvramMagic[1]) // ldd #"GA"
        a.ext(0xFD, 0x9C00); a.ext(0xFD, 0x9C02) // std $9C00; std $9C02

        // Bands: 60 lines of 128 bytes, two pixels a byte, high nibble first.
        a.emit(0x8E, 0x08, 0x00) // ldx #$0800
        for color in 1...4 {
            let byte = UInt8(color << 4 | color), fill = a.newLabel()
            a.emit(0xCC, byte, byte) // ldd #pixels
            a.emit(0x10, 0x8E); a.word(UInt16(bandHeight * 128 / 2)) // ldy #words
            a.label(fill)
            a.emit(0xED, 0x81) // std ,x++
            a.emit(0x31, 0x3F) // leay -1,y
            a.branch(0x26, fill) // bne fill
        }

        a.label("frame")
        let active = a.newLabel(), blank = a.newLabel()
        a.label(active)
        a.ext(0xB6, 0x9700) // lda IN2: bit 7 is VBlank.
        a.branch(0x2B, active) // bmi: wait for the end of this VBlank.
        a.label(blank)
        a.ext(0xB6, 0x9700)
        a.branch(0x2A, blank) // bpl: wait for the next one.
        a.ext(0xB7, 0x9380) // Watchdog.

        // Active low inputs into keys: bit 0 button 1 (IN0 bit 0), bit 1 start 1 (IN1 bit 2).
        a.ext(0xB6, 0x9502); a.emit(0x43, 0x84, 0x01); a.ext(0xB7, keys) // lda IN0; coma; anda #1; sta keys
        a.ext(0xB6, 0x9503); a.emit(0x43, 0x84, 0x04, 0x44); a.ext(0xBA, keys); a.ext(0xB7, keys) // lda IN1; coma; anda #4; lsra; ora; sta
        a.ext(0xB6, keys); a.emit(0x85, 0x01) // lda keys; bita #1
        drawCell(cellColumns[0])
        a.ext(0xB6, keys); a.emit(0x85, 0x02) // lda keys; bita #2
        drawCell(cellColumns[1])

        // Flip the toggle on the press of both only.
        let notHeld = a.newLabel(), done = a.newLabel()
        a.ext(0xB6, keys); a.emit(0x81, 0x03) // lda keys; cmpa #3
        a.branch(0x26, notHeld) // bne
        a.ext(0xB6, held) // lda held
        a.branch(0x26, done) // bne: still held from last frame.
        a.emit(0x1F, 0x30, 0xC8, 0x01, 0x1F, 0x03) // tfr u,d; eorb #1; tfr d,u
        a.emit(0x86, 0x01); a.ext(0xB7, held) // lda #1; sta held
        a.branch(0x20, done) // bra
        a.label(notHeld)
        a.ext(0x7F, held) // clr held
        a.label(done)
        a.emit(0x1F, 0x30, 0xC5, 0x01) // tfr u,d; bitb #1
        drawCell(cellColumns[2])
        a.jump(0x7E, "frame") // jmp frame

        // X: the cell's top left byte, D: four pixels. 16 lines of 16 bytes.
        a.label("fillcell")
        let line = a.newLabel()
        a.emit(0x10, 0x8E, 0x00, UInt8(cellSize.height)) // ldy #16
        a.label(line)
        for offset in stride(from: 0, to: cellSize.width / 2, by: 2) { a.emit(0xED, UInt8(offset)) } // std n,x
        a.emit(0x30, 0x89, 0x00, 0x80) // leax 128,x
        a.emit(0x31, 0x3F) // leay -1,y
        a.branch(0x26, line) // bne
        a.emit(0x39) // rts

        a.label("rti")
        a.emit(0x3B) // rti
        let code = a.resolved()
        let rti = a.address("rti"), reset = a.address("reset")
        precondition(code.count <= 0x1000, "the program must fit gridfnla.bin")
        return (code, [rti, rti, rti, rti, rti, rti, reset])
    }

    /// Just enough of a 6809 assembler: big-endian operands, labels, 8-bit relative branches.
    private struct Assembler {
        private static let origin: UInt16 = 0xA000
        private var bytes: [UInt8] = []
        private var labels: [String: UInt16] = [:]
        private var fixups: [(at: Int, label: String, relative: Bool)] = []
        private var count = 0
        private var here: UInt16 { Self.origin + UInt16(bytes.count) }

        mutating func emit(_ values: UInt8...) { bytes += values }
        mutating func word(_ value: UInt16) { bytes += [UInt8(value >> 8), UInt8(value & 0xFF)] }
        /// An opcode with an extended (absolute) or 16-bit immediate operand.
        mutating func ext(_ opcode: UInt8, _ value: UInt16) { emit(opcode); word(value) }
        mutating func newLabel() -> String { count += 1; return "L\(count)" }
        mutating func label(_ name: String) { labels[name] = here }
        func address(_ name: String) -> UInt16 { labels[name]! }

        mutating func branch(_ opcode: UInt8, _ target: String) {
            emit(opcode, 0)
            fixups.append((bytes.count - 1, target, true))
        }

        mutating func jump(_ opcode: UInt8, _ target: String) {
            emit(opcode, 0, 0)
            fixups.append((bytes.count - 2, target, false))
        }

        func resolved() -> [UInt8] {
            var out = bytes
            for fixup in fixups {
                let target = Int(labels[fixup.label]!)
                if fixup.relative {
                    let delta = target - (Int(Self.origin) + fixup.at + 1)
                    precondition((-128...127).contains(delta), "branch out of range")
                    out[fixup.at] = UInt8(bitPattern: Int8(delta))
                } else {
                    out[fixup.at] = UInt8(target >> 8)
                    out[fixup.at + 1] = UInt8(target & 0xFF)
                }
            }
            return out
        }
    }
}
#endif
