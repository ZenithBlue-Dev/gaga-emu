import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// Azahar through the real bridge (milestone 6.3): the dyncom ARM11 interpreter, the shader interpreter, and
/// Azahar's Vulkan renderer on MoltenVK presenting to a CAMetalLayer. Device pending: built, not yet run on a
/// device (docs/07 6.3). No homebrew 3DS program is generated yet, so the tests that need a running game skip.
@MainActor
final class AzaharCoreTests: XCTestCase {
    private var directory: URL!
    private let interface = GagaCoreRegistry_FindByID("azahar")!.pointee

    override func setUp() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("azahar"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("3ds-\(UUID().uuidString)")
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
        XCTAssertTrue(CoreCatalog.drawsOwnPicture("azahar"))
        for ext in ["3ds", "3dsx", "cci", "cxi", "app", "axf"] {
            XCTAssertEqual(CoreCatalog.platformID(forExtension: ext), "n3ds", ext)
        }
        XCTAssertNil(CoreCatalog.platformID(forExtension: "cia"), "encrypted installs are not supported")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "n3ds"), "azahar")
        XCTAssertEqual(interface.state_version, 21262)
    }

    /// .elf is shared with PSP: an ARM ELF goes to 3DS, anything else stays PSP.
    func testElfFilesAreRoutedByMachine() throws {
        var arm = Data([0x7F, 0x45, 0x4C, 0x46, 1, 1, 1] + [UInt8](repeating: 0, count: 45))
        arm[18] = 40
        var mips = arm
        mips[18] = 8
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: try write(arm, name: "a.elf"))), "n3ds")
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: try write(mips, name: "m.elf"))), "psp")
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "elf"), "psp")
    }

    /// Azahar reads games by path, so a bad file is refused by retro_load_game.
    func testBadFilesGiveAMessageForThePlayer() async throws {
        let files = [try write(Data(), name: "empty.3ds"),
                     try write(Data(repeating: 0x41, count: 0x8000), name: "text.cci"),
                     try write(Data(repeating: 0, count: 0x400), name: "zero.3dsx")]
        for path in files {
            let core = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, "This file is not a decrypted Nintendo 3DS game or 3DS homebrew.")
            }
            core.stop()
        }
    }

    /// No keys, firmware or system files are shipped or written.
    func testNoSystemFilesAreWritten() async throws {
        let core = try makeCore()
        try? await core.loadROM(path: try write(Data(), name: "empty.3ds"))
        core.stop()
        let found = FileManager.default.enumerator(atPath: directory.path)?.compactMap { $0 as? String } ?? []
        XCTAssertFalse(found.contains { $0.hasSuffix("aes_keys.txt") || $0.hasSuffix("seeddb.bin") }, "\(found)")
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let core = try makeCore()
        try? await core.loadROM(path: try write(Data(repeating: 0x41, count: 0x8000), name: "text.cci"))
        core.stop()
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testBenchmarkHasNo3DSTestFileYet() {
        XCTAssertThrowsError(try BenchmarkRun.writeTestROM(platformID: "n3ds", to: directory))
    }

    func testBootsAGameAndDrawsBothScreens() throws {
        throw XCTSkip("no free 3DS test program yet (docs/07 6.3)")
    }

    func testTouchInputAudioSaveAndStateRoundTrip() throws {
        throw XCTSkip("no free 3DS test program yet (docs/07 6.3)")
    }
}
