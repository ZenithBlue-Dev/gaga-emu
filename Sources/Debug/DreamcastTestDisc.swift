#if DEBUG
import Foundation

/// A self-made Dreamcast GD-ROM image (.gdi and three tracks) for the Flycast tests. Flycast's HLE BIOS (reios)
/// reads IP.BIN from track 3, finds `1ST_READ.BIN` through ISO 9660, and starts at IP.BIN + 0x300, as a real
/// boot does. The SH-4 program there sets a 640x480 RGB565 framebuffer at the start of VRAM and keeps filling
/// it with `color565`, so every frame is a direct framebuffer write, which Flycast draws without the TA.
enum DreamcastTestDisc {
    static let color565: UInt16 = 0xE408 // R 28/31, G 32/63, B 8/31.
    static let colorBGRA: [UInt8] = [66, 130, 230, 0xFF]

    static let gdi = "3\n1 0 4 2048 track01.iso 0\n2 450 0 2352 track02.raw 0\n3 45000 4 2048 track03.iso 0\n"

    /// Every file of the image, the .gdi last.
    static func files(name: String = "GagaDreamcast") -> [(name: String, data: Data)] {
        [("track01.iso", Data(count: 16 * 2048)),
         ("track02.raw", Data(count: 75 * 2352)), // One second of silence.
         ("track03.iso", track3()),
         ("\(name).gdi", Data(gdi.utf8))]
    }

    private static let trackStart = 45000 // LBA; ISO 9660 extents are absolute.

    private static func track3() -> Data {
        var sectors = [UInt8](repeating: 0, count: 20 * 2048)
        let ip = ipBin()
        sectors.replaceSubrange(0..<ip.count, with: ip)
        // 16: primary volume descriptor, whose root directory is sector 18.
        var pvd = [UInt8](repeating: 0x20, count: 2048)
        pvd[0] = 1
        pvd.replaceSubrange(1..<6, with: Array("CD001".utf8))
        pvd[6] = 1
        pvd[7] = 0
        pvd.replaceSubrange(156..<190, with: record(name: [0], extent: trackStart + 18, size: 2048, directory: true))
        sectors.replaceSubrange(16 * 2048..<17 * 2048, with: pvd)
        // 17: set terminator.
        sectors.replaceSubrange(17 * 2048..<17 * 2048 + 7, with: [255] + Array("CD001".utf8) + [1])
        // 18: the root: ".", "..", then 1ST_READ.BIN in sector 19, which reios loads but this program never runs.
        let root = record(name: [0], extent: trackStart + 18, size: 2048, directory: true)
            + record(name: [1], extent: trackStart + 18, size: 2048, directory: true)
            + record(name: Array("1ST_READ.BIN;1".utf8), extent: trackStart + 19, size: 2048, directory: false)
        sectors.replaceSubrange(18 * 2048..<18 * 2048 + root.count, with: root)
        return Data(sectors)
    }

    /// An ISO 9660 directory record. Both-endian fields are little-endian then big-endian.
    private static func record(name: [UInt8], extent: Int, size: Int, directory: Bool) -> [UInt8] {
        func both32(_ v: Int) -> [UInt8] {
            let le = withUnsafeBytes(of: UInt32(v).littleEndian, Array.init)
            return le + le.reversed()
        }
        var r: [UInt8] = [0, 0] + both32(extent) + both32(size) + [UInt8](repeating: 0, count: 7)
        r += [directory ? 2 : 0, 0, 0, 1, 0, 0, 1, UInt8(name.count)] + name
        if r.count % 2 == 1 { r.append(0) }
        r[0] = UInt8(r.count)
        return r
    }

    /// 16 sectors: the header reios and Flycast read (ip_meta_t), then the program at 0x300.
    private static func ipBin() -> [UInt8] {
        var ip = [UInt8](repeating: 0x20, count: 16 * 2048)
        func put(_ text: String, at offset: Int) { ip.replaceSubrange(offset..<offset + text.utf8.count, with: Array(text.utf8)) }
        put("SEGA SEGAKATANA ", at: 0x00)
        put("SEGA ENTERPRISES", at: 0x10)
        put("0000 GD-ROM1/1  ", at: 0x20) // checksum, disk type, disk number
        put("JUE     ", at: 0x30)
        put("0000", at: 0x38) // peripherals
        put("010", at: 0x3C) // dev, VGA supported, not Windows CE
        put("GAGA00001 ", at: 0x40)
        put("V1.000", at: 0x4A)
        put("20261108", at: 0x50)
        put("1ST_READ.BIN    ", at: 0x60)
        put("GAGAEMU         ", at: 0x70)
        put("GAGAEMU DREAMCAST TEST", at: 0x80)
        let code = program()
        ip.replaceSubrange(0x300..<0x300 + code.count, with: code)
        return ip
    }

    /// SH-4, run at 0xAC008300. Literals follow the code, each loaded with mov.l @(disp,PC).
    private static func program() -> [UInt8] {
        let literals: [UInt32] = [
            0xA05F_8050, // FB_R_SOF1
            0xA05F_805C, // FB_R_SIZE
            UInt32(640 * 2 / 4 - 1) | 479 << 10 | 1 << 20, // 320 words a line, 480 lines, modulus 1
            0xA05F_8044, // FB_R_CTRL
            0x0080_0005, // enabled, RGB565, VGA pixel clock
            UInt32(color565) << 16 | UInt32(color565),
            0xA500_0000, // VRAM, 32-bit path
            640 * 480 / 2, // words
        ]
        var code: [UInt16] = []
        var loads: [(at: Int, literal: Int)] = []
        func load(_ literal: Int, _ rn: UInt16) {
            loads.append((code.count, literal))
            code.append(0xD000 | rn << 8)
        }
        load(0, 1)
        code.append(0xE000) // mov #0,r0
        code.append(0x2102) // mov.l r0,@r1: FB_R_SOF1 first, so FB_R_SIZE's write watches the right range.
        load(1, 1); load(2, 0); code.append(0x2102)
        load(3, 1); load(4, 0); code.append(0x2102)
        load(5, 2)
        let fill = code.count
        load(6, 1)
        load(7, 3)
        let loop = code.count
        code.append(0x2122) // mov.l r2,@r1
        code.append(0x7104) // add #4,r1
        code.append(0x4310) // dt r3
        code.append(0x8B00 | UInt16(UInt8(bitPattern: Int8(loop - (code.count + 2))))) // bf loop
        code.append(0xA000 | UInt16(bitPattern: Int16(fill - (code.count + 2))) & 0x0FFF) // bra fill
        code.append(0x0009) // nop, the delay slot
        if code.count % 2 == 1 { code.append(0x0009) }
        let pool = code.count * 2 // byte offset, 4-aligned
        for (at, literal) in loads {
            let disp = (pool + literal * 4 - ((at * 2) & ~3) - 4) / 4
            precondition((0...255).contains(disp))
            code[at] |= UInt16(disp)
        }
        var bytes = code.flatMap { withUnsafeBytes(of: $0.littleEndian, Array.init) }
        for literal in literals { bytes += withUnsafeBytes(of: literal.littleEndian, Array.init) }
        return bytes
    }
}
#endif
