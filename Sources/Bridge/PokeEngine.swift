import Foundation

/// Raw RAM cheats for cores with no cheat handler of their own: writes, or conditional writes, after every frame on
/// the core's queue. Addresses are checked against the core's memory on every write (`docs/06`).
struct PokeEngine {
    /// One `AAAAAAAA:VV` or `AAAAAAAA?CC:VV` line. 2, 4 or 8 value digits write 1, 2 or 4 bytes, low byte first as
    /// RetroArch does, so the libretro `.cht` values land as they were found.
    struct Code: Equatable {
        var address: UInt64
        var value: UInt32
        var compare: UInt32?
        var width: Int
    }

    private struct Cheat {
        var id: UInt32
        var codes: [Code]
        var enabled: Bool
    }

    private var cheats: [Cheat] = []

    /// Where one core's codes point. nil: the core has its own handler, or exposes no writable memory.
    /// Virtual Boy codes carry the console's 0x05000000 work RAM address. The rest are offsets into system RAM.
    static func base(coreID: String) -> UInt64? {
        switch coreID {
        case "beetle_vb": 0x0500_0000
        case "handy", "atari800", "prosystem", "stella", "beetle_ngp", "virtualjaguar", "flycast", "pokemini", "vice", "puae": 0
        default: nil
        }
    }

    static let hint = "Raw RAM AAAA:VV, or AAAA?CC:VV to write only when the byte is CC. One per line."

    static func parse(_ text: String) -> [Code]? {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let codes = lines.compactMap(parseLine)
        return codes.count == lines.count && !codes.isEmpty ? codes : nil
    }

    private static func parseLine(_ line: String) -> Code? {
        let halves = line.split(separator: ":", omittingEmptySubsequences: false)
        guard halves.count == 2, [2, 4, 8].contains(halves[1].count), halves[1].allSatisfy(\.isHexDigit),
              let value = UInt32(halves[1], radix: 16) else { return nil }
        let left = halves[0].split(separator: "?", omittingEmptySubsequences: false)
        guard left.count <= 2, left[0].count <= 16, !left[0].isEmpty, left[0].allSatisfy(\.isHexDigit),
              let address = UInt64(left[0], radix: 16) else { return nil }
        var compare: UInt32?
        if left.count == 2 {
            guard left[1].count == halves[1].count, left[1].allSatisfy(\.isHexDigit), let parsed = UInt32(left[1], radix: 16) else { return nil }
            compare = parsed
        }
        return Code(address: address, value: value, compare: compare, width: halves[1].count / 2)
    }

    var hasEnabled: Bool { cheats.contains(where: \.enabled) }

    mutating func set(id: UInt32, codes: [Code], enabled: Bool) {
        remove(id: id)
        cheats.append(Cheat(id: id, codes: codes, enabled: enabled))
    }

    mutating func remove(id: UInt32) { cheats.removeAll { $0.id == id } }

    mutating func setEnabled(id: UInt32, _ enabled: Bool) {
        if let index = cheats.firstIndex(where: { $0.id == id }) { cheats[index].enabled = enabled }
    }

    static func fits(_ code: Code, in regions: [GagaPokeRegion]) -> Bool { span(code, regions) != nil }

    private static func span(_ code: Code, _ regions: [GagaPokeRegion]) -> UnsafeMutablePointer<UInt8>? {
        for region in regions where code.address >= region.start {
            let offset = code.address - region.start
            // Subtracting from the length cannot wrap, unlike adding the width to the address.
            if offset < region.length, region.length - offset >= UInt64(code.width) { return region.data + Int(offset) }
        }
        return nil
    }

    func apply(to regions: [GagaPokeRegion]) {
        for cheat in cheats where cheat.enabled {
            for code in cheat.codes {
                guard let bytes = Self.span(code, regions) else { continue }
                if let compare = code.compare {
                    var current: UInt32 = 0
                    for index in 0..<code.width { current |= UInt32(bytes[index]) << (8 * UInt32(index)) }
                    guard current == compare else { continue }
                }
                for index in 0..<code.width { bytes[index] = UInt8(truncatingIfNeeded: code.value >> (8 * UInt32(index))) }
            }
        }
    }
}
