#if DEBUG
import Foundation

/// Generates a small homebrew Neo Geo Pocket Color cartridge, so tests need no commercial game and no SNK
/// material. Hand-assembled TLCS-900/H. The core boots it with its own high-level BIOS, which jumps to the
/// header's start address. `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - Scroll plane 1 shows four bands: the white background, then red, green and blue tiles from palette 0.
/// - Seven key cells on tile row 1, from column 2: blue while that pad bit is held. The bits are Up, Down,
///   Left, Right, A, B, Option.
/// - The T6W28 plays a square wave at about 375 Hz, written directly with the Z80 stopped.
/// - Flash: "GAGA" at `flashMagicAddress` and a boot counter after it, rewritten once per boot through the
///   flash command the core watches for. The core keeps changed flash blocks in `<game>.flash`.
/// - Toggle cell, column 12 of row 1: pressing A and B together flips it. The flag lives in work RAM.
enum NGPTestROM {
    static let flashMagic: [UInt8] = Array("GAGA".utf8)
    static let size = 0x10000
    static let romBase: UInt32 = 0x20_0000
    static let flashMagicAddress: UInt32 = 0x20_FF10
    static let entry: UInt32 = 0x20_0040

    // Work RAM: the chord's previous state and the toggle flag.
    private static let previous: UInt16 = 0x4000, toggle: UInt16 = 0x4001

