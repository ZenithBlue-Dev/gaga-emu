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

    func testPlainCodesAreNotABlock() {
        XCTAssertEqual(CheatFormat.cwCheatBlocks("_L 0x20000000 0x00000001"), [], "no _C line: one cheat, as typed")
        XCTAssertEqual(CheatFormat.cwCheatBlocks("01FF34C2\nGameShark"), [])
        XCTAssertEqual(CheatFormat.cwCheatBlocks(""), [])
    }
}
