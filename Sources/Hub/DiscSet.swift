import Foundation

/// A multi-file disc: a descriptor (.cue, .gdi, .ccd, .toc, .m3u) and the files it names. Each set lives in its
/// own folder under the ROM folder with every file under its original name, so the names in the descriptor
/// always resolve. Files may arrive one at a time and in any order. Flat sets from older builds stay as they are.
enum DiscSet {
    static let descriptorExtensions: Set<String> = ["cue", "gdi", "ccd", "toc", "m3u"]

    static func isDescriptor(_ name: String) -> Bool {
        descriptorExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// The file names `descriptor` references, as written in it. A name with a folder in it is left out, because
    /// a set is one flat folder.
    static func references(of descriptor: URL) -> [String] {
        let ext = descriptor.pathExtension.lowercased()
        let stem = descriptor.deletingPathExtension().lastPathComponent
        // CloneCD names nothing: its image and subchannel share the sheet's name.
        if ext == "ccd" { return ["\(stem).img", "\(stem).sub"] }
        let size = (try? descriptor.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size <= 1 << 20, let data = try? Data(contentsOf: descriptor) else { return [] }
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        func quoted(_ line: String) -> String? {
            guard let open = line.firstIndex(of: "\"") else { return nil }
            let rest = line[line.index(after: open)...]
            return rest.firstIndex(of: "\"").map { String(rest[..<$0]) }
        }
        var names: [String] = []
        switch ext {
        case "cue":
            for line in lines where line.uppercased().hasPrefix("FILE ") {
                let rest = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                names.append(quoted(rest) ?? rest.split(separator: " ").first.map(String.init) ?? "")
            }
        case "gdi":
            // "track lba type sector-size name offset", after a first line that counts the tracks.
            for line in lines.dropFirst() {
                let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                guard tokens.count >= 5 else { continue }
                names.append(quoted(line) ?? String(tokens[4]))
            }
        case "toc":
            for line in lines {
                let upper = line.uppercased()
                guard upper.hasPrefix("FILE ") || upper.hasPrefix("DATAFILE ") || upper.hasPrefix("AUDIOFILE ") else { continue }
                quoted(line).map { names.append($0) }
            }
        default: // m3u
            names = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") }
        }
        var seen = Set<String>()
        return names.filter { !$0.isEmpty && WiFiTransferServer.sanitize($0) == $0 && seen.insert($0.lowercased()).inserted }
    }

    private static func files(in folder: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { name in
            var isDirectory: ObjCBool = false
            return !name.hasPrefix(".")
                && FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        }.sorted()
    }

    /// Every name the set in `folder` needs: its descriptors and what they name, through an .m3u's sheets.
    static func wanted(in folder: URL) -> [String] {
        var wanted = files(in: folder).filter(isDescriptor)
        var index = 0
        while index < wanted.count {
            let url = folder.appendingPathComponent(wanted[index])
            index += 1
            guard isDescriptor(url.lastPathComponent), FileManager.default.fileExists(atPath: url.path) else { continue }
            for name in references(of: url) where !wanted.contains(where: { $0.lowercased() == name.lowercased() }) {
                wanted.append(name)
            }
        }
        return wanted
    }

    static func missing(in folder: URL) -> [String] {
        wanted(in: folder).filter { !FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }
    }

    /// The descriptor the game entry points at: the one no other descriptor in the folder names.
    static func primary(in folder: URL) -> URL? {
        let descriptors = files(in: folder).filter(isDescriptor)
        let named = Set(descriptors.flatMap { references(of: folder.appendingPathComponent($0)) }.map { $0.lowercased() })
        let rank = ["m3u", "gdi", "cue", "ccd", "toc"]
        return descriptors.filter { !named.contains($0.lowercased()) }
            .min { (rank.firstIndex(of: ($0 as NSString).pathExtension.lowercased()) ?? 9, $0)
                 < (rank.firstIndex(of: ($1 as NSString).pathExtension.lowercased()) ?? 9, $1) }
            .map { folder.appendingPathComponent($0) }
    }

    /// The set folder holding `url`, when it sits directly under `romDirectory`.
    static func folder(of url: URL, romDirectory: URL) -> URL? {
        let folder = url.deletingLastPathComponent()
        guard folder.deletingLastPathComponent().resolvingSymlinksInPath().path == romDirectory.resolvingSymlinksInPath().path
        else { return nil }
        return folder
    }

    /// Set folders directly under `romDirectory`, newest first, so a late track joins the latest set that misses it.
    static func folders(in romDirectory: URL) -> [URL] {
        let key = URLResourceKey.creationDateKey
        // Built from names, because a listed URL may spell /var as /private/var and then match no saved path.
        let urls = ((try? FileManager.default.contentsOfDirectory(atPath: romDirectory.path)) ?? [])
            .filter { !$0.hasPrefix(".") }.map { romDirectory.appendingPathComponent($0, isDirectory: true) }
        return urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && files(in: $0).contains(where: isDescriptor) }
            .map { ($0, (try? $0.resourceValues(forKeys: [key]).creationDate) ?? .distantPast) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// A new empty folder for a set, "Game", else "Game 2" and so on. Creating it is the claim, so two never share.
    static func newFolder(for descriptorName: String, in romDirectory: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: romDirectory, withIntermediateDirectories: true)
        var stem = (descriptorName as NSString).deletingPathExtension
        while stem.hasPrefix(".") { stem.removeFirst() }
        if stem.isEmpty { stem = "Disc" }
        for number in 1... {
            let folder = romDirectory.appendingPathComponent(number == 1 ? stem : "\(stem) \(number)", isDirectory: true)
            if fileManager.fileExists(atPath: folder.path) { continue }
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: false)
                return folder
            } catch where fileManager.fileExists(atPath: folder.path) {
                continue
            }
        }
        throw CocoaError(.fileWriteUnknown)
    }

