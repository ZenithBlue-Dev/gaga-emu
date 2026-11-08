import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// Flycast through the real bridge (milestone 6.2): the SH-4, ARM7 and AICA DSP interpreters, and Flycast's
/// Vulkan renderer on MoltenVK, presenting to a CAMetalLayer. Device pending: built, not yet run on a device
/// (docs/07 6.2). The running-game test boots DreamcastTestDisc, a self-made GD-ROM image, through reios.
@MainActor
final class FlycastCoreTests: GagaTestCase {
    private var directory: URL!
    private let interface = GagaCoreRegistry_FindByID("flycast")!.pointee

    override func setUp() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("flycast"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("dc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func write(_ data: Data, name: String) throws -> String {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    private func makeCore() throws -> GagaCoreWrapper {
        try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
    }

    func testTheCoreIsALayerPathCoreWithItsExtensions() throws {
        XCTAssertEqual(interface.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertNotEqual(interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue, 0)
        XCTAssertTrue(CoreCatalog.drawsOwnPicture("flycast"))
        for ext in ["gdi", "cdi"] { XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "dreamcast") }
        XCTAssertEqual(CoreCatalog.defaultCore(for: "dreamcast"), "flycast")
        XCTAssertEqual(interface.state_version, 854)
    }

    /// Flycast reads discs by path, so a bad file is refused by retro_load_game, not by the adapter.
    func testBadFilesGiveAMessageForThePlayer() async throws {
        let files = [try write(Data(), name: "empty.gdi"),
                     try write(Data(repeating: 0x41, count: 0x8000), name: "text.cdi"),
                     try write(Data("1\n1 0 4 2352 missing.bin 0\n".utf8), name: "missing.gdi")]
        for path in files {
            let core = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, "Flycast could not load this game.")
            }
            core.stop()
        }
    }

    /// No BIOS is shipped or written: a failed load leaves System/dc without dc_boot.bin.
    func testNoBIOSIsWrittenToTheSystemFolder() async throws {
        let core = try makeCore()
        try? await core.loadROM(path: try write(Data(), name: "empty.gdi"))
        core.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("dc/dc_boot.bin").path))
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let core = try makeCore()
        try? await core.loadROM(path: try write(Data(repeating: 0x41, count: 0x8000), name: "text.cdi"))
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testBenchmarkWritesTheDreamcastTestDisc() throws {
        let url = try BenchmarkRun.writeTestROM(platformID: "dreamcast", to: directory)
        XCTAssertEqual(url.pathExtension, "gdi")
        XCTAssertEqual(CoreCatalog.platformID(forFile: url), "dreamcast")
        for track in ["track01.iso", "track02.raw", "track03.iso"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(track).path), track)
        }
        let track3 = try Data(contentsOf: directory.appendingPathComponent("track03.iso"))
        XCTAssertEqual(track3.prefix(16), Data("SEGA SEGAKATANA ".utf8), "IP.BIN")
        XCTAssertEqual(track3[16 * 2048 + 1..<16 * 2048 + 6], Data("CD001".utf8), "ISO 9660 volume descriptor")
    }

    /// Device pending: reios boots DreamcastTestDisc without a BIOS, and its program fills the framebuffer.
    func testBootsTheTestDiscAndDrawsAPicture() async throws {
        final class Capture {
            var frames = 0
            var fatal: String?
        }
        for file in DreamcastTestDisc.files() { _ = try write(file.data, name: file.name) }
        let core = try makeCore()
        let capture = Capture()
        core.onVideoFrame = { _ in capture.frames += 1 }
        core.onEvent = { event in if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message } }
        try await core.loadROM(path: directory.appendingPathComponent("GagaDreamcast.gdi").path)
        for _ in 0..<120 { core.step(inputs: [GagaInputState()]) }
        // The SH-4's round-toward-zero stays in the core: run 11 read JSON 0.2 back as 0.19999999 after this test.
        XCTAssertEqual(Float(try XCTUnwrap(Double("0.2"))), 0.2, "the core's FPCR rounding mode reached the caller's thread")
        XCTAssertNil(capture.fatal)
        XCTAssertGreaterThan(capture.frames, 0, "no frame presented")
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented")
        let i = ((frame.height / 2) * frame.width + frame.width / 2) * 4
        let middle = Array(frame.pixels[i..<i + 4])
        XCTAssertTrue(zip(middle, DreamcastTestDisc.colorBGRA).allSatisfy { abs(Int($0) - Int($1)) <= 8 }, "\(middle)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("dc/dc_boot.bin").path))
        core.stop()
    }

    func testInputAudioVMUSaveAndStateRoundTrip() throws {
        throw XCTSkip("the Dreamcast test disc reads no input and plays no sound yet (docs/07 6.2)")
    }
}
