#if DEBUG
import Foundation

/// A self-made 3DS homebrew program (.3dsx) for the Azahar tests: no SDK, no services. Azahar maps all of VRAM
/// at 0x1F000000 into a 3DSX process and starts the screens on nn::gx's default framebuffers (RGB8, stored as
/// B, G, R), so the program fills the top one with `topBGRA` and the bottom one with `bottomBGRA`, then sleeps
/// in a loop (svcSleepThread).
enum N3DSTestProgram {
    static let topBGRA: [UInt8] = [0x20, 0x40, 0xE0, 0xFF]
    static let bottomBGRA: [UInt8] = [0xE0, 0x80, 0x20, 0xFF]

    private static let origin = 0x0010_0000 // Memory::PROCESS_IMAGE_VADDR, the code segment and entry point.
    private static let topFramebuffer: UInt32 = 0x1F1E_6000 // 0x181E6000 in VRAM, pica_core.cpp's default.
    private static let bottomFramebuffer: UInt32 = 0x1F48_F000 // 0x1848F000.

    static func build() -> Data {
        var asm = ARMAssembler(origin: origin)
        fill(&asm, at: topFramebuffer, bytes: 240 * 400 * 3, color: topBGRA)
        fill(&asm, at: bottomFramebuffer, bytes: 240 * 320 * 3, color: bottomBGRA)
        let loop = asm.here
        asm.load32(0, 16_000_000) // r1:r0 nanoseconds.
        asm.mov(1, 0)
        asm.swi(0x0A) // svcSleepThread
        asm.branch(to: loop)
        return threeDSX(code: asm.bytes)
    }

    /// Four RGB8 pixels are three words, stored until `bytes` are written.
    private static func fill(_ asm: inout ARMAssembler, at address: UInt32, bytes: Int, color: [UInt8]) {
        let pattern = (0..<4).flatMap { _ in color.prefix(3) }
        let words = stride(from: 0, to: 12, by: 4).map { i in
            (0..<4).reduce(UInt32(0)) { $0 | UInt32(pattern[i + $1]) << UInt32($1 * 8) }
        }
        asm.load32(0, address)
        asm.load32(1, UInt32(bytes / 12))
        for (register, word) in zip(2..., words) { asm.load32(register, word) }
        let top = asm.here
        for register in 2...4 { asm.str(register, 0, (register - 2) * 4) }
        asm.add(0, 0, 12)
        asm.subs(1, 1, 1)
        asm.branch(to: top, cond: .ne)
    }

    /// The 44-byte header (with the SMDH and RomFS fields, both empty), three empty relocation headers, then
    /// the segments. Rodata and data get one zero word each, so no segment is empty.
    private static func threeDSX(code: [UInt8]) -> Data {
        var data = Data("3DSX".utf8)
        func u16(_ v: Int) { data += withUnsafeBytes(of: UInt16(v).littleEndian, Array.init) }
        func u32(_ v: Int) { data += withUnsafeBytes(of: UInt32(v).littleEndian, Array.init) }
        u16(44) // header_size
        u16(8) // reloc_hdr_size: absolute and relative counts
        u32(0) // format_ver
        u32(0) // flags
        u32(code.count)
        u32(4) // rodata
        u32(4) // data, bss included
        u32(0) // bss
        u32(0); u32(0); u32(0) // smdh_offset, smdh_size, fs_offset
        for _ in 0..<3 { u32(0); u32(0) }
        data += code
        u32(0) // rodata
        u32(0) // data
        return data
    }
}
#endif