    /// Moves an arriving `file` named `name` into a set: the newest set folder that misses that name, under the
    /// spelling its descriptor uses, or else a new folder when it is a descriptor. Nil means it is no set's file.
    static func route(_ file: URL, named name: String, in romDirectory: URL) throws -> URL? {
        let fileManager = FileManager.default
        for folder in folders(in: romDirectory) {
            guard let wanted = missing(in: folder).first(where: { $0.lowercased() == name.lowercased() }) else { continue }
            let dest = folder.appendingPathComponent(wanted)
            try fileManager.moveItem(at: file, to: dest) // Missing, so nothing is replaced; a move never overwrites.
            return dest
        }
        guard isDescriptor(name) else { return nil }
        let folder = try newFolder(for: name, in: romDirectory)
        let dest = folder.appendingPathComponent(name)
        do {
            try fileManager.moveItem(at: file, to: dest)
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }
        return dest
    }

    /// Names the flat descriptors in `romDirectory` reference, lowercased. Those files belong to an older flat set.
    static func flatClaims(in romDirectory: URL) -> Set<String> {
        Set(files(in: romDirectory).filter(isDescriptor)
            .flatMap { references(of: romDirectory.appendingPathComponent($0)) }.map { $0.lowercased() })
    }

    /// Moves files that arrived before the descriptor into `folder`: flat files under the name it uses (or the
    /// "Name 2.bin" an older import gave a colliding one), and for an .m3u, whole set folders of its sheets. Only
    /// what `movable` allows and no flat set names moves. Returns the files and folders taken.
    static func gather(into folder: URL, romDirectory: URL, movable: (URL) -> Bool) -> [URL] {
        let fileManager = FileManager.default
        var taken: [URL] = []
        var progress = true
        while progress {
            progress = false
            let claims = flatClaims(in: romDirectory)
            let flat = files(in: romDirectory)
            for name in missing(in: folder) {
                let lower = name.lowercased()
                if isDescriptor(name), let other = folders(in: romDirectory).first(where: {
                    $0.path != folder.path && primary(in: $0)?.lastPathComponent.lowercased() == lower
                }), let sheet = primary(in: other), movable(sheet) {
                    let names = files(in: other)
                    let local = Set(files(in: folder).map { $0.lowercased() })
                    guard !names.contains(where: { local.contains($0.lowercased()) }) else { continue }
                    for file in names {
                        let dest = folder.appendingPathComponent(file == sheet.lastPathComponent ? name : file)
                        guard (try? fileManager.moveItem(at: other.appendingPathComponent(file), to: dest)) != nil else { continue }
                    }
                    if files(in: other).isEmpty { try? fileManager.removeItem(at: other) }
                    taken.append(other)
                    progress = true
                    continue
                }
                let stem = (lower as NSString).deletingPathExtension, ext = (lower as NSString).pathExtension
                func number(_ candidate: String) -> Int? {
                    let c = candidate.lowercased()
                    if c == lower { return Int.max }
                    guard c.hasPrefix(stem + " "), (c as NSString).pathExtension == ext else { return nil }
                    return Int((c as NSString).deletingPathExtension.dropFirst(stem.count + 1))
                }
                let source = flat.compactMap { candidate in number(candidate).map { (candidate, $0) } }
                    .filter { !claims.contains($0.0.lowercased()) && movable(romDirectory.appendingPathComponent($0.0)) }
                    .max { $0.1 < $1.1 }
                guard let source else { continue }
                let from = romDirectory.appendingPathComponent(source.0)
                guard (try? fileManager.moveItem(at: from, to: folder.appendingPathComponent(name))) != nil else { continue }
                taken.append(from)
                progress = true
            }
        }
        return taken
    }

    /// An older folder holding the same complete set: the same names, and every file the same size and CRC-32.
    static func twin(of folder: URL, in romDirectory: URL) -> URL? {
        guard missing(in: folder).isEmpty, let sheet = primary(in: folder)?.lastPathComponent else { return nil }
        let names = files(in: folder)
        return folders(in: romDirectory).first { other in
            other.path != folder.path
                && primary(in: other)?.lastPathComponent == sheet && files(in: other) == names
                && names.allSatisfy { ClipboardImporter.sameContents(folder.appendingPathComponent($0), other.appendingPathComponent($0)) }
        }
    }
}
