import Foundation
import Compression

/// xdelta patches: VCDIFF decoding from RFC 3284, plus xdelta3's secondary compressors (djw, fgk, lzma) written
/// from that project's format as published (Apache-2.0). A patch is untrusted: every size is checked before it is
/// used, and nothing here traps on bad input. Windows are written as they finish, so a disc image is never held whole.
enum Xdelta {
    typealias PatchError = RomPatcher.PatchError

    /// Largest target window. xdelta3 tops out at 16 MiB, so a patch asking for more than this is not real.
    static let maxWindow = 1 << 28

    static func isPatch(_ patch: Data) -> Bool { patch.starts(with: [0xD6, 0xC3, 0xC4, 0x00]) }

    static func apply(_ patch: Data, to source: Data) throws -> Data {
        var output = Data()
        try decode(patch, source: source, readTarget: { output.subdata(in: $0..<($0 + $1)) }, write: { output.append(contentsOf: $0) })
        return output
    }

    /// The source is mapped and the output goes straight to `dest`.
    static func apply(patch: Data, toFile source: URL, writingTo dest: URL) throws {
        let mapped = try Data(contentsOf: source, options: .alwaysMapped)
        guard FileManager.default.createFile(atPath: dest.path, contents: nil) else { throw PatchError.corrupt }
        let handle = try FileHandle(forUpdating: dest)
        defer { try? handle.close() }
        try decode(patch, source: mapped, readTarget: { offset, count in
            try handle.seek(toOffset: UInt64(offset))
            let data = try handle.read(upToCount: count) ?? Data()
            guard data.count == count else { throw PatchError.corrupt }
            return data
        }, write: { bytes in
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(bytes))
        })
    }

    static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0, index = 0
        while index < bytes.count {
            for byte in bytes[index..<min(index + 5552, bytes.count)] { a &+= UInt32(byte); b &+= a }
            index += 5552
            a %= 65521
            b %= 65521
        }
        return b << 16 | a
    }

    // MARK: VCDIFF

    private static func decode(_ patch: Data, source: Data, readTarget: (Int, Int) throws -> Data, write: ([UInt8]) throws -> Void) throws {
        var file = Cursor(Array(patch))
        guard isPatch(patch) else { throw PatchError.unknownFormat }
        file.position = 4
        let indicator = try file.byte()
        guard indicator & 0xF8 == 0 else { throw PatchError.corrupt }
        let compressor = indicator & 1 != 0 ? try file.byte() : nil
        var table = CodeTable.standard
        if indicator & 2 != 0 { table = try customTable(try file.take(file.varint())) }
        if indicator & 4 != 0 { _ = try file.take(file.varint()) }
        var written = 0
        while file.remaining > 0 {
            let target = try window(&file, compressor: compressor, table: table, source: source, written: written, readTarget: readTarget)
            written += target.count
            guard written <= RomPatcher.maxOutput else { throw PatchError.corrupt }
            try write(target)
        }
    }

    /// RFC 3284 section 7: the near and same sizes, then the table as a delta against the default table's string.
    private static func customTable(_ data: [UInt8]) throws -> CodeTable {
        guard data.count > 2 else { throw PatchError.corrupt }
        var decoded = [UInt8]()
        var nested = Cursor(Array(data[2...]))
        guard nested.remaining >= 5, Array(nested.bytes[0..<4]) == [0xD6, 0xC3, 0xC4, 0x00], nested.bytes[4] == 0 else { throw PatchError.corrupt }
        nested.position = 5
        let reference = Data(CodeTable.standard.string)
        while nested.remaining > 0 {
            decoded += try window(&nested, compressor: nil, table: .standard, source: reference, written: decoded.count, readTarget: { offset, count in
                Data(decoded[offset..<(offset + count)])
            })
            guard decoded.count <= 1536 else { throw PatchError.corrupt }
        }
        return try CodeTable(string: decoded, near: Int(data[0]), same: Int(data[1]))
    }

    private static func window(_ file: inout Cursor, compressor: UInt8?, table: CodeTable, source: Data, written: Int,
                               readTarget: (Int, Int) throws -> Data) throws -> [UInt8] {
        let indicator = try file.byte()
        guard indicator & 0xF8 == 0, indicator & 3 != 3 else { throw PatchError.corrupt }
        var segment = Data()
        if indicator & 3 != 0 {
            let length = try file.varint(), position = try file.varint()
            let (end, overflow) = position.addingReportingOverflow(length)
            guard !overflow else { throw PatchError.corrupt }
            if indicator & 1 != 0 {
                guard end <= source.count else { throw PatchError.wrongSource }
                segment = source[position..<end]
            } else {
                guard end <= written, length <= maxWindow else { throw PatchError.corrupt }
                segment = try readTarget(position, length)
            }
        }
        _ = try file.varint() // Length of the delta encoding: the three section lengths below are what is used.
        let targetLength = try file.varint()
        guard targetLength <= maxWindow else { throw PatchError.corrupt }
        let sections = try file.byte()
        guard sections & 0xF8 == 0, sections == 0 || compressor != nil else { throw PatchError.corrupt }
        let dataLength = try file.varint(), instructionLength = try file.varint(), addressLength = try file.varint()
        var expectedAdler: UInt32?
        if indicator & 4 != 0 { expectedAdler = try file.u32() }
        // A window's sections cannot usefully exceed these: each instruction makes at least one byte of output.
        let instructionLimit = targetLength * 10 + 16
        var data = Cursor(try section(try file.take(dataLength), compressed: sections & 1 != 0, compressor, limit: targetLength))
        var instructions = Cursor(try section(try file.take(instructionLength), compressed: sections & 2 != 0, compressor, limit: instructionLimit))
        var addresses = Cursor(try section(try file.take(addressLength), compressed: sections & 4 != 0, compressor, limit: instructionLimit))
        let target = try run(table, segment: segment, targetLength: targetLength, data: &data, instructions: &instructions, addresses: &addresses)
        if let expectedAdler, adler32(target) != expectedAdler { throw PatchError.wrongSource }
        return target
    }

    private static func run(_ table: CodeTable, segment: Data, targetLength: Int, data: inout Cursor, instructions: inout Cursor, addresses: inout Cursor) throws -> [UInt8] {
        var target = [UInt8](repeating: 0, count: targetLength)
        var length = 0
        var near = [Int](repeating: 0, count: table.near), nextNear = 0
        var same = [Int](repeating: 0, count: table.same * 256)
        let segmentCount = segment.count
        try segment.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            while instructions.remaining > 0 {
                let code = Int(try instructions.byte())
                for half in 0..<2 {
                    let entry = half == 0 ? table.first[code] : table.second[code]
                    guard entry.type != 0 else { continue }
                    let size = entry.size != 0 ? Int(entry.size) : try instructions.varint()
                    guard size <= targetLength - length else { throw PatchError.corrupt }
                    switch entry.type {
                    case 1:
                        let added = try data.take(size)
                        target.replaceSubrange(length..<(length + size), with: added)
                    case 2:
                        let byte = try data.byte()
                        for index in length..<(length + size) { target[index] = byte }
                    default:
                        let here = segmentCount + length
                        let address = try decodeAddress(Int(entry.mode), here: here, near: near, same: same, table: table, addresses: &addresses)
                        guard address < here else { throw PatchError.corrupt }
                        if table.near > 0 {
                            near[nextNear] = address
                            nextNear = (nextNear + 1) % table.near
                        }
                        if table.same > 0 { same[address % same.count] = address }
                        // Byte by byte: a copy may run past where it started writing, repeating what it wrote.
                        for offset in 0..<size {
                            let from = address + offset
                            target[length + offset] = from < segmentCount ? bytes[from] : target[from - segmentCount]
                        }
                    }
                    length += size
                }
            }
        }
        guard length == targetLength else { throw PatchError.corrupt }
        return target
    }

    private static func decodeAddress(_ mode: Int, here: Int, near: [Int], same: [Int], table: CodeTable, addresses: inout Cursor) throws -> Int {
        let address: Int
        switch mode {
        case 0: address = try addresses.varint()
        case 1: address = here - (try addresses.varint())
        case 2..<(2 + table.near): address = near[mode - 2] &+ (try addresses.varint())
        case (2 + table.near)..<(2 + table.near + table.same):
            address = same[(mode - 2 - table.near) * 256 + Int(try addresses.byte())]
        default: throw PatchError.corrupt
        }
        guard address >= 0 else { throw PatchError.corrupt }
        return address
    }

    private static func section(_ raw: [UInt8], compressed: Bool, _ compressor: UInt8?, limit: Int) throws -> [UInt8] {
        guard compressed else { return raw }
        var cursor = Cursor(raw)
        let size = try cursor.varint()
        guard size > 0, size <= limit else { throw PatchError.corrupt }
        let body = Array(raw[cursor.position...])
        switch compressor {
        case 1: return try FGK().decode(body, count: size)
        case 2: return try lzma(body, count: size)
        case 16: return try DJW.decode(body, count: size)
        default: throw PatchError.unsupported
        }
    }

    /// xdelta3 writes an XZ stream with no integrity check, which the system decoder reads.
    private static func lzma(_ body: [UInt8], count: Int) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: count)
        let decoded = compression_decode_buffer(&output, count, body, body.count, nil, COMPRESSION_LZMA)
        guard decoded == count else { throw PatchError.corrupt }
        return output
    }

    // MARK: Code table

    struct CodeTable {
        struct Entry { var type: UInt8 = 0, size: UInt8 = 0, mode: UInt8 = 0 }
        var first: [Entry]
        var second: [Entry]
        var near = 4
        var same = 3

        /// RFC 3284 section 5.6.
        static let standard: CodeTable = {
            var table = CodeTable(first: Array(repeating: Entry(), count: 256), second: Array(repeating: Entry(), count: 256))
            let run: UInt8 = 2, add: UInt8 = 1, copy: UInt8 = 3
            var code = 0
            func put(_ a: Entry, _ b: Entry = Entry()) {
                table.first[code] = a
                table.second[code] = b
                code += 1
            }
            put(Entry(type: run))
            for size in 0...17 { put(Entry(type: add, size: UInt8(size))) }
            for mode in 0...8 {
                put(Entry(type: copy, size: 0, mode: UInt8(mode)))
                for size in 4...18 { put(Entry(type: copy, size: UInt8(size), mode: UInt8(mode))) }
            }
            for mode in 0...5 {
                for addSize in 1...4 {
                    for copySize in 4...6 { put(Entry(type: add, size: UInt8(addSize)), Entry(type: copy, size: UInt8(copySize), mode: UInt8(mode))) }
                }
            }
            for mode in 6...8 {
                for addSize in 1...4 { put(Entry(type: add, size: UInt8(addSize)), Entry(type: copy, size: 4, mode: UInt8(mode))) }
            }
            for mode in 0...8 { put(Entry(type: copy, size: 4, mode: UInt8(mode)), Entry(type: add, size: 1)) }
            return table
        }()

        init(first: [Entry], second: [Entry]) {
            self.first = first
            self.second = second
        }

        init(string: [UInt8], near: Int, same: Int) throws {
            guard string.count == 1536 else { throw PatchError.corrupt }
            first = (0..<256).map { Entry(type: string[$0], size: string[512 + $0], mode: string[1024 + $0]) }
            second = (0..<256).map { Entry(type: string[256 + $0], size: string[768 + $0], mode: string[1280 + $0]) }
            self.near = near
            self.same = same
            guard (first + second).allSatisfy({ $0.type <= 3 }) else { throw PatchError.corrupt }
        }

        var string: [UInt8] {
            first.map(\.type) + second.map(\.type) + first.map(\.size) + second.map(\.size) + first.map(\.mode) + second.map(\.mode)
        }
    }

    struct Cursor {
        let bytes: [UInt8]
        var position = 0

        init(_ bytes: [UInt8]) { self.bytes = bytes }

        var remaining: Int { bytes.count - position }

        mutating func byte() throws -> UInt8 {
            guard position < bytes.count else { throw PatchError.truncated }
            defer { position += 1 }
            return bytes[position]
        }

        mutating func take(_ count: Int) throws -> [UInt8] {
            guard count >= 0, count <= remaining else { throw PatchError.truncated }
            defer { position += count }
            return Array(bytes[position..<(position + count)])
        }

        mutating func u32() throws -> UInt32 {
            var value: UInt32 = 0
            for _ in 0..<4 { value = value << 8 | UInt32(try byte()) }
            return value
        }

        /// Seven bits a byte, most significant first. Never negative.
        mutating func varint() throws -> Int {
            var value = 0
            for _ in 0..<9 {
                let next = try byte()
                value = value << 7 | Int(next & 0x7F)
                if next & 0x80 == 0 { return value }
            }
            throw PatchError.corrupt
        }
    }
}

