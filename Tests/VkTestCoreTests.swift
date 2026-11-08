import Metal
import QuartzCore
import UIKit
import XCTest
@testable import GagaEmu

/// The layer path (milestone 5.1) through the real bridge: the Vulkan test core (Cores/vktest) renders
/// with the adapter's libretro Vulkan context on MoltenVK and presents to a CAMetalLayer.
@MainActor
final class VkTestCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("vktest")!.pointee
    private var layer: CAMetalLayer!

    override func setUp() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("vktest"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("vktest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        romPath = try write(VkTestROM.build())
        // In the test host's window when there is one, as the game view puts it.
        layer = CAMetalLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first
        window?.layer.addSublayer(layer)
    }

    override func tearDown() async throws {
        layer?.removeFromSuperlayer()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func write(_ data: Data, name: String = "triangle.gagavk") throws -> String {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    private final class Capture {
        var frames = 0
        var lastWidth = 0
        var hadPixels = false
        var left: [Int16] = []
        var fatal: String?
        var rumble: [RumbleManager.Change] = []
    }

    private func makeCore() throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            capture.frames += 1
            capture.lastWidth = frame.width
            if frame.pixelData != nil { capture.hadPixels = true }
        }
        core.onAudioPacket = { packet in
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) { capture.left.append(packet.samples[index]) }
        }
        core.onEvent = { event in
            if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message }
            if event.severity == GAGA_EVENT_RUMBLE { capture.rumble.append(RumbleManager.Change(code: event.code)) }
        }
        return (core, capture)
    }

    private func loaded(_ flags: VkTestROM.Flags = [], attach: Bool = true) async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: flags.isEmpty ? romPath : try write(VkTestROM.build(flags), name: "flags\(flags.rawValue).gagavk"))
        if attach { XCTAssertTrue(core.attachMetalLayer(layer, width: 800, height: 600, scale: 2)) }
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0) {
        var input = GagaInputState()
        input.buttons = buttons
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    private func pixel(_ frame: (pixels: Data, width: Int, height: Int), x: Int, y: Int) -> [UInt8] {
        let i = (y * frame.width + x) * 4
        return Array(frame.pixels[i..<i + 4])
    }

    private func assertColor(_ got: [UInt8], _ want: [UInt8], _ what: String, line: UInt = #line) {
        XCTAssertTrue(zip(got, want).allSatisfy { abs(Int($0) - Int($1)) <= 1 }, "\(what): \(got), want \(want)", line: line)
    }

    /// The triangle's apex is at (160, 60) and its base runs from (80, 180) to (240, 180).
    private func assertPicture(_ core: GagaCoreWrapper, offset: Int = 0, line: UInt = #line) throws {
        let frame = try XCTUnwrap(core.readLayerPixels(), "no frame presented", line: line)
        XCTAssertEqual(frame.width, VkTestROM.width, line: line)
        XCTAssertEqual(frame.height, VkTestROM.height, line: line)
        assertColor(pixel(frame, x: 160 + offset, y: 140), VkTestROM.triangleBGRA, "inside", line: line)
        assertColor(pixel(frame, x: 5, y: 5), VkTestROM.clearBGRA, "corner", line: line)
        assertColor(pixel(frame, x: 160 + offset, y: 40), VkTestROM.clearBGRA, "above the apex", line: line)
    }

    // MARK: - Picture

    func testTheCoreIsALayerPathCore() throws {
        XCTAssertEqual(interface.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertNotEqual(interface.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue, 0)
        XCTAssertNotNil(interface.attach_metal_layer)
        XCTAssertNotNil(interface.detach_metal_layer)
        XCTAssertNotNil(interface.read_layer_pixels)
        XCTAssertTrue(CoreCatalog.drawsOwnPicture("vktest"))
        XCTAssertFalse(CoreCatalog.drawsOwnPicture("gambatte"))
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "gagavk"), "vktest")
    }

    func testDrawsTheTriangleIntoTheLayer() async throws {
        let (core, capture) = try await loaded()
        XCTAssertTrue(core.usesMetalLayer)
        run(core, frames: 10)
        try assertPicture(core)
        XCTAssertEqual(capture.frames, 10, "a size-only frame for each one presented")
        XCTAssertEqual(capture.lastWidth, VkTestROM.width)
        XCTAssertFalse(capture.hadPixels, "a layer-path core sends no pixels")
        XCTAssertEqual(layer.drawableSize, CGSize(width: 800, height: 600), "MoltenVK sized the drawables")
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    /// Fast-forward: frames the host drops render but are not presented, so FIFO's vsync wait comes once per tick.
    func testDroppedFastForwardFramesAreNotPresented() async throws {
        let (core, capture) = try await loaded()
        var dropped = GagaInputState()
        dropped.skip_present = true
        for _ in 0..<20 { core.step(inputs: [dropped]) }
        XCTAssertEqual(capture.frames, 0, "no size-only frame for a dropped frame")
        XCTAssertNil(core.readLayerPixels(), "nothing presented yet")
        run(core, frames: 1)
        XCTAssertEqual(capture.frames, 1)
        try assertPicture(core)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testTheDPadMovesTheTriangle() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let before = try XCTUnwrap(core.readLayerPixels())
        assertColor(pixel(before, x: 100, y: 170), VkTestROM.triangleBGRA, "left of the base before")
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_RIGHT.rawValue))
        try assertPicture(core, offset: 20 * VkTestROM.stepPixels)
        let after = try XCTUnwrap(core.readLayerPixels())
        assertColor(pixel(after, x: 100, y: 170), VkTestROM.clearBGRA, "left of the base after")
        core.stop()
    }

    func testBothDevicePathsAndFrontendSubmitDraw() async throws {
        for flags: VkTestROM.Flags in [.noNegotiation, .frontendSubmit, [.noNegotiation, .frontendSubmit]] {
            let (core, capture) = try await loaded(flags)
            run(core, frames: 6)
            try assertPicture(core)
            XCTAssertNil(capture.fatal, "flags \(flags.rawValue)")
            core.stop()
        }
    }

    /// The layer path hands the screen what the texture path does: UNORM bytes tagged sRGB. The core clears
    /// to (0, 0.25, 0.5) in a UNORM image, so 0.25 must read 64 (not 137, which a second gamma encode gives),
    /// through the same copy the swapchain gets.
    func testLayerColourMatchesTheTexturePath() async throws {
        MetalRenderer.configureOutput(layer)
        let (core, _) = try await loaded()
        run(core, frames: 3)
        let frame = try XCTUnwrap(core.readLayerPixels())
        XCTAssertEqual(pixel(frame, x: 5, y: 5), [128, 64, 0, 255], "exact clear bytes, B G R A")
        XCTAssertEqual(layer.pixelFormat, MetalRenderer.outputPixelFormat, "MoltenVK kept the texture path's format")
        XCTAssertEqual(layer.colorspace?.name as String?, CGColorSpace.sRGB as String, "MoltenVK kept the sRGB tag")
        core.stop()
    }

    /// A finger on a layer-path picture reaches the core: the session takes the frame size from the core's
    /// size-only frames, as it takes the texture's on the copy path.
    func testASessionPlacesAFingerOnTheLayerPicture() async throws {
        let game = GameItem(id: UUID(), title: "Triangle", platformID: "vktest", romPath: romPath, coverPath: nil,
                            coreOverride: "vktest", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let controllers = ControllerManager()
        controllers.devices = []
        let skins = TouchSkinEngine()
        skins.loadDefault()
        let session = try GameSession(game: game, interface: interface, romPath: romPath, audio: AudioEngineManager(),
                                      controllers: controllers, skins: skins, bindings: [], shaderID: "original",
                                      respectSilentMode: false, saveDirectory: directory)
        XCTAssertTrue(session.drawsOwnPicture)
        try await session.prepare()
        session.attachLayer(layer, width: 800, height: 600, scale: 2)
        session.run()
        let deadline = Date().addingTimeInterval(5)
        while session.renderer.contentSize == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let content = try XCTUnwrap(session.renderer.contentSize, "no size-only frame reached the session")
        XCTAssertEqual(content, CGSize(width: VkTestROM.width, height: VkTestROM.height))
        let middle = try XCTUnwrap(GameSession.libretroPointer(CGPoint(x: 200, y: 150), bounds: layer.bounds.size, content: content))
        XCTAssertEqual(middle.x, 0)
        XCTAssertEqual(middle.y, 0)
        // Presented layer frames count as written, and the benchmark's screenshot reads the layer back.
        XCTAssertGreaterThan(session.stats.videoWritten, 0)
        session.pause(.menu)
        XCTAssertNotNil(session.benchmarkScreenshot().flatMap(UIImage.init(data:)))
        session.stop()
    }

    func testAudioIsATone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 30)
        XCTAssertEqual(capture.left.count, 30 * 800)
        XCTAssertEqual(capture.left.max(), 3000)
        XCTAssertEqual(capture.left.min(), -3000)
        core.stop()
    }

    /// The core's set_rumble_state reaches the host through the adapter as one event per change, after the frame.
    func testSetRumbleStateBecomesRumbleEvents() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 3)
        XCTAssertEqual(capture.rumble, [], "a motor that stays off sends nothing")
        run(core, frames: 3, buttons: UInt32(GAGA_BTN_EAST.rawValue | GAGA_BTN_SOUTH.rawValue))
        XCTAssertEqual(capture.rumble, [.init(port: 1, motor: .strong, strength: 0xFFFF), .init(port: 1, motor: .weak, strength: 0x8000)],
                       "each change once, with its port and motor")
        capture.rumble = []
        run(core, frames: 1)
        XCTAssertEqual(capture.rumble, [.init(port: 1, motor: .strong, strength: 0), .init(port: 1, motor: .weak, strength: 0)])
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    // MARK: - Output texture (docs/05 section 2.4)

    /// Inverts the frame, so the expected bytes are 255 minus the core's.
    private let invertFilter = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; float2 uv; };
    struct ShaderParameters { float curvature; float scanlineWeight; float phosphorGlow; float colorTemp; float time;
                              uint viewportW; uint viewportH; uint sourceW; uint sourceH; };
    fragment float4 gaga_fragment(VertexOut in [[stage_in]], texture2d<float> core_texture [[texture(0)]],
                                  sampler tex_sampler [[sampler(0)]], constant ShaderParameters& params [[buffer(0)]]) {
        return float4(1.0 - core_texture.sample(tex_sampler, in.uv).rgb, 1.0);
    }
    """

    /// A filter on a layer-path core: frames come as Metal textures, through the ring and the filter chain.
    /// Device pending: built, not run on a device yet.
    func testAFilterDrawsTheCoreFramesOnTheOutputTexturePath() async throws {
        XCTAssertNotEqual(interface.capabilities & GAGA_CORE_CAP_OUTPUT_TEXTURE.rawValue, 0)
        let (core, capture) = try await loaded(attach: false)
        let renderer = try XCTUnwrap(MetalRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice())))
        let ring = MetalTextureRing(device: renderer.device, width: 1, height: 1)
        renderer.textureRing = ring
        var textures = 0
        core.onVideoFrame = { frame in
            guard frame.pixelFormat == GAGA_PIXEL_FORMAT_METAL_TEXTURE, let shared = frame.pixelData else { return }
            textures += 1
            renderer.receive(shared.load(as: GagaMetalTextureFrame.self), ring: ring)
        }
        XCTAssertTrue(core.attachOutputTexture())
        renderer.setImported(try ImportedFilter.pipeline(source: invertFilter, device: renderer.device))
        run(core, frames: 3)
        XCTAssertEqual(textures, 3, "a texture frame for each one shown")
        XCTAssertEqual(ring.stats.width, VkTestROM.width)
        XCTAssertEqual(ring.stats.pixelFormat, .bgra8Unorm)

        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: VkTestROM.width,
                                                            height: VkTestROM.height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        let target = try XCTUnwrap(renderer.device.makeTexture(descriptor: desc))
        renderer.render(into: target)
        var bytes = [UInt8](repeating: 0, count: target.width * target.height * 4)
        target.getBytes(&bytes, bytesPerRow: target.width * 4, from: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0)
        let drawn = (pixels: Data(bytes), width: target.width, height: target.height)
        let inverted = { (bgra: [UInt8]) in bgra.prefix(3).map { 255 - $0 } + [255] }
        assertColor(pixel(drawn, x: 5, y: 5), inverted(VkTestROM.clearBGRA), "filtered corner")
        assertColor(pixel(drawn, x: 160, y: 140), inverted(VkTestROM.triangleBGRA), "filtered triangle")
        try assertPicture(core) // Read back still works: the frame is still copied once.

        // Back to the layer: the core presents again and sends size-only frames.
        XCTAssertTrue(core.attachMetalLayer(layer, width: 800, height: 600, scale: 2))
        run(core, frames: 2)
        XCTAssertEqual(textures, 3)
        try assertPicture(core)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    /// A session with a filter on a layer-path core draws through the renderer; Original keeps the layer.
    func testASessionWithAFilterUsesTheOutputTexture() async throws {
        for (shader, filtered) in [("crt-v1", true), ("original", false)] {
            let game = GameItem(id: UUID(), title: "Triangle", platformID: "vktest", romPath: romPath, coverPath: nil,
                                coreOverride: "vktest", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: shader)
            let controllers = ControllerManager()
            controllers.devices = []
            let skins = TouchSkinEngine()
            skins.loadDefault()
            let session = try GameSession(game: game, interface: interface, romPath: romPath, audio: AudioEngineManager(),
                                          controllers: controllers, skins: skins, bindings: [], shaderID: shader,
                                          respectSilentMode: false, saveDirectory: directory)
            XCTAssertEqual(session.filtersLayerCore, filtered, shader)
            guard filtered else { continue }
            try await session.prepare()
            XCTAssertTrue(session.filtersLayerCore, "the core took the output texture")
            session.run()
            let deadline = Date().addingTimeInterval(5)
            while session.renderer.contentSize == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(session.renderer.contentSize, CGSize(width: VkTestROM.width, height: VkTestROM.height))
            XCTAssertGreaterThan(session.stats.videoWritten, 0)
            session.stop()
        }
    }

    // MARK: - Layer

    func testResizeDetachAndReattach() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 3)
        // The same size again (a turn between the two landscapes) and a new one.
        XCTAssertTrue(core.attachMetalLayer(layer, width: 800, height: 600, scale: 2))
        layer.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        XCTAssertTrue(core.attachMetalLayer(layer, width: 600, height: 800, scale: 2))
        run(core, frames: 3)
        XCTAssertEqual(layer.drawableSize, CGSize(width: 600, height: 800))
        core.detachMetalLayer()
        run(core, frames: 3) // Renders, shows nothing.
        try assertPicture(core)
        let other = CAMetalLayer()
        other.frame = CGRect(x: 0, y: 0, width: 200, height: 150)
        XCTAssertTrue(core.attachMetalLayer(other, width: 400, height: 300, scale: 2))
        run(core, frames: 3)
        XCTAssertEqual(other.drawableSize, CGSize(width: 400, height: 300))
        try assertPicture(core)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testRunsWithNoLayerAndAttachesLater() async throws {
        let (core, _) = try await loaded(attach: false)
        run(core, frames: 3)
        try assertPicture(core)
        XCTAssertTrue(core.attachMetalLayer(layer, width: 800, height: 600, scale: 2))
        run(core, frames: 3)
        try assertPicture(core)
        core.stop()
    }

    func testPauseAndResumeKeepThePicture() async throws {
        let (core, _) = try await loaded()
        core.start()
        try await Task.sleep(for: .milliseconds(200))
        core.pause()
        let paused = core.stats.frames
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(core.stats.frames, paused, "no frames while paused")
        try assertPicture(core)
        core.resume()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(core.stats.frames, paused)
        core.stop()
    }

    // MARK: - Lifecycle

    func testTeardownAndRelaunchTenTimes() async throws {
        for round in 0..<10 {
            let (core, capture) = try await loaded(round % 2 == 0 ? [] : .noNegotiation)
            run(core, frames: 4)
            try assertPicture(core)
            XCTAssertNil(capture.fatal)
            core.stop()
        }
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, _) = try await loaded()
        run(core, frames: 120, buttons: UInt32(GAGA_BTN_LEFT.rawValue))
        core.stop()
        // MoltenVK compiles MSL to an MTLLibrary for the GPU. That makes no executable CPU pages.
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let cases = [(try write(Data(), name: "empty.gagavk"), "This file is not a GagaEmu Vulkan test file."),
                     (try write(Data("GAGAVK2\0".utf8), name: "other.gagavk"), "This file is not a GagaEmu Vulkan test file.")]
        for (path, message) in cases {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, message)
            }
            core.stop()
        }
        let (core, _) = try await loaded()
        run(core, frames: 2)
        try assertPicture(core)
        core.stop()
    }

    // MARK: - Saves

    func testBatteryBootCounterSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("triangle.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 2)
            core.flushBatterySave()
            let bytes = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(Array(bytes[0..<4]), Array("GAVK".utf8))
            XCTAssertEqual(Int(bytes[4]), boot)
            core.stop()
        }
    }

    func testStateRoundTripAndARefusedStateLeavesTheGameRunning() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 10, buttons: UInt32(GAGA_BTN_RIGHT.rawValue))
        let state = try core.saveState()
        run(core, frames: 20, buttons: UInt32(GAGA_BTN_LEFT.rawValue))
        try core.loadState(state)
        run(core, frames: 1)
        try assertPicture(core, offset: 10 * VkTestROM.stepPixels)
        XCTAssertThrowsError(try core.loadState(Data(repeating: 0, count: 3)))
        run(core, frames: 1)
        try assertPicture(core, offset: 10 * VkTestROM.stepPixels)
        core.stop()
    }

    func testBenchmarkWritesATestFile() throws {
        XCTAssertEqual(try BenchmarkRun.writeTestROM(platformID: "vktest", to: directory).pathExtension, "gagavk")
    }

    #if !GAGA_SIDELOAD
    func testFilterStatementNamesLayerPathCores() {
        XCTAssertEqual(GagaPlusView.filterStatement(layerPathCores: []),
                       "Premium Filters work only on cores that draw through the app's filter chain.")
        XCTAssertEqual(GagaPlusView.filterStatement(layerPathCores: ["Vulkan Test"]),
                       "Premium Filters work only on cores that draw through the app's filter chain. Vulkan Test draws its own 3D picture, so filters do not apply there.")
    }
    #endif
}
