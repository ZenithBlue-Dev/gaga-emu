import XCTest
@testable import GagaEmu

/// Snes9x, the sideload-only alternate Super Famicom core, through the shared libretro adapter and the real
/// bridge, running the generated homebrew ROM (`SNESTestROM`). No firmware and no commercial game.
/// Device-pending: written against a macOS host run of the same core and adapter, not yet run on the iPhone.
final class Snes9xCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("snes9x")!.pointee
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("snes9x"), "GAGA_CORE_SET left this core out (sideload builds only)")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("snes9x-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.sfc")
        try SNESTestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private final class Capture {
        var pixels: [UInt8] = []
        var width = 0
        var height = 0
        var pitch = 0
        var format = GagaPixelFormat(rawValue: 99)
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var fatal: String?

        /// Each channel as on (above half) or off, from RGB565, the format Snes9x picks.
        func lit(x: Int, y: Int) -> [Bool] {
            let i = y * pitch + x * 2
            let v = UInt16(pixels[i]) | UInt16(pixels[i + 1]) << 8
            return [v >> 15 != 0, (v >> 10) & 1 != 0, (v >> 4) & 1 != 0]
        }
    }

    private func makeCore(saveDirectory: String? = nil) throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: saveDirectory ?? directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            (capture.width, capture.height, capture.pitch, capture.format) = (frame.width, frame.height, frame.pitch, frame.pixelFormat)
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

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        guard capture.width == SNESTestROM.width, capture.height == SNESTestROM.height else {
            return XCTFail("frame is \(capture.width) by \(capture.height)", file: file, line: line)
        }
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565, file: file, line: line)
        var wrong = 0
        for y in 0..<SNESTestROM.height {
            for x in 0..<SNESTestROM.width {
                let color = SNESTestROM.colors[SNESTestROM.expectedShade(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, genie: false)]
                let expected = [color & 0x1F, (color >> 5) & 0x1F, (color >> 10) & 0x1F].map { $0 != 0 }
                if capture.lit(x: x, y: y) != expected { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture", file: file, line: line)
    }

    private let chord = UInt32(GAGA_BTN_EAST.rawValue | GAGA_BTN_SOUTH.rawValue)

    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    func testRegistryResolvesTheRealCoreAsAnAlternate() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("snes9x")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.63 fae2fea0")
        XCTAssertEqual(found.native_sample_rate, 32040)
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.platform("snes")?.cores.map(\.id), ["bsnes", "snes9x"])
        XCTAssertEqual(CoreCatalog.defaultCore(for: "snes"), "bsnes", "an alternate, never the default")
        let game = GameItem(id: UUID(), title: "t", platformID: "snes", romPath: romPath, coverPath: nil, coreOverride: "snes9x",
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "snes9x", "picked per game through core switching")
    }

    func testPictureInputAndSound() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        let order: [GagaButtonMask] = [GAGA_BTN_SOUTH, GAGA_BTN_WEST, GAGA_BTN_SELECT, GAGA_BTN_START,
                                       GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                       GAGA_BTN_EAST, GAGA_BTN_NORTH, GAGA_BTN_L1, GAGA_BTN_R1]
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 32040)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 5000, "not silent")
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_EAST.rawValue))
        try core.loadState(try core.saveState())
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let noise = directory.appendingPathComponent("noise.sfc")
        try Data((0..<0x8000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        for (path, message) in [(noise.path, "This file is not a Super Famicom or Super NES game."),
                                (directory.appendingPathComponent("gone.sfc").path, "The game file could not be opened.")] {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, message)
            }
            core.stop()
        }
    }

    /// The adapter writes RETRO_MEMORY_SAVE_RAM to <rom stem>.sav.
    func testBatterySaveSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, SNESTestROM.sramSize)
            XCTAssertEqual(Array(flushed[0..<4]), SNESTestROM.sramMagic)
            XCTAssertEqual(Int(flushed[SNESTestROM.sramBootCounterOffset]), boot)
            core.stop()
        }
    }

    func testStateRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        assertPicture(capture, toggle: true)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_START.rawValue))
        let first = capture.pixels
        try core.loadState(state)
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_START.rawValue))
        XCTAssertEqual(capture.pixels, first, "the same input from the same state gives the same frame")
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)

        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var damaged = state
        for index in Self.headerSize..<(Self.headerSize + 32) { damaged[index] ^= 0x5A }
        let cases: [(Data, String)] = [
            (wrongMagic, "This save state belongs to another game or another version of this game."),
            (state.prefix(state.count - 1), "This save state is the wrong size for Snes9x."),
            (damaged, "Snes9x could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) { XCTAssertEqual($0.localizedDescription, message) }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertPicture(capture, toggle: true)
        }
        core.stop()
    }

    /// Pro Action Replay 7E000001 and the same write as 7E0000:01 set the ROM's cheat flag.
    func testCheatsHaveTheirEffectAndBadCodesAreRefused() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        for code in ["7E000001", "7E0000:01"] {
            try core.addCheat(id: 1, code: code, enabled: true)
            run(core, frames: 3)
            assertPicture(capture, cheat: true)
            core.removeCheat(id: 1)
            run(core, frames: 3)
            assertPicture(capture)
        }
        for code in ["ZZZZZZZZ", "7E00", "7E000001+7E000101", String(repeating: "7", count: 300)] {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: code, enabled: true))
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }
}
