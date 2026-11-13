import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

@_silgen_name("csops")
private func jitTestCsops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

/// PPSSPP through the real bridge (milestone 5.5): the IR interpreter, HLE kernel and the Vulkan renderer on
/// MoltenVK, presenting to a CAMetalLayer. The game is PSPTestELF, linked by the core's HLE kernel, so no
/// firmware is read. Device pending: these were built but have not run on a device yet (docs/07 5.5).
@MainActor
final class PpssppCoreTests: GagaTestCase {
    private var directory: URL!
    private var elfPath: String!
    private let interface = GagaCoreRegistry_FindByID("ppsspp")!.pointee
    private var layer: CAMetalLayer!

    override func setUp() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("ppsspp"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("psp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        elfPath = try write(PSPTestELF.build())
        layer = CAMetalLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 480, height: 272)
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first
        window?.layer.addSublayer(layer)
    }

    override func tearDown() async throws {
        layer?.removeFromSuperlayer()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func write(_ data: Data, name: String = "test.elf") throws -> String {
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

    /// Loads and runs until the program has drawn its bands. PPSSPP boots on a loader thread (PSP_InitStart),
    /// and a frame stepped before it finishes presents nothing. Stepped with no pacing, a fixed 120 frames could
    /// all fall inside the boot (device runs 5 and 7, "no frame presented"), so the count starts at the first
    /// presented frame.
    private func loaded() async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: elfPath)
        XCTAssertTrue(core.attachMetalLayer(layer, width: 960, height: 544, scale: 2))
        let deadline = Date().addingTimeInterval(20)
        // A fatal event stops the wrapper stepping, so waiting on would only spin (device run 9: 20 s, then no audio).
        while capture.frames == 0 && capture.fatal == nil && Date() < deadline { run(core, frames: 1) }
        XCTAssertNil(capture.fatal, "the core stopped while booting")
        run(core, frames: 120)
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    /// The band a BGRA pixel shows: 0 red, 1 green, 2 blue, 3 white, -1 anything else.
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

    /// Checks the middle of every cell and of each band against PSPTestELF.expectedColor, mapping the
    /// program's 480x272 onto whatever size the frame came out.
    private func assertPicture(_ core: GagaCoreWrapper, keys: UInt32 = 0, toggle: Bool = false, counter: Int = 1,
                               line: UInt = #line) throws {
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented", line: line)
        func at(_ x: Int, _ y: Int) -> Int {
            let fx = x * frame.width / PSPTestELF.width, fy = y * frame.height / PSPTestELF.height
            let i = (fy * frame.width + fx) * 4
            return band(Array(frame.pixels[i..<i + 4]))
        }
        let half = PSPTestELF.cellSize / 2
        var points = (0..<4).map { (240, $0 * PSPTestELF.bandHeight + PSPTestELF.bandHeight - 6) }
        for row in [PSPTestELF.keyRow, PSPTestELF.counterRow] {
            points += (0..<16).map { (PSPTestELF.cellColumn + $0 * PSPTestELF.cellSize + half, row + half) }
        }
        points.append((half, PSPTestELF.keyRow + half))
        for (x, y) in points {
            let want = PSPTestELF.expectedColor(x: x, y: y, keys: keys, toggle: toggle, counter: counter)
            XCTAssertEqual(at(x, y), want, "pixel \(x), \(y)", line: line)
        }
    }

    // MARK: - Picture and input

    func testTheCoreIsALayerPathCoreWithItsExtensions() throws {
        XCTAssertEqual(interface.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertNotEqual(interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue, 0)
        for ext in ["cso", "elf"] { XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "psp") }
        XCTAssertEqual(CoreCatalog.defaultCore(for: "psp"), "ppsspp")
        XCTAssertNotNil(interface.cheat_add, "CWCheat is wired")
    }

    func testBootsTheHomebrewProgramAndDrawsTheBands() async throws {
        let (core, capture) = try await loaded()
        try assertPicture(core)
        XCTAssertGreaterThan(capture.frames, 0)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    /// The core maps RetroPad B to Cross, A to Circle, and Start and the D-pad to themselves.
    func testInputLightsThatButtonsCell() async throws {
        let (core, _) = try await loaded()
        let cases: [(GagaButtonMask, UInt32)] = [(GAGA_BTN_SOUTH, PSPTestELF.buttonCross), (GAGA_BTN_START, PSPTestELF.buttonStart),
                                             (GAGA_BTN_RIGHT, PSPTestELF.buttonRight)]
        for (host, psp) in cases {
            run(core, frames: 4, buttons: UInt32(host.rawValue))
            try assertPicture(core, keys: psp)
        }
        // PPSSPP draws on its own thread, so the presented picture can trail input by a few frames.
        run(core, frames: 8)
        try assertPicture(core)
        core.stop()
    }

    func testAudioIsATone() async throws {
        let (core, capture) = try await loaded()
        capture.left.removeAll()
        run(core, frames: 60)
        XCTAssertGreaterThan(capture.left.count, 30 * 735, "about a second of 44.1 kHz")
        XCTAssertGreaterThan(capture.left.max() ?? 0, 4000)
        XCTAssertLessThan(capture.left.min() ?? 0, -4000)
        core.stop()
    }

    // MARK: - Saves

    /// The program's memory stick file is a file in the save folder, so it survives a restart as it is.
    func testMemoryStickBootCounterSurvivesARestart() async throws {
        let file = directory.appendingPathComponent(PSPTestELF.countFolder).appendingPathComponent(PSPTestELF.countFile)
        for boot in 1...3 {
            let (core, _) = try await loaded()
            try assertPicture(core, counter: boot)
            core.stop()
            XCTAssertEqual(try Data(contentsOf: file), Data([UInt8(boot), 0, 0, 0]))
        }
    }

    // MARK: - Cheats

    /// A CWCheat code lands in PPSSPP's own cheat file, <save folder>/PSP/Cheats/<disc ID>.ini, and leaves it
    /// when removed. The write goes to the middle of user memory, which the test program does not use.
    func testCWCheatIsWrittenToTheCheatFileAndRemoved() async throws {
        let (core, capture) = try await loaded()
        XCTAssertTrue(core.supportsCheats)
        XCTAssertThrowsError(try core.addCheat(id: 1, code: "0x20F00000", enabled: true), "half a code")
        XCTAssertThrowsError(try core.addCheat(id: 1, code: "_C1 Lives", enabled: true), "a heading, not a code")
        try core.addCheat(id: 1, code: "_L 0x20F00000 0x00000063\n0x20F00004 0x00000001", enabled: true)
        let folder = directory.appendingPathComponent("PSP/Cheats")
        func cheatFile() throws -> String {
            let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".ini") }
            XCTAssertEqual(files.count, 1, "one file, named after the disc ID")
            return try String(contentsOf: folder.appendingPathComponent(try XCTUnwrap(files.first)), encoding: .utf8)
        }
        let written = try cheatFile()
        XCTAssertTrue(written.hasPrefix("_S "), written)
        XCTAssertTrue(written.contains("_L 0x20F00000 0x00000063\n_L 0x20F00004 0x00000001"), written)
        let frames = capture.frames
        run(core, frames: 30)
        XCTAssertGreaterThan(capture.frames, frames, "still running with the cheat on")
        core.removeCheat(id: 1)
        XCTAssertFalse(try cheatFile().contains("_L "))
        core.stop()
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        let (core, _) = try await loaded()
        let chord = UInt32(GAGA_BTN_SOUTH.rawValue | GAGA_BTN_EAST.rawValue)
        // Eight release frames: the presented picture can trail input, as in the input test.
        run(core, frames: 3, buttons: chord)
        run(core, frames: 8)
        try assertPicture(core, toggle: true)
        let state = try core.saveState()
        run(core, frames: 3, buttons: chord)
        run(core, frames: 8)
        try assertPicture(core, toggle: false)
        try core.loadState(state)
        run(core, frames: 8)
        try assertPicture(core, toggle: true)
        XCTAssertThrowsError(try core.loadState(Data(repeating: 0, count: 3)))
        run(core, frames: 3)
        try assertPicture(core, toggle: true)
        core.stop()
    }

