import Foundation
import Metal

/// An imported RetroArch `.slangp` preset, already translated to MSL (docs/05 section 4.2). Translation runs
/// once, at import, through GagaSlang (glslang and SPIRV-Cross); this is what is kept, as JSON, and a later
/// launch only hands the MSL to Metal, like an imported `.metal` file.
struct SlangFilter: Codable, Equatable {
    struct Block: Codable, Equatable {
        var size: Int
        var members: [String: Int]
    }

    enum ScaleType: String, Codable { case source, viewport, absolute }

    struct Scale: Codable, Equatable {
        var type: ScaleType
        var value: Float
    }

    enum Wrap: String, Codable {
        case clampToBorder = "clamp_to_border", clampToEdge = "clamp_to_edge", repeating = "repeat"
        case mirroredRepeat = "mirrored_repeat"
    }

    struct Pass: Codable, Equatable {
        var vertex: String
        var fragment: String
        var ubo: Block
        var push: Block
        /// In binding order: texture and sampler i. Only `Source` and `Original` pass the import.
        var textures: [String]
        var filterLinear: Bool
        var wrap: Wrap
        /// Nil keeps the input's size, or the screen's for the last pass.
        var scaleX: Scale?
        var scaleY: Scale?
        /// An `MTLPixelFormat` raw value for the pass's output. The last pass draws to the screen.
        var format: UInt
        var frameCountMod: Int
    }

    struct Parameter: Codable, Equatable, Identifiable {
        var name: String
        var title: String
        var initial: Float
        var minimum: Float
        var maximum: Float
        var step: Float
        var id: String { name }
    }

    var name: String
    var passes: [Pass]
    var parameters: [Parameter]

    /// The values the renderer writes, by member name, besides parameters.
    static let semantics: Set<String> = ["MVP", "SourceSize", "OriginalSize", "OutputSize", "FinalViewportSize",
                                         "FrameCount", "FrameDirection"]
    static let textureNames = ["Source", "Original"]
}

enum SlangImportError: LocalizedError, Equatable {
    case notPreset
    case tooLarge(String)
    case notText(String)
    case malformed(String)
    case missingFile(String)
    case unsupported(String)
    case pass(Int, String)

    var errorDescription: String? {
        switch self {
        case .notPreset: return "Choose a .slangp preset, with its .slang files if they are not in the same folder."
        case .tooLarge(let file): return "\(file) is larger than \(SlangImporter.maxFileBytes / 1024) KB."
        case .notText(let file): return "\(file) is not UTF-8 text."
        case .malformed(let what): return "The preset could not be read: \(what)"
        case .missingFile(let path):
            return "The preset needs \(path), which could not be opened. Choose it together with the preset, or choose files from the preset's own folder."
        case .unsupported(let what): return "This preset uses \(what), which GagaEmu does not support yet."
        case .pass(let index, let message): return "Pass \(index):\n\n\(message)"
        }
    }
}

/// Reads a `.slangp` and its `.slang` files, and translates each pass. Blocks: call it off the main thread.
enum SlangImporter {
    static let maxFileBytes = 256 * 1024
    static let maxFiles = 64
    static let maxPasses = 16
    static let maxIncludeDepth = 8
    static let maxBlockBytes = 4096

    /// Reads a file the preset names, by a path relative to the file that names it.
    typealias Loader = (_ path: String) throws -> String

