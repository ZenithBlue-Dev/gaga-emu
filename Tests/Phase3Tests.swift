import Metal
import UIKit
import XCTest
@testable import GagaEmu

/// Runs the presets on mGBA's real frames, and the multi-pass chain's parts, through `MetalRenderer`.
final class ShaderChainTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("phase3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeDevice() throws -> MTLDevice {
        try XCTUnwrap(MTLCreateSystemDefaultDevice())
    }

    private func target(_ device: MTLDevice, width: Int = 480, height: Int = 320) throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        return try XCTUnwrap(device.makeTexture(descriptor: desc))
    }

    /// A blocky test picture: colour bars and a diagonal, in the shape of a GBA frame.
    private func sourceTexture(_ device: MTLDevice, width: Int = 240, height: Int = 160) throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        desc.storageMode = .shared
        let texture = try XCTUnwrap(device.makeTexture(descriptor: desc))
        var pixels = [UInt32](repeating: 0, count: width * height)
        let bars: [UInt32] = [0xFF20_30E0, 0xFF30_E040, 0xFFE0_4030, 0xFFF0_F0F0]
        for y in 0..<height {
            for x in 0..<width {
                pixels[y * width + x] = x > y ? bars[(x / 30) % bars.count] : 0xFF10_1010
            }
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
        return texture
    }

    private func bytes(_ texture: MTLTexture) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&out, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return out
    }

    private func meanLevel(_ pixels: [UInt8]) -> Double {
        var sum = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            sum += Int(pixels[index]) + Int(pixels[index + 1]) + Int(pixels[index + 2])
        }
        return Double(sum) / Double(pixels.count / 4 * 3)
    }

    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(a.count)
    }

    private func render(_ renderer: MetalRenderer, _ device: MTLDevice) throws -> [UInt8] {
        let output = try target(device)
        renderer.render(into: output)
        return bytes(output)
    }

    func testEveryPresetDrawsMgbaFramesAndEachLooksDifferent() async throws {
        let device = try makeDevice()
        let rom = directory.appendingPathComponent("homebrew.gba")
        try GBATestROM.build().write(to: rom)
        let interface = GagaCoreRegistry_FindByID("mgba")!.pointee
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        let ring = MetalTextureRing(device: device, width: 240, height: 160)
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        var written = 0
        core.onVideoFrame = { frame in
            guard let pixels = frame.pixelData, let format = MetalTextureRing.metalFormat(for: frame.pixelFormat) else { return }
            if let texture = ring.writeFrame(pixelData: pixels, width: frame.width, height: frame.height, pitch: frame.pitch, pixelFormat: format) {
                renderer.setTexture(texture)
                written += 1
            }
        }
        try await core.loadROM(path: rom.path)
        renderer.textureRing = ring
        renderer.apply(ShaderParameterValues())

        var results: [ShaderPreset: [UInt8]] = [:]
        for preset in ShaderPreset.allCases {
            core.step(inputs: [GagaInputState()])
            renderer.activePreset = preset
            let pixels = try render(renderer, device)
            XCTAssertGreaterThan(meanLevel(pixels), 8, "\(preset) drew almost nothing")
            results[preset] = pixels
        }
        core.stop()
        XCTAssertGreaterThan(written, 0)
        XCTAssertEqual(ring.stats.width, 240)

        // Every pair differs, so no preset silently fell back to another's pass.
        let presets = ShaderPreset.allCases
        for (index, a) in presets.enumerated() {
            for b in presets[(index + 1)...] {
                XCTAssertGreaterThan(difference(results[a]!, results[b]!), 0.05, "\(a) and \(b) look the same")
            }
        }
    }

    func testEveryPassInEveryChainHasACompiledFunction() throws {
        let device = try makeDevice()
        let library = try XCTUnwrap(device.makeDefaultLibrary())
        for preset in ShaderPreset.allCases {
            for upscaler in Upscaler.allCases {
                let chain = MetalRenderer.chain(preset: preset, upscaler: upscaler)
                XCTAssertNil(chain.last?.size, "\(preset) must end on the drawable")
                for pass in chain {
                    XCTAssertNotNil(library.makeFunction(name: pass.fragment), pass.fragment)
                }
            }
        }
    }

    func testChainPutsTheUpscalerFirstAndLeavesSelfScalingPresetsAlone() {
        XCTAssertEqual(MetalRenderer.chain(preset: .crtV1, upscaler: .nearest).count, 1)
        XCTAssertEqual(MetalRenderer.chain(preset: .crtV1, upscaler: .bilinear).count, 1)
        XCTAssertEqual(MetalRenderer.chain(preset: .crtV1, upscaler: .bicubic).map(\.fragment), ["bicubic_fragment", "crt_v1_fragment"])
        XCTAssertEqual(MetalRenderer.chain(preset: .film, upscaler: .edgeSmooth).first?.fragment, "edge_smooth_fragment")
        XCTAssertEqual(MetalRenderer.chain(preset: .crtDeluxe, upscaler: .bicubic).count, 3)
        XCTAssertEqual(MetalRenderer.chain(preset: .anime4k, upscaler: .edgeSmooth).count, 6)
    }

    func testUpscalersChangeThePicture() throws {
        let device = try makeDevice()
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        renderer.setTexture(try sourceTexture(device))
        renderer.apply(ShaderParameterValues())
        var results: [[UInt8]] = []
        for upscaler in Upscaler.allCases {
            renderer.upscaler = upscaler
            let pixels = try render(renderer, device)
            XCTAssertGreaterThan(meanLevel(pixels), 8, upscaler.rawValue)
            results.append(pixels)
        }
        for (index, a) in results.enumerated() {
            for b in results[(index + 1)...] {
                XCTAssertGreaterThan(difference(a, b), 0.02)
            }
        }
    }

    func testOriginalAtDefaultColourIsExact() throws {
        let device = try makeDevice()
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        let source = try sourceTexture(device)
        renderer.setTexture(source)
        renderer.apply(ShaderParameterValues())
        let output = try target(device, width: 240, height: 160)
        renderer.render(into: output)
        let drawn = bytes(output)
        let expected = bytes(source)
        // Output is BGRA, source RGBA.
        for index in stride(from: 0, to: drawn.count, by: 4 * 97) {
            XCTAssertEqual(drawn[index], expected[index + 2])
            XCTAssertEqual(drawn[index + 1], expected[index + 1])
            XCTAssertEqual(drawn[index + 2], expected[index])
        }
    }

    func testSlidersChangeTheFilterThatUsesThem() throws {
        let device = try makeDevice()
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        renderer.setTexture(try sourceTexture(device))
        for preset in ShaderPreset.allCases {
            renderer.activePreset = preset
            for kind in preset.parameters {
                var low = ShaderParameterValues()
                var high = ShaderParameterValues()
                low[keyPath: kind.keyPath] = 0.05
                high[keyPath: kind.keyPath] = 0.95
                renderer.apply(low)
                let a = try render(renderer, device)
                renderer.apply(high)
                let b = try render(renderer, device)
                XCTAssertGreaterThan(difference(a, b), 0.05, "\(preset) ignores \(kind)")
            }
        }
    }

    func testSavedValuesAreClamped() throws {
        let renderer = try XCTUnwrap(MetalRenderer(device: try makeDevice()))
        var values = ShaderParameterValues()
        values.curvature = 9
        values.colorTemp = -3
        values.upscaler = "from-a-later-build"
        renderer.apply(values)
        XCTAssertEqual(renderer.uniforms.curvature, 1)
        XCTAssertEqual(renderer.uniforms.colorTemp, 0)
        XCTAssertEqual(renderer.upscaler, .nearest)
    }

    func testUniformLayoutMatchesTheShaderStruct() {
        XCTAssertEqual(MemoryLayout<ShaderUniforms>.size, 36)
    }

    func testCatalogMatchesThePresetsAndThePremiumList() {
        XCTAssertEqual(Set(ShaderCatalog.all.map(\.id)), Set(ShaderPreset.allCases.map(\.id)))
        XCTAssertEqual(Set(ShaderCatalog.all.filter(\.premium).map(\.id)), StoreKitManager.premiumShaderIDs)
        XCTAssertFalse(ShaderCatalog.all.contains { $0.id == "crt-royale" })
        XCTAssertTrue(ShaderCatalog.community.allSatisfy { $0.credit?.contains("public domain") == true && !$0.premium })
    }
}

