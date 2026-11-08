import XCTest
@testable import GagaEmu

/// MAME through the shared libretro adapter and the real bridge, running the generated homebrew set for the
/// `gridlee` machine (`GridleeTestSet`). `GambatteCoreTests` covers the adapter itself; this file covers what
/// is MAME's: ROM sets by machine name, NVRAM, MAME's own state format.
final class MameCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("mame")!.pointee

    private static let headerSize = 16
    private let button1 = UInt32(GAGA_BTN_SOUTH.rawValue) // RetroPad B, MAME's button 1.
    private let start1 = UInt32(GAGA_BTN_START.rawValue)

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("mame"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("mame-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        romPath = try write(GridleeTestSet.build(), as: "gridlee.zip")
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// MAME finds a machine by the file's name, so each set gets its own folder.
    private func write(_ data: Data, as name: String, folder: String = "roms") throws -> String {
        let url = directory.appendingPathComponent(folder).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url.path
    }

    private var nvram: URL { directory.appendingPathComponent("saves/mame/nvram/gridlee/nvram") }

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

        /// The rectangle that is not black: the game picture, wherever MAME put it in the frame.
        func picture() -> (x: Int, y: Int, width: Int, height: Int)? {
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where pixel(x: x, y: y) != (0, 0, 0) {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            return maxX < 0 ? nil : (minX, minY, maxX - minX + 1, maxY - minY + 1)
        }
    }

    private func makeCore(saveDirectory: String? = nil) throws -> (GagaCoreWrapper, Capture) {
        let saves = saveDirectory ?? directory.appendingPathComponent("saves").path
        try? FileManager.default.createDirectory(atPath: saves, withIntermediateDirectories: true)
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.appendingPathComponent("system").path,
                                       saveDirectory: saves)
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

    /// Boot, and the bands drawn: the program fills them in about 12 frames.
    private let bootFrames = 60

    /// Compares the centre of every 4 x 4 block of the 256 x 240 picture, so MAME's scaling and filtering
    /// between pixels do not matter. Every block is one colour in `GridleeTestSet`.
    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        guard capture.format == GAGA_PIXEL_FORMAT_XRGB8888, let area = capture.picture() else {
            return XCTFail("no picture in a \(capture.width) x \(capture.height) frame", file: file, line: line)
        }
        XCTAssertEqual(Double(area.width) / Double(area.height), Double(GridleeTestSet.width) / Double(GridleeTestSet.height),
                       accuracy: 0.05, "the picture's shape", file: file, line: line)
        var wrong = 0
        for y in stride(from: 2, to: GridleeTestSet.height, by: 4) {
            for x in stride(from: 2, to: GridleeTestSet.width, by: 4) {
                let want = GridleeTestSet.colors[GridleeTestSet.expectedColor(x: x, y: y, keys: keys, toggle: toggle)]
                let got = capture.pixel(x: area.x + x * area.width / GridleeTestSet.width,
                                        y: area.y + y * area.height / GridleeTestSet.height)
                let close = { (got: UInt8, want: UInt8) in abs(Int(got) - Int(want) * 17) <= 8 } // 4-bit PROM values.
                if !(close(got.r, want.r) && close(got.g, want.g) && close(got.b, want.b)) { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "blocks that differ from the expected picture", file: file, line: line)
    }

    private var chord: UInt32 { button1 | start1 }

    /// Press and release both buttons, then leave frames for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 3, buttons: chord)
        run(core, frames: 3)
    }

    // MARK: - ROM set generator

    func testGeneratedSetHasUpstreamsFileNamesAndSizes() {
        let files = GridleeTestSet.files()
        let expected = ["gridfnla.bin", "gridfnlb.bin", "gridfnlc.bin", "gridfnld.bin", "gridfnle.bin", "gridfnlf.bin",
                        "gridpix0.bin", "gridpix1.bin", "gridpix2.bin", "gridpix3.bin",
                        "grdrprom.bin", "grdgprom.bin", "grdbprom.bin"]
        XCTAssertEqual(files.map(\.name), expected)
        XCTAssertEqual(files.map(\.data.count), [Int](repeating: 0x1000, count: 10) + [0x800, 0x800, 0x800])
        let last = [UInt8](files[5].data)
        XCTAssertEqual(UInt16(last[0xFFE]) << 8 | UInt16(last[0xFFF]), 0xA000, "6809 reset vector, big endian")
        let zip = [UInt8](GridleeTestSet.build())
        XCTAssertEqual(Array(zip[0..<4]), [0x50, 0x4B, 0x03, 0x04])
        XCTAssertEqual(Array(zip[(zip.count - 22)..<(zip.count - 18)]), [0x50, 0x4B, 0x05, 0x06], "end of central directory")
        XCTAssertEqual(Int(zip[zip.count - 12]) | Int(zip[zip.count - 11]) << 8, expected.count)
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("mame")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "0.289 5f5a0774")
        XCTAssertEqual(found.native_sample_rate, 48000)
        XCTAssertEqual(found.target_fps, 60.0, accuracy: 0.0001)
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("zip")).pointee.core_id), "mame")
        XCTAssertNil(found.cheat_add, "no cheats: upstream's retro_cheat_set does nothing")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertNil(CoreCatalog.platformID(forExtension: "zip"), "placed by content")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "7z"), "arcade")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "arcade"), "mame")
    }

    func testDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: bootFrames)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        assertPicture(capture)
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: bootFrames)
        run(core, frames: 3, buttons: button1)
        assertPicture(capture, keys: 1)
        run(core, frames: 3)
        assertPicture(capture)
        run(core, frames: 3, buttons: start1)
        assertPicture(capture, keys: 2)
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.channels, 2)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(tone.count, 48000 / 2, "about a second of the second half")
        XCTAssertGreaterThan(Int(tone.max() ?? 0) - Int(tone.min() ?? 0), 500, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / max(tone.count, 1)
        var crossings = 0
        var previous = (tone.first ?? 0) >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 48000)
        XCTAssertEqual(hertz, GridleeTestSet.toneHertz, accuracy: GridleeTestSet.toneHertz * 0.05)
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
        for _ in 0..<4 {
            let (core, capture) = try await loaded()
            run(core, frames: bootFrames)
            assertPicture(capture)
            core.stop()
        }
    }

    func testASecondLiveInstanceIsRefusedAndTheFirstKeepsRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: bootFrames)
        XCTAssertThrowsError(try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path))
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: button1)
        core.stop()
        XCTAssertGreaterThan(capture.width, 0)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        var missing = GridleeTestSet.files()
        missing.removeFirst() // gridfnla.bin, the program.
        let notASet = "This file is not a MAME ROM set (a .zip named after the machine) for a machine in this build."
        // MAME's own auditor refuses the last two before MAME starts them (gaga_mame_refuse_load).
        let missingFiles = "This ROM set is missing files that gridlee needs, such as gridfnla.bin. Its parent or BIOS set may be missing too."
        let unknown = "This build of MAME has no machine named \"pacman\". A ROM set's file name must be the machine's short name."
        let cases = [(try write(Data(), as: "gridlee.zip", folder: "empty"), notASet),
                     (try write(Data((0..<0x6000).map { UInt8(truncatingIfNeeded: $0 &* 73) }), as: "gridlee.zip", folder: "noise"), notASet),
                     (try write(Data("-gridlee".utf8), as: "gridlee.cmd", folder: "cmd"), notASet), // A MAME command line.
                     (try write(GridleeTestSet.zip(missing), as: "gridlee.zip", folder: "missing"), missingFiles),
                     (try write(GridleeTestSet.build(), as: "pacman.zip", folder: "unknown"), unknown), // Not in drivers.flt.
                     (directory.appendingPathComponent("gone/gridlee.zip").path, "The game file could not be opened.")]
        for (path, message) in cases {
            let (core, capture) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, message, path)
            }
            XCTAssertNotNil(capture.fatal)
            core.stop()
        }
        // MAME still starts the next game normally.
        let (core, capture) = try await loaded()
        run(core, frames: bootFrames)
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

    // MARK: - Cheats

    /// A player's cheat file for gridlee, in MAME's XML: an on/off cheat and one with settings, each writing an
    /// NVRAM byte the program never touches, every frame. Hex numbers in actions, decimal in attributes.
    private static let cheatXML = """
        <mamecheat version="1">
          <cheat desc="Mark NVRAM">
            <script state="run"><action>maincpu.pb@9c80=5a</action></script>
          </cheat>
          <cheat desc="Mark Level">
            <parameter>
              <item value="17">Low</item>
              <item value="34">High</item>
            </parameter>
            <script state="run"><action>maincpu.pb@9c81=param</action></script>
          </cheat>
        </mamecheat>
        """

    func testCheatsFromThePlayersCheatFileRunInMamesEngine() async throws {
        _ = try write(Data(Self.cheatXML.utf8), as: "gridlee.xml", folder: "system/mame/cheat")
        let (core, _) = try await loaded()
        run(core, frames: bootFrames)
        XCTAssertTrue(core.supportsCheats)
        for refused in ["No Such Cheat", "Mark Level", "Mark Level = Medium", "maincpu.pb@9c80=5a"] {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: refused, enabled: true), refused)
        }
        try core.addCheat(id: 1, code: "MARK NVRAM", enabled: true) // The sheet's code field types capitals.
        try core.addCheat(id: 2, code: "Mark Level = High", enabled: true)
        run(core, frames: 2)
        core.flushBatterySave()
        var saved = [UInt8](try Data(contentsOf: nvram))
        XCTAssertEqual(saved[0x80], 0x5A)
        XCTAssertEqual(saved[0x81], 34)
        XCTAssertEqual(Int(saved[GridleeTestSet.nvramBootCounterOffset]), 1, "the program's own bytes untouched")

        core.setCheat(id: 2, enabled: false)
        try core.addCheat(id: 3, code: "Mark Level = Low", enabled: true)
        run(core, frames: 2)
        core.flushBatterySave()
        saved = [UInt8](try Data(contentsOf: nvram))
        XCTAssertEqual(saved[0x81], 17, "the other setting, once the first is off")
        core.stop()
    }

    func testWithoutACheatFileEveryNameIsRefused() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        XCTAssertThrowsError(try core.addCheat(id: 1, code: "Mark NVRAM", enabled: true)) { error in
            XCTAssertEqual(error.localizedDescription, "MAME does not recognise this code: Mark NVRAM")
        }
        core.stop()
    }

    // MARK: - Battery saves

    func testNVRAMReachesItsFileAndSurvivesARestart() async throws {
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: bootFrames)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: nvram))
            XCTAssertEqual(flushed.count, GridleeTestSet.nvramSize)
            XCTAssertEqual(Array(flushed[0..<4]), GridleeTestSet.nvramMagic)
            XCTAssertEqual(Int(flushed[GridleeTestSet.nvramBootCounterOffset]), boot, "on disk when the flush returns")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: nvram))[GridleeTestSet.nvramBootCounterOffset]), boot)
        }
    }

    func testPlayingFlushesWithoutAPause() async throws {
        let (core, _) = try await loaded()
        let first = [UInt8](try Data(contentsOf: nvram))
        XCTAssertNotEqual(Array(first[0..<4]), GridleeTestSet.nvramMagic, "written at load, before the program ran")
        run(core, frames: 300)
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: nvram))[0..<4]), GridleeTestSet.nvramMagic)
        core.stop()
    }

    // MARK: - Save states

    func testStateIsMamesOwnFormat() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<(Self.headerSize + 8)]), Array("MAMESAVE".utf8))
        XCTAssertEqual(UInt32(state[Self.headerSize + 8]), core.stateVersion, "MAME's SAVE_VERSION")
        XCTAssertEqual(core.stateVersion, 2)
        core.stop()
    }

    func testRoundTripPlaysBackExactlyAndRestoresTheCPU() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: bootFrames)
        flipToggle(core)
        assertPicture(capture, toggle: true)
        let state = try core.saveState()

        func script() -> [[UInt8]] {
            (0..<30).map { frame in
                run(core, frames: 1, buttons: frame == 15 ? chord : frame % 7 == 0 ? button1 : 0)
                return capture.pixels
            }
        }
        let first = script()
        run(core, frames: 3)
        assertPicture(capture, toggle: false)
        try core.loadState(state)
        let second = script()
        XCTAssertEqual(first, second)

        // The flag is only in register U, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        var other = GridleeTestSet.files()
        other[1].data[0] = 0x55 // gridfnlb.bin: unused by the program, so only the file differs.
        let otherSet = try write(GridleeTestSet.zip(other), as: "gridlee.zip", folder: "other")
        let (foreign, _) = try await loaded(path: otherSet)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: bootFrames)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for MAME."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var notMame = state // Past the adapter's checks: MAME itself must refuse this one.
        notMame[Self.headerSize] ^= 0xFF
        var newerVersion = state
        newerVersion[Self.headerSize + 8] += 1
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (notMame, "MAME could not load this save state."),
            (newerVersion, "MAME could not load this save state."),
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

    // MARK: - Import

    @MainActor
    func testUploadedSetsPickThisCore() async {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved }
        for ext in ["7z"] { // A .zip is placed by its contents: GagaEmuTests.testZipsArePlacedByContent.
            let name = "upload-\(UUID().uuidString).\(ext)"
            // Since 7z import an upload is opened, so it must be a real set (SevenZipImportTests.testAMAMESetStaysArcade).
            let url = state.romDirectory.appendingPathComponent(name)
            let text = Data("set".utf8)
            try? SevenZipTestArchive.build([("pacman.6e", text), ("82s123", text)]).write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            await state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, "arcade")
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "mame")
        }
    }

    /// The importer copies a set as it is, keeping the machine's name and every file inside, so MAME can find
    /// it in the ROM folder.
    @MainActor
    func testImportedSetKeepsItsNameAndBoots() async throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = URL(fileURLWithPath: romPath)
        let dest = state.romDirectory.appendingPathComponent("gridlee.zip")
        let existing = try? Data(contentsOf: dest)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            if let existing { try? existing.write(to: dest) } else { try? FileManager.default.removeItem(at: dest) }
        }
        try await state.importDebugROM(at: source)
        try await state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == "gridlee.zip" && !saved.contains($0.id) }
        XCTAssertLessThanOrEqual(added.count, 1)
        XCTAssertEqual(try Data(contentsOf: dest), GridleeTestSet.build())
        let game = try XCTUnwrap(state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == "gridlee.zip" })
        XCTAssertEqual(game.platformID, "arcade")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "mame")

        let (core, capture) = try await loaded(path: try XCTUnwrap(game.resolvedROMPath(romDirectory: state.romDirectory)))
        run(core, frames: bootFrames)
        assertPicture(capture)
        core.stop()
    }

    // MARK: - Debug launch arguments

    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "arcade", to: directory)
        XCTAssertEqual(rom.lastPathComponent, "gridlee.zip")
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "arcade", romPath: rom.path, coverPath: nil,
                            coreOverride: "mame", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
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
        XCTAssertTrue(url.lastPathComponent.hasPrefix("mame-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "mame")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }
}
