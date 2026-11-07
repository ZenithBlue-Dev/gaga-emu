import XCTest
@testable import GagaEmu

/// The skin editor's custom layouts: flex skin save and load, the layout checks, editing moves, and reset.
@MainActor
final class CustomSkinTests: GagaTestCase {
    private func game(_ platformID: String, skinID: String? = nil) -> GameItem {
        GameItem(id: UUID(), title: "t", platformID: platformID, romPath: "/nowhere", coverPath: nil, coreOverride: nil,
                 playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original", skinID: skinID)
    }

    func testFlexRoundTripKeepsIdsMasksFramesAndOpacity() throws {
        let buttons = TouchSkinEngine.Layout.twinPad.buttons
        let data = try TouchSkinEngine.encodeFlex(name: "Custom", buttons: buttons, opacity: 0.5)
        let skin = try TouchSkinEngine.decodeFlex(data, id: "vb.json")
        XCTAssertEqual(skin.buttons, buttons, "Diagonals and the second pad keep their combined masks")
        XCTAssertEqual(skin.opacity, 0.5)
        XCTAssertTrue(skin.landscape)
    }

    func testFlexWithoutIdsStillLoadsByInputName() throws {
        let json = #"{"name":"Old","buttons":[{"input":"a","frame":{"x":0.85,"y":0.5,"width":0.1,"height":0.2}}]}"#
        let skin = try TouchSkinEngine.decodeFlex(Data(json.utf8), id: "old")
        XCTAssertEqual(skin.buttons.first?.mask, ControllerManager.Button.south)
        XCTAssertEqual(skin.opacity, TouchSkinEngine.defaultOpacity)
    }

    func testEveryBuiltInLayoutPassesTheChecks() {
        for layout in TouchSkinEngine.Layout.builtIn {
            XCTAssertEqual(TouchSkinEngine.problems(in: layout.buttons(for: "dos")), [], layout.id)
        }
    }

    func testChecksFindPictureOverlapSmallTargetsAndOffScreen() {
        let standard = TouchSkinEngine.Layout.standard.buttons
        let intoPicture = TouchSkinEngine.moving(standard, group: "start", by: CGSize(width: -0.3, height: 0))
        XCTAssertTrue(TouchSkinEngine.problems(in: intoPicture).contains { $0.contains("covers the picture") })
        let tiny = TouchSkinEngine.resizing(standard, group: "start", by: 0.3)
        XCTAssertTrue(TouchSkinEngine.problems(in: tiny).contains { $0.contains("44 points") })
        let onTop = TouchSkinEngine.moving(standard, group: "east", by: CGSize(width: -0.065, height: -0.13))
        XCTAssertTrue(TouchSkinEngine.problems(in: onTop).contains { $0.contains("overlaps") })
        var off = standard
        off[0].frame.origin.y = -0.1
        XCTAssertTrue(TouchSkinEngine.problems(in: off).contains { $0.contains("off the screen") })
    }

    func testThePadMovesAndResizesAsOnePieceInsideTheCanvas() throws {
        let standard = TouchSkinEngine.Layout.standard.buttons
        let moved = TouchSkinEngine.moving(standard, group: "pad", by: CGSize(width: -1, height: 0.05))
        let up = try XCTUnwrap(moved.first { $0.id == "up" }), downLeft = try XCTUnwrap(moved.first { $0.id == "downleft" })
        XCTAssertEqual(downLeft.frame.minX, 0, accuracy: 0.0001, "Stopped at the left edge")
        XCTAssertEqual(up.frame.minX - downLeft.frame.minX, TouchSkinEngine.Layout.standard.buttons.first { $0.id == "up" }!.frame.minX
                       - TouchSkinEngine.Layout.standard.buttons.first { $0.id == "downleft" }!.frame.minX, accuracy: 0.0001)
        XCTAssertEqual(moved.first { $0.id == "south" }, standard.first { $0.id == "south" }, "Other groups stay")
        XCTAssertEqual(TouchSkinEngine.resizing(standard, group: "pad", by: 10), standard, "Too big for the canvas is refused")
    }

    func testSaveLoadsInTheGameAndResetReturnsTheDefault() throws {
        let state = AppState()
        state.skins.hapticsEnabled = false
        state.skins.soundEnabled = false
        let buttons = TouchSkinEngine.moving(TouchSkinEngine.Layout.twoButton.buttons, group: "pad", by: CGSize(width: 0, height: -0.1))
        try state.saveCustomSkin(buttons, opacity: 0.6, platformID: "gba")
        XCTAssertEqual(state.platformSkins["gba"], TouchSkinEngine.customID)
        XCTAssertTrue(state.hasCustomSkin("gba"))

        state.applySkin(for: game("gba"))
        XCTAssertEqual(state.skins.skin?.buttons, buttons)
        XCTAssertEqual(state.skins.opacity, 0.6)
        state.applySkin(for: game("gba", skinID: "low-reach"))
        XCTAssertEqual(state.skins.skin?.id, "low-reach", "A game's own choice beats the platform's custom skin")
        XCTAssertEqual(state.skins.opacity, TouchSkinEngine.defaultOpacity)

        state.resetCustomSkin("gba")
        XCTAssertNil(state.platformSkins["gba"])
        XCTAssertFalse(state.hasCustomSkin("gba"))
        state.applySkin(for: game("gba"))
        XCTAssertEqual(state.skins.skin?.id, "standard")
    }

    func testSaveRefusesABrokenLayoutAndWritesNothing() {
        let state = AppState()
        let broken = TouchSkinEngine.moving(TouchSkinEngine.Layout.standard.buttons, group: "start", by: CGSize(width: -0.3, height: 0))
        XCTAssertThrowsError(try state.saveCustomSkin(broken, opacity: 0.85, platformID: "snes"))
        XCTAssertFalse(state.hasCustomSkin("snes"))
        XCTAssertNil(state.platformSkins["snes"])
    }

    func testAMissingCustomFileFallsBackToTheBuiltIn() {
        let state = AppState()
        state.platformSkins["pce"] = TouchSkinEngine.customID
        state.applySkin(for: game("pce"))
        XCTAssertEqual(state.skins.skin?.id, "two-button")
    }
}