// MARK: - Bits, least significant first within each byte

struct XdeltaBits {
    private let bytes: [UInt8]
    private var position = 0
    private var current: UInt8 = 0
    private var mask: UInt16 = 0x100

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func bit() throws -> Int {
        if mask == 0x100 {
            guard position < bytes.count else { throw RomPatcher.PatchError.truncated }
            current = bytes[position]
            position += 1
            mask = 1
        }
        defer { mask <<= 1 }
        return UInt16(current) & mask != 0 ? 1 : 0
    }

    mutating func bits(_ count: Int) throws -> Int {
        var value = 0
        for _ in 0..<count { value = value << 1 | (try bit()) }
        return value
    }
}

// MARK: - DJW: semi-adaptive Huffman with code-length tables, as xdelta3 writes it

enum DJW {
    private static let maxCodeLength = 20, totalCodes = 22, maxLengthLength = 15, maxSelectorLength = 7

    struct Prefix {
        var inorder: [UInt8]
        var base: [Int]
        var limit: [Int]
        var minimum: Int
        var maximum: Int

        init(lengths: ArraySlice<UInt8>, maxLength: Int) throws {
            var counts = [Int](repeating: 0, count: maxLength + 2)
            for length in lengths {
                guard Int(length) <= maxLength else { throw RomPatcher.PatchError.corrupt }
                counts[Int(length)] += 1
            }
            guard let low = (1...maxLength).first(where: { counts[$0] != 0 }),
                  let high = (1...maxLength).last(where: { counts[$0] != 0 }) else { throw RomPatcher.PatchError.corrupt }
            minimum = low
            maximum = high
            base = [Int](repeating: 0, count: maxLength + 2)
            limit = [Int](repeating: -1, count: maxLength + 2)
            var next = [Int](repeating: 0, count: maxLength + 2)
            limit[low] = counts[low] - 1
            if low < high {
                for length in (low + 1)...high {
                    let last = (limit[length - 1] + 1) << 1
                    next[length] = next[length - 1] + counts[length - 1]
                    limit[length] = last + counts[length] - 1
                    base[length] = last - next[length]
                }
            }
            inorder = [UInt8](repeating: 0, count: lengths.count)
            for (symbol, length) in lengths.enumerated() where length != 0 {
                inorder[next[Int(length)]] = UInt8(symbol)
                next[Int(length)] += 1
            }
        }

