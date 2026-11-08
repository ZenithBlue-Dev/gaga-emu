import Foundation
import CryptoKit

/// IPS, UPS, BPS, PPF, APS and RUP patcher, written from the format descriptions. The source dump is never
/// modified; the patched image is returned (or written to a new file).
public enum RomPatcher {

    public enum Format: String, Sendable { case ips, ups, bps, ppf, aps, rup }

    /// Largest image a patch may ask for: a header is untrusted, and its size is allocated.
    static let maxOutput = 1 << 31

    public struct Checksums: Equatable, Sendable {
        public let crc32: UInt32
        public let md5: String
        public let sha1: String
    }

    public enum PatchError: LocalizedError, Equatable {
        case unknownFormat, truncated, badChecksum(expected: String, actual: String), unsupported
        public var errorDescription: String? {
            switch self {
            case .unknownFormat: return "Patch is not IPS, UPS, BPS, PPF, APS or RUP."
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
        if patch.starts(with: Data("PPF".utf8)) { return .ppf }
        if patch.starts(with: Data("APS1".utf8)) { return .aps }
        if patch.starts(with: Data("NINJA2".utf8)) { return .rup }
        return nil
    }

    /// Applies `patch` to `source`. When the patch names a source checksum, it is verified first.
    public static func apply(_ patch: Data, to source: Data) throws -> Data {
        switch format(of: patch) {
        case .ips: return try applyIPS(patch, to: source)
        case .ups: return try applyUPS(patch, to: source)
        case .bps: return try applyBPS(patch, to: source)
        case .ppf: return try applyPPF(patch, to: source)
        case .aps: return patch.starts(with: Data("APS10".utf8)) ? try applyAPSN64(patch, to: source) : try applyAPSGBA(patch, to: source)
        case .rup: return try applyRUP(patch, to: source)
        case nil: throw PatchError.unknownFormat
        }
    }

    public static func apply(patch url: URL, toSource sourceURL: URL, writingTo dest: URL) throws -> Checksums {
        let patch = try Data(contentsOf: url)
        // PPF is for disc images: the copy is patched on disk, so the image is never held in memory.
        if format(of: patch) == .ppf {
            try applyPPF(patch, toFile: sourceURL, writingTo: dest)
            guard let sums = checksums(fileAt: dest) else { throw PatchError.truncated }
            return sums
        }
        let source = try Data(contentsOf: sourceURL)
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

    /// `checksums` of a file read 1 MiB at a time. Nil when a read fails.
    static func checksums(fileAt url: URL) -> Checksums? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var crc: UInt32 = 0xFFFF_FFFF
        var md5 = Insecure.MD5(), sha1 = Insecure.SHA1()
        do {
            while let data = try handle.read(upToCount: 1 << 20), !data.isEmpty {
                for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
                md5.update(data: data)
                sha1.update(data: data)
            }
        } catch { return nil }
        return Checksums(crc32: crc ^ 0xFFFF_FFFF, md5: hex(md5.finalize()), sha1: hex(sha1.finalize()))
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

    // MARK: PPF 1, 2 and 3

    private struct PPF {
        var size: Int?
        var block: (offset: Int, bytes: Data)?
        var records: [(offset: Int, bytes: Data)] = []
    }

    private static func parsePPF(_ patch: Data) throws -> PPF {
        guard patch.count >= 56 else { throw PatchError.truncated }
        let version = patch[3]
        var ppf = PPF()
        var r = Reader(patch)
        var wideOffsets = false, undo = false
        let blockSize = 1024
        switch version {
        case UInt8(ascii: "1"):
            r.offset = 56
        case UInt8(ascii: "2"):
            guard patch.count >= 60 + blockSize else { throw PatchError.truncated }
            r.offset = 56
            ppf.size = Int(r.u32())
            ppf.block = (0x9320, r.take(blockSize))
        case UInt8(ascii: "3"):
            guard patch.count >= 60 else { throw PatchError.truncated }
            let isGI = patch[56] == 1, checked = patch[57] != 0
            undo = patch[58] != 0
            wideOffsets = true
            r.offset = 60
            if checked {
                guard r.remaining >= blockSize else { throw PatchError.truncated }
                ppf.block = (isGI ? 0x80A0 : 0x9320, r.take(blockSize))
            }
        default:
            throw PatchError.unsupported
        }
        // An optional text file ends the patch; it is not a record.
        var end = patch.count
        let tail = max(r.offset, patch.count - 8192)..<patch.count
        if let begin = patch.range(of: Data("@BEGIN_FILE_ID.DIZ".utf8), options: .backwards, in: tail),
           patch.range(of: Data("@END_FILE_ID.DIZ".utf8), in: begin.upperBound..<patch.count) != nil {
            end = begin.lowerBound
        }
        while r.offset < end {
            guard end - r.offset >= (wideOffsets ? 9 : 5) else { throw PatchError.truncated }
            var offset = UInt64(r.u32())
            if wideOffsets { offset |= UInt64(r.u32()) << 32 }
            let length = Int(r.byte())
            guard end - r.offset >= length * (undo ? 2 : 1) else { throw PatchError.truncated }
            guard offset <= UInt64(maxOutput) else { throw PatchError.unsupported }
            ppf.records.append((Int(offset), r.take(length)))
            if undo { r.offset += length }
        }
        return ppf
    }

    private static func checkPPF(_ ppf: PPF, sourceSize: Int, read: (Int, Int) -> Data?) throws {
        if let size = ppf.size, size != sourceSize {
            throw PatchError.badChecksum(expected: "size \(size)", actual: "size \(sourceSize)")
        }
        if let block = ppf.block, read(block.offset, block.bytes.count) != block.bytes {
            throw PatchError.badChecksum(expected: "this patch's disc image", actual: "a different image")
        }
    }

    static func applyPPF(_ patch: Data, to source: Data) throws -> Data {
        let ppf = try parsePPF(patch)
        try checkPPF(ppf, sourceSize: source.count) { offset, count in
            offset + count <= source.count ? source.subdata(in: offset..<(offset + count)) : nil
        }
        var output = source
        for record in ppf.records { write(record.bytes, into: &output, at: record.offset) }
        return output
    }

    private static func applyPPF(_ patch: Data, toFile source: URL, writingTo dest: URL) throws {
        let ppf = try parsePPF(patch)
        let size = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int ?? 0
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        try checkPPF(ppf, sourceSize: size) { offset, count in
            guard (try? input.seek(toOffset: UInt64(offset))) != nil else { return nil }
            return try? input.read(upToCount: count)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        let output = try FileHandle(forWritingTo: dest)
        defer { try? output.close() }
        for record in ppf.records {
            try output.seek(toOffset: UInt64(record.offset))
            try output.write(contentsOf: record.bytes)
        }
    }

    // MARK: APS

    private static let apsBlock = 0x10000

    /// CRC-16/CCITT-FALSE, the block check of the GBA flavour.
    static func crc16(_ bytes: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 { crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1 }
        }
        return crc
    }

    private static func sized(_ source: Data, to size: Int) throws -> Data {
        guard size <= maxOutput else { throw PatchError.unsupported }
        var output = Data(count: size)
        let shared = min(size, source.count)
        output.replaceSubrange(0..<shared, with: source.prefix(shared))
        return output
    }

    static func applyAPSGBA(_ patch: Data, to source: Data) throws -> Data {
        let recordSize = 8 + apsBlock
        guard patch.count > 12, (patch.count - 12) % recordSize == 0 else { throw PatchError.truncated }
        var r = Reader(patch)
        r.offset = 4
        let sourceSize = Int(r.u32()), targetSize = Int(r.u32())
        guard source.count == sourceSize else {
            throw PatchError.badChecksum(expected: "size \(sourceSize)", actual: "size \(source.count)")
        }
        var output = try sized(source, to: targetSize)
        while !r.isEmpty {
            let offset = Int(r.u32())
            let sourceCRC = r.u16le(), targetCRC = r.u16le()
            let xor = r.take(apsBlock)
            guard offset + apsBlock <= max(sourceSize, targetSize) else { throw PatchError.truncated }
            var input = Data(count: apsBlock)
            if offset < source.count {
                let end = min(offset + apsBlock, source.count)
                input.replaceSubrange(0..<(end - offset), with: source.subdata(in: offset..<end))
            }
            guard crc16(input) == sourceCRC else {
                throw PatchError.badChecksum(expected: String(format: "%04X", sourceCRC), actual: String(format: "%04X", crc16(input)))
            }
            let block = Data(zip(input, xor).map { $0 ^ $1 })
            guard crc16(block) == targetCRC else {
                throw PatchError.badChecksum(expected: String(format: "%04X", targetCRC), actual: String(format: "%04X", crc16(block)))
            }
            if offset < targetSize {
                let end = min(offset + apsBlock, targetSize)
                output.replaceSubrange(offset..<end, with: block.prefix(end - offset))
            }
        }
        return output
    }

    static func applyAPSN64(_ patch: Data, to source: Data) throws -> Data {
        guard patch.count >= 61 else { throw PatchError.truncated }
        let isN64 = patch[5] == 1
        var r = Reader(patch)
        r.offset = 57
        if isN64 {
            guard patch.count >= 78 else { throw PatchError.truncated }
            let cartridge = patch.subdata(in: 58..<61), crc = patch.subdata(in: 61..<69)
            guard source.count >= 0x40, source.subdata(in: 0x3C..<0x3F) == cartridge, source.subdata(in: 0x10..<0x18) == crc else {
                throw PatchError.badChecksum(expected: "this patch's ROM", actual: "a different ROM")
            }
            r.offset = 74
        }
        let targetSize = Int(r.u32())
        var output = try sized(source, to: targetSize)
        while !r.isEmpty {
            guard r.remaining >= 5 else { throw PatchError.truncated }
            let offset = Int(r.u32())
            let length = Int(r.byte())
            let bytes: Data
            if length == 0 {
                guard r.remaining >= 2 else { throw PatchError.truncated }
                let value = r.byte()
                bytes = Data(repeating: value, count: Int(r.byte()))
            } else {
                guard r.remaining >= length else { throw PatchError.truncated }
                bytes = r.take(length)
            }
            guard offset + bytes.count <= targetSize else { throw PatchError.truncated }
            output.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
        }
        return output
    }

    // MARK: RUP (NINJA 2)

    /// Applies the file entry whose source MD5 is this ROM's. Undoing an already patched ROM is not offered.
    static func applyRUP(_ patch: Data, to source: Data) throws -> Data {
        let headerSize = 0x800
        guard patch.count > headerSize else { throw PatchError.truncated }
        var r = Reader(patch)
        r.offset = headerSize
        let sourceMD5 = Data(Insecure.MD5.hash(data: source))
        var output: Data?
        var expected: Data?
        var done = false
        commands: while true {
            guard r.remaining >= 1 else { throw PatchError.truncated }
            switch r.byte() {
            case 0: break commands
            case 1:
                if output != nil { done = true }
                let nameLength = try r.vlv()
                guard r.remaining >= nameLength + 1 else { throw PatchError.truncated }
                r.offset += nameLength + 1 // The name and the ROM type byte.
                let fileSize = try r.vlv(), targetSize = try r.vlv()
                guard r.remaining >= 32 else { throw PatchError.truncated }
                let fileMD5 = r.take(16), targetMD5 = r.take(16)
                var overflow = Data(), append = false
                if fileSize != targetSize {
                    guard r.remaining >= 1 else { throw PatchError.truncated }
                    let mode = r.byte()
                    guard mode == UInt8(ascii: "A") || mode == UInt8(ascii: "M") else { throw PatchError.unsupported }
                    append = mode == UInt8(ascii: "A")
                    let count = try r.vlv()
                    guard r.remaining >= count else { throw PatchError.truncated }
                    overflow = Data(r.take(count).map { $0 ^ 0xFF })
                }
                guard !done, fileMD5 == sourceMD5 else { output = done ? output : nil; continue commands }
                guard !append || fileSize + overflow.count <= targetSize, source.count == fileSize else { throw PatchError.truncated }
                var sizedOutput = try sized(source, to: targetSize)
                if append { sizedOutput.replaceSubrange(fileSize..<(fileSize + overflow.count), with: overflow) }
                output = sizedOutput
                expected = targetMD5
            case 2:
                let offset = try r.vlv(), length = try r.vlv()
                guard r.remaining >= length else { throw PatchError.truncated }
                let xor = r.take(length)
                guard !done, var target = output else { continue commands }
                output = nil // One owner, so writing does not copy the image for each record.
                for (index, value) in xor.enumerated() where offset + index < target.count {
                    let at = offset + index
                    target[at] = (at < source.count ? source[at] : 0) ^ value
                }
                output = target
            default:
                throw PatchError.unsupported
            }
        }
        guard let output, let expected else {
            throw PatchError.badChecksum(expected: "this patch's ROM", actual: "a different ROM")
        }
        let actual = Data(Insecure.MD5.hash(data: output))
        guard actual == expected else { throw PatchError.badChecksum(expected: hex(expected), actual: hex(actual)) }
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
        mutating func u16le() -> UInt16 { UInt16(byte()) | UInt16(byte()) << 8 }
        /// RUP's integer: a byte count, then that many little-endian bytes.
        mutating func vlv() throws -> Int {
            guard remaining >= 1 else { throw PatchError.truncated }
            let count = Int(byte())
            guard count <= 7, remaining >= count else { throw PatchError.truncated }
            var value = 0
            for index in 0..<count { value |= Int(byte()) << (8 * index) }
            guard value <= RomPatcher.maxOutput else { throw PatchError.unsupported }
            return value
        }
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
