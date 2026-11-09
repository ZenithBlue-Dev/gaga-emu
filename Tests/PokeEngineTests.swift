import XCTest
@testable import GagaEmu

/// The host's raw RAM cheats: parsing, bounds and compare on a plain buffer, then real cores with homebrew fixtures.
final class PokeEngineTests: GagaTestCase {
    private func withMemory(_ count: Int = 16, start: UInt64 = 0, _ body: ([GagaPokeRegion], UnsafeMutablePointer<UInt8>) -> Void) {
        let memory = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        memory.initialize(repeating: 0, count: count)
        defer { memory.deallocate() }
        body([GagaPokeRegion(data: memory, start: start, length: UInt64(count))], memory)
    }

    func testParsesWidthsAndCompare() throws {
        XCTAssertEqual(PokeEngine.parse("0010:AB"), [.init(address: 0x10, value: 0xAB, compare: nil, width: 1)])
        XCTAssertEqual(PokeEngine.parse("10?1234:BEEF\n20:00000001")?.map(\.width), [2, 4])
        XCTAssertEqual(PokeEngine.parse("10?1234:BEEF")?.first?.compare, 0x1234)
        for bad in ["", "10", "10:ABC", "10:??", "xx:00", "10?1:00", ":00", "12345678901234567:00"] {
            XCTAssertNil(PokeEngine.parse(bad), bad)
        }
        XCTAssertNil(PokeEngine.parse("10:00\nnope"), "one bad line refuses the cheat")
    }

    func testOffByDefaultAndSwitching() throws {
        withMemory { regions, memory in
            var engine = PokeEngine()
            XCTAssertFalse(engine.hasEnabled)
            engine.set(id: 1, codes: PokeEngine.parse("02:7F")!, enabled: false)
            XCTAssertFalse(engine.hasEnabled)
            engine.apply(to: regions)
            XCTAssertEqual(memory[2], 0)
            engine.setEnabled(id: 1, true)
            engine.apply(to: regions)
            XCTAssertEqual(memory[2], 0x7F)
            memory[2] = 0
            engine.setEnabled(id: 1, false) // What the hardcore gate calls for each enabled cheat.
            engine.apply(to: regions)
            XCTAssertEqual(memory[2], 0)
            engine.setEnabled(id: 1, true)
            engine.remove(id: 1)
            engine.apply(to: regions)
            XCTAssertEqual(memory[2], 0)
        }
    }

    func testBoundsNeverWritePastTheRegion() throws {
        withMemory(4, start: 0x100) { regions, memory in
            let inside = PokeEngine.parse("103:11")![0]
            XCTAssertTrue(PokeEngine.fits(inside, in: regions))
            for line in ["FF:11", "104:11", "102:11223344", "103:1122", "FFFFFFFFFFFFFFFF:1122"] {
                XCTAssertFalse(PokeEngine.fits(PokeEngine.parse(line)![0], in: regions), line)
            }
            var engine = PokeEngine()
            engine.set(id: 1, codes: PokeEngine.parse("102:11223344\n103:55")!, enabled: true)
            engine.apply(to: regions)
            XCTAssertEqual([memory[0], memory[1], memory[2], memory[3]], [0, 0, 0, 0x55], "the overrun is skipped, the fit applies")
        }
    }

    func testCompareAndByteOrder() throws {
        withMemory { regions, memory in
            var engine = PokeEngine()
            engine.set(id: 1, codes: PokeEngine.parse("00?05:09")!, enabled: true)
            engine.apply(to: regions)
            XCTAssertEqual(memory[0], 0, "compare did not match")
            memory[0] = 5
            engine.apply(to: regions)
            XCTAssertEqual(memory[0], 9)
            engine.set(id: 2, codes: PokeEngine.parse("04:A1B2C3D4")!, enabled: true)
            engine.apply(to: regions)
            XCTAssertEqual([memory[4], memory[5], memory[6], memory[7]], [0xD4, 0xC3, 0xB2, 0xA1], "low byte first")
        }
    }

