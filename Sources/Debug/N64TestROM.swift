#if DEBUG
import Foundation

/// Generates a small homebrew Nintendo 64 cartridge, so tests need no commercial game, no PIF ROM and no
/// Nintendo boot code. The core's HLE PIF boot (bootrom_hle.c) copies ROM 0x40...0xFFF to RSP DMEM and jumps
/// there, as the real PIF does with a cartridge's IPL3. Here that space holds this program instead of IPL3,
/// so it runs from DMEM and never touches the RSP or the RDP: the CPU draws into RDRAM and the VI shows it.
/// The core reads an unknown boot block as CIC 6102, which only changes the seed in s6, unused here.
/// `scripts/make-test-rom.sh` writes it to a `.z64` file.
///
/// What the program does:
/// - Four horizontal bands, 60 lines each, on a 320x240 RGBA5551 framebuffer: red, green, blue, white.
/// - Key cells, 16 wide and 32 tall from x 32 on line `keyRow`: white while that controller bit is held, in
///   the N64's own order (bit 0 C-Right ... bit 15 A, cell 0 first). Read each frame over SI from the PIF.
/// - Counter cells on line `counterRow`: the SRAM boot counter, one bit per cell.
/// - Toggle cell at x `toggleColumn` on line `flagRow`: pressing A and B together flips it. The flag lives
///   only in a CPU register, so it proves a save state restored the CPU.
/// - Cheat cell at x `cheatColumn` on line `flagRow`: white for a frame after anything writes a non-zero
///   byte to `cheatAddress`, which the program clears each frame, so a GameShark code shows while it is on.
/// - A square wave at `toneHertz` through AI DMA, one 4 KiB buffer queued whenever the AI FIFO has room.
/// - Battery SRAM (the Advanced Homebrew ROM Header says 32 KiB SRAM): "GAGA" and a boot counter at offset 0,
///   read and written once per boot by PI DMA.
/// - Waits for the VI interrupt by polling MI_INTR with interrupts off, so no handler runs.
enum N64TestROM {
    static let width = 320
    static let height = 240
    static let bandHeight = 60
    static let cellWidth = 16
    static let cellHeight = 32
    static let keyRow = 14
    static let counterRow = 74
    static let flagRow = 134
    static let cellColumn = 32
    static let toggleColumn = 32
    static let cheatColumn = 64
    static let cheatAddress: UInt32 = 0x800F_0000
    static let sramMagic = "GAGA"
    /// AI rate: the NTSC VI clock over (dacrate + 1), and 50 samples a period.
    static let dacRate: UInt32 = 2207
    static let toneHertz = 48_681_812.0 / Double(dacRate + 1) / 50
    static let toneAmplitude: Int16 = 0x2000
    // N64 controller bits. The core maps RetroPad B to A and Y to B (emulate_game_controller_via_libretro.c).
    static let buttonA: UInt32 = 0x8000
    static let buttonB: UInt32 = 0x4000
    static let buttonStart: UInt32 = 0x1000
    static let dpadRight: UInt32 = 0x0100
    static let chord = buttonA | buttonB
    /// RGBA5551: red, green, blue, white. The cells are white or their band's colour.
    static let bandColors: [UInt32] = [0xF801, 0x07C1, 0x003F, 0xFFFF]
    static let white = 3

    /// The band index (0 red, 1 green, 2 blue, 3 white) at a pixel. `keys` is in N64 bit order.
    static func expectedColor(x: Int, y: Int, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, counter: Int = 1) -> Int {
        let band = y / bandHeight
        func cell(_ row: Int) -> Bool { (row..<(row + cellHeight)).contains(y) }
        let column = (x - cellColumn) / cellWidth
        let inBits = x >= cellColumn && column < 16
        if cell(keyRow) && inBits && keys & (1 << UInt32(column)) != 0 { return white }
        if cell(counterRow) && inBits && counter & (1 << column) != 0 { return white }
        if cell(flagRow) {
            if (toggleColumn..<(toggleColumn + cellWidth)).contains(x) && toggle { return white }
            if (cheatColumn..<(cheatColumn + cellWidth)).contains(x) && cheat { return white }
        }
        return band
    }

