import CryptoKit
import XCTest
@testable import GagaEmu

/// The patch formats, shelf options, picked accents and BIOS row import of the first Manic parity batch.
final class Manic1Tests: XCTestCase {
    private func le32(_ value: Int) -> [UInt8] { (0..<4).map { UInt8(value >> (8 * $0) & 0xFF) } }
    private func header(_ magic: String, to size: Int) -> Data {
        var data = Data(magic.utf8)
        data.append(Data(count: size - data.count))
        return data
    }

    // MARK: PPF

    func testPPF1WritesRecords() throws {
        var patch = header("PPF10", to: 56)
        patch.append(contentsOf: le32(2) + [2, 0xAA, 0xBB])
        XCTAssertEqual(try RomPatcher.apply(patch, to: Data([1, 2, 3, 4])), Data([1, 2, 0xAA, 0xBB]))
    }

    func testPPF3SkipsUndoDataAndTrailerAndChecksTheBlock() throws {
        var source = Data(count: 0x9320 + 1024 + 4)
        source[0x9320] = 7
        var patch = header("PPF30", to: 60)
        patch[57] = 1 // Block check on.
        patch[58] = 1 // Undo data present.
        patch.append(source.subdata(in: 0x9320..<(0x9320 + 1024)))
        patch.append(contentsOf: le32(1) + le32(0) + [1, 0xEE, 0x00])
        patch.append(Data("@BEGIN_FILE_ID.DIZhello@END_FILE_ID.DIZ".utf8))
        patch.append(contentsOf: le32(5))
        let output = try RomPatcher.apply(patch, to: source)
        XCTAssertEqual(output[1], 0xEE)
        XCTAssertEqual(output.count, source.count)

        var other = source
        other[0x9320] = 8
        XCTAssertThrowsError(try RomPatcher.apply(patch, to: other))
    }

