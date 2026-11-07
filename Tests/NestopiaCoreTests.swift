import XCTest
@testable import GagaEmu

/// Nestopia UE through the shared libretro adapter and the real bridge, running the generated homebrew
/// ROM (`NESTestROM`). `GambatteCoreTests` covers the adapter itself; this file covers what is Nestopia's.
final class NestopiaCoreTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("nestopia")!.pointee

    /// Upstream's default "royaltea" palette at the four entries `NESTestROM.palette` uses.
    private static let colors: [(r: UInt8, g: UInt8, b: UInt8)] = [(0, 0, 0), (187, 45, 9), (0, 115, 18), (255, 255, 255)]
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("nestopia"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("nestopia-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.nes")
        try NESTestROM.build().write(to: rom)
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

        /// XRGB8888, little endian.
        func pixel(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
            let i = y * pitch + x * 4
            return (pixels[i + 2], pixels[i + 1], pixels[i])
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

    private func loaded(path: String? = nil, saveDirectory: String? = nil) async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore(saveDirectory: saveDirectory)
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
        guard capture.width == NESTestROM.width, capture.height == NESTestROM.height else {
            return XCTFail("frame is \(capture.width) x \(capture.height)", file: file, line: line)
        }
        var wrong = 0
        for y in 0..<NESTestROM.height {
            for x in 0..<NESTestROM.width {
                let want = Self.colors[NESTestROM.expectedColor(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, genie: genie)]
                let got = capture.pixel(x: x, y: y)
                if got != want { wrong += 1 }
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

    func testGeneratedHeaderIsValidINES() {
        for battery in [true, false] {
            let rom = [UInt8](NESTestROM.build(battery: battery))
            XCTAssertEqual(rom.count, 16 + 0x4000 + 0x2000)
            XCTAssertEqual(Array(rom[0..<4]), [0x4E, 0x45, 0x53, 0x1A])
            XCTAssertEqual(rom[4], 1, "16 KB of PRG")
            XCTAssertEqual(rom[5], 1, "8 KB of CHR")
            XCTAssertEqual(rom[6], battery ? 0x02 : 0x00, "mapper 0, battery flag")
            XCTAssertEqual(rom[7], 0, "mapper 0, iNES 1.0")
            XCTAssertTrue(rom[8..<16].allSatisfy { $0 == 0 })
            let vector = { (offset: Int) in UInt16(rom[16 + offset]) | UInt16(rom[17 + offset]) << 8 }
            XCTAssertEqual(vector(0x3FFC), 0xC000, "reset")
            XCTAssertGreaterThan(vector(0x3FFA), 0xC000, "NMI")
            XCTAssertEqual(rom[16 + Int(NESTestROM.genieAddress - 0xC000)], 0, "the byte a Genie code patches")
        }
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("nestopia")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "2.0.0 f1e02d12")
        XCTAssertEqual(found.native_sample_rate, 48000)
        XCTAssertEqual(found.target_fps, 60.0988, accuracy: 0.0001)
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("nes")).pointee.core_id), "nestopia")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "nes"), "nestopia")
    }

    func testDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.width, 256)
        XCTAssertEqual(capture.height, 224, "8 lines cropped top and bottom")
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        // Joypad order. Touch A is the bridge's EAST, and B is its SOUTH.
        let order: [GagaButtonMask] = [GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_SELECT, GAGA_BTN_START,
                                       GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT]
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
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.channels, 2)
        XCTAssertEqual(capture.left.count, 120 * 48000 / 60, accuracy: 1100)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 500, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 48000)
        XCTAssertEqual(hertz, NESTestROM.toneHertz, accuracy: NESTestROM.toneHertz * 0.05)
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

    func testSessionPerLaunchIsFreshEachTime() async throws {
        for _ in 0..<10 {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture)
            core.stop()
        }
    }

    func testASecondLiveInstanceIsRefusedAndTheFirstKeepsRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertThrowsError(try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path))
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_EAST.rawValue))
        core.stop()
        XCTAssertEqual(capture.width, 256)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        func write(_ name: String, _ bytes: [UInt8]) throws -> String {
            let url = directory.appendingPathComponent(name)
            try Data(bytes).write(to: url)
            return url.path
        }
        var truncated = [UInt8](NESTestROM.build())
        truncated.removeLast(0x3000)

        let notAGame = "This file is not an NES cartridge image."
        let cannotLoad = "Nestopia could not load this game."
        let cases = [(try write("empty.nes", []), notAGame),
                     (try write("short.nes", [0x4E, 0x45, 0x53, 0x1A]), notAGame),
                     (try write("noise.nes", (0..<0x6000).map { UInt8(truncatingIfNeeded: $0 &* 73) }), notAGame),
                     (try write("truncated.nes", truncated), cannotLoad),
                     (directory.appendingPathComponent("gone.nes").path, "The game file could not be opened.")]
        for (path, message) in cases {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, message, path)
            }
            core.stop()
        }
        let saves = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".sav") }
        XCTAssertEqual(saves, [], "a refused file must not leave a save behind")
    }

    /// No FDS BIOS ships, so a disk image is refused with a message, not a crash or a black screen.
    func testADiskImageIsRefused() async throws {
        let disk = directory.appendingPathComponent("disk.fds")
        try Data([0x46, 0x44, 0x53, 0x1A, 1] + [UInt8](repeating: 0, count: 65500)).write(to: disk)
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: disk.path)
            XCTFail("loaded a disk image")
        } catch {
            XCTAssertEqual(error.localizedDescription, "This file is not an NES cartridge image.")
        }
        core.stop()
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

    func testACartridgeWithoutBatteryWritesNoSave() async throws {
        let rom = directory.appendingPathComponent("plain.nes")
        try NESTestROM.build(battery: false).write(to: rom)
        let (core, capture) = try await loaded(path: rom.path, saveDirectory: "/nonexistent/saves")
        run(core, frames: 12)
        assertPicture(capture)
        core.flushBatterySave()
        core.stop()
        XCTAssertNil(capture.fatal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("plain.sav").path))
    }

    func testBatterySaveReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, NESTestROM.sramSize)
            XCTAssertEqual(Array(flushed[0..<4]), NESTestROM.sramMagic)
            XCTAssertEqual(Int(flushed[NESTestROM.sramBootCounterOffset]), boot, "on disk when the flush returns")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[NESTestROM.sramBootCounterOffset]), boot)
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [])
    }

    func testPlayingFlushesWithoutAPause() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let (core, _) = try await loaded()
        run(core, frames: 12)
        let first = [UInt8](try Data(contentsOf: save))
        XCTAssertNotEqual(Array(first[0..<4]), NESTestROM.sramMagic, "created at load, before the program ran")
        run(core, frames: 300)
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: save))[0..<4]), NESTestROM.sramMagic)
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

    // MARK: - Save states

    func testStateIsNestopiasOwnFormat() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<(Self.headerSize + 4)]), [0x4E, 0x53, 0x54, 0x1A], "NST and EOF")
        XCTAssertEqual(core.stateVersion, 1)
        core.stop()
    }

    /// Upstream works the size out once per game, and its state is 9 bytes longer in the first frames after
    /// power on. A state saved early in one session must still fit a session that first asks much later.
    func testStateSizeDoesNotDependOnWhenItIsFirstAsked() async throws {
        let (early, _) = try await loaded()
        let earlySize = try early.saveState().count
        run(early, frames: 300)
        let earlyState = try early.saveState()
        XCTAssertEqual(earlyState.count, earlySize)
        early.stop()

        let (late, capture) = try await loaded()
        run(late, frames: 300)
        XCTAssertEqual(try late.saveState().count, earlySize)
        try late.loadState(earlyState)
        run(late, frames: 3)
        assertPicture(capture)
        late.stop()
    }

    func testRoundTripPlaysBackExactlyAndRestoresTheCPU() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        assertPicture(capture, toggle: true)
        let state = try core.saveState()

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

        // The flag is only in register Y, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](NESTestROM.build())
        other[other.count - 1] = 0x55
        let otherROM = directory.appendingPathComponent("other.nes")
        try Data(other).write(to: otherROM)
        let (foreign, _) = try await loaded(path: otherROM.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for Nestopia."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var notNestopia = state // Past the adapter's checks: Nestopia itself must refuse this one.
        notNestopia[Self.headerSize] ^= 0xFF
        var damaged = state
        for index in (Self.headerSize + 8)..<damaged.count { damaged[index] = 0xFF }
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (notNestopia, "Nestopia could not load this save state."),
            (damaged, "Nestopia could not load this save state."),
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

    // MARK: - Cheats

    /// A Game Genie code for a ROM address, 6 letters, or 8 with a compare byte.
    static func gameGenie(address: UInt16, value: UInt8, compare: UInt8? = nil) -> String {
        let a = Int(address & 0x7FFF), v = Int(value)
        var n = [(v & 7) | (v >> 4 & 8), (v >> 4 & 7) | (a >> 4 & 8), (a >> 4 & 7) | (compare == nil ? 0 : 8),
                 (a >> 12 & 7) | (a & 8), (a & 7) | (a >> 8 & 8), (a >> 8 & 7) | (v & 8)]
        if let compare {
            let c = Int(compare)
            n[5] = (a >> 8 & 7) | (c & 8)
            n += [(c & 7) | (c >> 4 & 8), (c >> 4 & 7) | (v & 8)]
        }
        let letters = Array("APZLGITYEOXUKSVN")
        return String(n.map { letters[$0] })
    }

    private lazy var ram = String(format: "%04X:01", NESTestROM.cheatAddress)
    private lazy var genie = Self.gameGenie(address: NESTestROM.genieAddress, value: 1)

    func testCheatFormatsHaveTheirEffectAndStop() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        assertPicture(capture)

        try core.addCheat(id: 1, code: ram, enabled: true)
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

        // Compares: the 8 letter code applies only while the ROM holds the byte it names.
        try core.addCheat(id: 4, code: Self.gameGenie(address: NESTestROM.genieAddress, value: 1, compare: 0x00), enabled: true)
        run(core, frames: 3)
        assertPicture(capture, genie: true)
        try core.addCheat(id: 4, code: Self.gameGenie(address: NESTestROM.genieAddress, value: 1, compare: 0x42), enabled: true)
        run(core, frames: 3)
        assertPicture(capture)
        try core.addCheat(id: 4, code: String(format: "%04X?00:01", NESTestROM.cheatAddress), enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.removeCheat(id: 4)

        // Several lines, in both formats, are one cheat.
        try core.addCheat(id: 3, code: " \(ram.lowercased()) \n\n\(genie.lowercased())\n", enabled: true)
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
        let tooLong = String(repeating: "A", count: 300)
        let cases = [("", "Enter a cheat code."),
                     ("0300:1", "Nestopia does not recognise this code: 0300:1"),
                     ("03G0:01", "Nestopia does not recognise this code: 03G0:01"),
                     ("AAEAAA", "Nestopia does not recognise this code: AAEAAA"), // The third letter asks for 8.
                     ("AAAAAAAA", "Nestopia does not recognise this code: AAAAAAAA"),
                     ("QQQQQQ", "Nestopia does not recognise this code: QQQQQQ"),
                     ("0300:01+AAAAAA", "Nestopia does not recognise this code: 0300:01+AAAAAA"),
                     (tooLong, "Nestopia does not recognise this code: \(tooLong.prefix(32))"),
                     ("\(ram)\nnope", "Nestopia does not recognise this code: nope")]
        for (code, message) in cases {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: code, enabled: true)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    func testTheGenieEncoderMatchesAPublishedCode() {
        // SXIOPO, the widely published infinite-lives code, decodes to 0x91D9 = 0xAD.
        XCTAssertEqual(Self.gameGenie(address: 0x91D9, value: 0xAD), "SXIOPO")
    }

    @MainActor
    func testUploadedGamesPickThisCore() {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() } // Leaves no upload- entry in the saved Library.
        let name = "upload-\(UUID().uuidString).nes"
        state.addUploads([name])
        let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
        XCTAssertEqual(added?.platformID, "nes")
        XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "nestopia")
    }

    // MARK: - Debug launch arguments

    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "nes", to: directory)
        XCTAssertEqual(rom.pathExtension, "nes")
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "nes", romPath: rom.path, coverPath: nil,
                            coreOverride: "nestopia", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
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
        XCTAssertTrue(url.lastPathComponent.hasPrefix("nestopia-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "nestopia")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    @MainActor
    func testDebugImportAddsTheGameOnce() throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).nes")
        try NESTestROM.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try state.importDebugROM(at: source)
        try state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "nes")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "nestopia")
    }
}
