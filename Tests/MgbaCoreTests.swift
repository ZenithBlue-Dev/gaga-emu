import GameController
import Metal
import UIKit
import XCTest
@testable import GagaEmu

/// mGBA through the real bridge, running the generated homebrew ROM (`GBATestROM`).
final class MgbaCoreTests: GagaTestCase {
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

    private func assertPicture(_ capture: Capture, keys: UInt32, toggle: Bool = false, cheat: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        var wrong = 0
        for y in 0..<GBATestROM.height {
            for x in 0..<GBATestROM.width {
                let want = GBATestROM.rgb8(GBATestROM.expectedColor(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat))
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
    func testUploadedFilesReachTheLibraryOnce() async {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() } // Leaves no upload- entry in the saved Library.
        let name = "upload-\(UUID().uuidString).gba"
        await state.addUploads([name])
        await state.addUploads([name])
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

    func testBenchmarkInputPressesButtonsAtTheirSecond() throws {
        let presses = try XCTUnwrap(BenchmarkRun.parseInput("start@8, Cross@12.5"))
        let start = UInt32(GAGA_BTN_START.rawValue), cross = UInt32(GAGA_BTN_SOUTH.rawValue)
        XCTAssertEqual(presses.map(\.frame), [480, 750])
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 479, presses: presses) & start, 0)
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 480, presses: presses) & start, start)
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 489, presses: presses) & start, start)
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 490, presses: presses) & start, 0)
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 755, presses: presses) & cross, cross)
        XCTAssertEqual(BenchmarkRun.scriptedButtons(frame: 7, presses: []), BenchmarkRun.scriptedButtons(frame: 7), "no arg, same script")
        for bad in ["", "start", "jump@3", "start@-1", "start@x"] { XCTAssertNil(BenchmarkRun.parseInput(bad), bad) }
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
        let png = url.deletingPathExtension().appendingPathExtension("png")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: png)
        }
        XCTAssertNotNil(UIImage(contentsOfFile: png.path), "the run's last frame beside the record")
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertGreaterThan(try XCTUnwrap((record["video"] as? [String: Any])?["framesWritten"] as? Int), 0)
        #if targetEnvironment(simulator)
        XCTAssertEqual(record["label"] as? String, "simulator, not a performance measure")
        #else
        XCTAssertEqual(record["label"] as? String, "measured")
        #endif
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(try XCTUnwrap(record["fps"] as? Double), 59.7275, accuracy: 6)
        XCTAssertEqual(record["interrupted"] as? Bool, false)
        XCTAssertNil(record["interruption"], "a reason only for an interrupted run")
        XCTAssertEqual(record["filter"] as? String, "original")
        XCTAssertEqual(record["filterOnOutputTexture"] as? Bool, false)
        XCTAssertEqual((record["rom"] as? [String: Any])?["sha256"] as? String,
                       SHA256Hex(try Data(contentsOf: URL(fileURLWithPath: romPath))))
        for key in ["device", "os", "appBuild", "buildCommit", "core", "coreCPUMsPerFrame", "frameIntervalMs", "fps1PercentLow",
                    "threadCPUPercentOfOneCore", "memory", "thermal", "audio", "video", "inputScript", "codeGenViolations",
                    "startupSlowFrames"] {
            XCTAssertNotNil(record[key], key)
        }
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    // MARK: - Audio replacement

    /// Our blip buffer must carry the tone and not add its own. A square wave has no even harmonics.
    func testResampledAudioIsACleanTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        core.stop()
        let tone = capture.left.dropFirst(capture.left.count / 2).map(Double.init)
        let mean = tone.reduce(0, +) / Double(tone.count)
        func power(_ hertz: Double) -> Double {
            let w = 2 * Double.pi * hertz / 32768
            var previous = 0.0, older = 0.0
            for sample in tone {
                (previous, older) = (sample - mean + 2 * cos(w) * previous - older, previous)
            }
            return previous * previous + older * older - 2 * cos(w) * previous * older
        }
        let fundamental = power(GBATestROM.toneHertz)
        XCTAssertGreaterThan(fundamental, 0)
        XCTAssertLessThan(power(GBATestROM.toneHertz * 2), fundamental * 0.02, "no even harmonic")
        XCTAssertLessThan(power(GBATestROM.toneHertz * 1.37), fundamental * 0.02, "nothing between harmonics")
    }

    // MARK: - Save states

    private let chord = UInt32(GAGA_BTN_L1.rawValue | GAGA_BTN_R1.rawValue)

    /// Press and release the L and R chord, then leave a frame for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(state.prefix(4).reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }, core.stateVersion)
        core.stop()
    }

    func testRoundTripPlaysBackExactlyAndRestoresTheCPU() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        assertPicture(capture, keys: 0, toggle: true)
        let state = try core.saveState()

        // The same scripted input from the same state must give the same frames, byte for byte.
        func script() -> [[UInt8]] {
            (0..<30).map { frame in
                run(core, frames: 1, buttons: frame % 7 == 0 ? UInt32(GAGA_BTN_EAST.rawValue) : frame == 15 ? chord : 0)
                return capture.pixels
            }
        }
        let first = script()
        assertPicture(capture, keys: 0, toggle: false)
        try core.loadState(state)
        let second = script()
        XCTAssertEqual(first, second)

        // The flag is only in r6, so this proves CPU registers came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, keys: 0, toggle: true)
        flipToggle(core)
        assertPicture(capture, keys: 0, toggle: false)
        core.stop()
    }

    func testBadFilesAreRefusedBeforeACoreSeesThem() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let payload = try core.saveState()
        core.stop()
        let version = interface.state_version
        let good = SaveStateFile.encode(payload: payload, coreID: "mgba", stateVersion: version)
        XCTAssertEqual(try SaveStateFile.decode(good, coreID: "mgba", stateVersion: version), payload)

        func assertRefused(_ file: Data, _ expected: SaveStateError, line: UInt = #line) {
            XCTAssertThrowsError(try SaveStateFile.decode(file, coreID: "mgba", stateVersion: version), line: line) {
                XCTAssertEqual($0 as? SaveStateError, expected, line: line)
            }
        }
        var flipped = good
        flipped[flipped.count - 100] ^= 0x40
        assertRefused(flipped, .damaged)
        var hashHit = good
        hashHit[60] ^= 1
        assertRefused(hashHit, .damaged)
        assertRefused(good.prefix(good.count - 1), .incomplete)
        assertRefused(good.prefix(SaveStateFile.headerSize), .incomplete)
        assertRefused(good.prefix(20), .incomplete)
        assertRefused(good + [0], .incomplete)
        assertRefused(Data(), .notAState)
        assertRefused(Data("GAGA".utf8), .notAState)
        assertRefused(Data(repeating: 0x41, count: 4096), .notAState)
        assertRefused(SaveStateFile.encode(payload: payload, coreID: "mock", stateVersion: version), .otherCore("mock"))
        assertRefused(SaveStateFile.encode(payload: payload, coreID: "mgba", stateVersion: version + 1), .otherVersion)
        var format = good
        format[8] = 9
        assertRefused(format, .otherVersion)
    }

    /// Past the host's checks, the core must refuse too, and the game must carry on exactly where it was.
    func testCoreRefusesBadStatesAndTheGameKeepsRunning() async throws {
        let otherROM = directory.appendingPathComponent("other.gba")
        var other = [UInt8](GBATestROM.build())
        other[other.count - 1] = 0x55
        try Data(other).write(to: otherROM)
        let foreign = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        try await foreign.loadROM(path: otherROM.path)
        foreign.step(inputs: [GagaInputState()])
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()
        var wrongVersion = state
        wrongVersion[0] ^= 0xFF

        let mock = MockCore_GetInterface()!.pointee
        let mockCore = try GagaCoreWrapper(interface: mock, systemDirectory: directory.path, saveDirectory: directory.path)
        let mockState = try mockCore.saveState()
        mockCore.stop()

        let cases: [(Data, String)] = [
            (otherGame, "This save state belongs to another game or another version of this game."),
            (mockState, "This save state is the wrong size for mGBA."),
            (state.prefix(state.count - 1), "This save state is the wrong size for mGBA."),
            (Data(), "This save state is the wrong size for mGBA."),
            (wrongVersion, "This save state belongs to another game or another version of this game."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertPicture(capture, keys: 0, toggle: true)
        }
        flipToggle(core)
        assertPicture(capture, keys: 0, toggle: false)
        core.stop()
    }

    // MARK: - Files

    func testAtomicWriteLeavesTheOldFileOnFailure() throws {
        let folder = directory.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("state")
        try AtomicFile.write(Data("old".utf8), to: file)
        try AtomicFile.write(Data("new".utf8), to: file)
        XCTAssertEqual(try Data(contentsOf: file), Data("new".utf8))

        chmod(folder.path, 0o555)
        defer { chmod(folder.path, 0o755) }
        XCTAssertThrowsError(try AtomicFile.write(Data("broken".utf8), to: file))
        XCTAssertEqual(try Data(contentsOf: file), Data("new".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["state"], "no temp file left")

        // Rename fails because the target is a folder: the temp file must not survive that either.
        chmod(folder.path, 0o755)
        let blocked = folder.appendingPathComponent("blocked")
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        XCTAssertThrowsError(try AtomicFile.write(Data("x".utf8), to: blocked))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(), ["blocked", "state"])
    }

    func testStoreListsWholeSlotsAndClearsAKilledWrite() throws {
        let store = SaveStore(directory: directory.appendingPathComponent("store"))
        XCTAssertEqual(store.slots(), [])
        let one = try store.writeState(Data("a".utf8), thumbnail: Data("png".utf8), auto: false)
        try store.writeState(Data("b".utf8), thumbnail: nil, auto: true)
        try store.writeState(Data("c".utf8), thumbnail: nil, auto: true)
        XCTAssertEqual(store.slots().count, 2, "one auto slot, overwritten")
        XCTAssertEqual(store.manualCount, 1)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(store.autoSlot).url), Data("c".utf8))

        let leftover = one.url.deletingLastPathComponent().appendingPathComponent(".state.tmp-1")
        try Data("half".utf8).write(to: leftover)
        XCTAssertEqual(store.slots().count, 2, "a killed write is not a slot")
        try store.writeState(Data("d".utf8), thumbnail: nil, auto: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftover.path), "the next write clears it")

        try store.delete(one)
        XCTAssertFalse(FileManager.default.fileExists(atPath: one.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: one.thumbnailURL.path))
        XCTAssertEqual(store.manualCount, 1)

        try store.saveCheats([CheatEntry(id: 1, name: "n", code: "c", enabled: true)])
        try Data("sav".utf8).write(to: store.directory.appendingPathComponent("game.sav"))
        XCTAssertEqual(store.batterySaves().map(\.lastPathComponent), ["game.sav"], "only what the game wrote is exported")
    }

    // MARK: - Fast-forward

    func testFastForwardRunsWholeFramesDrawsTheLastAndDropsAudio() async throws {
        let (core, _) = try makeCore()
        final class Counts { var video = 0, audio = 0 }
        let counts = Counts()
        core.onVideoFrame = { _ in counts.video += 1 }
        core.onAudioPacket = { _ in counts.audio += 1 }
        try await core.loadROM(path: romPath)
        core.setSpeed(3)
        core.start()
        try await Task.sleep(for: .milliseconds(500))
        core.pause()
        let fastFrames = core.stats.frames
        XCTAssertGreaterThan(fastFrames, 45, "faster than the 30 frames normal speed gives in this time")
        XCTAssertEqual(fastFrames, counts.video * 3, "only the last frame of a tick is drawn")
        XCTAssertEqual(counts.audio, 0, "audio is dropped, so its ring cannot back up")

        core.setSpeed(1)
        counts.video = 0
        core.resume()
        try await Task.sleep(for: .milliseconds(300))
        core.pause()
        XCTAssertEqual(core.stats.frames - fastFrames, counts.video, "normal speed draws every frame")
        XCTAssertGreaterThan(counts.audio, 0, "audio comes back")
        core.stop()
    }

    // MARK: - Rewind

    private func enableRewind(_ core: GagaCoreWrapper, policy: RewindPolicy) -> () -> String?? {
        final class Verdict { var value: String?? }
        let verdict = Verdict()
        core.onRewindVerdict = { verdict.value = .some($0) }
        core.enableRewind(policy: policy)
        return { verdict.value }
    }

    func testRewindRestoresAnEarlierFrame() async throws {
        let (core, capture) = try await loaded()
        let verdict = enableRewind(core, policy: RewindPolicy(interval: 1, probeCount: 3))
        run(core, frames: 12)
        XCTAssertEqual(verdict(), .some(nil), "mGBA's state is small and quick, so it qualifies")
        assertPicture(capture, keys: 0, toggle: false)
        flipToggle(core) // Five frames: 13 to 17.
        assertPicture(capture, keys: 0, toggle: true)
        XCTAssertEqual(core.rewindSnapshotCount, 17)

        // The first step redraws frame 17; each one after goes back a frame. Six reach frame 12, before the flip.
        for _ in 0..<6 { XCTAssertTrue(core.stepBackward()) }
        assertPicture(capture, keys: 0, toggle: false)
        XCTAssertEqual(core.rewindSnapshotCount, 11)

        // Play goes on from there, and the toggle still works, so the CPU came back whole.
        flipToggle(core)
        assertPicture(capture, keys: 0, toggle: true)
        core.stop()
    }

    func testRewindRunsOutAtTheOldestSnapshot() async throws {
        let (core, _) = try await loaded()
        _ = enableRewind(core, policy: RewindPolicy(interval: 2, probeCount: 1))
        run(core, frames: 8)
        XCTAssertEqual(core.rewindSnapshotCount, 4, "one every second frame")
        for _ in 0..<4 { XCTAssertTrue(core.stepBackward()) }
        XCTAssertFalse(core.stepBackward(), "nothing older is kept")
        core.stop()
    }

    func testACoreOverTheLimitGetsNoRewind() async throws {
        let (core, capture) = try await loaded()
        let verdict = enableRewind(core, policy: RewindPolicy(maxStateBytes: 1024, interval: 1, probeCount: 3))
        run(core, frames: 6)
        let reason = try XCTUnwrap(verdict() ?? nil, "refused with a reason")
        XCTAssertTrue(reason.contains("rewind limit"), reason)
        XCTAssertEqual(core.rewindSnapshotCount, 0, "no snapshots are taken or kept")
        flipToggle(core)
        XCTAssertFalse(core.stepBackward())
        assertPicture(capture, keys: 0, toggle: true) // Play is untouched.
        core.stop()
    }

    @MainActor
    func testSessionRewindsOnlyWithTheSettingOn() async throws {
        let off = try await mgbaSession(folder: "off")
        try await waitForFrames(off)
        XCTAssertEqual(off.rewindStatus, .off)
        off.setRewindHeld(true)
        XCTAssertFalse(off.rewinding)
        off.stop()

        let on = try await mgbaSession(folder: "on", rewind: true)
        defer { on.stop() }
        try await waitForFrames(on)
        for _ in 0..<100 where on.rewindStatus != .ready { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(on.rewindStatus, .ready)
        on.setRewindHeld(true)
        XCTAssertTrue(on.rewinding)
        on.setRewindHeld(false)
        XCTAssertFalse(on.rewinding)
    }

    // MARK: - Cheats

    private func codes(_ value: UInt32) -> [String] {
        let address = GBATestROM.cheatAddress
        func tea(_ first: UInt32, _ second: UInt32, _ seeds: [UInt32]) -> String {
            var a = first, b = second, sum: UInt32 = 0
            for _ in 0..<32 {
                sum &+= 0x9E3779B9
                a &+= ((b << 4) &+ seeds[0]) ^ (b &+ sum) ^ ((b >> 5) &+ seeds[1])
                b &+= ((a << 4) &+ seeds[2]) ^ (a &+ sum) ^ ((a >> 5) &+ seeds[3])
            }
            return String(format: "%08X %08X", a, b)
        }
        return [
            String(format: "%08X:%02X", address, value), // VBA.
            String(format: "3%07X %04X", address, value), // CodeBreaker.
            tea(address, value, [0x09F4FBBD, 0x9681884A, 0x352027E9, 0xF3DEE5A7]), // GameShark.
            tea(0x00200000, value, [0x7AA9648F, 0x7FAE6994, 0xC0EFAAD5, 0x42712C57]), // Action Replay.
        ]
    }

    func testEveryCodeFormatWorks() async throws {
        for code in codes(1) {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture, keys: 0)
            try core.addCheat(id: 1, code: code, enabled: true)
            run(core, frames: 3)
            XCTAssertEqual(capture.pixel(x: 20, y: 10).g, 0xFF, "\(code) has no effect")
            assertPicture(capture, keys: 0, cheat: true)
            core.stop()
        }
    }

    func testCheatsSwitchOffAndComeOut() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        try core.addCheat(id: 1, code: codes(1)[0], enabled: false)
        run(core, frames: 3)
        assertPicture(capture, keys: 0)
        core.setCheat(id: 1, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, keys: 0, cheat: true)
        core.setCheat(id: 1, enabled: false)
        run(core, frames: 3)
        assertPicture(capture, keys: 0)
        core.setCheat(id: 1, enabled: true)
        core.removeCheat(id: 1)
        run(core, frames: 3)
        assertPicture(capture, keys: 0)
        core.removeCheat(id: 99) // Unknown IDs are harmless.
        core.setCheat(id: 99, enabled: true)
        try core.addCheat(id: 2, code: "\(codes(0)[0])\n\(codes(1)[0])", enabled: true)
        run(core, frames: 3)
        assertPicture(capture, keys: 0, cheat: true)
        core.stop()
    }

    func testInvalidCodesGetAMessageAndAddNothing() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        let cases = [("", "Enter a cheat code."), ("   \n ", "Enter a cheat code."),
                     ("ZZZZ", "mGBA does not recognise this code: ZZZZ"),
                     ("hello world", "mGBA does not recognise this code: hello world"),
                     ("\(codes(1)[0])\nnope", "mGBA does not recognise this code: nope")]
        for (code, message) in cases {
            XCTAssertThrowsError(try core.addCheat(id: 1, code: code, enabled: true), code) {
                XCTAssertEqual($0.localizedDescription, message)
            }
            run(core, frames: 3)
            assertPicture(capture, keys: 0)
        }
        // The refused ID stays free.
        try core.addCheat(id: 1, code: codes(1)[0], enabled: true)
        run(core, frames: 3)
        assertPicture(capture, keys: 0, cheat: true)
        core.stop()
    }

    // MARK: - Session

    @MainActor
    private func mgbaSession(folder: String = "saves", rewind: Bool = false,
                             entitlements: @escaping @MainActor () -> StoreKitManager.Entitlements = { .effective(.free, gateOpen: false) })
    async throws -> GameSession {
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager(defaults: UserDefaults(suiteName: "session-\(UUID().uuidString)")!)
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Homebrew", platformID: "gba", romPath: romPath, coverPath: nil,
                            coreOverride: "mgba", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let session = try GameSession(game: game, interface: interface, romPath: romPath, audio: AudioEngineManager(),
                                      controllers: controllers, skins: skins, bindings: [], shaderID: "original",
                                      respectSilentMode: false, saveDirectory: directory.appendingPathComponent(folder),
                                      entitlements: entitlements)
        session.rewindEnabled = rewind
        try await session.prepare()
        session.run()
        return session
    }

    @MainActor
    private func waitForFrames(_ session: GameSession, _ count: Int = 15) async throws {
        // No view draws in a test, so stand in for the renderer, which frees a ring slot per drawn frame.
        let queue = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeCommandQueue())
        let target = session.stats.frames + count
        let deadline = Date().addingTimeInterval(10)
        while session.stats.frames < target, Date() < deadline {
            let buffer = try XCTUnwrap(queue.makeCommandBuffer())
            session.ring.attachCompletion(to: buffer)
            buffer.commit()
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertGreaterThanOrEqual(session.stats.frames, target)
    }

    /// RGB at a point of a state's thumbnail.
    private func thumbnailPixel(_ slot: SaveSlot, x: Int, y: Int) throws -> (r: UInt8, g: UInt8, b: UInt8) {
        let image = try XCTUnwrap(UIImage(contentsOfFile: slot.thumbnailURL.path)?.cgImage)
        XCTAssertEqual(image.width, GBATestROM.width)
        XCTAssertEqual(image.height, GBATestROM.height)
        var rgba = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (rgba[0], rgba[1], rgba[2])
    }

    @MainActor
    func testFreeLimitsHoldWithTheGateOpen() async throws {
        let session = try await mgbaSession(entitlements: { .effective(.free, gateOpen: true) })
        defer { session.stop() }
        try await waitForFrames(session)
        for _ in 0..<3 { try session.saveState() }
        XCTAssertThrowsError(try session.saveState()) {
            XCTAssertEqual($0 as? SaveStateError, .limitReached(3))
        }
        XCTAssertEqual(session.saves.manualCount, 3)
        try session.saves.delete(try XCTUnwrap(session.saves.slots().first))
        XCTAssertNoThrow(try session.saveState(), "deleting one frees a slot")

        XCTAssertEqual(session.fastForwardSpeeds, [1, 2])
        session.setFastForward(5)
        XCTAssertEqual(session.fastForward, 2, "clamped to the limit")
        session.toggleFastForward()
        XCTAssertEqual(session.fastForward, 1)
        session.toggleFastForward()
        XCTAssertEqual(session.fastForward, 2)

        let code = codes(1)[0]
        for index in 0..<3 { try session.addCheat(name: "Cheat \(index)", code: code) }
        XCTAssertFalse(session.canAddCheat)
        XCTAssertThrowsError(try session.addCheat(name: "One more", code: code)) {
            XCTAssertEqual($0.localizedDescription, "You have 3 cheats, the most without Gaga Plus. Remove one to add another.")
        }
        XCTAssertEqual(session.cheats.count, 3)
        XCTAssertFalse(StoreKitManager.Entitlements.effective(.free, gateOpen: true).autoSaveState)
    }

    @MainActor
    func testClosedGateLiftsTheLimits() async throws {
        let session = try await mgbaSession()
        defer { session.stop() }
        try await waitForFrames(session)
        for _ in 0..<4 { try session.saveState() }
        XCTAssertEqual(session.saves.manualCount, 4)
        for index in 0..<4 { try session.addCheat(name: "Cheat \(index)", code: codes(1)[0]) }
        XCTAssertEqual(session.fastForwardSpeeds, [1, 2, 3, 5])
        session.setFastForward(5)
        XCTAssertEqual(session.fastForward, 5)
        session.setFastForward(4)
        XCTAssertEqual(session.fastForward, 3, "only offered speeds")
        XCTAssertTrue(StoreKitManager.Entitlements.effective(.free, gateOpen: false).autoSaveState)
    }

    @MainActor
    func testSessionSavesLoadsAndRefusesADamagedFile() async throws {
        let session = try await mgbaSession()
        defer { session.stop() }
        try await waitForFrames(session)
        let slot = try session.saveState()
        XCTAssertFalse(slot.isAuto)
        let red = try thumbnailPixel(slot, x: 120, y: 30)
        XCTAssertEqual([red.r, red.g, red.b], [0xFF, 0, 0], "the thumbnail is the picture")
        XCTAssertEqual(try thumbnailPixel(slot, x: 48, y: 10).r, 0, "and a current one, with the key cells drawn")
        try session.loadState(slot)

        var file = try Data(contentsOf: slot.url)
        file[file.count - 1] ^= 1
        try file.write(to: slot.url)
        let before = session.stats.frames
        XCTAssertThrowsError(try session.loadState(slot)) {
            XCTAssertEqual($0 as? SaveStateError, .damaged)
        }
        try await waitForFrames(session)
        XCTAssertGreaterThan(session.stats.frames, before)
        XCTAssertEqual(session.phase, .running)
    }

    @MainActor
    func testCheatListIsPerGameAndComesBack() async throws {
        let first = try await mgbaSession()
        try await waitForFrames(first)
        XCTAssertThrowsError(try first.addCheat(name: "Bad", code: "ZZZZ"))
        XCTAssertEqual(first.cheats, [], "a refused code is not stored")
        try first.addCheat(name: "On", code: codes(1)[0])
        try first.addCheat(name: "Off", code: "\(codes(2)[0])\n\(codes(2)[0])")
        let off = try XCTUnwrap(first.cheats.last)
        try first.setCheat(off, enabled: false)
        first.stop()

        let second = try await mgbaSession()
        defer { second.stop() }
        XCTAssertEqual(second.cheats.map(\.name), ["On", "Off"])
        XCTAssertEqual(second.cheats.map(\.enabled), [true, false])
        try await waitForFrames(second)
        let slot = try second.saveState()
        XCTAssertEqual(try thumbnailPixel(slot, x: 20, y: 10).g, 0xFF, "the stored cheat is back on in the core")
        try second.removeCheat(try XCTUnwrap(second.cheats.first))
        XCTAssertEqual(second.saves.cheats().map(\.name), ["Off"])
        try await waitForFrames(second)
        XCTAssertEqual(try thumbnailPixel(try second.saveState(), x: 20, y: 10).g, 0)

        let other = try await mgbaSession(folder: "another game")
        defer { other.stop() }
        XCTAssertEqual(other.cheats, [])
    }

    @MainActor
    func testAutoSaveOnQuitAndBackgroundButNotOnFailure() async throws {
        let off = try await mgbaSession(folder: "off")
        try await waitForFrames(off)
        off.stop()
        XCTAssertNil(off.saves.autoSlot, "off by default, so the gate and the toggle decide")

        let failing = try await mgbaSession(folder: "failing")
        failing.autoSaveEnabled = { true }
        try await waitForFrames(failing)
        failing.stop(message: "The core stopped.")
        XCTAssertNil(failing.saves.autoSlot, "a failure must not overwrite a good auto save")

        let session = try await mgbaSession()
        session.autoSaveEnabled = { true }
        try await waitForFrames(session)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        let first = try XCTUnwrap(session.saves.autoSlot)
        XCTAssertEqual(session.saves.manualCount, 0)
        session.stop()
        let second = try XCTUnwrap(session.saves.autoSlot)
        XCTAssertGreaterThanOrEqual(second.date, first.date)

        let resumed = try await mgbaSession()
        defer { resumed.stop() }
        try resumed.loadState(second)
        XCTAssertNil(resumed.notice)
    }

    @MainActor
    func testBatterySaveIsOnDiskWhilePaused() async throws {
        let session = try await mgbaSession()
        defer { session.stop() }
        try await waitForFrames(session)
        session.pause(.menu)
        let file = session.saves.directory.appendingPathComponent("homebrew.sav")
        XCTAssertEqual(Array(try Data(contentsOf: file).prefix(4)), GBATestROM.sramMagic)
        XCTAssertEqual(session.saves.batterySaves().map(\.lastPathComponent), ["homebrew.sav"])
    }

    // MARK: - Controllers

    @MainActor
    func testASilentControllerDoesNotHideTouchAndUnassignPersists() throws {
        let suite = "controllers-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = ControllerManager(defaults: defaults)
        manager.devices = []
        let pad = GCController.withExtendedGamepad()
        manager.attach(pad)
        let device = try XCTUnwrap(manager.devices.first)
        XCTAssertEqual(device.slot, 0)
        XCTAssertTrue(manager.touchOwnsPlayerOne, "connected but silent")
        _ = manager.sample()
        XCTAssertTrue(manager.touchOwnsPlayerOne, "still silent after a read")

        pad.extendedGamepad?.leftThumbstick.xAxis.setValue(0.1)
        _ = manager.sample()
        XCTAssertTrue(manager.touchOwnsPlayerOne, "stick drift is not input")

        pad.extendedGamepad?.buttonA.setValue(1)
        XCTAssertNotEqual(manager.sample()[0].buttons, 0)
        XCTAssertFalse(manager.touchOwnsPlayerOne, "first real input takes over")
        pad.extendedGamepad?.buttonA.setValue(0)
        _ = manager.sample()
        XCTAssertFalse(manager.touchOwnsPlayerOne, "and keeps it")

        manager.assign(device.id, to: nil)
        XCTAssertTrue(manager.touchOwnsPlayerOne)

        let relaunched = ControllerManager(defaults: defaults)
        relaunched.devices = []
        relaunched.attach(GCController.withExtendedGamepad())
        XCTAssertNil(try XCTUnwrap(relaunched.devices.first).slot, "Unassign survives a relaunch")
        relaunched.assign(try XCTUnwrap(relaunched.devices.first).id, to: 0)

        let again = ControllerManager(defaults: defaults)
        again.devices = []
        again.attach(GCController.withExtendedGamepad())
        XCTAssertEqual(try XCTUnwrap(again.devices.first).slot, 0, "assigning clears it")
    }

    @MainActor
    func testControllerPairOpensAndClosesTheMenu() async throws {
        let manager = ControllerManager(defaults: try XCTUnwrap(UserDefaults(suiteName: "pair-\(UUID().uuidString)")))
        manager.devices = []
        let pad = GCController.withExtendedGamepad()
        manager.attach(pad)
        let gamepad = try XCTUnwrap(pad.extendedGamepad)
        gamepad.buttonMenu.setValue(1)
        var state = manager.sample()[0]
        XCTAssertFalse(state.actions.contains(.app(.pauseMenu)), "Menu alone is Start")
        XCTAssertEqual(state.buttons, ControllerManager.Button.start)
        if let options = gamepad.buttonOptions {
            options.setValue(1)
            state = manager.sample()[0]
            XCTAssertTrue(state.actions.contains(.app(.pauseMenu)))
            XCTAssertEqual(state.buttons, 0, "the pair never reaches the game")
        }

        let session = try await mgbaSession()
        defer { session.stop() }
        session.menuPair(held: true)
        XCTAssertTrue(session.menuOpen)
        session.menuPair(held: true)
        XCTAssertTrue(session.menuOpen, "holding does not flicker")
        session.menuPair(held: false)
        XCTAssertTrue(session.menuOpen)
        session.menuPair(held: true)
        XCTAssertFalse(session.menuOpen)
        session.menuPair(held: false)
        XCTAssertEqual(session.phase, .running)
    }
}

import CryptoKit

private func SHA256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
