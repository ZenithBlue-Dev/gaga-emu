import Foundation

/// How the Library draws its shelves. Saved in state.json: raw values are stable keys, not labels, because a value
/// that no longer decodes would fail the whole file.
struct LibraryDisplay: Codable, Equatable {
    enum Sort: String, Codable, CaseIterable, Identifiable {
        case added, title, played, time
        var id: String { rawValue }
        var label: String {
            switch self {
            case .added: return "Date Added"
            case .title: return "Title"
            case .played: return "Last Played"
            case .time: return "Play Time"
            }
        }
    }

    enum CoverStyle: String, Codable, CaseIterable, Identifiable {
        case spine, plain, framed
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    enum GroupStyle: String, Codable, CaseIterable, Identifiable {
        case full, code, maker
        var id: String { rawValue }
        var label: String {
            switch self {
            case .full: return "Full Name"
            case .code: return "Short Code"
            case .maker: return "Maker"
            }
        }
    }

    /// Games across a shelf: 2 to 5 wraps into rows, 0 keeps the single sideways-scrolling row.
    var perRow = 0
    var sort = Sort.added
    var descending = false
    var coverStyle = CoverStyle.spine
    var corner = 6.0
    var square = false
    var hideTitle = false
    var hideDetails = false
    var hideIndicators = false
    var groupStyle = GroupStyle.full
    var hideGroup = false

    func sorted(_ games: [GameItem]) -> [GameItem] {
        let ascending: [GameItem]
        switch sort {
        case .added: ascending = games
        case .title: ascending = games.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .played: ascending = games.sorted { ($0.lastPlayed ?? .distantPast) < ($1.lastPlayed ?? .distantPast) }
        case .time: ascending = games.sorted { $0.playTime < $1.playTime }
        }
        return descending ? ascending.reversed() : ascending
    }

    func heading(_ platformID: String) -> String {
        switch groupStyle {
        case .full: return CoreCatalog.platformName(platformID)
        case .code: return CoreCatalog.platformCode(platformID)
        case .maker:
            let maker = CoreCatalog.platforms.first { $0.id == platformID }?.manufacturer
            return maker.map { "\($0) \(CoreCatalog.platformCode(platformID))" } ?? CoreCatalog.platformName(platformID)
        }
    }
}
