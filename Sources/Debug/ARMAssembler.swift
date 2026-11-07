#if DEBUG
import Foundation

/// Just enough of an ARM assembler (ARMv4, which the DS's ARMv5 also runs) for the generated test ROMs.
/// `here` is the address the next instruction runs at: `origin` plus what is emitted so far.
struct ARMAssembler {
    enum Cond: UInt32 { case eq = 0x0, ne = 0x1, always = 0xE }

    let origin: Int
    private(set) var bytes: [UInt8] = []
    var here: Int { origin + bytes.count }

    init(origin: Int) { self.origin = origin }

    mutating func word(_ value: UInt32) {
        bytes += withUnsafeBytes(of: value.littleEndian, Array.init)
    }

    /// ARM immediates are 8 bits rotated right by an even amount.
    private static func immediate(_ value: UInt32) -> UInt32 {
        for rotate in 0..<16 {
            let unrotated = (value << UInt32(rotate * 2)) | (rotate == 0 ? 0 : value >> (32 - UInt32(rotate * 2)))
            if unrotated <= 0xFF { return UInt32(rotate) << 8 | unrotated }
        }
        preconditionFailure("no ARM immediate for \(value)")
    }

    private mutating func alu(_ opcode: UInt32, rd: Int, rn: Int, _ value: UInt32, cond: Cond = .always) {
        word(cond.rawValue << 28 | 0x02000000 | opcode << 20 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.immediate(value))
    }

    mutating func mov(_ rd: Int, _ value: UInt32, cond: Cond = .always) { alu(0x1A, rd: rd, rn: 0, value, cond: cond) }
    mutating func add(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x08, rd: rd, rn: rn, value) }
    mutating func subs(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x05, rd: rd, rn: rn, value) }
    mutating func cmp(_ rn: Int, _ value: UInt32) { alu(0x15, rd: 0, rn: rn, value) }
    mutating func tst(_ rn: Int, _ value: UInt32) { alu(0x11, rd: 0, rn: rn, value) }
    private mutating func orr(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x18, rd: rd, rn: rn, value) }
    mutating func ands(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x01, rd: rd, rn: rn, value) }
    mutating func and(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x00, rd: rd, rn: rn, value) }
    mutating func bic(_ rd: Int, _ rn: Int, _ value: UInt32) { alu(0x1C, rd: rd, rn: rn, value) }
    mutating func eor(_ rd: Int, _ rn: Int, _ value: UInt32, cond: Cond = .always) { alu(0x02, rd: rd, rn: rn, value, cond: cond) }
    mutating func bicReg(_ rd: Int, _ rn: Int, _ rm: Int) { word(0xE1C00000 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(rm)) }
    mutating func orrReg(_ rd: Int, _ rn: Int, _ rm: Int, lsl: Int = 0) {
        word(0xE1800000 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(lsl) << 7 | UInt32(rm))
    }
    mutating func addReg(_ rd: Int, _ rn: Int, _ rm: Int, lsl: Int = 0) {
        word(0xE0800000 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(lsl) << 7 | UInt32(rm))
    }

    /// mov and orr, one byte at a time. ARMv4 has no movw, and this avoids a literal pool.
    mutating func load32(_ rd: Int, _ value: UInt32) {
        var pending = (0..<4).map { value & (0xFF << UInt32($0 * 8)) }.filter { $0 != 0 }
        mov(rd, pending.isEmpty ? 0 : pending.removeFirst())
        for part in pending { orr(rd, rd, part) }
    }

    mutating func movReg(_ rd: Int, _ rm: Int, cond: Cond = .always) {
        word(cond.rawValue << 28 | 0x01A00000 | UInt32(rd) << 12 | UInt32(rm))
    }

    /// mov rd, rm, lsr #shift (shift 1 to 31).
    mutating func lsr(_ rd: Int, _ rm: Int, _ shift: Int) {
        word(0xE1A00020 | UInt32(rd) << 12 | UInt32(shift) << 7 | UInt32(rm))
    }

    /// msr cpsr_c, #value: sets the mode and the interrupt masks.
    mutating func msrControl(_ value: UInt32) { word(0xE321F000 | value) }

    private static func halfwordOffset(_ offset: Int) -> UInt32 {
        precondition((0...0xFF).contains(offset), "halfword offsets are 8 bits")
        return UInt32(offset >> 4) << 8 | UInt32(offset & 0xF)
    }

    private static func wordOffset(_ offset: Int) -> UInt32 {
        precondition((0...0xFFF).contains(offset), "word and byte offsets are 12 bits")
        return UInt32(offset)
    }

    mutating func strh(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE1C000B0 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.halfwordOffset(offset))
    }

    mutating func strhPost(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE0C000B0 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.halfwordOffset(offset))
    }

    mutating func ldrh(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE1D000B0 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.halfwordOffset(offset))
    }

    mutating func str(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE5800000 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.wordOffset(offset))
    }

    mutating func ldr(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE5900000 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.wordOffset(offset))
    }

    /// ldr rd, [rn, rm, lsl #2]: a word table lookup.
    mutating func ldrIndexed(_ rd: Int, _ rn: Int, _ rm: Int) {
        word(0xE7900100 | UInt32(rn) << 16 | UInt32(rd) << 12 | UInt32(rm))
    }

    mutating func strb(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE5C00000 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.wordOffset(offset))
    }

    mutating func ldrb(_ rd: Int, _ rn: Int, _ offset: Int) {
        word(0xE5D00000 | UInt32(rn) << 16 | UInt32(rd) << 12 | Self.wordOffset(offset))
    }

    mutating func swi(_ comment: UInt32) { word(0xEF000000 | comment) }

    mutating func branch(to target: Int, cond: Cond = .always) {
        let delta = (target - (here + 8)) / 4
        word(cond.rawValue << 28 | 0x0A000000 | UInt32(truncatingIfNeeded: delta) & 0xFFFFFF)
    }
}
#endif
