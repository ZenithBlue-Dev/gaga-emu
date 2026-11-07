import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Reads the clipboard only when the user taps. Never polls.
/// Accepts a file URL, an http(s) download URL, or a binary ROM blob.
public struct ClipboardImporter: Sendable {

    public enum Item: Equatable {
        case file(URL)
        case archive(URL)
        case remote(URL)
        case blob(filename: String, data: Data)
    }

    public enum ImportError: LocalizedError, Equatable {
        case empty, unsupported, unreadable
        public var errorDescription: String? {
            switch self {
            case .empty: return "Clipboard is empty."
            case .unsupported: return "Clipboard has nothing GagaEmu can import."
            case .unreadable: return "Clipboard item could not be read."
            }
        }
    }

    public static let romExtensions: Set<String> = [
        "zip", "7z", "rar", "bin", "iso", "chd", "pbp", "cso", "cue", "m3u", "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf",
        "gba", "gbc", "gb", "nes", "sfc", "smc", "n64", "z64", "v64", "nds", "3ds", "cia",
        "md", "gen", "sms", "gg", "cdi", "gdi", "pce", "ccd", "sgx", "vb", "vboy", "a26", "a78", "lnx", "ws", "wsc", "ngp", "ngc",
        "ips", "ups", "bps", "sav", "srm"
    ]
    public static let archiveExtensions: Set<String> = ["zip", "7z", "rar"]

    /// Call from the "Read Clipboard" button action. This is the only entry point.
    public static func scan() throws -> Item {
        #if canImport(UIKit)
        return try scan(pasteboard: UIPasteboard.general)
        #else
        throw ImportError.empty
        #endif
    }

    #if canImport(UIKit)
    static func scan(pasteboard: UIPasteboard) throws -> Item {
        if let url = pasteboard.url ?? pasteboard.urls?.first {
            return try classify(url)
        }
        if let text = pasteboard.string, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if url.isFileURL || remoteScheme(url) { return try classify(url) }
        }
        if let data = pasteboard.data(forPasteboardType: "public.data")
            ?? pasteboard.data(forPasteboardType: "public.zip-archive"), !data.isEmpty {
            let ext = sniffExtension(data) ?? "bin"
            return .blob(filename: "clipboard.\(ext)", data: data)
        }
        if pasteboard.hasURLs || pasteboard.hasStrings || pasteboard.numberOfItems > 0 {
            throw ImportError.unsupported
        }
        throw ImportError.empty
    }
    #endif

    static func classify(_ url: URL) throws -> Item {
        if remoteScheme(url) { return .remote(url) }
        guard url.isFileURL else { throw ImportError.unsupported }
        let ext = url.pathExtension.lowercased()
        guard romExtensions.contains(ext) else { throw ImportError.unsupported }
        guard FileManager.default.isReadableFile(atPath: url.path) else { throw ImportError.unreadable }
        return archiveExtensions.contains(ext) ? .archive(url) : .file(url)
    }

    /// Downloads a remote ROM into `directory`. Rejects non-http schemes and non-ROM names.
    public static func download(_ url: URL, into directory: URL) async throws -> URL {
        guard remoteScheme(url) else { throw ImportError.unsupported }
        let (temp, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ImportError.unreadable
        }
        let suggested = response.suggestedFilename ?? url.lastPathComponent
        let name = WiFiTransferServer.sanitize(suggested)
        let ext = (name as NSString).pathExtension.lowercased()
        guard romExtensions.contains(ext), !name.isEmpty else {
            try? FileManager.default.removeItem(at: temp)
            throw ImportError.unsupported
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dest = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }

    public static func persist(_ item: Item, into directory: URL) throws -> URL {
        switch item {
        case .file(let url), .archive(let url):
            let name = WiFiTransferServer.sanitize(url.lastPathComponent)
            guard !name.isEmpty else { throw ImportError.unsupported }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let dest = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        case .blob(let filename, let data):
            let name = WiFiTransferServer.sanitize(filename)
            guard !name.isEmpty else { throw ImportError.unsupported }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let dest = directory.appendingPathComponent(name)
            try data.write(to: dest, options: .atomic)
            return dest
        case .remote:
            throw ImportError.unsupported // use download(_:into:)
        }
    }

    private static func remoteScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Cheap magic-byte sniff so a raw paste still gets a usable extension.
    static func sniffExtension(_ data: Data) -> String? {
        if data.starts(with: Data([0x50, 0x4B, 0x03, 0x04])) { return "zip" }
        if data.starts(with: Data("7z".utf8)) { return "7z" }
        if data.starts(with: Data("Rar!".utf8)) { return "rar" }
        if data.starts(with: Data("PATCH".utf8)) { return "ips" }
        if data.starts(with: Data("UPS1".utf8)) { return "ups" }
        if data.starts(with: Data("BPS1".utf8)) { return "bps" }
        return nil
    }
}

#if DEBUG
enum ClipboardImporterChecks {
    static func run() {
        assert(ClipboardImporter.sniffExtension(Data([0x50, 0x4B, 0x03, 0x04, 0x00])) == "zip")
        assert(ClipboardImporter.sniffExtension(Data("PATCH".utf8)) == "ips")
        let remote = URL(string: "https://example.com/game.gba")!
        assert((try? ClipboardImporter.classify(remote)) == .remote(remote))
        let junk = URL(string: "file:///tmp/notes.txt")!
        assert((try? ClipboardImporter.classify(junk)) == nil)
    }
}
#endif
