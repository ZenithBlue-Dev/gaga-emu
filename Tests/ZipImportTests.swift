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

    /// A 40 KiB ISO 9660 image whose primary volume descriptor (sector 16) names a PSP UMD.
    static func pspISO() -> Data {
        var iso = Data(count: 40960)
        iso.replaceSubrange(32768..<32776, with: [1] + Array("CD001".utf8) + [1, 0])
        iso.replaceSubrange(32776..<32784, with: Array("PSP GAME".utf8))
        return iso
    }

    /// One deflated entry written as zip64: the central record's sizes and offset, and the end record's directory
    /// size and offset, are all ones and live in the zip64 extra and the zip64 end record.
    static func zip64(_ name: String, _ data: Data) throws -> Data {
        func le(_ value: Int, _ bytes: Int) -> Data { Data((0..<bytes).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) }
        let packed = try (data as NSData).compressed(using: .zlib) as Data, file = Data(name.utf8)
        let crc = Int(RomPatcher.crc32(data)), ones = 0xFFFF_FFFF
        var out = le(0x0403_4B50, 4) + le(45, 2) + le(0, 2) + le(8, 2) + le(0, 4) + le(crc, 4)
        out += le(packed.count, 4) + le(data.count, 4) + le(file.count, 2) + le(0, 2) + file + packed
        let extra = le(1, 2) + le(24, 2) + le(data.count, 8) + le(packed.count, 8) + le(0, 8)
        let directory = le(0x0201_4B50, 4) + le(45, 2) + le(45, 2) + le(0, 2) + le(8, 2) + le(0, 4) + le(crc, 4)
            + le(ones, 4) + le(ones, 4) + le(file.count, 2) + le(extra.count, 2) + le(0, 2) + le(0, 2) + le(0, 2)
            + le(0, 4) + le(ones, 4) + file + extra
        let start = out.count
        out += directory
        let record = out.count
        out += le(0x0606_4B50, 4) + le(44, 8) + le(45, 2) + le(45, 2) + le(0, 4) + le(0, 4) + le(1, 8) + le(1, 8)
            + le(directory.count, 8) + le(start, 8)
        out += le(0x0706_4B50, 4) + le(0, 4) + le(record, 8) + le(1, 4)
        out += le(0x0605_4B50, 4) + le(0xFFFF, 2) + le(0xFFFF, 2) + le(0xFFFF, 2) + le(0xFFFF, 2) + le(ones, 4) + le(ones, 4) + le(0, 2)
        return out
    }

    func testZip64RecordsAreRead() throws {
        let gba = GBATestROM.build()
        let zip = dir.appendingPathComponent("big.zip")
        try Self.zip64("Game.gba", gba).write(to: zip)
        let entry = try XCTUnwrap(CoreCatalog.zipEntries(zip).first)
        XCTAssertEqual(entry.size, gba.count)
        XCTAssertEqual(entry.localHeaderOffset, 0)
        XCTAssertEqual(CoreCatalog.platformID(forFile: zip), "gba")
        let out = try CoreCatalog.extractZipEntry(entry, from: zip, to: dir.appendingPathComponent("Game.gba"), limit: 1 << 30)
        XCTAssertEqual(try Data(contentsOf: out), gba)
    }

    /// An .iso names no platform by itself, so one in a zip or 7z is unpacked and placed by its sector 16, as a bare
    /// .iso is (device run 5: a PSP UMD in a 7z named .zip stayed "unknown").
    @MainActor
    func testAnISOInAnArchiveIsPlacedByItsContents() throws {
        let state = AppState()
        let saved = state.games
        let stem = "iso-\(UUID().uuidString)"
        defer { cleanUp(state, saved, stem: stem) }
        try FileManager.default.createDirectory(at: state.romDirectory, withIntermediateDirectories: true)
        let iso = Self.pspISO()
        XCTAssertNil(try platform("umd.zip", try Self.deflatedZip([("Game.iso", iso, nil)])), "nothing extracted yet")
        for (suffix, archive) in [("zip", try Self.deflatedZip([("\(stem)-a.iso", iso, nil)])),
                                  ("7z", SevenZipTestArchive.build([("\(stem)-b.iso", iso)])),
                                  ("zip", try Self.zip64("\(stem)-c.iso", iso))] {
            let url = state.romDirectory.appendingPathComponent("\(stem)-\(suffix)-\(archive.count).\(suffix)")
            try archive.write(to: url)
            let game = try XCTUnwrap(state.importROM(at: url), suffix)
            XCTAssertEqual(game.platformID, "psp", suffix)
            XCTAssertEqual(URL(fileURLWithPath: game.romPath).pathExtension, "iso", suffix)
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: game.romPath)), iso, suffix)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "\(suffix): the copied archive is not kept")
        }
    }

    /// Restores the saved library and removes every ROM-folder file a test made.
    @MainActor
    private func cleanUp(_ state: AppState, _ saved: [GameItem], stem: String) {
        state.games = saved
        state.save()
        for name in (try? FileManager.default.contentsOfDirectory(atPath: state.romDirectory.path)) ?? [] where name.hasPrefix(stem) {
            try? FileManager.default.removeItem(at: state.romDirectory.appendingPathComponent(name))
        }
    }

    @MainActor
    func testTheSameROMNameNeverReplacesADifferentROM() throws {
        let state = AppState()
        let saved = state.games
        let stem = "same-\(UUID().uuidString)"
        defer { cleanUp(state, saved, stem: stem) }
        try FileManager.default.createDirectory(at: state.romDirectory, withIntermediateDirectories: true)
        let first = GBATestROM.build()
        var second = first
        second[second.count - 1] ^= 0xFF
        func importZip(_ zipName: String, _ data: Data) throws -> GameItem? {
            let zip = state.romDirectory.appendingPathComponent("\(stem)-\(zipName).zip")
            try Self.deflatedZip([("\(stem).gba", data, nil)]).write(to: zip)
            return state.importROM(at: zip)
        }
        let game = try XCTUnwrap(try importZip("a", first))
        let other = try XCTUnwrap(try importZip("b", second), "another zip, same ROM name, other bytes")
        XCTAssertNotEqual(other.id, game.id)
        XCTAssertEqual(URL(fileURLWithPath: other.romPath).lastPathComponent, "\(stem) 2.gba")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: game.romPath)), first, "the first ROM is untouched")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: other.romPath)), second)
        XCTAssertEqual(try importZip("c", first)?.id, game.id, "the same bytes again are the same game")
        XCTAssertEqual(state.games.count, saved.count + 2)

        // A plain file goes through the same placement.
        let blob = { (data: Data) in try ClipboardImporter.persist(.blob(filename: "\(stem).nes", data: data), into: state.romDirectory) }
        let nes = try blob(Data("one".utf8))
        XCTAssertEqual(try blob(Data("one".utf8)), nes)
        XCTAssertEqual(try blob(Data("two".utf8)).lastPathComponent, "\(stem) 2.nes")
        XCTAssertEqual(try Data(contentsOf: nes), Data("one".utf8))
    }

    @MainActor
    func testABIOSNameNeverReplacesADifferentSystemFile() throws {
        let state = AppState()
        let saved = state.games
        state.systemDirectory = dir.appendingPathComponent("System")
        let rom = state.romDirectory.appendingPathComponent("firmware.bin")
        try XCTSkipIf(FileManager.default.fileExists(atPath: rom.path), "a real firmware.bin is in ROMs")
        defer {
            state.games = saved
            state.save()
            try? FileManager.default.removeItem(at: rom)
        }
        try FileManager.default.createDirectory(at: state.systemDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: state.romDirectory, withIntermediateDirectories: true)
        let system = state.systemDirectory.appendingPathComponent("firmware.bin")
        let kept = Data(repeating: 1, count: 256 << 10)
        try kept.write(to: system)

        try kept.write(to: rom)
        XCTAssertNil(state.importROM(at: rom))
        XCTAssertNil(state.lastImportNote, "identical: nothing to say")
        XCTAssertFalse(FileManager.default.fileExists(atPath: rom.path))

        try Data(repeating: 2, count: 256 << 10).write(to: rom)
        XCTAssertNil(state.importROM(at: rom))
        XCTAssertNotNil(state.lastImportNote, "the player hears the System copy was kept")
        XCTAssertEqual(try Data(contentsOf: system), kept)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rom.path), "the new file is not lost")

        // A game that happens to have a BIOS name, at a size no core reads as that BIOS.
        try Data(repeating: 3, count: 1 << 20).write(to: rom)
        XCTAssertNotNil(state.importROM(at: rom))
        XCTAssertEqual(try Data(contentsOf: system), kept)
        XCTAssertEqual(Set(BIOSManagerView.sizes.keys), Set(BIOSManagerView.required.map(\.0) + BIOSManagerView.snesFirmware.map(\.0)),
                       "every BIOS has its sizes")
    }

    @MainActor
    func testARefusedOrDamagedZipSaysWhyAndAnUnclearOneOffersItsPlatforms() throws {
        let state = AppState()
        let saved = state.games
        let stem = "refused-\(UUID().uuidString)"
        defer { cleanUp(state, saved, stem: stem) }
        try FileManager.default.createDirectory(at: state.romDirectory, withIntermediateDirectories: true)
        let gba = GBATestROM.build()
        var garbled = try Self.deflatedZip([("game.gba", gba, nil)])
        garbled[30 + 8 + 4] ^= 0xFF // Inside the deflated data, after the 30-byte header and "game.gba".
        let cases: [(String, Data, CoreCatalog.ZipError)] = [
            ("broken", Data("PK".utf8), .corrupt),
            ("garbled", garbled, .corrupt),
            ("up", try Self.deflatedZip([("../evil.gba", gba, nil)]), .unsafeName),
            ("big", try Self.deflatedZip([("big.gba", gba, 64 << 20)]), .tooLarge)
        ]
        for (name, data, error) in cases {
            let zip = state.romDirectory.appendingPathComponent("\(stem)-\(name).zip")
            try data.write(to: zip)
            XCTAssertNil(state.importROM(at: zip), name)
            XCTAssertEqual(state.lastImportNote?.hasSuffix(try XCTUnwrap(error.errorDescription)), true, name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: zip.path), "\(name) stays where it is")
        }
        XCTAssertEqual(state.games.count, saved.count, "no shelf entry, so no platform question")

        let unclear = state.romDirectory.appendingPathComponent("\(stem)-two.zip")
        try Self.deflatedZip([("a.gba", gba, nil), ("b.nes", NESTestROM.build(), nil), ("c.gba", gba, nil)]).write(to: unclear)
        let game = try XCTUnwrap(state.importROM(at: unclear))
        XCTAssertEqual(game.platformID, "unknown")
        XCTAssertEqual(CoreCatalog.unplacedPlatforms(forFile: URL(fileURLWithPath: game.romPath))?.map(\.id), ["gba", "nes", "arcade", "dos"])
    }

    @MainActor
    func testMixedCaseBIOSNamesRouteToSystemUnderTheCoreName() throws {
        let state = AppState()
        let saved = state.games
        let system = FileManager.default.temporaryDirectory.appendingPathComponent("system-\(UUID().uuidString)")
        state.systemDirectory = system
        defer { state.games = saved; state.save(); try? FileManager.default.removeItem(at: system) }
        let cases: [(String, String, Int)] = [
            ("BIOS_CD_U.BIN", "bios_CD_U.bin", 128 << 10), ("bios_cd_e.bin", "bios_CD_E.bin", 128 << 10),
            ("Bios_Cd_J.bin", "bios_CD_J.bin", 128 << 10), ("KICK34005.a500", "kick34005.A500", 256 << 10),
            ("kick40068.a1200", "kick40068.A1200", 512 << 10), ("SCPH5501.BIN", "scph5501.bin", 512 << 10)
        ]
        for (arrived, exact, size) in cases {
            let file = state.romDirectory.appendingPathComponent(arrived)
            try Data(count: size).write(to: file)
            XCTAssertNil(state.importROM(at: file), arrived)
            let names = try FileManager.default.contentsOfDirectory(atPath: system.path)
            XCTAssertTrue(names.contains(exact), "\(arrived) is placed as \(exact), got \(names)")
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "\(arrived) left ROMs")
        }
        XCTAssertEqual(state.games.count, saved.count)
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
