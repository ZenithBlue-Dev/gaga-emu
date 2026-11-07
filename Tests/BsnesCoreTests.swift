import XCTest
@testable import GagaEmu

/// bsnes through the shared libretro adapter and the real bridge, running the generated homebrew ROM
/// (`SNESTestROM`). No firmware and no commercial game.
final class BsnesCoreTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("bsnes")!.pointee
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("bsnes"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("bsnes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.sfc")
        try SNESTestROM.build().write(to: rom)
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
        func pixel(x: Int, y: Int) -> [UInt8] {
            let i = y * pitch + x * 4
            return [pixels[i + 2], pixels[i + 1], pixels[i]]
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

    /// BGR555 with each channel 0 or 31, which bsnes's palette maps to 0 or 255 at any gamma.
    private static func rgb8(_ color: UInt16) -> [UInt8] {
        [color & 0x1F, (color >> 5) & 0x1F, (color >> 10) & 0x1F].map { $0 == 0 ? 0 : 255 }
    }

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, genie: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        guard capture.width == SNESTestROM.width, capture.height == SNESTestROM.height else {
            return XCTFail("frame is \(capture.width) by \(capture.height)", file: file, line: line)
        }
        var wrong = 0
        var cells = Set<String>()
        for y in 0..<SNESTestROM.height {
            for x in 0..<SNESTestROM.width {
                let shade = SNESTestROM.expectedShade(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, genie: genie)
                if capture.pixel(x: x, y: y) != Self.rgb8(SNESTestROM.colors[shade]) {
                    wrong += 1
                    cells.insert("\(x / 8),\(y / 8)")
                }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture, in tile cells \(cells.sorted())", file: file, line: line)
    }

    private let chord = UInt32(GAGA_BTN_EAST.rawValue | GAGA_BTN_SOUTH.rawValue)

    /// Press and release A and B, then leave frames for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    // MARK: - ROM generator

    func testGeneratedHeaderChecks() {
        let rom = [UInt8](SNESTestROM.build())
        XCTAssertEqual(rom.count, 0x8000)
        XCTAssertEqual(String(decoding: rom[0x7FC0..<0x7FD5], as: UTF8.self), "GAGA TEST SNES       ")
        XCTAssertEqual(rom[0x7FD5], 0x20, "LoROM")
        XCTAssertEqual(rom[0x7FD6], 0x02, "battery SRAM")
        XCTAssertEqual(1024 << Int(rom[0x7FD8]), SNESTestROM.sramSize)
        let complement = UInt16(rom[0x7FDC]) | UInt16(rom[0x7FDD]) << 8
        let checksum = UInt16(rom[0x7FDE]) | UInt16(rom[0x7FDF]) << 8
        XCTAssertEqual(complement ^ checksum, 0xFFFF)
        XCTAssertEqual(rom.reduce(UInt16(0)) { $0 &+ UInt16($1) }, checksum, "the checksum covers the whole image")
        XCTAssertEqual(UInt16(rom[0x7FFC]) | UInt16(rom[0x7FFD]) << 8, 0x8000, "reset vector")
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("bsnes")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "115 b51612a7")
        XCTAssertEqual(found.native_sample_rate, 48000)
        XCTAssertEqual(found.target_fps, 60.0988, accuracy: 0.001)
        for ext in ["sfc", "smc"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "bsnes")
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "snes"), "bsnes")
    }

    func testLoadsWithNoFirmwareAndDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.width, 256)
        XCTAssertEqual(capture.height, 224, "240 lines less the 8 of overscan at each edge")
        XCTAssertEqual(capture.pitch, 1024)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        // SNESTestROM.keyOrder. The bridge's SOUTH is Nintendo's B and EAST is A.
        let order: [GagaButtonMask] = [GAGA_BTN_SOUTH, GAGA_BTN_WEST, GAGA_BTN_SELECT, GAGA_BTN_START,
                                       GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                       GAGA_BTN_EAST, GAGA_BTN_NORTH, GAGA_BTN_L1, GAGA_BTN_R1]
        XCTAssertEqual(order.count, SNESTestROM.keyOrder.count)
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    /// The tone comes from the SPC700 program the ROM uploads, so it also proves the sound CPU ran it.
    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.channels, 2)
        // Packets of 800 frames, so within one packet of the exact count.
        XCTAssertEqual(Double(capture.left.count), 120 * 48000 / 60.0988, accuracy: 800)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 5000, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 48000)
        XCTAssertEqual(hertz, SNESTestROM.toneHertz, accuracy: SNESTestROM.toneHertz * 0.05)
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

    func testASecondLiveInstanceIsRefusedAndTheFirstKeepsRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertThrowsError(try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)) {
            XCTAssertEqual($0.localizedDescription, "The emulator core could not start.")
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    /// libco.c switches between bsnes's CPU, sound CPU and PPU threads with compiled code, never generated code.
    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_EAST.rawValue))
        let state = try core.saveState()
        try core.loadState(state)
        run(core, frames: 3)
        core.stop()
        XCTAssertEqual(capture.width, 256)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let empty = directory.appendingPathComponent("empty.sfc")
        try Data().write(to: empty)
        let short = directory.appendingPathComponent("short.sfc")
        try Data(repeating: 0, count: 0x100).write(to: short)
        let noise = directory.appendingPathComponent("noise.sfc")
        try Data((0..<0x8000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        var damaged = [UInt8](SNESTestROM.build())
        damaged[0x7FFD] = 0x00 // The reset vector no longer points into ROM.
        let badHeader = directory.appendingPathComponent("damaged.sfc")
        try Data(damaged).write(to: badHeader)

        let notAGame = "This file is not a Super Famicom or Super NES game."
        let cases = [(empty.path, notAGame), (short.path, notAGame), (noise.path, notAGame), (badHeader.path, notAGame),
                     (directory.appendingPathComponent("gone.sfc").path, "The game file could not be opened.")]
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("noise.srm").path),
                       "a refused file must not leave a save behind")
    }

    /// A copier's 512-byte header in front of the image, which bsnes skips.
    func testACopierHeaderStillLoads() async throws {
        let rom = directory.appendingPathComponent("copier.smc")
        try (Data(repeating: 0, count: 0x200) + SNESTestROM.build()).write(to: rom)
        let (core, capture) = try await loaded(path: rom.path)
        run(core, frames: 12)
        assertPicture(capture)
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

    /// bsnes names the file itself: <rom stem>.srm in the save folder.
    func testBatterySaveReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.srm")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, SNESTestROM.sramSize)
            XCTAssertEqual(Array(flushed[0..<4]), SNESTestROM.sramMagic)
            XCTAssertEqual(Int(flushed[SNESTestROM.sramBootCounterOffset]), boot, "on disk when the flush returns")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[SNESTestROM.sramBootCounterOffset]), boot)
        }
    }

    /// Progress must not depend on the player pausing: a crash would lose everything since the last pause.
    func testPlayingFlushesWithoutAPause() async throws {
        let save = directory.appendingPathComponent("homebrew.srm")
        let (core, _) = try await loaded()
        let first = [UInt8](try Data(contentsOf: save))
        XCTAssertNotEqual(Array(first[0..<4]), SNESTestROM.sramMagic, "created at load, before the program ran")
        run(core, frames: 300)
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: save))[0..<4]), SNESTestROM.sramMagic)
        core.stop()
    }

    func testAFailedSaveWriteTellsThePlayer() async throws {
        let save = directory.appendingPathComponent("homebrew.srm")
        let (core, capture) = try makeCore()
        try await core.loadROM(path: romPath)
        chmod(save.path, 0o444)
        defer { chmod(save.path, 0o644) }
        run(core, frames: 12)
        core.flushBatterySave()
        XCTAssertEqual(capture.fatal, "The save file for this game could not be written.")
        chmod(save.path, 0o644)
        core.flushBatterySave()
        core.stop()
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: save))[0..<4]), SNESTestROM.sramMagic, "the next flush still tries")
    }

    // MARK: - Save states

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<(Self.headerSize + 4)]), Array("BST1".utf8), "bsnes's own signature")
        XCTAssertEqual(core.stateVersion, 1)
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
        // Upstream leaves the bottom line black in the first frame after a load, so that one line is skipped.
        let lastRow = first[0].count - first[0].count / 224
        XCTAssertEqual(first[0][..<lastRow], second[0][..<lastRow], "the first frame after the load")
        XCTAssertEqual(first.indices.dropFirst().filter { first[$0] != second[$0] }, [], "frames that differ")

        // The flag is only in register Y, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](SNESTestROM.build())
        other[0x7000] = 0x55 // Unused ROM, so the program runs the same.
        let otherROM = directory.appendingPathComponent("other.sfc")
        try Data(other).write(to: otherROM)
        let (foreign, _) = try await loaded(path: otherROM.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for bsnes."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var wrongSignature = state // Past the adapter's checks: bsnes itself must refuse this one.
        wrongSignature[Self.headerSize] ^= 0xFF
        var wrongVersion = state
        wrongVersion[Self.headerSize + 8] ^= 0xFF // The first byte of bsnes's serializer version string.
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (Data(repeating: 0, count: 4096), wrongSize),
            (wrongSignature, "bsnes could not load this save state."),
            (wrongVersion, "bsnes could not load this save state."),
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

    /// Pro Action Replay AAAAAADD: 01 to $7E0000. Game Genie for 01 at ROM $00F000.
    private let replay = "7E000001"
    private let genie = "DFED-DDDD"

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

        // Several lines, in both formats, are one cheat.
        try core.addCheat(id: 3, code: " \(replay.lowercased()) \n\n\(genie.lowercased())\n", enabled: true)
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

    /// Upstream's parser reads past the end of a short code, so these must never reach it.
    func testBadCodesAreRefusedAndAddNothing() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        let cases = [("", "Enter a cheat code."), (" \n ", "Enter a cheat code."),
                     ("ZZZZZZZZ", "bsnes does not recognise this code: ZZZZZZZZ"),
                     ("7E00", "bsnes does not recognise this code: 7E00"),
                     ("7E000001+7E000101", "bsnes does not recognise this code: 7E000001+7E000101"),
                     ("DFED-DDD", "bsnes does not recognise this code: DFED-DDD"),
                     ("\(replay)\nnope", "bsnes does not recognise this code: nope")]
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
        for ext in ["sfc", "smc"] {
            let name = "upload-\(UUID().uuidString).\(ext)"
            state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, "snes")
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "bsnes")
        }
    }

    // MARK: - Debug launch arguments

    /// `-GagaBenchmarkCore bsnes` with no ROM: the generated ROM and a record named for this core.
    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "snes", to: directory)
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "snes", romPath: rom.path, coverPath: nil,
                            coreOverride: "bsnes", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
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
        XCTAssertTrue(url.lastPathComponent.hasPrefix("bsnes-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "bsnes")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    /// `-GagaImportROM <path>`: an .sfc file lands in the Library as a Super Famicom game on this core.
    @MainActor
    func testDebugImportAddsTheGameOnce() throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).sfc")
        try SNESTestROM.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try state.importDebugROM(at: source)
        try state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "snes")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "bsnes")
    }
}
