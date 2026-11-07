import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// Beetle PSX HW through the shared libretro adapter and the real bridge (milestone 5.4): Mednafen's interpreter
/// and the Vulkan renderer on MoltenVK, presenting to a CAMetalLayer. No Sony BIOS is in the system folder, so the
/// core boots the OpenBIOS build it embeds. Upstream starts a PS-EXE only by patching a Sony BIOS, and OpenBIOS
/// refuses `PS1TestEXE.disc()` (no licence sector), so these tests check the bridge contract on OpenBIOS's own
/// screen, not the homebrew program's picture, and that a PS-EXE is refused with a message. A player's own BIOS
/// runs both. Device pending: built, not yet run on a device (docs/07 5.4).
@MainActor
final class BeetlePsxCoreTests: XCTestCase {
    private var directory: URL!
    private var cuePath: String!
    private let interface = GagaCoreRegistry_FindByID("beetle_psx")!.pointee
    private var layer: CAMetalLayer!
    private static let headerSize = 16

    override func setUp() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_psx"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("beetle-psx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let disc = PS1TestEXE.disc()
        try disc.bin.write(to: directory.appendingPathComponent("homebrew.bin"))
        let cue = directory.appendingPathComponent("homebrew.cue")
        try disc.cue("homebrew.bin").write(to: cue, atomically: true, encoding: .utf8)
        cuePath = cue.path
        layer = CAMetalLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first
        window?.layer.addSublayer(layer)
    }

    override func tearDown() async throws {
        layer?.removeFromSuperlayer()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private final class Capture {
        var frames = 0
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var fatal: String?
    }

    private func makeCore() throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        let capture = Capture()
        core.onVideoFrame = { _ in capture.frames += 1 }
        core.onAudioPacket = { packet in
            capture.sampleRate = packet.sampleRate
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) { capture.left.append(packet.samples[index]) }
        }
        core.onEvent = { event in if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message } }
        return (core, capture)
    }

    private func loaded() async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: cuePath)
        XCTAssertTrue(core.attachMetalLayer(layer, width: 800, height: 600, scale: 2))
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    /// Keeps a BGRA8 frame in the result bundle as a PNG.
    private func attach(_ pixels: Data, width: Int, height: Int, named name: String) {
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func picture(_ core: GagaCoreWrapper, line: UInt = #line) throws -> [UInt8] {
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented", line: line)
        return [UInt8](frame.pixels)
    }

    func testTheCoreIsALayerPathAlternate() throws {
        XCTAssertEqual(interface.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: interface.core_version), "0.9.44.1 71ee81e7")
        XCTAssertEqual(interface.native_sample_rate, 44100)
        XCTAssertNotEqual(interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue, 0)
        XCTAssertTrue(CoreCatalog.drawsOwnPicture("beetle_psx"))
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(interface.self_test(&error, error.count))
        XCTAssertTrue(CoreCatalog.platform("ps1")?.cores.contains { $0.id == "beetle_psx" } ?? false)
        if !GagaCoreRegistry_IsExcluded("pcsx_rearmed") {
            XCTAssertEqual(CoreCatalog.defaultCore(for: "ps1"), "pcsx_rearmed", "an alternate, never the default")
        }
        let game = GameItem(id: UUID(), title: "t", platformID: "ps1", romPath: cuePath, coverPath: nil, coreOverride: "beetle_psx",
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "beetle_psx", "picked per game through core switching")
    }

    /// OpenBIOS's screen, drawn by the Vulkan renderer: frames reach the layer, the picture is not one flat
    /// colour, and the BIOS plays sound. Its tiny shell spins a flat-shaded cube on a blue (0x004058) field: the
    /// software renderer on a Mac shows the cube's three faces from frame 60 on (black border, field and faces, 5
    /// colours at frame 180), so more frames do not help a picture with fewer. The picture is attached either way.
    func testOpenBIOSBootsOnTheVulkanLayerWithNoBIOSFile() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 180)
        XCTAssertNil(capture.fatal)
        XCTAssertGreaterThan(capture.frames, 0)
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented")
        let pixels = [UInt8](frame.pixels)
        var counts: [Int: Int] = [:]
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            counts[Int(pixels[index]) << 16 | Int(pixels[index + 1]) << 8 | Int(pixels[index + 2]), default: 0] += 1
        }
        let listed = counts.sorted { $0.value > $1.value }.prefix(8).map { String(format: "BGR %06x x%d", $0.key, $0.value) }
        attach(frame.pixels, width: frame.width, height: frame.height, named: "OpenBIOS frame 180")
        XCTAssertGreaterThan(counts.count, 2, "not one flat colour: \(frame.width)x\(frame.height) \(listed)")
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertGreaterThan(Int(capture.left.max() ?? 0) - Int(capture.left.min() ?? 0), 5000, "not silent")
        core.stop()
    }

    /// upstream would patch OpenBIOS at a Sony BIOS offset and never start the program, so the bridge refuses first.
    func testAPSEXEWithoutTheSonyBIOSIsRefusedWithAMessage() async throws {
        let exe = directory.appendingPathComponent("homebrew.exe")
        try PS1TestEXE.build().write(to: exe)
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: exe.path)
            XCTFail("loaded a PS-EXE with no BIOS")
        } catch {
            XCTAssertTrue(error.localizedDescription.hasPrefix("Beetle PSX HW needs the PlayStation BIOS scph5501.bin"))
        }
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        try core.loadState(try core.saveState())
        core.stop()
        // Interpreter only, and MoltenVK's GPU-only shader compiles: no executable CPU pages.
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    /// Beetle loads by path and has no is_rom, so the adapter never opens the file and upstream's refusal is the
    /// message.
    func testBadFilesGiveAMessageForThePlayer() async throws {
        let noise = directory.appendingPathComponent("noise.cue")
        try "FILE \"gone.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n".write(to: noise, atomically: true, encoding: .utf8)
        for path in [noise.path, directory.appendingPathComponent("gone.chd").path] {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, "Beetle PSX HW could not load this game.")
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
        let first = try picture(core)
        try core.loadState(state)
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_SOUTH.rawValue))
        XCTAssertEqual(try picture(core), first, "the same input from the same state gives the same frame")

        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var damaged = state
        for index in Self.headerSize..<(Self.headerSize + 32) { damaged[index] ^= 0x5A }
        let cases: [(Data, String)] = [
            (wrongMagic, "This save state belongs to another game or another version of this game."),
            (state.prefix(state.count - 1), "This save state is the wrong size for Beetle PSX HW."),
            (damaged, "Beetle PSX HW could not load this save state."),
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

    /// The Vulkan context, the core's device and the renderer's threads are torn down and built again each time.
    func testTeardownAndRelaunchThreeTimes() async throws {
        for _ in 1...3 {
            let (core, capture) = try await loaded()
            run(core, frames: 30)
            XCTAssertNotNil(core.readLayerPixels())
            XCTAssertNil(capture.fatal)
            core.stop()
        }
    }
}
