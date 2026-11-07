import XCTest
@testable import GagaEmu

/// PCSX-ReARMed through the shared libretro adapter and the real bridge, running the generated homebrew
/// program (`PS1TestEXE`) on the core's HLE BIOS. No Sony BIOS is in the system folder.
final class PcsxReArmedCoreTests: GagaTestCase {
    private var directory: URL!
    private var exePath: String!
    private let interface = GagaCoreRegistry_FindByID("pcsx_rearmed")!.pointee

    /// The bands in 5 bits per channel: red, green, blue, white.
    private static let colors: [(r: UInt16, g: UInt16, b: UInt16)] = [(31, 0, 0), (0, 31, 0), (0, 0, 31), (31, 31, 31)]
    private static let headerSize = 16
    /// The pad's bit order, as the bridge's buttons.
    private static let padOrder: [GagaButtonMask] = [
        GAGA_BTN_SELECT, GAGA_BTN_L3, GAGA_BTN_R3, GAGA_BTN_START, GAGA_BTN_UP, GAGA_BTN_RIGHT, GAGA_BTN_DOWN, GAGA_BTN_LEFT,
        GAGA_BTN_L2, GAGA_BTN_R2, GAGA_BTN_L1, GAGA_BTN_R1, GAGA_BTN_NORTH, GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_WEST,
    ]
    private static let cardCounter = PS1TestEXE.cardSector * 128 + PS1TestEXE.cardCounterOffset

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("pcsx_rearmed"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("pcsx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let exe = directory.appendingPathComponent("homebrew.exe")
        try PS1TestEXE.build().write(to: exe)
        exePath = exe.path
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
        try await core.loadROM(path: path ?? exePath)
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, counter: Int = 1,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(capture.width, PS1TestEXE.width, file: file, line: line)
        XCTAssertEqual(capture.height, PS1TestEXE.height, file: file, line: line)
        guard capture.width == PS1TestEXE.width, capture.height == PS1TestEXE.height else { return }
        var wrong = 0
        for y in 0..<PS1TestEXE.height {
            for x in 0..<PS1TestEXE.width {
                let want = Self.colors[PS1TestEXE.expectedColor(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, counter: counter)]
                let got = capture.pixel(x: x, y: y)
                if got != want { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture", file: file, line: line)
    }

    private let chord = UInt32(GAGA_BTN_EAST.rawValue | GAGA_BTN_SOUTH.rawValue) // Circle and Cross.

    /// Press and release Circle and Cross, then leave frames for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    // MARK: - Program generator

    func testGeneratedEXEIsAPlainPSEXE() {
        let exe = [UInt8](PS1TestEXE.build())
        XCTAssertEqual(Array(exe[0..<8]), Array("PS-X EXE".utf8))
        func word(_ offset: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(exe[offset + $1]) << ($1 * 8) } }
        XCTAssertEqual(word(0x10), 0x8001_0000, "pc0")
        XCTAssertEqual(word(0x18), 0x8001_0000, "t_addr")
        XCTAssertEqual(Int(word(0x1C)), exe.count - 2048, "t_size")
        XCTAssertEqual(exe.count % 2048, 0)
        XCTAssertTrue(exe[0x4C..<0x800].allSatisfy { $0 == 0 }, "no region marker text in the header")
    }

    func testGeneratedDiscIsISO9660WithASystemCNF() {
        let disc = [UInt8](PS1TestEXE.disc().bin)
        XCTAssertEqual(disc.count % 2352, 0)
        func data(_ sector: Int) -> ArraySlice<UInt8> { disc[(sector * 2352 + 24)..<(sector * 2352 + 24 + 2048)] }
        XCTAssertEqual(Array(data(16).dropFirst().prefix(5)), Array("CD001".utf8))
        XCTAssertTrue(String(decoding: data(20), as: UTF8.self).hasPrefix("BOOT = cdrom:\\PSX.EXE;1"))
        XCTAssertEqual(Array(data(21).prefix(8)), Array("PS-X EXE".utf8))
        XCTAssertEqual(Array(disc[(16 * 2352 + 12)..<(16 * 2352 + 16)]), [0x00, 0x02, 0x16, 0x02], "MSF 00:02:16, mode 2")
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("pcsx_rearmed")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "r26 7b0e8f8f")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 60, accuracy: 0.001)
        let extensions = Set(String(cString: found.supported_extensions).split(separator: "|").map(String.init))
        XCTAssertTrue(extensions.isSuperset(of: ["cue", "bin", "chd", "m3u", "exe", "iso", "pbp"]))
        // Earlier stubs take "cue" and "bin" first in a lookup by extension; these are this core's alone.
        for ext in ["exe", "m3u", "chd", "pbp", "iso"] {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), "pcsx_rearmed", ext)
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "ps1"), "pcsx_rearmed")
    }

    func testRunsOnTheHLEBIOSAndDrawsTheExpectedPicture() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.pitch, 640)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        core.stop()
        let system = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(Set(system), ["homebrew.exe", "homebrew.sav"], "no BIOS file, and nothing else written")
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        for (bit, button) in Self.padOrder.enumerated() {
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
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertEqual(capture.channels, 2)
        XCTAssertEqual(capture.left.count, 2 * 44100, accuracy: 1500, "735 samples per frame")
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 10000, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 44100)
        XCTAssertEqual(hertz, PS1TestEXE.toneHertz, accuracy: PS1TestEXE.toneHertz * 0.05)
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
        try await core.loadROM(path: exePath)
        core.setSpeed(4)
        core.start()
        try await Task.sleep(for: .milliseconds(500))
        core.pause()
        let frames = core.stats.frames
        XCTAssertGreaterThan(frames, 60, "faster than the 30 frames normal speed gives in this time")
        XCTAssertEqual(Double(frames) / Double(counts.video), 4, accuracy: 0.3, "only the last frame of a tick is drawn")
        XCTAssertEqual(counts.audio, 0)
        core.stop()
    }

    // MARK: - Lifecycle

    /// Each launch is a new core; the memory card counts the boots.
    func testSessionPerLaunchIsFreshEachTime() async throws {
        for boot in 1...10 {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture, counter: boot)
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
        let (again, againCapture) = try await loaded()
        run(again, frames: 12)
        assertPicture(againCapture, counter: 2)
        again.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        core.stop()
        XCTAssertEqual(capture.width, PS1TestEXE.width)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    // MARK: - Discs and playlists

    /// What the Multi-Disc Helper writes for two generated cue and bin discs loads, and the save follows the
    /// playlist's name, so every disc of the game shares one memory card.
    func testMultiDiscPlaylistOfCueSheetsBoots() async throws {
        let disc = PS1TestEXE.disc()
        for number in 1...2 {
            let bin = "Gaga Test (Disc \(number)).bin"
            try disc.bin.write(to: directory.appendingPathComponent(bin))
            try Data(disc.cue(bin).utf8).write(to: directory.appendingPathComponent("Gaga Test (Disc \(number)).cue"))
        }
        let groups = MultiDiscHelper.scan(directory)
        XCTAssertEqual(groups.count, 1)
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(group.discs.map(\.lastPathComponent), ["Gaga Test (Disc 1).cue", "Gaga Test (Disc 2).cue"])
        XCTAssertEqual(group.platform.platformID, "ps1")
        let playlist = try MultiDiscHelper.writePlaylist(for: group, into: directory)

        let (core, capture) = try await loaded(path: playlist.path)
        run(core, frames: 12)
        assertPicture(capture)
        core.stop()
        let card = [UInt8](try Data(contentsOf: directory.appendingPathComponent("Gaga Test.sav")))
        XCTAssertEqual(Int(card[Self.cardCounter]), 1)

        let (single, singleCapture) = try await loaded(path: directory.appendingPathComponent("Gaga Test (Disc 2).cue").path)
        run(single, frames: 12)
        assertPicture(singleCapture)
        single.stop()
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let empty = directory.appendingPathComponent("empty.exe")
        try Data().write(to: empty)
        let noise = directory.appendingPathComponent("noise.exe")
        try Data((0..<0x10000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        let noiseDisc = directory.appendingPathComponent("noise.bin")
        try Data((0..<(2352 * 40)).map { UInt8(truncatingIfNeeded: $0 &* 31) }).write(to: noiseDisc)
        let badSheet = directory.appendingPathComponent("broken.cue")
        try Data("FILE \"gone.bin\" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n".utf8).write(to: badSheet)

        for path in [empty.path, noise.path, noiseDisc.path, badSheet.path, directory.appendingPathComponent("gone.exe").path] {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, "PCSX-ReARMed could not load this game.")
            }
            core.stop()
        }
        let saves = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".sav") }
        XCTAssertEqual(saves, [], "a refused file must not leave a save behind")
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        assertPicture(capture)
        core.stop()
    }

    func testAnUnwritableSaveFolderRefusesToRun() async throws {
        let (core, _) = try makeCore(saveDirectory: "/nonexistent/saves")
        do {
            try await core.loadROM(path: exePath)
            XCTFail("loaded with no way to save")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The save file for this game could not be opened.")
        }
        core.stop()
    }

    // MARK: - Memory card

    func testMemoryCardReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let sector = PS1TestEXE.cardSector * 128
        for boot in 1...3 {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture, counter: boot)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, PS1TestEXE.cardSize)
            XCTAssertEqual(Array(flushed[sector..<(sector + 4)]), PS1TestEXE.cardMagic)
            XCTAssertEqual(Int(flushed[Self.cardCounter]), boot, "on disk when the flush returns")
            XCTAssertEqual(Array(flushed[0..<2]), Array("MC".utf8), "still a formatted card")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[Self.cardCounter]), boot)
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [])
    }

    func testPlayingFlushesWithoutAPause() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let (core, _) = try await loaded()
        let sector = PS1TestEXE.cardSector * 128
        XCTAssertNotEqual(Array([UInt8](try Data(contentsOf: save))[sector..<(sector + 4)]), PS1TestEXE.cardMagic,
                          "created at load, before the program ran")
        run(core, frames: 300)
        XCTAssertEqual(Array([UInt8](try Data(contentsOf: save))[sector..<(sector + 4)]), PS1TestEXE.cardMagic)
        core.stop()
    }

    func testASaveThatDoesNotFitIsNeverOverwritten() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        let foreign = Data(repeating: 0xAB, count: 8192)
        try foreign.write(to: save)
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: exePath)
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
        try await core.loadROM(path: exePath)
        chmod(folder.path, 0o555)
        defer { chmod(folder.path, 0o755) }
        run(core, frames: 12)
        core.flushBatterySave()
        XCTAssertEqual(capture.fatal, "The save file for this game could not be written.")
        chmod(folder.path, 0o755)
        core.flushBatterySave()
        core.stop()
        XCTAssertEqual(Int([UInt8](try Data(contentsOf: folder.appendingPathComponent("homebrew.sav")))[Self.cardCounter]), 1,
                       "the next flush still tries")
    }

    // MARK: - Save states

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<(Self.headerSize + 9)]), Array("STv4 PCSX".utf8))
        let version = (0..<4).reduce(UInt32(0)) { $0 | UInt32(state[Self.headerSize + 32 + $1]) << ($1 * 8) }
        XCTAssertEqual(version, core.stateVersion)
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

        // The flag is only in register s0, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        let otherEXE = directory.appendingPathComponent("other.exe")
        try PS1TestEXE.build().write(to: otherEXE)
        let (foreign, _) = try await loaded(path: otherEXE.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for PCSX-ReARMed."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var wrongVersion = state // Past the adapter's checks: the core itself must refuse this one.
        wrongVersion[Self.headerSize + 32] ^= 0xFF
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (Data(repeating: 0, count: 4096), wrongSize),
            (wrongVersion, "PCSX-ReARMed could not load this save state."),
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

    /// GameShark: 30 writes a byte, 80 a halfword, each frame. Both put a non-zero byte at `cheatAddress`.
    private let byteCode = "300F0000 0001"
    private let halfwordCode = "800F0000 0101"

    func testCheatFormatsHaveTheirEffectAndStop() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        assertPicture(capture)

        try core.addCheat(id: 1, code: byteCode, enabled: true)
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

        try core.addCheat(id: 2, code: " \(halfwordCode.lowercased()) \n\n\(byteCode)\n", enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.setCheat(id: 2, enabled: false)
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()

        let (next, nextCapture) = try await loaded()
        run(next, frames: 12)
        assertPicture(nextCapture, counter: 2)
        next.stop()
    }

    func testBadCodesAreRefusedAndAddNothing() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        let refused = "PCSX-ReARMed does not recognise this code: "
        let cases = [("", "Enter a cheat code."), (" \n ", "Enter a cheat code."),
                     ("ZZZZZZZZ ZZZZ", refused + "ZZZZZZZZ ZZZZ"),
                     ("300F0000", refused + "300F0000"),
                     ("D00F0000 0001", refused + "D00F0000 0001"), // Conditional: it needs the next line.
                     ("\(byteCode)\nnope", refused + "nope")]
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
    func testUploadedGamesPickThisCore() async throws {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() } // Leaves no upload- entry in the saved Library.
        // An .exe is a PS-EXE only by its first bytes (DosboxPureCoreTests), and a disc image by its contents
        // (GagaEmuTests.testDiscImagesArePlacedByContent), so only .pbp goes by name.
        let name = "upload-\(UUID().uuidString).pbp"
        await state.addUploads([name])
        let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
        XCTAssertEqual(added?.platformID, "ps1")
        XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "pcsx_rearmed")
        let disc = PS1TestEXE.disc()
        let bin = directory.appendingPathComponent("upload-\(UUID().uuidString).bin")
        let cue = bin.deletingPathExtension().appendingPathExtension("cue")
        try disc.bin.write(to: bin)
        try Data(disc.cue(bin.lastPathComponent).utf8).write(to: cue)
        XCTAssertEqual(state.importROM(at: cue)?.resolvedCoreID(defaults: [:]), "pcsx_rearmed")
        let playlist = state.importROM(at: URL(fileURLWithPath: "/roms/Gaga.m3u"), platformID: MultiDiscHelper.Platform.ps1.platformID)
        XCTAssertEqual(playlist?.resolvedCoreID(defaults: [:]), "pcsx_rearmed")
    }

    // MARK: - Debug launch arguments

    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "ps1", to: directory)
        XCTAssertEqual(rom.pathExtension, "exe")
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "ps1", romPath: rom.path, coverPath: nil,
                            coreOverride: "pcsx_rearmed", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
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
        XCTAssertTrue(url.lastPathComponent.hasPrefix("pcsx_rearmed-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "pcsx_rearmed")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 60)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    @MainActor
    func testDebugImportAddsTheGameOnce() async throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).exe")
        try PS1TestEXE.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try await state.importDebugROM(at: source)
        try await state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "ps1")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "pcsx_rearmed")
    }
}
