import Foundation

/// Groups multi-disc dumps and writes one `.m3u` per game so disc swaps keep the same save.
public struct MultiDiscHelper: Sendable {

    public struct Group: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let platform: Platform
        public let discs: [URL]
        public var playlistName: String { "\(title).m3u" }
    }

    public enum Platform: String, CaseIterable, Sendable {
        case ps1 = "PlayStation"
        case megaCD = "Mega-CD"
        case saturn = "Sega Saturn"
        case dreamcast = "Dreamcast"

        /// The `CoreCatalog` platform a playlist of these discs plays on. An `.m3u` alone does not say.
        public var platformID: String {
            switch self {
            case .ps1: return "ps1"
            case .megaCD: return "megacd"
            case .saturn: return "saturn"
            case .dreamcast: return "dreamcast"
            }
        }

        var extensions: Set<String> {
            switch self {
            case .ps1: return ["bin", "cue", "chd", "pbp", "iso", "img"]
            case .megaCD: return ["bin", "cue", "chd", "iso"]
            case .saturn: return ["bin", "cue", "chd", "iso", "ccd", "toc"]
            case .dreamcast: return ["gdi", "cdi", "chd", "cue"]
            }
        }
    }

    public static let discExtensions: Set<String> = Set(Platform.allCases.flatMap(\.extensions))

    /// `Final Fantasy VII (Disc 2).chd` -> (`Final Fantasy VII`, 2, platform)
    public static func parse(_ url: URL) -> (title: String, disc: Int, platform: Platform?)? {
        let ext = url.pathExtension.lowercased()
        let platform = Platform.allCases.first { $0.extensions.contains(ext) }
        guard platform != nil || discExtensions.contains(ext) else { return nil }
        let stem = url.deletingPathExtension().lastPathComponent
        guard let match = discPattern.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)),
              let titleRange = Range(match.range(at: 1), in: stem),
              let discRange = Range(match.range(at: 2), in: stem),
              let disc = Int(stem[discRange]) else { return nil }
        let title = stem[titleRange]
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard !title.isEmpty else { return nil }
        return (title, disc, platform)
    }

    private static func candidates(in directory: URL) -> [URL] {
        // A disc set in its own folder counts by its descriptor.
        let urls = ((try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
            + DiscSet.folders(in: directory).compactMap(DiscSet.primary(in:))
        // A cue sheet is the disc. Its track file beside it, under the same name, is not a disc of its own.
        let sheets = Set(urls.filter { ["cue", "ccd", "toc"].contains($0.pathExtension.lowercased()) }.map { $0.deletingPathExtension().lastPathComponent })
        return urls.filter { !["bin", "img"].contains($0.pathExtension.lowercased()) || !sheets.contains($0.deletingPathExtension().lastPathComponent) }
    }

    /// Every disc file a playlist could list, for picking by hand.
    static func discFiles(in directory: URL) -> [URL] {
        candidates(in: directory)
            .filter { discExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Scans a directory (non-recursive) and returns groups of two or more discs.
    public static func scan(_ directory: URL) -> [Group] {
        var buckets: [String: [(disc: Int, url: URL, platform: Platform?)]] = [:]
        for url in candidates(in: directory) {
            guard let parsed = parse(url) else { continue }
            let key = parsed.platform.map { "\($0.rawValue)|\(parsed.title.lowercased())" } ?? parsed.title.lowercased()
            buckets[key, default: []].append((parsed.disc, url, parsed.platform))
        }
        return buckets.compactMap { key, entries -> Group? in
            guard entries.count >= 2 else { return nil }
            let ordered = entries.sorted { $0.disc < $1.disc }.map(\.url)
            let platform = entries.compactMap(\.platform).first ?? .ps1
            let title = parse(ordered[0])?.title ?? key
            return Group(id: key, title: title, platform: platform, discs: ordered)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Writes `Title.m3u` beside the discs. Paths are relative ("Disc.cue", or "Disc/Disc.cue" for a set folder)
    /// so the playlist stays portable.
    @discardableResult
    public static func writePlaylist(for group: Group, into directory: URL) throws -> URL {
        let lines = group.discs.map { ClipboardImporter.relativePath($0, in: directory) }
        let text = lines.joined(separator: "\n") + "\n"
        let name = WiFiTransferServer.sanitize(group.playlistName)
        guard name.hasSuffix(".m3u") else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dest = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: dest, options: .atomic)
        return dest
    }

    /// Writes a playlist for every detected group. Returns the files created.
    public static func generateAll(in directory: URL) throws -> [URL] {
        try scan(directory).map { try writePlaylist(for: $0, into: directory) }
    }

    // "Game (Disc 1)", "Game - Disc 2", "Game CD3", "Game Disk 4", "Game (Disc 1 of 3)"
    private static let discPattern: NSRegularExpression = {
        let pattern = #"^(.*?)[\s\-_\(\[]*(?:disc|disk|cd)\s*0*(\d+)(?:\s*of\s*\d+)?[\)\]]*$"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
}

#if DEBUG
enum MultiDiscHelperChecks {
    static func run() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gaga-m3u-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["Final Fantasy VII (Disc 1).chd", "Final Fantasy VII (Disc 2).chd", "Final Fantasy VII (Disc 3).chd", "solo.gba"] {
            FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data())
        }
        let groups = MultiDiscHelper.scan(dir)
        assert(groups.count == 1)
        assert(groups[0].discs.count == 3)
        assert(groups[0].platform == .ps1)
        let playlist = try? MultiDiscHelper.writePlaylist(for: groups[0], into: dir)
        let text = playlist.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        assert(text == "Final Fantasy VII (Disc 1).chd\nFinal Fantasy VII (Disc 2).chd\nFinal Fantasy VII (Disc 3).chd\n")
        let dc = URL(fileURLWithPath: "/roms/Skies of Arcadia (Disc 2).gdi")
        assert(MultiDiscHelper.parse(dc)?.platform == .dreamcast)
        assert(MultiDiscHelper.parse(URL(fileURLWithPath: "/roms/solo.gba")) == nil)

        let sheets = dir.appendingPathComponent("sheets")
        try? FileManager.default.createDirectory(at: sheets, withIntermediateDirectories: true)
        for name in ["Gaga (Disc 1).cue", "Gaga (Disc 1).bin", "Gaga (Disc 2).cue", "Gaga (Disc 2).bin"] {
            FileManager.default.createFile(atPath: sheets.appendingPathComponent(name).path, contents: Data())
        }
        assert(MultiDiscHelper.scan(sheets).first?.discs.map(\.lastPathComponent) == ["Gaga (Disc 1).cue", "Gaga (Disc 2).cue"])
    }
}
#endif
