import XCTest
@testable import GagaEmu

/// What the cheat sheet says each core reads, and the CWCheat paste that turns one .ini block into cheats.
final class CheatFormatTests: GagaTestCase {
    func testEveryCoreWithCheatsNamesItsFormat() {
        let fallback = CheatFormat.hint(coreID: "")
        for index in 0..<GagaCoreRegistry_GetCount() {
            guard let core = GagaCoreRegistry_GetAtIndex(index)?.pointee, core.cheat_add != nil else { continue }
            let id = String(cString: core.core_id)
            XCTAssertNotEqual(CheatFormat.hint(coreID: id), fallback, id)
        }
        XCTAssertTrue(CheatFormat.hint(coreID: "ppsspp").contains("CWCheat"))
        XCTAssertTrue(CheatFormat.hint(coreID: "mame").contains("System/mame/cheat/"))
        XCTAssertTrue(CheatFormat.hint(coreID: "fbneo").contains("System/fbneo/cheats/"))
        XCTAssertEqual(CheatFormat.unsupported(coreName: "Stella"), "Cheats: Stella has no cheat support in GagaEmu.")
    }

    func testACWCheatBlockBecomesOneCheatPerHeading() {
        let pasted = """
            _S ULUS-10041
            _G Example Game
            _C0 Infinite HP
            _L 0x2012A3C4 0x000003E7
            _L 0x2012A3C8 0x000003E7
            _C1   Max Money
            _l 0x20200000 0x0098967F
            _C1 Empty Heading
            _C0
            _L 0x20300000 0x00000001
            """
        XCTAssertEqual(CheatFormat.cwCheatBlocks(pasted), [
            .init(name: "Infinite HP", code: "_L 0x2012A3C4 0x000003E7\n_L 0x2012A3C8 0x000003E7", enabled: false),
            .init(name: "Max Money", code: "_l 0x20200000 0x0098967F", enabled: true),
            .init(name: "Cheat 4", code: "_L 0x20300000 0x00000001", enabled: false),
        ], "headings with no lines drop out, a nameless one gets a number")
    }

    func testAChtFileBecomesCheatsAllOff() {
        let file = """
            cheats = 4
            cheat0_desc = "Infinite Lives"
            cheat0_code = "0200A1B2+0063"
            cheat0_enable = true
            cheat1_code = "ABCDEF012345"
            cheat2_desc = "Memory search"
            cheat2_code = ""
            cheat2_handler = 1
            cheat3_desc = "Two codes"
            cheat3_code = "01020304+AABBCCDD+11223344+55667788"
            nonsense
            cheat99999999_code = "00000000"
            """
        XCTAssertEqual(CheatFormat.chtBlocks(file, coreID: "mgba"), [
            .init(name: "Infinite Lives", code: "0200A1B2 0063", enabled: false),
            .init(name: "Cheat 2", code: "ABCDEF01 2345", enabled: false),
            .init(name: "Two codes", code: "01020304 AABBCCDD\n11223344 55667788", enabled: false),
        ])
        XCTAssertEqual(CheatFormat.chtBlocks(file, coreID: "bsnes").last?.code, "01020304\nAABBCCDD\n11223344\n55667788",
                       "a core with whole-code tokens gets one per line")
        XCTAssertEqual(CheatFormat.chtBlocks("", coreID: "mgba"), [])
        XCTAssertEqual(CheatFormat.chtBlocks(String(repeating: "\u{0}cheat=\n", count: 1000), coreID: "mgba"), [], "junk is skipped")
    }

    func testTheBundledDatabaseFindsAGameByItsLibraryTitle() {
        XCTAssertEqual(CheatDatabase.key("Legend of Zelda, The - Oracle (USA) [T+Eng]"), "legendofzeldaoracle")
        XCTAssertEqual(CheatDatabase.key("The Pokémon!"), "pokemon")
        let found = CheatDatabase.blocks(title: "Super Mario Advance 4 - Super Mario Bros. 3 (USA)", platformID: "gba", coreID: "mgba")
        XCTAssertFalse(found.isEmpty)
        XCTAssertTrue(found.allSatisfy { !$0.enabled }, "off until the player switches one on")
        XCTAssertEqual(CheatDatabase.blocks(title: "No Such Game (USA)", platformID: "gba", coreID: "mgba"), [])
        XCTAssertEqual(CheatDatabase.blocks(title: "Super Mario Advance 4 - Super Mario Bros. 3 (USA)", platformID: "n3ds", coreID: "azahar"), [], "no 3DS data")
    }

    func testPlainCodesAreNotABlock() {
        XCTAssertEqual(CheatFormat.cwCheatBlocks("_L 0x20000000 0x00000001"), [], "no _C line: one cheat, as typed")
        XCTAssertEqual(CheatFormat.cwCheatBlocks("01FF34C2\nGameShark"), [])
        XCTAssertEqual(CheatFormat.cwCheatBlocks(""), [])
    }
}
