import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// Azahar through the real bridge (milestone 6.3): the dyncom ARM11 interpreter, the shader interpreter, and
/// Azahar's Vulkan renderer on MoltenVK presenting to a CAMetalLayer. Device pending: built, not yet run on a
/// device (docs/07 6.3). The running-game test boots N3DSTestProgram, a self-made .3dsx.
@MainActor
final class AzaharCoreTests: GagaTestCase {
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

    func testBenchmarkWritesThe3DSTestProgram() throws {
        let url = try BenchmarkRun.writeTestROM(platformID: "n3ds", to: directory)
        XCTAssertEqual(url.pathExtension, "3dsx")
        XCTAssertEqual(CoreCatalog.platformID(forFile: url), "n3ds")
        XCTAssertEqual(try Data(contentsOf: url).prefix(4), Data("3DSX".utf8))
    }

    /// Device pending: N3DSTestProgram fills each default framebuffer with its own colour. Side by side, the top
    /// screen is the left 400 of every 720 columns and the bottom screen the right 320.
    func testBootsTheTestProgramAndDrawsBothScreens() async throws {
        final class Capture {
            var frames = 0
            var fatal: String?
        }
        let core = try makeCore()
        let capture = Capture()
        core.onVideoFrame = { _ in capture.frames += 1 }
        core.onEvent = { event in if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message } }
        try await core.loadROM(path: try write(N3DSTestProgram.build(), name: "test.3dsx"))
        for _ in 0..<120 { core.step(inputs: [GagaInputState()]) }
        XCTAssertNil(capture.fatal)
        XCTAssertGreaterThan(capture.frames, 0, "no frame presented")
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented")
        XCTAssertEqual(frame.width * 240, frame.height * 720, "side by side, \(frame.width)x\(frame.height)")
        func pixel(_ column: Int) -> [UInt8] {
            let i = ((frame.height / 2) * frame.width + column * frame.width / 720) * 4
            return Array(frame.pixels[i..<i + 4])
        }
        func near(_ got: [UInt8], _ want: [UInt8]) -> Bool { zip(got, want).allSatisfy { abs(Int($0) - Int($1)) <= 8 } }
        XCTAssertTrue(near(pixel(200), N3DSTestProgram.topBGRA), "top screen: \(pixel(200))")
        XCTAssertTrue(near(pixel(560), N3DSTestProgram.bottomBGRA), "bottom screen: \(pixel(560))")
        core.stop()
    }

    /// A finger on the middle of the bottom screen reaches Azahar as that screen's middle. Azahar scales the
    /// libretro pointer over the whole frame and keeps it if it lands on the bottom screen (mouse_tracker.cpp).
    func testAFingerOnTheBottomScreenMapsToItsTouchPoint() throws {
        let content = CGSize(width: 720, height: 240) // Side by side: top 400x240, bottom 320x240 at x 400.
        let bounds = CGSize(width: 1600, height: 480) // Wider than 3:1, so the picture is letterboxed left and right.
        let pointer = try XCTUnwrap(GameSession.libretroPointer(CGPoint(x: 80 + 560 * 2, y: 240), bounds: bounds, content: content))
        let x = Int(Float(Int(pointer.x) + 0x7fff) / Float(0x7fff * 2) * 720)
        let y = Int(Float(Int(pointer.y) + 0x7fff) / Float(0x7fff * 2) * 240)
        XCTAssertEqual(x - 400, 160, accuracy: 1)
        XCTAssertEqual(y, 120, accuracy: 1)
        XCTAssertNil(GameSession.libretroPointer(CGPoint(x: 40, y: 240), bounds: bounds, content: content), "letterbox")
    }

    func testTouchInputAudioSaveAndStateRoundTrip() throws {
        throw XCTSkip("the 3DS test program reads no input and plays no sound yet (docs/07 6.3)")
    }
}
