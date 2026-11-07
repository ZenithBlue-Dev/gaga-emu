import Metal
import XCTest
@testable import GagaEmu

/// `.slangp` import (docs/05 section 4.2, milestone 3.6) with small presets written here: parsing, the
/// glslang and SPIRV-Cross translation, and the translated chain drawing through `MetalRenderer`.
final class SlangImportTests: GagaTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("slang-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("shaders"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Fixtures

    /// Mixes the pass's input with the inverse of the core frame by AMOUNT. Uses push constants, the uniform
    /// block, an include and both textures.
    private static let invert = """
    #version 450
    #include "../include/common.inc"

    #pragma parameter AMOUNT "Invert amount" 0.5 0.0 1.0 0.25
    #pragma name Inverted

    #pragma stage vertex
    layout(location = 0) in vec4 Position;
    layout(location = 1) in vec2 TexCoord;
    layout(location = 0) out vec2 vTexCoord;
    void main() {
        gl_Position = global.MVP * Position;
        vTexCoord = TexCoord;
    }

    #pragma stage fragment
    layout(location = 0) in vec2 vTexCoord;
    layout(location = 0) out vec4 FragColor;
    layout(set = 0, binding = 2) uniform sampler2D Source;
    layout(set = 0, binding = 3) uniform sampler2D Original;
    void main() {
        vec3 inverse = vec3(1.0) - texture(Original, vTexCoord).rgb;
        FragColor = vec4(mix(texture(Source, vTexCoord).rgb, inverse, params.AMOUNT), 1.0);
    }
    """

    private static let common = """
    layout(push_constant) uniform Push {
        vec4 SourceSize;
        vec4 OutputSize;
        uint FrameCount;
        float AMOUNT;
    } params;
    layout(std140, set = 0, binding = 0) uniform UBO {
        mat4 MVP;
    } global;
    """

    private static func stock(fragmentBody: String = "FragColor = texture(Source, vTexCoord);") -> String {
        """
        #version 450
        layout(std140, set = 0, binding = 0) uniform UBO {
            mat4 MVP;
            vec4 OutputSize;
        } global;
        #pragma stage vertex
        layout(location = 0) in vec4 Position;
        layout(location = 1) in vec2 TexCoord;
        layout(location = 0) out vec2 vTexCoord;
        void main() {
            gl_Position = global.MVP * Position;
            vTexCoord = TexCoord;
        }
        #pragma stage fragment
        layout(location = 0) in vec2 vTexCoord;
        layout(location = 0) out vec4 FragColor;
        layout(set = 0, binding = 2) uniform sampler2D Source;
        void main() {
            \(fragmentBody)
        }
        """
    }

    private static let preset = """
    # A two-pass test preset.
    shaders = 2

    shader0 = shaders/invert.slang
    filter_linear0 = false
    scale_type0 = source
    scale0 = 2.0
    wrap_mode0 = "clamp_to_edge"

    shader1 = "shaders/stock.slang"
    filter_linear1 = true
    float_framebuffer1 = false

    AMOUNT = 1.0
    """

    private func write(_ text: String, _ path: String) throws {
        let url = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func writeFixture(preset: String = SlangImportTests.preset, stock: String = SlangImportTests.stock()) throws -> URL {
        try write(Self.invert, "shaders/invert.slang")
        try write(Self.common, "include/common.inc")
        try write(stock, "shaders/stock.slang")
        try write(preset, "test.slangp")
        return directory.appendingPathComponent("test.slangp")
    }

    private func translate(_ presetURL: URL, device: MTLDevice? = nil) throws -> SlangFilter {
        let folder = presetURL.deletingLastPathComponent()
        return try SlangImporter.translate(preset: String(contentsOf: presetURL), name: "test",
                                           load: { try ImportedFilterStore.slangFile($0, folder: folder, companions: []) },
                                           device: device)
    }

    private func assertRefused(_ presetURL: URL, file: StaticString = #filePath, line: UInt = #line,
                               _ check: (SlangImportError) -> Bool) {
        XCTAssertThrowsError(try translate(presetURL), file: file, line: line) { error in
            guard let refusal = error as? SlangImportError else { return XCTFail("\(error)", file: file, line: line) }
            XCTAssertTrue(check(refusal), "\(refusal.localizedDescription)", file: file, line: line)
            XCTAssertFalse(refusal.localizedDescription.isEmpty, file: file, line: line)
        }
    }

    // MARK: - Parsing

    func testConfigReadsQuotesCommentsAndBareValues() throws {
        let config = try SlangImporter.parseConfig("""
        # comment
        shaders = 1
        shader0 = "a b/c.slang"
        scale0 = 2.0 # trailing
        // also a comment
        """)
        XCTAssertEqual(config["shaders"], "1")
        XCTAssertEqual(config["shader0"], "a b/c.slang")
        XCTAssertEqual(config["scale0"], "2.0")
        XCTAssertThrowsError(try SlangImporter.parseConfig("#reference \"other.slangp\""))
        XCTAssertThrowsError(try SlangImporter.parseConfig("no equals sign here"))
    }

    func testPathsResolveAgainstTheNamingFile() {
        XCTAssertEqual(SlangImporter.resolve("../include/common.inc", from: "shaders/invert.slang"), "include/common.inc")
        XCTAssertEqual(SlangImporter.resolve("./x.inc", from: "a/b/c.slang"), "a/b/x.inc")
        XCTAssertEqual(SlangImporter.resolve("../../up.inc", from: "a.slang"), "../../up.inc")
    }

    func testStagesSplitAndPragmasAreRead() throws {
        let stages = try SlangImporter.stages(of: Self.invert, path: "shaders/invert.slang", load: { path in
            XCTAssertEqual(path, "include/common.inc")
            return Self.common
        }, depth: 0)
        XCTAssertTrue(stages.vertex.hasPrefix("#version 450"))
        XCTAssertTrue(stages.vertex.contains("gl_Position") && !stages.vertex.contains("FragColor"))
        XCTAssertTrue(stages.fragment.contains("FragColor") && !stages.fragment.contains("gl_Position"))
        XCTAssertTrue(stages.fragment.contains("uniform Push"), "the include is pasted into both stages")
        XCTAssertFalse(stages.fragment.contains("#pragma"))
        XCTAssertEqual(stages.parameters, [SlangFilter.Parameter(name: "AMOUNT", title: "Invert amount", initial: 0.5,
                                                                 minimum: 0, maximum: 1, step: 0.25)])
    }

    // MARK: - Translation

    func testTwoPassPresetTranslatesWithItsSettings() throws {
        let filter = try translate(try writeFixture())
        XCTAssertEqual(filter.passes.count, 2)
        let first = filter.passes[0], last = filter.passes[1]
        XCTAssertEqual(Set(first.textures), ["Source", "Original"], "bound in the order SPIR-V lists them")
        XCTAssertEqual(first.push.members["AMOUNT"], 36)
        XCTAssertEqual(first.ubo.members["MVP"], 0)
        XCTAssertEqual(first.scaleX, SlangFilter.Scale(type: .source, value: 2))
        XCTAssertEqual(first.wrap, .clampToEdge)
        XCTAssertFalse(first.filterLinear)
        XCTAssertTrue(last.filterLinear)
        XCTAssertEqual(last.format, MetalRenderer.outputPixelFormat.rawValue, "the last pass draws to the screen")
        XCTAssertTrue(first.fragment.contains("fragment main0_out main0"), "SPIRV-Cross wrote MSL")
        XCTAssertEqual(filter.parameters.first?.initial, 1, "the preset's value replaces the shader's default")
    }

    func testTranslatedChainDrawsThroughTheRenderer() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let filter = try translate(try writeFixture(), device: device)
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        renderer.setSlang(try SlangChain(filter: filter, device: device))

        let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        sourceDescriptor.storageMode = .shared
        let source = try XCTUnwrap(device.makeTexture(descriptor: sourceDescriptor))
        let red = [UInt8](repeating: 0, count: 64).enumerated().map { $0.offset % 4 == 0 || $0.offset % 4 == 3 ? UInt8(255) : 0 }
        source.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: red, bytesPerRow: 16)
        renderer.setTexture(source)

        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 8, height: 8, mipmapped: false)
        targetDescriptor.usage = [.renderTarget, .shaderRead]
        targetDescriptor.storageMode = .shared
        let target = try XCTUnwrap(device.makeTexture(descriptor: targetDescriptor))
        func centre() -> [UInt8] {
            renderer.render(into: target)
            var pixel = [UInt8](repeating: 9, count: 4)
            target.getBytes(&pixel, bytesPerRow: 32, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
            return Array(pixel[0..<3]) // BGR.
        }
        XCTAssertEqual(centre(), [255, 255, 0], "AMOUNT 1 from the preset: red inverted to cyan")

        var values = ShaderParameterValues()
        values.slang = ["AMOUNT": 0]
        renderer.apply(values)
        XCTAssertEqual(centre(), [0, 0, 255], "AMOUNT 0 from the sliders: the frame unchanged")
    }

    func testTheSavedTranslationLoadsAgainAndCanBeDeleted() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let presetURL = try writeFixture()
        let store = ImportedFilterStore(directory: directory.appendingPathComponent("Filters"))
        let entry = try await store.addSlang(files: [presetURL], device: device)
        XCTAssertEqual(entry.id, "slang:test")
        XCTAssertTrue(ImportedFilter.isSlang(entry.id))
        XCTAssertFalse(ImportedFilter.isImported(entry.id), "not taken for a .metal filter")
        XCTAssertEqual(store.entries.map(\.id), ["slang:test"])
        XCTAssertEqual(store.slangFilter(for: entry.id)?.passes.count, 2)
        _ = try await store.slangChain(for: entry.id, device: device)
        store.delete(entry)
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testCompanionFilesAreFoundByName() async throws {
        // As from the Files picker: the preset's folder is not readable, only the chosen files are.
        let presetURL = try writeFixture()
        let elsewhere = directory.appendingPathComponent("picked", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        var picked: [URL] = []
        for path in ["test.slangp", "shaders/invert.slang", "shaders/stock.slang", "include/common.inc"] {
            let copy = elsewhere.appendingPathComponent((path as NSString).lastPathComponent)
            try FileManager.default.copyItem(at: directory.appendingPathComponent(path), to: copy)
            picked.append(copy)
        }
        try FileManager.default.removeItem(at: presetURL)
        let text = try String(contentsOf: picked[0])
        let filter = try SlangImporter.translate(preset: text, name: "picked", load: {
            try ImportedFilterStore.slangFile($0, folder: self.directory.appendingPathComponent("gone"), companions: picked)
        }, device: nil)
        XCTAssertEqual(filter.passes.count, 2)
    }

    // MARK: - Refusals

    func testLookupTexturesAreRefused() throws {
        let url = try writeFixture(preset: Self.preset + "\ntextures = \"LUT\"\nLUT = lut.png\n")
        assertRefused(url) { if case .unsupported(let what) = $0 { return what.contains("lookup textures") } else { return false } }
    }

    func testOtherPassesOutputsAreRefused() throws {
        let shader = Self.stock(fragmentBody: "FragColor = texture(Source, vTexCoord) + texture(PassOutput0, vTexCoord);")
            .replacingOccurrences(of: "uniform sampler2D Source;", with: "uniform sampler2D Source;\nlayout(set = 0, binding = 4) uniform sampler2D PassOutput0;")
        let url = try writeFixture(stock: shader)
        assertRefused(url) { if case .unsupported(let what) = $0 { return what.contains("PassOutput0") } else { return false } }
    }

    func testUnknownUniformsAreRefused() throws {
        let shader = Self.stock(fragmentBody: "FragColor = texture(Source, vTexCoord) * global.Mystery.x;")
            .replacingOccurrences(of: "vec4 OutputSize;", with: "vec4 OutputSize;\n    vec4 Mystery;")
        let url = try writeFixture(stock: shader)
        assertRefused(url) { if case .pass(1, let message) = $0 { return message.contains("Mystery") } else { return false } }
    }

    func testCompileErrorsNameThePass() throws {
        let url = try writeFixture(stock: Self.stock(fragmentBody: "FragColor = this is not glsl;"))
        assertRefused(url) { if case .pass(1, let message) = $0 { return message.contains("did not compile") } else { return false } }
    }

    func testAMissingShaderFileIsNamed() throws {
        let url = try writeFixture()
        try FileManager.default.removeItem(at: directory.appendingPathComponent("shaders/stock.slang"))
        assertRefused(url) { $0 == .missingFile("shaders/stock.slang") }
    }

    func testFeedbackAndTooManyPassesAreRefused() throws {
        assertRefused(try writeFixture(preset: Self.preset + "\nfeedback_pass = 0\n")) {
            if case .unsupported(let what) = $0 { return what.contains("feedback") } else { return false }
        }
        assertRefused(try writeFixture(preset: "shaders = 40\n")) {
            if case .unsupported(let what) = $0 { return what.contains("passes") } else { return false }
        }
    }
}
