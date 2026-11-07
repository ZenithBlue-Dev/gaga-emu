import Foundation
import Metal

/// A `.metal` file the player imported. Its source is untrusted input: `ImportedFilter.pipeline` checks
/// the file, compiles it at runtime and checks what compiled (docs/05 section 4).
enum FilterImportError: LocalizedError, Equatable {
    case notMetalFile
    case empty
    case tooLarge(bytes: Int)
    case notText
    case forbiddenInclude(String)
    case compile(String)
    case missingEntryPoint
    case link(String)
    case unsupportedBinding(String)

    var errorDescription: String? {
        switch self {
        case .notMetalFile: return "This is not a .metal file."
        case .empty: return "The file is empty."
        case .tooLarge(let bytes):
            return "The file is \(bytes.formatted(.byteCount(style: .file))). The limit is \(ImportedFilter.maxBytes.formatted(.byteCount(style: .file)))."
        case .notText: return "The file is not UTF-8 text."
        case .forbiddenInclude(let line): return "Only Metal's own headers may be included. This line is not allowed:\n\(line)"
        case .compile(let log): return "The file did not compile.\n\n\(log)"
        case .missingEntryPoint: return "The file needs a fragment function named \(ImportedFilter.entryPoint)."
        case .link(let log): return "The filter could not be set up.\n\n\(log)"
        case .unsupportedBinding(let what): return "\(ImportedFilter.entryPoint) uses \(what). A filter may use buffer(0), texture(0), texture(1) and sampler(0)."
        }
    }
}

enum ImportedFilter {
    static let entryPoint = "gaga_fragment"
    static let maxBytes = 256 * 1024
    /// Everything before the name is how a saved filter ID differs from a preset ID.
    static let idPrefix = "import:"

    static func isImported(_ shaderID: String) -> Bool { shaderID.hasPrefix(idPrefix) }

    /// The checks that need no GPU. Returns the source to compile.
    static func validate(_ data: Data) throws -> String {
        guard !data.isEmpty else { throw FilterImportError.empty }
        guard data.count <= maxBytes else { throw FilterImportError.tooLarge(bytes: data.count) }
        guard !data.contains(0), let source = String(data: data, encoding: .utf8) else { throw FilterImportError.notText }
        // An include could pull any readable file into the compiler and its error text. "%:" is C's digraph for "#".
        for line in source.split(whereSeparator: \.isNewline) {
            let text = line.drop { $0 == " " || $0 == "\t" }
            guard text.hasPrefix("#") || text.hasPrefix("%:") else { continue }
            let directive = text.drop { "#%: \t".contains($0) }
            guard directive.hasPrefix("include") || directive.hasPrefix("import") else { continue }
            let allowed = directive.contains("<metal_") || directive.contains("<simd/")
            if !allowed { throw FilterImportError.forbiddenInclude(String(text)) }
        }
        return source
    }

    /// Compiles and links. Blocks while the compiler runs, so call it off the main thread.
    static func pipeline(source: String, device: MTLDevice) throws -> MTLRenderPipelineState {
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: nil)
        } catch {
            throw FilterImportError.compile(error.localizedDescription)
        }
        guard let fragment = library.makeFunction(name: entryPoint), fragment.functionType == .fragment else {
            throw FilterImportError.missingEntryPoint
        }
        guard let vertex = device.makeDefaultLibrary()?.makeFunction(name: "vertex_main") else {
            throw FilterImportError.link("The app's own shaders are missing.")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            var reflection: MTLRenderPipelineReflection?
            let state = try device.makeRenderPipelineState(descriptor: descriptor, options: [.bindingInfo, .bufferTypeInfo],
                                                           reflection: &reflection)
            try checkBindings(reflection?.fragmentBindings ?? [])
            return state
        } catch let error as FilterImportError {
            throw error
        } catch {
            throw FilterImportError.link(error.localizedDescription)
        }
    }

    /// The renderer binds only these, and an unbound resource is a GPU fault waiting to happen.
    private static func checkBindings(_ bindings: [MTLBinding]) throws {
        for binding in bindings {
            switch binding.type {
            case .buffer:
                guard binding.index == 0 else { throw FilterImportError.unsupportedBinding("buffer(\(binding.index))") }
                if let buffer = binding as? MTLBufferBinding, buffer.bufferDataSize > MemoryLayout<ShaderUniforms>.size {
                    throw FilterImportError.unsupportedBinding("a buffer larger than ShaderParameters")
                }
            case .texture:
                guard binding.index <= 1 else { throw FilterImportError.unsupportedBinding("texture(\(binding.index))") }
                if let texture = binding as? MTLTextureBinding, texture.textureType != .type2D || texture.textureDataType != .float {
                    throw FilterImportError.unsupportedBinding("a texture that is not texture2d<float>")
                }
            case .sampler:
                guard binding.index == 0 else { throw FilterImportError.unsupportedBinding("sampler(\(binding.index))") }
            default:
                throw FilterImportError.unsupportedBinding("\(binding.name)")
            }
        }
    }
}

/// Imported files, kept as copies in Application Support, so they survive the original moving.
final class ImportedFilterStore {
    struct Entry: Identifiable, Equatable {
        let id: String
        let name: String
        let url: URL
    }

    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    var entries: [Entry] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "metal" }
            .map { url in
                let name = url.deletingPathExtension().lastPathComponent
                return Entry(id: ImportedFilter.idPrefix + name, name: name, url: url)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func name(of shaderID: String) -> String? { entries.first { $0.id == shaderID }?.name }

    /// Reads `file`, proves it builds, and only then keeps a copy. Same name replaces.
    func add(file: URL, device: MTLDevice) async throws -> Entry {
        guard file.pathExtension.lowercased() == "metal" else { throw FilterImportError.notMetalFile }
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        // Checks the size first, so a huge file is refused without being read in.
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= ImportedFilter.maxBytes else { throw FilterImportError.tooLarge(bytes: size) }
        let data = try Data(contentsOf: file)
        let source = try ImportedFilter.validate(data)
        _ = try await Task.detached(priority: .userInitiated) { try ImportedFilter.pipeline(source: source, device: device) }.value
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = file.deletingPathExtension().lastPathComponent
        let destination = directory.appendingPathComponent(name).appendingPathExtension("metal")
        try data.write(to: destination, options: .atomic)
        return Entry(id: ImportedFilter.idPrefix + name, name: name, url: destination)
    }

    func delete(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.url)
    }

    /// The pipeline for a saved selection. Throws if the file went missing or no longer builds.
    func pipeline(for shaderID: String, device: MTLDevice) async throws -> MTLRenderPipelineState {
        guard let entry = entries.first(where: { $0.id == shaderID }) else { throw FilterImportError.empty }
        let source = try ImportedFilter.validate(try Data(contentsOf: entry.url))
        return try await Task.detached(priority: .userInitiated) { try ImportedFilter.pipeline(source: source, device: device) }.value
    }
}
