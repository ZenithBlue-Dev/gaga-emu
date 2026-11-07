import Foundation
import CryptoKit

/// In-memory IPS, UPS, and BPS patcher. The source dump is never modified;
/// the patched image is returned (or written to a new file).
public enum RomPatcher {

    public enum Format: String, Sendable { case ips, ups, bps }

    public struct Checksums: Equatable, Sendable {
        public let crc32: UInt32
        public let md5: String
        public let sha1: String
    }

    public enum PatchError: LocalizedError, Equatable {
        case unknownFormat, truncated, badChecksum(expected: String, actual: String), unsupported
        public var errorDescription: String? {
            switch self {
            case .unknownFormat: return "Patch is not IPS, UPS, or BPS."
            case .truncated: return "Patch ended early."
            case .badChecksum(let expected, let actual): return "Checksum \(actual) != \(expected)."
            case .unsupported: return "Patch uses an unsupported feature."
            }
        }
    }

    public static func format(of patch: Data) -> Format? {
        if patch.starts(with: Data("PATCH".utf8)) { return .ips }
        if patch.starts(with: Data("UPS1".utf8)) { return .ups }
        if patch.starts(with: Data("BPS1".utf8)) { return .bps }
        return nil
    }

    /// Applies `patch` to `source`. When the patch names a source checksum, it is verified first.
    public static func apply(_ patch: Data, to source: Data) throws -> Data {
        switch format(of: patch) {
        case .ips: return try applyIPS(patch, to: source)
        case .ups: return try applyUPS(patch, to: source)
        case .bps: return try applyBPS(patch, to: source)
        case nil: throw PatchError.unknownFormat
        }
    }

    public static func apply(patch url: URL, toSource sourceURL: URL, writingTo dest: URL) throws -> Checksums {
        let source = try Data(contentsOf: sourceURL)
        let patch = try Data(contentsOf: url)
        let output = try apply(patch, to: source)
        try output.write(to: dest, options: .atomic)
        return checksums(output)
    }

    // MARK: Checksums

