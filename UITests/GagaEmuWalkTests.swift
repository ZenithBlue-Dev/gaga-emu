import XCTest

/// Device walks for a Debug build, run by the orchestrator on the iPhone (docs/06 section 2.5). Each step
/// attaches a screenshot to the result bundle. The test bundle never ships: it is its own target, and the
/// app's `-GagaImportTestROM` launch argument exists only in Debug builds.
///
/// Launch environment, read by the test runner (`TEST_RUNNER_<NAME>` through xcodebuild):
/// - `GAGA_WALK_CORE`: core ID whose generated test ROM is played. Default `mgba`.
/// - `GAGA_WALK_ROM`: optional ROM path for `-GagaImportROM` instead (relative is under Documents).
/// - `GAGA_WALK_TITLE`: Library title of that game. Default `GagaBenchmark`, the test ROM's name.
/// - `GAGA_WALK_BATTERY`: `0` when the game writes no battery save. Default `1`.
final class GagaEmuWalkTests: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment
    private var core: String { environment["GAGA_WALK_CORE"] ?? "mgba" }
    private var title: String { environment["GAGA_WALK_TITLE"] ?? "GagaBenchmark" }
    private let timeout: TimeInterval = 30

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        if let rom = environment["GAGA_WALK_ROM"] {
            app.launchArguments = ["-GagaImportROM", rom]
        } else {
            app.launchArguments = ["-GagaImportTestROM", core]
        }
        app.launch()
        return app
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Labels can carry a value after the title, such as "Save State, Saved 20:06".
    private func button(_ app: XCUIApplication, _ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func tap(_ element: XCUIElement, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(what) did not appear")
        element.tap()
    }

    /// How long the launch import may take: a large `GAGA_WALK_ROM` archive is unpacked before it is listed.
    private let importTimeout: TimeInterval = 180

    /// The imported game, once the Library lists it (the import filters the Library to it). A failed import
    /// shows an alert instead, and its text is the failure.
    private func importedGame(_ app: XCUIApplication, _ what: String) -> XCUIElement {
        let game = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        let alert = app.alerts.firstMatch
        let deadline = Date().addingTimeInterval(importTimeout)
        while Date() < deadline {
            if game.exists || promptUp() { return game }
            if alert.exists {
                snapshot("Import alert")
                XCTFail("\(what): the import failed: " + ([alert.label] + alert.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " | "))
                return game
            }
            sleep(1)
        }
        snapshot("No game")
        XCTFail("\(what) was not in the Library after \(Int(importTimeout)) s, and no import alert appeared")
        return game
    }

    // MARK: Layout audit

    /// The current screen upright and in landscape, ending upright, so a turn on every screen is shot too.
    private func audit(_ name: String) {
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        snapshot("\(name) portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        snapshot("\(name) landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
    }

    /// A system prompt over the app, such as a sign-in request, must not get the walk's taps: a tap could answer it.
    private func promptUp() -> Bool {
        let up = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists
        if up { snapshot("STOPPED system prompt") }
        return up
    }

    /// Taps a button by its label's start. False, with a screenshot, when it is not there, so the audit goes on.
    @discardableResult private func open(_ app: XCUIApplication, _ prefix: String) -> Bool {
        if promptUp() { return false }
        let element = button(app, prefix)
        guard element.waitForExistence(timeout: 6) else {
            snapshot("MISSING \(prefix)")
            return false
        }
        element.tap()
        sleep(1)
        return true
    }

    /// Leaves a sheet or cover by its own button, else by a swipe down.
    private func close(_ app: XCUIApplication) {
        if promptUp() { return }
        for label in ["Close", "Cancel", "Done"] where app.buttons[label].firstMatch.exists {
            app.buttons[label].firstMatch.tap()
            sleep(1)
            return
        }
        app.swipeDown(velocity: .fast)
        sleep(1)
    }

    private func auditPage(_ app: XCUIApplication, _ prefix: String, as name: String) {
        guard open(app, prefix) else { return }
        audit(name)
        close(app)
    }

    /// Library, its long-press sheets, Add and every Settings page, each upright and in landscape.
    func testAuditScreens() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        sleep(1)
        audit("01 Library")
        for (index, entry) in ["Change Core", "Choose Filter", "Assign Skin", "Manage Saves", "Edit Details", "Delete"].enumerated() {
            let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            guard !promptUp(), tile.waitForExistence(timeout: 6) else { continue }
            tile.press(forDuration: 1.2)
            sleep(1)
            if index == 0 { snapshot("02 Library menu portrait") }
            auditPage(app, entry, as: "03 Game \(entry)")
        }
        guard !promptUp() else { return }
        app.buttons["Add"].tap()
        sleep(1)
        audit("04 Add")
        auditPage(app, "Multi-Disc", as: "05 Add Multi-Disc")
        auditPage(app, "Patch a ROM", as: "05 Add Patch")
        guard !promptUp() else { return }
        app.buttons["Settings"].tap()
        sleep(1)
        for category in ["Play", "Library", "Display", "Graphics", "Controls", "Storage", "About"] {
            // By identifier, as the rail has a Library button too.
            let row = app.buttons["settings.\(category)"].firstMatch
            if !promptUp(), row.waitForExistence(timeout: 6) {
                XCTAssertTrue(row.isHittable, "The \(category) tab is off the screen")
                row.tap()
                sleep(1)
                audit("06 Settings \(category)")
            }
            switch category {
            case "Library": auditPage(app, "BIOS Files", as: "07 BIOS")
            case "Graphics":
                auditPage(app, "Default Filter", as: "07 Filter")
                auditPage(app, "Screen", as: "07 Screen")
            case "Controls":
                if open(app, "Touch Layout") {
                    audit("07 Assign Skin")
                    let edit = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "skin")).firstMatch
                    if edit.waitForExistence(timeout: 6) {
                        edit.tap()
                        sleep(2)
                        audit("07 Skin Editor")
                        cancel(app)
                    }
                    close(app)
                }
                auditPage(app, "Controller Mapping", as: "07 Mapping")
                auditPage(app, "Macros", as: "07 Macros")
                auditPage(app, "Turbo", as: "07 Turbo")
            case "About":
                auditPage(app, "About Us", as: "07 About Us")
                auditPage(app, "Licences", as: "07 Licences")
            default: break
            }
        }
    }

    /// The accessibility tree as text: scroll bars and system sheets show here, not always in a screenshot.
    private func dumpTree(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func flip(_ app: XCUIApplication, _ toggle: String) {
        let row = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", toggle)).firstMatch
        if row.waitForExistence(timeout: 6) { row.switches.firstMatch.tap() }
        sleep(1)
    }

    /// Settings > Display with non-default choices, then the Library that draws them, and the filter search.
    func testAuditDisplay() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        // More shelves than one screen holds, so the Library scrolls.
        for extra in ["nestopia", "melonds_ds", "azahar"] {
            let other = XCUIApplication()
            other.launchArguments = ["-GagaImportTestROM", extra]
            other.launch()
            _ = importedGame(other, "The \(extra) game")
        }
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        // The system's Game Center banner sits over the tabs just after launch: a tap there opened its dashboard.
        sleep(10)
        guard !promptUp() else { return }
        app.buttons["Settings"].tap()
        sleep(1)
        tap(app.buttons["settings.Display"].firstMatch, "The Display tab")
        sleep(1)
        guard app.buttons["settings.Display"].firstMatch.isSelected else {
            snapshot("STOPPED Display tab not selected")
            return
        }
        audit("20 Display default")
        for choice in ["Light", "Teal", "3", "Framed"] where !promptUp() {
            app.buttons[choice].firstMatch.tap()
            sleep(1)
        }
        for toggle in ["Square Covers", "Hide Details"] where !promptUp() { flip(app, toggle) }
        if open(app, "Shelf Title") { open(app, "Maker") }
        audit("21 Display changed")
        guard !promptUp() else { return }
        app.buttons["Library"].firstMatch.tap()
        sleep(1)
        open(app, "All games")
        audit("22 Library three per row")
        dumpTree(app, "22 hierarchy")
        if open(app, "Sort games") {
            snapshot("23 Sort menu portrait")
            open(app, "Title")
        }
        guard !promptUp() else { return }
        app.buttons["Settings"].tap()
        sleep(1)
        // Leaving Settings put it back on its first tab.
        tap(app.buttons["settings.Display"].firstMatch, "The Display tab")
        sleep(1)
        for choice in ["5", "Plain"] where !promptUp() {
            app.buttons[choice].firstMatch.tap()
            sleep(1)
        }
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 1)
        sleep(1)
        for toggle in ["Hide Game Titles", "Hide Scroll Indicators"] where !promptUp() { flip(app, toggle) }
        if open(app, "Shelf Title") { open(app, "Short Code") }
        audit("25 Display second pass")
        guard !promptUp() else { return }
        app.buttons["Library"].firstMatch.tap()
        sleep(1)
        audit("26 Library five per row")
        dumpTree(app, "26 hierarchy")
        guard !promptUp() else { return }
        app.buttons["Settings"].tap()
        sleep(1)
        tap(app.buttons["settings.Display"].firstMatch, "The Display tab")
        sleep(1)
        flip(app, "Hide Shelf Titles")
        guard !promptUp() else { return }
        app.buttons["Library"].firstMatch.tap()
        sleep(1)
        audit("27 Library no shelf titles")
        guard !promptUp() else { return }
        app.buttons["Settings"].tap()
        sleep(1)
        tap(app.buttons["settings.Display"].firstMatch, "The Display tab")
        sleep(1)
        let well = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Custom accent colour")).firstMatch
        if well.waitForExistence(timeout: 6) {
            well.tap()
            sleep(2)
            snapshot("28 Colour picker portrait")
            dumpTree(app, "28 hierarchy")
            guard !promptUp() else { return }
            // A spot in the picker's colour area, then away.
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.62)).tap()
            sleep(1)
            snapshot("28 Colour picked")
            close(app)
            sleep(1)
            snapshot("29 Custom accent portrait")
        } else {
            snapshot("MISSING colour well")
        }
        guard !promptUp() else { return }
        tap(app.buttons["settings.Library"].firstMatch, "The Library tab")
        sleep(1)
        if open(app, "BIOS Files") {
            if open(app, "Import scph5500") {
                sleep(2)
                snapshot("30 BIOS file picker")
                dumpTree(app, "30 hierarchy")
                guard !promptUp() else { return }
                // The picker's own X: the sheet behind it has a Close button too.
                app.buttons["Cancel"].firstMatch.tap()
                sleep(1)
            }
            close(app)
        }
        guard !promptUp() else { return }
        tap(app.buttons["settings.Graphics"].firstMatch, "The Graphics tab")
        sleep(1)
        guard open(app, "Default Filter") else { return }
        let search = app.textFields["Search filters"].firstMatch
        if search.waitForExistence(timeout: 6) {
            search.tap()
            search.typeText("zzz")
            sleep(1)
            snapshot("24 Filter search no match")
            search.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "cr")
            sleep(1)
            snapshot("24 Filter search")
            dumpTree(app, "24 hierarchy")
            XCUIDevice.shared.orientation = .landscapeLeft
            sleep(2)
            snapshot("24 Filter search landscape")
            XCUIDevice.shared.orientation = .portrait
        }
    }

    /// Playing, the pause menu and its pages, upright and in landscape.
    private func auditGame(_ core: String, platform: String, tag: String) {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-GagaImportTestROM", core]
        app.launch()
        _ = importedGame(app, "The \(title) game")
        guard !promptUp() else { return }
        // The Library keeps earlier tests' test ROMs, all of one title: the platform picks this one.
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, platform)).firstMatch, "The \(platform) tile")
        let pause = app.buttons["Pause game"]
        guard pause.waitForExistence(timeout: timeout) else {
            snapshot("\(tag) did not start")
            return
        }
        sleep(4)
        audit("\(tag) Playing")
        guard !promptUp() else { return }
        pause.tap()
        sleep(1)
        audit("\(tag) Pause")
        if open(app, "Screen") {
            audit("\(tag) Pause Screen")
            open(app, "Back")
        }
        auditPage(app, "Load State", as: "\(tag) Load State")
        if open(app, "Controls") {
            audit("\(tag) Controls")
            if open(app, "Touch Layout") {
                sleep(1)
                audit("\(tag) Touch Editor")
                cancel(app)
            }
            close(app)
        }
        auditPage(app, "Cheats", as: "\(tag) Cheats")
        auditPage(app, "Play Nearby", as: "\(tag) Play Nearby")
        // The Device skin style, on systems that have one.
        guard open(app, "Controls") else { return }
        let style = button(app, "Skin Style, This System")
        guard !promptUp(), style.waitForExistence(timeout: 3) else {
            close(app)
            return
        }
        style.tap()
        sleep(1)
        open(app, "Device")
        close(app)
        open(app, "Resume")
        sleep(3)
        audit("\(tag) Device Skin")
    }

    /// Batch 2: Add's new rows and the WebDAV sheet, Guides, optional BIOS, Graphics, the Library menu and the
    /// Multi-Disc picker, upright and in landscape. Types only placeholder text into the WebDAV address.
    func testAuditManic2() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        sleep(10)
        guard !promptUp() else { return }
        open(app, "Sort games")
        snapshot("40 Sort menu with maker portrait")
        if open(app, "Controllers") {
            audit("41 Controllers from Library")
            close(app)
        }
        guard !promptUp() else { return }
        app.buttons["Add"].firstMatch.tap()
        sleep(1)
        audit("42 Add")
        if open(app, "WebDAV Server") {
            audit("43 WebDAV sign in")
            let field = app.textFields["Server address"].firstMatch
            if field.waitForExistence(timeout: 4), !promptUp() {
                field.tap()
                field.typeText("http://example.test")
                app.keyboards.buttons["return"].firstMatch.tap()
                sleep(1)
                open(app, "Connect")
                sleep(2)
                snapshot("43 WebDAV plain HTTP refused")
            }
            close(app)
        }
        guard !promptUp() else { return }
        auditPage(app, "Multi-Disc", as: "44 Multi-Disc picker")
        guard !promptUp() else { return }
        app.buttons["Settings"].firstMatch.tap()
        sleep(1)
        tap(app.buttons["settings.Play"].firstMatch, "The Play tab")
        sleep(1)
        audit("45 Play")
        tap(app.buttons["settings.Graphics"].firstMatch, "The Graphics tab")
        sleep(1)
        audit("46 Graphics")
        tap(app.buttons["settings.Library"].firstMatch, "The Library tab")
        sleep(1)
        auditPage(app, "BIOS Files", as: "47 BIOS optional")
        tap(app.buttons["settings.About"].firstMatch, "The About tab")
        sleep(1)
        audit("48 About")
        auditPage(app, "Guides", as: "49 Guides")
    }

    /// The maker filter, picking discs by hand, and the BIOS list's Optional section.
    func testMakerFilterAndDiscPicker() {
        XCUIDevice.shared.orientation = .portrait
        let psp = XCUIApplication()
        psp.launchArguments = ["-GagaImportTestROM", "ppsspp"]
        psp.launch()
        _ = importedGame(psp, "The ppsspp game")
        let app = XCUIApplication()
        app.launchArguments = ["-GagaSeedDiscs", "YES", "-GagaImportTestROM", core]
        app.launch()
        _ = importedGame(app, "The \(title) game")
        sleep(10)
        guard !promptUp() else { return }
        tap(button(app, "All"), "All games")
        sleep(1)
        let pspGame = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "PSP")).firstMatch
        XCTAssertTrue(pspGame.waitForExistence(timeout: 6), "The PSP game is not listed before filtering")
        open(app, "Sort games")
        open(app, "Nintendo")
        sleep(1)
        audit("52 Filtered by Nintendo")
        XCTAssertFalse(pspGame.exists, "The maker filter left the PSP game")

        guard !promptUp() else { return }
        app.buttons["Add"].firstMatch.tap()
        sleep(1)
        XCTAssertTrue(open(app, "Multi-Disc"))
        tap(button(app, "Odd End.chd"), "The second disc")
        tap(button(app, "Odd Start.chd"), "The first disc")
        let name = app.textFields["Game title"].firstMatch
        tap(name, "The title field")
        name.typeText("Picked Set\n")
        sleep(1)
        snapshot("53 Discs picked")
        tap(button(app, "Create Playlist"), "Create Playlist")
        XCTAssertTrue(app.staticTexts["Wrote Picked Set.m3u"].waitForExistence(timeout: 6), "No playlist written")
        audit("53 Playlist written")
        close(app)

        guard !promptUp() else { return }
        app.buttons["Settings"].firstMatch.tap()
        sleep(1)
        tap(app.buttons["settings.Library"].firstMatch, "The Library tab")
        sleep(1)
        XCTAssertTrue(open(app, "BIOS Files"))
        let optional = app.staticTexts["Optional"].firstMatch
        for _ in 0..<8 where !optional.exists { app.swipeUp() }
        XCTAssertTrue(optional.exists, "No Optional section")
        audit("54 BIOS Optional")
    }

    /// Spanish through the launch arguments: the rail and Settings read it, and the Language row appears.
    func testAuditSpanish() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES", "-GagaImportTestROM", core]
        app.launch()
        _ = importedGame(app, "The \(title) game")
        sleep(10)
        guard !promptUp() else { return }
        let settings = app.buttons["Ajustes"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 6), "No Ajustes tab")
        settings.tap()
        sleep(1)
        tap(app.buttons["settings.About"].firstMatch, "The About tab")
        sleep(1)
        XCTAssertTrue(button(app, "Idioma").waitForExistence(timeout: 6), "No Idioma row")
        audit("50 Spanish About")
    }

    /// Auto Save State: on, play, quit, and playing again offers Resume.
    func testAutoSaveOffersResume() {
        let app = launchApp()
        let game = importedGame(app, "The \(title) game")
        sleep(10)
        guard !promptUp() else { return }
        tap(app.buttons["Settings"].firstMatch, "Settings")
        sleep(1)
        flip(app, "Auto Save State")
        snapshot("51 Auto Save on")
        tap(app.buttons["Library"].firstMatch, "Library")
        sleep(1)
        game.tap()
        let pause = app.buttons["Pause game"]
        XCTAssertTrue(pause.waitForExistence(timeout: timeout), "The game did not start")
        sleep(4)
        pause.tap()
        tap(button(app, "Quit to Library"), "Quit to Library")
        XCTAssertTrue(game.waitForExistence(timeout: timeout), "Quit did not return to the Library")
        sleep(1)
        game.tap()
        let resume = app.alerts.buttons["Resume"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: timeout), "No Resume offer after quitting with Auto Save on")
        snapshot("51 Resume offer")
        app.alerts.buttons["Cancel"].firstMatch.tap()
    }

    /// Leaves an editor whose parent sheet also has a Close button.
    private func cancel(_ app: XCUIApplication) {
        if promptUp() { return }
        app.buttons["Cancel"].firstMatch.tap()
        sleep(1)
    }

    func testAuditGameGBA() { auditGame("mgba", platform: "Game Boy Advance", tag: "10 GBA") }
    func testAuditGameNES() { auditGame("nestopia", platform: "NES", tag: "11 NES") }
    func testAuditGameNDS() { auditGame("melonds_ds", platform: "Nintendo DS", tag: "12 NDS") }
    func testAuditGame3DS() { auditGame("azahar", platform: "Nintendo 3DS", tag: "13 3DS") }
    func testAuditGamePSP() { auditGame("ppsspp", platform: "PSP", tag: "14 PSP") }

    /// Settings > About > Licences.
    func testOpenLicences() throws {
        let app = launchApp()
        try guardedTap(button(app, "Settings"), "Settings in the rail")
        try guardedTap(button(app, "About"), "About")
        try guardedTap(button(app, "Licences"), "Licences")
        snapshot("Licences")
    }

    /// Ends the test as skipped, with a screenshot, while a system prompt is up, so nothing taps or waits under it.
    private func stopIfPrompt() throws {
        if promptUp() { throw XCTSkip("A system prompt is up") }
    }

    private func arrive(_ element: XCUIElement, _ what: String) throws {
        try stopIfPrompt()
        if element.waitForExistence(timeout: timeout) { return }
        try stopIfPrompt()
        XCTFail("\(what) did not appear")
    }

    private func guardedTap(_ element: XCUIElement, _ what: String) throws {
        try arrive(element, what)
        try stopIfPrompt()
        element.tap()
    }

    /// Play, turn the phone upright and back: the touch controls lay out again for each orientation and stay on
    /// screen, and the game keeps running, so its pause menu still opens and closes.
    func testRotation() throws {
        let app = launchApp()
        try guardedTap(importedGame(app, "The \(title) game"), "The game")
        let pause = app.buttons["Pause game"]
        try arrive(pause, "The game")
        sleep(2)
        let control = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@",
            ["A button", "B button", "Start", "D-pad right"])).firstMatch
        try arrive(control, "A touch control")
        let landscape = control.frame
        snapshot("Rotation landscape")

        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        snapshot("Rotation portrait")
        try arrive(control, "The touch control after turning upright")
        let portrait = control.frame
        XCTAssertNotEqual(portrait, landscape, "The touch controls did not lay out again upright")
        XCTAssertTrue(app.frame.contains(portrait), "The touch control is off screen upright: \(portrait) in \(app.frame)")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        snapshot("Rotation landscape again")
        try arrive(control, "The touch control after turning back")
        XCTAssertTrue(app.frame.contains(control.frame), "The touch control is off screen in landscape: \(control.frame) in \(app.frame)")

        try guardedTap(pause, "Pause game after turning")
        try guardedTap(button(app, "Resume"), "Resume after turning")
        try arrive(pause, "The running game after turning")
    }

    /// Play, press a touch control, pause, resume, save a state, load it, quit, relaunch, check the battery save.
    func testWalk() throws {
        var app = launchApp()
        snapshot("Library")
        let play = importedGame(app, "The \(title) game")
        sleep(1)
        snapshot("Library landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        snapshot("Library portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        try guardedTap(play, "The game")
        let pause = app.buttons["Pause game"]
        try arrive(pause, "The game")
        sleep(2)
        snapshot("Playing, touch layout")

        // Touch input: the glyph passes the touch to the layer under it, which presses the button.
        let control = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@",
            ["A button", "B button", "Start", "D-pad right"])).firstMatch
        try guardedTap(control, "A touch control")
        snapshot("After input")

        try guardedTap(pause, "Pause game")
        try guardedTap(button(app, "Resume"), "Resume")
        try guardedTap(pause, "Pause game")
        try guardedTap(button(app, "Save State"), "Save State")
        try guardedTap(button(app, "Load State"), "Load State")
        let load = button(app, "Load Save state")
        try guardedTap(load, "The saved state")
        try arrive(pause, "The game after loading the state")
        snapshot("Loaded state")

        try guardedTap(pause, "Pause game")
        try guardedTap(button(app, "Quit to Library"), "Quit to Library")
        try arrive(play, "The Library after quitting")

        app.terminate()
        app = launchApp()
        try guardedTap(importedGame(app, "The game after relaunch"), "The game after relaunch")
        try guardedTap(app.buttons["Pause game"], "Pause game after relaunch")
        try guardedTap(button(app, "Load State"), "Load State after relaunch")
        snapshot("Saves after relaunch")
        XCTAssertTrue(button(app, "Load Save state").exists,
                      "The save state did not survive a relaunch")
        if environment["GAGA_WALK_BATTERY"] != "0" {
            XCTAssertTrue(app.staticTexts["Written by the game itself"].exists, "No battery save after quit and relaunch")
        }
    }
}
