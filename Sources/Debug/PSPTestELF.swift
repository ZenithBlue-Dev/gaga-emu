#if DEBUG
import Foundation

/// Generates a small homebrew PSP program, so tests need no commercial UMD and no Sony firmware. A user-mode
/// ELF of hand-assembled Allegrex that imports a few kernel functions by NID, which PPSSPP's HLE kernel
/// links and runs. `scripts/make-test-rom.sh` writes it to a file.
///
/// What the program does:
/// - Four horizontal bands, 68 lines each, written by the CPU into the framebuffer at VRAM 0x04000000 (480 by
///   272, stride 512, 8888): red, green, blue, white.
/// - Key cells, 16 by 16 from x 32 on line 16: white while that sceCtrl button bit is held, else the band.
/// - Toggle cell, x 0 on line 16: pressing Cross and Circle together flips it. The flag lives only in a CPU
///   register, so it proves a save state restored the CPU.
/// - Counter cells, from x 32 on line 40: a boot counter, one bit per cell. It lives in `countPath` on the
///   memory stick, read and written once per boot.
/// - Audio channel output of a square wave at `toneHertz`, offered every frame.
/// - Waits for VBlank with sceDisplayWaitVblankStart.
enum PSPTestELF {
    static let width = 480
    static let height = 272
    static let bandHeight = 68
    static let cellSize = 16
    static let keyRow = 16
    static let counterRow = 40
    static let cellColumn = 32
    /// The boot counter's file, relative to the memory stick root (the core's save folder).
    static let countFolder = "PSP/SAVEDATA/GAGATEST0"
    static let countFile = "COUNT.BIN"
    static let toneHertz = 441.0
    // sceCtrl bits.
    static let buttonStart: UInt32 = 0x0008
    static let buttonRight: UInt32 = 0x0020
    static let buttonCircle: UInt32 = 0x2000
    static let buttonCross: UInt32 = 0x4000
    static let chord: UInt32 = 0x6000 // Cross and Circle.
    /// Framebuffer words, 0xAABBGGRR: red, green, blue, white. The cells are white or red.
    static let bandColors: [UInt32] = [0xFF00_00FF, 0xFF00_FF00, 0xFFFF_0000, 0xFFFF_FFFF]
    static let white = 3

    /// The band index (0 red, 1 green, 2 blue, 3 white) at a pixel. `keys` is in sceCtrl bits.
    static func expectedColor(x: Int, y: Int, keys: UInt32 = 0, toggle: Bool = false, counter: Int = 1) -> Int {
        func cell(_ row: Int) -> Bool { (row..<(row + cellSize)).contains(y) }
        let column = (x - cellColumn) / cellSize
        let inBits = x >= cellColumn && column < 16
        if cell(keyRow) {
            if inBits && keys & (1 << UInt32(column)) != 0 { return white }
            if x < cellSize && toggle { return white }
            if inBits || x < cellSize { return 0 }
        }
        if cell(counterRow) && inBits { return counter & (1 << column) != 0 ? white : 0 }
        return y / bandHeight
    }

    static func build() -> Data { elf() }

    // MARK: - Layout

    /// Everything is one segment at the start of user memory. Data first, at fixed offsets, then the code.
    private static let base: UInt32 = 0x0880_4000
    private static let moduleInfo = base
    private static let stubEntries = base + 0x40
    private static let nidTables = base + 0x100
    private static let stubs = base + 0x140
    private static let strings = base + 0x200
    private static let ctrlBuffer = base + 0x300
    private static let countBuffer = base + 0x310
    private static let audioBuffer = base + 0x400
    private static let audioSamples = 1024
    private static let code = base + 0x1400

    /// The imports, in stub order. NIDs from upstream's HLE tables (Core/HLE/sce*.cpp).
    private static let imports: [(module: String, functions: [(name: String, nid: UInt32)])] = [
        ("sceDisplay", [("sceDisplaySetMode", 0x0E20_F177), ("sceDisplaySetFrameBuf", 0x289D_82FE),
                        ("sceDisplayWaitVblankStart", 0x984C_27E7)]),
        ("sceCtrl", [("sceCtrlSetSamplingCycle", 0x6A27_74F3), ("sceCtrlSetSamplingMode", 0x1F40_11E6),
                     ("sceCtrlPeekBufferPositive", 0x3A62_2550)]),
        ("sceAudio", [("sceAudioChReserve", 0x5EC8_1C55), ("sceAudioOutput", 0x8C10_09B2)]),
        ("IoFileMgrForUser", [("sceIoOpen", 0x109F_50BC), ("sceIoRead", 0x6A63_8D83), ("sceIoWrite", 0x42EC_03AC),
                              ("sceIoClose", 0x810C_4BC3), ("sceIoMkdir", 0x06A7_0004)]),
    ]