    public static func checksums(_ data: Data) -> Checksums {
        Checksums(crc32: crc32(data), md5: hex(Insecure.MD5.hash(data: data)), sha1: hex(Insecure.SHA1.hash(data: data)))
    }

    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    /// A file's CRC-32 read 1 MiB at a time, so a disc image is never loaded whole. Nil when a read fails.
    static func crc32(fileAt url: URL) -> UInt32? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var crc: UInt32 = 0xFFFF_FFFF
        do {
            while let data = try handle.read(upToCount: 1 << 20), !data.isEmpty {
                for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
            }
        } catch { return nil }
        return crc ^ 0xFFFF_FFFF
    }

    /// Verifies and throws `badChecksum` on mismatch. Comparison is case-insensitive.
    public static func verify(_ data: Data, crc32 expectedCRC: UInt32? = nil, md5 expectedMD5: String? = nil) throws -> Checksums {
        let sums = checksums(data)
        if let expectedCRC, sums.crc32 != expectedCRC {
            throw PatchError.badChecksum(expected: String(format: "%08X", expectedCRC), actual: String(format: "%08X", sums.crc32))
        }
        if let expectedMD5, sums.md5.caseInsensitiveCompare(expectedMD5) != .orderedSame {
            throw PatchError.badChecksum(expected: expectedMD5.lowercased(), actual: sums.md5.lowercased())
        }
        return sums
    }

    private static func hex(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Also read by the zip importer, which checks CRC-32 a chunk at a time.
    static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) == 1 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
            return c
        }
    }()

    // MARK: IPS, including RLE records

    static func applyIPS(_ patch: Data, to source: Data) throws -> Data {
        var r = Reader(patch)
        guard r.take(5) == Data("PATCH".utf8) else { throw PatchError.unknownFormat }
        var output = source
        while !r.isEmpty {
            let marker = r.peek(3)
            if marker == Data("EOF".utf8) { break }
            guard r.remaining >= 5 else { throw PatchError.truncated }
            let offset = Int(r.u24())
            let size = Int(r.u16())
            if size == 0 {
                // RLE: two-byte length, one value byte.
                guard r.remaining >= 3 else { throw PatchError.truncated }
                let run = Int(r.u16())
                let value = r.byte()
                write(Data(repeating: value, count: run), into: &output, at: offset)
            } else {
                guard r.remaining >= size else { throw PatchError.truncated }
                write(r.take(size), into: &output, at: offset)
            }
        }
        return output
    }

    // MARK: UPS

    static func applyUPS(_ patch: Data, to source: Data) throws -> Data {
        var r = Reader(patch)
        guard r.take(4) == Data("UPS1".utf8) else { throw PatchError.unknownFormat }
        let sourceSize = Int(try r.uvarint())
        let targetSize = Int(try r.uvarint())
        guard source.count == sourceSize else {
            throw PatchError.badChecksum(expected: "size \(sourceSize)", actual: "size \(source.count)")
        }
        // Patch body is everything except the trailing 12 checksum bytes.
        guard patch.count >= 16 else { throw PatchError.truncated }
        let bodyEnd = patch.count - 12
        var output = Data(count: targetSize)
        let copyCount = min(sourceSize, targetSize)
        output.replaceSubrange(0..<copyCount, with: source.prefix(copyCount))
        var index = 0
        while r.offset < bodyEnd {
            let skip = Int(try r.uvarint())
            index += skip
            while r.offset < bodyEnd {
                let x = r.byte()
                if index < targetSize {
                    let base: UInt8 = index < source.count ? source[index] : 0
                    output[index] = base ^ x
                }
                index += 1
                if x == 0 { break }
            }
        }
        let inputCRC = r.u32()
        let outputCRC = r.u32()
        guard crc32(source) == inputCRC else {
            throw PatchError.badChecksum(expected: String(format: "%08X", inputCRC), actual: String(format: "%08X", crc32(source)))
        }
        guard crc32(output) == outputCRC else {
            throw PatchError.badChecksum(expected: String(format: "%08X", outputCRC), actual: String(format: "%08X", crc32(output)))
        }
        return output
    }

    // MARK: BPS (linear mode; source-copy and target-copy)

    static func applyBPS(_ patch: Data, to source: Data) throws -> Data {
        var r = Reader(patch)
        guard r.take(4) == Data("BPS1".utf8) else { throw PatchError.unknownFormat }
        let sourceSize = Int(try r.uvarint())
        let targetSize = Int(try r.uvarint())
        let metadataSize = Int(try r.uvarint())
        guard r.remaining >= metadataSize + 12 else { throw PatchError.truncated }
        _ = r.take(metadataSize)
        guard source.count == sourceSize else {
            throw PatchError.badChecksum(expected: "size \(sourceSize)", actual: "size \(source.count)")
        }
        let bodyEnd = patch.count - 12
        var output = Data()
        output.reserveCapacity(targetSize)
        var sourceRel = 0
        var targetRel = 0
        while r.offset < bodyEnd {
            let word = try r.uvarint()
            let command = word & 3
            let length = Int((word >> 2) + 1)
            switch command {
            case 0: // SourceRead
                guard output.count + length <= source.count else { throw PatchError.truncated }
                output.append(source[output.count..<(output.count + length)])
            case 1: // TargetRead
                guard r.remaining >= length else { throw PatchError.truncated }
                output.append(r.take(length))
            case 2: // SourceCopy
                let offset = try r.signedVarint()
                sourceRel += offset
                guard sourceRel >= 0, sourceRel + length <= source.count else { throw PatchError.truncated }
                output.append(source[sourceRel..<(sourceRel + length)])
                sourceRel += length
            case 3: // TargetCopy
                let offset = try r.signedVarint()
                targetRel += offset
                guard targetRel >= 0 else { throw PatchError.truncated }
                for _ in 0..<length {
                    guard targetRel < output.count else { throw PatchError.truncated }
                    output.append(output[targetRel])
                    targetRel += 1
                }
            default:
                throw PatchError.unsupported
            }
        }
        guard output.count == targetSize else { throw PatchError.truncated }
        let sourceCRC = r.u32()
        let targetCRC = r.u32()
        guard crc32(source) == sourceCRC else {
            throw PatchError.badChecksum(expected: String(format: "%08X", sourceCRC), actual: String(format: "%08X", crc32(source)))
        }
        guard crc32(output) == targetCRC else {
            throw PatchError.badChecksum(expected: String(format: "%08X", targetCRC), actual: String(format: "%08X", crc32(output)))
        }
        return output
    }

    private static func write(_ bytes: Data, into output: inout Data, at offset: Int) {
        guard offset >= 0 else { return }
        if offset > output.count {
            output.append(Data(count: offset - output.count))
        }
        let end = offset + bytes.count
        if end <= output.count {
            output.replaceSubrange(offset..<end, with: bytes)
        } else if offset < output.count {
            let head = output.count - offset
            output.replaceSubrange(offset..<output.count, with: bytes.prefix(head))
            output.append(bytes.dropFirst(head))
        } else {
            output.append(bytes)
        }
    }

    struct Reader {
        let data: Data
        var offset: Int = 0
        init(_ data: Data) { self.data = data }
        var remaining: Int { data.count - offset }
        var isEmpty: Bool { offset >= data.count }

        mutating func byte() -> UInt8 {
            defer { offset += 1 }
            return data[offset]
        }
        mutating func take(_ n: Int) -> Data {
            let slice = data[offset..<(offset + n)]
            offset += n
            return Data(slice)
        }
        func peek(_ n: Int) -> Data { Data(data[offset..<min(offset + n, data.count)]) }
        mutating func u16() -> UInt16 { UInt16(byte()) << 8 | UInt16(byte()) }
        mutating func u24() -> UInt32 { UInt32(byte()) << 16 | UInt32(byte()) << 8 | UInt32(byte()) }
        mutating func u32() -> UInt32 {
            let b0 = UInt32(byte()), b1 = UInt32(byte()), b2 = UInt32(byte()), b3 = UInt32(byte())
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        }
        mutating func uvarint() throws -> UInt64 {
            var shift = 0, value: UInt64 = 0
            while remaining > 0 {
                let b = byte()
                value += UInt64(b & 0x7F) << shift
                if b & 0x80 != 0 { return value }
                shift += 7
                value += 1 << shift
                guard shift <= 56 else { throw PatchError.truncated }
            }
            throw PatchError.truncated
        }
        mutating func signedVarint() throws -> Int {
            let raw = try uvarint()
            let sign = (raw & 1) != 0
            let mag = Int(raw >> 1)
            return sign ? -mag : mag
        }
    }
}

#if DEBUG
enum RomPatcherChecks {
    static func run() {
        let source = Data("Hello World".utf8)
        // IPS: overwrite "World" at offset 6.
        var ips = Data("PATCH".utf8)
        ips.append(contentsOf: [0x00, 0x00, 0x06, 0x00, 0x05])
        ips.append(contentsOf: Data("Gaga!".utf8))
        ips.append(contentsOf: Data("EOF".utf8))
        let patched = try? RomPatcher.apply(ips, to: source)
        assert(patched == Data("Hello Gaga!".utf8))
        let sums = RomPatcher.checksums(Data("123456789".utf8))
        assert(sums.crc32 == 0xCBF4_3926)
        assert(sums.md5 == "25f9e794323b453885f5181f1b624d0b")
        assert((try? RomPatcher.verify(Data([0x00]), crc32: 0)) == nil)
    }
}
#endif