    func testCoresWithAHandlerGetNoPokes() throws {
        for id in ["mgba", "azahar", "prboom", "dosbox_pure", "fbneo", ""] { XCTAssertNil(PokeEngine.base(coreID: id), id) }
        XCTAssertEqual(PokeEngine.base(coreID: "beetle_vb"), 0x0500_0000)
        XCTAssertEqual(CheatFormat.hint(coreID: "handy"), PokeEngine.hint)
    }

    /// A poke holds the value frame after frame against a running program, and stops when switched off.
    private func assertPoke(coreID: String, name: String, rom: Data, address: UInt64, system: [(String, Data)] = [],
                            file: StaticString = #filePath, line: UInt = #line) async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded(coreID), "GAGA_CORE_SET left this core out")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("poke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for (fileName, data) in system { try data.write(to: directory.appendingPathComponent(fileName)) }
        let path = directory.appendingPathComponent(name)
        try rom.write(to: path)
        let kit = RetroCoreTestKit(coreID: coreID, directory: directory)
        let (core, _) = try await kit.loaded(path: path.path, systemDirectory: directory.path)
        kit.run(core, frames: 30)
        XCTAssertTrue(core.supportsCheats, coreID, file: file, line: line)
        // Bit-flip what is there, so the test cannot pass on a byte that already held the value.
        let before = try XCTUnwrap(core.pokeReadForTest(address: address), coreID, file: file, line: line)
        let wanted = before ^ 0x5A
        let hex = String(address, radix: 16)
        XCTAssertThrowsError(try core.addCheat(id: 9, code: "FFFFFFFF0:00", enabled: true), coreID, file: file, line: line)
        try core.addCheat(id: 1, code: "\(hex):\(String(format: "%02X", wanted))", enabled: true)
        kit.run(core, frames: 10)
        XCTAssertEqual(core.pokeReadForTest(address: address), wanted, coreID, file: file, line: line)
        core.setCheat(id: 1, enabled: false)
        core.pokeWriteForTest(address: address, value: before)
        kit.run(core, frames: 1)
        XCTAssertNotEqual(core.pokeReadForTest(address: address), wanted, "off stops the write: \(coreID)", file: file, line: line)
        core.stop()
    }

    func testPokeChangesRealCoreMemory() async throws {
        // Address chosen in each core's RAM, past where these small programs store anything they rewrite each frame.
        try await assertPoke(coreID: "handy", name: "h.lnx", rom: LynxTestROM.build(), address: 0x9000)
        try await assertPoke(coreID: "stella", name: "s.a26", rom: Atari2600TestROM.build(), address: 0x70)
        try await assertPoke(coreID: "atari800", name: "a.a52", rom: Atari800TestROM.a52(), address: 0x2000)
        try await assertPoke(coreID: "prosystem", name: "p.a78", rom: Atari7800TestROM.build(), address: 0x2100)
        try await assertPoke(coreID: "virtualjaguar", name: "j.j64", rom: JaguarTestROM.build(), address: 0x100000)
        try await assertPoke(coreID: "beetle_ngp", name: "n.ngc", rom: NGPTestROM.build(), address: 0x3000)
        try await assertPoke(coreID: "beetle_vb", name: "v.vb", rom: VBTestROM.build(), address: 0x0500_8000)
        try await assertPoke(coreID: "pokemini", name: "m.min", rom: PMTestROM.build(), address: 0x0F00)
        try await assertPoke(coreID: "puae", name: "a.adf", rom: AmigaTestROM.adf(), address: 0x60000)
        try await assertPoke(coreID: "vice", name: "c.crt", rom: C64TestROM.crt(), address: 0x4000,
                             system: C64TestROM.standInSystemFiles.map { ($0.name, Data(count: $0.size)) })
    }
}
