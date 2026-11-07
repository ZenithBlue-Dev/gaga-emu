#if DEBUG
import Foundation

/// Generates a tiny Doom II style IWAD (about 230 KB), so tests need no commercial or Freedoom WAD. Every lump is
/// GagaEmu's own: no id Software or Freedoom data. `scripts/make-test-rom.sh` writes the same bytes to a file.
///
/// What it holds:
/// - `PLAYPAL` (RGB 3-3-2, so each index has its own colour) and an identity `COLORMAP`.
/// - `MAP01`: a 512 x 512 room, one sector, four one-sided walls, one subsector and no nodes (PrBoom accepts a
///   trivial map), with the player 1 start south of the centre facing north. `MAP02` to `MAP30` are empty markers:
///   PrBoom calls an IWAD Doom II only when it has 30.
/// - `TITLEPIC`, a solid blue page; `WALL`, a patch in 8-pixel stripes so each step or turn changes the picture;
///   `FLOOR` (checkered), `CEIL` and `F_SKY1` flats; `DSPISTOL`, a square wave (Doom plays it for the pistol and the
///   menu).
/// - Every other patch the status bar, menus and Doom sprites ask for, as directory entries that all point at one
///   1 x 1 patch, so the engine finds each name without the file growing.
enum DoomTestWAD {
    /// Palette index of the title page: RGB 3-3-2 `0x03` is (0, 0, 192).
    static let titleIndex: UInt8 = 0x03

    static func colour(_ index: UInt8) -> (r: Int, g: Int, b: Int) {
        (Int(index & 0xE0), Int(index & 0x1C) << 3, Int(index & 0x03) << 6)
    }

    /// Doom's sprite names (PrBoom's `info.h`), less TNT1, which PrBoom's own prboom.wad supplies.
    static let sprites = """
        TROO SHTG PUNG PISG PISF SHTF SHT2 CHGG CHGF MISG MISF SAWG PLSG PLSF BFGG BFGF BLUD PUFF BAL1 BAL2 PLSS PLSE MISL \
        BFS1 BFE1 BFE2 TFOG IFOG PLAY POSS SPOS VILE FIRE FATB FBXP SKEL MANF FATT CPOS SARG HEAD BAL7 BOSS BOS2 SKUL SPID \
        BSPI APLS APBX CYBR PAIN SSWV KEEN BBRN BOSF ARM1 ARM2 BAR1 BEXP FCAN BON1 BON2 BKEY RKEY YKEY BSKU RSKU YSKU STIM \
        MEDI SOUL PINV PSTR PINS MEGA SUIT PMAP PVIS CLIP AMMO ROCK BROK CELL CELP SHEL SBOX BPAK BFUG MGUN CSAW LAUN PLAS \
        SHOT SGN2 COLU SMT2 GOR1 POL2 POL5 POL4 POL3 POL1 POL6 GOR2 GOR3 GOR4 GOR5 SMIT COL1 COL2 COL3 COL4 CAND CBRA COL6 \
        TRE1 TRE2 ELEC CEYE FSKU COL5 TBLU TGRN TRED SMBT SMGT SMRT HDB1 HDB2 HDB3 HDB4 HDB5 HDB6 POB1 POB2 BRS1 TLMP TLP2 \
        DOGS PLS1 PLS2 BON3 BON4
        """.split(separator: " ").map(String.init)

    private enum Lump {
        case data(String, Data)
        case alias(String, of: String)
    }

