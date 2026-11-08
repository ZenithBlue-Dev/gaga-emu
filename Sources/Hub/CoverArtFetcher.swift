import CryptoKit
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Libretro's public boxart server (docs/06 section 5). Its file names are No-Intro and Redump names, so a
/// player's own file name is matched against the folder's listing by a cleaned key, not sent as it is.
enum LibretroThumbnails {
    static let host = "thumbnails.libretro.com"

    /// Folder names on the server. A platform not listed never makes a request.
    static let systems: [String: String] = [
        "gba": "Nintendo - Game Boy Advance",
        "gbc": "Nintendo - Game Boy Color",
        "gb": "Nintendo - Game Boy",
        "nes": "Nintendo - Nintendo Entertainment System",
        "snes": "Nintendo - Super Nintendo Entertainment System",
        "n64": "Nintendo - Nintendo 64",
        "nds": "Nintendo - Nintendo DS",
        "n3ds": "Nintendo - Nintendo 3DS",
        "ps1": "Sony - PlayStation",
        "psp": "Sony - PlayStation Portable",
        "saturn": "Sega - Saturn",
        "megacd": "Sega - Mega-CD - Sega CD",
        "megadrive": "Sega - Mega Drive - Genesis",
        "sega32x": "Sega - 32X",
        "dreamcast": "Sega - Dreamcast",
        "dos": "DOS",
        "pce": "NEC - PC Engine - TurboGrafx 16",
        "sgx": "NEC - PC Engine SuperGrafx",
        "vb": "Nintendo - Virtual Boy",
        "ngp": "SNK - Neo Geo Pocket Color",
        "ws": "Bandai - WonderSwan Color",
        "pokemini": "Nintendo - Pokemon Mini",
        "mastersystem": "Sega - Master System - Mark III",
        "gamegear": "Sega - Game Gear",
        "sg1000": "Sega - SG-1000",
        "atari2600": "Atari - 2600",
        "atari7800": "Atari - 7800",
        "lynx": "Atari - Lynx",
        "atari5200": "Atari - 5200",
        "atari8bit": "Atari - 8-bit",
        "jaguar": "Atari - Jaguar",
        "c64": "Commodore - 64",
        "amiga": "Commodore - Amiga",
        "doom": "DOOM"
        // Arcade is left out: a MAME set is named like "sf2", and the server's MAME art is named by full title.
    ]

    /// Libretro's own rule: these characters become an underscore in a thumbnail's file name.
    static func fileName(title: String) -> String {
        String(title.map { "&*/:`<>?\\|\"".contains($0) ? "_" : $0 }) + ".png"
    }

    static func url(platformID: String, title: String) -> URL? {
        guard let system = systems[platformID], !title.isEmpty else { return nil }
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = host
        // URLComponents percent-encodes each part of the path, so a title cannot change the host or folder.
        parts.path = "/\(system)/Named_Boxarts/\(fileName(title: title))"
        return parts.url
    }

    /// The folder's directory listing. It names the platform only, never a game.
    static func listingURL(platformID: String) -> URL? {
        guard let system = systems[platformID] else { return nil }
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = host
        parts.path = "/\(system)/Named_Boxarts/"
        return parts.url
    }

    /// Box art names (without .png) from the server's Apache index page.
    static func names(fromListing html: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"<a href="([^"?/][^"]*)\.png">"#)
        return pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap {
            Range($0.range(at: 1), in: html).flatMap { html[$0].removingPercentEncoding }
        }
    }

    /// Bracketed tags, a leading four-digit scene number, case, accents and punctuation all dropped, so
    /// "0042 - Zorbo Quest (U) [!]", "Zorbo_Quest" and "Zorbo Quest (USA, Europe)" share one key.
    static func key(_ name: String) -> String {
        var text = name.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"^\s*\d{4} - "#, with: "", options: .regularExpression)
        text = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return String(String.UnicodeScalarView(text.unicodeScalars.filter(CharacterSet.alphanumerics.contains)))
    }

