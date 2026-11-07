#if DEBUG
import Foundation

/// Generates a small homebrew PC Engine HuCard, so tests need no commercial game and no NEC or Hudson material.
/// Hand-assembled HuC6280. The same image also runs as a SuperGrafx card (`build(superGrafx:)`), which shows
/// the first VDC. `scripts/make-test-rom.sh` writes the same bytes to a file for import tests.
///
/// What the program does:
/// - Four horizontal bands of background tiles, red, green, blue and white, from palettes 1 to 4.
/// - Eight key cells on tile row 2, from tile column 4: white while that pad bit is held. The bits are I, II,
///   Select, Run, Up, Right, Down, Left.
/// - Polls the VDC's vertical blank flag once per frame, so it stalls if the VDC never reaches blanking.
/// - PSG channel 0 plays a square wave at about 440 Hz.
/// - Backup RAM (bank F7): "GAGA" at `bramMagicOffset` and a boot counter after it, incremented once per boot.
/// - Toggle cell, tile column 0 of row 2: pressing I and II together flips it. The flag lives in work RAM.
/// - Cheat cell, column 1: lit for a frame after anything writes a non-zero byte to work RAM `cheatOffset`,
///   which the program clears each frame, so a raw RAM code shows while it is on and stops when it is off.
enum PCETestROM {
    static let bramMagic: [UInt8] = Array("GAGA".utf8)
    /// After upstream's 8-byte "HUBM" file cabinet header, which the core writes into a new backup RAM.
    static let bramMagicOffset = 0x10
    static let bramCounterOffset = 0x14
    static let cheatOffset: UInt16 = 0x0010
    /// Upstream's raw code for a byte of work RAM: bank 1F, then the offset.
    static var cheatCode: String { String(format: "1F%04X:01", cheatOffset) }
    static let toneHertz = 3_579_545.0 / (32 * 254)

    // Zero page, in work RAM at 0x2000.
    private static let keys: UInt16 = 0x2000, previous: UInt16 = 0x2001, toggle: UInt16 = 0x2002, scratch: UInt16 = 0x2003

    /// 9-bit GRB: black, red, green, blue, white, as colour 1 of palettes 1 to 4 (colour 0 stays black).
    private static let colours: [UInt16] = [0x038, 0x1C0, 0x007, 0x1FF]

