import XCTest
@testable import GagaEmu

/// Handy (Atari Lynx) with the generated homebrew program (`LynxTestROM`), run without a boot ROM. The program uses
/// no cart EEPROM, and upstream's libretro target has no cheats, so neither is tested.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class HandyCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("handy"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("handy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "handy", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.lnx")
        try LynxTestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "0.97 bc55d462", extensions: ["lnx"], platforms: ["lynx"])
        XCTAssertEqual(kit.interface.native_sample_rate, 48000)
    }

    func testDrawsTheBackgroundAndEachInputChangesIt() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 30)
        XCTAssertEqual(capture.width, 160)
        XCTAssertEqual(capture.height, 102)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.sampledColours, 1, "a zeroed framebuffer: the whole picture is palette entry 0")
        let rest = capture.centre
        XCTAssertTrue(rest == (80, 0, 80), "GREEN0 0, BLUERED0 0x55: \(rest)")
        // Lynx A is RetroPad A (EAST), Lynx B RetroPad B (SOUTH).
        var seen = [rest.r << 16 | rest.g << 8 | rest.b]
        for button in [GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT, GAGA_BTN_SOUTH, GAGA_BTN_EAST] {
            kit.run(core, frames: 4, buttons: UInt32(button.rawValue))
            let c = capture.centre
            let key = c.r << 16 | c.g << 8 | c.b
            XCTAssertFalse(seen.contains(key), "\(button) gives its own colour")
            seen.append(key)
            kit.run(core, frames: 4)
            XCTAssertTrue(capture.centre == rest)
        }
        core.stop()
    }

    func testAudioIsNotSilent() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.left.count, 120 * 800, accuracy: 900)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](LynxTestROM.build())
        other.append(0x55) // Past the header's size: same program, different file.
        let otherROM = kit.directory.appendingPathComponent("other.lnx")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    /// Upstream's ContextLoad returns success without loading anything when the "LSS3" tag is wrong, so a damaged
    /// tag is not reported. The game must keep running unchanged.
    func testDamagedStateTagLeavesTheGameAsItWas() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of Handy's "LSS3" tag.
        kit.run(core, frames: 4, buttons: UInt32(GAGA_BTN_UP.rawValue))
        let held = capture.centre
        try? core.loadState(state)
        kit.run(core, frames: 1, buttons: UInt32(GAGA_BTN_UP.rawValue))
        XCTAssertTrue(capture.centre == held)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: romPath)
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await kit.assertUploadsPick([("lnx", "lynx")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "lynx", to: kit.directory).pathExtension, "lnx")
    }
}
