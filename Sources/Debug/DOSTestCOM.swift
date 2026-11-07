#if DEBUG
import Foundation

/// Generates a small DOS program, so tests need no commercial software. Hand-assembled 8086 in a `.com`
/// file, which DOSBox Pure mounts as C: and runs at once. `scripts/make-test-rom.sh` writes it to a file.
///
/// What the program does, in mode 13h (320 by 200, 256 colours):
/// - Programs DAC entries 0 to 7 so colour `c` is red, green and blue at full or none, by bits 2, 1 and 0.
/// - Lines 0 to 99: ten bars, 32 pixels wide, in colour `(bar + presses) & 7`. Each key read through
///   INT 16h adds one press and draws again.
/// - Lines 100 to 149: white while INT 33h reports the left mouse button down, else blue.
/// - Lines 150 to 199: green from x 0 to 32 times the boot count (at most 10 bars), black after.
/// - The boot count is one byte in C:\GAGA.DAT, read, counted and written back once per boot, so it proves
///   DOSBox Pure's save file keeps what the program writes.
/// - The PC speaker plays a square wave at `toneHertz` through PIT channel 2 for as long as it runs.
/// - Waits for interrupts with HLT, and never exits.
enum DOSTestCOM {
    static let width = 320
    static let height = 200
    static let barWidth = 32
    static let mouseRow = 100
    static let counterRow = 150
    static let fileName = "GAGA.DAT"
    static let divisor = 1193
    static let toneHertz = 1_193_182.0 / Double(divisor)

    /// The colour index (0 to 7) at a pixel.
    static func expectedColor(x: Int, y: Int, presses: Int = 0, button: Bool = false, boots: Int = 1) -> Int {
        if y < mouseRow { return (x / barWidth + presses) & 7 }
        if y < counterRow { return button ? 7 : 1 }
        return x < min(boots, 10) * barWidth ? 2 : 0
    }

    /// 8-bit RGB of a colour index.
    static func rgb(_ color: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        (color & 4 != 0 ? 255 : 0, color & 2 != 0 ? 255 : 0, color & 1 != 0 ? 255 : 0)
    }

