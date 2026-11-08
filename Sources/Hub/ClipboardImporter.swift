import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Reads the clipboard only when the user taps. Never polls.
/// Accepts a file URL or a binary ROM blob. Web links are rejected: no ROM is downloaded.
public struct ClipboardImporter: Sendable {

    public enum Item: Equatable {
        case file(URL)
        case archive(URL)
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
        "zip", "7z", "rar", "bin", "iso", "chd", "pbp", "cso", "cue", "ccd", "toc", "m3u", "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf",
        "gba", "gbc", "gb", "nes", "sfc", "smc", "n64", "z64", "v64", "nds", "3ds", "cia", "md", "gen",
        "sms", "gg", "cdi", "gdi", "pce", "sgx", "vb", "vboy", "a26", "a78", "lnx", "ws", "wsc",
        "pc2", "ngp", "ngc", "ngpc", "npc", "min", "3dsx", "cci", "cxi", "app", "axf", "elf",
        "sg", "mv", "a52", "xex", "atr", "xfd", "dcm", "atx", "j64", "jag", "d64", "t64", "prg", "crt", "tap", "adf", "hdf", "wad",
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
            if url.isFileURL { return try classify(url) }
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
        guard url.isFileURL else { throw ImportError.unsupported }
        let ext = url.pathExtension.lowercased()
        guard romExtensions.contains(ext) else { throw ImportError.unsupported }
        guard FileManager.default.isReadableFile(atPath: url.path) else { throw ImportError.unreadable }
        return archiveExtensions.contains(ext) ? .archive(url) : .file(url)
    }

    public static func persist(_ item: Item, into directory: URL) throws -> URL {
        switch item {
        case .file(let url), .archive(let url):
            let name = WiFiTransferServer.sanitize(url.lastPathComponent)
            guard !name.isEmpty else { throw ImportError.unsupported }
            let part = try partFile(in: directory)
            defer { try? FileManager.default.removeItem(at: part) }
            try FileManager.default.copyItem(at: url, to: part)
            return try placeROM(part, named: name, in: directory)
        case .blob(let filename, let data):
            let name = WiFiTransferServer.sanitize(filename)
            guard !name.isEmpty else { throw ImportError.unsupported }
            let part = try partFile(in: directory)
            defer { try? FileManager.default.removeItem(at: part) }
            try data.write(to: part, options: .atomic)
            return try placeROM(part, named: name, in: directory)
        }
    }

    /// A hidden scratch name in `directory`, so the move into place stays on one volume.
    static func partFile(in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(".\(UUID().uuidString).part")
    }

    /// Every import into the ROM folder ends here. A disc set's file goes to its set's folder under its own name
    /// (`DiscSet.route`); anything else is placed flat.
    static func placeROM(_ file: URL, named name: String, in directory: URL) throws -> URL {
        try DiscSet.route(file, named: name, in: directory) ?? place(file, named: name, in: directory)
    }

    /// The path of `url` under `directory`, as "Game.gba" or "Game/Game.cue".
    static func relativePath(_ url: URL, in directory: URL) -> String {
        DiscSet.folder(of: url, romDirectory: directory).map { "\($0.lastPathComponent)/\(url.lastPathComponent)" } ?? url.lastPathComponent
    }

    /// Moves `file` into `directory` as `name`, never over a different file. A file
    /// already there with the same size and CRC-32 is reused and `file` goes; otherwise the name takes the
    /// Files app's " 2", " 3" suffix, as in "Game 2.gba".
    static func place(_ file: URL, named name: String, in directory: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let stem = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        var number = 1
        while true {
            let candidate = number == 1 ? name : "\(stem) \(number)" + (ext.isEmpty ? "" : ".\(ext)")
            let dest = directory.appendingPathComponent(candidate)
            if !fileManager.fileExists(atPath: dest.path) {
                try fileManager.moveItem(at: file, to: dest)
                return dest
            }
            if sameContents(file, dest) {
                try? fileManager.removeItem(at: file)
                return dest
            }
            number += 1
        }
    }

    /// Same size and CRC-32. False when either cannot be read.
    static func sameContents(_ a: URL, _ b: URL) -> Bool {
        // Not resourceValues: a URL caches them, so a file rewritten at the same URL would keep its old size.
        func size(_ url: URL) -> Int? { (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int }
        guard let sizeA = size(a), sizeA == size(b), let crcA = RomPatcher.crc32(fileAt: a) else { return false }
        return crcA == RomPatcher.crc32(fileAt: b)
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
        assert((try? ClipboardImporter.classify(remote)) == nil, "web links are not imported")
        let junk = URL(string: "file:///tmp/notes.txt")!
        assert((try? ClipboardImporter.classify(junk)) == nil)

        // The same name never replaces a different file.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gaga-place-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        func put(_ text: String) -> String? {
            guard let part = try? ClipboardImporter.partFile(in: dir), (try? Data(text.utf8).write(to: part)) != nil else { return nil }
            return (try? ClipboardImporter.place(part, named: "Game.gba", in: dir))?.lastPathComponent
        }
        assert(put("one") == "Game.gba")
        assert(put("one") == "Game.gba", "identical: reused")
        assert(put("two") == "Game 2.gba", "different: a new name")
        assert(put("one") == "Game.gba")
        assert((try? Data(contentsOf: dir.appendingPathComponent("Game.gba"))) == Data("one".utf8))
    }
}
#endif
