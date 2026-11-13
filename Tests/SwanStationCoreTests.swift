import XCTest
@testable import GagaEmu

@_silgen_name("csops")
private func swanJitTestCsops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

/// SwanStation through the shared libretro adapter and the real bridge, with no Sony BIOS in the system folder,
/// so the core boots the OpenBIOS build it embeds. OpenBIOS does not start `PS1TestEXE`: upstream starts a
/// PS-EXE by patching a Sony BIOS at fixed offsets, and OpenBIOS refuses a disc with no licence sector. So these
/// tests check the bridge contract (boot, picture, sound, memory card, states, cheat parsing) on OpenBIOS's own
/// screen, not the homebrew program's picture. A player's own BIOS runs both.
final class SwanStationCoreTests: GagaTestCase {
    private var directory: URL!
    private var exePath: String!
    private let interface = GagaCoreRegistry_FindByID("swanstation")!.pointee
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("swanstation"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("swanstation-\(UUID().uuidString)")
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
        var format = GagaPixelFormat(rawValue: 99)
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var fatal: String?
    }

    private func makeCore() throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            capture.width = frame.width
            capture.height = frame.height
            capture.format = frame.pixelFormat
            guard let bytes = frame.pixelData else { return }
            capture.pixels = Array(UnsafeRawBufferPointer(start: bytes, count: frame.pitch * frame.height))
        }
        core.onAudioPacket = { packet in
            capture.sampleRate = packet.sampleRate
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
        try await core.loadROM(path: exePath)
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    func testRegistryResolvesTheRealCoreAsAnAlternate() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("swanstation")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.0.0 631f0fb3")
        XCTAssertEqual(found.native_sample_rate, 44100)
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.platform("ps1")?.cores.last?.id, "swanstation")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "ps1"), "pcsx_rearmed", "an alternate, never the default")
        let game = GameItem(id: UUID(), title: "t", platformID: "ps1", romPath: exePath, coverPath: nil, coreOverride: "swanstation",
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "swanstation", "picked per game through core switching")
    }

    /// OpenBIOS's shell draws a moving picture and plays sound, from the software renderer.
    func testOpenBIOSBootsWithNoBIOSFile() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565)
        XCTAssertGreaterThan(capture.width, 0)
        let first = capture.pixels
        XCTAssertGreaterThan(Set(stride(from: 0, to: first.count - 1, by: 2).map { UInt16(first[$0]) | UInt16(first[$0 + 1]) << 8 }).count, 2,
                             "not one flat colour")
        run(core, frames: 4)
        XCTAssertNotEqual(capture.pixels, first, "the picture moves")
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertGreaterThan(Int(capture.left.max()!) - Int(capture.left.min()!), 5000, "not silent")
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        try core.loadState(try core.saveState())
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    /// Sideload JIT (docs/04 section 8.1): a DevJIT build on a device, run with TEST_RUNNER_GAGA_JIT_TEST=1, with a
    /// debugger that serves Cores/shared/Jit26.c. Waits up to 120 s for it, then expects OpenBIOS's moving screen
    /// from the AArch64 recompiler: new anonymous executable pages. Skips everywhere else, the simulator included.
    func testRecompilerRunsOpenBIOSUnderADebugger() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GAGA_JIT_TEST"] == "1", "a DevJIT device run only")
        func debugged() -> Bool {
            var flags: UInt32 = 0
            return swanJitTestCsops(getpid(), 0, &flags, MemoryLayout<UInt32>.size) == 0 && flags & 0x1000_0000 != 0 // CS_DEBUGGED
        }
        let deadline = Date().addingTimeInterval(120)
        while !debugged() && Date() < deadline { try await Task.sleep(for: .seconds(1)) }
        try XCTSkipUnless(debugged(), "no debugger attached")
        setenv("GAGA_JIT", "1", 1)
        defer { setenv("GAGA_JIT", "0", 1) }
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertNil(capture.fatal)
        let first = capture.pixels
        run(core, frames: 4)
        XCTAssertNotEqual(capture.pixels, first, "the picture moves")
        XCTAssertGreaterThan(Int(capture.left.max()!) - Int(capture.left.min()!), 5000, "not silent")
        try core.loadState(try core.saveState())
        run(core, frames: 4)
        XCTAssertNil(capture.fatal)
        XCTAssertFalse(CodeGenCheck.violations().isEmpty, "no JIT code pages: the core fell back to the interpreter")
        core.stop()
    }

    /// SwanStation loads by path and has no is_rom, so the adapter never opens the file and upstream's refusal is
    /// the message.
    func testBadFilesGiveAMessageForThePlayer() async throws {
        let noise = directory.appendingPathComponent("noise.exe")
        try Data((0..<0x8000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        for path in [noise.path, directory.appendingPathComponent("gone.exe").path] {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, "SwanStation could not load this game.")
            }
            core.stop()
        }
    }

    /// Memory card 1 is RETRO_MEMORY_SAVE_RAM, which the adapter writes to <rom stem>.sav: 128 KB, read back on
    /// the next boot.
    func testMemoryCardSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        var card = [UInt8](repeating: 0, count: 128 * 1024)
        let marker = Array("GAGA".utf8)
        card.replaceSubrange(0x1F000..<(0x1F000 + marker.count), with: marker)
        try Data(card).write(to: save)
        for _ in 1...2 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, 128 * 1024)
            XCTAssertEqual(Array(flushed[0x1F000..<(0x1F000 + marker.count)]), marker)
            core.stop()
        }
    }

    func testStateRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 60)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        let first = capture.pixels
        try core.loadState(state)
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        XCTAssertEqual(capture.pixels, first, "the same input from the same state gives the same frame")

        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var damaged = state
        for index in Self.headerSize..<(Self.headerSize + 32) { damaged[index] ^= 0x5A }
        let cases: [(Data, String)] = [
            (wrongMagic, "This save state belongs to another game or another version of this game."),
            (state.prefix(state.count - 1), "This save state is the wrong size for SwanStation."),
            (damaged, "SwanStation could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) { XCTAssertEqual($0.localizedDescription, message) }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
        }
        core.stop()
    }

    /// Standalone GameShark lines are taken; conditional codes, which act on the next line, and malformed ones
    /// are refused.
    func testCheatsAreTakenAndBadCodesAreRefused() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        try core.addCheat(id: 1, code: "800F0000 0001", enabled: true)
        run(core, frames: 3)
        core.removeCheat(id: 1)
        run(core, frames: 3)
        for code in ["D00F0000 0001", "800F0000", String(repeating: "A", count: 300)] {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: code, enabled: true))
        }
        XCTAssertNil(capture.fatal)
        core.stop()
    }
}
