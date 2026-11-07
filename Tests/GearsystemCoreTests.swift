import XCTest
@testable import GagaEmu

/// Gearsystem (Master System, Game Gear, SG-1000) with the generated homebrew ROM (`SMSTestROM`).
/// Device-pending: checked on a macOS host harness, not yet run on the iPhone.
final class GearsystemCoreTests: GagaTestCase {
    private var kit: RetroCoreTestKit!
    private var romPath: String!

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("gearsystem"), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gearsystem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        kit = RetroCoreTestKit(coreID: "gearsystem", directory: directory)
        let rom = directory.appendingPathComponent("homebrew.sms")
        try SMSTestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let kit { try? FileManager.default.removeItem(at: kit.directory) }
    }

    /// CRAM --BBGGRR to what Gearsystem draws: each 2-bit level spread over 8 bits, as RGB565 keeps it.
    private func expected(_ cram: UInt8) -> (r: Int, g: Int, b: Int) {
        let five = [0, 10, 21, 31], six = [0, 21, 42, 63]
        return (five[Int(cram & 3)] << 3, six[Int(cram >> 2 & 3)] << 2, five[Int(cram >> 4 & 3)] << 3)
    }

    func testRegistryResolvesTheRealCore() throws {
        try kit.assertRegistry(version: "3.9.24 40b8eeba", extensions: ["sms", "gg", "sg"],
                               platforms: ["mastersystem", "gamegear", "sg1000"])
        XCTAssertEqual(kit.interface.target_fps, 59.9227, accuracy: 0.001)
        XCTAssertEqual(kit.interface.native_sample_rate, 44100)
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "sms"), "mastersystem")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "gg"), "gamegear")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "sg"), "sg1000")
    }

    func testDrawsTheProgramsColourAndEachButtonChangesIt() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 20)
        XCTAssertEqual(capture.width, 256)
        XCTAssertEqual(capture.height, 192)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.sampledColours, 1)
        XCTAssertTrue(capture.centre == expected(SMSTestROM.color(joypad: 0xFF)), "\(capture.centre)")
        // Port 0xDC order. Button 1 is the bridge's SOUTH (RetroPad B), button 2 its EAST (RetroPad A).
        let order: [GagaButtonMask] = [GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT, GAGA_BTN_SOUTH, GAGA_BTN_EAST]
        for (bit, button) in order.enumerated() {
            kit.run(core, frames: 3, buttons: UInt32(button.rawValue))
            let want = expected(SMSTestROM.color(joypad: ~UInt8(1 << bit)))
            XCTAssertTrue(capture.centre == want, "bit \(bit): \(capture.centre) not \(want)")
        }
        kit.run(core, frames: 3)
        XCTAssertTrue(capture.centre == expected(SMSTestROM.color(joypad: 0xFF)))
        core.stop()
    }

    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertGreaterThan(RetroCoreTestKit.loudness(capture.left), 2000, "not silent")
        XCTAssertEqual(RetroCoreTestKit.hertz(capture.left, rate: 44100), SMSTestROM.toneHertz, accuracy: SMSTestROM.toneHertz * 0.05)
        core.stop()
    }

    func testBatteryRAMReachesItsFileAndSurvivesARestart() async throws {
        let save = kit.directory.appendingPathComponent("homebrew.sav")
        var last: UInt8?
        for _ in 1...3 {
            let (core, _) = try await kit.loaded(path: romPath)
            kit.run(core, frames: 12)
            core.flushBatterySave()
            let bytes = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(bytes.count, 0x8000)
            XCTAssertEqual(Array(bytes[0..<4]), SMSTestROM.sramMagic)
            let counter = bytes[SMSTestROM.sramBootCounterOffset]
            if let last { XCTAssertEqual(counter, last &+ 1, "one boot later") }
            last = counter
            core.stop()
        }
    }

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 2)
        let state = [UInt8](try core.saveState())
        // Upstream ends its state with GS_SaveState_Header_Libretro: magic 0x03121220, then the version.
        let tail = Array(state.suffix(8))
        XCTAssertEqual(Array(tail[0..<4]), [0x20, 0x12, 0x12, 0x03])
        XCTAssertEqual(UInt32(tail[4]) | UInt32(tail[5]) << 8, core.stateVersion)
        core.stop()
    }

    func testStatesRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](SMSTestROM.build())
        other[other.count - 1] = 0x55
        let otherROM = kit.directory.appendingPathComponent("other.sms")
        try Data(other).write(to: otherROM)
        try await kit.assertStates(romPath: romPath, otherROMPath: otherROM.path) { frame in
            frame % 5 == 0 ? UInt32(GAGA_BTN_UP.rawValue) : frame % 3 == 0 ? UInt32(GAGA_BTN_SOUTH.rawValue) : 0
        }
    }

    func testCheatsWriteMemoryAndBadCodesAreRefused() async throws {
        let (core, _) = try await kit.loaded(path: romPath)
        kit.run(core, frames: 10)
        try core.addCheat(id: 1, code: "00C000:42", enabled: true) // Pro Action Replay, address 0xC000.
        try core.addCheat(id: 2, code: "00C00042", enabled: true)
        try core.addCheat(id: 3, code: "3E8-0C7", enabled: true)    // Game Genie form.
        for bad in ["ZZZZZZZZ", "00C000-42", "12-345"] {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: bad, enabled: true)) {
                XCTAssertEqual($0.localizedDescription, "Gearsystem does not recognise this code: \(bad)")
            }
        }
        kit.run(core, frames: 3)
        core.removeCheat(id: 1)
        core.removeCheat(id: 2)
        core.removeCheat(id: 3)
        kit.run(core, frames: 3)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        try await kit.assertNoGeneratedCode(romPath: romPath)
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        await kit.assertUploadsPick([("sms", "mastersystem"), ("gg", "gamegear"), ("sg", "sg1000")])
    }

    @MainActor
    func testBenchmarkTestROMIsGenerated() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "mastersystem", to: kit.directory).pathExtension, "sms")
    }
}