    /// `load` resolves a path relative to the preset's folder. Throws a reason for the player.
    static func translate(preset text: String, name: String, load: Loader, device: MTLDevice?) throws -> SlangFilter {
        let config = try parseConfig(text)
        guard let countText = config["shaders"], let count = Int(countText), count > 0 else {
            throw SlangImportError.malformed("it has no shaders = line.")
        }
        guard count <= maxPasses else { throw SlangImportError.unsupported("\(count) passes, over the \(maxPasses) allowed") }
        if let textures = config["textures"], !textures.trimmingCharacters(in: .whitespaces).isEmpty {
            throw SlangImportError.unsupported("lookup textures (textures = \(textures))")
        }
        if config.keys.contains(where: { $0.hasPrefix("feedback_pass") }) {
            throw SlangImportError.unsupported("pass feedback")
        }

        var parameters: [SlangFilter.Parameter] = []
        var passes: [SlangFilter.Pass] = []
        var filesRead = 0
        func counted(_ path: String) throws -> String {
            filesRead += 1
            guard filesRead <= maxFiles else { throw SlangImportError.unsupported("more than \(maxFiles) files") }
            return try load(path)
        }
        for index in 0..<count {
            guard let path = config["shader\(index)"] else { throw SlangImportError.malformed("shader\(index) is missing.") }
            let source = try stages(of: try counted(path), path: path, load: counted, depth: 0)
            for parameter in source.parameters where !parameters.contains(where: { $0.name == parameter.name }) {
                parameters.append(parameter)
            }
            passes.append(try translatePass(index: index, source: source, config: config, isLast: index == count - 1))
        }
        // The preset's own values replace the shaders' defaults.
        for index in parameters.indices {
            guard let text = config[parameters[index].name], let value = Float(text) else { continue }
            parameters[index].initial = min(max(value, parameters[index].minimum), parameters[index].maximum)
        }
        for (index, pass) in passes.enumerated() {
            let names = Set(pass.ubo.members.keys).union(pass.push.members.keys)
            if let unknown = names.subtracting(SlangFilter.semantics).first(where: { name in !parameters.contains { $0.name == name } }) {
                throw SlangImportError.pass(index, "It reads \(unknown), which is neither a #pragma parameter nor a value GagaEmu supplies (\(SlangFilter.semantics.sorted().joined(separator: ", "))).")
            }
        }
        let filter = SlangFilter(name: name, passes: passes, parameters: parameters)
        if let device { _ = try SlangChain(filter: filter, device: device) } // Proves Metal accepts every pass.
        return filter
    }

    // MARK: - Preset file