    static func build() -> Data {
        var a = Assembler()
        a.bytes(0xB8, 0x13, 0x00, 0xCD, 0x10) // mov ax, 0013h; int 10h: mode 13h.

        // DAC from entry 0: three 6-bit components per colour.
        a.bytes(0xBA, 0xC8, 0x03, 0x30, 0xC0, 0xEE, 0x42) // mov dx, 3C8h; xor al, al; out dx, al; inc dx
        a.movImmediate(0xBE, "palette") // mov si, palette
        a.bytes(0xB9, 24, 0x00, 0xFC) // mov cx, 24; cld
        a.label("pal")
        a.bytes(0xAC, 0xEE) // lodsb; out dx, al
        a.short(0xE2, "pal") // loop

        // Boot counter: open C:\GAGA.DAT, or create it, then count this boot and write the byte back.
        a.movImmediate(0xBA, "file") // mov dx, file
        a.bytes(0xB8, 0x02, 0x3D, 0xCD, 0x21) // mov ax, 3D02h; int 21h: open, read and write.
        a.short(0x72, "create") // jc
        a.bytes(0x89, 0xC3, 0xB4, 0x3F, 0xB9, 0x01, 0x00) // mov bx, ax; mov ah, 3Fh; mov cx, 1
        a.movImmediate(0xBA, "count") // mov dx, count
        a.bytes(0xCD, 0x21) // int 21h: read one byte.
        a.bytes(0xB8, 0x00, 0x42, 0x31, 0xC9, 0x31, 0xD2, 0xCD, 0x21) // mov ax, 4200h; xor cx, cx; xor dx, dx; int 21h: seek to 0.
        a.short(0xEB, "counted") // jmp
        a.label("create")
        a.bytes(0xB4, 0x3C, 0x31, 0xC9) // mov ah, 3Ch; xor cx, cx
        a.movImmediate(0xBA, "file") // mov dx, file
        a.bytes(0xCD, 0x21) // int 21h: create.
        a.short(0x72, "nofile") // jc
        a.bytes(0x89, 0xC3) // mov bx, ax
        a.label("counted")
        a.memory(0xFE, 0x06, "count") // inc byte [count]
        a.bytes(0xB4, 0x40, 0xB9, 0x01, 0x00) // mov ah, 40h; mov cx, 1
        a.movImmediate(0xBA, "count") // mov dx, count
        a.bytes(0xCD, 0x21, 0xB4, 0x3E, 0xCD, 0x21) // int 21h: write; mov ah, 3Eh; int 21h: close.
        a.short(0xEB, "tone") // jmp
        a.label("nofile")
        a.memory(0xFE, 0x06, "count") // inc byte [count]

        // PIT channel 2, square wave, into the speaker.
        a.label("tone")
        a.bytes(0xB0, 0xB6, 0xE6, 0x43) // mov al, 0B6h; out 43h, al
        a.bytes(0xB8, UInt8(divisor & 0xFF), UInt8(divisor >> 8), 0xE6, 0x42, 0x88, 0xE0, 0xE6, 0x42) // mov ax, divisor; out 42h, al; mov al, ah; out 42h, al
        a.bytes(0xE4, 0x61, 0x0C, 0x03, 0xE6, 0x61) // in al, 61h; or al, 3; out 61h, al
        a.bytes(0x31, 0xC0, 0xCD, 0x33) // xor ax, ax; int 33h: reset the mouse.

        a.label("redraw")
        a.near(0xE8, "draw") // call
        a.label("idle")
        a.bytes(0xF4, 0xB4, 0x01, 0xCD, 0x16) // hlt; mov ah, 1; int 16h: a key waiting?
        a.short(0x74, "nokey") // jz
        a.bytes(0x30, 0xE4, 0xCD, 0x16) // xor ah, ah; int 16h: take it.
        a.memory(0xFE, 0x06, "presses") // inc byte [presses]
        a.short(0xEB, "redraw") // jmp
        a.label("nokey")
        a.bytes(0xB8, 0x03, 0x00, 0xCD, 0x33, 0x80, 0xE3, 0x01) // mov ax, 3; int 33h; and bl, 1
        a.memory(0x3A, 0x1E, "button") // cmp bl, [button]
        a.short(0x74, "idle") // je
        a.memory(0x88, 0x1E, "button") // mov [button], bl
        a.short(0xEB, "redraw") // jmp

        // draw: the whole screen from presses, button and count.
        a.label("draw")
        a.bytes(0x06, 0xB8, 0x00, 0xA0, 0x8E, 0xC0, 0x31, 0xFF, 0xFC) // push es; mov ax, 0A000h; mov es, ax; xor di, di; cld
        a.bytes(0xBA, UInt8(mouseRow), 0x00) // mov dx, 100
        a.label("bars")
        a.memory(0x8A, 0x1E, "presses") // mov bl, [presses]
        a.bytes(0xB7, UInt8(width / barWidth)) // mov bh, 10
        a.label("bar")
        a.bytes(0x88, 0xD8, 0x24, 0x07, 0xB9, UInt8(barWidth), 0x00, 0xF3, 0xAA) // mov al, bl; and al, 7; mov cx, 32; rep stosb
        a.bytes(0xFE, 0xC3, 0xFE, 0xCF) // inc bl; dec bh
        a.short(0x75, "bar") // jnz
        a.bytes(0x4A) // dec dx
        a.short(0x75, "bars") // jnz
        a.bytes(0xB0, 0x01) // mov al, 1
        a.memory(0x80, 0x3E, "button", 0x00) // cmp byte [button], 0
        a.short(0x74, "blue") // je
        a.bytes(0xB0, 0x07) // mov al, 7
        a.label("blue")
        let mouseBytes = (counterRow - mouseRow) * width
        a.bytes(0xB9, UInt8(mouseBytes & 0xFF), UInt8(mouseBytes >> 8), 0xF3, 0xAA) // mov cx, 50 * 320; rep stosb
        a.bytes(0xA0); a.address("count") // mov al, [count]
        a.bytes(0x3C, 0x0A) // cmp al, 10
        a.short(0x76, "capped") // jbe
        a.bytes(0xB0, 0x0A) // mov al, 10
        a.label("capped")
        a.bytes(0x30, 0xE4, 0xB1, 0x05, 0xD3, 0xE0, 0x89, 0xC5) // xor ah, ah; mov cl, 5; shl ax, cl; mov bp, ax
        a.bytes(0xBA, UInt8(height - counterRow), 0x00) // mov dx, 50
        a.label("counter")
        a.bytes(0x89, 0xE9, 0xB0, 0x02, 0xF3, 0xAA) // mov cx, bp; mov al, 2; rep stosb
        a.bytes(0xB9, UInt8(width & 0xFF), UInt8(width >> 8), 0x29, 0xE9, 0x30, 0xC0, 0xF3, 0xAA) // mov cx, 320; sub cx, bp; xor al, al; rep stosb
        a.bytes(0x4A) // dec dx
        a.short(0x75, "counter") // jnz
        a.bytes(0x07, 0xC3) // pop es; ret

        a.label("palette")
        for color in 0..<8 {
            a.bytes(color & 4 != 0 ? 63 : 0, color & 2 != 0 ? 63 : 0, color & 1 != 0 ? 63 : 0)
        }
        a.label("file")
        a.bytes(Array("C:\\\(fileName)".utf8) + [0])
        a.label("count")
        a.bytes(0)
        a.label("presses")
        a.bytes(0)
        a.label("button")
        a.bytes(0)
        return Data(a.finish())
    }