    private static func stub(_ name: String) -> UInt32 {
        let names = imports.flatMap { $0.functions.map(\.name) }
        return stubs + UInt32(names.firstIndex(of: name)!) * 8
    }

    /// Zero-terminated strings at `strings`, and their addresses.
    private static let stringList: [String] = imports.map(\.module) + [
        "ms0:/PSP", "ms0:/PSP/SAVEDATA", "ms0:/\(countFolder)", "ms0:/\(countFolder)/\(countFile)",
    ]

    private static func address(of string: String) -> UInt32 {
        var at = strings
        for item in stringList {
            if item == string { return at }
            at += UInt32(item.utf8.count + 1)
        }
        preconditionFailure("no string \(string)")
    }

    // MARK: - Program

    private static func program() -> [UInt32] {
        var a = Assembler(origin: code)
        func call(_ name: String) { a.jal(stub(name)) }

        a.li(.a0, 0); a.li(.a1, UInt32(width)); a.li(.a2, UInt32(height))
        call("sceDisplaySetMode")
        a.li(.a0, 0x0400_0000); a.li(.a1, 512); a.li(.a2, 3); a.li(.a3, 1) // 8888, from the next frame.
        call("sceDisplaySetFrameBuf")
        a.li(.a0, 0)
        call("sceCtrlSetSamplingCycle")
        a.li(.a0, 1)
        call("sceCtrlSetSamplingMode")

        // The boot counter: make the folders (an existing one is an error, ignored), read, count, write.
        for folder in ["ms0:/PSP", "ms0:/PSP/SAVEDATA", "ms0:/\(countFolder)"] {
            a.li(.a0, address(of: folder)); a.li(.a1, 0o777)
            call("sceIoMkdir")
        }
        let path = address(of: "ms0:/\(countFolder)/\(countFile)")
        a.li(.s3, 0) // s3: the boot counter.
        a.li(.a0, path); a.li(.a1, 0x0001); a.li(.a2, 0) // PSP_O_RDONLY
        call("sceIoOpen")
        a.bltz(.v0, "fresh")
        a.or(.s4, .v0, .zero)
        a.or(.a0, .s4, .zero); a.li(.a1, countBuffer); a.li(.a2, 4)
        call("sceIoRead")
        a.or(.a0, .s4, .zero)
        call("sceIoClose")
        a.li(.t0, countBuffer)
        a.lw(.s3, 0, .t0)
        a.label("fresh")
        a.addiu(.s3, .s3, 1)
        a.andi(.s3, .s3, 0xFFFF)
        a.li(.t0, countBuffer)
        a.sw(.s3, 0, .t0)
        a.li(.a0, path); a.li(.a1, 0x0602); a.li(.a2, 0o777) // PSP_O_WRONLY | PSP_O_CREAT | PSP_O_TRUNC
        call("sceIoOpen")
        a.bltz(.v0, "written")
        a.or(.s4, .v0, .zero)
        a.or(.a0, .s4, .zero); a.li(.a1, countBuffer); a.li(.a2, 4)
        call("sceIoWrite")
        a.or(.a0, .s4, .zero)
        call("sceIoClose")
        a.label("written")

        a.li(.a0, 0xFFFF_FFFF); a.li(.a1, UInt32(audioSamples)); a.li(.a2, 0) // Any channel, stereo.
        call("sceAudioChReserve")
        a.or(.s6, .v0, .zero) // s6: the audio channel, negative when none.

        for (band, color) in bandColors.enumerated() {
            a.li(.a0, color); a.li(.a1, 0); a.li(.a2, UInt32(band * bandHeight))
            a.li(.a3, UInt32(width)); a.li(.v1, UInt32(bandHeight))
            a.jal("fill")
        }
        a.li(.s0, 0) // s0 bit 0: the toggle. Bit 1: the chord was held last frame.

        a.label("frame")
        a.li(.a0, ctrlBuffer); a.li(.a1, 1)
        call("sceCtrlPeekBufferPositive")
        a.li(.t0, ctrlBuffer)
        a.lw(.s2, 4, .t0) // s2: the buttons.
        a.or(.t8, .s2, .zero)
        a.li(.t9, UInt32(keyRow))
        a.jal("row")
        a.or(.t8, .s3, .zero)
        a.li(.t9, UInt32(counterRow))
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
        a.li(.a1, 0); a.li(.a2, UInt32(keyRow))
        a.jal("cell")

        a.bltz(.s6, "quiet")
        a.or(.a0, .s6, .zero); a.li(.a1, 0x8000); a.li(.a2, audioBuffer) // Full volume. Busy is fine.
        call("sceAudioOutput")
        a.label("quiet")
        call("sceDisplayWaitVblankStart")
        a.j("frame")

        // fill: a0 colour, a1 x, a2 y, a3 width, v1 height. Uses t0 to t5.
        a.label("fill")
        a.sll(.t0, .a2, 9)
        a.addu(.t0, .t0, .a1)
        a.sll(.t0, .t0, 2)
        a.lui(.t1, 0x0400)
        a.addu(.t0, .t0, .t1)
        a.or(.t3, .v1, .zero)
        a.label("fill-row")
        a.or(.t4, .t0, .zero)
        a.or(.t5, .a3, .zero)
        a.label("fill-column")
        a.sw(.a0, 0, .t4)
        a.addiu(.t4, .t4, 4)
        a.addiu(.t5, .t5, -1)
        a.bne(.t5, .zero, "fill-column")
        a.addiu(.t0, .t0, 2048)
        a.addiu(.t3, .t3, -1)
        a.bne(.t3, .zero, "fill-row")
        a.jr(.ra)

        // cell: one cell at a1, a2, white when t2 is not zero, else red. Ends in fill.
        a.label("cell")
        a.li(.a0, bandColors[0])
        a.beq(.t2, .zero, "cell-draw")
        a.li(.a0, bandColors[white])
        a.label("cell-draw")
        a.li(.a3, UInt32(cellSize)); a.li(.v1, UInt32(cellSize))
        a.j("fill")

        // row: 16 cells from x 32 on line t9, one per bit of t8. Uses s4, s5 and s7.
        a.label("row")
        a.or(.s7, .ra, .zero)
        a.li(.s4, 0)
        a.li(.s5, UInt32(cellColumn))
        a.label("row-next")
        a.srlv(.t2, .t8, .s4)
        a.andi(.t2, .t2, 1)
        a.or(.a1, .s5, .zero)
        a.or(.a2, .t9, .zero)
        a.jal("cell")
        a.addiu(.s4, .s4, 1)
        a.addiu(.s5, .s5, Int16(cellSize))
        a.sltiu(.t2, .s4, 16)
        a.bne(.t2, .zero, "row-next")
        a.jr(.s7)
        return a.finish()
    }

