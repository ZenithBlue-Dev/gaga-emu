import XCTest
import Compression
@testable import GagaEmu

/// VCDIFF windows written here, then decoded: every secondary compressor, the address caches and bad input.
final class XdeltaTests: GagaTestCase {
    private func varint(_ value: Int) -> [UInt8] {
        var bytes = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            bytes.insert(UInt8(rest & 0x7F) | 0x80, at: 0)
            rest >>= 7
        }
        return bytes
    }

    private enum Compressor: UInt8 { case fgk = 1, lzma = 2, djw = 16 }

    /// ADD, COPY (mode 0, source or target) and RUN, using the table's size-0 codes.
    private struct Program {
        var data = [UInt8](), instructions = [UInt8](), addresses = [UInt8]()
    }

    private func patch(windows: [(program: Program, source: (length: Int, position: Int)?, targetLength: Int, adler: UInt32?)], compressor: Compressor? = nil) -> Data {
        var out: [UInt8] = [0xD6, 0xC3, 0xC4, 0x00, compressor == nil ? 0 : 1]
        if let compressor { out.append(compressor.rawValue) }
        for window in windows {
            var indicator: UInt8 = window.source == nil ? 0 : 1
            if window.adler != nil { indicator |= 4 }
            out.append(indicator)
            if let source = window.source { out += varint(source.length) + varint(source.position) }
            let sections = [window.program.data, window.program.instructions, window.program.addresses].map { compress($0, compressor) }
            var delta = varint(window.targetLength) + [compressor == nil ? 0 : 7]
            delta += varint(sections[0].count) + varint(sections[1].count) + varint(sections[2].count)
            if let adler = window.adler { delta += [24, 16, 8, 0].map { UInt8(adler >> UInt32($0) & 0xFF) } }
            delta += sections[0] + sections[1] + sections[2]
            out += varint(delta.count) + delta
        }
        return Data(out)
    }

    private func compress(_ bytes: [UInt8], _ compressor: Compressor?) -> [UInt8] {
        guard let compressor else { return bytes }
        let body: [UInt8]
        switch compressor {
        case .lzma:
            var output = [UInt8](repeating: 0, count: bytes.count * 2 + 1024)
            let count = compression_encode_buffer(&output, output.count, bytes, bytes.count, nil, COMPRESSION_LZMA)
            body = Array(output[0..<count])
        case .fgk: body = fgkEncode(bytes)
        case .djw: body = djwEncode(bytes, groups: bytes.count > 30 ? 2 : 1)
        }
        return varint(bytes.count) + body
    }

    private func program(from source: [UInt8], to target: [UInt8]) -> Program {
        var result = Program()
        var index = 0
        while index < target.count {
            if index < source.count, index + 64 <= target.count, Array(source[index..<(index + 64)]) == Array(target[index..<(index + 64)]) {
                result.instructions += [19] + varint(64)
                result.addresses += varint(index)
                index += 64
            } else if index + 8 <= target.count, Set(target[index..<(index + 8)]).count == 1 {
                result.instructions += [0] + varint(8)
                result.data.append(target[index])
                index += 8
            } else {
                let count = min(40, target.count - index)
                result.instructions += [1] + varint(count)
                result.data += target[index..<(index + count)]
                index += count
            }
        }
        return result
    }

    private func sampleSource() -> [UInt8] { (0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 73 ^ ($0 >> 3)) } }

    private func sampleTarget(_ source: [UInt8]) -> [UInt8] {
        var target = source
        target.replaceSubrange(100..<140, with: [UInt8](repeating: 0x11, count: 40))
        target.replaceSubrange(2000..<2010, with: (0..<10).map { UInt8($0) })
        return target
    }

    func testCodeTableMatchesTheRFC() {
        let table = Xdelta.CodeTable.standard
        XCTAssertEqual(table.first[0].type, 2)
        XCTAssertEqual(table.first[18].size, 17)
        XCTAssertEqual(table.first[19].type, 3)
        XCTAssertEqual(table.first[19 + 16 * 8].mode, 8)
        XCTAssertEqual(table.first[163].size, 1)
        XCTAssertEqual(table.second[163].size, 4)
        XCTAssertEqual(table.first[234].size, 4)
        XCTAssertEqual(table.second[234].size, 6)
        XCTAssertEqual(table.second[234].mode, 5)
        XCTAssertEqual(table.second[235].mode, 6)
        XCTAssertEqual(table.first[247].type, 3)
        XCTAssertEqual(table.second[255].type, 1)
        XCTAssertEqual(table.first[255].mode, 8)
        XCTAssertEqual(Xdelta.CodeTable.standard.string.count, 1536)
    }

    func testRoundTripsEachCompressor() throws {
        let source = sampleSource(), target = sampleTarget(source)
        for compressor in [nil, Compressor.lzma, .djw, .fgk] {
            let made = patch(windows: [(program(from: source, to: target), (source.count, 0), target.count, Xdelta.adler32(target))], compressor: compressor)
            XCTAssertEqual(RomPatcher.format(of: made), .xdelta)
            XCTAssertEqual(Array(try RomPatcher.apply(made, to: Data(source))), target, "\(String(describing: compressor))")
        }
    }

    func testTwoWindowsAndAFile() throws {
        let source = sampleSource(), target = sampleTarget(source)
        let first = Array(target[0..<2048]), second = Array(target[2048...])
        let addressed = program(from: Array(source[2048...]), to: second) // Addresses are relative to the second segment.
        let made = patch(windows: [(program(from: source, to: first), (2048, 0), first.count, Xdelta.adler32(first)),
                                   (addressed, (2048, 2048), second.count, Xdelta.adler32(second))])
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (patchURL, sourceURL, dest) = (dir.appendingPathComponent("p"), dir.appendingPathComponent("s"), dir.appendingPathComponent("d"))
        try made.write(to: patchURL)
        try Data(source).write(to: sourceURL)
        let sums = try RomPatcher.apply(patch: patchURL, toSource: sourceURL, writingTo: dest)
        XCTAssertEqual(Array(try Data(contentsOf: dest)), target)
        XCTAssertEqual(sums.crc32, RomPatcher.crc32(Data(target)))
    }

    func testAddressCachesAndOverlappingCopy() throws {
        // Source "ABCDEFGH". COPY 4 from 0 (self), then near[0] + 4 (mode 2), then here - 2 running over itself (mode 1).
        let source = Array("ABCDEFGH".utf8)
        var code = Program()
        code.instructions = [19 + 0] + varint(4) + [19 + 16 * 2] + varint(4) + [19 + 16 * 1] + varint(6)
        code.addresses = varint(0) + varint(4) + varint(2) // here = 8 + 8 = 16, so 14.
        let made = patch(windows: [(code, (8, 0), 14, nil)])
        XCTAssertEqual(String(decoding: try Xdelta.apply(made, to: Data(source)), as: UTF8.self), "ABCDEFGHGHGHGH")
    }

    func testWrongSourceIsReported() {
        let source = sampleSource(), target = sampleTarget(source)
        let made = patch(windows: [(program(from: source, to: target), (source.count, 0), target.count, Xdelta.adler32(target))])
        var other = source
        other[5] ^= 0xFF
        XCTAssertThrowsError(try RomPatcher.apply(made, to: Data(other))) { XCTAssertEqual($0 as? RomPatcher.PatchError, .wrongSource) }
        XCTAssertThrowsError(try RomPatcher.apply(made, to: Data(source[0..<100]))) { XCTAssertEqual($0 as? RomPatcher.PatchError, .wrongSource) }
    }

    func testHeaderLimitsAreEnforced() {
        // A window asking for a 2 GiB target with an empty body.
        let huge = Data([0xD6, 0xC3, 0xC4, 0, 0, 0] + varint(4) + varint(1 << 31) + [0, 0, 0, 0])
        XCTAssertThrowsError(try RomPatcher.apply(huge, to: Data()))
        // A varint that never ends.
        XCTAssertThrowsError(try RomPatcher.apply(Data([0xD6, 0xC3, 0xC4, 0, 0, 0] + [UInt8](repeating: 0xFF, count: 12)), to: Data()))
        // A source segment past the end of the file.
        XCTAssertThrowsError(try RomPatcher.apply(Data([0xD6, 0xC3, 0xC4, 0, 0, 1, 0x7F, 0x7F, 4, 0, 0, 0, 0, 0]), to: Data()))
        // Unknown secondary compressor.
        let body: [UInt8] = [0xD6, 0xC3, 0xC4, 0, 1, 9, 0, 6, 1, 1, 1, 0, 0, 0xFF]
        XCTAssertThrowsError(try RomPatcher.apply(Data(body), to: Data()))
    }

    func testBadInputNeverCrashes() {
        let source = sampleSource(), target = sampleTarget(source)
        var generator = SeededBytes(seed: 0x1234_5678)
        for compressor in [nil, Compressor.lzma, .djw, .fgk] {
            let good = Array(patch(windows: [(program(from: source, to: target), (source.count, 0), target.count, nil)], compressor: compressor))
            for length in stride(from: 0, to: good.count, by: max(good.count / 200, 1)) {
                _ = try? Xdelta.apply(Data(good[0..<length]), to: Data(source))
            }
            for _ in 0..<400 {
                var bad = good
                for _ in 0...(generator.next() % 6) { bad[generator.next() % bad.count] = UInt8(generator.next() & 0xFF) }
                _ = try? Xdelta.apply(Data(bad), to: Data(source))
            }
        }
        for _ in 0..<400 {
            let body = (0..<(generator.next() % 600)).map { _ in UInt8(generator.next() & 0xFF) }
            let count = 1 + generator.next() % 4096
            _ = try? DJW.decode(body, count: count)
            _ = try? FGK().decode(body, count: count)
        }
    }

    // MARK: Encoders for the fixtures

    private struct SeededBytes {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int(state >> 33)
        }
    }

    private struct BitWriter {
        var bytes = [UInt8]()
        var used = 8
        mutating func put(_ bit: Int) {
            if used == 8 {
                bytes.append(0)
                used = 0
            }
            if bit != 0 { bytes[bytes.count - 1] |= 1 << UInt8(used) }
            used += 1
        }
        mutating func put(_ value: Int, bits: Int) {
            for shift in (0..<bits).reversed() { put(value >> shift & 1) }
        }
    }

    /// A tree the decoder builds too, so the encoder walks the same state.
    private func fgkEncode(_ input: [UInt8]) -> [UInt8] {
        let tree = FGK()
        var writer = BitWriter()
        for byte in input {
            var coded = [Int]()
            var target = Int(byte)
            if tree.nodes[target].weight == 0 {
                var position = 0, walk = tree.zeros
                while walk != target {
                    walk = tree.nodes[walk].rightChild
                    position += 1
                }
                var shift = 1
                for _ in 0..<tree.zeroBits {
                    coded.append(shift & position != 0 ? 1 : 0)
                    shift <<= 1
                }
                target = tree.zeros
            }
            while target != tree.root {
                let parent = tree.nodes[target].parent
                coded.append(tree.nodes[parent].rightChild == target ? 1 : 0)
                target = parent
            }
            try? tree.update(Int(byte))
            for bit in coded.reversed() { writer.put(bit) }
        }
        return writer.bytes
    }

    /// Every symbol at length 8 in every group, so the code is the byte itself. `groups` is 1 or 2.
    private func djwEncode(_ input: [UInt8], groups: Int) -> [UInt8] {
        var writer = BitWriter()
        writer.put(groups - 1, bits: 3)
        let sectorSize = 15
        if groups > 1 { writer.put(sectorSize / 5 - 1, bits: 5) }
        // The length code: symbol 0 (RUN_0), 1 (RUN_1), and 6 (MTF index 5, the value 8) at length 2.
        writer.put(0, bits: 4) // No extras past the 7 always sent.
        for symbol in 0..<7 { writer.put([0, 1, 6].contains(symbol) ? 2 : 0, bits: 4) }
        let codes = [0: 0, 1: 1, 6: 2]
        writer.put(codes[6]!, bits: 2) // The value 8 moves to the front. One symbol done.
        // Bijective base 2, least significant digit first: digit d at position s adds (d + 1) << s.
        var remaining = 256 * groups - 1
        while remaining > 0 {
            let symbol = remaining & 1 == 1 ? 0 : 1
            writer.put(codes[symbol]!, bits: 2)
            remaining = (remaining - symbol - 1) / 2
        }
        let sectors = groups > 1 ? 1 + (input.count - 1) / sectorSize : 1
        if groups > 1 {
            // Selector symbols 0, 1, 2 at length 2: sectors alternate between the two identical tables.
            for _ in 0...groups { writer.put(2, bits: 3) }
            writer.put(0, bits: 2) // RUN_0: the first sector uses group 0.
            for _ in 1..<max(sectors, 1) { writer.put(2, bits: 2) } // MTF index 1, symbol 2: the other group.
        }
        for byte in input { writer.put(Int(byte), bits: 8) }
        return writer.bytes
    }
}