/// Bad `.metal` input must end in a plain message, never a crash, and never a kept file.
final class ImportedFilterTests: XCTestCase {
    private var directory: URL!
    private var store: ImportedFilterStore!

    private static let good = """
    #include <metal_stdlib>
    using namespace metal;
    struct ShaderParameters { float curvature; float scanline_weight; float phosphor_glow; float color_temp;
                              float time; uint viewport_w; uint viewport_h; uint source_w; uint source_h; };
    struct VertexOut { float4 position [[position]]; float2 uv; };
    fragment float4 gaga_fragment(VertexOut in [[stage_in]], texture2d<float> core_texture [[texture(0)]],
                                  sampler tex_sampler [[sampler(0)]], constant ShaderParameters& params [[buffer(0)]]) {
        return float4(1.0 - core_texture.sample(tex_sampler, in.uv).rgb, 1.0);
    }
    """

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("filters-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = ImportedFilterStore(directory: directory.appendingPathComponent("kept"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func write(_ text: String, name: String = "test.metal") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    private func assertRefused(_ file: URL, _ check: (FilterImportError) -> Bool, line: UInt = #line) async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        do {
            _ = try await store.add(file: file, device: device)
            XCTFail("Accepted bad input", line: line)
        } catch let error as FilterImportError {
            XCTAssertTrue(check(error), "Wrong refusal: \(error)", line: line)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, line: line)
        }
        XCTAssertTrue(store.entries.isEmpty, "A refused file must not be kept", line: line)
    }

    func testGoodFilterIsKeptAndDrawsThroughTheChain() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let entry = try await store.add(file: try write(Self.good), device: device)
        XCTAssertEqual(entry.id, "import:test")
        XCTAssertEqual(store.entries.map(\.id), ["import:test"])

        let pipeline = try await store.pipeline(for: entry.id, device: device)
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 4, height: 4, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        let source = try XCTUnwrap(device.makeTexture(descriptor: desc))
        source.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0,
                       withBytes: [UInt8](repeating: 255, count: 64), bytesPerRow: 16)
        renderer.setTexture(source)
        renderer.setImported(pipeline)
        let output = try XCTUnwrap(device.makeTexture(descriptor: desc))
        renderer.render(into: output)
        var pixel = [UInt8](repeating: 9, count: 4)
        output.getBytes(&pixel, bytesPerRow: 16, from: MTLRegionMake2D(1, 1, 1, 1), mipmapLevel: 0)
        XCTAssertEqual(Array(pixel[0..<3]), [0, 0, 0], "The imported shader inverts white to black")

        store.delete(entry)
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testRefusals() async throws {
        try await assertRefused(try write("not metal at all {{{")) { if case .compile(let log) = $0 { return !log.isEmpty } else { return false } }
        try await assertRefused(try write("")) { $0 == .empty }
        try await assertRefused(try write(Self.good, name: "test.txt")) { $0 == .notMetalFile }
        try await assertRefused(try write(String(repeating: "/", count: ImportedFilter.maxBytes + 1))) { if case .tooLarge = $0 { return true } else { return false } }
        // Compiles, but has no entry point the app can use.
        try await assertRefused(try write(Self.good.replacingOccurrences(of: "gaga_fragment", with: "other_name"))) { $0 == .missingEntryPoint }
        try await assertRefused(try write("""
        #include <metal_stdlib>
        using namespace metal;
        kernel void gaga_fragment(uint id [[thread_position_in_grid]]) {}
        """)) { $0 == .missingEntryPoint }
        // Links only if the stage_in matches what vertex_main writes.
        try await assertRefused(try write(Self.good.replacingOccurrences(of: "float2 uv;", with: "float3 uv;").replacingOccurrences(of: "in.uv)", with: "in.uv.xy)"))) { if case .link = $0 { return true } else { return false } }
        // Bindings the renderer never sets.
        try await assertRefused(try write(Self.good.replacingOccurrences(of: "[[buffer(0)]]", with: "[[buffer(3)]]"))) { if case .unsupportedBinding = $0 { return true } else { return false } }
        try await assertRefused(try write(Self.good.replacingOccurrences(of: "[[texture(0)]]", with: "[[texture(5)]]"))) { if case .unsupportedBinding = $0 { return true } else { return false } }
        try await assertRefused(try write(Self.good.replacingOccurrences(of: "uint source_h;", with: "uint source_h; float huge[200];"))) { if case .unsupportedBinding = $0 { return true } else { return false } }
        // Reads a file into the compiler's error text.
        try await assertRefused(try write("#include \"/etc/hosts\"\n" + Self.good)) { if case .forbiddenInclude = $0 { return true } else { return false } }
        try await assertRefused(try write("  %: include \"/etc/hosts\"\n" + Self.good)) { if case .forbiddenInclude = $0 { return true } else { return false } }
    }

    func testBinaryFileIsRefused() async throws {
        let url = directory.appendingPathComponent("binary.metal")
        try Data([0x00, 0xFF, 0xFE, 0x01]).write(to: url)
        try await assertRefused(url) { $0 == .notText }
    }

    func testMissingFileThrowsInsteadOfCrashing() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        do {
            _ = try await store.pipeline(for: "import:gone", device: device)
            XCTFail("A deleted filter must throw")
        } catch {}
    }

    @MainActor
    func testRemovedShaderStillFallsBackInASession() {
        XCTAssertEqual(ShaderPreset.from(id: "crt-royale"), .original)
        XCTAssertEqual(ShaderPreset.from(id: "import:mine"), .original)
        XCTAssertTrue(StoreKitManager().canUseShader("import:mine"), "Your own shader is never behind Gaga Plus")
    }
}

