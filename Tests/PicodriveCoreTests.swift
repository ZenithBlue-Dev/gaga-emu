import XCTest
@testable import GagaEmu

/// PicoDrive, the sideload-only 32X core and alternate Mega Drive core, through the shared libretro adapter and the real
/// bridge, running the generated homebrew ROM (`MDTestROM`). No BIOS and no commercial game.
/// Device-pending: written against a macOS host run of the same core and adapter, not yet run on the iPhone.
final class PicodriveCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("picodrive")!.pointee
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("picodrive"), "GAGA_CORE_SET left this core out (sideload builds only)")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("picodrive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.md")
        try MDTestROM.build().write(to: rom)
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

        /// Each channel as on (top bit set) or off, from RGB565, the format this build renders.
        func lit(x: Int, y: Int) -> [Bool] {
            let i = y * pitch + x * 2
            let v = UInt16(pixels[i]) | UInt16(pixels[i + 1]) << 8
            return [v >> 15 != 0, (v >> 10) & 1 != 0, (v >> 4) & 1 != 0]
        }
    }

    private func makeCore() throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
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

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false, genie: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        guard capture.width == MDTestROM.width, capture.height == MDTestROM.height else {
            return XCTFail("frame is \(capture.width) by \(capture.height)", file: file, line: line)
        }
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565, file: file, line: line)
        var wrong = 0
        for y in 0..<MDTestROM.height {
            for x in 0..<MDTestROM.width {
                let color = MDTestROM.colors[MDTestROM.expectedShade(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, genie: genie)]
                let expected = [(color >> 1) & 7, (color >> 5) & 7, (color >> 9) & 7].map { $0 != 0 }
                if capture.lit(x: x, y: y) != expected { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture", file: file, line: line)
    }

    /// The pad's A and B: the controller's west and south buttons.
    private let chord = UInt32(GAGA_BTN_WEST.rawValue | GAGA_BTN_SOUTH.rawValue)

    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    func testRegistryResolvesTheRealCoreAsAnAlternate() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("picodrive")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "2.05 1890c293")
        XCTAssertEqual(found.native_sample_rate, 44100)
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        for platform in ["megadrive", "megacd"] {
            XCTAssertEqual(CoreCatalog.platform(platform)?.cores.last?.id, "picodrive")
            XCTAssertEqual(CoreCatalog.defaultCore(for: platform), "jgenesis", "an alternate, never the default")
        }
        XCTAssertEqual(CoreCatalog.platform("sega32x")?.cores.map(\.id), ["picodrive"])
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "32x"), "sega32x")
        let game = GameItem(id: UUID(), title: "t", platformID: "megadrive", romPath: romPath, coverPath: nil, coreOverride: "picodrive",
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "picodrive", "picked per game through core switching")
    }

    func testPictureInputAndSound() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        // MDTestROM.keyOrder: A B C on west, south and east, X Y Z on L1, north and R1, Mode on Select.
        let order: [GagaButtonMask] = [GAGA_BTN_UP, GAGA_BTN_DOWN, GAGA_BTN_LEFT, GAGA_BTN_RIGHT,
                                       GAGA_BTN_WEST, GAGA_BTN_SOUTH, GAGA_BTN_EAST, GAGA_BTN_START]
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 44100)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 5000, "not silent")
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 300, buttons: chord)
        try core.loadState(try core.saveState())
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    /// PicoDrive loads by path and has no is_rom, so the adapter never opens the file and upstream's refusal is the
    /// message, for noise, a missing file and a Mega-CD disc with no BIOS alike.
    func testBadFilesGiveAMessageForThePlayer() async throws {
        let noise = directory.appendingPathComponent("noise.md")
        try Data((0..<0x8000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        let bin = directory.appendingPathComponent("disc.bin")
        try Data(repeating: 0, count: 2352 * 300).write(to: bin)
        let cue = directory.appendingPathComponent("disc.cue")
        try Data("FILE \"disc.bin\" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n".utf8).write(to: cue)
        for path in [noise.path, directory.appendingPathComponent("gone.md").path, cue.path] {
            let message = "PicoDrive could not load this game."
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

    /// The adapter writes RETRO_MEMORY_SAVE_RAM to <rom stem>.sav. PicoDrive keeps 16 KB of cartridge
    /// SRAM with the ROM's bytes on odd addresses, so byte n of MDTestROM's save is at file offset 2n + 1.
    func testBatterySaveSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, 2 * MDTestROM.sramSize)
            XCTAssertEqual(MDTestROM.sramMagic.indices.map { flushed[2 * $0 + 1] }, MDTestROM.sramMagic)
            XCTAssertEqual(Int(flushed[2 * MDTestROM.sramBootCounterOffset + 1]), boot)
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
            (state.prefix(state.count - 1), "This save state is the wrong size for PicoDrive."),
            (damaged, "PicoDrive could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) { XCTAssertEqual($0.localizedDescription, message) }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertPicture(capture, toggle: true)
        }
        core.stop()
    }

    /// Game Genie AGAA-AAAA patches ROM $008000 (the genie cell); FF0000:0001 writes the RAM cheat word. Upstream
    /// puts back what each code replaced when the adapter resets the list, so both come off with the cheat.
    func testCheatsHaveTheirEffectAndBadCodesAreRefused() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        for (code, genie) in [("AGAA-AAAA", true), ("FF0000:0001", false)] {
            try core.addCheat(id: 1, code: code, enabled: true)
            run(core, frames: 3)
            assertPicture(capture, cheat: !genie, genie: genie)
            core.removeCheat(id: 1)
            run(core, frames: 3)
            assertPicture(capture)
        }
        for code in ["ZZZZ-ZZZZ", "FF00", String(repeating: "A", count: 300)] {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: code, enabled: true))
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }
}
