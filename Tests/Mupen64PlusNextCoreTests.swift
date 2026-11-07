import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// Mupen64Plus-Next through the real bridge (milestone 5.2): the pure interpreter, the cxd4 RSP and
/// paraLLEl-RDP on MoltenVK, presenting to a CAMetalLayer. The game is N64TestROM, booted by the core's HLE
/// PIF boot. Device pending: these were built but have not run on a device yet (docs/07 5.2).
@MainActor
final class Mupen64PlusNextCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("mupen64plus_next")!.pointee
    private var layer: CAMetalLayer!

    override func setUp() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("mupen64plus_next"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("n64-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        romPath = try write(N64TestROM.build())
        layer = CAMetalLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first
        window?.layer.addSublayer(layer)
    }

    override func tearDown() async throws {
        layer?.removeFromSuperlayer()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func write(_ data: Data, name: String = "test.z64") throws -> String {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    private final class Capture {
        var frames = 0
        var left: [Int16] = []
        var fatal: String?
    }

    private func makeCore() throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        let capture = Capture()
        core.onVideoFrame = { _ in capture.frames += 1 }
        core.onAudioPacket = { packet in
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) { capture.left.append(packet.samples[index]) }
        }
        core.onEvent = { event in if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message } }
        return (core, capture)
    }

    private func loaded() async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: romPath)
        XCTAssertTrue(core.attachMetalLayer(layer, width: 800, height: 600, scale: 2))
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    /// The band a BGRA pixel shows: 0 red, 1 green, 2 blue, 3 white, -1 anything else. Thresholds, not exact
    /// values, because the VI filters and paraLLEl-RDP expands 5-bit colour.
    private func band(_ pixel: [UInt8]) -> Int {
        let (b, g, r) = (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
        func high(_ v: Int) -> Bool { v > 160 }
        func low(_ v: Int) -> Bool { v < 96 }
        if high(r) && high(g) && high(b) { return 3 }
        if high(r) && low(g) && low(b) { return 0 }
        if low(r) && high(g) && low(b) { return 1 }
        if low(r) && low(g) && high(b) { return 2 }
        return -1
    }

    /// Checks the middle of every cell and of each band against N64TestROM.expectedColor, mapping the
    /// program's 320x240 onto whatever size the VI scanout came out.
    private func assertPicture(_ core: GagaCoreWrapper, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false,
                               counter: Int = 1, line: UInt = #line) throws {
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented", line: line)
        func at(_ x: Int, _ y: Int) -> Int {
            let fx = x * frame.width / N64TestROM.width, fy = y * frame.height / N64TestROM.height
            let i = (fy * frame.width + fx) * 4
            return band(Array(frame.pixels[i..<i + 4]))
        }
        let half = (N64TestROM.cellWidth / 2, N64TestROM.cellHeight / 2)
        var points = (0..<4).map { (160, $0 * N64TestROM.bandHeight + N64TestROM.bandHeight - 6) }
        for row in [N64TestROM.keyRow, N64TestROM.counterRow] {
            points += (0..<16).map { (N64TestROM.cellColumn + $0 * N64TestROM.cellWidth + half.0, row + half.1) }
        }
        points += [(N64TestROM.toggleColumn + half.0, N64TestROM.flagRow + half.1),
                   (N64TestROM.cheatColumn + half.0, N64TestROM.flagRow + half.1)]
        for (x, y) in points {
            let want = N64TestROM.expectedColor(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, counter: counter)
            XCTAssertEqual(at(x, y), want, "pixel \(x), \(y)", line: line)
        }
    }

    // MARK: - Picture and input

    func testTheCoreIsALayerPathCoreWithItsExtensions() throws {
        XCTAssertEqual(interface.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertNotEqual(interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue, 0)
        XCTAssertTrue(CoreCatalog.drawsOwnPicture("mupen64plus_next"))
        for ext in ["n64", "v64", "z64"] { XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "n64") }
        XCTAssertEqual(CoreCatalog.defaultCore(for: "n64"), "mupen64plus_next")
    }

    func testBootsTheHomebrewCartridgeAndDrawsTheBands() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 10)
        try assertPicture(core)
        XCTAssertEqual(capture.frames, 10)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    /// The core maps RetroPad B to the N64's A, Y to B, and Start and the D-pad to themselves.
    func testInputLightsThatButtonsCell() async throws {
        let (core, _) = try await loaded()
        let cases: [(GagaButtonMask, UInt32)] = [(GAGA_BTN_SOUTH, N64TestROM.buttonA), (GAGA_BTN_START, N64TestROM.buttonStart),
                                             (GAGA_BTN_RIGHT, N64TestROM.dpadRight)]
        for (host, n64) in cases {
            run(core, frames: 3, buttons: UInt32(host.rawValue))
            try assertPicture(core, keys: n64)
        }
        run(core, frames: 3)
        try assertPicture(core)
        core.stop()
    }

    func testAudioIsATone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 60)
        XCTAssertGreaterThan(capture.left.count, 30 * 735, "about a second of 44.1 kHz")
        XCTAssertGreaterThan(capture.left.max() ?? 0, 4000)
        XCTAssertLessThan(capture.left.min() ?? 0, -4000)
        core.stop()
    }

    // MARK: - Saves

    func testBatterySRAMBootCounterSurvivesARestart() async throws {
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 4)
            try assertPicture(core, counter: boot)
            core.flushBatterySave()
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("test.sav").path))
            core.stop()
        }
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        let (core, _) = try await loaded()
        let chord = UInt32(GAGA_BTN_SOUTH.rawValue | GAGA_BTN_WEST.rawValue)
        run(core, frames: 4)
        run(core, frames: 2, buttons: chord)
        run(core, frames: 2)
        try assertPicture(core, toggle: true)
        let state = try core.saveState()
        run(core, frames: 2, buttons: chord)
        run(core, frames: 2)
        try assertPicture(core, toggle: false)
        try core.loadState(state)
        run(core, frames: 2)
        try assertPicture(core, toggle: true)
        XCTAssertThrowsError(try core.loadState(Data(repeating: 0, count: 3)))
        run(core, frames: 2)
        try assertPicture(core, toggle: true)
        core.stop()
    }

    // MARK: - Cheats

    /// GameShark 80 writes a byte at every VI. The program clears it each frame, so the cell shows only while on.
    func testGameSharkCheatHasItsEffectAndStops() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 4)
        try core.addCheat(id: 1, code: "800F0000 0001", enabled: true)
        run(core, frames: 3)
        try assertPicture(core, cheat: true)
        core.setCheat(id: 1, enabled: false)
        run(core, frames: 3)
        try assertPicture(core)
        XCTAssertThrowsError(try core.addCheat(id: 2, code: "800F0000", enabled: true))
        XCTAssertThrowsError(try core.addCheat(id: 3, code: "ZZZZZZZZ 0001", enabled: true))
        core.stop()
    }

    // MARK: - Lifecycle

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 120, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        core.stop()
        // Pure interpreter, cxd4 interpreter, and MoltenVK's GPU-only shader compiles: no executable CPU pages.
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testBadFilesGiveAMessageForThePlayer() async throws {
        for path in [try write(Data(), name: "empty.z64"), try write(Data(repeating: 0x41, count: 0x2000), name: "text.z64")] {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, "This file is not a Nintendo 64 game.")
            }
            core.stop()
        }
    }

    func testTeardownAndRelaunchFiveTimes() async throws {
        for boot in 1...5 {
            let (core, capture) = try await loaded()
            run(core, frames: 4)
            try assertPicture(core, counter: boot) // The SRAM boot counter persists from one launch to the next.
            XCTAssertNil(capture.fatal)
            core.stop()
        }
    }

    func testBenchmarkWritesATestFile() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "n64", to: directory).pathExtension, "z64")
    }

    /// Runs without a core: the generator's own layout.
    func testTheTestROMHasAHeaderAndFitsItsBootBlock() {
        let rom = [UInt8](N64TestROM.build())
        XCTAssertEqual(rom.count, 1 << 20)
        XCTAssertEqual(Array(rom[0..<4]), [0x80, 0x37, 0x12, 0x40])
        XCTAssertEqual(Array(rom[0x3C..<0x40]), Array("ED".utf8) + [0x45, 0x30])
        XCTAssertNotEqual(Array(rom[0x40..<0x44]), [0, 0, 0, 0])
    }
}
