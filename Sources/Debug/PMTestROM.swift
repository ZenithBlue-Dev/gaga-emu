#if DEBUG
import Foundation

/// Generates a small homebrew Pokemon Mini cartridge, so tests need no commercial game and no Nintendo
/// material. Hand-assembled S1C88. The core boots it with its own free BIOS, which checks for "MN" at 0x2100
/// and jumps to 0x2102. `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - The PRC only copies the frame buffer in RAM to the LCD, so the program draws pixels directly: a black
///   band on pages 3 and 4 and a striped one on page 5. Each byte is a column of eight pixels.
/// - Eight key cells on page 7, ten pixels wide every twelve: black while that key bit is held. The bits are
///   A, B, C, Up, Down, Left, Right, Power.
/// - Timer 3 drives the speaker with a square wave of about 488 Hz.
/// - EEPROM: "GAGA" at `eepromMagicAddress` and a boot counter after it, read and rewritten once per boot
///   over the console's I2C pins. The core keeps the EEPROM in `<game>.eep`.
/// - Toggle cell, page 6 columns 0 to 9: pressing A and B together flips it. The flag lives in RAM.
enum PMTestROM {
    static let size = 0x8000
    static let eepromMagic: [UInt8] = Array("GAGA".utf8)
    static let eepromMagicAddress = 0x0010

    // RAM: the frame buffer at 0x1000, then the chord's previous state, the toggle flag, the keys and a copy of
    // the EEPROM bytes.
    private static let frame = 0x1000, previous = 0x1400, toggle = 0x1401, keys = 0x1403, copy = 0x1410

    /// Relative branches land at the instruction's last byte plus the offset, as upstream's JMPS computes.
    private struct Assembler {
        let base: Int
        var bytes: [UInt8] = []
        var labels: [String: Int] = [:]
        var fixups: [(at: Int, label: String, wide: Bool)] = []

        mutating func label(_ name: String) { labels[name] = base + bytes.count }
        mutating func emit(_ values: UInt8...) { bytes += values }
        mutating func emit16(_ op: UInt8, _ value: Int) { bytes += [op, UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)] }
        mutating func branch(_ op: UInt8, _ name: String, wide: Bool = false) {
            bytes.append(op)
            fixups.append((bytes.count, name, wide))
            bytes += wide ? [0, 0] : [0]
        }

