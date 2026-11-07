import XCTest
@testable import GagaEmu

/// PrBoom with the generated IWAD (`DoomTestWAD`): no id Software or Freedoom data. The title page shows from the
/// first frame; Start, then A twice (New Game, then the default skill) puts the player in MAP01.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class PrboomCoreTests: XCTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("prboom"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("prboom-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "prboom", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.wad")
        try DoomTestWAD.wad().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    /// From the title page into MAP01 through the menu, as a player would; then lets the screen wipe finish. A
    /// press on the very first frames is lost, so the title gets half a second first.
    private func enterGame(_ core: GagaCoreWrapper) {
        kit.run(core, frames: 30)
        for button in [GAGA_BTN_START, GAGA_BTN_EAST, GAGA_BTN_EAST] {
            kit.run(core, frames: 6, buttons: UInt32(button.rawValue))
            kit.run(core, frames: 14)
        }
        kit.run(core, frames: 120)
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "2.5.0 4849268e", extensions: ["wad"], platforms: ["doom"])
        XCTAssertEqual(kit.interface.target_fps, 60.0, accuracy: 0.01)
        XCTAssertEqual(kit.interface.native_sample_rate, 48000)
    }

    func testTitleThenEachMoveChangesTheView() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 60)
        XCTAssertEqual(capture.width, 320)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        XCTAssertTrue(capture.centre == DoomTestWAD.colour(DoomTestWAD.titleIndex), "TITLEPIC: \(capture.centre)")
        enterGame(core)
        XCTAssertGreaterThan(capture.sampledColours, 8, "MAP01's walls, floor and ceiling")
        // Classic RetroPad: the pad walks and turns, L1 and R1 strafe.
        for button in [GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT, GAGA_BTN_L1, GAGA_BTN_R1] {
            kit.run(core, frames: 120) // Doom's momentum and view bob die away.
            let still = capture.pixels
            kit.run(core, frames: 6)
            XCTAssertEqual(capture.pixels, still, "no input, no change before \(button)")
            kit.run(core, frames: 6, buttons: UInt32(button.rawValue))
            XCTAssertNotEqual(capture.pixels, still, "\(button) moves the view")
        }
        core.stop()
    }

    /// Fire (RetroPad X, North) plays DSPISTOL, the only sound in the WAD; there is no music.
    func testFiringPlaysTheSound() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        enterGame(core)
        kit.run(core, frames: 40)
        capture.left.removeAll()
        kit.run(core, frames: 30)
        XCTAssertEqual(RetroCoreTestKit.loudness(capture.left), 0, "silent until something happens")
        capture.left.removeAll()
        kit.run(core, frames: 6, buttons: UInt32(GAGA_BTN_NORTH.rawValue))
        kit.run(core, frames: 24)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.left.count, 30 * 800, accuracy: 800)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        // Bytes after the lump directory are ignored by the engine but make another game.
        let otherROM = kit.directory.appendingPathComponent("other.wad")
        try (DoomTestWAD.wad() + [0x55]).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame == 2 ? UInt32(GAGA_BTN_START.rawValue) : frame % 5 == 0 ? UInt32(GAGA_BTN_DOWN.rawValue) : 0
        }
    }

    func testDamagedStateIsRefusedAndTheGameRuns() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        enterGame(core)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of PrBoom's own payload.
        XCTAssertThrowsError(try core.loadState(state)) {
            XCTAssertEqual($0.localizedDescription, "PrBoom could not load this save state.")
        }
        XCTAssertNil(capture.fatal)
        kit.run(core, frames: 40)
        let still = capture.pixels
        kit.run(core, frames: 6, buttons: UInt32(GAGA_BTN_LEFT.rawValue))
        XCTAssertNotEqual(capture.pixels, still)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: romPath)
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        kit.assertUploadsPick([("wad", "doom")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "doom", to: kit.directory).pathExtension, "wad")
    }
}
