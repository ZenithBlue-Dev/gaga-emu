import Compression
import Foundation

/// The libretro `cht` collection, bundled as Resources/cheats.pack (`scripts/build-cheat-pack.py` has the layout).
/// A lookup inflates one system's index and one chunk, so nothing stays in memory between lookups.
enum CheatDatabase {
    // A chunk holds at least 256 KiB, then the title that passed that mark, which is at most maxChtBytes.
    private static let maxInflated = 2 * CheatFormat.maxChtBytes

    /// Cheats for a game by its library title, all off, for the player to switch on. Empty when none match.
    static func blocks(title: String, platformID: String, coreID: String) -> [CheatFormat.Block] {
        guard let url = Bundle.main.url(forResource: "cheats", withExtension: "pack") else { return [] }
        return blocks(title: title, platformID: platformID, coreID: coreID, pack: url)
    }

    static func blocks(title: String, platformID: String, coreID: String, pack url: URL) -> [CheatFormat.Block] {
        guard let pack = try? Data(contentsOf: url, options: .mappedIfSafe), pack.count > 4 else { return [] }
        let headerLength = Int(pack[0]) | Int(pack[1]) << 8 | Int(pack[2]) << 16 | Int(pack[3]) << 24
        let base = 4 + headerLength
        guard let headerData = slice(pack, 4, headerLength),
              let header = try? JSONDecoder().decode([String: [Int]].self, from: headerData),
              let system = header[platformID], system.count == 2,
              let compressedIndex = slice(pack, base + system[0], system[1]),
              let indexData = inflate(compressedIndex),
              let index = try? JSONDecoder().decode([String: [Int]].self, from: indexData),
              let entry = index[key(title)], entry.count == 4, entry[3] <= CheatFormat.maxChtBytes,
              let compressed = slice(pack, base + entry[0], entry[1]),
              let chunk = inflate(compressed),
              let text = slice(chunk, entry[2], entry[3]) else { return [] }
        return CheatFormat.chtBlocks(String(decoding: text, as: UTF8.self), coreID: coreID)
    }

    /// A title without its tags or article, in ASCII letters and digits. Must match `key` in the pack script.
    static func key(_ title: String) -> String {
        let untagged = title.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: "", options: .regularExpression)
        let text = untagged.decomposedStringWithCanonicalMapping.lowercased()
            .replacingOccurrences(of: #",\s*the\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*the\s+"#, with: "", options: .regularExpression)
        return String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0)) }))
    }

    private static func slice(_ data: Data, _ offset: Int, _ length: Int) -> Data? {
        guard offset >= 0, length > 0, offset <= data.count - length else { return nil }
        return data.subdata(in: data.startIndex + offset..<data.startIndex + offset + length)
    }

    /// Nil when the data is bad or would pass the limit.
    private static func inflate(_ input: Data) -> Data? {
        var output = Data(count: maxInflated)
        let count = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { source in
                compression_decode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, maxInflated,
                                          source.bindMemory(to: UInt8.self).baseAddress!, input.count, nil, COMPRESSION_LZMA)
            }
        }
        guard count > 0, count < maxInflated else { return nil }
        return output.prefix(count)
    }
}