/// Network replaced by a stub. No live scraping.
final class StubCoverProtocol: URLProtocol {
    struct Reply {
        var status = 200
        var data = Data()
        var headers: [String: String] = [:]
    }

    static var reply = Reply()
    static var requests: [URLRequest] = []
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let reply = Self.reply
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class CoverArtTests: XCTestCase {
    private var directory: URL!
    private var fetcher: CoverArtFetcher!
    private let game = GameItem(id: UUID(), title: "Some Game (USA)", platformID: "gba", romPath: "/a.gba", coverPath: nil,
                                coreOverride: nil, playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("covers-\(UUID().uuidString)")
        StubCoverProtocol.requests = []
        StubCoverProtocol.reply = .init()
        fetcher = CoverArtFetcher(session: CoverArtFetcher.makeSession(protocolClasses: [StubCoverProtocol.self]), directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func png(width: Int = 32, height: Int = 32) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; return format
        }()).pngData { $0.fill(CGRect(x: 0, y: 0, width: width, height: height)) }
    }

    func testURLIsHTTPSOnThatHostAndEncodesTheTitle() throws {
        let url = try XCTUnwrap(LibretroThumbnails.url(platformID: "gba", title: "A/B: C? (USA) & More"))
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "thumbnails.libretro.com")
        XCTAssertEqual(url.path, "/Nintendo - Game Boy Advance/Named_Boxarts/A_B_ C_ (USA) _ More.png")
        XCTAssertTrue(url.absoluteString.contains("Nintendo%20-%20Game%20Boy%20Advance"))
        XCTAssertNil(LibretroThumbnails.url(platformID: "unknown", title: "Game"))
        XCTAssertNil(LibretroThumbnails.url(platformID: "gba", title: ""))
    }

    func testSessionHasTimeoutsAndKeepsNothing() {
        let configuration = CoverArtFetcher.makeSession().configuration
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 10)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 30)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCache)
    }

    func testAValidImageIsCachedAndShrunk() async throws {
        StubCoverProtocol.reply.data = png(width: 1200, height: 1600)
        let file = await fetcher.fetch(game)
        let cached = try XCTUnwrap(file)
        XCTAssertEqual(fetcher.cachedCover(for: game), cached)
        let image = try XCTUnwrap(UIImage(contentsOfFile: cached.path))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height) * image.scale, CGFloat(CoverArtFetcher.storedPixels))
    }

    func testBadRepliesStayOnThePlaceholder() async {
        let cases: [StubCoverProtocol.Reply] = [
            .init(status: 404, data: png()),
            .init(status: 500),
            .init(data: Data("<html>not an image</html>".utf8)),
            .init(data: Data()),
            .init(data: Data(repeating: 0x41, count: CoverArtFetcher.maxBytes + 1)),
            .init(data: png(), headers: ["Content-Length": "\(CoverArtFetcher.maxBytes + 1)"]),
            .init(data: Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 0, 1, 0, 0, 0, 0, 0x3B]))
        ]
        for reply in cases {
            StubCoverProtocol.reply = reply
            let file = await fetcher.fetch(game)
            XCTAssertNil(file, "status \(reply.status), \(reply.data.count) bytes")
            XCTAssertNil(fetcher.cachedCover(for: game))
        }
    }

    func testOversizedDimensionsAreRefusedBeforeDecoding() {
        XCTAssertNotNil(CoverArtFetcher.validatedPNG(png()))
        XCTAssertNil(CoverArtFetcher.validatedPNG(png(width: CoverArtFetcher.maxPixels + 1, height: 1)))
    }

    @MainActor
    func testNoRequestWhileTheToggleIsOff() async {
        StubCoverProtocol.reply.data = png()
        await fetcher.fetchMissing(games: [game], isEnabled: { false }, onCover: {})
        XCTAssertTrue(StubCoverProtocol.requests.isEmpty)

        let state = AppState()
        let saved = state.coverArt
        defer { state.coverArt = saved }
        state.coverFetcher = fetcher
        state.coverArt = false
        state.refreshCovers()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(StubCoverProtocol.requests.isEmpty)
        XCTAssertNil(state.coverURL(for: game))
    }

    @MainActor
    func testTurningOffStopsTheWalkAndAMissIsNotAskedAgain() async {
        StubCoverProtocol.reply = .init(status: 404)
        await fetcher.fetchMissing(games: [game], isEnabled: { true }, onCover: {})
        await fetcher.fetchMissing(games: [game], isEnabled: { true }, onCover: {})
        XCTAssertEqual(StubCoverProtocol.requests.count, 1)

        var other = game
        other.title = "Another"
        var calls = 0
        StubCoverProtocol.reply = .init(data: png())
        await fetcher.fetchMissing(games: [other], isEnabled: { calls += 1; return calls == 0 }, onCover: {})
        XCTAssertEqual(StubCoverProtocol.requests.count, 1)
    }

    /// Older state.json files say coverScraping true, because it defaulted to on. That must not turn fetching on.
    func testAnOldSavedValueDoesNotTurnCoversOn() throws {
        let json = """
        {"games":[],"history":[],"nickname":"A","joined":0,"avatarIndex":0,"appearance":"dark","quickStart":false,
         "autoSaveStates":false,"coverScraping":true,"airPlayFullscreen":false,"iCloudSync":false,
         "autoFullScreen":true,"respectSilentMode":false,"rumble":false,"skinSoundEffects":true,
         "language":"English","shaderID":"film","defaultCores":{}}
        """
        let snapshot = try JSONDecoder().decode(AppState.Snapshot.self, from: Data(json.utf8))
        XCTAssertNil(snapshot.coverArt, "Absent means off: AppState reads it with ?? false")
        XCTAssertNil(snapshot.shaderParameters)
        XCTAssertNil(snapshot.platformSkins)
    }
}

