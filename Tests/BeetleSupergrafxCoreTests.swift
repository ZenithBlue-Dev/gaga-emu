import XCTest
@testable import GagaEmu

/// Beetle SuperGrafx through the shared libretro adapter, running the generated SuperGrafx card
/// (`PCETestROM.build(superGrafx: true)`). Device pending: built and checked on a macOS host harness, not yet run
/// on a device (docs/07 8.2).
final class BeetleSupergrafxCoreTests: XCTestCase {
    private var probe: LibretroProbe!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_supergrafx"), "GAGA_CORE_SET left this core out")
        probe = try LibretroProbe(coreID: "beetle_supergrafx", rom: PCETestROM.build(superGrafx: true), name: "homebrew.sgx")
    }

    override func tearDownWithError() throws { probe?.cleanUp() }

    func testRegistryResolvesTheRealCore() throws {
        let found = probe.interface
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.29.0 9c11dcd2")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 59.82, accuracy: 0.001)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("sgx")).pointee.core_id), "beetle_supergrafx")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "sgx"), "beetle_supergrafx")
        XCTAssertEqual(CoreCatalog.platformName("sgx"), "SuperGrafx")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "sgx"), "sgx")
    }

    func testDrawsTheBandsWithNoBIOS() async throws {
        try await probe.load()
        probe.run(30)
        XCTAssertEqual(probe.size.width, 256)
        XCTAssertGreaterThanOrEqual(probe.colourCount, 4, "red, green, blue and white bands")
        XCTAssertNil(probe.fatal)
    }

    /// The .sgx name turns on the second VDC and the 32 KB of work RAM, which the state carries.
    func testTheSGXExtensionRunsInSuperGrafxMode() async throws {
        try await probe.load()
        probe.run(4)
        let superGrafx = try probe.core.saveState().count
        let plain = try probe.write(PCETestROM.build(superGrafx: true), name: "plain.pce")
        try await probe.load(path: plain)
        probe.run(4)
        XCTAssertGreaterThan(superGrafx, try probe.core.saveState().count + 32768)
    }

    func testEachButtonChangesThePicture() async throws {
        try await probe.load()
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
                                                  refused: ["1F0010", "1F0010:1", "ZZ0010:01", "300000:01", "1F0010:01:02",
                                                            String(repeating: "1F0010:01+", count: 40)])
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await probe.assertNoGeneratedCode(buttons: GAGA_BTN_EAST)
    }

    func testAMissingFileGivesAMessageForThePlayer() async throws {
        do {
            try await probe.load(path: probe.directory.appendingPathComponent("gone.sgx").path)
            XCTFail("loaded a missing file")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Beetle SuperGrafx could not load this game.")
        }
    }

    func testThePadStartsOnTheTwoButtonLayout() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "sgx"), "two-button")
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        LibretroProbe.assertUploadsPick("beetle_supergrafx", platforms: ["sgx": "sgx"])
    }

    @MainActor
    func testBenchmarkWritesATestCard() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "sgx", to: probe.directory).pathExtension, "sgx")
    }
}