    static func build() -> Data {
        let code = program()
        precondition(code.count * 4 <= bootSize, "the program must fit in DMEM")
        var rom = header()
        rom += code.flatMap(bigEndian)
        rom += [UInt8](repeating: 0, count: 0x1000 - rom.count)
        rom += data()
        rom += [UInt8](repeating: 0, count: romSize - rom.count)
        return Data(rom)
    }

    // MARK: - Layout

    private static let romSize = 1 << 20
    private static let bootSize = 0x1000 - 0x40
    private static let entry: UInt32 = 0xA400_0040 // DMEM, where the HLE boot jumps.
    private static let framebuffer: UInt32 = 0x0010_0000
    private static let dataAddress: UInt32 = 0x0020_0000 // ROM 0x1000 lands here: the audio buffer first.
    private static let audioBytes = 4096
    private static let requestAddress = dataAddress + UInt32(audioBytes) // The SI request block, from ROM.
    private static let responseAddress = dataAddress + 0x2000
    private static let sramBuffer: UInt32 = 0x0030_0000
    private static func uncached(_ physical: UInt32) -> UInt32 { physical | 0xA000_0000 }
    private static func pixelAddress(x: Int, y: Int) -> UInt32 { uncached(framebuffer) + UInt32((y * width + x) * 2) }

    /// Byte 0 is padding, then channel 0: send 1, receive 4, command 01 (read buttons), four reply bytes,
    /// then the end marker. Byte 63 set asks the PIF to run the block. The buttons land at offset 4.
    private static let siRequest: [UInt8] = {
        var block = [UInt8](repeating: 0, count: 64)
        block.replaceSubrange(0..<9, with: [0xFF, 0x01, 0x04, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE])
        block[63] = 0x01
        return block
    }()

    private static func data() -> [UInt8] {
        var bytes: [UInt8] = []
        for sample in 0..<(audioBytes / 4) {
            let value = UInt16(bitPattern: sample % 50 < 25 ? toneAmplitude : -toneAmplitude)
            bytes += [UInt8(value >> 8), UInt8(value & 0xFF), UInt8(value >> 8), UInt8(value & 0xFF)] // Left, right.
        }
        return bytes + siRequest
    }

