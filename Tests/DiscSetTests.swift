import XCTest
@testable import GagaEmu

/// Multi-file discs: each set in its own folder under ROMs, every file under its own name. Files are generated.
@MainActor
final class DiscSetTests: XCTestCase {
    private var state: AppState!
    private var saved: [GameItem] = []
    private var stem = ""

    override func setUp() async throws {
        state = AppState()
        saved = state.games
        stem = "discset-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(at: state.romDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        state.games = saved
        state.save()
        for name in (try? FileManager.default.contentsOfDirectory(atPath: state.romDirectory.path)) ?? [] where name.hasPrefix(stem) {
            try? FileManager.default.removeItem(at: state.romDirectory.appendingPathComponent(name))
        }
    }

    /// One upload, as Wi-Fi Transfer sends it: placed, then imported.
    @discardableResult
    private func upload(_ name: String, _ data: Data) throws -> GameItem? {
        let part = try ClipboardImporter.partFile(in: state.romDirectory)
        try data.write(to: part)
        let placed = try ClipboardImporter.placeROM(part, named: name, in: state.romDirectory)
        return state.importROM(at: placed)
    }

    private func cue(_ bin: String) -> Data { Data("FILE \"\(bin)\" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n".utf8) }
    private func folder(_ game: GameItem?) -> String? { game.map { URL(fileURLWithPath: $0.romPath).deletingLastPathComponent().lastPathComponent } }

    func testTwoDifferentSetsWithOneNameBothWork() throws {
        try upload("\(stem).cue", cue("\(stem).bin"))
        let first = try XCTUnwrap(try upload("\(stem).bin", Data("one".utf8)), "a late track joins its sheet")
        try upload("\(stem).bin", Data("two".utf8)) // Track first this time: it waits flat.
        let second = try XCTUnwrap(try upload("\(stem).cue", cue("\(stem).bin")))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(folder(first), stem)
        XCTAssertEqual(folder(second), "\(stem) 2")
        for (game, bytes) in [(first, "one"), (second, "two")] {
            let track = URL(fileURLWithPath: game.romPath).deletingLastPathComponent().appendingPathComponent("\(stem).bin")
            XCTAssertEqual(try Data(contentsOf: track), Data(bytes.utf8), "each sheet finds its own track")
        }
        XCTAssertFalse(state.games.contains { $0.romPath.hasSuffix("\(stem).bin") }, "a track that joined a set is no game")
        XCTAssertNotEqual(GagaCoreWrapper.saveDirectory(forROM: first.romPath), GagaCoreWrapper.saveDirectory(forROM: second.romPath),
                          "two sets never share saves")
    }

    func testAnIdenticalSetIsReused() throws {
        try upload("\(stem).cue", cue("\(stem).bin"))
        let game = try XCTUnwrap(try upload("\(stem).bin", Data("same".utf8)))
        try upload("\(stem).cue", cue("\(stem).bin"))
        let again = try XCTUnwrap(try upload("\(stem).bin", Data("same".utf8)))
        XCTAssertEqual(again.id, game.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: state.romDirectory.appendingPathComponent("\(stem) 2").path), "no second copy")
        XCTAssertEqual(state.games.count, saved.count + 1)
    }

    func testAGDIWithSeveralTracks() throws {
        let gdi = Data("3\n1 0 4 2352 \(stem)-1.bin 0\n2 600 0 2352 \"\(stem) 2.raw\" 0\n3 45000 4 2352 \(stem)-3.bin 0\n".utf8)
        try upload("\(stem)-1.bin", Data("1".utf8))
        let game = try XCTUnwrap(try upload("\(stem).gdi", gdi))
        try upload("\(stem) 2.raw", Data("2".utf8))
        try upload("\(stem)-3.bin", Data("3".utf8))
        let dir = URL(fileURLWithPath: game.romPath).deletingLastPathComponent()
        XCTAssertEqual(game.platformID, "dreamcast")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted(),
                       ["\(stem) 2.raw", "\(stem)-1.bin", "\(stem)-3.bin", "\(stem).gdi"])
        XCTAssertEqual(state.games.count, saved.count + 1, "the early track's entry went with it")
    }

    func testAnM3UWithTwoCues() throws {
        for disc in 1...2 {
            try upload("\(stem) (Disc \(disc)).cue", cue("\(stem) (Disc \(disc)).bin"))
            try upload("\(stem) (Disc \(disc)).bin", Data("disc \(disc)".utf8))
        }
        let game = try XCTUnwrap(state.importROM(at: try XCTUnwrap(try {
            let part = try ClipboardImporter.partFile(in: state.romDirectory)
            try Data("\(stem) (Disc 1).cue\n\(stem) (Disc 2).cue\n".utf8).write(to: part)
            return try ClipboardImporter.placeROM(part, named: "\(stem).m3u", in: state.romDirectory)
        }()), platformID: "ps1"))
        let dir = URL(fileURLWithPath: game.romPath).deletingLastPathComponent()
        XCTAssertEqual(dir.lastPathComponent, stem)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 5, "playlist, two sheets, two tracks")
        XCTAssertEqual(state.games.count, saved.count + 1, "the unplayed disc entries joined the playlist")
    }

    func testDeletingAGameRemovesItsFolder() throws {
        try upload("\(stem).cue", cue("\(stem).bin"))
        let game = try XCTUnwrap(try upload("\(stem).bin", Data("x".utf8)))
        let dir = URL(fileURLWithPath: game.romPath).deletingLastPathComponent()
        state.delete(game)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }

    func testAnOldFlatEntryStillLoads() throws {
        let sheet = state.romDirectory.appendingPathComponent("\(stem).cue")
        try cue("\(stem).bin").write(to: sheet)
        try Data("flat".utf8).write(to: state.romDirectory.appendingPathComponent("\(stem).bin"))
        let old = GameItem(id: UUID(), title: stem, platformID: "ps1", romPath: "/old/container/ROMs/\(stem).cue", coverPath: nil,
                           coreOverride: nil, playTime: 60, lastPlayed: Date(), isFavorite: false, shaderID: "original")
        state.games.append(old)
        XCTAssertEqual(old.resolvedROMPath(romDirectory: state.romDirectory), sheet.path, "a flat entry resolves as before")
        XCTAssertEqual(GagaCoreWrapper.saveDirectory(forROM: sheet.path).hasSuffix("Saves/\(stem).cue"), true, "its saves keep their key")
        XCTAssertEqual(state.importROM(at: sheet)?.id, old.id, "and it is not moved or added again")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sheet.path))
    }
}