    /// Regions a GoodTools or No-Intro tag asks for, in order, such as (U), (UE), (Europe) or [J].
    static func regions(in name: String) -> [String] {
        let codes: [String: [String]] = [
            "u": ["USA"], "us": ["USA"], "usa": ["USA"], "ue": ["USA", "Europe"], "ju": ["USA", "Japan"],
            "jue": ["World", "USA", "Europe", "Japan"], "e": ["Europe"], "eu": ["Europe"], "europe": ["Europe"],
            "j": ["Japan"], "jp": ["Japan"], "japan": ["Japan"], "w": ["World"], "world": ["World"]
        ]
        let pattern = try! NSRegularExpression(pattern: #"[(\[]([^)\]]*)[)\]]"#)
        let tags = pattern.matches(in: name, range: NSRange(name.startIndex..., in: name))
            .compactMap { Range($0.range(at: 1), in: name).map { name[$0] } }.joined(separator: ",")
        return tags.split(whereSeparator: { $0 == "," || $0 == " " }).flatMap { codes[$0.lowercased()] ?? [] }
    }

    /// Server names grouped by `key`.
    typealias Index = [String: [String]]

    static func index(_ names: [String]) -> Index {
        Dictionary(grouping: names, by: key)
    }

    /// The first query with an equal key wins; failing that, the shortest key that starts with it, such as
    /// "Zorbo Red" for "Zorbo - Red Version". Among equals: no demo or prototype, the asked region, then USA.
    static func bestMatch(for queries: [String], in index: Index) -> String? {
        for query in queries {
            let wanted = key(query)
            guard !wanted.isEmpty else { continue }
            var found = index[wanted] ?? []
            if found.isEmpty, wanted.count >= 6 {
                let longer = index.keys.filter { $0.hasPrefix(wanted) }
                if let shortest = longer.map(\.count).min() {
                    found = longer.filter { $0.count == shortest }.flatMap { index[$0] ?? [] }
                }
            }
            let order = regions(in: query) + ["USA", "World", "Europe", "Japan"]
            func rank(_ name: String) -> (Int, Int, Int) {
                let odd = ["(Demo", "(Kiosk", "(Beta", "(Proto", "(Sample", "e-Reader", "(Pirate"].contains { name.contains($0) }
                return (odd ? 1 : 0, order.firstIndex { name.contains($0) } ?? order.count, name.count)
            }
            if let best = found.min(by: { rank($0) < rank($1) }) { return best }
        }
        return nil
    }
}

/// Downloads into Caches and writes only what it could decode. Every failure leaves the placeholder.
final class CoverArtFetcher {
    static let maxBytes = 5 * 1024 * 1024
    /// The largest folder listing (PlayStation) is about 2.5 MB.
    static let maxListingBytes = 12 * 1024 * 1024
    static let maxPixels = 4096
    /// Plenty for the largest shelf tile, and a fixed cost per cover once on disk.
    static let storedPixels = 600
    /// A saved listing is used for this long before it is fetched again.
    static let listingLifetime: TimeInterval = 30 * 24 * 3600

    enum Outcome: Equatable {
        case cover(URL)
        /// No art on the server for this game. Remembered until Refresh Covers or the next launch.
        case notFound
        /// Network or disk trouble. Not remembered, so the next refresh tries again.
        case failed

        var file: URL? {
            if case .cover(let url) = self { return url }
            return nil
        }
    }

    private let session: URLSession
    private let directory: URL
    /// Games that found nothing this launch, so reopening the app's screens does not ask again.
    @MainActor private var misses = Set<String>()

    init(session: URLSession = CoverArtFetcher.makeSession(),
         directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers", isDirectory: true)) {
        self.session = session
        self.directory = directory
    }

    /// Ephemeral: no cookies or disk cache. `protocolClasses` lets a test replace the network.
    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        return URLSession(configuration: configuration)
    }

    private func cacheFile(platformID: String, title: String) -> URL {
        let digest = SHA256.hash(data: Data("\(platformID)/\(title)".utf8))
        return directory.appendingPathComponent(digest.map { String(format: "%02x", $0) }.joined()).appendingPathExtension("png")
    }

    private func listingFile(platformID: String) -> URL {
        directory.appendingPathComponent("index-\(platformID).txt")
    }

