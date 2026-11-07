import XCTest
@testable import GagaEmu

/// Beetle VB through the shared libretro adapter, running the generated cartridge (`VBTestROM`).
/// Device pending: built and checked on a macOS host harness, not yet run on a device (docs/07 8.3).
final class BeetleVbCoreTests: GagaTestCase {
    private var probe: LibretroProbe!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_vb"), "GAGA_CORE_SET left this core out")
        probe = try LibretroProbe(coreID: "beetle_vb", rom: VBTestROM.build(), name: "homebrew.vb")
    }

    override func tearDownWithError() throws { probe?.cleanUp() }

    func testTheGeneratedCartridgeEntersAtTheTopOfROM() {
        let rom = [UInt8](VBTestROM.build())
        XCTAssertEqual(rom.count, VBTestROM.size)
        // movhi 0x0700, r0, r1 at the reset entry, 16 bytes from the end.
        XCTAssertEqual(Array(rom[(rom.count - 16)..<(rom.count - 12)]), [0x20, 0xBC, 0x00, 0x07])
    }

    func testRegistryResolvesTheRealCore() throws {
        let found = probe.interface
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.31.0 d5ae54c8")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 50.27, accuracy: 0.001)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertNil(found.cheat_add, "upstream has no cheats, so the menu row hides")
        for ext in ["vb", "vboy"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "beetle_vb")
            XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "vb")
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "vb"), "beetle_vb")
        XCTAssertEqual(CoreCatalog.platformName("vb"), "Virtual Boy")
    }

    /// One eye, red on black, at the console's 384x224: no stereo mode doubles the picture.
    func testDrawsOneRedEyeWithNoBIOS() async throws {
        try await probe.load()
        probe.run(30)
        XCTAssertEqual(probe.size.width, 384)
        XCTAssertEqual(probe.size.height, 224)
        XCTAssertGreaterThanOrEqual(probe.colourCount, 4, "black and three shades of red")
        XCTAssertNil(probe.fatal)
    }

    func testEachButtonChangesThePicture() async throws {
        try await probe.load()
        // A, B, R, L, the right pad (L2 up, R3 right, R2 left, L3 down), the left pad, Start and Select.
        probe.assertEachButtonChangesThePicture([GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_R1, GAGA_BTN_L1,
                                                 GAGA_BTN_L2, GAGA_BTN_R3, GAGA_BTN_R2, GAGA_BTN_L3,
                                                 GAGA_BTN_UP, GAGA_BTN_RIGHT, GAGA_BTN_DOWN, GAGA_BTN_LEFT,
                                                 GAGA_BTN_START, GAGA_BTN_SELECT])
    }

    func testAudioIsNotSilent() async throws {
        try await probe.load()
        probe.assertAudioIsNotSilent()
    }

    func testCartridgeRAMBootCounterSurvivesRestarts() async throws {
        try await probe.assertBootCounterSurvivesRestarts(magic: VBTestROM.sramMagic, magicOffset: VBTestROM.sramMagicOffset,
                                                          counterOffset: VBTestROM.sramCounterOffset)
        XCTAssertEqual(try probe.battery().count, 65536)
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        try await probe.load()
        try probe.assertMednafenStateVersion()
        try probe.assertStateRoundTripAndRefusal(chord: [GAGA_BTN_EAST, GAGA_BTN_SOUTH])
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await probe.assertNoGeneratedCode(buttons: GAGA_BTN_EAST)
    }

    /// Upstream takes only a power-of-two image from 256 bytes to 16 MB.
    func testAFileThatIsNotACartridgeIsRefused() async throws {
        try await probe.assertRefused([("empty.vb", Data()), ("short.vb", Data(count: 128)), ("odd.vb", Data(count: 3000))],
                                      message: "This file is not a Virtual Boy game.")
    }

    func testThePadStartsOnTheTwinPadLayout() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "vb"), "twin-pad")
        let masks = TouchSkinEngine.Layout.twinPad.buttons.map(\.mask)
        for mask in [ControllerManager.Button.l2, ControllerManager.Button.l3, ControllerManager.Button.r2,
                     ControllerManager.Button.r3] {
            XCTAssertTrue(masks.contains(mask), "the right pad")
        }
        XCTAssertEqual(TouchSkinEngine.Layout.choices(for: "nes").map(\.id).contains("twin-pad"), false)
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await LibretroProbe.assertUploadsPick("beetle_vb", platforms: ["vb": "vb", "vboy": "vb"])
    }

    @MainActor
    func testBenchmarkWritesATestCartridge() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "vb", to: probe.directory).pathExtension, "vb")
    }
}
