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

    /// Upright choices are kept apart, under the same key with this suffix, so each orientation has its own.
    private static func key(_ id: String, _ portrait: Bool) -> String { portrait ? id + "@portrait" : id }

    /// Upright, the picture starts above the controls; a two-screen system keeps Stacked, its default.
    static func defaults(portrait: Bool) -> ScreenSettings {
        var settings = ScreenSettings()
        if portrait { settings.area = .betweenControls }
        return settings
    }

    /// The game's own choice, then its system's, then the defaults, for one orientation.
    func settings(platformID: String, gameID: UUID?, portrait: Bool = false) -> ScreenSettings {
        (gameID.flatMap { file.games[Self.key($0.uuidString, portrait)] } ?? file.systems[Self.key(platformID, portrait)]
            ?? Self.defaults(portrait: portrait)).normalized()
    }

    func hasOverride(_ gameID: UUID, portrait: Bool = false) -> Bool { file.games[Self.key(gameID.uuidString, portrait)] != nil }

    /// A nil `gameID` saves the system's choice.
    func save(_ settings: ScreenSettings, platformID: String, gameID: UUID?, portrait: Bool = false) {
        let value = settings.normalized()
        if let gameID { file.games[Self.key(gameID.uuidString, portrait)] = value } else { file.systems[Self.key(platformID, portrait)] = value }
        write()
    }

    func removeOverride(_ gameID: UUID, portrait: Bool = false) {
        guard file.games.removeValue(forKey: Self.key(gameID.uuidString, portrait)) != nil else { return }
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