    /// RetroArch's config format: `key = value`, values optionally quoted, `#` comments.
    static func parseConfig(_ text: String) throws -> [String: String] {
        var values: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#reference") || line.hasPrefix("#include") {
                throw SlangImportError.unsupported("#reference presets")
            }
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("//") else { continue }
            guard let equals = line.firstIndex(of: "=") else { throw SlangImportError.malformed("\"\(line)\" is not key = value.") }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") {
                let body = value.dropFirst()
                value = String(body.prefix { $0 != "\"" })
            } else if let comment = value.firstIndex(of: "#") {
                value = value[..<comment].trimmingCharacters(in: .whitespaces)
            }
            guard !key.isEmpty else { throw SlangImportError.malformed("\"\(line)\" has no key.") }
            values[key] = value
        }
        return values
    }

    private static func bool(_ text: String?) -> Bool? {
        switch text?.lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: return nil
        }
    }

    private static func scale(_ config: [String: String], axis: String, index: Int) throws -> SlangFilter.Scale? {
        guard let typeText = config["scale_type_\(axis)\(index)"] ?? config["scale_type\(index)"] else { return nil }
        guard let type = SlangFilter.ScaleType(rawValue: typeText) else {
            throw SlangImportError.malformed("scale_type\(index) = \(typeText) is not source, viewport or absolute.")
        }
        let valueText = config["scale_\(axis)\(index)"] ?? config["scale\(index)"]
        let value = try valueText.map { text -> Float in
            guard let value = Float(text), value > 0 else { throw SlangImportError.malformed("scale\(index) = \(text) is not a positive number.") }
            return value
        } ?? 1
        return SlangFilter.Scale(type: type, value: value)
    }

    // MARK: - Shader file

    struct Stages: Equatable {
        var vertex: String
        var fragment: String
        var parameters: [SlangFilter.Parameter]
        var format: String?
    }

    /// Pastes includes in and splits at `#pragma stage`: lines before the first stage go to both.
    static func stages(of text: String, path: String, load: Loader, depth: Int) throws -> Stages {
        var shared: [String] = [], vertex: [String] = [], fragment: [String] = []
        var stage = 0 // 0 both, 1 vertex, 2 fragment
        var parameters: [SlangFilter.Parameter] = []
        var format: String?
        for line in try expand(text, path: path, load: load, depth: depth) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var kept = line
            if trimmed.hasPrefix("#pragma") {
                let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                switch words.count > 1 ? words[1] : "" {
                case "stage":
                    switch words.count > 2 ? words[2] : "" {
                    case "vertex": stage = 1
                    case "fragment": stage = 2
                    default: throw SlangImportError.unsupported("the shader stage in \"\(trimmed)\"")
                    }
                    kept = ""
                case "parameter":
                    parameters.append(try parameter(trimmed))
                    kept = ""
                case "format":
                    format = words.count > 2 ? words[2] : nil
                    kept = ""
                case "name":
                    kept = ""
                default:
                    break
                }
            }
            switch stage {
            case 1: vertex.append(kept)
            case 2: fragment.append(kept)
            default: shared.append(kept)
            }
        }
        guard !vertex.isEmpty, !fragment.isEmpty else {
            throw SlangImportError.malformed("\(path) needs both #pragma stage vertex and #pragma stage fragment.")
        }
        return Stages(vertex: (shared + vertex).joined(separator: "\n"), fragment: (shared + fragment).joined(separator: "\n"),
                      parameters: parameters, format: format)
    }

    private static func expand(_ text: String, path: String, load: Loader, depth: Int) throws -> [String] {
        var lines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#include") else {
                lines.append(line)
                continue
            }
            guard depth < maxIncludeDepth else { throw SlangImportError.unsupported("includes nested over \(maxIncludeDepth) deep") }
            let parts = trimmed.split(separator: "\"", omittingEmptySubsequences: false)
            guard parts.count >= 3, !parts[1].isEmpty else { throw SlangImportError.malformed("\"\(trimmed)\" in \(path)") }
            let included = resolve(String(parts[1]), from: path)
            lines += try expand(try load(included), path: included, load: load, depth: depth + 1)
        }
        return lines
    }

    /// `path` relative to the folder of `file`, both relative to the preset's folder, with `.` and `..` folded.
    static func resolve(_ path: String, from file: String) -> String {
        var parts = file.split(separator: "/").dropLast().map(String.init)
        for part in path.split(separator: "/").map(String.init) {
            switch part {
            case ".": continue
            case "..": if parts.isEmpty || parts.last == ".." { parts.append("..") } else { parts.removeLast() }
            default: parts.append(part)
            }
        }
        return parts.joined(separator: "/")
    }

    /// `#pragma parameter NAME "Title" initial minimum maximum [step]`.
    static func parameter(_ line: String) throws -> SlangFilter.Parameter {
        let quoted = line.split(separator: "\"", omittingEmptySubsequences: false)
        let head = quoted.first?.split(whereSeparator: \.isWhitespace).map(String.init) ?? []
        guard quoted.count >= 3, head.count == 3, head[1] == "parameter" else {
            throw SlangImportError.malformed("\"\(line)\" is not #pragma parameter NAME \"Title\" initial minimum maximum step.")
        }
        let numbers = quoted[2].split(whereSeparator: \.isWhitespace).compactMap { Float($0) }
        guard numbers.count >= 3, numbers[1] <= numbers[2] else {
            throw SlangImportError.malformed("\"\(line)\" needs initial, minimum and maximum values.")
        }
        return SlangFilter.Parameter(name: head[2], title: String(quoted[1]), initial: min(max(numbers[0], numbers[1]), numbers[2]),
                                     minimum: numbers[1], maximum: numbers[2], step: numbers.count > 3 ? numbers[3] : 0)
    }

    private static func pixelFormat(_ name: String?, float: Bool, srgb: Bool) throws -> MTLPixelFormat {
        if float { return .rgba16Float }
        if srgb { return .rgba8Unorm_srgb }
        switch name {
        case nil, "R8G8B8A8_UNORM", "B8G8R8A8_UNORM": return .bgra8Unorm
        case "R8G8B8A8_SRGB", "B8G8R8A8_SRGB": return .rgba8Unorm_srgb
        case "R16G16B16A16_SFLOAT": return .rgba16Float
        case "R32G32B32A32_SFLOAT": return .rgba32Float
        case "A2B10G10R10_UNORM_PACK32": return .rgb10a2Unorm
        case "R16G16B16A16_UNORM": return .rgba16Unorm
        default: throw SlangImportError.unsupported("the framebuffer format \(name ?? "")")
        }
    }

    // MARK: - Translation

    private struct Translated: Decodable {
        var vertex: String
        var fragment: String
        var ubo: SlangFilter.Block
        var push: SlangFilter.Block
        var textures: [String]
    }

    private static func translatePass(index: Int, source: Stages, config: [String: String], isLast: Bool) throws -> SlangFilter.Pass {
        var error = [CChar](repeating: 0, count: 4096)
        guard let json = gaga_slang_translate(source.vertex, source.fragment, &error, error.count) else {
            throw SlangImportError.pass(index, String(cString: error))
        }
        defer { gaga_slang_free(json) }
        let translated = try JSONDecoder().decode(Translated.self, from: Data(String(cString: json).utf8))
        if let other = translated.textures.first(where: { !SlangFilter.textureNames.contains($0) }) {
            throw SlangImportError.unsupported("the texture \(other) in pass \(index); only Source and Original are supplied")
        }
        guard translated.ubo.size <= maxBlockBytes, translated.push.size <= maxBlockBytes else {
            throw SlangImportError.pass(index, "Its uniforms are larger than \(maxBlockBytes) bytes.")
        }
        let wrapText = config["wrap_mode\(index)"] ?? "clamp_to_border"
        guard let wrap = SlangFilter.Wrap(rawValue: wrapText) else {
            throw SlangImportError.malformed("wrap_mode\(index) = \(wrapText) is not a wrap mode.")
        }
        let format = try pixelFormat(source.format, float: bool(config["float_framebuffer\(index)"]) ?? false,
                                     srgb: bool(config["srgb_framebuffer\(index)"]) ?? false)
        return SlangFilter.Pass(vertex: translated.vertex, fragment: translated.fragment, ubo: translated.ubo, push: translated.push,
                                textures: translated.textures, filterLinear: bool(config["filter_linear\(index)"]) ?? false,
                                wrap: wrap, scaleX: try scale(config, axis: "x", index: index), scaleY: try scale(config, axis: "y", index: index),
                                format: isLast ? MetalRenderer.outputPixelFormat.rawValue : format.rawValue,
                                frameCountMod: Int(config["frame_count_mod\(index)"] ?? "") ?? 0)
    }
}

