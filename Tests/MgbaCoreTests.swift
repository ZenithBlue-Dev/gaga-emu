import XCTest
@testable import GagaEmu

/// mGBA through the real bridge, running the generated homebrew ROM (`GBATestROM`).
final class MgbaCoreTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("mgba")!.pointee

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("mgba-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.gba")
        try GBATestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
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

        func pixel(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            let i = y * pitch + x * 4
            return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
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

    private func loaded() async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: romPath)
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    private func assertPicture(_ capture: Capture, keys: UInt32, file: StaticString = #filePath, line: UInt = #line) {
        var wrong = 0
        for y in 0..<GBATestROM.height {
            for x in 0..<GBATestROM.width {
                let want = GBATestROM.rgb8(GBATestROM.expectedColor(x: x, y: y, keys: keys))
                let got = capture.pixel(x: x, y: y)
                if got.r != want.r || got.g != want.g || got.b != want.b || got.a != 0xFF { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture", file: file, line: line)
    }

    // MARK: - ROM generator

    func testGeneratedHeaderChecks() {
        let rom = [UInt8](GBATestROM.build())
        XCTAssertEqual(rom[3], 0xEA, "reset vector is an ARM branch")
        XCTAssertEqual(rom[0xB2], 0x96)
        XCTAssertEqual(rom[0xBD], GBATestROM.headerChecksum(rom))
        XCTAssertEqual((rom[0xA0...0xBD].reduce(0) { $0 + Int($1) } + 0x19) & 0xFF, 0, "header complement sums to zero")
        XCTAssertTrue(rom[0x04..<0xA0].allSatisfy { $0 == 0 }, "no Nintendo logo in the ROM")
        XCTAssertEqual(rom.count.nonzeroBitCount, 1, "power-of-two size")
    }

    @MainActor
    func testUploadedFilesReachTheLibraryOnce() {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved }
        let name = "upload-\(UUID().uuidString).gba"
        state.addUploads([name])
        state.addUploads([name])
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "gba")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "mgba")
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("mgba")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "0.10.5 26b7884b")
        XCTAssertEqual(found.native_sample_rate, 32768)
        XCTAssertEqual(found.target_fps, 59.7275, accuracy: 0.001)
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("gba")).pointee.core_id), "mgba")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
    }

    func testLoadsWithNoBIOSAndDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.width, 240)
        XCTAssertEqual(capture.height, 160)
        XCTAssertEqual(capture.pitch, 960)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGBA8888)
        XCTAssertNil(capture.fatal)
        // Includes the band from SWI 6 and proves VBlankIntrWait returns, because cells draw after it.
        assertPicture(capture, keys: 0)
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        // KEYINPUT order: A, B, Select, Start, Right, Left, Up, Down, R, L. Touch A is the bridge's EAST.
        let order: [GagaButtonMask] = [GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_SELECT, GAGA_BTN_START, GAGA_BTN_RIGHT,
                                       GAGA_BTN_LEFT, GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_R1, GAGA_BTN_L1]
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 3)
        assertPicture(capture, keys: 0)
        core.stop()
    }

    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 32768)
        XCTAssertEqual(capture.channels, 2)
        // About 549 samples per frame, within a packet of rounding.
        XCTAssertEqual(capture.left.count, 120 * 32768 * 280896 / 16777216, accuracy: 1100)
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
        XCTAssertEqual(hertz, GBATestROM.toneHertz, accuracy: GBATestROM.toneHertz * 0.05)
        core.stop()
    }

    func testBatterySaveReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.stop()
            let bytes = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(bytes.count, 32768, "SRAM is 32 KB")
            XCTAssertEqual(Array(bytes[0..<4]), GBATestROM.sramMagic)
            XCTAssertEqual(Int(bytes[GBATestROM.sramBootCounterOffset]), boot)
        }
    }

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let empty = directory.appendingPathComponent("empty.gba")
        try Data().write(to: empty)
        let random = directory.appendingPathComponent("noise.gba")
        try Data((0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: random)
        let cases = [(empty.path, "This file is not a Game Boy Advance game."),
                     (random.path, "This file is not a Game Boy Advance game."),
                     (directory.appendingPathComponent("gone.gba").path, "The game file could not be opened.")]
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

    func testUnwritableSaveFolderRefusesToRun() async throws {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: "/nonexistent/saves")
        do {
            try await core.loadROM(path: romPath)
            XCTFail("loaded with no way to save")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The save file for this game could not be opened.")
        }
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
            assertPicture(capture, keys: 0)
            core.stop()
        }
    }

    // MARK: - No JIT at runtime

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_EAST.rawValue))
        core.stop()
        XCTAssertEqual(capture.width, 240)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    /// Positive control: the check must see real executable memory, or a clean result means nothing.
    func testCodeGenCheckSeesGeneratedRegions() throws {
        CodeGenCheck.captureBaseline()
        let size = 16384
        let page = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0)
        guard let page, page != MAP_FAILED else { throw XCTSkip("no anonymous mapping") }
        defer { munmap(page, size) }
        guard mprotect(page, size, PROT_READ | PROT_EXEC) == 0 else {
            throw XCTSkip("this OS refuses PROT_EXEC here, which is the enforcement the check backs up")
        }
        let found = CodeGenCheck.violations()
        XCTAssertTrue(found.contains { $0.start <= UInt(bitPattern: page) && UInt(bitPattern: page) < $0.start + $0.size },
                      "walker missed an anonymous executable page")
    }

    func testBaselineItselfIsCleanAndDyldRegionsAreOwned() {
        CodeGenCheck.captureBaseline()
        XCTAssertEqual(CodeGenCheck.violations(), [])
        XCTAssertFalse(CodeGenCheck.executableRegions().isEmpty, "the walker found this very code")
    }

    // MARK: - Benchmark

    func testPercentilesUseNearestRank() {
        let p = BenchmarkRun.Percentiles((1...100).map(Double.init))
        XCTAssertEqual(p.p50, 50)
        XCTAssertEqual(p.p95, 95)
        XCTAssertEqual(p.p99, 99)
        XCTAssertEqual(p.max, 100)
        XCTAssertEqual(p.mean, 50.5)
        XCTAssertEqual(BenchmarkRun.Percentiles([]).max, 0)
    }

    func testInputScriptDependsOnlyOnTheFrame() {
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 7), BenchmarkRun.scriptedButtons(frame: 7))
        XCTAssertNotEqual(BenchmarkRun.scriptedButtons(frame: 0), BenchmarkRun.scriptedButtons(frame: 30))
    }

    @MainActor
    func testBenchmarkWritesALabelledRecord() async throws {
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "gba", romPath: romPath, coverPath: nil,
                            coreOverride: "mgba", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let session = try GameSession(game: game, interface: interface, romPath: romPath, audio: AudioEngineManager(),
                                      controllers: controllers, skins: skins, bindings: [], shaderID: "original",
                                      respectSilentMode: false)
        try await session.prepare()
        let run = BenchmarkRun(session: session, interface: interface, romURL: URL(fileURLWithPath: romPath), seconds: 2, warmup: 0.2)
        run.attach()
        var written: URL?
        run.onWritten = { written = $0 }
        session.run()
        await run.drive()
        XCTAssertEqual(session.phase, .stopped)

        let url = try XCTUnwrap(written)
        defer { try? FileManager.default.removeItem(at: url) }
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(record["label"] as? String, "simulator, not a performance measure")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(try XCTUnwrap(record["fps"] as? Double), 59.7275, accuracy: 6)
        XCTAssertEqual(record["interrupted"] as? Bool, false)
        XCTAssertEqual((record["rom"] as? [String: Any])?["sha256"] as? String,
                       SHA256Hex(try Data(contentsOf: URL(fileURLWithPath: romPath))))
        for key in ["device", "os", "appBuild", "buildCommit", "core", "coreCPUMsPerFrame", "frameIntervalMs", "fps1PercentLow",
                    "threadCPUPercentOfOneCore", "memory", "thermal", "audio", "video", "inputScript", "codeGenViolations"] {
            XCTAssertNotNil(record[key], key)
        }
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }
}

import CryptoKit

private func SHA256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
