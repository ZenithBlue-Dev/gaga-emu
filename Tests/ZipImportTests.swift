import XCTest
@testable import GagaEmu

/// Console ROMs in a .zip: placed by the one ROM inside, then stored unzipped. Every zip here is generated.
final class ZipImportTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A zip of deflated entries. `size` overrides the size the records claim, to fake a bomb.
    static func deflatedZip(_ entries: [(name: String, data: Data, size: Int?)]) throws -> Data {
        var out = Data(), directory = Data()
        func u16(_ value: Int, into data: inout Data) { data += [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)] }
        func u32(_ value: Int, into data: inout Data) { for shift in stride(from: 0, to: 32, by: 8) { data.append(UInt8(value >> shift & 0xFF)) } }
        for entry in entries {
            let name = Data(entry.name.utf8), offset = out.count
            let packed = try (entry.data as NSData).compressed(using: .zlib) as Data // Raw DEFLATE.
            let crc = Int(RomPatcher.crc32(entry.data))
            let fields: (inout Data) -> Void = { data in
                u16(20, into: &data); u16(0, into: &data); u16(8, into: &data); u16(0, into: &data); u16(0x21, into: &data)
                u32(crc, into: &data); u32(packed.count, into: &data); u32(entry.size ?? entry.data.count, into: &data)
                u16(name.count, into: &data); u16(0, into: &data)
            }
            u32(0x0403_4B50, into: &out)
            fields(&out)
            out += name + packed
            u32(0x0201_4B50, into: &directory)
            u16(20, into: &directory)
            fields(&directory)
            u16(0, into: &directory); u16(0, into: &directory); u16(0, into: &directory)
            u32(0, into: &directory); u32(offset, into: &directory)
            directory += name
        }
        let start = out.count
        out += directory
        u32(0x0605_4B50, into: &out)
        u16(0, into: &out); u16(0, into: &out); u16(entries.count, into: &out); u16(entries.count, into: &out)
        u32(directory.count, into: &out); u32(start, into: &out); u16(0, into: &out)
        return out
    }

    private func platform(_ name: String, _ data: Data) throws -> String? {
        try data.write(to: dir.appendingPathComponent(name))
        return CoreCatalog.platformID(forFile: dir.appendingPathComponent(name))
    }

    func testOneConsoleROMPlacesTheZip() throws {
        let gba = GBATestROM.build(), nes = NESTestROM.build(), note = Data("readme".utf8)
        XCTAssertEqual(try platform("gba.zip", try Self.deflatedZip([("Game.GBA", gba, nil)])), "gba")
        XCTAssertEqual(try platform("nes.zip", try Self.deflatedZip([("Game.nes", nes, nil), ("Game.htm", note, nil)])), "nes",
                       "a sidecar file is ignored")
        XCTAssertEqual(try platform("folder.zip", try Self.deflatedZip([("Game/", Data(), nil), ("Game/Game.nes", nes, nil)])), "nes")
        XCTAssertEqual(try platform("stored.zip", GridleeTestSet.zip([("game.gb", GBTestROM.build()), ("info.nfo", note)])), "gb")
        XCTAssertEqual(try platform("disk.zip", GridleeTestSet.zip([("disk.fds", Data(count: 65500))])), "nes")
    }

    func testTwoROMsAndBadEntriesStillAsk() throws {
        let gba = GBATestROM.build()
        XCTAssertNil(try platform("two.zip", try Self.deflatedZip([("a.gba", gba, nil), ("b.nes", NESTestROM.build(), nil)])))
        XCTAssertNil(try platform("up.zip", try Self.deflatedZip([("../evil.gba", gba, nil)])), "path traversal")
        XCTAssertNil(try platform("abs.zip", try Self.deflatedZip([("/tmp/evil.gba", gba, nil)])), "absolute path")
        XCTAssertNil(try platform("drive.zip", try Self.deflatedZip([("C:\\evil.gba", gba, nil)])), "drive path")
        XCTAssertNil(try platform("big.zip", try Self.deflatedZip([("big.gba", gba, 64 << 20)])), "over the GBA limit")
        XCTAssertNil(try platform("eboot.zip", try Self.deflatedZip([("EBOOT.PBP", gba, nil)])), "a .pbp is placed by contents")
    }

    func testMAMEAndDOSZipsAreUnchanged() throws {
        let text = Data("text".utf8)
        XCTAssertEqual(try platform("gridlee.zip", GridleeTestSet.build()), "arcade")
        XCTAssertEqual(try platform("set.zip", GridleeTestSet.zip([("pacman.6e", text), ("82s123", text)])), "arcade")
        XCTAssertEqual(try platform("game.zip", GridleeTestSet.zip([("GAME.EXE", text), ("README.TXT", text)])), "dos")
        XCTAssertEqual(try platform("one.zip", try Self.deflatedZip([("GAME.EXE", text, nil)])), "dos")
    }

    func testExtractionChecksSizeAndCRC() throws {
        let gba = GBATestROM.build()
        let zip = dir.appendingPathComponent("rom.zip"), out = dir.appendingPathComponent("rom.gba")
        try Self.deflatedZip([("rom.gba", gba, nil)]).write(to: zip)
        let entry = try XCTUnwrap(CoreCatalog.zipEntries(zip).first)
        try CoreCatalog.extractZipEntry(entry, from: zip, to: out, limit: CoreCatalog.zipROMLimit("gba"))
        XCTAssertEqual(try Data(contentsOf: out), gba)

        // Claims 1 KiB, inflates to 9 MiB: stops at the 8 MiB Game Boy limit and leaves nothing behind.
        let bomb = dir.appendingPathComponent("bomb.zip"), bombOut = dir.appendingPathComponent("bomb.gb")
        try Self.deflatedZip([("bomb.gb", Data(count: 9 << 20), 1024)]).write(to: bomb)
        XCTAssertEqual(CoreCatalog.platformID(forFile: bomb), "gb", "the records look harmless")
        let bombEntry = try XCTUnwrap(CoreCatalog.zipEntries(bomb).first)
        XCTAssertThrowsError(try CoreCatalog.extractZipEntry(bombEntry, from: bomb, to: bombOut, limit: CoreCatalog.zipROMLimit("gb"))) {
            XCTAssertEqual($0 as? CoreCatalog.ZipError, .tooLarge)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: bombOut.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".part") }, [])

        // A wrong CRC is refused.
        var bad = entry
        bad.crc ^= 1
        XCTAssertThrowsError(try CoreCatalog.extractZipEntry(bad, from: zip, to: out, limit: 1 << 30))
    }

    @MainActor
    func testImportStoresTheROMUnzippedUnderItsOwnName() throws {
        let state = AppState()
        let saved = state.games
        let stem = "zip-\(UUID().uuidString)"
        let zip = state.romDirectory.appendingPathComponent("\(stem).zip")
        let rom = state.romDirectory.appendingPathComponent("\(stem) (USA).gba")
        defer {
            state.games = saved
            state.save()
            try? FileManager.default.removeItem(at: zip)
            try? FileManager.default.removeItem(at: rom)
        }
        try FileManager.default.createDirectory(at: state.romDirectory, withIntermediateDirectories: true)
        try Self.deflatedZip([(rom.lastPathComponent, GBATestROM.build(), nil), ("readme.txt", Data("hi".utf8), nil)]).write(to: zip)
        let game = try XCTUnwrap(state.importROM(at: zip))
        XCTAssertEqual(game.platformID, "gba")
        XCTAssertEqual(game.title, "\(stem) (USA)")
        XCTAssertEqual(URL(fileURLWithPath: game.romPath).lastPathComponent, rom.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: rom), GBATestROM.build())
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip.path), "the copied zip is not kept")

        // The same zip again is the same game.
        try Self.deflatedZip([(rom.lastPathComponent, GBATestROM.build(), nil)]).write(to: zip)
        XCTAssertEqual(state.importROM(at: zip)?.id, game.id)
        XCTAssertEqual(state.games.count, saved.count + 1)
    }

    @MainActor
    func testAROMFileIsNeverAGame() throws {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() }
        XCTAssertNil(state.importROM(at: dir.appendingPathComponent("disksys.rom")))
        XCTAssertEqual(state.games.count, saved.count)
        XCTAssertTrue(BIOSManagerView.required.contains { $0.0 == "disksys.rom" })
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("fds")).pointee.core_id), "nestopia")
    }
}