    /// Just enough of an 8086 assembler: raw bytes, plus labels for short and near jumps and for absolute
    /// addresses. A .com file loads at offset 100h.
    private struct Assembler {
        private var code: [UInt8] = []
        private var labels: [String: Int] = [:]
        private var fixups: [(at: Int, label: String, kind: Kind)] = []
        private enum Kind { case short, near, absolute }

        mutating func bytes(_ values: UInt8...) { code += values }
        mutating func bytes(_ values: [UInt8]) { code += values }

        mutating func label(_ name: String) {
            precondition(labels[name] == nil, "label \(name) twice")
            labels[name] = code.count
        }

        /// A jump with an 8-bit displacement.
        mutating func short(_ opcode: UInt8, _ label: String) {
            code.append(opcode)
            fixups.append((code.count, label, .short))
            code.append(0)
        }

        /// A jump or call with a 16-bit displacement.
        mutating func near(_ opcode: UInt8, _ label: String) {
            code.append(opcode)
            fixups.append((code.count, label, .near))
            code += [0, 0]
        }

        mutating func address(_ label: String) {
            fixups.append((code.count, label, .absolute))
            code += [0, 0]
        }

        /// `mov reg16, offset label`.
        mutating func movImmediate(_ opcode: UInt8, _ label: String) {
            code.append(opcode)
            address(label)
        }

        /// An instruction on the byte at a label: opcode, ModRM with a 16-bit displacement, then any immediate.
        mutating func memory(_ opcode: UInt8, _ modrm: UInt8, _ label: String, _ immediate: UInt8...) {
            code += [opcode, modrm]
            address(label)
            code += immediate
        }

        func finish() -> [UInt8] {
            var out = code
            for fixup in fixups {
                guard let target = labels[fixup.label] else { preconditionFailure("no label \(fixup.label)") }
                switch fixup.kind {
                case .short:
                    let delta = target - (fixup.at + 1)
                    precondition((-128...127).contains(delta), "jump to \(fixup.label) out of range")
                    out[fixup.at] = UInt8(bitPattern: Int8(delta))
                case .near, .absolute:
                    let value = fixup.kind == .near ? UInt16(truncatingIfNeeded: target - (fixup.at + 2)) : UInt16(0x100 + target)
                    out[fixup.at] = UInt8(value & 0xFF)
                    out[fixup.at + 1] = UInt8(value >> 8)
                }
            }
            return out
        }
    }
}
#endif
