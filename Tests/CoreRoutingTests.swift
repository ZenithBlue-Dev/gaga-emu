import XCTest
@testable import GagaEmu

/// Which core opens a file. Import places a file on a platform by its contents, and the platform's default core
/// runs it. The registry's lookup by extension alone must agree with the catalog for every extension it claims.
final class CoreRoutingTests: GagaTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("routing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    private func claims(_ coreID: String, _ ext: String) -> Bool {
        guard let core = GagaCoreRegistry_FindByID(coreID) else { return false }
        return String(cString: core.pointee.supported_extensions).lowercased().split(separator: "|").contains { $0 == ext }
    }

    /// The registry's rule (GagaCoreRegistry.c): the extension's own platform, or for a shared disc or archive
    /// extension, the first platform import offers whose default core opens it.
    private func expectedCore(_ ext: String) -> String? {
        let platform = CoreCatalog.platformID(forExtension: ext)
            ?? CoreCatalog.unplacedPlatforms(forExtension: ext)?.first { claims(CoreCatalog.defaultCore(for: $0.id), ext) }?.id
        return platform.map(CoreCatalog.defaultCore(for:)).flatMap { $0.isEmpty ? nil : $0 }
    }

    func testTheRegistryGivesEachExtensionItsPlatformsDefaultCore() throws {
        var checked = Set<String>()
        for index in 0..<GagaCoreRegistry_GetCount() {
            let core = try XCTUnwrap(GagaCoreRegistry_GetAtIndex(index)).pointee
            let id = String(cString: core.core_id)
            guard id != "mock", !GagaCoreRegistry_IsExcluded(id) else { continue }
            // .exe: a PS-EXE or a DOS program, told apart by its first bytes. The registry keeps PCSX-ReARMed.
            for ext in String(cString: core.supported_extensions).lowercased().split(separator: "|").map(String.init)
            where ext != "exe" && checked.insert(ext).inserted {
                guard let expected = expectedCore(ext) else { continue } // An alternate's extension import never offers.
                XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), expected, ext)
            }
        }
        for ext in ["cue", "chd", "ccd", "toc", "m3u", "iso", "bin", "zip", "7z", "elf"] {
            XCTAssertTrue(checked.contains(ext), "shared extension \(ext) is claimed")
        }
    }

    func testTheSharedExtensionsGoWhereTheCatalogSays() throws {
        func core(_ ext: String) throws -> String { String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id) }
        let ps1 = CoreCatalog.defaultCore(for: "ps1")
        try XCTSkipIf(ps1.isEmpty || CoreCatalog.defaultCore(for: "saturn").isEmpty, "GAGA_CORE_SET left a disc core out")
        for ext in ["cue", "chd", "toc", "m3u", "iso", "bin"] { XCTAssertEqual(try core(ext), ps1, ext) }
        XCTAssertEqual(try core("ccd"), "beetle_saturn", "PCSX-ReARMed does not claim .ccd; Saturn is the next disc platform")
        XCTAssertEqual(try core("zip"), CoreCatalog.defaultCore(for: "arcade"))
        XCTAssertEqual(try core("7z"), CoreCatalog.defaultCore(for: "arcade"))
        XCTAssertEqual(try core("elf"), CoreCatalog.defaultCore(for: "psp"))
    }

    /// Gambatte (GPL-2.0-only) is held out of release builds, so mGBA's own GB machine is the default for both.
    func testGameBoyFilesGoToMgba() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("mgba"), "GAGA_CORE_SET left mGBA out")
        for ext in ["gb", "gbc"] {
            XCTAssertEqual(CoreCatalog.defaultCore(for: ext), "mgba", ext)
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "mgba", ext)
        }
    }

    private func write(_ name: String, _ data: Data) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func image(_ text: String, at offset: Int, size: Int = 0x10000) -> Data {
        var bytes = [UInt8](repeating: 0, count: size)
        bytes.replaceSubrange(offset..<(offset + text.utf8.count), with: Array(text.utf8))
        return Data(bytes)
    }

    /// Each platform's own disc, archive or program, placed by content, goes to that platform's default core.
    func testEachPlatformsDefaultCoreIsChosenForItsOwnDiscs() throws {
        let cueBody = { (bin: String) in Data("FILE \"\(bin)\" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n".utf8) }
        _ = try write("ps1.bin", image("PLAYSTATION", at: 16 * 2352 + 24 + 8))
        _ = try write("saturn.bin", image("SEGA SEGASATURN ", at: 16))
        _ = try write("mcd.bin", image("SEGADISCSYSTEM  ", at: 16))
        _ = try write("dc.bin", image("SEGA SEGAKATANA ", at: 16))
        _ = try write("blank.bin", Data(count: 1024))
        _ = try write("saturn2.img", image("SEGA SEGASATURN ", at: 16))
        var elf = [UInt8](repeating: 0, count: 64)
        elf.replaceSubrange(0..<4, with: [0x7F, 0x45, 0x4C, 0x46])
        let mips = Data(elf.enumerated().map { $0.offset == 18 ? 8 : $0.element })
        let arm = Data(elf.enumerated().map { $0.offset == 18 ? 40 : $0.element })
        let cases: [(name: String, data: Data, platform: String)] = [
            ("ps1.cue", cueBody("ps1.bin"), "ps1"),
            ("ps1.m3u", Data("ps1.cue\n".utf8), "ps1"),
            ("ps1.toc", Data("CD_ROM_XA\nTRACK MODE2_RAW\nFILE \"ps1.bin\" 0\n".utf8), "ps1"),
            ("ps1.iso", image("PLAYSTATION", at: 32768 + 8), "ps1"),
            ("psp.iso", image("PSP GAME", at: 32776), "psp"),
            ("saturn.cue", cueBody("saturn.bin"), "saturn"),
            ("saturn2.ccd", Data("[CloneCD]\n".utf8), "saturn"),
            ("mcd.cue", cueBody("mcd.bin"), "megacd"),
            ("dc.cue", cueBody("dc.bin"), "dreamcast"),
            ("pce.cue", Data("FILE \"blank.bin\" BINARY\n  TRACK 01 AUDIO\n".utf8), "pce"),
            ("pce.ccd", Data("[CloneCD]\n".utf8), "pce"),
            ("dos.iso", image("CD001", at: 32769), "dos"),
            ("gridlee.zip", GridleeTestSet.build(), "arcade"),
            ("game.zip", GridleeTestSet.zip([("GAME.EXE", Data("MZ".utf8))]), "dos"),
            ("mips.elf", mips, "psp"),
            ("arm.elf", arm, "n3ds")
        ]
        for item in cases {
            let url = try write(item.name, item.data)
            let platform = CoreCatalog.platformID(forFile: url)
            XCTAssertEqual(platform, item.platform, item.name)
            let expected = CoreCatalog.defaultCore(for: item.platform)
            guard !expected.isEmpty else { continue } // GAGA_CORE_SET left the platform out.
            let game = GameItem(id: UUID(), title: item.name, platformID: platform ?? "unknown", romPath: url.path, coverPath: nil,
                                coreOverride: nil, playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
            XCTAssertEqual(game.resolvedCoreID(defaults: [:]), expected, item.name)
        }
    }
}
