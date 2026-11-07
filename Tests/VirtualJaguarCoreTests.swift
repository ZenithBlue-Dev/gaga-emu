import XCTest
@testable import GagaEmu

/// Virtual Jaguar (Atari Jaguar) with the generated homebrew cartridge (`JaguarTestROM`), booted by HLE with no boot
/// ROM. Heavy tier: the homebrew is trivial, so these tests say nothing about full-speed play of real games.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class VirtualJaguarCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("virtualjaguar"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("virtualjaguar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "virtualjaguar", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.j64")
        try JaguarTestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "3.11.0 34696082", extensions: ["j64", "jag"], platforms: ["jaguar"])
        XCTAssertEqual(kit.interface.target_fps, 60.05, accuracy: 0.01)
        XCTAssertEqual(kit.interface.native_sample_rate, 48044)
    }

    func testDrawsTheBackgroundAndEachInputChangesIt() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 30)
        XCTAssertEqual(capture.width, 326)
        XCTAssertEqual(capture.height, 240)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        XCTAssertNil(capture.fatal)
        let rest = capture.centre
        XCTAssertTrue(rest == (0, 64, 64), "BG with no input: \(rest)")
        // A is RetroPad SOUTH, B is EAST.
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
        XCTAssertEqual(capture.sampleRate, 48044)
        XCTAssertEqual(capture.left.count, 120 * 800, accuracy: 1000)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testEEPROMReachesItsFile() async throws {
        let (core, _) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        core.flushBatterySave()
        let save = kit.directory.appendingPathComponent("homebrew.sav")
        XCTAssertEqual(try Data(contentsOf: save).count, 128, "the cartridge's 128-byte serial EEPROM")
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](JaguarTestROM.build())
        other[0x10000] = 0x55
        let otherROM = kit.directory.appendingPathComponent("other.j64")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    func testDamagedStateBytesAreRefusedByVirtualJaguar() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of Virtual Jaguar's "SSJV" magic.
        XCTAssertThrowsError(try core.loadState(state)) {
            XCTAssertEqual($0.localizedDescription, "Virtual Jaguar could not load this save state.")
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
        await kit.assertUploadsPick([("j64", "jaguar"), ("jag", "jaguar")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "jaguar", to: kit.directory).pathExtension, "j64")
    }
}
