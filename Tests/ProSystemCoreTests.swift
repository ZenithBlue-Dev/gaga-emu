import XCTest
@testable import GagaEmu

/// ProSystem (Atari 7800) with the generated homebrew cartridge (`Atari7800TestROM`), booted without a BIOS. The
/// 7800 has no battery memory and upstream's libretro target has no cheats, so neither is tested.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class ProSystemCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("prosystem"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("prosystem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "prosystem", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.a78")
        try Atari7800TestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "1.3e 8a880142", extensions: ["a78"], platforms: ["atari7800"])
        XCTAssertEqual(kit.interface.native_sample_rate, 31440)
    }

    func testDrawsTheBackgroundAndEachInputChangesIt() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 30)
        XCTAssertEqual(capture.width, 320)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.sampledColours, 1, "empty display lists: the whole picture is BACKGRND")
        let rest = capture.centre
        XCTAssertTrue(rest == (80, 80, 80), "BACKGRND 0x04, grey in ProSystem's palette: \(rest)")
        // Button 1 is RetroPad B (SOUTH), button 2 RetroPad A (EAST).
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
        XCTAssertEqual(capture.sampleRate, 31440)
        XCTAssertEqual(capture.left.count, 120 * 524, accuracy: 600)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](Atari7800TestROM.build())
        other[128 + 0x4000] = 0x55
        let otherROM = kit.directory.appendingPathComponent("other.a78")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    func testDamagedStateBytesAreRefusedByProSystem() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of ProSystem's "PRO-SYSTEM STATE" header.
        XCTAssertThrowsError(try core.loadState(state)) {
            XCTAssertEqual($0.localizedDescription, "ProSystem could not load this save state.")
        }
        kit.run(core, frames: 2)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: romPath)
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await kit.assertUploadsPick([("a78", "atari7800")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "atari7800", to: kit.directory).pathExtension, "a78")
    }
}
