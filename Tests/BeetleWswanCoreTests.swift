import XCTest
@testable import GagaEmu

/// Beetle Cygne through the shared libretro adapter, running the generated cartridge (`WSTestROM`).
/// Device pending: built and checked on a macOS host harness, not yet run on a device (docs/07 8.5).
final class BeetleWswanCoreTests: XCTestCase {
    private var probe: LibretroProbe!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_wswan"), "GAGA_CORE_SET left this core out")
        probe = try LibretroProbe(coreID: "beetle_wswan", rom: WSTestROM.build(), name: "homebrew.wsc")
    }

    override func tearDownWithError() throws { probe?.cleanUp() }

    func testTheGeneratedCartridgeHasItsResetJump() {
        let rom = [UInt8](WSTestROM.build())
        XCTAssertEqual(rom.count, WSTestROM.size)
        XCTAssertEqual(Array(rom[(rom.count - 16)..<(rom.count - 10)]), [0xEA, 0x00, 0x00, 0x00, 0xF0, 0x00], "jmp F000:0000")
        XCTAssertEqual(rom[rom.count - 5], 0x01, "8 KB of SRAM")
    }

    func testRegistryResolvesTheRealCore() throws {
        let found = probe.interface
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "0.9.35.1 4b012958")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 60.38, accuracy: 0.01)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertNotNil(found.cheat_add)
        for ext in ["ws", "wsc", "pc2"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "beetle_wswan")
            XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "ws")
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "ws"), "beetle_wswan")
        XCTAssertEqual(CoreCatalog.platformName("ws"), "WonderSwan")
    }

    func testDrawsTheBandsWithNoBIOS() async throws {
        try await probe.load()
        probe.run(30)
        XCTAssertEqual(probe.size.width, 224)
        XCTAssertEqual(probe.size.height, 144)
        XCTAssertGreaterThanOrEqual(probe.colourCount, 4, "four greys")
        XCTAssertNil(probe.fatal)
    }

    func testEachButtonChangesThePicture() async throws {
        try await probe.load()
        // X pad on the D-pad, Y pad on R2 up, R1 right, L2 down, L1 left. RetroPad A is the console's A.
        probe.assertEachButtonChangesThePicture([GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                                 GAGA_BTN_R2, GAGA_BTN_R1, GAGA_BTN_L2, GAGA_BTN_L1,
                                                 GAGA_BTN_START, GAGA_BTN_EAST, GAGA_BTN_SOUTH])
    }

    /// Select is not a console key: the core uses it to turn a vertical game upright.
    func testSelectTurnsThePictureUpright() async throws {
        try await probe.load()
        probe.run(3, buttons: GAGA_BTN_SELECT)
        probe.run(3)
        XCTAssertEqual(probe.size.width, 144)
        XCTAssertEqual(probe.size.height, 224)
    }

    func testAudioIsNotSilent() async throws {
        try await probe.load()
        probe.assertAudioIsNotSilent()
    }

    func testSRAMBootCounterSurvivesRestarts() async throws {
        try await probe.assertBootCounterSurvivesRestarts(magic: WSTestROM.sramMagic, magicOffset: WSTestROM.sramMagicOffset,
                                                          counterOffset: WSTestROM.sramCounterOffset)
        XCTAssertEqual(try probe.battery().count, 8192)
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        try await probe.load()
        try probe.assertMednafenStateVersion()
        try probe.assertStateRoundTripAndRefusal(chord: [GAGA_BTN_EAST, GAGA_BTN_SOUTH])
    }

    func testRawRAMCheatHasItsEffectAndStops() async throws {
        try await probe.load()
        try probe.assertCheatHasItsEffectAndStops(WSTestROM.cheatCode,
                                                  refused: ["1F0010:01", "10000:01", "0010:1", "ZZ:01", "", "0010:01:02"])
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await probe.assertNoGeneratedCode(buttons: GAGA_BTN_EAST)
    }

    func testAFileThatIsNotACartridgeIsRefused() async throws {
        try await probe.assertRefused([("empty.wsc", Data()), ("short.wsc", Data(count: 0xFFFF))],
                                      message: "This file is not a WonderSwan game.")
    }

    func testThePadStartsOnTheXYPadLayout() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "ws"), "xy-pad")
        let masks = TouchSkinEngine.Layout.xyPad.buttons.map(\.mask)
        for mask in [ControllerManager.Button.r2, ControllerManager.Button.l2, ControllerManager.Button.l1,
                     ControllerManager.Button.r1, ControllerManager.Button.east, ControllerManager.Button.south,
                     ControllerManager.Button.start, ControllerManager.Button.select] {
            XCTAssertTrue(masks.contains(mask), "mask \(mask)")
        }
        XCTAssertEqual(TouchSkinEngine.Layout.choices(for: "nes").map(\.id).contains("xy-pad"), false)
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        LibretroProbe.assertUploadsPick("beetle_wswan", platforms: ["ws": "ws", "wsc": "ws", "pc2": "ws"])
    }

    @MainActor
    func testBenchmarkWritesATestCartridge() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "ws", to: probe.directory).pathExtension, "wsc")
    }
}