        func symbol(_ bits: inout XdeltaBits) throws -> Int {
            var code = 0
            for length in 1...maximum {
                code = code << 1 | (try bits.bit())
                if length >= minimum, code <= limit[length] {
                    let offset = code - base[length]
                    guard offset >= 0, offset < inorder.count else { throw RomPatcher.PatchError.corrupt }
                    return Int(inorder[offset])
                }
            }
            throw RomPatcher.PatchError.corrupt
        }
    }

    /// `skip` is the distance to the previous table: a symbol that table left out stays out.
    private static func decodeMTF(_ bits: inout XdeltaBits, prefix: Prefix, mtf: inout [UInt8], count: Int, skip: Int, into values: inout [UInt8]) throws {
        var index = 0, repeats = 0, pending = 0, shift = 0
        while index < count {
            if skip != 0, index >= skip, values[index - skip] == 0 {
                index += 1
            } else if repeats != 0 {
                values[index] = mtf[0]
                index += 1
                repeats -= 1
            } else if pending != 0 {
                guard pending < mtf.count else { throw RomPatcher.PatchError.corrupt }
                let symbol = mtf.remove(at: pending)
                mtf.insert(symbol, at: 0)
                values[index] = symbol
                index += 1
                pending = 0
            } else {
                let symbol = try prefix.symbol(&bits)
                if symbol <= 1 {
                    guard shift < 31 else { throw RomPatcher.PatchError.corrupt }
                    repeats = (symbol + 1) << shift
                    shift += 1
                } else {
                    pending = symbol - 1
                    shift = 0
                }
            }
        }
        guard repeats == 0 else { throw RomPatcher.PatchError.corrupt }
    }

