import XCTest
@testable import GagaEmu

@_silgen_name("csops")
private func dosboxJitTestCsops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

/// DOSBox Pure through the shared libretro adapter and the real bridge, running the generated DOS program
/// (`DOSTestCOM`). DOS runs on its own thread between frames and boots for a while first, so each check
/// steps until the picture is the expected one, within a frame budget.
final class DosboxPureCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("dosbox_pure")!.pointee
    private static let headerSize = 16
    private static let budget = 1200

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("dosbox_pure"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("dosbox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("gagatest.com")
        try DOSTestCOM.build().write(to: rom)
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

        /// Program pixels that differ from the expected picture, with the frame scaled to 320 by 200.
        func wrong(presses: Int = 0, button: Bool = false, boots: Int = 1) -> (count: Int, first: String?) {
            guard width >= DOSTestCOM.width, height >= DOSTestCOM.height, pixels.count >= pitch * height else {
                return (1, "frame \(width)x\(height)")
            }
            var count = 0
            var first: String?
            for y in 0..<DOSTestCOM.height {
                for x in 0..<DOSTestCOM.width {
                    let fx = (x * 2 + 1) * width / (DOSTestCOM.width * 2), fy = (y * 2 + 1) * height / (DOSTestCOM.height * 2)
                    let i = fy * pitch + fx * 4
                    let want = DOSTestCOM.rgb(DOSTestCOM.expectedColor(x: x, y: y, presses: presses, button: button, boots: boots))
                    if pixels[i + 2] != want.r || pixels[i + 1] != want.g || pixels[i] != want.b {
                        count += 1
                        if first == nil { first = "(\(x), \(y)): \(pixels[i + 2]),\(pixels[i + 1]),\(pixels[i]) not \(want)" }
                    }
                }
            }
            return (count, first)
        }
    }

    private func makeCore() throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
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

    /// `keys` are USB HID usages held on a hardware keyboard.
    private func input(buttons: UInt32 = 0, finger: Bool = false, keys: [Int] = []) -> GagaInputState {
        var input = GagaInputState()
        input.buttons = buttons
        input.pointer_down = finger // The middle of the picture: pointer 0, 0.
        withUnsafeMutableBytes(of: &input.keys) { bytes in
            for usage in keys { bytes[usage >> 3] |= UInt8(1 << (usage & 7)) }
        }
        return input
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0, finger: Bool = false, keys: [Int] = []) {
        for _ in 0..<frames { core.step(inputs: [input(buttons: buttons, finger: finger, keys: keys)]) }
    }

    /// Steps until the picture matches, at most `budget` frames, holding `buttons` and the finger meanwhile.
    /// `pace` sleeps that long per frame, for DOSBox Pure's wall-clock touch timing.
    private func expectPicture(_ core: GagaCoreWrapper, _ capture: Capture, presses: Int = 0, button: Bool = false,
                               boots: Int = 1, finger: Bool = false, pace: TimeInterval = 0, budget: Int = budget,
                               file: StaticString = #filePath, line: UInt = #line) {
        var result = capture.wrong(presses: presses, button: button, boots: boots)
        var frames = 0
        while result.count > 0 && frames < budget {
            core.step(inputs: [input(finger: finger)])
            if pace > 0 { Thread.sleep(forTimeInterval: pace) }
            frames += 1
            result = capture.wrong(presses: presses, button: button, boots: boots)
        }
        XCTAssertEqual(result.count, 0, "pixels that differ after \(frames) frames, first \(result.first ?? "none")", file: file, line: line)
        XCTAssertNil(capture.fatal, file: file, line: line)
    }

    /// One keystroke: held for a few frames, then released.
    private func press(_ core: GagaCoreWrapper, _ button: GagaButtonMask) {
        run(core, frames: 4, buttons: UInt32(button.rawValue))
        run(core, frames: 4)
    }

    /// The C: folder a loose program runs from, in the save directory.
    private func driveC(_ name: String = "gagatest.com") -> URL { directory.appendingPathComponent("DOS/\(name)") }

    // MARK: - Program generator

    func testGeneratedProgramIsASmallComFile() {
        let program = [UInt8](DOSTestCOM.build())
        XCTAssertLessThan(program.count, 1024)
        XCTAssertEqual(Array(program.prefix(5)), [0xB8, 0x13, 0x00, 0xCD, 0x10], "starts by setting mode 13h")
        XCTAssertNotEqual(Array(program.prefix(2)), Array("MZ".utf8))
        XCTAssertNotNil(program.firstRange(of: Array("C:\\GAGA.DAT".utf8) + [0]))
        XCTAssertEqual(DOSTestCOM.expectedColor(x: 0, y: 0), 0)
        XCTAssertEqual(DOSTestCOM.expectedColor(x: 319, y: 99, presses: 2), (9 + 2) & 7)
        XCTAssertEqual(DOSTestCOM.expectedColor(x: 0, y: 120, button: true), 7)
        XCTAssertEqual(DOSTestCOM.expectedColor(x: 63, y: 199, boots: 2), 2)
        XCTAssertEqual(DOSTestCOM.expectedColor(x: 64, y: 199, boots: 2), 0)
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("dosbox_pure")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertTrue(String(cString: found.core_version).hasPrefix("1.0-preview7"))
        XCTAssertEqual(found.native_sample_rate, 48000)
        XCTAssertEqual(found.target_fps, 60.0, accuracy: 0.001)
        XCTAssertNil(found.cheat_add, "DOSBox Pure has no cheats, so the menu row hides")
        for ext in ["com", "bat", "dosz", "ima", "vhd", "jrc", "conf"] { // .zip finds MAME first. The catalog picks by the contents.
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "dosbox_pure", ext)
        }
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("exe")).pointee.core_id), "pcsx_rearmed",
                       "the registry's first match. The catalog picks by the file's bytes")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "dos"), "dosbox_pure")
    }

    func testRunsTheProgramAndDrawsThePattern() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        core.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("GAGA.DAT").path),
                       "the program's files stay out of the ROM folder")
        XCTAssertEqual(try Data(contentsOf: driveC().appendingPathComponent("GAGA.DAT")), Data([1]))
        XCTAssertEqual(try Data(contentsOf: driveC().appendingPathComponent("gagatest.com")), DOSTestCOM.build(),
                       "runs from a copy in its own C: folder")
    }

    /// The pad reaches DOS as keys through DOSBox Pure's generic keyboard mapping: Start is Enter, the top face
    /// button (RetroPad X) is space, and the d-pad is the arrow keys.
    func testPadButtonsReachTheProgramAsKeys() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        for (index, button) in [GAGA_BTN_START, GAGA_BTN_NORTH, GAGA_BTN_UP].enumerated() {
            press(core, button)
            expectPicture(core, capture, presses: index + 1)
        }
        core.stop()
    }

    /// A hardware keyboard reaches DOS key by key through the adapter's keyboard callback: a letter, Enter,
    /// a digit, Escape, and a shifted letter (both keys down, then both up) each make one keystroke.
    func testHardwareKeysReachTheProgram() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        let strokes: [[Int]] = [[0x04], [0x28], [0x1E], [0x29], [0xE1, 0x1D]] // a, Enter, 1, Esc, Shift+Z.
        for (index, keys) in strokes.enumerated() {
            run(core, frames: 4, keys: keys)
            run(core, frames: 4)
            expectPicture(core, capture, presses: index + 1)
        }
        core.stop()
    }

    /// Touchpad mode: a finger held still for half a second is the left button, down until it lifts.
    func testAHeldFingerIsTheLeftMouseButton() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        expectPicture(core, capture, button: true, finger: true, pace: 0.01, budget: 300)
        expectPicture(core, capture, button: false, budget: 120)
        core.stop()
    }

    func testAudioIsTheSpeakerTone() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        capture.left = []
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 48000)
        XCTAssertEqual(capture.channels, 2)
        XCTAssertEqual(Double(capture.left.count), 120 * 48000 / 60, accuracy: 120 * 48000 / 60 * 0.1)
        let tone = capture.left.dropFirst(capture.left.count / 4)
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
        XCTAssertEqual(hertz, DOSTestCOM.toneHertz, accuracy: DOSTestCOM.toneHertz * 0.05)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        press(core, GAGA_BTN_START)
        run(core, frames: 240, finger: true)
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    /// Sideload JIT (docs/04 section 8.1): a DevJIT build on a device, run with TEST_RUNNER_GAGA_JIT_TEST=1, with a
    /// debugger that serves Cores/shared/Jit26.c (scripts/jit26_lldb.py or StikDebug's universal.js). Waits up to
    /// 120 s for that debugger, then expects the program drawn by the dynamic core: new anonymous executable pages.
    func testDynamicCoreRunsTheProgramUnderADebugger() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GAGA_JIT_TEST"] == "1", "a DevJIT device run only")
        func debugged() -> Bool {
            var flags: UInt32 = 0
            return dosboxJitTestCsops(getpid(), 0, &flags, MemoryLayout<UInt32>.size) == 0 && flags & 0x1000_0000 != 0 // CS_DEBUGGED
        }
        let deadline = Date().addingTimeInterval(120)
        while !debugged() && Date() < deadline { try await Task.sleep(for: .seconds(1)) }
        try XCTSkipUnless(debugged(), "no debugger attached")
        setenv("GAGA_JIT", "1", 1)
        defer { setenv("GAGA_JIT", "0", 1) }
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        press(core, GAGA_BTN_START)
        expectPicture(core, capture, presses: 1)
        XCTAssertFalse(CodeGenCheck.violations().isEmpty, "no JIT code pages: the core fell back to the interpreter")
        core.stop()
    }

    /// Each session starts from its own file, also after another file ran in the same process.
    func testSessionPerLaunchIsFreshEachTime() async throws {
        let other = directory.appendingPathComponent("second.com")
        try DOSTestCOM.build().write(to: other)
        for (path, boots) in [(romPath!, 1), (other.path, 1), (romPath!, 2)] {
            let (core, capture) = try await loaded(path: path)
            expectPicture(core, capture, boots: boots)
            core.stop()
        }
        XCTAssertEqual(try Data(contentsOf: driveC("second.com").appendingPathComponent("GAGA.DAT")), Data([1]),
                       "the second file has its own C:")
    }

    func testAMissingFileGivesAMessageForThePlayer() async throws {
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: directory.appendingPathComponent("gone.com").path)
            XCTFail("loaded a missing file")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The game file could not be opened.")
        }
        core.stop()
    }

    // MARK: - Battery saves

    /// The program counts its boots in C:\GAGA.DAT, which is <save dir>/DOS/<file name>/GAGA.DAT.
    func testFilesTheProgramWritesSurviveARestart() async throws {
        for boot in 1...3 {
            let (core, capture) = try await loaded()
            expectPicture(core, capture, boots: boot)
            core.flushBatterySave()
            XCTAssertEqual(try? Data(contentsOf: driveC().appendingPathComponent("GAGA.DAT")), Data([UInt8(boot)]),
                           "on disk when the flush returns, boot \(boot)")
            core.stop()
        }
        let leftovers = try FileManager.default.subpathsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [])
    }

    /// ZIP content keeps upstream's save file: what the program writes goes to <save dir>/<name>.pure.zip,
    /// and the archive itself is never changed.
    func testZipContentWritesToItsSaveFile() async throws {
        let program = DOSTestCOM.build()
        let archive = directory.appendingPathComponent("zipped.zip")
        // AUTOBOOT.DBP picks the program, so DOSBox Pure skips its start menu.
        try zip(["GAGA.COM", "AUTOBOOT.DBP"], contents: [program, Data("C:\\GAGA.COM".utf8)]).write(to: archive)
        let before = try Data(contentsOf: archive)
        for boot in 1...2 {
            let (core, capture) = try await loaded(path: archive.path)
            expectPicture(core, capture, boots: boot)
            core.flushBatterySave()
            XCTAssertTrue(CoreCatalog.zipEntryNames(directory.appendingPathComponent("zipped.pure.zip"))
                .contains { $0.uppercased() == "GAGA.DAT" }, "in the save file when the flush returns, boot \(boot)")
            core.stop()
        }
        XCTAssertEqual(try Data(contentsOf: archive), before)
    }

    // MARK: - Save states

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<Self.headerSize + 4]), [0x47, 0x57, 0x5B, 0xD0], "DBPSerialize_All's magic")
        XCTAssertEqual(UInt32(state[Self.headerSize + 4]), core.stateVersion)
        run(core, frames: 30)
        XCTAssertEqual(try core.saveState().count, state.count, "one size for the whole session")
        core.stop()
    }

    func testRoundTripRestoresTheProgram() async throws {
        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        press(core, GAGA_BTN_START)
        expectPicture(core, capture, presses: 1)
        let state = try core.saveState()
        press(core, GAGA_BTN_START)
        press(core, GAGA_BTN_START)
        expectPicture(core, capture, presses: 3)

        try core.loadState(state)
        expectPicture(core, capture, presses: 1, budget: 30)
        press(core, GAGA_BTN_START)
        expectPicture(core, capture, presses: 2)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        let otherPath = directory.appendingPathComponent("other.com")
        try DOSTestCOM.build().write(to: otherPath)
        let (foreign, foreignCapture) = try await loaded(path: otherPath.path)
        expectPicture(foreign, foreignCapture)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        expectPicture(core, capture)
        press(core, GAGA_BTN_START)
        expectPicture(core, capture, presses: 1)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for DOSBox Pure."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var wrongPayload = state // Past the adapter's checks: DOSBox Pure itself must refuse this one.
        wrongPayload[Self.headerSize] ^= 0xFF
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (wrongPayload, "DOSBox Pure could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
            expectPicture(core, capture, presses: 1, budget: 30)
        }
        press(core, GAGA_BTN_START)
        expectPicture(core, capture, presses: 2)
        core.stop()
    }

    // MARK: - Catalog

    /// A stored ZIP holding files with these names, empty where `contents` has no entry.
    private func zip(_ names: [String], contents: [Data] = []) -> Data {
        var local: [UInt8] = [], central: [UInt8] = []
        func le16(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF)] }
        func le32(_ v: Int) -> [UInt8] { le16(v & 0xFFFF) + le16(v >> 16) }
        func crc32(_ data: [UInt8]) -> Int {
            var crc: UInt32 = 0xFFFF_FFFF
            for byte in data {
                crc ^= UInt32(byte)
                for _ in 0..<8 { crc = crc & 1 != 0 ? crc >> 1 ^ 0xEDB8_8320 : crc >> 1 }
            }
            return Int(~crc)
        }
        for (index, name) in names.enumerated() {
            let bytes = [UInt8](name.utf8)
            let data = index < contents.count ? [UInt8](contents[index]) : []
            let crc = crc32(data), size = data.count
            let offset = local.count
            local += le32(0x0403_4B50) + le16(10) + le16(0) + le16(0) + le32(0) + le32(crc) + le32(size) + le32(size)
                + le16(bytes.count) + le16(0) + bytes + data
            central += le32(0x0201_4B50) + le16(10) + le16(10) + le16(0) + le16(0) + le32(0) + le32(crc) + le32(size)
                + le32(size) + le16(bytes.count) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0) + le32(offset) + bytes
        }
        let end = le32(0x0605_4B50) + le16(0) + le16(0) + le16(names.count) + le16(names.count)
            + le32(central.count) + le32(local.count) + le16(0)
        return Data(local + central + end)
    }

    func testCatalogTellsDOSFilesFromPlayStationOnes() throws {
        func platform(_ name: String, _ data: Data) throws -> String? {
            let url = directory.appendingPathComponent(name)
            try data.write(to: url)
            return CoreCatalog.platformID(forFile: url)
        }
        XCTAssertEqual(try platform("psx.exe", PS1TestEXE.build()), "ps1", "PS-X EXE magic")
        XCTAssertEqual(try platform("dos.exe", Data("MZ".utf8) + Data(count: 62)), "dos")
        XCTAssertEqual(try platform("tiny.exe", Data([0xC3])), "dos", "shorter than the magic")
        XCTAssertEqual(try platform("prog.com", DOSTestCOM.build()), "dos")
        XCTAssertEqual(try platform("game.zip", zip(["README.TXT", "GAME/START.EXE"])), "dos")
        XCTAssertEqual(try platform("run.zip", zip(["RUN.BAT"])), "dos")
        XCTAssertEqual(try platform("arcade.zip", zip(["rom.bin", "rom2.bin"])), "arcade", "no DOS program, ROM-like names")
        XCTAssertNil(try platform("broken.zip", Data("PK".utf8)))
        XCTAssertEqual(CoreCatalog.platformID(forFile: directory.appendingPathComponent("gone.exe")), "dos")
        for ext in ["com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf"] {
            XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "dos", ext)
        }
        for ext in ["iso", "cue"] { XCTAssertNil(CoreCatalog.platformID(forExtension: ext), "placed by content, \(ext)") }
        XCTAssertEqual(try platform("dos.iso", Data(count: 4096)), "dos")
        XCTAssertEqual(CoreCatalog.zipEntryNames(directory.appendingPathComponent("game.zip")), ["README.TXT", "GAME/START.EXE"])
    }

    @MainActor
    func testUploadedGamesPickThisCore() async throws {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() } // Leaves no upload- entry in the saved Library.
        for ext in ["com", "bat", "dosz", "exe"] {
            let name = "upload-\(UUID().uuidString).\(ext)"
            await state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, "dos", ext)
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "dosbox_pure", ext)
        }
        let psx = directory.appendingPathComponent("psx.exe")
        try PS1TestEXE.build().write(to: psx)
        XCTAssertEqual(state.importROM(at: psx)?.resolvedCoreID(defaults: [:]), "pcsx_rearmed")
    }

    // MARK: - Debug launch arguments

    /// `-GagaBenchmarkCore dosbox_pure` with no ROM: the generated DOS program and a record named for this core.
    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "dos", to: directory)
        XCTAssertEqual(rom.pathExtension, "com")
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "dos", romPath: rom.path, coverPath: nil,
                            coreOverride: "dosbox_pure", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
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
        XCTAssertTrue(url.lastPathComponent.hasPrefix("dosbox_pure-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "dosbox_pure")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 30)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    /// `-GagaImportROM <path>`: copied into the ROM folder, added once however often the app relaunches.
    @MainActor
    func testDebugImportAddsTheGameOnce() async throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).com")
        try DOSTestCOM.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try await state.importDebugROM(at: source)
        try await state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "dos")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "dosbox_pure")
        XCTAssertEqual(try Data(contentsOf: dest), try Data(contentsOf: source))
    }
}
