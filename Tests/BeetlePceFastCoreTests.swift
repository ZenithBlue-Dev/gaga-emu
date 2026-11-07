import XCTest
@testable import GagaEmu

/// Beetle PCE Fast through the shared libretro adapter, running the generated HuCard (`PCETestROM`).
/// Device pending: built and checked on a macOS host harness, not yet run on a device (docs/07 8.1).
final class BeetlePceFastCoreTests: GagaTestCase {
    private var probe: LibretroProbe!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_pce_fast"), "GAGA_CORE_SET left this core out")
        probe = try LibretroProbe(coreID: "beetle_pce_fast", rom: PCETestROM.build(), name: "homebrew.pce")
    }

    override func tearDownWithError() throws { probe?.cleanUp() }

    func testTheGeneratedCardHasItsVectors() {
        let rom = [UInt8](PCETestROM.build())
        XCTAssertEqual(rom.count, 0x8000)
        XCTAssertEqual(Array(rom[0x1FFE...0x1FFF]), [0x00, 0xE0], "reset to 0xE000, bank 0")
        XCTAssertEqual(rom[0], 0x78, "sei first")
    }

    func testRegistryResolvesTheRealCore() throws {
        let found = probe.interface
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.31.0 2de1ce1c")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 59.82, accuracy: 0.001)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("pce")).pointee.core_id), "beetle_pce_fast")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "pce"), "beetle_pce_fast")
        XCTAssertEqual(CoreCatalog.platformName("pce"), "PC Engine")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "pce"), "pce")
        XCTAssertNil(CoreCatalog.platformID(forExtension: "ccd"), "a shared disc extension, placed by content")
        let ccd = try probe.write(Data("[CloneCD]\n".utf8), name: "lone.ccd")
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: ccd)), "pce", "a .ccd with no .img to read")
    }

    func testAPCEngineCDIsPlacedByItsAudioFirstTrack() throws {
        let cue = try probe.write(Data("FILE \"game.bin\" BINARY\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n".utf8), name: "game.cue")
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: cue)), "pce")
        XCTAssertTrue(CoreCatalog.discPlatforms.map(\.id).contains("pce"), "offered when a disc says nothing")
    }

    func testDrawsTheBandsWithNoBIOS() async throws {
        try await probe.load()
        probe.run(30)
        XCTAssertEqual(probe.size.width, 256)
        XCTAssertGreaterThanOrEqual(probe.colourCount, 4, "red, green, blue and white bands")
        XCTAssertNil(probe.fatal)
    }

    func testEachButtonChangesThePicture() async throws {
        try await probe.load()
        // RetroPad A is the pad's I, B is II.
        probe.assertEachButtonChangesThePicture([GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_SELECT, GAGA_BTN_START,
                                                 GAGA_BTN_UP, GAGA_BTN_RIGHT, GAGA_BTN_DOWN, GAGA_BTN_LEFT])
    }

    func testAudioIsNotSilent() async throws {
        try await probe.load()
        probe.assertAudioIsNotSilent()
    }

    func testBackupRAMBootCounterSurvivesRestarts() async throws {
        try await probe.assertBootCounterSurvivesRestarts(magic: PCETestROM.bramMagic, magicOffset: PCETestROM.bramMagicOffset,
                                                          counterOffset: PCETestROM.bramCounterOffset)
        XCTAssertEqual(try probe.battery().count, 2048)
        XCTAssertEqual(Array(try probe.battery()[0..<4]), Array("HUBM".utf8), "upstream's file cabinet header")
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        try await probe.load()
        try probe.assertMednafenStateVersion()
        try probe.assertStateRoundTripAndRefusal(chord: [GAGA_BTN_EAST, GAGA_BTN_SOUTH])
    }

    func testRawRAMCheatHasItsEffectAndStops() async throws {
        try await probe.load()
        try probe.assertCheatHasItsEffectAndStops(PCETestROM.cheatCode,
                                                  refused: ["1F0010", "1F0010:1", "ZZ0010:01", "300000:01", "1F0010:01:02"])
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await probe.assertNoGeneratedCode(buttons: GAGA_BTN_EAST)
    }

    /// Upstream opens any HuCard file by path and has no header to check, so a missing file is the bad HuCard
    /// it refuses. An empty one runs as a blank card.
    func testAMissingFileGivesAMessageForThePlayer() async throws {
        do {
            try await probe.load(path: probe.directory.appendingPathComponent("gone.pce").path)
            XCTFail("loaded a missing file")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Beetle PCE Fast could not load this game.")
        }
    }

    func testACDWithNoSystemCardIsRefused() async throws {
        let bin = try probe.write(Data(count: 2352 * 300), name: "disc.bin")
        let cue = try probe.write(Data("FILE \"\((bin as NSString).lastPathComponent)\" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n".utf8),
                                  name: "disc.cue")
        do {
            try await probe.load(path: cue)
            XCTFail("a CD booted without syscard3.pce")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Beetle PCE Fast could not load this game.")
        }
    }

    /// The pad has I and II, Select and Run.
    func testThePadStartsOnTheTwoButtonLayout() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "pce"), "two-button")
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: "standard", platformID: "pce"), "standard")
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await LibretroProbe.assertUploadsPick("beetle_pce_fast", platforms: ["pce": "pce", "ccd": "pce"])
    }

    @MainActor
    func testBenchmarkWritesATestCard() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "pce", to: probe.directory).pathExtension, "pce")
    }
}
