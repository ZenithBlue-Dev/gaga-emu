import XCTest
@testable import GagaEmu

/// VICE x64sc (Commodore 64) with the generated Ultimax cartridge (`C64TestROM`). VICE will not start without
/// KERNAL, BASIC and character ROM files, so each test puts all-zero stand-ins (`C64TestROM.standInSystemFiles`) in
/// the system folder; the cartridge replaces the KERNAL, so they never run. No Commodore ROM is used.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class ViceCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("vice"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vice-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "vice", directory: directory)
        for file in C64TestROM.standInSystemFiles {
            try Data(count: file.size).write(to: directory.appendingPathComponent(file.name))
        }
        let rom = directory.appendingPathComponent("homebrew.crt")
        try C64TestROM.crt().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "3.10 5ebe7d33", extensions: ["d64", "t64", "prg", "crt", "tap"], platforms: ["c64"])
        XCTAssertEqual(kit.interface.target_fps, 50.12, accuracy: 0.01)
        XCTAssertEqual(kit.interface.native_sample_rate, 48000)
    }

    /// Upstream crashes without its ROM files, so the bridge refuses the game first and says what to add.
    func testMissingROMFilesGiveAMessageForThePlayer() async throws {
        try FileManager.default.removeItem(at: kit.directory.appendingPathComponent("kernal-901227-03.bin"))
        let (core, _) = try kit.makeCore()
        do {
            try await core.loadROM(path: romPath)
            XCTFail("loaded without a KERNAL")
        } catch {
            XCTAssertEqual(error.localizedDescription, "VICE needs the C64 KERNAL, BASIC and character ROMs. Add "
                           + "kernal-901227-03.bin, basic-901226-01.bin and chargen-901225-01.bin in BIOS Files.")
        }
        core.stop()
    }

    func testDrawsTheBorderAndEachInputChangesIt() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 100)
        XCTAssertEqual(capture.width, 384)
        XCTAssertEqual(capture.height, 272)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.sampledColours, 1, "screen blanked: the whole picture is the border")
        let rest = capture.centre
        XCTAssertTrue(rest == (80, 84, 80), "colour 11, dark grey: \(rest)")
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
    func testKeysReachTheC64Keyboard() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 100)
        let rest = capture.centre
        kit.run(core, frames: 4, keys: [0x04]) // HID A
        XCTAssertFalse(capture.centre == rest, "colour 3 while a key is down")
        kit.run(core, frames: 4)
        XCTAssertTrue(capture.centre == rest)
        core.stop()
    }

    func testAudioIsNotSilent() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 100)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.left.count, 100 * 958, accuracy: 1000)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](C64TestROM.crt())
        other[other.count - 0x100] = 0x55 // Unused cartridge bytes.
        let otherROM = kit.directory.appendingPathComponent("other.crt")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    func testDamagedStateBytesAreRefusedByVICE() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of VICE's snapshot magic.
        XCTAssertThrowsError(try core.loadState(state)) {
            XCTAssertEqual($0.localizedDescription, "VICE could not load this save state.")
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
        await kit.assertUploadsPick([("d64", "c64"), ("t64", "c64"), ("prg", "c64"), ("crt", "c64"), ("tap", "c64")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "c64", to: kit.directory).pathExtension, "crt")
    }
}