    // MARK: - ELF

    /// An ELF32 MIPS executable with one loadable segment and no sections. With no .rodata.sceModuleInfo,
    /// PPSSPP finds the module info at the segment's p_paddr, a file offset (sceKernelModule.cpp).
    private static func elf() -> Data {
        var segment = [UInt8](repeating: 0, count: Int(code - base))
        func put32(_ value: UInt32, _ address: UInt32) {
            for byte in 0..<4 { segment[Int(address - base) + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8)) }
        }
        func put16(_ value: UInt16, _ address: UInt32) {
            segment[Int(address - base)] = UInt8(value & 0xFF)
            segment[Int(address - base) + 1] = UInt8(value >> 8)
        }
        func putBytes(_ bytes: [UInt8], _ address: UInt32) {
            segment.replaceSubrange(Int(address - base)..<(Int(address - base) + bytes.count), with: bytes)
        }

        // PspModuleInfo: attributes (user mode), version, name[28], gp, libent, libentend, libstub, libstubend.
        put16(0, moduleInfo)
        put16(0x0101, moduleInfo + 2)
        putBytes(Array("GagaPSPTest".utf8), moduleInfo + 4)
        put32(stubEntries, moduleInfo + 0x2C)
        put32(stubEntries + UInt32(imports.count * 20), moduleInfo + 0x30)

        var at = strings
        for item in stringList {
            putBytes(Array(item.utf8) + [0], at)
            at += UInt32(item.utf8.count + 1)
        }
        precondition(at <= ctrlBuffer, "strings overflow")

        // PspLibStubEntry: name, version, flags, size in words (5), variables, functions, NIDs, first stub.
        var nid = nidTables, slot = stubs
        for (index, entry) in imports.enumerated() {
            let entryAddress = stubEntries + UInt32(index * 20)
            put32(address(of: entry.module), entryAddress)
            put16(0x4001, entryAddress + 4)
            put16(0x0009, entryAddress + 6)
            segment[Int(entryAddress - base) + 8] = 5
            segment[Int(entryAddress - base) + 9] = 0
            put16(UInt16(entry.functions.count), entryAddress + 10)
            put32(nid, entryAddress + 12)
            put32(slot, entryAddress + 16)
            for function in entry.functions {
                put32(function.nid, nid)
                put32(0x03E0_0008, slot) // jr ra, then a nop that the kernel replaces with the syscall.
                nid += 4
                slot += 8
            }
        }
        precondition(nid <= stubs && slot <= strings, "imports overflow")

        // The tone: stereo 16-bit, a whole number of periods in the buffer.
        let period = 44100.0 / toneHertz
        for sample in 0..<audioSamples {
            let level: Int16 = Double(sample).truncatingRemainder(dividingBy: period) < period / 2 ? 12000 : -12000
            let word = UInt32(UInt16(bitPattern: level))
            put32(word | word << 16, audioBuffer + UInt32(sample * 4))
        }

