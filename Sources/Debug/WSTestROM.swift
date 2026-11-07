#if DEBUG
import Foundation

/// Generates a small homebrew WonderSwan Color cartridge, so tests need no commercial game and no Bandai
/// material. Hand-assembled V30MZ (8086 encodings). It runs from reset with no boot ROM, in the mono video
/// mode. `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - Screen 1 shows four bands of tiles in palette 0, from the lightest shade to black.
/// - Eleven key cells on tile row 1, from column 2: black while that key is held. The keys are X1 to X4,
///   Y1 to Y4 (each pad up, right, down, left), Start, A and B.
/// - Waits for line 144 once per frame, so it stalls if the display never reaches blanking.
/// - Sound channel 1 plays a square wave at about 390 Hz from wave RAM at 0x0380.
/// - Cartridge SRAM (8 KB): "GAGA" at `sramMagicOffset` and a boot counter after it, incremented once per boot.
/// - Toggle cell, column 20: pressing A and B together flips it. The flag lives in RAM.
/// - Cheat cell, column 22: lit for a frame after anything writes a non-zero byte to RAM `cheatOffset`,
///   which the program clears each frame, so a raw RAM code shows while it is on and stops when it is off.
enum WSTestROM {
    static let sramMagic: [UInt8] = Array("GAGA".utf8)
    static let sramMagicOffset = 0x10
    static let sramCounterOffset = 0x14
    static let cheatOffset: UInt16 = 0x0010
    /// Upstream's raw code: a RAM address of up to five hex digits, a colon, two hex digits.
    static var cheatCode: String { String(format: "%05X:01", cheatOffset) }
    static let size = 0x10000

    private static let toggle: UInt16 = 0x0011, previous: UInt16 = 0x0012
    private static let map: UInt16 = 0x1000, tiles: UInt16 = 0x2000, wave: UInt16 = 0x0380

