import XCTest
@testable import GagaEmu

/// JGenesis through GagaEmu's own Rust shim and the real bridge, running the generated homebrew ROM
/// (`MDTestROM`). No BIOS, no TMSS and no commercial game.
final class JgenesisCoreTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("jgenesis")!.pointee
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("jgenesis"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("jgenesis-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.md")
        try MDTestROM.build().write(to: rom)
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

        /// RGBA8888.
        func pixel(x: Int, y: Int) -> [UInt8] {
            let i = y * pitch + x * 4
            return [pixels[i], pixels[i + 1], pixels[i + 2]]
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

    /// Colour words with each channel 0 or 7, which every JGenesis colour table maps to 0 or 255.
    private static func rgb8(_ color: UInt16) -> [UInt8] {
        [(color >> 1) & 7, (color >> 5) & 7, (color >> 9) & 7].map { $0 == 0 ? 0 : 255 }
    }

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, genie: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        guard capture.width == MDTestROM.width, capture.height == MDTestROM.height else {
            return XCTFail("frame is \(capture.width) by \(capture.height)", file: file, line: line)
        }
        var wrong = 0
        var cells = Set<String>()
        for y in 0..<MDTestROM.height {
            for x in 0..<MDTestROM.width {
                let shade = MDTestROM.expectedShade(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, genie: genie)
                if capture.pixel(x: x, y: y) != Self.rgb8(MDTestROM.colors[shade]) {
                    wrong += 1
                    cells.insert("\(x / 8),\(y / 8)")
                }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture, in tile cells \(cells.sorted())", file: file, line: line)
    }

    /// The pad's A and B: the controller's west and south buttons.
    private let chord = UInt32(GAGA_BTN_WEST.rawValue | GAGA_BTN_SOUTH.rawValue)

    /// Press and release A and B, then leave frames for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    // MARK: - ROM generator

    func testGeneratedHeaderChecks() {
        let rom = [UInt8](MDTestROM.build())
        XCTAssertEqual(rom.count, 0x10000)
        XCTAssertEqual(String(decoding: rom[0x100..<0x110], as: UTF8.self), "SEGA MEGA DRIVE ")
        func word(_ offset: Int) -> UInt16 { UInt16(rom[offset]) << 8 | UInt16(rom[offset + 1]) }
        func long(_ offset: Int) -> UInt32 { UInt32(word(offset)) << 16 | UInt32(word(offset + 2)) }
        let sum = stride(from: 0x200, to: rom.count, by: 2).reduce(UInt16(0)) { $0 &+ word($1) }
        XCTAssertEqual(word(0x18E), sum, "the checksum covers everything after the header")
        XCTAssertEqual(long(0x004), 0x200, "reset vector")
        XCTAssertEqual(long(0x1A4), UInt32(rom.count - 1), "ROM end")
        XCTAssertEqual(Array(rom[0x1B0..<0x1B4]), [0x52, 0x41, 0xF8, 0x20], "battery SRAM on odd bytes")
        XCTAssertEqual(Int(long(0x1B8) - long(0x1B4)) / 2 + 1, MDTestROM.sramSize)
        XCTAssertEqual(word(Int(MDTestROM.genieAddress)), 0, "the genie word reads zero")
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("jgenesis")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "0.14.1 cbe7f129")
        XCTAssertEqual(found.native_sample_rate, 48000)
        XCTAssertEqual(found.target_fps, 59.9227, accuracy: 0.001)
        for ext in ["md", "gen", "smd"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "jgenesis")
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "megadrive"), "jgenesis")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "megacd"), "jgenesis")
    }

    func testLoadsWithNoBIOSAndDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.width, 320)
        XCTAssertEqual(capture.height, 224, "V28, with no border")
        XCTAssertEqual(capture.pitch, 1280)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGBA8888)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        // MDTestROM.keyOrder: A B C on west, south and east, X Y Z on L1, north and R1, Mode on Select.
        let order: [GagaButtonMask] = [GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                       GAGA_BTN_WEST, GAGA_BTN_SOUTH, GAGA_BTN_EAST, GAGA_BTN_START,
                                       GAGA_BTN_L1, GAGA_BTN_NORTH, GAGA_BTN_R1, GAGA_BTN_SELECT]
        XCTAssertEqual(order.count, MDTestROM.keyOrder.count)
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    /// The tone comes from the PSG, so it also proves the program's writes reached the sound chip.
    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.channels, 2)
        // About 801 frames a frame; within one frame's worth of the exact count.
        XCTAssertEqual(Double(capture.left.count), 120 * 48000 / 59.9227, accuracy: 801)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 3000, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 48000)
        XCTAssertEqual(hertz, MDTestROM.toneHertz, accuracy: MDTestROM.toneHertz * 0.05)
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

    // MARK: - Lifecycle

    func testSessionPerLaunchIsFreshEachTime() async throws {
        for _ in 0..<10 {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture)
            core.stop()
        }
    }

    /// The machine is plain Rust code: the CPUs are interpreters and nothing is generated.
    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_WEST.rawValue))
        let state = try core.saveState()
        try core.loadState(state)
        run(core, frames: 3)
        core.stop()
        XCTAssertEqual(capture.width, 320)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let empty = directory.appendingPathComponent("empty.md")
        try Data().write(to: empty)
        let short = directory.appendingPathComponent("short.md")
        try Data(repeating: 0, count: 0x100).write(to: short)
        let noise = directory.appendingPathComponent("noise.md")
        try Data((0..<0x10000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)

        let notAGame = "This file is not a Mega Drive or Genesis game."
        let cases = [(empty.path, notAGame), (short.path, notAGame), (noise.path, notAGame),
                     (directory.appendingPathComponent("gone.md").path, "The game file could not be opened.")]
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

    /// No Mega-CD BIOS ships with GagaEmu, so a disc says what the player needs instead of failing silently.
    func testAMegaCDDiscWithoutABIOSSaysWhatIsMissing() async throws {
        let bin = directory.appendingPathComponent("disc.bin")
        try Data(repeating: 0, count: 2352 * 300).write(to: bin)
        let cue = directory.appendingPathComponent("disc.cue")
        try Data("FILE \"disc.bin\" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n".utf8).write(to: cue)
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: cue.path)
            XCTFail("loaded a disc with no BIOS")
        } catch {
            XCTAssertEqual(error.localizedDescription,
                           "This Mega-CD game needs a Mega-CD BIOS file (bios_CD_U.bin, bios_CD_E.bin or bios_CD_J.bin). GagaEmu does not include one.")
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

    func testBatterySaveReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, MDTestROM.sramSize)
            XCTAssertEqual(Array(flushed[0..<4]), MDTestROM.sramMagic)
            XCTAssertEqual(Int(flushed[MDTestROM.sramBootCounterOffset]), boot, "on disk when the flush returns")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[MDTestROM.sramBootCounterOffset]), boot)
        }
    }

    /// Progress must not depend on the player pausing: a crash would lose everything since the last pause.
    func testPlayingFlushesWithoutAPause() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let (core, _) = try await loaded()
        let first = [UInt8](try Data(contentsOf: save))
        XCTAssertNotEqual(Array(first[0..<4]), MDTestROM.sramMagic, "created at load, before the program ran")
        run(core, frames: 300)
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: save))[0..<4]), MDTestROM.sramMagic)
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
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: folder.appendingPathComponent("homebrew.sav")))[0..<4]), MDTestROM.sramMagic,
                       "the next flush still tries")
    }

    // MARK: - Save states

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("JGS1".utf8))
        XCTAssertEqual(state[4..<8].reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }, core.stateVersion)
        XCTAssertEqual(core.stateVersion, 0x000E_0001, "upstream's state format 0.14.0-1, which self_test checks")
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
        XCTAssertEqual(first.indices.filter { first[$0] != second[$0] }, [], "frames that differ")

        // The flag is only in register D7, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](MDTestROM.build())
        other[0x9000] = 0x55 // Unused ROM, so the program runs the same.
        let otherROM = directory.appendingPathComponent("other.md")
        try Data(other).write(to: otherROM)
        let (foreign, _) = try await loaded(path: otherROM.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for JGenesis."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var wrongVersion = state
        wrongVersion[4] ^= 0xFF
        var garbage = state // Past the header checks: upstream's decoder itself must refuse this one.
        garbage.replaceSubrange(Self.headerSize..<state.count, with: Data(repeating: 0xFF, count: state.count - Self.headerSize))
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (wrongVersion, otherOwner),
            (Data(repeating: 0, count: 4096), otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (state.prefix(Self.headerSize), wrongSize),
            (Data(), wrongSize),
            (garbage, "JGenesis could not load this save state."),
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

    /// Pro Action Replay for 0001 at RAM $FF0000 (its value is byte-swapped). Game Genie for 0001 at ROM $008000.
    private let replay = "FF000-00100"
    private let genie = "AGAA-AAAA"

    func testCheatFormatsHaveTheirEffectAndStop() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        assertPicture(capture)

        try core.addCheat(id: 1, code: replay, enabled: true)
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

        // Several lines, in any of the formats, are one cheat. Adding an ID again replaces it.
        try core.addCheat(id: 3, code: " FF0000:0001 \n\n\(genie.lowercased())\n", enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true, genie: true)
        try core.addCheat(id: 3, code: genie, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, genie: true)

        // A save state carries the settings it was made with; loading one keeps this session's cheats.
        let state = try core.saveState()
        core.removeCheat(id: 3)
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture)
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
                     ("ZZZZZZZZ", "JGenesis does not recognise this code: ZZZZZZZZ"),
                     ("AGAA-AAAI", "JGenesis does not recognise this code: AGAA-AAAI"),
                     ("FF0000:01", "JGenesis does not recognise this code: FF0000:01"),
                     ("\(replay)\nnope", "JGenesis does not recognise this code: nope")]
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
        for ext in ["md", "gen", "smd"] {
            let name = "upload-\(UUID().uuidString).\(ext)"
            state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, "megadrive")
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "jgenesis")
        }
    }

    // MARK: - Debug launch arguments

    /// `-GagaBenchmarkCore jgenesis` with no ROM: the generated ROM and a record named for this core.
    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "megadrive", to: directory)
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "megadrive", romPath: rom.path, coverPath: nil,
                            coreOverride: "jgenesis", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
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
        XCTAssertTrue(url.lastPathComponent.hasPrefix("jgenesis-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "jgenesis")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    /// `-GagaImportROM <path>`: an .md file lands in the Library as a Mega Drive game on this core.
    @MainActor
    func testDebugImportAddsTheGameOnce() throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).md")
        try MDTestROM.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try state.importDebugROM(at: source)
        try state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "megadrive")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "jgenesis")
    }
}