    static func build(superGrafx: Bool = false) -> Data {
        var a = Assembler6502(origin: 0xE000)
        a.emit(0x78, 0xD4, 0xD8) // sei; csh; cld
        a.emit(0xA2, 0xFF, 0x9A) // ldx #$FF; txs
        a.emit(0xA9, 0xFF, 0x53, 0x01) // lda #$FF; tam #0: I/O at 0x0000.
        a.emit(0xA9, 0xF8, 0x53, 0x02) // lda #$F8; tam #1: work RAM at 0x2000.
        a.emit(0xA9, 0xF7, 0x53, 0x04) // lda #$F7; tam #2: backup RAM at 0x4000.
        a.emit(0xA9, 0x07, 0x8D, 0x02, 0x14) // lda #7; sta $1402: mask every interrupt source.
        a.emit(0x9C, 0x00, 0x04) // stz $0400: VCE dot clock 0, 256 pixels.
        if superGrafx {
            // VPC: VDC 1 in front everywhere, VDC 2 off, so the card shows what a PC Engine shows.
            for (address, value) in [(0x0008, 0x11), (0x0009, 0x11), (0x000A, 0), (0x000B, 0), (0x000C, 0), (0x000D, 0)] as [(UInt16, UInt8)] {
                a.emit(0xA9, value, 0x8D, UInt8(address & 0xFF), UInt8(address >> 8))
            }
        }

        // VDC timing for 256x240, the MagicKit values, then the 32x32 background map and no sprites.
        let registers: [(UInt8, UInt16)] = [(0x05, 0), (0x06, 0), (0x07, 0), (0x08, 0), (0x09, 0x0000), (0x0A, 0x0202),
                                            (0x0B, 0x031F), (0x0C, 0x0F02), (0x0D, 0x00EF), (0x0E, 0x0003), (0x0F, 0)]
        for (register, value) in registers { a.vdc(register, value) }

        // Palettes 0 to 4, colour 0 black and colour 1 from `colours`.
        a.emit(0x9C, 0x02, 0x04, 0x9C, 0x03, 0x04) // stz $0402; stz $0403: colour address 0.
        for palette in 0..<5 {
            for colour in 0..<16 {
                let value: UInt16 = palette > 0 && colour == 1 ? colours[palette - 1] : 0
                a.emit(0xA9, UInt8(value & 0xFF), 0x8D, 0x04, 0x04, 0xA9, UInt8(value >> 8), 0x8D, 0x05, 0x04)
            }
        }

        // One tile at VRAM word 0x1000 (tile 0x100), every pixel colour 1: plane 0 set, planes 1 to 3 clear.
        a.vdc(0x00, 0x1000)
        a.emit(0x03, 0x02) // st0 #2: VRAM data.
        for row in 0..<16 { a.emit(0x13, row < 8 ? 0xFF : 0x00, 0x23, 0x00) } // st1; st2

        // The bands, 8 tile rows each.
        a.vdc(0x00, 0x0000)
        a.emit(0x03, 0x02)
        for band in 1...4 {
            a.emit(0xA2, 0x00) // ldx #0: 256 entries.
            let fill = a.here
            a.emit(0x13, 0x00, 0x23, UInt8(band << 4 | 0x01)) // st1 #0; st2 #palette | tile 0x100
            a.emit(0xCA) // dex
            a.branch(0xD0, to: fill) // bne
        }

        // PSG channel 0: main volume, then a square wave in the waveform RAM, the period and on at full volume.
        a.store(0x0800, 0x00)
        a.store(0x0801, 0xFF)
        a.store(0x0804, 0x00) // Off, which also resets the waveform index.
        for sample in 0..<32 { a.store(0x0806, sample < 16 ? 0x1F : 0x00) }
        a.store(0x0802, 254)
        a.store(0x0803, 0)
        a.store(0x0805, 0xFF)
        a.store(0x0804, 0x9F)

        // Backup RAM: a first boot has no magic, whatever the bytes hold. Then the counter goes up by one.
        let bram = 0x4000 + UInt16(bramMagicOffset)
        a.emit(0xAD, UInt8(bram & 0xFF), UInt8(bram >> 8)) // lda magic
        a.emit(0xC9, bramMagic[0]) // cmp #'G'
        let known = a.forwardBranch(0xF0) // beq
        for (offset, byte) in bramMagic.enumerated() { a.store(bram + UInt16(offset), byte) }
        a.emit(0x9C, UInt8((0x4000 + bramCounterOffset) & 0xFF), UInt8((0x4000 + bramCounterOffset) >> 8)) // stz counter
        a.patch(known)
        a.emit(0xEE, UInt8((0x4000 + bramCounterOffset) & 0xFF), UInt8((0x4000 + bramCounterOffset) >> 8)) // inc counter

        a.emit(0x64, 0x02, 0x64, 0x01) // stz toggle; stz previous (zero page 0x2002, 0x2001)
        a.vdc(0x05, 0x0088) // CR: background on, vertical blank flag on.

        let frame = a.here
        a.emit(0xAD, 0x00, 0x00, 0x29, 0x20) // lda $0000; and #$20: VDC status, vertical blank.
        a.branch(0xF0, to: frame) // beq

        // Pad: Up, Right, Down, Left with SEL set, then I, II, Select, Run with it clear. Active low.
        a.store(0x1000, 0x01)
        a.store(0x1000, 0x03)
        a.store(0x1000, 0x01)
        a.emit(0xAD, 0x00, 0x10, 0x0A, 0x0A, 0x0A, 0x0A, 0x85, 0x03) // lda $1000; asl x4; sta scratch
        a.store(0x1000, 0x00)
        a.emit(0xAD, 0x00, 0x10, 0x29, 0x0F, 0x05, 0x03, 0x49, 0xFF, 0x85, 0x00) // lda; and #$0F; ora scratch; eor #$FF; sta keys

        // Key cells, BAT words 0x44 to 0x4B.
        a.vdc(0x00, 0x0044)
        a.emit(0x03, 0x02)
        a.emit(0xA5, 0x00, 0x85, 0x03) // lda keys; sta scratch
        a.emit(0xA2, 0x08) // ldx #8
        let cell = a.here
        a.emit(0x46, 0x03) // lsr scratch
        a.emit(0xA9, 0x11) // lda #$11: red band.
        a.emit(0x90, 0x02, 0xA9, 0x41) // bcc +2; lda #$41: white.
        a.emit(0x9C, 0x02, 0x00, 0x8D, 0x03, 0x00) // stz $0002; sta $0003
        a.emit(0xCA) // dex
        a.branch(0xD0, to: cell)

        // Flip the toggle on the press of I and II only.
        a.emit(0xA5, 0x00, 0x29, 0x03, 0xC9, 0x03) // lda keys; and #3; cmp #3
        let notHeld = a.forwardBranch(0xD0) // bne
        a.emit(0xA5, 0x01, 0x29, 0x03, 0xC9, 0x03) // lda previous; and #3; cmp #3
        let wasHeld = a.forwardBranch(0xF0) // beq
        a.emit(0xA5, 0x02, 0x49, 0x01, 0x85, 0x02) // lda toggle; eor #1; sta toggle
        a.patch(notHeld)
        a.patch(wasHeld)
        a.emit(0xA5, 0x00, 0x85, 0x01) // lda keys; sta previous

        // Toggle and cheat cells, BAT words 0x40 and 0x41.
        a.vdc(0x00, 0x0040)
        a.emit(0x03, 0x02)
        a.emit(0xA5, 0x02) // lda toggle
        a.litCell()
        let cheat = 0x2000 + cheatOffset
        a.emit(0xAD, UInt8(cheat & 0xFF), UInt8(cheat >> 8), 0x9C, UInt8(cheat & 0xFF), UInt8(cheat >> 8)) // lda cheat; stz cheat
        a.litCell()
        a.jump(frame)

        let rti = a.here
        a.emit(0x40) // rti, for every vector but reset.
        return image(code: a.bytes, rti: rti)
    }

