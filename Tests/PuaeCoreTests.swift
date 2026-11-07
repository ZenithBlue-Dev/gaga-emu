import XCTest
@testable import GagaEmu

/// PUAE (Amiga 500) with the generated bootable floppy (`AmigaTestROM`), booted on upstream's built-in AROS Kickstart
/// replacement: no Kickstart is in the system folder. AROS takes about 600 frames to reach the bootblock.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class PuaeCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!
    private let boot = 650

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("puae"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("puae-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "puae", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.adf")
        try AmigaTestROM.adf().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "5.3.1 c1d1d49d", extensions: ["adf", "hdf"], platforms: ["amiga"])
        XCTAssertEqual(kit.interface.target_fps, 50.0, accuracy: 0.01)
        XCTAssertEqual(kit.interface.native_sample_rate, 44100)
    }

    func testBootsOnAROSAndEachInputChangesTheColour() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: boot)
        XCTAssertEqual(capture.width, 720)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        let rest = capture.centre
        XCTAssertTrue(rest == (0, 68, 0), "COLOR00 $040: \(rest)")
        // Joystick port 2; fire is RetroPad B (SOUTH).
        var seen = [rest.r << 16 | rest.g << 8 | rest.b]
        for button in [GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT, GAGA_BTN_SOUTH] {
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

    /// The keyboard reaches the core through GagaInputState.keys, as on DOS.
    func testKeysReachTheAmigaKeyboard() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: boot)
        let rest = capture.centre
        kit.run(core, frames: 6, keys: [0x04]) // HID A
        XCTAssertFalse(capture.centre == rest, "COLOR00 bit 11 while a key is down")
        kit.run(core, frames: 6)
        XCTAssertTrue(capture.centre == rest)
        core.stop()
    }

    func testAudioIsNotSilent() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: boot)
        capture.left.removeAll()
        kit.run(core, frames: 50)
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertEqual(capture.left.count, 50 * 882, accuracy: 900)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](AmigaTestROM.adf())
        other[0x2000] = 0x55 // Past the bootblock.
        let otherROM = kit.directory.appendingPathComponent("other.adf")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path, warmup: boot) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    /// Upstream's retro_unserialize defers the restore to the next frame and always reports success, so a damaged
    /// state is not refused. The game must keep running and still answer its inputs.
    func testDamagedStateLeavesTheGameRunning() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: boot)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of UAE's "ASF " header.
        try? core.loadState(state)
        kit.run(core, frames: boot)
        XCTAssertNil(capture.fatal)
        let rest = capture.centre
        kit.run(core, frames: 4, buttons: UInt32(GAGA_BTN_UP.rawValue))
        XCTAssertFalse(capture.centre == rest)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: romPath)
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await kit.assertUploadsPick([("adf", "amiga"), ("hdf", "amiga")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "amiga", to: kit.directory).pathExtension, "adf")
    }
}
