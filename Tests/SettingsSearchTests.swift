import XCTest
@testable import GagaEmu

/// The redesign's navigation (docs/ux-redesign.md): settings search, the four tabs, Style's pages and the pictures'
/// alt text.
final class SettingsSearchTests: XCTestCase {
    func testEveryCategoryCanBeFound() {
        for category in SettingsCategory.allCases {
            XCTAssertTrue(SettingEntry.all.contains { $0.category == category }, "\(category.title) has no searchable setting")
        }
    }

    func testTheWordsPeopleUseFindSomething() {
        for word in ["skin", "bios", "filter", "shader", "cheat", "username", "icloud", "controller", "rewind", "core", "icon"] {
            XCTAssertFalse(SettingEntry.search(word).isEmpty, "\"\(word)\" finds nothing")
        }
        XCTAssertTrue(SettingEntry.search("zzzz").isEmpty)
        XCTAssertTrue(SettingEntry.search("   ").isEmpty)
    }

    func testResultsOpenTheRightPlace() {
        XCTAssertEqual(SettingEntry.search("skin").first?.title, "Skins")
        XCTAssertEqual(SettingEntry.search("skin").first?.target?.style, .skins)
        XCTAssertEqual(SettingEntry.search("bios").first?.target, .bios)
        XCTAssertEqual(SettingEntry.search("shader").first?.target?.style, .filters)
        XCTAssertEqual(SettingEntry.search("username").first?.category, .profile)
        XCTAssertEqual(SettingEntry.search("BIOS Files").first?.title, "BIOS Files", "Case and several words")
    }

    func testTitlesAreUniqueAndOnlyVisibleCategoriesAnswer() {
        XCTAssertEqual(Set(SettingEntry.all.map(\.title)).count, SettingEntry.all.count)
        if !PaywallGate.isOpen { XCTAssertTrue(SettingEntry.search("subscription").isEmpty, "A closed paywall gate still shows Gaga Plus") }
    }

    func testFourOneWordTabsAndFourStylePages() {
        XCTAssertEqual(AppScreen.allCases.map(\.title), ["Library", "Import", "Style", "Settings"])
        XCTAssertTrue(AppScreen.allCases.allSatisfy { !$0.title.contains(" ") })
        XCTAssertEqual(StyleSection.allCases.count, 4)
        XCTAssertEqual(Set(StyleSection.allCases.map(\.identifier)).count, 4)
        XCTAssertEqual(Set(SettingsCategory.allCases.map(\.identifier)).count, SettingsCategory.allCases.count)
    }

    func testCoreOptionPictures() {
        XCTAssertEqual(CoreOptionsView.symbol(key: "mgba_frameskip", label: "Frameskip"), "speedometer")
        XCTAssertEqual(CoreOptionsView.symbol(key: "x_internal_resolution", label: "Internal Resolution"), "arrow.up.left.and.arrow.down.right")
        XCTAssertEqual(CoreOptionsView.symbol(key: "x_zzz", label: "Something"), "slider.horizontal.3")
    }

    /// A skin's picture is its own controls at their places, per orientation, custom layouts included.
    func testSkinPicturesDrawTheRealLayout() throws {
        let standard = TouchSkinEngine.Layout.builtIn[0]
        let wide = SkinDrawing.layout(standard, platformID: "n64", portrait: false)
        XCTAssertEqual(wide.buttons, standard.buttons(for: "n64"))
        XCTAssertTrue(wide.buttons.contains { $0.shape == .stick }, "The N64 picture has no stick")
        XCTAssertGreaterThan(wide.aspect, 1)
        let upright = SkinDrawing.layout(standard, platformID: "n64", portrait: true)
        XCTAssertEqual(upright.buttons, TouchSkinEngine.portrait(from: standard.buttons(for: "n64")))
        XCTAssertLessThan(upright.aspect, 1)
        XCTAssertNotEqual(SkinDrawing.layout(standard, platformID: "gba", portrait: false).buttons.count, wide.buttons.count)

        var moved = standard.buttons(for: "gba")
        moved[0].frame.origin.x += 0.01
        let data = try TouchSkinEngine.encodeFlex(name: "Custom", buttons: moved, opacity: 0.8)
        let custom = try TouchSkinEngine.decodeFlex(data, id: "custom")
        XCTAssertEqual(SkinDrawing.skin(custom, portrait: false).buttons.map(\.frame), moved.map(\.frame))
        XCTAssertEqual(SkinDrawing.skin(custom, portrait: true).buttons.map(\.frame), TouchSkinEngine.portrait(from: moved).map(\.frame))

        let spoken = SkinThumbnail.spoken("Standard", platformID: "gba", upright: true)
        XCTAssertTrue(spoken.contains("Standard") && spoken.contains(CoreCatalog.platformName("gba")) && spoken.contains("portrait"))
    }

    func testPicturesSayWhatTheyShow() {
        for mode in ScalingMode.allCases { XCTAssertFalse(ScalingPicture.effect(mode).isEmpty) }
        var display = LibraryDisplay()
        XCTAssertTrue(ShelfPicture.description(display).contains("one sideways row"))
        display.perRow = 3
        display.square = true
        XCTAssertEqual(ShelfPicture.description(display), "Shelf preview: 3 per row, Spine covers, square")
    }
}