    static func wad() -> Data {
        var lumps: [Lump] = []
        func add(_ name: String, _ bytes: Data = Data()) { lumps.append(.data(name, bytes)) }

        add("PLAYPAL", Data((0..<14).flatMap { _ in (0...255).flatMap { i -> [UInt8] in
            let c = colour(UInt8(i)); return [UInt8(c.r), UInt8(c.g), UInt8(c.b)] } }))
        add("COLORMAP", Data((0..<34).flatMap { _ in (0...255).map { UInt8($0) } }))

        // MAP01. Vertices run clockwise, so each wall's front (right-hand) side faces the room.
        let vertices: [(Int16, Int16)] = [(-256, -256), (-256, 256), (256, 256), (256, -256)]
        add("MAP01")
        add("THINGS", le(0, -128, 90, 1, 7))  // x, y, angle, type 1 (player 1 start), all skills
        add("LINEDEFS", Data((0..<4).flatMap { i in le(Int16(i), Int16((i + 1) % 4), 1, 0, 0, Int16(i), -1) }))
        add("SIDEDEFS", Data((0..<4).flatMap { _ in le(0, 0) + name("-") + name("-") + name("WALL") + le(0) }))
        add("VERTEXES", Data(vertices.flatMap { le($0.0, $0.1) }))
        add("SEGS", Data((0..<4).flatMap { i -> Data in
            let (a, b) = (vertices[i], vertices[(i + 1) % 4])
            let turn = atan2(Double(b.1 - a.1), Double(b.0 - a.0)) / (2 * .pi)
            let angle = UInt16(truncatingIfNeeded: Int((turn * 65536).rounded()))
            return le(Int16(i), Int16((i + 1) % 4), Int16(bitPattern: angle), Int16(i), 0, 0)
        }))
        add("SSECTORS", le(4, 0))
        add("NODES")
        add("SECTORS", le(0, 128) + name("FLOOR") + name("CEIL") + le(255, 0, 0))
        add("REJECT")    // PrBoom pads an empty REJECT
        add("BLOCKMAP")  // and builds a missing BLOCKMAP.
        for map in 2...30 { add(String(format: "MAP%02d", map)) }

        // Textures: index 0 is never drawn, by Doom's rule; SKY1 is the Doom II sky.
        add("PNAMES", le32(1) + name("WALL"))
        let textures = ["AASTINKY", "WALL", "SKY1"]
        var texture1 = le32(Int32(textures.count))
        for i in textures.indices { texture1 += le32(Int32(4 + 4 * textures.count + 32 * i)) }
        for t in textures { texture1 += name(t) + le32(0) + le(64, 128) + le32(0) + le(1) + le(0, 0, 0, 1, 0) }
        add("TEXTURE1", texture1)
        add("WALL", patch(width: 64, height: 128) { x, y in UInt8(truncatingIfNeeded: (x / 8) * 0x24 + 0x21 + y / 32) })
        add("DOT", patch(width: 1, height: 1) { _, _ in 0xFF })
        add("TITLEPIC", patch(width: 320, height: 200) { _, _ in titleIndex })

        add("F_START")
        add("FLOOR", Data((0..<4096).map { i -> UInt8 in ((i % 64 / 8) ^ (i / 64 / 8)) & 1 == 1 ? 0x1C : 0x10 }))
        add("CEIL", Data(repeating: 0x49, count: 4096))
        add("F_SKY1", Data(repeating: 0x02, count: 4096))
        add("F_END")

        // DMX sound: format 3, 11025 Hz, sample count with 16 pad bytes each side, 8-bit unsigned.
        let samples = (0..<5512).map { ($0 / 25) % 2 == 1 ? UInt8(0xC0) : 0x40 }
        add("DSPISTOL", le(3, 11025) + le32(Int32(samples.count + 32)) + Data(repeating: 0x80, count: 16)
            + Data(samples) + Data(repeating: 0x80, count: 16))

        var dots = ["STBAR", "STTMINUS", "STTPRCNT", "STARMS", "STFGOD0", "STFDEAD0"]
        dots += (0..<10).flatMap { ["STTNUM\($0)", "STYSNUM\($0)", "STGNUM\($0)", "AMMNUM\($0)"] }
        dots += (0..<9).map { "STKEYS\($0)" } + (0..<4).map { "STFB\($0)" }
        for i in 0..<5 {
            dots += (0..<3).map { "STFST\(i)\($0)" } + ["STFTR\(i)0", "STFTL\(i)0", "STFOUCH\(i)", "STFEVL\(i)", "STFKILL\(i)"]
        }
        dots += (33..<128).filter { $0 != 96 }.map { String(format: "STCFN%03d", $0) }  // prboom.wad has STCFN096.
        dots += ["M_DOOM", "M_NGAME", "M_OPTION", "M_LOADG", "M_SAVEG", "M_RDTHIS", "M_QUITG", "M_SKULL1", "M_SKULL2",
                 "M_NEWG", "M_SKILL", "M_JKILL", "M_ROUGH", "M_HURT", "M_ULTRA", "M_NMARE", "M_PAUSE",
                 "M_THERML", "M_THERMM", "M_THERMR", "M_THERMO", "M_LSLEFT", "M_LSCNTR", "M_LSRGHT",
                 "BRDR_TL", "BRDR_T", "BRDR_TR", "BRDR_L", "BRDR_R", "BRDR_BL", "BRDR_B", "BRDR_BR"]
        lumps += dots.map { .alias($0, of: "DOT") }
        // Frames A to Z of every sprite, rotation 0, so any state the player's weapon reaches has a picture.
        add("S_START")
        lumps += sprites.flatMap { s in (0..<26).map { Lump.alias("\(s)\(Character(UnicodeScalar(65 + $0)!))0", of: "DOT") } }
        add("S_END")
        return pack(lumps)
    }

    /// Doom patch: header, column offsets, then one post per column.
    private static func patch(width: Int, height: Int, _ pixel: (Int, Int) -> UInt8) -> Data {
        var columns = Data(), offsets = Data()
        for x in 0..<width {
            offsets += le32(Int32(8 + 4 * width + columns.count))
            columns += [0, UInt8(height), 0] + (0..<height).map { pixel(x, $0) } + [0, 0xFF]
        }
        return le(Int16(width), Int16(height), 0, 0) + offsets + columns
    }

    private static func pack(_ lumps: [Lump]) -> Data {
        var body = Data(), directory = Data(), placed: [String: (Int32, Int32)] = [:]
        for lump in lumps {
            switch lump {
            case let .data(lumpName, bytes):
                let entry = (Int32(12 + body.count), Int32(bytes.count))
                placed[lumpName] = entry
                body += bytes
                directory += le32(entry.0) + le32(entry.1) + name(lumpName)
            case let .alias(lumpName, of: target):
                let entry = placed[target]!
                directory += le32(entry.0) + le32(entry.1) + name(lumpName)
            }
        }
        return Data("IWAD".utf8) + le32(Int32(lumps.count)) + le32(Int32(12 + body.count)) + body + directory
    }

    private static func name(_ s: String) -> Data {
        Data(s.utf8.prefix(8)) + Data(repeating: 0, count: 8 - min(8, s.utf8.count))
    }

    private static func le(_ values: Int16...) -> Data {
        Data(values.flatMap { v in [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 8)] })
    }

    private static func le32(_ v: Int32) -> Data {
        Data((0..<4).map { UInt8(truncatingIfNeeded: v >> ($0 * 8)) })
    }
}
#endif
