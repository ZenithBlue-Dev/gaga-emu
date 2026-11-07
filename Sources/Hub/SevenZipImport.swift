import Foundation

/// .7z import beside .zip: the same entries, rules, limits and placement, read through Sources/Archive.
extension CoreCatalog {
    static let rarMessage = "RAR archives are not supported. Extract it or repack it as .zip or .7z."

    /// The first bytes of a 7z archive, which can arrive named .zip.
    static func isSevenZip(_ url: URL) -> Bool { startsWith(url, [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) }

    /// A RAR archive by name or by its "Rar!" signature (RAR 4 and 5 alike).
    static func isRAR(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "rar" || startsWith(url, [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])
    }

    private static func startsWith(_ url: URL, _ magic: [UInt8]) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: magic.count)).map { [UInt8]($0) == magic } ?? false
    }

    /// A .zip's or .7z's records, by contents: a 7z named .zip is read as 7z.
    static func archiveEntries(_ url: URL) -> [ZipEntry] {
        isSevenZip(url) ? sevenZipEntries(url) : zipEntries(url)
    }

    /// A 7z's files as zip records: a folder's name ends in "/", and `sevenZipIndex` says which file to decode.
    /// None when the file is not a readable 7z.
    static func sevenZipEntries(_ url: URL) -> [ZipEntry] {
        guard let archive = gaga_7z_open(url.path) else { return [] }
        defer { gaga_7z_close(archive) }
        return (0..<gaga_7z_count(archive)).map { index in
            var name = [UInt16](repeating: 0, count: gaga_7z_name(archive, index, nil))
            gaga_7z_name(archive, index, &name)
            var crc: UInt32 = 0
            _ = gaga_7z_crc(archive, index, &crc)
            let path = String(decoding: name.prefix { $0 != 0 }, as: UTF16.self)
            return ZipEntry(name: gaga_7z_is_dir(archive, index) != 0 ? path + "/" : path, flags: 0, method: 0, crc: crc,
                            compressedSize: 0, size: Int(clamping: gaga_7z_size(archive, index)), localHeaderOffset: 0,
                            sevenZipIndex: Int(index))
        }
    }

    /// The most a 7z block behind a filter (BCJ and the like) may unpack to, as the SDK holds it whole.
    static let sevenZipMemoryLimit = 64 << 20

    /// As `extractZipEntry`, for a 7z file: streamed to a .part file, stopped past `limit`, CRC-checked by the
    /// decoder, then placed (or matched to an identical file) by `ClipboardImporter.place`.
    static func extractSevenZipEntry(_ entry: ZipEntry, index: Int, from archiveURL: URL, to destination: URL,
                                     limit: Int) throws -> URL {
        guard entry.size <= limit else { throw ZipError.tooLarge }
        guard let archive = gaga_7z_open(archiveURL.path) else { throw ZipError.corrupt }
        defer { gaga_7z_close(archive) }
        let part = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).part")
        guard FileManager.default.createFile(atPath: part.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        defer { try? FileManager.default.removeItem(at: part) }

        final class Sink {
            let output: FileHandle, limit: Int
            var written = 0, error: Error?
            init(_ output: FileHandle, _ limit: Int) { self.output = output; self.limit = limit }
        }
        let sink = Sink(try FileHandle(forWritingTo: part), limit)
        let status = withExtendedLifetime(sink) {
            gaga_7z_extract(archive, UInt32(index), UInt64(sevenZipMemoryLimit), { context, bytes, count in
                let sink = Unmanaged<Sink>.fromOpaque(context!).takeUnretainedValue()
                sink.written += count
                guard sink.written <= sink.limit else { sink.error = ZipError.tooLarge; return 1 }
                do { try sink.output.write(contentsOf: UnsafeBufferPointer(start: bytes, count: count)) } catch {
                    sink.error = error
                    return 1
                }
                return 0
            }, Unmanaged.passUnretained(sink).toOpaque())
        }
        try? sink.output.close()
        switch Int(status) {
        case Int(GAGA_7Z_OK): break
        case Int(GAGA_7Z_STOPPED): throw sink.error ?? ZipError.corrupt
        case Int(GAGA_7Z_UNSUPPORTED), Int(GAGA_7Z_NO_MEMORY): throw ZipError.unsupported
        default: throw ZipError.corrupt
        }
        guard sink.written == entry.size else { throw ZipError.corrupt }
        return try ClipboardImporter.place(part, named: destination.lastPathComponent, in: destination.deletingLastPathComponent())
    }
}