    private static func le16(_ value: UInt16) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8)] }
    private static func le24(_ value: UInt32) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value >> 16 & 0xFF)] }
    private static func cellAddress(column: Int, row: Int) -> UInt16 { UInt16(0x9000 + (row * 32 + column) * 2) }

    // Instruction bytes, from the core's decode tables. Byte registers: W 0, A 1, B 2, C 3.
    private static func storeWord(_ address: UInt16, _ value: UInt16) -> [UInt8] { [0xF1] + le16(address) + [0x02] + le16(value) }
    private static func storeByte(_ address: UInt16, _ value: UInt8) -> [UInt8] { [0xF1] + le16(address) + [0x00, value] }
    private static func storeIO(_ port: UInt8, _ value: UInt8) -> [UInt8] { [0xF0, port, 0x00, value] }
    private static func storeFar(_ address: UInt32, _ value: UInt8) -> [UInt8] { [0xF2] + le24(address) + [0x00, value] }
    private static func storeFarA(_ address: UInt32) -> [UInt8] { [0xF2] + le24(address) + [0x41] }
    private static func loadA(_ address: UInt16) -> [UInt8] { [0xC1] + le16(address) + [0x21] }
    private static func loadFarA(_ address: UInt32) -> [UInt8] { [0xC2] + le24(address) + [0x21] }
    private static func loadC(_ address: UInt16) -> [UInt8] { [0xC1] + le16(address) + [0x23] }
    private static func storeC(_ address: UInt16) -> [UInt8] { [0xF1] + le16(address) + [0x43] }
    private static let bFromA: [UInt8] = [0xC9, 0x8A]
    private static func andB(_ mask: UInt8) -> [UInt8] { [0xCA, 0xCC, mask] }
    private static func cpB(_ value: UInt8) -> [UInt8] { [0xCA, 0xCF, value] }
    private static func andC(_ mask: UInt8) -> [UInt8] { [0xCB, 0xCC, mask] }
    private static func cpC(_ value: UInt8) -> [UInt8] { [0xCB, 0xCF, value] }
    private static func cpA(_ value: UInt8) -> [UInt8] { [0xC9, 0xCF, value] }
    private static let xorC1: [UInt8] = [0xCB, 0xCD, 0x01]
    private static let incA: [UInt8] = [0xC9, 0x61]
    private static func jr(_ condition: UInt8, _ skip: Int) -> [UInt8] { [0x60 | condition, UInt8(bitPattern: Int8(skip))] }
    private static let z: UInt8 = 6, nz: UInt8 = 14, always: UInt8 = 8
    /// The core takes the byte after a write to 0x205555 or 0x202AAA as a flash write.
    private static let flashCommand = storeFar(0x20_5555, 0xAA)

    /// A cell's tile: `lit` when the Z flag is clear, else `dark`.
    private static func cell(_ address: UInt16, lit: UInt16, dark: UInt16) -> [UInt8] {
        let on = storeWord(address, lit), off = storeWord(address, dark)
        return jr(z, on.count + 2) + on + jr(always, off.count) + off
    }

    static func build() -> Data {
        var code: [UInt8] = [0x06, 0x07] // EI 7: no interrupts.
        code += [0x47] + le16(0x6C00) + le16(0) // LD XSP, 0x6C00.

        // Sound: the PSG on, the Z80 off, then tone 0 at full volume on both sides.
        code += storeIO(0xB8, 0x55) + storeIO(0xB9, 0xAA)
        for value: UInt8 in [0x80, 0x10, 0x90] { code += storeIO(0xA1, value) + storeIO(0xA0, value) }

        // Palette 0 of scroll plane 1: red, green, blue (0x0BGR). Colour 0 shows the white background.
        for (index, colour) in [UInt16(0x000F), 0x00F0, 0x0F00].enumerated() {
            code += storeWord(UInt16(0x8282 + index * 2), colour)
        }
        // Tiles 1 to 3: every pixel colour 1, 2 or 3. A row is eight 2-bit pixels.
        for tile in 1...3 {
            for row in 0..<8 { code += storeWord(UInt16(0xA000 + tile * 16 + row * 2), UInt16(tile) * 0x5555) }
        }
        for row in 0..<19 {
            for column in 0..<20 { code += storeWord(cellAddress(column: column, row: row), UInt16(min(row / 5, 3))) }
        }

        // Boot counter in flash, after "GAGA", which a new cartridge gets first.
        var check: [UInt8] = []
        for (index, byte) in flashMagic.enumerated() { check += loadFarA(flashMagicAddress + UInt32(index)) + cpA(byte) + [0x6E, 0] }
        var fresh: [UInt8] = []
        for (index, byte) in flashMagic.enumerated() { fresh += flashCommand + storeFar(flashMagicAddress + UInt32(index), byte) }
        fresh += flashCommand + storeFar(flashMagicAddress + 4, 0)
        // Each JR NZ in `check` goes to `fresh`; a full match jumps over it.
        let skipFresh = jr(always, fresh.count)
        var offset = 0
        for _ in flashMagic {
            offset += 4 + 1 + 3 + 2 // LD A,(n24); CP A,n; JR NZ
            check[offset - 1] = UInt8(bitPattern: Int8(check.count - offset + skipFresh.count))
        }
        code += check + skipFresh + fresh
        code += loadFarA(flashMagicAddress + 4) + incA + flashCommand + storeFarA(flashMagicAddress + 4)

        let main = entry + UInt32(code.count)
        code += loadA(0x6F82)
        // A and B flip the toggle once per press.
        let flip = loadC(toggle) + xorC1 + storeC(toggle)
        let pressed = cpC(0) + jr(nz, flip.count) + flip
        let heldStore = storeByte(previous, 1), clear = storeByte(previous, 0)
        let chord = loadC(previous) + pressed + heldStore + jr(always, clear.count)
        code += bFromA + andB(0x30) + cpB(0x30) + jr(nz, chord.count) + chord + clear

        for key in 0..<7 { code += bFromA + andB(UInt8(1 << key)) + cell(cellAddress(column: 2 + key, row: 1), lit: 3, dark: 0) }
        code += loadC(toggle) + andC(1) + cell(cellAddress(column: 12, row: 1), lit: 1, dark: 0)
        code += [0x1B] + le24(main) // JP main.

        // Header: a homebrew licence line, the start address, a catalog no hack matches, colour mode, the name.
        var rom = [UInt8](repeating: 0xFF, count: size)
        let licence = Array("GAGAEMU HOMEBREW TEST CART  ".utf8)
        rom.replaceSubrange(0..<28, with: licence)
        rom.replaceSubrange(0x1C..<0x20, with: le24(entry) + [0])
        rom.replaceSubrange(0x20..<0x24, with: le16(0x7A61) + [0x00, 0x10])
        rom.replaceSubrange(0x24..<0x30, with: Array("GAGA TEST   ".utf8))
        rom.replaceSubrange(0x30..<0x40, with: [UInt8](repeating: 0, count: 16))
        precondition(Int(entry - romBase) + code.count <= Int(flashMagicAddress - romBase) & ~0xFF, "the program reached the flash block")
        rom.replaceSubrange(Int(entry - romBase)..<(Int(entry - romBase) + code.count), with: code)
        return Data(rom)
    }

    /// The boot counter in a `.flash` file the core wrote, found after the magic.
    static func bootCount(inFlashFile bytes: [UInt8]) -> Int? {
        guard bytes.count >= 5 else { return nil }
        for start in 0...(bytes.count - 5) where Array(bytes[start..<(start + 4)]) == flashMagic { return Int(bytes[start + 4]) }
        return nil
    }
}
#endif