    static func decode(_ body: [UInt8], count: Int) throws -> [UInt8] {
        var bits = XdeltaBits(body)
        let groups = try bits.bits(3) + 1
        let sectorSize = groups > 1 ? (try bits.bits(5) + 1) * 5 : count
        let sectors = 1 + (count - 1) / sectorSize

        var lengthLengths = [UInt8](repeating: 0, count: totalCodes)
        let coded = try bits.bits(4) + 7
        for index in 0..<coded { lengthLengths[index] = UInt8(try bits.bits(4)) }
        let lengthPrefix = try Prefix(lengths: lengthLengths[...], maxLength: maxLengthLength)
        var lengthMTF: [UInt8] = [0, 4, 5, 6, 7, 8, 9, 10, 3, 11, 2, 12, 13, 1, 14, 15, 16, 17, 18, 19, 20]

        var lengths = [UInt8](repeating: 0, count: groups * 256)
        try decodeMTF(&bits, prefix: lengthPrefix, mtf: &lengthMTF, count: groups * 256, skip: 256, into: &lengths)
        var tables = [Prefix]()
        for group in 0..<groups { tables.append(try Prefix(lengths: lengths[(group * 256)..<((group + 1) * 256)], maxLength: maxCodeLength)) }

        var selectors = [UInt8](repeating: 0, count: sectors)
        if groups > 1 {
            var selectorLengths = [UInt8](repeating: 0, count: groups + 1)
            for index in 0...groups { selectorLengths[index] = UInt8(try bits.bits(3)) }
            let selectorPrefix = try Prefix(lengths: selectorLengths[...], maxLength: maxSelectorLength)
            var selectorMTF = (0...groups).map { UInt8($0) }
            try decodeMTF(&bits, prefix: selectorPrefix, mtf: &selectorMTF, count: sectors, skip: 0, into: &selectors)
        }

        var output = [UInt8]()
        output.reserveCapacity(count)
        for sector in 0..<sectors {
            guard Int(selectors[sector]) < groups else { throw RomPatcher.PatchError.corrupt }
            let table = tables[Int(selectors[sector])]
            for _ in 0..<min(sectorSize, count - output.count) { output.append(UInt8(try table.symbol(&bits))) }
        }
        return output
    }
}