    // MARK: - Lifecycle

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 120, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        core.stop()
        // The IR interpreter, and MoltenVK's GPU-only shader compiles: no executable CPU pages.
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    /// Sideload JIT (docs/04 section 8.1): a DevJIT build on a device, run with TEST_RUNNER_GAGA_JIT_TEST=1, with a
    /// debugger that serves Cores/shared/Jit26.c (scripts/jit26_lldb.py or StikDebug's universal.js). Waits up to
    /// 120 s for that debugger to attach, then expects the program drawn from JIT code: new anonymous executable pages.
    func testJITRunsTheHomebrewProgramUnderADebugger() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GAGA_JIT_TEST"] == "1", "a DevJIT device run only")
        func debugged() -> Bool {
            var flags: UInt32 = 0
            return jitTestCsops(getpid(), 0, &flags, MemoryLayout<UInt32>.size) == 0 && flags & 0x1000_0000 != 0 // CS_DEBUGGED
        }
        let deadline = Date().addingTimeInterval(120)
        while !debugged() && Date() < deadline { try await Task.sleep(for: .seconds(1)) }
        try XCTSkipUnless(debugged(), "no debugger attached")
        setenv("GAGA_JIT", "1", 1)
        defer { setenv("GAGA_JIT", "0", 1) }
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        try assertPicture(core)
        run(core, frames: 120, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        try assertPicture(core, keys: UInt32(GAGA_BTN_SOUTH.rawValue))
        XCTAssertNil(capture.fatal)
        XCTAssertFalse(CodeGenCheck.violations().isEmpty, "no JIT code pages: the core fell back to the interpreter")
        core.stop()
    }