    /// 32 KB, no header. Bank 0 holds the code at 0xE000 and the vectors, as MPR 7 maps it at power on.
    private static func image(code: [UInt8], rti: UInt16) -> Data {
        var rom = [UInt8](repeating: 0xFF, count: 0x8000)
        precondition(code.count < 0x1FF0, "the program ran into the vectors")
        rom.replaceSubrange(0..<code.count, with: code)
        for vector in stride(from: 0x1FF6, to: 0x1FFE, by: 2) {
            rom[vector] = UInt8(rti & 0xFF)
            rom[vector + 1] = UInt8(rti >> 8)
        }
        rom[0x1FFE] = 0x00
        rom[0x1FFF] = 0xE0
        return Data(rom)
    }
}

/// Just enough of a 6502 assembler for the HuC6280 programs. Addresses are CPU addresses.
struct Assembler6502 {
    let origin: UInt16
    private(set) var bytes: [UInt8] = []
    var here: UInt16 { origin + UInt16(bytes.count) }

    init(origin: UInt16) { self.origin = origin }

    mutating func emit(_ values: UInt8...) { bytes += values }

    /// lda #value; sta address
    mutating func store(_ address: UInt16, _ value: UInt8) {
        bytes += [0xA9, value, 0x8D, UInt8(address & 0xFF), UInt8(address >> 8)]
    }

    /// HuC6280 st0, st1, st2: selects a VDC register and writes a word to it.
    mutating func vdc(_ register: UInt8, _ value: UInt16) {
        bytes += [0x03, register, 0x13, UInt8(value & 0xFF), 0x23, UInt8(value >> 8)]
    }

    /// Writes one background map entry at the VDC's address: white when A is non-zero, otherwise the red band.
    mutating func litCell() {
        bytes += [0xF0, 0x02] // beq +2
        bytes += [0xA9, 0x30] // lda #$30, turned into $41 below
        bytes += [0x18, 0x69, 0x11] // clc; adc #$11: $11 when A was 0, $41 when it was $30.
        bytes += [0x9C, 0x02, 0x00, 0x8D, 0x03, 0x00] // stz $0002; sta $0003
    }

    mutating func jump(_ target: UInt16) { bytes += [0x4C, UInt8(target & 0xFF), UInt8(target >> 8)] }

    mutating func branch(_ opcode: UInt8, to target: UInt16) {
        let delta = Int(target) - (Int(here) + 2)
        precondition((-128...127).contains(delta), "branch out of range")
        bytes += [opcode, UInt8(bitPattern: Int8(delta))]
    }

    /// A branch to a later place, filled in by `patch`.
    mutating func forwardBranch(_ opcode: UInt8) -> Int {
        bytes += [opcode, 0]
        return bytes.count - 1
    }

    mutating func patch(_ fixup: Int) {
        let delta = bytes.count - (fixup + 1)
        precondition(delta <= 127, "branch out of range")
        bytes[fixup] = UInt8(delta)
    }
}
#endif