// MARK: - FGK: adaptive Huffman, as xdelta3 writes it

/// Nodes are indexes into arrays; -1 is none. Symbols are the first 256 nodes.
final class FGK {
    private static let alphabet = 256, totalNodes = 511, totalBlocks = 1022

    struct Node {
        var weight: UInt32 = 0
        var parent = -1, leftChild = -1, rightChild = -1, left = -1, right = -1, block = -1
    }

    var nodes = [Node](repeating: Node(), count: FGK.totalNodes)
    private var leaders = [Int](repeating: -1, count: FGK.totalBlocks)
    private var freeBlocks: [Int] = Array((0..<FGK.totalBlocks).reversed())
    var root = 0
    private var freeNode = FGK.alphabet
    var zeros = 0
    private var zeroCount = FGK.alphabet + 2
    private var zeroExponent = 0, zeroRemainder = 0
    private var cursor = 0
    private var coded = [Int]()

    init() {
        factorRemaining()
        factorRemaining()
        for index in 0..<Self.alphabet {
            nodes[index].rightChild = index < Self.alphabet - 1 ? index + 1 : -1
            nodes[index].leftChild = index >= 1 ? index - 1 : -1
        }
    }

    var zeroBits: Int { zeroRemainder == 0 ? zeroExponent : zeroExponent + 1 }