    private static func le16(_ value: UInt16) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8)] }
    private static func cellAddress(column: Int, row: Int) -> UInt16 { map + UInt16((row * 32 + column) * 2) }
    private static func out(_ port: UInt8, _ value: UInt8) -> [UInt8] { [0xB0, value, 0xE6, port] } // mov al,v; out p,al
    private static func storeWord(_ address: UInt16, _ value: UInt16) -> [UInt8] { [0xC7, 0x06] + le16(address) + le16(value) }
    private static func storeByte(_ address: UInt16, _ value: UInt8) -> [UInt8] { [0xC6, 0x06] + le16(address) + [value] }
    /// A cell's tile: `lit` when the zero flag is clear, else `dark`.
    private static func cell(_ address: UInt16, lit: UInt16, dark: UInt16) -> [UInt8] {
        [0x74, 0x08] + storeWord(address, lit) + [0xEB, 0x06] + storeWord(address, dark)
    }

    static func build() -> Data {
        var code: [UInt8] = [0xFA, 0xFC, 0x31, 0xC0, 0x8E, 0xD8, 0x8E, 0xD0] // cli; cld; xor ax,ax; mov ds,ax; mov ss,ax
        code += [0xBC] + le16(0x0E00) // mov sp, 0x0E00
        code += [0xB8] + le16(0x1000) + [0x8E, 0xC0] // mov es, 0x1000: SRAM

        // Sound: a square wave (eight samples high, eight low, two to a byte), channel 1 on at full volume.
        for index in 0..<16 { code += storeByte(wave + UInt16(index), index < 8 ? 0xFF : 0x00) }
        code += out(0x8F, UInt8(wave >> 6)) + out(0x80, UInt8(1800 & 0xFF)) + out(0x81, UInt8(1800 >> 8)) + out(0x88, 0xFF)
        code += out(0x90, 0x01) + out(0x91, 0x0F)

        // Shades 0, 5, 10 and 15 as palette 0's four colours. Screen 1's map at 0x1000, screen 1 on.
        code += out(0x1C, 0x50) + out(0x1D, 0xFA) + out(0x20, 0x10) + out(0x21, 0x32) + out(0x07, 0x22)
        // Tiles 1 to 3: every pixel colour 1, 2 or 3. A row is a low plane byte, then a high plane byte.
        for tile in 1...3 {
            let row = UInt16(tile & 1 != 0 ? 0xFF : 0) | UInt16(tile & 2 != 0 ? 0xFF : 0) << 8
            for line in 0..<8 { code += storeWord(tiles + UInt16(tile * 16 + line * 2), row) }
        }
        for row in 0..<18 {
            for column in 0..<28 { code += storeWord(cellAddress(column: column, row: row), UInt16(min(row * 4 / 18, 3))) }
        }
        code += out(0x01, 0x00) + out(0x00, 0x01) + out(0x14, 0x01)

        // Boot counter in SRAM, after "GAGA", which a new SRAM gets first.
        let fresh = sramMagic.enumerated().flatMap { [0x26, 0xC6, 0x06] + le16(UInt16(sramMagicOffset + $0)) + [$1] }
            + [0x26, 0xC6, 0x06] + le16(UInt16(sramCounterOffset)) + [0]
        let skipFresh: [UInt8] = [0xEB, UInt8(fresh.count)]
        for (index, byte) in sramMagic.enumerated() {
            let remaining = (sramMagic.count - 1 - index) * 8 + skipFresh.count
            code += [0x26, 0x80, 0x3E] + le16(UInt16(sramMagicOffset + index)) + [byte, 0x75, UInt8(remaining)]
        }
        code += skipFresh + fresh
        code += [0x26, 0xFE, 0x06] + le16(UInt16(sramCounterOffset)) // inc byte es:[counter]

        let main = code.count
        code += [0xE4, 0x02, 0x3C, 0x90, 0x75, 0xFA] // until line 144
        code += [0xE4, 0x02, 0x3C, 0x90, 0x74, 0xFA] // then past it
        // BL: X1-X4, BH: Y1-Y4, CL bits 1-3: Start, A, B.
        code += out(0xB5, 0x20) + [0xE4, 0xB5, 0x24, 0x0F, 0x88, 0xC3]
        code += out(0xB5, 0x10) + [0xE4, 0xB5, 0x24, 0x0F, 0x88, 0xC7]
        code += out(0xB5, 0x40) + [0xE4, 0xB5, 0x24, 0x0E, 0x88, 0xC1]

        let keys: [(modrm: UInt8, mask: UInt8)] = [(0xC3, 1), (0xC3, 2), (0xC3, 4), (0xC3, 8), (0xC7, 1), (0xC7, 2),
                                                   (0xC7, 4), (0xC7, 8), (0xC1, 2), (0xC1, 4), (0xC1, 8)]
        for (index, key) in keys.enumerated() {
            code += [0xF6, key.modrm, key.mask] + cell(cellAddress(column: 2 + index, row: 1), lit: 3, dark: 0)
        }

        // A and B flip the toggle once per press.
        let flip: [UInt8] = [0x80, 0x36] + le16(toggle) + [0x01]
        let clear = storeByte(previous, 0)
        let chord: [UInt8] = [0x80, 0x3E] + le16(previous) + [0x00, 0x75, UInt8(flip.count)] + flip + storeByte(previous, 1)
            + [0xEB, UInt8(clear.count)]
        code += [0x88, 0xC8, 0x24, 0x0C, 0x3C, 0x0C, 0x75, UInt8(chord.count)] + chord + clear
        code += [0xF6, 0x06] + le16(toggle) + [0x01] + cell(cellAddress(column: 20, row: 1), lit: 1, dark: 0)
        code += [0x80, 0x3E] + le16(cheatOffset) + [0x00] + cell(cellAddress(column: 22, row: 1), lit: 2, dark: 0)
        code += storeByte(cheatOffset, 0)
        let back = main - (code.count + 3)
        code += [0xE9] + le16(UInt16(bitPattern: Int16(back)))

        precondition(code.count <= size - 16, "the program reached the reset entry")
        var rom = code + [UInt8](repeating: 0xFF, count: size - code.count)
        // Reset at FFFF:0000 runs the last 16 bytes: jmp far F000:0000, the ROM's first byte.
        rom.replaceSubrange((size - 16)..<(size - 10), with: [0xEA, 0x00, 0x00, 0x00, 0xF0, 0x00])
        // Footer: developer, colour, game, version, ROM size, 8 KB SRAM, horizontal, no RTC, then the checksum.
        rom.replaceSubrange((size - 10)..<(size - 2), with: [0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x00])
        let sum = rom[0..<(size - 2)].reduce(UInt16(0)) { $0 &+ UInt16($1) }
        rom.replaceSubrange((size - 2)..<size, with: le16(sum))
        return Data(rom)
    }
}
#endif