final class TouchLayoutTests: XCTestCase {
    func testEveryLayoutStaysInTheBandsWithLargeTargetsAndNoOverlaps() {
        for layout in TouchSkinEngine.Layout.builtIn {
            let band = TouchSkinEngine.controlBand
            for button in layout.buttons {
                XCTAssertTrue(button.frame.maxX <= band || button.frame.minX >= 1 - band, "\(layout.id) \(button.id) overlaps the picture")
                XCTAssertGreaterThanOrEqual(button.frame.minY, 0, button.id)
                XCTAssertLessThanOrEqual(button.frame.maxY, 1, "\(layout.id) \(button.id)")
                // iPhone 17e landscape safe canvas: 750 by 369 points.
                XCTAssertGreaterThanOrEqual(button.frame.width * 750, 44, button.id)
                XCTAssertGreaterThanOrEqual(button.frame.height * 369, 44, button.id)
            }
            XCTAssertEqual(Set(layout.buttons.map(\.id)).count, layout.buttons.count, layout.id)
            for (index, a) in layout.buttons.enumerated() {
                for b in layout.buttons[(index + 1)...] {
                    XCTAssertFalse(a.frame.insetBy(dx: 0.0001, dy: 0.0001).intersects(b.frame), "\(layout.id): \(a.id) and \(b.id) overlap")
                }
            }
        }
    }

