import Foundation

/// Screen choices per system, with a per-game override, in ScreenLayouts.json beside the Skins folder. A missing,
/// damaged or later-version file reads as the defaults; it is replaced on the next change.
@MainActor
final class ScreenLayoutStore: ObservableObject {
    struct File: Codable, Equatable {
        static let currentVersion = 1
        var version = currentVersion
        /// By platform ID.
        var systems: [String: ScreenSettings] = [:]
        /// By game ID.
        var games: [String: ScreenSettings] = [:]
    }

    @Published private(set) var file: File
    let url: URL

    init(url: URL) {
        self.url = url
        let decoded = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(File.self, from: $0) }
        file = decoded.flatMap { $0.version <= File.currentVersion ? $0 : nil } ?? File()
    }

    /// The game's own choice, then its system's, then the defaults.
    func settings(platformID: String, gameID: UUID?) -> ScreenSettings {
        (gameID.flatMap { file.games[$0.uuidString] } ?? file.systems[platformID] ?? ScreenSettings()).normalized()
    }

    func hasOverride(_ gameID: UUID) -> Bool { file.games[gameID.uuidString] != nil }

    /// A nil `gameID` saves the system's choice.
    func save(_ settings: ScreenSettings, platformID: String, gameID: UUID?) {
        let value = settings.normalized()
        if let gameID { file.games[gameID.uuidString] = value } else { file.systems[platformID] = value }
        write()
    }

    func removeOverride(_ gameID: UUID) {
        guard file.games.removeValue(forKey: gameID.uuidString) != nil else { return }
        write()
    }

    /// Losing a layout is not worth stopping play for, so a failed write keeps the choice for this launch only.
    private func write() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(file) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