        func resolved() -> [UInt8] {
            var out = bytes
            for fixup in fixups {
                let target = labels[fixup.label]!
                let last = base + fixup.at + (fixup.wide ? 1 : 0)
                let offset = target - last
                if fixup.wide {
                    out[fixup.at] = UInt8(offset & 0xFF)
                    out[fixup.at + 1] = UInt8(offset >> 8 & 0xFF)
                } else {
                    precondition((-128...127).contains(offset), "branch to \(fixup.label) out of range")
                    out[fixup.at] = UInt8(bitPattern: Int8(offset))
                }
            }
            return out
        }
    }

    // Opcodes, from upstream's MinxCPU_XX.c. Registers 0x20nn are reached as [N+nn] with N = 0x20.
    private static let jz: UInt8 = 0xE6, jnz: UInt8 = 0xE7, jmp: UInt8 = 0xF1, jmpWide: UInt8 = 0xF3, call: UInt8 = 0xF2
    private static func io(_ asm: inout Assembler, _ register: UInt8, _ value: UInt8) { asm.emit(0xDD, register, value) }
    /// The I2C pins: data 0x04, clock 0x08, both outputs unless a read switches data to input.
    private static func pins(_ asm: inout Assembler, _ values: UInt8...) { for value in values { io(&asm, 0x61, value) } }

    static func build() -> Data {
        var asm = Assembler(base: 0x2102)
        asm.branch(jmpWide, "start", wide: true)
        while asm.base + asm.bytes.count < 0x21D0 { asm.emit(0xFF) } // Interrupt vectors and header, unused.

        asm.label("start")
        asm.emit(0xB4, 0x20) // MOV N, 0x20
        // Sound: oscillator 1 at 2 MHz into timer 3, 16 bits, preset 0x1000 and pivot half of it, full volume.
        for (register, value) in [(0x19, 0x20), (0x1C, 0x08), (0x1D, 0x00), (0x4A, 0x00), (0x4B, 0x10), (0x4C, 0x00),
                                  (0x4D, 0x08), (0x48, 0x86), (0x70, 0x00), (0x71, 0x03)] as [(UInt8, UInt8)] {
            io(&asm, register, value)
        }
        io(&asm, 0x80, 0x08) // PRC: copy only.
        io(&asm, 0x81, 0x08) // Every second frame.

        // Bands. The BIOS cleared RAM, so pages 0 to 2 are already white.
        for (first, end, value) in [(frame + 3 * 96, frame + 5 * 96, 0xFF), (frame + 5 * 96, frame + 6 * 96, 0x55)] {
            let name = "band\(first)"
            asm.emit16(0xC5, first) // MOV HL, first
            asm.label(name)
            asm.emit(0xB5, UInt8(value), 0x91) // MOV [HL], value; INC HL
            asm.emit16(0xD5, end) // CMP HL, end
            asm.branch(jnz, name)
        }

        // Boot counter: read five EEPROM bytes into RAM, start them fresh when the magic is missing, count
        // this boot and write them back.
        asm.emit(0xDD, 0x60, 0x0C) // Both pins as outputs.
        asm.branch(call, "i2cStart", wide: true)
        for byte: UInt8 in [0xA0, UInt8(eepromMagicAddress >> 8), UInt8(eepromMagicAddress & 0xFF)] {
            asm.emit(0xB0, byte)
            asm.branch(call, "i2cSend", wide: true)
        }
        asm.branch(call, "i2cStart", wide: true)
        asm.emit(0xB0, 0xA1)
        asm.branch(call, "i2cSend", wide: true)
        asm.emit16(0xC5, copy)
        for _ in 0..<5 {
            asm.branch(call, "i2cRead", wide: true)
            asm.emit(0x91) // INC HL
        }
        asm.branch(call, "i2cStop", wide: true)

        asm.emit16(0xC5, copy)
        for byte in eepromMagic {
            asm.emit(0xB0, byte, 0x33) // MOV A, byte; CMP A, [HL]
            asm.branch(jnz, "fresh")
            asm.emit(0x91)
        }
        asm.branch(jmp, "count")
        asm.label("fresh")
        asm.emit16(0xC5, copy)
        for byte in eepromMagic + [0] { asm.emit(0xB5, byte, 0x91) }
        asm.label("count")
        asm.emit16(0xC5, copy + 4)
        asm.emit(0x86) // INC [HL]

        asm.branch(call, "i2cStart", wide: true)
        for byte: UInt8 in [0xA0, UInt8(eepromMagicAddress >> 8), UInt8(eepromMagicAddress & 0xFF)] {
            asm.emit(0xB0, byte)
            asm.branch(call, "i2cSend", wide: true)
        }
        asm.emit16(0xC5, copy)
        for _ in 0..<5 {
            asm.emit(0x45) // MOV A, [HL]
            asm.branch(call, "i2cSend", wide: true)
            asm.emit(0x91)
        }
        asm.branch(call, "i2cStop", wide: true)

        // Main loop. Keys read 0 while held.
        asm.label("main")
        asm.emit(0x44, 0x52, 0x3A, 0xFF) // MOV A, [N+0x52]; XOR A, 0xFF
        asm.emit16(0xC5, keys)
        asm.emit(0x68, 0x22, 0x03, 0x32, 0x03) // MOV [HL], A; AND A, 3; CMP A, 3
        asm.branch(jnz, "released")
        asm.emit16(0xC5, previous)
        asm.emit(0x45, 0x32, 0x00) // MOV A, [HL]; CMP A, 0
        asm.branch(jnz, "held")
        asm.emit16(0xC5, toggle)
        asm.emit(0x45, 0x3A, 0x01, 0x68) // MOV A, [HL]; XOR A, 1; MOV [HL], A
        asm.label("held")
        asm.emit16(0xC5, previous)
        asm.emit(0xB5, 0x01)
        asm.branch(jmp, "draw")
        asm.label("released")
        asm.emit16(0xC5, previous)
        asm.emit(0xB5, 0x00)
        asm.label("draw")

        let cells = (0..<8).map { (keys, UInt8(1 << $0), frame + 7 * 96 + 12 * $0) } + [(toggle, UInt8(1), frame + 6 * 96)]
        for (index, (source, mask, start)) in cells.enumerated() {
            asm.emit16(0xC5, source)
            asm.emit(0x45, 0x22, mask) // MOV A, [HL]; AND A, mask
            asm.branch(jz, "dark\(index)")
            asm.emit(0xB1, 0xFF) // MOV B, 0xFF
            asm.branch(jmp, "fill\(index)")
            asm.label("dark\(index)")
            asm.emit(0xB1, 0x00)
            asm.label("fill\(index)")
            asm.emit16(0xC5, start)
            for _ in 0..<10 { asm.emit(0x69, 0x91) } // MOV [HL], B; INC HL
        }
        asm.branch(jmpWide, "main", wide: true)

        // I2C, bit by bit through the pins the core's EEPROM watches. Data changes only while the clock is
        // low, except for start (data falls) and stop (data rises) with the clock high.
        asm.label("i2cStart")
        pins(&asm, 0x0C, 0x08, 0x00)
        asm.emit(0xF8)
        asm.label("i2cStop")
        pins(&asm, 0x00, 0x08, 0x0C)
        asm.emit(0xF8)
        // Sends A, most significant bit first, then clocks the acknowledge.
        asm.label("i2cSend")
        asm.emit(0xB1, 0x08) // MOV B, 8
        asm.label("sendBit")
        asm.emit(0x96, 0x80) // TST A, 0x80
        asm.branch(jz, "sendZero")
        pins(&asm, 0x04, 0x0C, 0x04)
        asm.branch(jmp, "sendNext")
        asm.label("sendZero")
        pins(&asm, 0x00, 0x08, 0x00)
        asm.label("sendNext")
        asm.emit(0x00) // ADD A, A
        asm.branch(0xF5, "sendBit") // JDBNZ
        pins(&asm, 0x00, 0x08, 0x00)
        asm.emit(0xF8)
        // Reads a byte into [HL], then clocks the acknowledge.
        asm.label("i2cRead")
        io(&asm, 0x60, 0x08) // Data as input.
        asm.emit(0xB5, 0x00, 0xB1, 0x08) // MOV [HL], 0; MOV B, 8
        asm.label("readBit")
        asm.emit(0x45, 0x00, 0x68) // MOV A, [HL]; ADD A, A; MOV [HL], A
        asm.emit(0x44, 0x61, 0x22, 0x04) // MOV A, [N+0x61]; AND A, 4
        asm.branch(jz, "readZero")
        asm.emit(0x86) // INC [HL]
        asm.label("readZero")
        pins(&asm, 0x08, 0x00)
        asm.branch(0xF5, "readBit")
        io(&asm, 0x60, 0x0C)
        pins(&asm, 0x00, 0x08, 0x00)
        asm.emit(0xF8)

        let code = asm.resolved()
        var rom = [UInt8](repeating: 0xFF, count: size)
        rom.replaceSubrange(0x2100..<0x2102, with: Array("MN".utf8))
        rom.replaceSubrange(0x2102..<(0x2102 + code.count), with: code)
        // Header: a game code and title no hack matches, in place of the licence string.
        rom.replaceSubrange(0x21A4..<0x21BC, with: [UInt8](repeating: 0, count: 8) + Array("GAGAGAGA TEST   ".utf8))
        precondition(0x2102 + code.count <= size)
        return Data(rom)
    }

    /// The boot counter in an `.eep` file the core wrote.
    static func bootCount(inEEPROMFile bytes: [UInt8]) -> Int? {
        let start = eepromMagicAddress
        guard bytes.count == 8192, Array(bytes[start..<(start + 4)]) == eepromMagic else { return nil }
        return Int(bytes[start + 4])
    }
}
#endif