    private static func bigEndian(_ word: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: word >> (24 - $0 * 8)) } }

    /// The 64-byte cartridge header. "ED" at 0x3C is the Advanced Homebrew ROM Header, whose save type nibble
    /// at 0x3F (3) asks for 32 KiB SRAM. Country "E" is NTSC. CRCs are zero: the core does not check them.
    private static func header() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 0x40)
        bytes.replaceSubrange(0..<4, with: [0x80, 0x37, 0x12, 0x40]) // PI timing, and the .z64 byte order mark.
        bytes.replaceSubrange(0x04..<0x08, with: bigEndian(0x0000_000F))
        bytes.replaceSubrange(0x08..<0x0C, with: bigEndian(0x8000_0400))
        let name = Array("GAGAEMU N64 TEST".utf8) + [UInt8](repeating: 0x20, count: 4)
        bytes.replaceSubrange(0x20..<0x34, with: name)
        bytes.replaceSubrange(0x3B..<0x40, with: [0x4E, 0x45, 0x44, 0x45, 0x30]) // N, ED, E, save type 3.
        return bytes
    }

    // MARK: - Program

    private typealias Reg = PS1TestEXE.Reg

    private static func program() -> [UInt32] {
        var a = PS1TestEXE.Assembler(origin: entry)

        // PI: the audio buffer and the SI request block from ROM 0x1000 to RDRAM.
        a.lui(.s1, 0xA460)
        a.li(.t0, dataAddress)
        a.sw(.t0, 0x00, .s1) // PI_DRAM_ADDR
        a.li(.t0, 0x1000_1000)
        a.sw(.t0, 0x04, .s1) // PI_CART_ADDR
        a.li(.t0, UInt32(audioBytes + siRequest.count - 1))
        a.sw(.t0, 0x0C, .s1) // PI_WR_LEN: cartridge to RDRAM.
        a.jal("pi-wait")

        // SRAM: read 16 bytes, count this boot, write them back.
        a.li(.t0, sramBuffer)
        a.sw(.t0, 0x00, .s1)
        a.li(.t0, 0x0800_0000)
        a.sw(.t0, 0x04, .s1)
        a.li(.t0, 15)
        a.sw(.t0, 0x0C, .s1)
        a.jal("pi-wait")
        a.li(.s4, uncached(sramBuffer))
        a.lw(.t0, 0, .s4)
        let magic = sramMagic.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        a.li(.t1, magic)
        a.li(.s3, 0) // s3: the boot counter.
        a.bne(.t0, .t1, "fresh")
        a.lbu(.s3, 4, .s4)
        a.label("fresh")
        a.addiu(.s3, .s3, 1)
        a.andi(.s3, .s3, 0xFF)
        a.sw(.t1, 0, .s4)
        a.sb(.s3, 4, .s4)
        a.li(.t0, sramBuffer)
        a.sw(.t0, 0x00, .s1)
        a.li(.t0, 0x0800_0000)
        a.sw(.t0, 0x04, .s1)
        a.li(.t0, 15)
        a.sw(.t0, 0x08, .s1) // PI_RD_LEN: RDRAM to cartridge.
        a.jal("pi-wait")

        // The bands, then the counter cells once.
        for (band, color) in bandColors.enumerated() {
            a.li(.a0, color)
            a.li(.a1, pixelAddress(x: 0, y: band * bandHeight))
            a.li(.a2, UInt32(width))
            a.li(.a3, UInt32(bandHeight))
            a.jal("rect")
        }
        a.or(.t4, .s3, .zero)
        a.li(.t3, pixelAddress(x: cellColumn, y: counterRow))
        a.li(.v1, bandColors[1])
        a.jal("row")

        // VI: NTSC, 320x240, 16-bit, resampled, no anti-aliasing. These are libdragon's NTSC timings. V_INTR
        // goes last: the core schedules the VI interrupt only while it is below V_SYNC.
        a.lui(.s1, 0xA440)
        let vi: [(UInt16, UInt32)] = [(0x00, 0x0000_3202), (0x04, framebuffer), (0x08, UInt32(width)),
                                      (0x14, 0x03E5_2239), (0x18, 0x0000_020D), (0x1C, 0x0000_0C15),
                                      (0x20, 0x0C15_0C15), (0x24, 0x006C_02EC), (0x28, 0x0025_01FF),
                                      (0x2C, 0x000E_0204), (0x30, 0x0000_0200), (0x34, 0x0000_0400),
                                      (0x0C, 0x0000_0002)]
        for (offset, value) in vi {
            a.li(.t0, value)
            a.sw(.t0, offset, .s1)
        }

        // AI: the rate, 16-bit, DMA on.
        a.lui(.s1, 0xA450)
        a.li(.t0, dacRate)
        a.sw(.t0, 0x10, .s1) // AI_DACRATE
        a.li(.t0, 15)
        a.sw(.t0, 0x14, .s1) // AI_BITRATE
        a.li(.t0, 1)
        a.sw(.t0, 0x08, .s1) // AI_CONTROL
        a.li(.s0, 0) // s0 bit 0: the toggle. Bit 1: the chord was held last frame.

        a.label("frame")
        a.lui(.t4, 0xA430)
        a.lw(.t0, 0x08, .t4) // MI_INTR: wait for VI, then acknowledge it by writing VI_CURRENT.
        a.andi(.t0, .t0, 0x08)
        a.beq(.t0, .zero, "frame")
        a.lui(.t4, 0xA440)
        a.sw(.zero, 0x10, .t4)

        // Queue the tone again while the AI FIFO is not full.
        a.lui(.t4, 0xA450)
        a.lw(.t0, 0x0C, .t4) // AI_STATUS bit 31: full.
        a.srl(.t0, .t0, 31)
        a.bne(.t0, .zero, "audio-done")
        a.li(.t0, dataAddress)
        a.sw(.t0, 0x00, .t4)
        a.li(.t0, UInt32(audioBytes))
        a.sw(.t0, 0x04, .t4)
        a.label("audio-done")

        // SI: send the request block to the PIF, read the reply back, buttons into s2.
        a.lui(.t4, 0xA480)
        a.li(.t0, requestAddress)
        a.sw(.t0, 0x00, .t4) // SI_DRAM_ADDR
        a.li(.t0, 0x1FC0_07C0)
        a.sw(.t0, 0x10, .t4) // SI_PIF_ADDR_WR64B
        a.jal("si-wait")
        a.li(.t0, responseAddress)
        a.sw(.t0, 0x00, .t4)
        a.li(.t0, 0x1FC0_07C0)
        a.sw(.t0, 0x04, .t4) // SI_PIF_ADDR_RD64B
        a.jal("si-wait")
        a.li(.t4, uncached(responseAddress))
        a.lhu(.s2, 4, .t4)

        a.or(.t4, .s2, .zero)
        a.li(.t3, pixelAddress(x: cellColumn, y: keyRow))
        a.li(.v1, bandColors[0])
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
        a.li(.a1, pixelAddress(x: toggleColumn, y: flagRow))
        a.li(.v1, bandColors[2])
        a.jal("cell")

        a.li(.t4, uncached(cheatAddress & 0x1FFF_FFFF))
        a.lbu(.t2, 0, .t4)
        a.sb(.zero, 0, .t4)
        a.sltu(.t2, .zero, .t2)
        a.li(.a1, pixelAddress(x: cheatColumn, y: flagRow))
        a.li(.v1, bandColors[2])
        a.jal("cell")
        a.j("frame")

        // rect: a0 colour, a1 top left address, a2 width, a3 height. Uses t0 and t1; changes a1 and a3.
        a.label("rect")
        a.label("rect-line")
        a.or(.t0, .a1, .zero)
        a.or(.t1, .a2, .zero)
        a.label("rect-pixel")
        a.sh(.a0, 0, .t0)
        a.addiu(.t0, .t0, 2)
        a.addiu(.t1, .t1, -1)
        a.bne(.t1, .zero, "rect-pixel")
        a.addiu(.a1, .a1, Int16(width * 2))
        a.addiu(.a3, .a3, -1)
        a.bne(.a3, .zero, "rect-line")
        a.jr(.ra)

        // cell: one cell at a1, white when t2 is not zero, else v1. Ends in rect.
        a.label("cell")
        a.or(.a0, .v1, .zero)
        a.beq(.t2, .zero, "cell-draw")
        a.li(.a0, bandColors[white])
        a.label("cell-draw")
        a.li(.a2, UInt32(cellWidth))
        a.li(.a3, UInt32(cellHeight))
        a.j("rect")

        // row: 16 cells from address t3, one per bit of t4, off colour v1. Uses s4, s5 and s7.
        a.label("row")
        a.or(.s7, .ra, .zero)
        a.li(.s4, 0)
        a.or(.s5, .t3, .zero)
        a.label("row-next")
        a.srlv(.t2, .t4, .s4)
        a.andi(.t2, .t2, 1)
        a.or(.a1, .s5, .zero)
        a.jal("cell")
        a.addiu(.s4, .s4, 1)
        a.addiu(.s5, .s5, Int16(cellWidth * 2))
        a.sltiu(.t2, .s4, 16)
        a.bne(.t2, .zero, "row-next")
        a.jr(.s7)

        // pi-wait: until PI_STATUS shows no DMA and no I/O busy. s1 is the PI base.
        a.label("pi-wait")
        a.lw(.t0, 0x10, .s1)
        a.andi(.t0, .t0, 3)
        a.bne(.t0, .zero, "pi-wait")
        a.jr(.ra)

        // si-wait: until SI_STATUS shows no DMA and no I/O busy. Uses t0 and t1.
        a.label("si-wait")
        a.lui(.t1, 0xA480)
        a.label("si-wait-poll")
        a.lw(.t0, 0x18, .t1)
        a.andi(.t0, .t0, 3)
        a.bne(.t0, .zero, "si-wait-poll")
        a.jr(.ra)
        return a.finish()
    }
}
#endif
