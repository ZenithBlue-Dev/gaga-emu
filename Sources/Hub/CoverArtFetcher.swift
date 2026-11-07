import CryptoKit
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Libretro's public boxart server, matched by title only (docs/06 section 5). The file name must equal
/// the title, so a title that is not the No-Intro name simply has no cover.
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
        "dreamcast": "Sega - Dreamcast",
        "dos": "DOS",
        "mastersystem": "Sega - Master System - Mark III",
        "gamegear": "Sega - Game Gear",
        "sg1000": "Sega - SG-1000"
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
}

/// Downloads into Caches and writes only what it could decode. Every failure leaves the placeholder.
final class CoverArtFetcher {
    static let maxBytes = 5 * 1024 * 1024
    static let maxPixels = 4096
    /// Plenty for the largest shelf tile, and a fixed cost per cover once on disk.
    static let storedPixels = 600

    private let session: URLSession
    private let directory: URL
    /// Titles that found nothing this launch, so reopening the app's screens does not ask again.
    private var misses = Set<String>()

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

    func cachedCover(for game: GameItem) -> URL? {
        let file = cacheFile(platformID: game.platformID, title: game.title)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// One at a time, to be polite to a volunteer-run server. `isEnabled` is checked before each request.
    @MainActor
    func fetchMissing(games: [GameItem], isEnabled: @escaping () -> Bool, onCover: @escaping () -> Void) async {
        for game in games where cachedCover(for: game) == nil {
            guard isEnabled(), !Task.isCancelled else { return }
            let key = "\(game.platformID)/\(game.title)"
            guard !misses.contains(key) else { continue }
            if await fetch(game) != nil {
                onCover()
            } else {
                misses.insert(key)
            }
        }
    }

    /// Returns the cached file, or nil for any failure.
    func fetch(_ game: GameItem) async -> URL? {
        guard let url = LibretroThumbnails.url(platformID: game.platformID, title: game.title),
              let data = await download(url), let png = Self.validatedPNG(data) else { return nil }
        let file = cacheFile(platformID: game.platformID, title: game.title)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: file, options: .atomic)
            return file
        } catch {
            return nil
        }
    }

    /// HTTPS only, including wherever a redirect ends up, and stops reading at the size limit.
    private func download(_ url: URL) async -> Data? {
        guard url.scheme == "https" else { return nil }
        do {
            let (bytes, response) = try await session.bytes(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.scheme == "https",
                  http.expectedContentLength <= Int64(Self.maxBytes) else { return nil }
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count > Self.maxBytes { return nil }
            }
            return data
        } catch {
            return nil
        }
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
