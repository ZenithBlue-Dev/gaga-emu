import XCTest
@testable import GagaEmu

/// Gambatte through the shared libretro adapter and the real bridge, running the generated homebrew ROM
/// (`GBTestROM`). Also the adapter's tests: a later libretro core copies this file.
final class GambatteCoreTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("gambatte")!.pointee

    /// Upstream's "GBC - Grayscale" palette, in 5 bits per channel, in the order the program's BGP selects.
    private static let greys: [UInt16] = [31, 20, 10, 0]
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("gambatte"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("gambatte-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.gb")
        try GBTestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// The last frame's bytes and the audio so far. Only touched inside `step`, which is a queue barrier.
    private final class Capture {
        var pixels: [UInt8] = []
        var width = 0
        var height = 0
        var pitch = 0
        var format = GagaPixelFormat(rawValue: 99)
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var channels: UInt8 = 0
        var fatal: String?

        /// RGB565, little endian, with green cut to 5 bits like the others.
        func pixel(x: Int, y: Int) -> (r: UInt16, g: UInt16, b: UInt16) {
            let i = y * pitch + x * 2
            let value = UInt16(pixels[i]) | UInt16(pixels[i + 1]) << 8
            return (value >> 11, (value >> 6) & 0x1F, value & 0x1F)
        }
    }

    private func makeCore(saveDirectory: String? = nil) throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: saveDirectory ?? directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            capture.width = frame.width
            capture.height = frame.height
            capture.pitch = frame.pitch
            capture.format = frame.pixelFormat
            guard let bytes = frame.pixelData else { return }
            capture.pixels = Array(UnsafeRawBufferPointer(start: bytes, count: frame.pitch * frame.height))
        }
        core.onAudioPacket = { packet in
            capture.sampleRate = packet.sampleRate
            capture.channels = packet.channels
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) {
                capture.left.append(packet.samples[index])
            }
        }
        core.onEvent = { event in
            if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message }
        }
        return (core, capture)
    }

    private func loaded(path: String? = nil) async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: path ?? romPath)
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, genie: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        var wrong = 0
        for y in 0..<GBTestROM.height {
            for x in 0..<GBTestROM.width {
                let want = Self.greys[GBTestROM.expectedShade(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, genie: genie)]
                let got = capture.pixel(x: x, y: y)
                if got.r != want || got.g != want || got.b != want { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture", file: file, line: line)
    }

    private let chord = UInt32(GAGA_BTN_EAST.rawValue | GAGA_BTN_SOUTH.rawValue)

    /// Press and release A and B, then leave frames for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    // MARK: - ROM generator

    func testGeneratedHeaderChecks() {
        let rom = [UInt8](GBTestROM.build())
        XCTAssertEqual(rom.count, 0x8000)
        XCTAssertEqual(rom[0x14D], GBTestROM.headerChecksum(rom))
        XCTAssertEqual(rom[0x134...0x14D].reduce(UInt8(0x19)) { $0 &+ $1 }, 0, "header complement")
        XCTAssertTrue(rom[0x104..<0x134].allSatisfy { $0 == 0 }, "no Nintendo logo in the ROM")
        XCTAssertEqual(rom[0x147], 0x03, "battery RAM")
        let sum = rom.enumerated().reduce(UInt16(0)) { $1.offset == 0x14E || $1.offset == 0x14F ? $0 : $0 &+ UInt16($1.element) }
        XCTAssertEqual(sum, UInt16(rom[0x14E]) << 8 | UInt16(rom[0x14F]), "global checksum")
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("gambatte")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "0.5.0 77f2567d")
        XCTAssertEqual(found.native_sample_rate, 32768)
        XCTAssertEqual(found.target_fps, 59.7275, accuracy: 0.001)
        for ext in ["gb", "gbc"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "gambatte")
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "gb"), "gambatte")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "gbc"), "gambatte")
    }

    func testLoadsWithNoBootROMAndDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.width, 160)
        XCTAssertEqual(capture.height, 144)
        XCTAssertEqual(capture.pitch, 512, "the core's own 256 pixel pitch")
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        core.stop()
    }

    func testAColorCartridgeRunsInColor() async throws {
        let rom = directory.appendingPathComponent("homebrew.gbc")
        try GBTestROM.build(color: true).write(to: rom)
        let (core, capture) = try await loaded(path: rom.path)
        run(core, frames: 12)
        let bands = [capture.pixel(x: 80, y: 0), capture.pixel(x: 80, y: 40), capture.pixel(x: 80, y: 72), capture.pixel(x: 80, y: 120)]
        // Colour correction moves the values, so only which channel leads is exact.
        XCTAssertTrue(bands[0].r > bands[0].g && bands[0].r > bands[0].b, "red band: \(bands[0])")
        XCTAssertTrue(bands[1].g > bands[1].r && bands[1].g > bands[1].b, "green band: \(bands[1])")
        XCTAssertTrue(bands[2].b > bands[2].r && bands[2].b > bands[2].g, "blue band: \(bands[2])")
        XCTAssertGreaterThan(bands[3].r, 26, "white band: \(bands[3])")
        XCTAssertGreaterThan(bands[3].g, 26, "white band: \(bands[3])")
        XCTAssertGreaterThan(bands[3].b, 26, "white band: \(bands[3])")
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        // Joypad order. Touch A is the bridge's EAST, and B is its SOUTH.
        let order: [GagaButtonMask] = [GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_SELECT, GAGA_BTN_START,
                                       GAGA_BTN_RIGHT, GAGA_BTN_LEFT, GAGA_BTN_UP, GAGA_BTN_DOWN]
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 32768)
        XCTAssertEqual(capture.channels, 2)
        // About 549 samples per frame, within a packet of rounding.
        XCTAssertEqual(capture.left.count, 120 * 32768 * 70224 / 4194304, accuracy: 1100)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(tone.max()! - tone.min()!, 500, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 32768)
        XCTAssertEqual(hertz, GBTestROM.toneHertz, accuracy: GBTestROM.toneHertz * 0.05)
        core.stop()
    }

    func testTimerDrivesFramesAndPauseStopsThem() async throws {
        let (core, _) = try await loaded()
        core.start()
        try await Task.sleep(for: .milliseconds(500))
        let running = core.stats.frames
        XCTAssertGreaterThan(running, 15)
        XCTAssertLessThan(running, 40, "the host timer sets the pace, not the core")
        core.pause()
        let paused = core.stats.frames
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(core.stats.frames, paused)
        core.resume()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertGreaterThan(core.stats.frames, paused)
        core.stop()
    }

    func testStepFrameIsSafeSeveralTimesPerTick() async throws {
        let (core, _) = try makeCore()
        final class Counts { var video = 0, audio = 0 }
        let counts = Counts()
        core.onVideoFrame = { _ in counts.video += 1 }
        core.onAudioPacket = { _ in counts.audio += 1 }
        try await core.loadROM(path: romPath)
        core.setSpeed(4)
        core.start()
        try await Task.sleep(for: .milliseconds(500))
        core.pause()
        let frames = core.stats.frames
        XCTAssertGreaterThan(frames, 60, "faster than the 30 frames normal speed gives in this time")
        // Not an exact division: a frame the core marks as a repeat reaches nobody.
        XCTAssertEqual(Double(frames) / Double(counts.video), 4, accuracy: 0.3, "only the last frame of a tick is drawn")
        XCTAssertEqual(counts.audio, 0)
        core.stop()
    }

    // MARK: - Lifecycle

    func testSessionPerLaunchIsFreshEachTime() async throws {
        for _ in 0..<10 {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture)
            core.stop()
        }
    }

    /// libretro's callbacks have no userdata, so a second instance would run on the first one's globals.
    func testASecondLiveInstanceIsRefusedAndTheFirstKeepsRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertThrowsError(try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)) {
            XCTAssertEqual($0.localizedDescription, "The emulator core could not start.")
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
        let (again, againCapture) = try await loaded()
        run(again, frames: 12)
        assertPicture(againCapture)
        again.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_EAST.rawValue))
        core.stop()
        XCTAssertEqual(capture.width, 160)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let empty = directory.appendingPathComponent("empty.gb")
        try Data().write(to: empty)
        let short = directory.appendingPathComponent("short.gb")
        try Data(repeating: 0, count: 0x100).write(to: short)
        let noise = directory.appendingPathComponent("noise.gb")
        try Data((0..<0x8000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        var damaged = [UInt8](GBTestROM.build())
        damaged[0x134] ^= 1
        let badHeader = directory.appendingPathComponent("damaged.gb")
        try Data(damaged).write(to: badHeader)

        let notAGame = "This file is not a Game Boy or Game Boy Color game."
        let cases = [(empty.path, notAGame), (short.path, notAGame), (noise.path, notAGame), (badHeader.path, notAGame),
                     (directory.appendingPathComponent("gone.gb").path, "The game file could not be opened.")]
        for (path, message) in cases {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, message)
            }
            core.stop()
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("noise.sav").path),
                       "a refused file must not leave a save behind")
    }

    func testAnUnwritableSaveFolderRefusesToRun() async throws {
        let (core, _) = try makeCore(saveDirectory: "/nonexistent/saves")
        do {
            try await core.loadROM(path: romPath)
            XCTFail("loaded with no way to save")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The save file for this game could not be opened.")
        }
        core.stop()
    }

    // MARK: - Battery saves

    func testBatterySaveReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, GBTestROM.cartRAMSize)
            XCTAssertEqual(Array(flushed[0..<4]), GBTestROM.sramMagic)
            XCTAssertEqual(Int(flushed[GBTestROM.sramBootCounterOffset]), boot, "on disk when the flush returns")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[GBTestROM.sramBootCounterOffset]), boot)
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [])
    }

    /// Progress must not depend on the player pausing: a crash would lose everything since the last pause.
    func testPlayingFlushesWithoutAPause() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let (core, _) = try await loaded()
        run(core, frames: 12)
        let first = [UInt8](try Data(contentsOf: save))
        XCTAssertNotEqual(Array(first[0..<4]), GBTestROM.sramMagic, "created at load, before the program ran")
        run(core, frames: 300)
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: save))[0..<4]), GBTestROM.sramMagic)
        core.stop()
    }

    func testASaveThatDoesNotFitIsNeverOverwritten() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let foreign = Data(repeating: 0xAB, count: 1024)
        try foreign.write(to: save)
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: romPath)
            XCTFail("loaded over another game's save")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The save file for this game could not be opened.")
        }
        core.stop()
        XCTAssertEqual(try Data(contentsOf: save), foreign)
    }

    func testAFailedSaveWriteTellsThePlayer() async throws {
        let folder = directory.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let (core, capture) = try makeCore(saveDirectory: folder.path)
        try await core.loadROM(path: romPath)
        chmod(folder.path, 0o555)
        defer { chmod(folder.path, 0o755) }
        run(core, frames: 12)
        core.flushBatterySave()
        XCTAssertEqual(capture.fatal, "The save file for this game could not be written.")
        chmod(folder.path, 0o755)
        core.flushBatterySave()
        core.stop()
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: folder.appendingPathComponent("homebrew.sav")))[0..<4]), GBTestROM.sramMagic,
                       "the next flush still tries")
    }

    // MARK: - Save states

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(state[Self.headerSize], 0, "the first byte of Gambatte's format")
        XCTAssertEqual(UInt32(state[Self.headerSize + 1]), core.stateVersion)
        core.stop()
    }

    func testRoundTripPlaysBackExactlyAndRestoresTheCPU() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        assertPicture(capture, toggle: true)
        let state = try core.saveState()

        // The same scripted input from the same state must give the same frames, byte for byte.
        func script() -> [[UInt8]] {
            (0..<30).map { frame in
                run(core, frames: 1, buttons: frame == 15 ? chord : frame % 7 == 0 ? UInt32(GAGA_BTN_START.rawValue) : 0)
                return capture.pixels
            }
        }
        let first = script()
        run(core, frames: 3)
        assertPicture(capture, toggle: false)
        try core.loadState(state)
        let second = script()
        XCTAssertEqual(first, second)

        // The flag is only in register E, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](GBTestROM.build())
        other[other.count - 1] = 0x55
        let otherROM = directory.appendingPathComponent("other.gb")
        try Data(other).write(to: otherROM)
        let (foreign, _) = try await loaded(path: otherROM.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for Gambatte."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var wrongVersion = state // Past the adapter's checks: Gambatte itself must refuse this one.
        wrongVersion[Self.headerSize] ^= 0xFF
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (Data(repeating: 0, count: 4096), wrongSize),
            (wrongVersion, "Gambatte could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertPicture(capture, toggle: true)
        }
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    /// Bad bytes that pass the size and ROM checks, with no wrapper to undo them: the adapter alone keeps the
    /// game unchanged, because Gambatte writes memory as it parses and only then finds the state is bad.
    func testACoreThatFailsPartWayIsPutBackByTheAdapter() throws {
        let inst = try XCTUnwrap(interface.create(directory.path, directory.path))
        defer { interface.destroy(inst) }
        XCTAssertTrue(interface.load_rom(inst, romPath, nil, 0))
        var inputs = [GagaInputState](repeating: GagaInputState(), count: 4)
        func capture() -> [UInt8] {
            let size = interface.state_size(inst)
            var bytes = [UInt8](repeating: 0, count: size)
            XCTAssertTrue(interface.save_state(inst, &bytes, size))
            return bytes
        }
        interface.step_frame(inst, &inputs, 4)
        // An earlier moment, so what the core applies before it fails is not what it already holds.
        var bad = capture()
        for index in (bad.count / 2)..<bad.count { bad[index] = 0xFF }
        for _ in 0..<12 { interface.step_frame(inst, &inputs, 4) }
        let before = capture()
        func changedBytes() -> Int { zip(capture(), before).filter { $0 != $1 }.count }
        let noise = changedBytes() // Upstream saves a few fields it never set, so two saves differ slightly.

        var error = [CChar](repeating: 0, count: 128)
        XCTAssertFalse(interface.load_state(inst, bad, bad.count, &error, error.count), "Gambatte took these bytes")
        XCTAssertEqual(String(cString: error), "Gambatte could not load this save state.")
        XCTAssertLessThan(changedBytes(), noise + 24)
    }

    // MARK: - Cheats

    /// GameShark 01VVLLHH: write VV to HHLL at each VBlank. Game Genie: VVA-LLT, with T the top nibble inverted.
    private let shark = "010100C0" // Write 1 to 0xC000.
    private let genie = "014-00F" // Write 1 to ROM 0x0400.

    func testCheatFormatsHaveTheirEffectAndStop() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        assertPicture(capture)

        try core.addCheat(id: 1, code: shark, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.setCheat(id: 1, enabled: false)
        run(core, frames: 3)
        assertPicture(capture)
        core.setCheat(id: 1, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.removeCheat(id: 1)
        run(core, frames: 3)
        assertPicture(capture)

        try core.addCheat(id: 2, code: genie, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, genie: true)
        core.setCheat(id: 2, enabled: false)
        run(core, frames: 3)
        assertPicture(capture)

        // Several lines, in both formats, are one cheat.
        try core.addCheat(id: 3, code: " \(shark.lowercased()) \n\n\(genie)\n", enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true, genie: true)
        try core.addCheat(id: 3, code: genie, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, genie: true)
        core.stop()

        let (next, nextCapture) = try await loaded()
        run(next, frames: 12)
        assertPicture(nextCapture)
        next.stop()
    }

    func testBadCodesAreRefusedAndAddNothing() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        let cases = [("", "Enter a cheat code."), (" \n ", "Enter a cheat code."),
                     ("ZZZZZZZZ", "Gambatte does not recognise this code: ZZZZZZZZ"),
                     ("910100C0", "Gambatte does not recognise this code: 910100C0"),
                     ("012-00", "Gambatte does not recognise this code: 012-00"),
                     ("\(shark)\nnope", "Gambatte does not recognise this code: nope")]
        for (code, message) in cases {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: code, enabled: true)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved }
        for ext in ["gb", "gbc"] {
            let name = "upload-\(UUID().uuidString).\(ext)"
            state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, ext)
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "gambatte")
        }
    }

    // MARK: - Debug launch arguments

    /// `-GagaBenchmarkCore gambatte` with no ROM: the generated GB ROM and a record named for this core.
    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "gb", to: directory)
        XCTAssertEqual(rom.pathExtension, "gb")
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "gb", romPath: rom.path, coverPath: nil,
                            coreOverride: "gambatte", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let session = try GameSession(game: game, interface: interface, romPath: rom.path, audio: AudioEngineManager(),
                                      controllers: controllers, skins: skins, bindings: [], shaderID: "original",
                                      respectSilentMode: false)
        try await session.prepare()
        let run = BenchmarkRun(session: session, interface: interface, romURL: rom, seconds: 2, warmup: 0.2)
        run.attach()
        var written: URL?
        run.onWritten = { written = $0 }
        session.run()
        await run.drive()

        let url = try XCTUnwrap(written)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(url.lastPathComponent.hasPrefix("gambatte-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "gambatte")
        XCTAssertEqual((record["core"] as? [String: Any])?["settings"] as? String, "defaults")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    @MainActor
    func testBenchmarkTestROMFollowsThePlatform() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "gbc", to: directory).pathExtension, "gbc")
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "gba", to: directory).pathExtension, "gba")
        XCTAssertThrowsError(try BenchmarkRun.writeTestROM(platformID: "nes", to: directory)) {
            XCTAssertEqual($0.localizedDescription, "No test ROM is generated for nes. Pass -GagaBenchmarkROM.")
        }
    }

    /// `-GagaImportROM <path>`: copied into the ROM folder, added once however often the app relaunches.
    @MainActor
    func testDebugImportAddsTheGameOnce() throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).gb")
        try GBTestROM.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try state.importDebugROM(at: source)
        try state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "gb")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "gambatte")
        XCTAssertEqual(try Data(contentsOf: dest), try Data(contentsOf: source))
        XCTAssertThrowsError(try state.importDebugROM(at: directory.appendingPathComponent("missing.gb")))
    }
}
