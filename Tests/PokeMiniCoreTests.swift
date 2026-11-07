import XCTest
@testable import GagaEmu

/// PokeMini through the shared libretro adapter, running the generated cartridge (`PMTestROM`).
/// Device pending: built and checked on a macOS host harness, not yet run on a device (docs/07 8.6).
final class PokeMiniCoreTests: GagaTestCase {
    private var probe: LibretroProbe!
    private var eepromPath: String { (probe.romPath as NSString).deletingPathExtension + ".eep" }

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("pokemini"), "GAGA_CORE_SET left this core out")
        probe = try LibretroProbe(coreID: "pokemini", rom: PMTestROM.build(), name: "homebrew.min")
    }

    override func tearDownWithError() throws { probe?.cleanUp() }

    func testTheGeneratedCartridgeHasItsHeader() {
        let rom = [UInt8](PMTestROM.build())
        XCTAssertEqual(rom.count, PMTestROM.size)
        XCTAssertEqual(Array(rom[0x2100..<0x2102]), Array("MN".utf8), "what the BIOS checks")
        XCTAssertEqual(rom[0x2102], 0xF3, "JMP to the program")
        XCTAssertNil(String(bytes: rom, encoding: .isoLatin1)?.range(of: "NINTENDO"), "no licence string")
    }

    func testRegistryResolvesTheRealCore() throws {
        let found = probe.interface
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "0.60 132111b7")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 60, accuracy: 0.001)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertNil(found.cheat_add, "upstream has no cheats, so the menu row hides")
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("min")).pointee.core_id), "pokemini")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "min"), "pokemini")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "pokemini"), "pokemini")
        XCTAssertEqual(CoreCatalog.platformName("pokemini"), "Pokémon Mini")
    }

    func testDrawsTheBandsWithTheFreeBIOS() async throws {
        try await probe.load()
        probe.run(30)
        XCTAssertEqual(probe.size.width, 96)
        XCTAssertEqual(probe.size.height, 64)
        XCTAssertEqual(probe.colourCount, 2, "a two-shade LCD")
        XCTAssertNil(probe.fatal)
    }

    func testEachButtonChangesThePicture() async throws {
        try await probe.load()
        probe.run(20) // The BIOS boot.
        // RetroPad A is the console's A, B its B, R its C and Select its Power key.
        probe.assertEachButtonChangesThePicture([GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                                 GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_R1, GAGA_BTN_SELECT])
    }

    func testAudioIsNotSilent() async throws {
        try await probe.load()
        probe.assertAudioIsNotSilent()
    }

    /// The EEPROM file is on disk when the flush returns, not only when the game unloads.
    func testEEPROMBootCounterSurvivesRestarts() async throws {
        for boot in 1...3 {
            try await probe.load()
            probe.run(10)
            probe.core.flushBatterySave()
            let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: eepromPath)))
            XCTAssertEqual(PMTestROM.bootCount(inEEPROMFile: bytes), boot)
            probe.stop()
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: probe.savePath), "no .sav: the EEPROM file is the save")
        XCTAssertFalse(FileManager.default.fileExists(atPath: eepromPath + ".tmp"))
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        try await probe.load()
        probe.run(20)
        let state = [UInt8](try probe.core.saveState())
        XCTAssertEqual(Array(state[16..<28]), Array("PokeMiniStat".utf8))
        let id = state[28..<32].reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        XCTAssertEqual(id, probe.interface.state_version)
        try probe.assertStateRoundTripAndRefusal(chord: [GAGA_BTN_EAST, GAGA_BTN_SOUTH])
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await probe.assertNoGeneratedCode(buttons: GAGA_BTN_EAST)
    }

    /// Upstream aborts the app on a file outside 0x2101 bytes to 2 MB, so those never reach it.
    func testAFileThatIsNotACartridgeIsRefused() async throws {
        try await probe.assertRefused([("empty.min", Data()), ("short.min", Data(count: 0x2100)),
                                       ("long.min", Data(count: 0x200001))],
                                      message: "This file is not a Pokémon Mini game.")
    }

    func testThePadStartsOnTheTwoButtonLayout() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "pokemini"), "two-button")
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await LibretroProbe.assertUploadsPick("pokemini", platforms: ["min": "pokemini"])
    }

    @MainActor
    func testBenchmarkWritesATestCartridge() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "pokemini", to: probe.directory).pathExtension, "min")
    }
}