    func testTeardownAndRelaunchThreeTimes() async throws {
        for _ in 0..<3 {
            let (core, capture) = try await loaded()
            try assertPicture(core, counter: Int(try Data(contentsOf: directory.appendingPathComponent(
                "\(PSPTestELF.countFolder)/\(PSPTestELF.countFile)"))[0]))
            XCTAssertNil(capture.fatal)
            core.stop()
        }
    }

    /// Device run 13: after many cores had run in one process, every load failed with "[BOOT] Memory init failed".
    /// A layer-path core loaded and stopped many times, on both its picture paths, must leave room for PPSSPP.
    func testBootsAfterALayerCoreLoadedManyTimes() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("vktest"), "GAGA_CORE_SET left the Vulkan test core out")
        let vktest = GagaCoreRegistry_FindByID("vktest")!.pointee
        let rom = try write(VkTestROM.build(), name: "triangle.gagavk")
        for round in 0..<20 {
            let core = try GagaCoreWrapper(interface: vktest, systemDirectory: directory.path, saveDirectory: directory.path)
            try await core.loadROM(path: rom)
            if round % 2 == 0 {
                XCTAssertTrue(core.attachOutputTexture())
            } else {
                XCTAssertTrue(core.attachMetalLayer(layer, width: 960, height: 544, scale: 2))
            }
            run(core, frames: 3)
            core.stop()
        }
        let (core, capture) = try await loaded()
        try assertPicture(core)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    /// Upstream probed for the memory base only between 4 and 6 GiB, where the app's frameworks and heap live. With
    /// the scratchpad address of every base it tried taken, PPSSPP still boots: its block is reserved at load.
    func testBootsWithTheOldMemoryProbeRangeTaken() async throws {
        var taken: [vm_address_t] = []
        defer { for address in taken { vm_deallocate(mach_task_self_, address, 0x4000) } }
        for base in stride(from: vm_address_t(0x1_0000_0000), to: 0x1_7FFF_0000, by: 0x80_0000) {
            var address = base + 0x10000
            if vm_allocate(mach_task_self_, &address, 0x4000, VM_FLAGS_FIXED) == KERN_SUCCESS { taken.append(address) }
        }
        for boot in 1...2 { // The second boot reuses the block the first released.
            let (core, capture) = try await loaded()
            // The program counts its boots on the memory stick, so the second boot shows 2 (device run 14).
            try assertPicture(core, counter: boot)
            XCTAssertNil(capture.fatal)
            core.stop()
        }
    }

    func testBenchmarkWritesATestFile() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "psp", to: directory).pathExtension, "elf")
    }

    /// Runs without a core: the generator's own layout, and the catalog telling PSP files from PS1 ones.
    func testTheTestProgramIsAPSPExecutableAndPBPsArePlaced() throws {
        let elf = [UInt8](PSPTestELF.build())
        XCTAssertEqual(Array(elf[0..<4]), [0x7F, 0x45, 0x4C, 0x46])
        XCTAssertEqual(elf[18], 8, "EM_MIPS")
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: try write(Data(elf)))), "psp")

        func pbp(psar: [UInt8]) -> Data {
            var header = [UInt8](repeating: 0, count: 40)
            header.replaceSubrange(0..<4, with: [0, 0x50, 0x42, 0x50])
            for slot in 0..<8 { header[8 + slot * 4] = 40 } // Every part empty, DATA.PSAR at the end.
            return Data(header + psar)
        }
        let psp = try write(pbp(psar: []), name: "psp.pbp")
        let ps1 = try write(pbp(psar: Array("PSISOIMG0000".utf8)), name: "ps1.pbp")
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: psp)), "psp")
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: ps1)), "ps1")
    }
}