        let text = program().flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> ($0 * 8)) } }
        segment += text

        let offset = 0x100
        var file = [UInt8](repeating: 0, count: offset)
        func header32(_ value: UInt32, _ at: Int) {
            for byte in 0..<4 { file[at + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8)) }
        }
        func header16(_ value: UInt16, _ at: Int) {
            file[at] = UInt8(value & 0xFF)
            file[at + 1] = UInt8(value >> 8)
        }
        file.replaceSubrange(0..<8, with: [0x7F, 0x45, 0x4C, 0x46, 1, 1, 1, 0]) // ELF, 32-bit, little-endian.
        header16(2, 16) // ET_EXEC
        header16(8, 18) // EM_MIPS
        header32(1, 20)
        header32(code, 24) // Entry.
        header32(52, 28) // Program headers.
        header32(0x10A2_3001, 36) // The PSP's MIPS flags.
        header16(52, 40)
        header16(32, 42)
        header16(1, 44)
        header16(40, 46)
        // Elf32_Phdr: PT_LOAD, offset, vaddr, paddr (module info's file offset), filesz, memsz, RWX, align.
        let ph = 52
        header32(1, ph)
        header32(UInt32(offset), ph + 4)
        header32(base, ph + 8)
        header32(UInt32(offset) + (moduleInfo - base), ph + 12)
        header32(UInt32(segment.count), ph + 16)
        header32(UInt32(segment.count), ph + 20)
        header32(7, ph + 24)
        header32(16, ph + 28)
        return Data(file + segment)
    }

    // MARK: - Assembler

    private enum Reg: UInt32 {
        case zero = 0, v0 = 2, v1 = 3, a0 = 4, a1 = 5, a2 = 6, a3 = 7, t0 = 8, t1 = 9, t2 = 10, t3 = 11, t4 = 12, t5 = 13
        case s0 = 16, s1, s2, s3, s4, s5, s6, s7, t8 = 24, t9 = 25, ra = 31
    }

    /// Just enough of a MIPS II assembler. Every branch and jump gets a nop in its delay slot.
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
        mutating func lw(_ rt: Reg, _ offset: UInt16, _ base: Reg) { immediate(0x23, rt, base, offset); nop() }
        mutating func or(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x25, rd: rd, rs: rs, rt: rt) }
        mutating func and(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x24, rd: rd, rs: rs, rt: rt) }
        mutating func xor(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x26, rd: rd, rs: rs, rt: rt) }
        mutating func nor(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x27, rd: rd, rs: rs, rt: rt) }
        mutating func addu(_ rd: Reg, _ rs: Reg, _ rt: Reg) { special(0x21, rd: rd, rs: rs, rt: rt) }
        mutating func sll(_ rd: Reg, _ rt: Reg, _ shift: UInt32) { special(0x00, rd: rd, rt: rt, shift: shift) }
        mutating func srl(_ rd: Reg, _ rt: Reg, _ shift: UInt32) { special(0x02, rd: rd, rt: rt, shift: shift) }
        mutating func srlv(_ rd: Reg, _ rt: Reg, _ rs: Reg) { special(0x06, rd: rd, rs: rs, rt: rt) }
        mutating func jr(_ rs: Reg) { special(0x08, rd: .zero, rs: rs); nop() }

        mutating func li(_ rt: Reg, _ value: UInt32) {
            if value >> 16 == 0 { return ori(rt, .zero, UInt16(value)) }
            lui(rt, UInt16(value >> 16))
            if value & 0xFFFF != 0 { ori(rt, rt, UInt16(value & 0xFFFF)) }
        }

        private mutating func branch(_ word: UInt32, _ label: String) {
            fixups.append((words.count, label, false))
            emit(word)
            nop()
        }

        mutating func beq(_ rs: Reg, _ rt: Reg, _ label: String) { branch(0x04 << 26 | rs.rawValue << 21 | rt.rawValue << 16, label) }
        mutating func bne(_ rs: Reg, _ rt: Reg, _ label: String) { branch(0x05 << 26 | rs.rawValue << 21 | rt.rawValue << 16, label) }
        mutating func bltz(_ rs: Reg, _ label: String) { branch(0x01 << 26 | rs.rawValue << 21, label) }

        private mutating func jump(_ op: UInt32, _ label: String) {
            fixups.append((words.count, label, true))
            emit(op << 26)
            nop()
        }

        mutating func j(_ label: String) { jump(0x02, label) }
        mutating func jal(_ label: String) { jump(0x03, label) }
        /// jal to a fixed address, such as an import stub.
        mutating func jal(_ address: UInt32) {
            emit(0x03 << 26 | address >> 2 & 0x03FF_FFFF)
            nop()
        }

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
