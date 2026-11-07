import XCTest
@testable import GagaEmu

/// Stella (Atari 2600) with the generated homebrew cartridge (`Atari2600TestROM`). The 2600 has no battery
/// memory and upstream's libretro target has no cheats, so neither is tested.
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class StellaCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("stella"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("stella-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "stella", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.a26")
        try Atari2600TestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "7.0c c4016ea4", extensions: ["a26"], platforms: ["atari2600"])
        XCTAssertEqual(kit.interface.native_sample_rate, 31440)
    }

    func testDrawsTheBackgroundAndEachInputChangesIt() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 40)
        XCTAssertEqual(capture.width, 160)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        XCTAssertNil(capture.fatal)
        let rest = capture.centre
        XCTAssertTrue(rest == (0x24, 0x28, 0xB0), "COLUBK 0x84 in Stella's NTSC palette: \(rest)")
        // Fire is RetroPad B, the bridge's SOUTH.
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

    func testAudioIsNotSilent() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 31440)
        XCTAssertEqual(capture.left.count, 120 * 524, accuracy: 600)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](Atari2600TestROM.build())
        other[0x800] = 0x55
        let otherROM = kit.directory.appendingPathComponent("other.a26")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame % 4 == 0 ? UInt32(GAGA_BTN_LEFT.rawValue) : frame % 7 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    func testDamagedStateBytesAreRefusedByStella() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        var state = try core.saveState()
        state[16] ^= 0xFF // The first byte of Stella's own header string.
        XCTAssertThrowsError(try core.loadState(state)) {
            XCTAssertEqual($0.localizedDescription, "Stella could not load this save state.")
        }
        kit.run(core, frames: 2)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: romPath)
    }

    /// A .bin is a 2600 image, a Mega Drive ROM or a disc, by content.
    func testBinFilesArePlacedByContent() throws {
        func place(_ name: String, _ data: Data) throws -> String? {
            let url = kit.directory.appendingPathComponent(name)
            try data.write(to: url)
            return CoreCatalog.platformID(forFile: url)
        }
        XCTAssertEqual(try place("vcs.bin", Atari2600TestROM.build()), "atari2600")
        var genesis = [UInt8](repeating: 0, count: 0x8000)
        genesis.replaceSubrange(0x100..<0x104, with: Array("SEGA".utf8))
        XCTAssertEqual(try place("md.bin", Data(genesis)), "megadrive", "a Sega header wins at any size")
        XCTAssertNil(try place("zeros.bin", Data(count: 4096)), "no 6507 reset vector, so it asks")
        XCTAssertNil(try place("odd.bin", Data(count: 3000)), "not whole 2 KB banks")
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await kit.assertUploadsPick([("a26", "atari2600")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "atari2600", to: kit.directory).pathExtension, "a26")
    }
}