    private func factorRemaining() {
        zeroCount -= 1
        var value = zeroCount
        zeroExponent = 0
        while value > 1 {
            zeroExponent += 1
            value >>= 1
        }
        zeroRemainder = zeroCount - (1 << zeroExponent)
    }

    private func makeBlock(_ leader: Int) throws -> Int {
        guard let block = freeBlocks.popLast() else { throw RomPatcher.PatchError.corrupt }
        leaders[block] = leader
        return block
    }

    func decode(_ body: [UInt8], count: Int) throws -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        for byte in body {
            for shift in 0..<8 {
                guard try decodeBit(Int(byte >> UInt8(shift)) & 1) else { continue }
                output.append(UInt8(try decodeData()))
                if output.count == count { return output }
            }
        }
        throw RomPatcher.PatchError.truncated
    }

    private func decodeBit(_ bit: Int) throws -> Bool {
        if nodes[cursor].weight == 0 {
            coded.append(bit)
            return coded.count >= zeroBits
        }
        let next = bit == 1 ? nodes[cursor].rightChild : nodes[cursor].leftChild
        guard next >= 0 else { throw RomPatcher.PatchError.corrupt }
        cursor = next
        if nodes[cursor].leftChild == -1 {
            return nodes[cursor].weight != 0 || zeroCount == 1
        }
        return false
    }

    private func decodeData() throws -> Int {
        var symbol = cursor
        if nodes[cursor].weight == 0 {
            var position = 0
            for value in coded { position = position << 1 | value }
            symbol = zeros
            while position != 0, nodes[symbol].rightChild != -1 {
                symbol = nodes[symbol].rightChild
                position -= 1
            }
        }
        coded = []
        try update(symbol)
        cursor = root
        return symbol
    }

    func update(_ symbol: Int) throws {
        var node = nodes[symbol].weight == 0 ? try increaseZero(symbol) : symbol
        while node != root {
            moveRight(node)
            try promote(node)
            nodes[node].weight += 1
            node = nodes[node].parent
        }
        nodes[root].weight += 1
    }

    private func moveRight(_ forward: Int) {
        let back = leaders[nodes[forward].block]
        guard forward != back, nodes[forward].parent != back, nodes[forward].weight != 0 else { return }
        nodes[nodes[back].right].left = forward
        if nodes[forward].left != -1 { nodes[nodes[forward].left].right = back }
        var hold = nodes[forward].right
        nodes[forward].right = nodes[back].right
        if hold == back {
            nodes[back].right = forward
        } else {
            nodes[hold].left = back
            nodes[back].right = hold
        }
        hold = nodes[back].left
        nodes[back].left = nodes[forward].left
        if hold == forward {
            nodes[forward].left = back
        } else {
            nodes[hold].right = forward
            nodes[forward].left = hold
        }
        let forwardParent = nodes[forward].parent, backParent = nodes[back].parent
        let forwardIsRight = nodes[forwardParent].rightChild == forward
        let backIsRight = nodes[backParent].rightChild == back
        nodes[forward].parent = backParent
        nodes[back].parent = forwardParent
        if forwardIsRight { nodes[forwardParent].rightChild = back } else { nodes[forwardParent].leftChild = back }
        if backIsRight { nodes[backParent].rightChild = forward } else { nodes[backParent].leftChild = forward }
        leaders[nodes[forward].block] = forward
    }

    private func promote(_ node: Int) throws {
        let right = nodes[node].right, left = nodes[node].left, block = nodes[node].block
        guard nodes[node].weight != 0 else { return }
        if left == nodes[node].rightChild, nodes[node].leftChild != -1, nodes[nodes[node].leftChild].weight == 0 {
            if nodes[node].weight == nodes[right].weight &- 1, right != root {
                freeBlocks.append(block)
                nodes[node].block = nodes[right].block
                nodes[left].block = nodes[right].block
            }
            return
        }
        if left == zeros { return }
        if left != -1, nodes[left].block == block {
            leaders[block] = left
        } else {
            freeBlocks.append(block)
        }
        if nodes[node].weight == nodes[right].weight &- 1, right != root {
            nodes[node].block = nodes[right].block
        } else {
            nodes[node].block = try makeBlock(node)
        }
    }

    private func increaseZero(_ symbol: Int) throws -> Int {
        if zeroCount == 1 {
            nodes[symbol].rightChild = -1
            if nodes[nodes[symbol].right].weight == 1 {
                nodes[symbol].block = nodes[nodes[symbol].right].block
            } else {
                nodes[symbol].block = try makeBlock(symbol)
            }
            zeros = -1
            return symbol
        }
        let zero = zeros
        guard freeNode < Self.totalNodes else { throw RomPatcher.PatchError.corrupt }
        let inner = freeNode
        freeNode += 1
        nodes[inner].parent = nodes[zero].parent
        nodes[inner].right = nodes[zero].right
        nodes[inner].weight = 0
        nodes[inner].rightChild = symbol
        nodes[inner].left = symbol
        if zero == root {
            root = inner
            nodes[symbol].block = try makeBlock(symbol)
            nodes[inner].block = try makeBlock(inner)
        } else {
            nodes[nodes[inner].right].left = inner
            let parent = nodes[zero].parent
            if nodes[parent].rightChild == zero { nodes[parent].rightChild = inner } else { nodes[parent].leftChild = inner }
            if nodes[nodes[inner].right].weight == 1 {
                nodes[inner].block = nodes[nodes[inner].right].block
            } else {
                nodes[inner].block = try makeBlock(inner)
            }
            nodes[symbol].block = nodes[inner].block
        }
        eliminateZero(symbol)
        nodes[inner].leftChild = zeros
        nodes[symbol].right = inner
        nodes[symbol].left = zeros
        nodes[symbol].parent = inner
        nodes[symbol].leftChild = -1
        nodes[symbol].rightChild = -1
        nodes[zeros].parent = inner
        nodes[zeros].right = symbol
        return symbol
    }

    private func eliminateZero(_ node: Int) {
        guard zeroCount != 1 else { return }
        factorRemaining()
        if nodes[node].leftChild == -1 {
            zeros = nodes[zeros].rightChild
            nodes[zeros].leftChild = -1
        } else if nodes[node].rightChild == -1 {
            nodes[nodes[node].leftChild].rightChild = -1
        } else {
            nodes[nodes[node].rightChild].leftChild = nodes[node].leftChild
            nodes[nodes[node].leftChild].rightChild = nodes[node].rightChild
        }
    }
}
