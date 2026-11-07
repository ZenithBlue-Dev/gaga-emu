import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// Flycast through the real bridge (milestone 6.2): the SH-4, ARM7 and AICA DSP interpreters, and Flycast's
/// Vulkan renderer on MoltenVK, presenting to a CAMetalLayer. Device pending: built, not yet run on a device
/// (docs/07 6.2). No homebrew Dreamcast disc is generated yet, so the tests that need a running game skip;
/// docs/07 6.2 says what a generator needs.
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

    func testBenchmarkHasNoDreamcastTestFileYet() {
        XCTAssertThrowsError(try BenchmarkRun.writeTestROM(platformID: "dreamcast", to: directory))
    }

    func testBootsAGameAndDrawsAPicture() throws {
        throw XCTSkip("no free Dreamcast test disc yet (docs/07 6.2)")
    }

    func testInputAudioVMUSaveAndStateRoundTrip() throws {
        throw XCTSkip("no free Dreamcast test disc yet (docs/07 6.2)")
    }
}
