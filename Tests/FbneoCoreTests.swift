import XCTest
@testable import GagaEmu

/// FinalBurn Neo, the sideload-only alternate arcade core, through the shared libretro adapter and the real
/// bridge, running the generated homebrew set for its `gridlee` driver (`GridleeTestSet`, the same set the MAME
/// tests use). The set's CRCs are not the dumped ones, so a copy goes in system/fbneo/patched, where upstream
/// matches files by name and size only. No commercial ROM and no BIOS.
/// Device-pending: written against a macOS host run of the same core and adapter, not yet run on the iPhone.
final class FbneoCoreTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("fbneo")!.pointee
    private static let headerSize = 16
    private let button1 = UInt32(GAGA_BTN_SOUTH.rawValue)
    private let start1 = UInt32(GAGA_BTN_START.rawValue)

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("fbneo"), "GAGA_CORE_SET left this core out (sideload builds only)")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("fbneo-\(UUID().uuidString)")
        let set = GridleeTestSet.build()
        romPath = try write(set, to: "roms/gridlee.zip")
        _ = try write(set, to: "system/fbneo/patched/gridlee.zip")
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func write(_ data: Data, to path: String) throws -> String {
        let url = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url.path
    }

    private var nvram: URL { directory.appendingPathComponent("saves/fbneo/gridlee.fs") }

    private final class Capture {
        var pixels: [UInt8] = []
        var width = 0
        var height = 0
        var pitch = 0
        var format = GagaPixelFormat(rawValue: 99)
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var fatal: String?

        /// Each channel as on (top bit set) or off, from RGB565, the format FBNeo gives a 16-bit driver.
        func lit(x: Int, y: Int) -> [Bool] {
            let i = y * pitch + x * 2
            let v = UInt16(pixels[i]) | UInt16(pixels[i + 1]) << 8
            return [v >> 15 != 0, (v >> 10) & 1 != 0, (v >> 4) & 1 != 0]
        }
    }

    private func makeCore(system: String = "system") throws -> (GagaCoreWrapper, Capture) {
        let saves = directory.appendingPathComponent("saves").path
        try FileManager.default.createDirectory(atPath: saves, withIntermediateDirectories: true)
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.appendingPathComponent(system).path,
                                       saveDirectory: saves)
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

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false,
                               file: StaticString = #filePath, line: UInt = #line) {
        guard capture.width == GridleeTestSet.width, capture.height == GridleeTestSet.height else {
            return XCTFail("frame is \(capture.width) by \(capture.height)", file: file, line: line)
        }
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_RGB565, file: file, line: line)
        var wrong = 0
        for y in 0..<GridleeTestSet.height {
            for x in 0..<GridleeTestSet.width {
                let color = GridleeTestSet.colors[GridleeTestSet.expectedColor(x: x, y: y, keys: keys, toggle: toggle)]
                if capture.lit(x: x, y: y) != [color.r, color.g, color.b].map({ $0 != 0 }) { wrong += 1 }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture", file: file, line: line)
    }

    private var chord: UInt32 { button1 | start1 }

    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 3, buttons: chord)
        run(core, frames: 3)
    }

    func testRegistryResolvesTheRealCoreAsAnAlternate() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("fbneo")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.0.0.03 4cdb31f1")
        XCTAssertEqual(found.native_sample_rate, 48000)
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.platform("arcade")?.cores.map(\.id), ["mame", "fbneo"])
        XCTAssertEqual(CoreCatalog.defaultCore(for: "arcade"), "mame", "an alternate, never the default")
        let game = GameItem(id: UUID(), title: "t", platformID: "arcade", romPath: romPath, coverPath: nil, coreOverride: "fbneo",
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "fbneo", "picked per game through core switching")
    }

    func testPictureInputAndSound() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 60)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        for (bit, button) in [button1, start1].enumerated() {
            run(core, frames: 3, buttons: button)
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 48000)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max()!) - Int(tone.min()!), 5000, "not silent")
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 300, buttons: button1)
        try core.loadState(try core.saveState())
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let noise = try write(Data((0..<0x8000).map { UInt8(truncatingIfNeeded: $0 &* 73) }), to: "roms/noise.zip")
        for (path, message) in [(noise, "This file is not an FBNeo ROM set (a .zip named after the game) for a game in this build."),
                                (directory.appendingPathComponent("roms/gone.zip").path, "The game file could not be opened.")] {
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

    /// A zip named after no driver, or a set without the dumped CRCs and no patched copy: upstream starts anyway
    /// and draws its own 640 x 480 message (the unknown name, or the files it needs), so the player sees what to fix.
    /// Nothing runs behind it, so there is no state to save.
    func testAnUnknownOrWrongSetShowsUpstreamsOwnMessage() async throws {
        let unknown = try write(GridleeTestSet.build(), to: "roms/notagame.zip")
        for (path, system) in [(unknown, "system"), (romPath!, "empty-system")] {
            let (core, capture) = try makeCore(system: system)
            try await core.loadROM(path: path)
            run(core, frames: 10)
            XCTAssertEqual([capture.width, capture.height], [640, 480], path)
            XCTAssertThrowsError(try core.saveState())
            core.stop()
        }
    }

    /// Upstream writes the driver's NVRAM to saves/fbneo/<set>.fs when the game closes.
    func testNVRAMSurvivesARestart() async throws {
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 60)
            core.stop()
            let saved = [UInt8](try Data(contentsOf: nvram))
            XCTAssertEqual(saved.count, GridleeTestSet.nvramSize)
            XCTAssertEqual(Array(saved[0..<4]), GridleeTestSet.nvramMagic)
            XCTAssertEqual(Int(saved[GridleeTestSet.nvramBootCounterOffset]), boot)
        }
    }

    /// Upstream's state carries no checksum, so a damaged payload is not tested: only the adapter's own checks.
    func testStateRoundTripAndRefusedStatesLeaveTheGameRunning() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 60)
        flipToggle(core)
        assertPicture(capture, toggle: true)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        run(core, frames: 20, buttons: button1)
        let first = capture.pixels
        try core.loadState(state)
        run(core, frames: 20, buttons: button1)
        XCTAssertEqual(capture.pixels, first, "the same input from the same state gives the same frame")
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)

        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        let cases: [(Data, String)] = [
            (wrongMagic, "This save state belongs to another game or another version of this game."),
            (state.prefix(state.count - 1), "This save state is the wrong size for FinalBurn Neo."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) { XCTAssertEqual($0.localizedDescription, message) }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertPicture(capture, toggle: true)
        }
        core.stop()
    }
}
