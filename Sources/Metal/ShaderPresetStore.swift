import Foundation

/// A filter with its slider values and upscaler, saved under the player's own name. Applying one selects
/// `shaderID` (a `ShaderPreset`, an imported `.metal` or an imported `.slangp`) and gives it `values`.
struct SavedFilterPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var shaderID: String
    var values: ShaderParameterValues
}

enum SavedPresetError: LocalizedError, Equatable {
    case emptyName
    case nameTooLong
    case duplicateName(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Give the preset a name."
        case .nameTooLong: return "Use a name of \(ShaderPresetStore.maxNameLength) characters or fewer."
        case .duplicateName(let name): return "A preset named \(name) already exists."
        case .notFound: return "That preset is gone."
        }
    }
}

/// The saved presets, as one JSON file in the app's Documents, so the player can see and back it up.
/// A file that does not decode is moved aside, not overwritten, so nothing the player made is lost.
final class ShaderPresetStore {
    static let maxNameLength = 40
    static let fileName = "Filter Presets.json"

    let url: URL
    private(set) var presets: [SavedFilterPreset] = []

    init(directory: URL) {
        url = directory.appendingPathComponent(Self.fileName)
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([SavedFilterPreset].self, from: data) {
            presets = decoded
        } else {
            let aside = directory.appendingPathComponent("Filter Presets (unreadable \(Int(Date().timeIntervalSince1970))).json")
            try? FileManager.default.moveItem(at: url, to: aside)
        }
    }

    @discardableResult
    func save(name: String, shaderID: String, values: ShaderParameterValues) throws -> SavedFilterPreset {
        let preset = SavedFilterPreset(id: UUID(), name: try checked(name, except: nil), shaderID: shaderID, values: values)
        try write(presets + [preset])
        return preset
    }

    func rename(_ id: UUID, to name: String) throws {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { throw SavedPresetError.notFound }
        var updated = presets
        updated[index].name = try checked(name, except: id)
        try write(updated)
    }

    func delete(_ id: UUID) throws {
        guard presets.contains(where: { $0.id == id }) else { throw SavedPresetError.notFound }
        try write(presets.filter { $0.id != id })
    }

    private func checked(_ name: String, except id: UUID?) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SavedPresetError.emptyName }
        guard trimmed.count <= Self.maxNameLength else { throw SavedPresetError.nameTooLong }
        if presets.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw SavedPresetError.duplicateName(trimmed)
        }
        return trimmed
    }

    /// The list on disk changes first, so a failed write leaves both as they were.
    private func write(_ updated: [SavedFilterPreset]) throws {
        let sorted = updated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(sorted).write(to: url, options: .atomic)
        presets = sorted
    }
}
