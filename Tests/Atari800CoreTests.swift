import XCTest
@testable import GagaEmu

/// Atari800 with the generated homebrew programs (`Atari800TestROM`): an 8-bit .xex and a 5200 .a52, both booted on
/// the bundled AltirraOS with no Atari ROM in the system folder. No battery memory or cheats upstream.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class Atari800CoreTests: XCTestCase {
    private var kit: RetroCoreTestKit!
    private var xexPath: String!
    private var a52Path: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("atari800"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("atari800-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "atari800", directory: directory)
        let xex = directory.appendingPathComponent("homebrew.xex"), a52 = directory.appendingPathComponent("homebrew.a52")
        try Atari800TestROM.xex().write(to: xex)
        try Atari800TestROM.a52().write(to: a52)
        (xexPath, a52Path) = (xex.path, a52.path)
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "7.0.0 4e7fbc73", extensions: ["a52", "xex", "atr", "xfd", "dcm", "atx"],
                               platforms: ["atari5200", "atari8bit"])
        XCTAssertEqual(kit.interface.native_sample_rate, 44100)
    }

    private func assertEachInputChangesThePicture(path: String, rest expected: (Int, Int, Int)) async throws {
        let (core, capture) = try await kit.loaded(path: path)
        kit.run(core, frames: 200) // AltirraOS boot and the binary load
        XCTAssertEqual(capture.width, 336)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.sampledColours, 1, "DMA off: the whole picture is COLBK")
        let rest = capture.centre
        XCTAssertTrue(rest == expected, "\(rest)")
        // Fire 1 is RetroPad B, the bridge's SOUTH.
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

    func testThe8BitProgramDrawsAndEachInputChangesIt() async throws {
        try await assertEachInputChangesThePicture(path: xexPath, rest: (48, 48, 48)) // COLBK $04
    }

    func testThe5200CartridgeDrawsAndEachInputChangesIt() async throws {
        try await assertEachInputChangesThePicture(path: a52Path, rest: (96, 16, 80)) // COLBK $44: stick centred
    }

    /// The keyboard reaches the core through GagaInputState.keys, as on DOS.
    func testKeysReachThe8BitKeyboard() async throws {
        let (core, capture) = try await kit.loaded(path: xexPath)
        kit.run(core, frames: 200)
        let rest = capture.centre
        kit.run(core, frames: 4, keys: [0x04]) // HID A
        let a = capture.centre
        kit.run(core, frames: 4)
        kit.run(core, frames: 4, keys: [0x1E]) // HID 1
        let one = capture.centre
        XCTAssertFalse(a == rest)
        XCTAssertFalse(one == rest)
        XCTAssertFalse(a == one, "COLBK is the key's KBCODE")
        core.stop()
    }

    func testAudioIsNotSilent() async throws {
        let (core, capture) = try await kit.loaded(path: xexPath)
        kit.run(core, frames: 240)
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(Array(capture.left.suffix(44100))), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](Atari800TestROM.a52())
        other[0x4000] = 0x55
        let otherROM = kit.directory.appendingPathComponent("other.a52")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: a52Path, otherROMPath: otherROM.path, warmup: 200) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    func testDamagedStateBytesAreRefusedByAtari800() async throws {
        let (core, capture) = try await kit.loaded(path: xexPath)
        kit.run(core, frames: 200)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of atari800's "ATARI800" state header.
        XCTAssertThrowsError(try core.loadState(state)) {
            XCTAssertEqual($0.localizedDescription, "Atari800 could not load this save state.")
        }
        kit.run(core, frames: 2)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: xexPath)
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        kit.assertUploadsPick([("a52", "atari5200"), ("xex", "atari8bit"), ("atr", "atari8bit")])
    }

    func testThe8BitPlatformTypes() {
        XCTAssertTrue(GameSession.typingPlatforms.contains("atari8bit"))
        XCTAssertFalse(GameSession.typingPlatforms.contains("atari5200"))
    }

    @MainActor
    func testBenchmarkTestROMsAreGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "atari5200", to: kit.directory).pathExtension, "a52")
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "atari8bit", to: kit.directory).pathExtension, "xex")
    }
}