    func testPPFFileRouteMatchesTheInMemoryOneAndLeavesTheSource() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ppf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = Data([1, 2, 3, 4]), sourceURL = folder.appendingPathComponent("rom.bin")
        var patch = header("PPF10", to: 56)
        patch.append(contentsOf: le32(3) + [2, 9, 9]) // Writes one byte past the end.
        let patchURL = folder.appendingPathComponent("p.ppf"), dest = folder.appendingPathComponent("out.bin")
        try source.write(to: sourceURL)
        try patch.write(to: patchURL)
        let sums = try RomPatcher.apply(patch: patchURL, toSource: sourceURL, writingTo: dest)
        let expected = try RomPatcher.apply(patch, to: source)
        XCTAssertEqual(try Data(contentsOf: dest), expected)
        XCTAssertEqual(sums, RomPatcher.checksums(expected))
        XCTAssertEqual(try Data(contentsOf: sourceURL), source)
    }

    // MARK: APS

    func testAPSGBA() throws {
        let block = 0x10000
        let source = Data(count: block)
        var target = source
        target[3] = 0x5A
        var patch = Data("APS1".utf8)
        patch.append(contentsOf: le32(block) + le32(block) + le32(0))
        for crc in [RomPatcher.crc16(source), RomPatcher.crc16(target)] {
            patch.append(contentsOf: [UInt8(crc & 0xFF), UInt8(crc >> 8)])
        }
        patch.append(target) // XOR against an all-zero source is the target itself.
        XCTAssertEqual(try RomPatcher.apply(patch, to: source), target)
        var wrong = source
        wrong[0] = 1
        XCTAssertThrowsError(try RomPatcher.apply(patch, to: wrong))
    }

    func testCRC16IsCCITTFalse() {
        XCTAssertEqual(RomPatcher.crc16(Data("123456789".utf8)), 0x29B1)
    }

    func testAPSN64WithRLEAndGrowth() throws {
        var source = Data(count: 0x40)
        source[0x3C] = 0x41
        source[0x10] = 0x77
        var patch = header("APS10", to: 57)
        patch[5] = 1
        patch.append(Data(count: 74 - 57)) // Format, cartridge, CRC and padding.
        patch[58] = 0x41
        patch[61] = 0x77
        patch.append(contentsOf: le32(0x42))
        patch.append(contentsOf: le32(0) + [1, 0xC3])
        patch.append(contentsOf: le32(0x40) + [0, 0xBE, 2])
        let output = try RomPatcher.apply(patch, to: source)
        XCTAssertEqual(output.count, 0x42)
        XCTAssertEqual(output[0], 0xC3)
        XCTAssertEqual(output.suffix(2), Data([0xBE, 0xBE]))

        var other = source
        other[0x3C] = 0
        XCTAssertThrowsError(try RomPatcher.apply(patch, to: other))
    }

    // MARK: RUP

    private func vlv(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = [], rest = value
        while rest > 0 { bytes.append(UInt8(rest & 0xFF)); rest >>= 8 }
        return [UInt8(bytes.count)] + bytes
    }

    private func rup(source: Data, target: Data, overflow: (mode: Character, bytes: [UInt8])?, xor: (Int, [UInt8])) -> Data {
        var patch = header("NINJA2", to: 0x800)
        patch.append(contentsOf: [1] + vlv(1) + [0x61] + [0] + vlv(source.count) + vlv(target.count))
        patch.append(Data(Insecure.MD5.hash(data: source)))
        patch.append(Data(Insecure.MD5.hash(data: target)))
        if let overflow {
            patch.append(overflow.mode.asciiValue!)
            patch.append(contentsOf: vlv(overflow.bytes.count) + overflow.bytes.map { $0 ^ 0xFF })
        }
        patch.append(contentsOf: [2] + vlv(xor.0) + vlv(xor.1.count) + xor.1 + [0])
        return patch
    }

    func testRUPAppendsAndChecksMD5() throws {
        let source = Data([1, 2, 3]), target = Data([1, 0, 3, 9, 8])
        let patch = rup(source: source, target: target, overflow: ("A", [9, 8]), xor: (1, [2]))
        XCTAssertEqual(try RomPatcher.apply(patch, to: source), target)
        XCTAssertThrowsError(try RomPatcher.apply(patch, to: Data([1, 2, 4])))
    }

    func testRUPMinifies() throws {
        let source = Data([1, 2, 3, 4]), target = Data([0, 2])
        let patch = rup(source: source, target: target, overflow: ("M", [3, 4]), xor: (0, [1]))
        XCTAssertEqual(try RomPatcher.apply(patch, to: source), target)
    }

    func testTruncatedPatchesThrowAndDoNotTrap() {
        let source = Data(count: 0x40)
        var ppf = header("PPF10", to: 56)
        ppf.append(contentsOf: le32(1) + [200, 1])
        let cut = header("APS10", to: 60)
        var ninja = header("NINJA2", to: 0x800)
        ninja.append(contentsOf: [1, 8])
        var aps = header("APS10", to: 57)
        aps.append(contentsOf: le32(0x40) + le32(0) + [9, 1])
        for patch in [ppf, cut, ninja, aps, Data("PPF10".utf8), Data("APS1".utf8)] {
            XCTAssertThrowsError(try RomPatcher.apply(patch, to: source))
        }
    }

    // MARK: Library display

    private func game(_ title: String, played: TimeInterval, last: Date? = nil) -> GameItem {
        GameItem(id: UUID(), title: title, platformID: "gba", romPath: title, coverPath: nil, coreOverride: nil,
                 playTime: played, lastPlayed: last, isFavorite: false, shaderID: "original")
    }

    func testSortFieldsAndOrder() {
        let games = [game("Game 10", played: 5, last: Date(timeIntervalSince1970: 200)),
                     game("Game 2", played: 9),
                     game("Alpha", played: 1, last: Date(timeIntervalSince1970: 300))]
        var display = LibraryDisplay()
        XCTAssertEqual(display.sorted(games).map(\.title), ["Game 10", "Game 2", "Alpha"], "the default keeps the Library's order")
        display.sort = .title
        XCTAssertEqual(display.sorted(games).map(\.title), ["Alpha", "Game 2", "Game 10"])
        display.descending = true
        XCTAssertEqual(display.sorted(games).map(\.title), ["Game 10", "Game 2", "Alpha"])
        display.sort = .played
        XCTAssertEqual(display.sorted(games).first?.title, "Alpha")
        display.sort = .time
        XCTAssertEqual(display.sorted(games).first?.title, "Game 2")
    }

    func testDisplaySurvivesAStateFileRoundTrip() throws {
        var display = LibraryDisplay()
        display.perRow = 4
        display.coverStyle = .framed
        display.groupStyle = .maker
        let data = try JSONEncoder().encode(display)
        XCTAssertEqual(try JSONDecoder().decode(LibraryDisplay.self, from: data), display)
    }

    // MARK: Accent

    func testAnyAccentMeetsAAInBothAppearances() {
        for hex in [0xFFFFFF, 0x000000, 0x777777, 0xFFFF00, 0x0000FF, 0x4A5BD4, 0xE4572E] {
            let accent = ThemeAccent(hex)
            XCTAssertGreaterThanOrEqual(ThemeAccent.contrast(accent.light, Palette.paper.light), 4.5, String(hex, radix: 16))
            XCTAssertGreaterThanOrEqual(ThemeAccent.contrast(accent.light, Palette.surface.light), 4.5, String(hex, radix: 16))
            XCTAssertGreaterThanOrEqual(ThemeAccent.contrast(accent.dark, Palette.paper.dark), 4.5, String(hex, radix: 16))
            XCTAssertGreaterThanOrEqual(ThemeAccent.contrast(accent.dark, Palette.surface.dark), 4.5, String(hex, radix: 16))
            XCTAssertGreaterThanOrEqual(ThemeAccent.contrast(accent.fill, Palette.onAccent), 4.5, String(hex, radix: 16))
        }
    }

    // MARK: BIOS row

    func testBIOSRowImportChecksSizeAndNamesTheFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("bios-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("anything.dat")
        try Data(repeating: 1, count: 4 << 10).write(to: file)
        try BIOSManagerView.install(file, as: "bios9.bin", in: folder)
        let dest = folder.appendingPathComponent("bios9.bin")
        XCTAssertEqual(try Data(contentsOf: dest).first, 1)

        try Data(repeating: 2, count: 4 << 10).write(to: file)
        try BIOSManagerView.install(file, as: "bios9.bin", in: folder)
        XCTAssertEqual(try Data(contentsOf: dest).first, 2, "Replace overwrites")

        try Data(repeating: 3, count: 10).write(to: file)
        XCTAssertThrowsError(try BIOSManagerView.install(file, as: "bios9.bin", in: folder))
        XCTAssertEqual(try Data(contentsOf: dest).first, 2, "a wrong file leaves the good one")
    }
}
