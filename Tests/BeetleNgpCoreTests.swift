import XCTest
@testable import GagaEmu

/// Beetle NeoPop through the shared libretro adapter, running the generated cartridge (`NGPTestROM`).
/// Device pending: built and checked on a macOS host harness, not yet run on a device (docs/07 8.4).
final class BeetleNgpCoreTests: XCTestCase {
    private var probe: LibretroProbe!
    private var flashPath: String { (probe.romPath as NSString).deletingPathExtension + ".flash" }

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_ngp"), "GAGA_CORE_SET left this core out")
        probe = try LibretroProbe(coreID: "beetle_ngp", rom: NGPTestROM.build(), name: "homebrew.ngc")
    }

    override func tearDownWithError() throws { probe?.cleanUp() }

    func testTheGeneratedCartridgeHasItsHeader() {
        let rom = [UInt8](NGPTestROM.build())
        XCTAssertEqual(rom.count, NGPTestROM.size)
        XCTAssertEqual(Array(rom[0x1C..<0x20]), [0x40, 0x00, 0x20, 0x00], "start address")
        XCTAssertEqual(rom[0x23], 0x10, "colour mode")
        XCTAssertNil(String(bytes: rom[0..<28], encoding: .ascii)?.range(of: "SNK"), "no SNK licence line")
    }

    func testRegistryResolvesTheRealCore() throws {
        let found = probe.interface
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.29.0.0 a50d5ac2")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 60.25, accuracy: 0.001)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertNil(found.cheat_add, "upstream has no cheats, so the menu row hides")
        for ext in ["ngp", "ngc", "ngpc", "npc"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "beetle_ngp")
            XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "ngp")
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "ngp"), "beetle_ngp")
        XCTAssertEqual(CoreCatalog.platformName("ngp"), "Neo Geo Pocket")
    }

    func testDrawsTheBandsWithNoBIOS() async throws {
        try await probe.load()
        probe.run(30)
        XCTAssertEqual(probe.size.width, 160)
        XCTAssertEqual(probe.size.height, 152)
        XCTAssertGreaterThanOrEqual(probe.colourCount, 4, "white, red, green and blue")
        XCTAssertNil(probe.fatal)
    }

    func testEachButtonChangesThePicture() async throws {
        try await probe.load()
        // RetroPad B is the pocket's A, RetroPad A its B, Start its Option.
        probe.assertEachButtonChangesThePicture([GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                                 GAGA_BTN_SOUTH, GAGA_BTN_EAST, GAGA_BTN_START])
    }

    func testAudioIsNotSilent() async throws {
        try await probe.load()
        probe.assertAudioIsNotSilent()
    }

    /// The flash file is on disk when the flush returns, not only when the game unloads.
    func testFlashBootCounterSurvivesRestarts() async throws {
        for boot in 1...3 {
            try await probe.load()
            probe.run(10)
            probe.core.flushBatterySave()
            let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: flashPath)))
            XCTAssertEqual(NGPTestROM.bootCount(inFlashFile: bytes), boot)
            probe.stop()
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: probe.savePath), "no .sav: the flash file is the save")
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        try await probe.load()
        try probe.assertMednafenStateVersion()
        try probe.assertStateRoundTripAndRefusal(chord: [GAGA_BTN_SOUTH, GAGA_BTN_EAST])
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await probe.assertNoGeneratedCode(buttons: GAGA_BTN_SOUTH)
    }

    /// Upstream reads the 64-byte header without a size check, so short files never reach it.
    func testAFileThatIsNotACartridgeIsRefused() async throws {
        var wrongStart = [UInt8](NGPTestROM.build())
        wrongStart[0x1E] = 0x00
        try await probe.assertRefused([("empty.ngc", Data()), ("short.ngc", Data(count: 0x3F)), ("start.ngc", Data(wrongStart))],
                                      message: "This file is not a Neo Geo Pocket game.")
    }

    func testThePadStartsOnTheTwoButtonLayout() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "ngp"), "two-button")
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        LibretroProbe.assertUploadsPick("beetle_ngp", platforms: ["ngp": "ngp", "ngc": "ngp", "ngpc": "ngp", "npc": "ngp"])
    }

    @MainActor
    func testBenchmarkWritesATestCartridge() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "ngp", to: probe.directory).pathExtension, "ngc")
    }
}