    func cachedCover(for game: GameItem) -> URL? {
        let file = cacheFile(platformID: game.platformID, title: game.title)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// What to look up: the title, then a disc set's folder name, since the sheet inside may be named anything.
    static func queries(for game: GameItem) -> [String] {
        let rom = URL(fileURLWithPath: game.romPath)
        guard DiscSet.isDescriptor(rom.lastPathComponent) else { return [game.title] }
        return [game.title, rom.deletingLastPathComponent().lastPathComponent]
    }

    /// Refresh Covers: forget this launch's misses and saved listings, so everything missing is asked again.
    @MainActor
    func forgetMisses() {
        misses.removeAll()
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("index-") { try? FileManager.default.removeItem(at: file) }
    }

    /// One at a time, to be polite to a volunteer-run server. `isEnabled` is checked before each request.
    /// Stops at the first network failure; the next refresh or launch tries again.
    @MainActor
    func fetchMissing(games: [GameItem], isEnabled: @escaping () -> Bool, onCover: @escaping () -> Void) async {
        var indexes: [String: LibretroThumbnails.Index] = [:]
        for game in games where cachedCover(for: game) == nil {
            guard isEnabled(), !Task.isCancelled else { return }
            let key = "\(game.platformID)/\(game.title)"
            guard !misses.contains(key) else { continue }
            guard LibretroThumbnails.systems[game.platformID] != nil else {
                log(game, "no thumbnail system")
                misses.insert(key)
                continue
            }
            if indexes[game.platformID] == nil {
                guard let index = await index(platformID: game.platformID) else {
                    if !Task.isCancelled { log(game, "listing failed") }
                    return
                }
                indexes[game.platformID] = index
            }
            guard isEnabled(), !Task.isCancelled else { return }
            let outcome = await fetch(game, index: indexes[game.platformID] ?? [:])
            // A cancelled walk (a newer refresh replaced it) is not a miss.
            guard !Task.isCancelled else { return }
            switch outcome {
            case .cover: onCover()
            case .notFound: misses.insert(key)
            case .failed: return
            }
        }
    }

    /// Looks the game up in `index` (or the folder's listing when nil) and caches the cover it finds.
    func fetch(_ game: GameItem, index given: LibretroThumbnails.Index? = nil) async -> Outcome {
        guard LibretroThumbnails.systems[game.platformID] != nil else { return .notFound }
        let index: LibretroThumbnails.Index
        if let given {
            index = given
        } else if let loaded = await self.index(platformID: game.platformID) {
            index = loaded
        } else {
            return .failed
        }
        guard let name = LibretroThumbnails.bestMatch(for: Self.queries(for: game), in: index),
              let url = LibretroThumbnails.url(platformID: game.platformID, title: name) else {
            log(game, "no match")
            return .notFound
        }
        let (data, status) = await download(url, limit: Self.maxBytes)
        guard let data else {
            log(game, "\(name) -> \(status)")
            return status == 404 ? .notFound : .failed
        }
        guard let png = Self.validatedPNG(data) else {
            log(game, "\(name) -> not an image")
            return .notFound
        }
        let file = cacheFile(platformID: game.platformID, title: game.title)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: file, options: .atomic)
            log(game, "\(name) -> cached")
            return .cover(file)
        } catch {
            return .failed
        }
    }

    /// The saved listing while it is fresh, else a new one from the server. Nil when neither works.
    func index(platformID: String) async -> LibretroThumbnails.Index? {
        let file = listingFile(platformID: platformID)
        let age = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            .map { Date().timeIntervalSince($0) }
        if let age, age < Self.listingLifetime, let text = try? String(contentsOf: file, encoding: .utf8) {
            return LibretroThumbnails.index(text.split(separator: "\n").map(String.init))
        }
        guard let url = LibretroThumbnails.listingURL(platformID: platformID) else { return nil }
        let (data, _) = await download(url, limit: Self.maxListingBytes)
        guard let data, let html = String(data: data, encoding: .utf8) else { return nil }
        let names = LibretroThumbnails.names(fromListing: html)
        guard !names.isEmpty else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? names.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        return LibretroThumbnails.index(names)
    }

    /// HTTPS only, including wherever a redirect ends up, and stops reading at `limit`. The status is 0 for a
    /// transport error.
    private func download(_ url: URL, limit: Int) async -> (Data?, Int) {
        guard url.scheme == "https" else { return (nil, 0) }
        do {
            let (bytes, response) = try await session.bytes(from: url)
            guard let http = response as? HTTPURLResponse else { return (nil, 0) }
            guard http.statusCode == 200, http.url?.scheme == "https",
                  http.expectedContentLength <= Int64(limit) else { return (nil, http.statusCode) }
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count > limit { return (nil, http.statusCode) }
            }
            return (data, 200)
        } catch {
            return (nil, 0)
        }
    }

    /// Debug builds only, and never the file's path: the platform, the title and what happened.
    private func log(_ game: GameItem, _ status: String) {
        #if DEBUG
        print("[gaga-cover] \(game.platformID) \(game.title) -> \(status)")
        #endif
    }

    /// Decodes for real and re-encodes, so only pixels we produced reach the cache. PNG or JPEG only, with
    /// the dimensions checked before any decode, because a small file can claim an enormous image.
    static func validatedPNG(_ data: Data) -> Data? {
        guard data.count <= maxBytes, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == UTType.png.identifier || type == UTType.jpeg.identifier,
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...maxPixels).contains(width), (1...maxPixels).contains(height) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: storedPixels,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).pngData()
    }
}
