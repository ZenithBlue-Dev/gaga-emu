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

    func testPicturesSayWhatTheyShow() {
        for mode in ScalingMode.allCases { XCTAssertFalse(ScalingPicture.effect(mode).isEmpty) }
        var display = LibraryDisplay()
        XCTAssertTrue(ShelfPicture.description(display).contains("one sideways row"))
        display.perRow = 3
        display.square = true
        XCTAssertEqual(ShelfPicture.description(display), "Shelf preview: 3 per row, Spine covers, square")
    }
}