    func testEveryLayoutHasTheGameBoyAdvanceButtons() {
        let b = ControllerManager.Button.self
        let needed = [b.up, b.down, b.left, b.right, b.south, b.east, b.l1, b.r1, b.start, b.select]
        for layout in TouchSkinEngine.Layout.choices(for: "gba") {
            let all = layout.buttons.reduce(UInt32(0)) { $0 | $1.mask }
            for mask in needed { XCTAssertNotEqual(all & mask, 0, layout.id) }
        }
    }

    func testChoiceOrderGameThenPlatformThenStandard() {
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: nil, platformID: "gba"), "standard")
        XCTAssertEqual(TouchSkinEngine.layoutID(game: nil, platform: "low-reach", platformID: "gba"), "low-reach")
        XCTAssertEqual(TouchSkinEngine.layoutID(game: "two-button", platform: "low-reach", platformID: "gba"), "two-button")
        // Two Button leaves out X and Y, which these systems need.
        XCTAssertEqual(TouchSkinEngine.layoutID(game: "two-button", platform: "low-reach", platformID: "snes"), "low-reach")
        XCTAssertEqual(TouchSkinEngine.layoutID(game: "two-button", platform: nil, platformID: "ps1"), "standard")
        XCTAssertEqual(TouchSkinEngine.layoutID(game: "from-a-later-build", platform: nil, platformID: "gba"), "standard")
    }

    func testEngineLoadsTheChosenLayoutAndHitsItsButtons() throws {
        let engine = TouchSkinEngine()
        engine.hapticsEnabled = false
        engine.soundEnabled = false
        engine.loadBuiltIn("two-button")
        XCTAssertEqual(engine.skin?.id, "two-button")
        XCTAssertNil(engine.skin?.buttons.first { $0.id == "north" })
        let east = try XCTUnwrap(engine.skin?.buttons.first { $0.id == "east" }).frame
        XCTAssertEqual(engine.setTouches([CGPoint(x: east.midX, y: east.midY)]), ControllerManager.Button.east)
        engine.loadBuiltIn("no-such-layout")
        XCTAssertEqual(engine.skin?.id, "standard")
    }

    /// DOSBox Pure opens its on-screen keyboard on L3, so every DOS layout carries a key for it.
    func testDOSLayoutsHaveAKeyboardKeyThatPressesL3() throws {
        let band = TouchSkinEngine.controlBand
        for layout in TouchSkinEngine.Layout.choices(for: "dos") {
            let buttons = layout.buttons(for: "dos")
            let key = try XCTUnwrap(buttons.first { $0.id == "l3" }, layout.id)
            XCTAssertEqual(key.mask, ControllerManager.Button.l3)
            XCTAssertTrue(key.frame.maxX <= band, layout.id)
            XCTAssertGreaterThanOrEqual(key.frame.height * 369, 44)
            for other in buttons where other.id != "l3" {
                XCTAssertFalse(key.frame.intersects(other.frame), "\(layout.id): keyboard and \(other.id) overlap")
            }
        }
        XCTAssertNil(TouchSkinEngine.Layout.standard.buttons(for: "gba").first { $0.id == "l3" })

        let engine = TouchSkinEngine()
        engine.hapticsEnabled = false
        engine.soundEnabled = false
        engine.loadBuiltIn("low-reach", platformID: "dos")
        let frame = try XCTUnwrap(engine.skin?.buttons.first { $0.id == "l3" }).frame
        XCTAssertEqual(engine.setTouches([CGPoint(x: frame.midX, y: frame.midY)]), ControllerManager.Button.l3)
        XCTAssertEqual(TouchSkinEngine.mask(for: "l3"), ControllerManager.Button.l3)
        XCTAssertEqual(TouchSkinEngine.label(for: "l3").spoken, "Keyboard")
    }

    func testAGameSkinSurvivesASaveAndOldFilesDecode() throws {
        var game = GameItem(id: UUID(), title: "A", platformID: "gba", romPath: "/a", coverPath: nil, coreOverride: nil,
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertNil(game.skinID)
        game.skinID = "low-reach"
        let round = try JSONDecoder().decode(GameItem.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(round.skinID, "low-reach")
    }
}