/// A `SlangFilter` made ready for the GPU: one pipeline and sampler per pass.
final class SlangChain {
    struct Pass {
        let spec: SlangFilter.Pass
        let pipeline: MTLRenderPipelineState
        let sampler: MTLSamplerState
        var format: MTLPixelFormat { MTLPixelFormat(rawValue: spec.format) ?? .bgra8Unorm }
    }

    /// Where the quad's corners go: attribute 0 position, attribute 1 texture coordinate, as RetroArch feeds them.
    static let vertexBufferIndex = 30

    let filter: SlangFilter
    let passes: [Pass]

    /// Compiles MSL only, which is what Metal does for any imported shader. Blocks while it compiles.
    init(filter: SlangFilter, device: MTLDevice) throws {
        self.filter = filter
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = Self.vertexBufferIndex
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = Self.vertexBufferIndex
        vertexDescriptor.layouts[Self.vertexBufferIndex].stride = 24
        passes = try filter.passes.enumerated().map { index, spec in
            func function(_ source: String, _ stage: String) throws -> MTLFunction {
                do {
                    guard let function = try device.makeLibrary(source: source, options: nil).makeFunction(name: "main0") else {
                        throw SlangImportError.pass(index, "The \(stage) stage has no main0.")
                    }
                    return function
                } catch let error as SlangImportError {
                    throw error
                } catch {
                    throw SlangImportError.pass(index, "Metal did not compile the \(stage) stage.\n\n\(error.localizedDescription)")
                }
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = try function(spec.vertex, "vertex")
            descriptor.fragmentFunction = try function(spec.fragment, "fragment")
            descriptor.vertexDescriptor = vertexDescriptor
            descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat(rawValue: spec.format) ?? .bgra8Unorm
            let pipeline: MTLRenderPipelineState
            do {
                pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                throw SlangImportError.pass(index, "The pass could not be set up.\n\n\(error.localizedDescription)")
            }
            let sampler = MTLSamplerDescriptor()
            sampler.minFilter = spec.filterLinear ? .linear : .nearest
            sampler.magFilter = sampler.minFilter
            let mode: MTLSamplerAddressMode = switch spec.wrap {
            case .clampToBorder: .clampToZero
            case .clampToEdge: .clampToEdge
            case .repeating: .repeat
            case .mirroredRepeat: .mirrorRepeat
            }
            sampler.sAddressMode = mode
            sampler.tAddressMode = mode
            guard let state = device.makeSamplerState(descriptor: sampler) else {
                throw SlangImportError.pass(index, "Its sampler could not be made.")
            }
            return Pass(spec: spec, pipeline: pipeline, sampler: state)
        }
    }

    /// The pass's output size in pixels from its input's and the picture's.
    static func outputSize(_ spec: SlangFilter.Pass, input: (width: Int, height: Int), viewport: (width: Int, height: Int)) -> (width: Int, height: Int) {
        func axis(_ scale: SlangFilter.Scale?, _ input: Int, _ viewport: Int) -> Int {
            let pixels: Float = switch scale?.type {
            case nil: Float(input)
            case .source: Float(input) * scale!.value
            case .viewport: Float(viewport) * scale!.value
            case .absolute: scale!.value
            }
            return min(max(Int(pixels.rounded()), 1), 8192)
        }
        return (axis(spec.scaleX, input.width, viewport.width), axis(spec.scaleY, input.height, viewport.height))
    }

    /// Values a pass reads, written at the offsets the translator reported.
    struct Frame {
        var source: (width: Int, height: Int)
        var original: (width: Int, height: Int)
        var output: (width: Int, height: Int)
        var viewport: (width: Int, height: Int)
        var frameCount: UInt32
        var parameters: [String: Float]
    }

    static func blockBytes(_ block: SlangFilter.Block, frame: Frame) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: block.size)
        func put<T>(_ name: String, _ value: T) {
            guard let offset = block.members[name], offset >= 0, offset + MemoryLayout<T>.size <= bytes.count else { return }
            withUnsafeBytes(of: value) { bytes.replaceSubrange(offset..<offset + $0.count, with: $0) }
        }
        func size(_ size: (width: Int, height: Int)) -> SIMD4<Float> {
            let width = Float(size.width), height = Float(size.height)
            return SIMD4(width, height, 1 / width, 1 / height)
        }
        // RetroArch's ortho(0, 1, 0, 1, -1, 1), column major: the quad's 0 to 1 corners to clip space.
        let mvp: [Float] = [2, 0, 0, 0, 0, 2, 0, 0, 0, 0, -1, 0, -1, -1, 0, 1]
        if let offset = block.members["MVP"], offset + 64 <= bytes.count {
            mvp.withUnsafeBytes { bytes.replaceSubrange(offset..<offset + 64, with: $0) }
        }
        put("SourceSize", size(frame.source))
        put("OriginalSize", size(frame.original))
        put("OutputSize", size(frame.output))
        put("FinalViewportSize", size(frame.viewport))
        put("FrameCount", frame.frameCount)
        put("FrameDirection", Int32(1))
        for (name, value) in frame.parameters { put(name, value) }
        return bytes
    }

    static let quad: [Float] = [0, 0, 0, 1, 0, 0,
                                1, 0, 0, 1, 1, 0,
                                0, 1, 0, 1, 0, 1,
                                1, 1, 0, 1, 1, 1]
}
