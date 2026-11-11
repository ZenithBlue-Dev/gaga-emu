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

    /// Never shoots another app: a notification can bring one forward, and the result bundle would keep its screen.
    private func snapshot(_ name: String) {
        guard XCUIApplication().state == .runningForeground else {
            let skipped = XCTAttachment(string: "GagaEmu was not in front")
            skipped.name = "SKIPPED \(name)"
            skipped.lifetime = .keepAlways
            add(skipped)
            return
        }
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
        if element.identifier.hasPrefix("settings.") || element.identifier.hasPrefix("style.") { reveal(element) }
        element.tap()
    }

    /// How long the launch import may take: a large `GAGA_WALK_ROM` archive is unpacked before it is listed.
    private let importTimeout: TimeInterval = 180

    /// The imported game, once the Library lists it (the import filters the Library to it). A failed import
    /// shows an alert instead, and its text is the failure.
    private func importedGame(_ app: XCUIApplication, _ what: String) -> XCUIElement {
        // BEGINSWITH: the cover, not the Continue panel's "Play <title>".
        let matches = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (identifier BEGINSWITH 'continue')", title))
        let game = matches.firstMatch
        let strip = app.scrollViews["continueStrip"]
        let alert = app.alerts.firstMatch
        let deadline = Date().addingTimeInterval(importTimeout)
        while Date() < deadline {
            // A Continue strip tap starts the game; the walks want the cover, which opens its page.
            if strip.exists {
                if let cover = matches.allElementsBoundByIndex.first(where: {
                    !strip.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
                }) { return cover }
            } else if game.exists { return game }
            if promptUp() { return game }
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
        checkBounds("\(name) portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        snapshot("\(name) landscape")
        checkBounds("\(name) landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
    }

    /// Fails when a control or text runs past the window: off the side anywhere except inside a sideways strip, or
    /// off the top or bottom outside a scroll view. One accessibility snapshot, so it is quick. With
    /// `GAGA_WALK_OVERFLOW=record` it only lists them, as an `OVERFLOW` attachment.
    private func checkBounds(_ name: String) {
        let app = XCUIApplication()
        guard app.state == .runningForeground, let root = try? app.snapshot() else { return }
        let screen = root.frame
        let kinds: Set<XCUIElement.ElementType> = [.button, .staticText, .textField, .secureTextField, .switch, .slider,
                                                   .stepper, .segmentedControl, .image, .link, .searchField, .toggle]
        var found: [String] = []
        func walk(_ node: XCUIElementSnapshot, vertical: Bool, sideways: Bool) {
            let frame = node.frame
            let scrolls = [.scrollView, .collectionView, .table].contains(node.elementType)
            // Sideways when its content runs past its sides only.
            let content = node.children.reduce(CGRect.null) { $0.union($1.frame) }
            let strip = scrolls && !content.isNull && (content.width > frame.width + 1 && content.height <= frame.height + 1
                                                      || frame.width > frame.height * 2.5)
            // A backdrop that covers the whole screen, such as the game picture behind a sheet, is not an overflow.
            if kinds.contains(node.elementType), frame.width > 1, frame.height > 1, !frame.contains(screen) {
                let offSide = frame.minX < screen.minX - 1 || frame.maxX > screen.maxX + 1
                let offEnd = frame.minY < screen.minY - 1 || frame.maxY > screen.maxY + 1
                // Off the top or bottom inside a scroll view is content scrolled away; off a side is an overflow.
                if (offSide && !sideways) || (offEnd && !vertical && !sideways) {
                    let what = node.label.isEmpty ? node.identifier : node.label
                    found.append("\(node.elementType.rawValue) '\(what.prefix(60))' \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))")
                }
            }
            for child in node.children { walk(child, vertical: vertical || (scrolls && !strip), sideways: sideways || strip) }
        }
        walk(root, vertical: false, sideways: false)
        guard !found.isEmpty else { return }
        let list = XCTAttachment(string: "screen \(Int(screen.width))x\(Int(screen.height))\n" + found.joined(separator: "\n"))
        list.name = "OVERFLOW \(name)"
        list.lifetime = .keepAlways
        add(list)
        if environment["GAGA_WALK_OVERFLOW"] != "record" {
            XCTFail("\(name): \(found.count) elements run past the window, first \(found[0])")
        }
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

    /// Opens a root tab (Library, Import, Style, Settings) from the rail or the bar.
    private func goTo(_ app: XCUIApplication, _ tab: String) {
        guard !promptUp() else { return }
        // Not the Settings category of the same name, such as Library.
        let button = app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH 'settings.') AND NOT (identifier BEGINSWITH 'style.')", tab)).firstMatch
        tap(button, "The \(tab) tab")
        sleep(1)
        // A tap made while a menu is open only closes the menu.
        if button.exists, !button.isSelected {
            button.tap()
            sleep(1)
        }
    }

    /// Plays a game: a tap on its cover opens its page, and Play (or Resume) there starts it.
    private func play(_ app: XCUIApplication, _ tile: XCUIElement) {
        tap(tile, "The game's cover")
        tap(startOnPage(app), "Play on the game's page")
    }

    /// The game page's Play, or Resume once the game has an auto save.
    private func startOnPage(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier IN %@", ["gamePage.play", "gamePage.resume"])).firstMatch
    }

    /// Opens a Style page by its identifier, such as `Skins` or `Library Layout`.
    @discardableResult private func styleSection(_ app: XCUIApplication, _ name: String) -> Bool {
        goTo(app, "Style")
        return selectTab(app, name, prefix: "style")
    }

    /// Selects a Settings tab and checks it took. The tabs sit under where a notification banner drops: a tap
    /// on the banner opens its app (seen on the iPhone), so GagaEmu is brought back and the tap made again.
    @discardableResult private func selectTab(_ app: XCUIApplication, _ name: String, prefix: String = "settings") -> Bool {
        let tab = app.buttons["\(prefix).\(name)"].firstMatch
        for _ in 0..<3 where !promptUp() {
            if app.state != .runningForeground {
                app.activate()
                sleep(6) // Lets the banner leave.
            }
            guard tab.waitForExistence(timeout: 6) else { continue }
            reveal(tab)
            tab.tap()
            sleep(1)
            if app.state == .runningForeground, tab.isSelected { return true }
        }
        XCTFail("The \(name) tab could not be selected")
        return false
    }

    /// Upright on a phone the category tabs are a sideways strip, and in landscape a sidebar list, so a tab past
    /// the edge is scrolled to first. Only identified elements are looked for in a scroll view.
    private func reveal(_ element: XCUIElement) {
        let app = XCUIApplication()
        guard element.exists, !element.identifier.isEmpty else { return }
        let screen = app.windows.firstMatch.frame
        guard !screen.contains(element.frame) else { return }
        let strip = app.scrollViews.containing(.any, identifier: element.identifier).firstMatch
        for forward in [true, true, true, false, false, false, false, false] where !screen.contains(element.frame) && strip.exists {
            switch (strip.frame.width > strip.frame.height, forward) {
            case (true, true): strip.swipeLeft()
            case (true, false): strip.swipeRight()
            case (false, true): strip.swipeUp()
            case (false, false): strip.swipeDown()
            }
            sleep(1)
        }
    }

    private func auditPage(_ app: XCUIApplication, _ prefix: String, as name: String) {
        guard open(app, prefix) else { return }
        audit(name)
        close(app)
    }

    /// Library, the game page and its long-press sheets, Import, every Style page and every Settings page, each
    /// upright and in landscape.
    func testAuditScreens() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        sleep(1)
        audit("01 Library")
        let cover = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        if !promptUp(), cover.waitForExistence(timeout: 6) {
            cover.tap()
            sleep(1)
            if app.buttons["gamePage.play"].waitForExistence(timeout: 6) || app.buttons["gamePage.resume"].exists {
                audit("02 Game page")
                for (entry, name) in [("gamePage.skin", "Skin"), ("gamePage.core", "Core"), ("gamePage.saves", "Save States"), ("gamePage.cheats", "Cheats"), ("gamePage.controls", "Controls")] {
                    let row = app.buttons[entry].firstMatch
                    guard !promptUp(), row.waitForExistence(timeout: 4) else { snapshot("MISSING \(entry)"); continue }
                    row.tap()
                    sleep(1)
                    XCTAssertFalse(app.buttons["Pause game"].exists, "\(name) on the game's page started the game")
                    audit("02 Game page \(name)")
                    close(app)
                }
                // A sheet the subpage left open is closed too, so the page itself goes.
                for _ in 0..<3 where app.buttons["gamePage.delete"].exists { close(app) }
            } else {
                snapshot("MISSING game page")
            }
        }
        for (index, entry) in ["Change Core", "Choose Filter", "Assign Skin", "Manage Saves", "Edit Details", "Delete"].enumerated() {
            let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            guard !promptUp(), tile.waitForExistence(timeout: 6) else { continue }
            tile.press(forDuration: 1.2)
            sleep(1)
            if index == 0 { snapshot("02 Library menu portrait") }
            auditPage(app, entry, as: "03 Game \(entry)")
        }
        goTo(app, "Import")
        audit("04 Import")
        auditPage(app, "Multi-Disc", as: "05 Import Multi-Disc")
        auditPage(app, "Patch a ROM", as: "05 Import Patch")
        for section in ["Skins", "Filters", "Icon and Colours", "Library Layout"] where styleSection(app, section) {
            audit("06 Style \(section)")
            if section == "Skins" {
                let edit = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "skin")).firstMatch
                if edit.waitForExistence(timeout: 6) {
                    edit.tap()
                    sleep(2)
                    audit("07 Skin Editor")
                    cancel(app)
                }
            }
            if section == "Filters" { auditPage(app, "Open Filter Studio", as: "07 Filter Studio") }
        }
        goTo(app, "Settings")
        for category in ["Profile", "Gameplay", "Controllers", "Screen", "Systems", "Library", "Storage and Sync", "Help"] {
            // By identifier, as the rail has a Library button too.
            let row = app.buttons["settings.\(category)"].firstMatch
            if !promptUp(), row.waitForExistence(timeout: 6) {
                reveal(row)
                XCTAssertTrue(row.isHittable, "The \(category) tab is off the screen")
                row.tap()
                sleep(1)
                audit("06 Settings \(category)")
            }
            switch category {
            case "Systems": auditPage(app, "BIOS Files", as: "07 BIOS")
            case "Screen": auditPage(app, "Screen, Scaling", as: "07 Screen")
            case "Controllers":
                auditPage(app, "Players", as: "07 Players")
                auditPage(app, "Controller Mapping", as: "07 Mapping")
                auditPage(app, "Macros", as: "07 Macros")
                auditPage(app, "Turbo", as: "07 Turbo")
            case "Help":
                auditPage(app, "Guides", as: "07 Guides")
                auditPage(app, "About Us", as: "07 About Us")
                auditPage(app, "Licences", as: "07 Licences")
            default: break
            }
        }
    }

    /// Every main screen upright at the largest accessibility text size, each with the bounds check: nothing runs
    /// past the window and no row is cut off by the edges.
    func testAuditLargeText() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-GagaImportTestROM", core, "-GagaDefaultDisplay", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let cover = importedGame(app, "The \(title) game")
        sleep(3)
        try stopIfPrompt()
        func shoot(_ name: String) {
            sleep(2)
            snapshot("AX \(name)")
            checkBounds("AX \(name)")
        }
        shoot("01 Library")
        tap(cover, "The cover")
        _ = startOnPage(app).waitForExistence(timeout: timeout)
        shoot("02 Game page")
        app.swipeUp()
        shoot("02 Game page scrolled")
        close(app)
        goTo(app, "Import")
        shoot("03 Import")
        for section in ["Skins", "Filters", "Icon and Colours", "Library Layout"] where styleSection(app, section) {
            shoot("04 Style \(section)")
        }
        goTo(app, "Settings")
        for category in ["Profile", "Gameplay", "Controllers", "Screen", "Systems", "Library", "Storage and Sync", "Help"] where selectTab(app, category) {
            shoot("05 Settings \(category)")
        }
        let field = app.textFields["Search settings"].firstMatch
        try enter(app, field, "skin", "The settings search field")
        shoot("06 Search skin")
        goTo(app, "Settings")
        if selectTab(app, "Systems") {
            let row = app.buttons["core.\(core)"].firstMatch
            if row.waitForExistence(timeout: 6) {
                row.tap()
                shoot("07 Core options")
                close(app)
            }
        }
        goTo(app, "Library")
        play(app, cover)
        let pause = app.buttons["Pause game"]
        try arrive(pause, "The game")
        sleep(3)
        shoot("08 Playing")
        pause.tap()
        shoot("09 Pause menu")
        app.swipeUp()
        shoot("09 Pause menu scrolled")
        // A grid Library at this size: one column, each card a row beside its cover.
        app.terminate()
        app.launchArguments += ["-GagaPerRow", "3"]
        app.launch()
        let card = importedGame(app, "The \(title) game in a grid")
        shoot("10 Library grid")
        XCTAssertGreaterThan(card.frame.width, app.windows.firstMatch.frame.width * 0.6, "The grid card is not one full-width row")
    }

    /// Batch 2: Settings search finds a setting by the word people use, and opens it.
    func testSettingsSearch() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        sleep(2)
        try guardedTap(app.buttons["Settings"].firstMatch, "Settings in the bar")
        let field = app.textFields["Search settings"].firstMatch
        try enter(app, field, "skin", "The settings search field")
        snapshot("80 Search skin")
        try guardedTap(app.buttons["settingsResult.Skins"].firstMatch, "The Skins result")
        try arrive(app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "skin")).firstMatch, "A skin's Edit button in Style")
        XCTAssertTrue(app.buttons["style.Skins"].firstMatch.isSelected, "Search did not open Style > Skins")
        snapshot("80 Search reached Skins")
        try guardedTap(app.buttons["Settings"].firstMatch, "Settings again")
        try enter(app, field, "bios", "The settings search field again")
        try guardedTap(app.buttons["settingsResult.BIOS Files"].firstMatch, "The BIOS Files result")
        try arrive(app.staticTexts["Required"].firstMatch, "The BIOS list")
        snapshot("81 Search reached BIOS")
        close(app)
        try enter(app, field, "username", "The settings search field for a username")
        try arrive(app.buttons["settingsResult.Player Name"].firstMatch, "The Player Name result")
        snapshot("82 Search username")
    }

    /// Search, open a result, back to Settings, ten times, with the keyboard up each time a result is picked. Opening
    /// Style from a result once left the app busy for good, so every round must finish in well under a minute. Odd
    /// rounds open a Style page; even rounds a Settings row, which flashes. The first rounds also try the area chips.
    func testSettingsSearchRepeat() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        sleep(2)
        let field = app.textFields["Search settings"].firstMatch
        var laps: [String] = []
        for round in 1...10 {
            let lap = Date()
            try guardedTap(app.buttons["Settings"].firstMatch, "Settings, round \(round)")
            if round.isMultiple(of: 2) {
                try enter(app, field, "rewind", "The search field, round \(round)")
                if round == 2 {
                    // The area chips: Gameplay keeps Rewind, Controllers has no match for it.
                    try arrive(app.buttons["searchScope.Gameplay"].firstMatch, "The Gameplay area chip")
                    snapshot("83 Search areas")
                    app.buttons["searchScope.Gameplay"].firstMatch.tap()
                    XCTAssertTrue(app.buttons["settingsResult.Rewind"].firstMatch.waitForExistence(timeout: 4), "Rewind left the Gameplay area")
                    app.buttons["searchScope.all"].firstMatch.tap()
                }
                try guardedTap(app.buttons["settingsResult.Rewind"].firstMatch, "The Rewind result, round \(round)")
                try arrive(app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Rewind")).firstMatch, "The Rewind row, round \(round)")
                XCTAssertTrue(app.buttons["settings.Gameplay"].firstMatch.isSelected, "Round \(round) did not open Gameplay")
                if round == 2 { snapshot("84 Search result flashes") }
            } else {
                try enter(app, field, "skin", "The search field, round \(round)")
                try guardedTap(app.buttons["settingsResult.Skins"].firstMatch, "The Skins result, round \(round)")
                try arrive(app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "skin")).firstMatch, "Style > Skins, round \(round)")
                XCTAssertTrue(app.buttons["style.Skins"].firstMatch.isSelected, "Round \(round) did not open Style > Skins")
                XCTAssertFalse(app.keyboards.firstMatch.exists, "Round \(round): the keyboard stayed up over Style")
                if round == 1 {
                    snapshot("86 Search opened Style")
                    dumpTree(app, "86 hierarchy")
                }
            }
            let seconds = Date().timeIntervalSince(lap)
            laps.append("round \(round)\t\(String(format: "%.1f", seconds)) s")
            XCTAssertLessThan(seconds, 30, "Round \(round) took \(Int(seconds)) s: the app stayed busy")
        }
        let report = XCTAttachment(string: laps.joined(separator: "\n"))
        report.name = "LAPS"
        report.lifetime = .keepAlways
        add(report)
        print("LAPS\n" + laps.joined(separator: "\n"))
        snapshot("85 Search after ten rounds")
    }

    /// The 20 most-used features of docs/ux-redesign.md section 1, each reached from the Library and its taps
    /// counted, against that table's counts. The counts go into the result bundle as `TAPS` and the log.
    func testTopFeatureTaps() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        let cover = importedGame(app, "The \(title) game")
        sleep(8)
        try stopIfPrompt()
        var taps = 0
        var rows: [(name: String, old: Int, new: Int, reached: Bool)] = []
        let pause = app.buttons["Pause game"]
        func count(_ element: XCUIElement, _ what: String) {
            tap(element, what)
            taps += 1
            sleep(1)
        }
        func record(_ name: String, old: Int, _ goal: XCUIElement) {
            let reached = goal.waitForExistence(timeout: 10)
            XCTAssertTrue(reached, "\(name) was not reached")
            rows.append((name, old, taps, reached))
            snapshot("90 \(rows.count) \(name)")
            taps = 0
        }
        /// Back to the Library with nothing open, uncounted.
        func home() {
            for _ in 0..<3 where app.buttons["Close"].firstMatch.exists || app.buttons["Cancel"].firstMatch.exists { close(app) }
            // A game still starting can ignore Pause, so it is tapped until the menu shows.
            let quit = button(app, "Quit to Library")
            for _ in 0..<4 where pause.exists && !quit.exists {
                pause.tap()
                _ = quit.waitForExistence(timeout: 4)
            }
            if quit.exists {
                quit.tap()
                sleep(3)
            }
            goTo(app, "Library")
        }
        /// Starts the game, uncounted, for the in-game features.
        func inGame() {
            home()
            play(app, cover)
            _ = pause.waitForExistence(timeout: timeout)
            sleep(3)
        }

        // 1 Resume last game: the Continue panel's Play.
        home()
        count(app.buttons["Play \(title)"].firstMatch, "Continue's Play")
        record("Resume last game", old: 1, pause)
        // 2 Start any game: the cover, then Play.
        home()
        count(cover, "The cover")
        count(app.buttons["gamePage.play"].firstMatch, "Play")
        record("Start any game", old: 2, pause)
        // 3 Import from Files: the tab, and the button that opens the system's file picker (not opened here).
        home()
        count(app.buttons["Import"].firstMatch, "Import")
        taps += 1
        record("Import from Files", old: 2, button(app, "Choose from Files"))
        // 4 and 5 Save and load a state.
        inGame()
        count(pause, "Pause")
        count(button(app, "Save State"), "Save State")
        record("Save state", old: 2, button(app, "Save State, Saved"))
        count(button(app, "Load State"), "Load State")
        count(button(app, "Load Save state"), "The saved state")
        record("Load state", old: 3, pause)
        // 6 Fast forward: the in-game button.
        count(app.buttons["Fast forward"].firstMatch, "Fast forward")
        record("Fast forward", old: 1, pause)
        // 7 Skin for every game on a system: Style opens on Skins; a picture picks it.
        home()
        count(app.buttons["Style"].firstMatch, "Style")
        let skin = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " skin: ")).element(boundBy: 1)
        count(skin, "A skin picture")
        record("Change skin, all games", old: 4, app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " skin: ")).firstMatch)
        // 8 Skin for one game: the cover, Skin, a choice.
        home()
        count(cover, "The cover")
        count(app.buttons["gamePage.skin"].firstMatch, "Skin")
        record("Change skin, one game", old: 3, button(app, "Platform Default"))
        // 9 Edit a skin's layout: Style, then Edit beside a system.
        home()
        count(app.buttons["Style"].firstMatch, "Style")
        count(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Edit ' AND label ENDSWITH ' skin'")).firstMatch, "Edit")
        record("Edit skin layout", old: 4, app.buttons["Cancel"].firstMatch)
        // 10 Default filter: Style, Filters, a picture.
        home()
        count(app.buttons["Style"].firstMatch, "Style")
        count(app.buttons["style.Filters"].firstMatch, "Filters")
        count(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'styleFilter.'")).element(boundBy: 1), "A filter picture")
        record("Default filter", old: 3, app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'styleFilter.'")).firstMatch)
        // 11 Filter for one game: the cover, Filter.
        home()
        count(cover, "The cover")
        count(app.buttons["gamePage.filter"].firstMatch, "Filter")
        record("Filter, one game", old: 3, app.textFields["Search filters"].firstMatch)
        // 12 Change core: the cover, Core.
        home()
        count(cover, "The cover")
        count(app.buttons["gamePage.core"].firstMatch, "Core")
        record("Change core", old: 3, app.staticTexts["Change Core"].firstMatch)
        // 13 and 14 Core options and cheats, from the pause menu.
        inGame()
        count(pause, "Pause")
        count(app.buttons["pause.coreOptions"].firstMatch, "Core Options")
        record("Core options", old: 2, app.buttons["coreOptions.resetAll"].firstMatch)
        close(app)
        taps += 1 // Pause, still open from Core Options, counts for Cheats too.
        count(button(app, "Cheats"), "Cheats")
        record("Cheats", old: 3, app.buttons["Import .cht File"].firstMatch)
        // 15 to 19 in Settings.
        home()
        count(app.buttons["Settings"].firstMatch, "Settings")
        count(app.buttons["settings.Controllers"].firstMatch, "Controllers")
        count(button(app, "Controller Mapping"), "Controller Mapping")
        record("Controller mapping", old: 3, app.buttons["Close"].firstMatch)
        home()
        count(app.buttons["Settings"].firstMatch, "Settings")
        count(app.buttons["settings.Controllers"].firstMatch, "Controllers")
        record("Controller player slots", old: 2, app.buttons["settingsPlayers"].firstMatch)
        home()
        count(app.buttons["Settings"].firstMatch, "Settings")
        count(app.buttons["settings.Systems"].firstMatch, "Systems")
        count(button(app, "BIOS Files"), "BIOS Files")
        record("BIOS files", old: 3, app.staticTexts["Required"].firstMatch)
        home()
        count(app.buttons["Settings"].firstMatch, "Settings")
        count(app.buttons["settings.Profile"].firstMatch, "Profile")
        taps -= 1 // Profile is where Settings opens: that tap only makes sure of it.
        count(button(app, "RetroAchievements"), "RetroAchievements")
        record("RetroAchievements sign-in", old: 3, app.textFields["raUsername"].firstMatch)
        home()
        count(app.buttons["Settings"].firstMatch, "Settings")
        count(app.buttons["settings.Storage and Sync"].firstMatch, "Storage and Sync")
        taps += 1 // The switch itself, not flipped here: it would start syncing.
        record("iCloud Sync", old: 3, app.switches["icloudSyncToggle"].firstMatch)
        // 20 Library layout: Style, Library Layout.
        home()
        count(app.buttons["Style"].firstMatch, "Style")
        count(app.buttons["style.Library Layout"].firstMatch, "Library Layout")
        record("Library layout", old: 2, app.buttons["Framed"].firstMatch)

        let table = rows.enumerated().map { "\($0.offset + 1)\t\($0.element.name)\told \($0.element.old)\tnew \($0.element.new)\($0.element.reached ? "" : "\tNOT REACHED")" }
        let report = (table + ["TOTAL\told \(rows.map(\.old).reduce(0, +))\tnew \(rows.map(\.new).reduce(0, +))"]).joined(separator: "\n")
        print("TAPS\n" + report)
        let attachment = XCTAttachment(string: report)
        attachment.name = "TAPS"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(rows.count, 20, "Not every feature was walked")
        for row in rows { XCTAssertLessThanOrEqual(row.new, row.old, "\(row.name) takes more taps than before") }
        XCTAssertLessThan(rows.map(\.new).reduce(0, +), rows.map(\.old).reduce(0, +), "The redesign does not save taps overall")
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
        guard !promptUp(), styleSection(app, "Icon and Colours") else { return }
        audit("20 Icon and Colours default")
        for choice in ["Light", "Teal"] where !promptUp() {
            app.buttons[choice].firstMatch.tap()
            sleep(1)
        }
        guard styleSection(app, "Library Layout") else { return }
        audit("20 Library Layout default")
        for choice in ["3", "Framed"] where !promptUp() {
            app.buttons[choice].firstMatch.tap()
            sleep(1)
        }
        for toggle in ["Square Covers", "Hide Details"] where !promptUp() { flip(app, toggle) }
        if open(app, "Shelf Title") { open(app, "Maker") }
        audit("21 Library Layout changed")
        goTo(app, "Library")
        open(app, "All games")
        audit("22 Library three per row")
        dumpTree(app, "22 hierarchy")
        if open(app, "Sort games") {
            snapshot("23 Sort menu portrait")
            open(app, "Title")
        }
        guard styleSection(app, "Library Layout") else { return }
        for choice in ["5", "Plain"] where !promptUp() {
            app.buttons[choice].firstMatch.tap()
            sleep(1)
        }
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 1)
        sleep(1)
        for toggle in ["Hide Game Titles", "Hide Scroll Indicators"] where !promptUp() { flip(app, toggle) }
        if open(app, "Shelf Title") { open(app, "Short Code") }
        audit("25 Library Layout second pass")
        goTo(app, "Library")
        audit("26 Library five per row")
        dumpTree(app, "26 hierarchy")
        guard styleSection(app, "Library Layout") else { return }
        flip(app, "Hide Shelf Titles")
        goTo(app, "Library")
        audit("27 Library no shelf titles")
        guard styleSection(app, "Icon and Colours") else { return }
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
            XCTFail("No custom colour well on Style > Icon and Colours")
        }
        goTo(app, "Settings")
        guard !promptUp(), selectTab(app, "Systems") else { return }
        XCTAssertTrue(button(app, "BIOS Files").waitForExistence(timeout: 6), "No BIOS Files row on the Systems tab")
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
        guard !promptUp(), styleSection(app, "Filters") else { return }
        guard open(app, "Open Filter Studio") else { return }
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

    /// The pause menu's Play Nearby, on every system. Where it can play nearby, Host must reach the waiting screen,
    /// with no second phone; elsewhere the sheet must say why not. A local network prompt stops it untouched.
    private func auditNearby(_ app: XCUIApplication, tag: String) {
        let row = app.buttons["playNearby"].firstMatch
        guard !promptUp(), row.waitForExistence(timeout: 6) else {
            snapshot("MISSING \(tag) Play Nearby")
            XCTFail("\(tag): no Play Nearby row in the pause menu")
            return
        }
        row.tap()
        sleep(1)
        audit("\(tag) Play Nearby")
        let host = app.buttons["Host"].firstMatch
        if host.exists {
            host.tap()
            let waiting = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Waiting for a nearby phone")).firstMatch
            let reached = waiting.waitForExistence(timeout: 15)
            snapshot("\(tag) Play Nearby hosting")
            guard !promptUp() else { return }
            XCTAssertTrue(reached, "\(tag): Host did not reach the waiting screen")
            if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() } // Stops hosting.
            sleep(1)
        } else {
            let why = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "not available")).firstMatch
            XCTAssertTrue(why.exists, "\(tag): Play Nearby is off with no reason given")
        }
        close(app)
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
        play(app, app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, platform)).firstMatch)
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
        auditPage(app, "Skin", as: "\(tag) Pause Skin")
        if open(app, "Filter") {
            sleep(2)
            audit("\(tag) Pause Filter")
            close(app)
        }
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
        auditNearby(app, tag: tag)
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
        app.swipeDown(velocity: .fast) // Leaves the menu.
        goTo(app, "Settings")
        if selectTab(app, "Controllers"), open(app, "Players") {
            audit("41 Players from Settings Controllers")
            close(app)
        }
        goTo(app, "Import")
        audit("42 Import")
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
        goTo(app, "Settings")
        tap(app.buttons["settings.Gameplay"].firstMatch, "The Gameplay tab")
        sleep(1)
        audit("45 Gameplay")
        tap(app.buttons["settings.Screen"].firstMatch, "The Screen tab")
        sleep(1)
        audit("46 Screen")
        tap(app.buttons["settings.Systems"].firstMatch, "The Systems tab")
        sleep(1)
        auditPage(app, "BIOS Files", as: "47 BIOS optional")
        tap(app.buttons["settings.Help"].firstMatch, "The Help tab")
        sleep(1)
        audit("48 Help")
        auditPage(app, "Guides", as: "49 Guides")
    }

    /// A catalogue filter on a texture-path Vulkan core, then that game's own picture from a save in the picker.
    func testAuditShaderOnVulkanCore() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-GagaImportTestROM", "ppsspp"]
        app.launch()
        _ = importedGame(app, "The \(title) game")
        sleep(6)
        guard !promptUp() else { return }
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "PSP")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: timeout), "No PSP tile")
        tile.press(forDuration: 1.2)
        sleep(1)
        XCTAssertTrue(open(app, "Choose Filter"), "No Choose Filter")
        XCTAssertTrue(open(app, "System"), "No System scope")
        XCTAssertTrue(open(app, "Show Scanlines"), "No Scanlines chip")
        sleep(1)
        tap(app.buttons["Thick Scanlines"].firstMatch, "Thick Scanlines")
        sleep(1)
        close(app)
        guard !promptUp() else { return }
        play(app, tile)
        let pause = app.buttons["Pause game"]
        guard pause.waitForExistence(timeout: timeout) else {
            snapshot("78 PSP did not start")
            return
        }
        sleep(5)
        audit("78 Vulkan core with a filter")
        guard !promptUp() else { return }
        pause.tap()
        sleep(1)
        tap(button(app, "Save State"), "Save State")
        sleep(2)
        tap(button(app, "Quit to Library"), "Quit to Library")
        XCTAssertTrue(tile.waitForExistence(timeout: timeout), "Quit did not return to the Library")
        sleep(1)
        tile.press(forDuration: 1.2)
        sleep(1)
        XCTAssertTrue(open(app, "Choose Filter"), "No Choose Filter")
        XCTAssertTrue(app.buttons["Use built-in preview image"].firstMatch.waitForExistence(timeout: 6), "The game's own picture was not used")
        sleep(3)
        audit("79 Filter on the game's picture")
        close(app)
    }

    /// The filter catalogue, every control: categories, search, favourites, compare, sliders, and each scope.
    func testAuditShaderCatalogue() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-GagaImportTestROM", core]
        app.launch()
        let game = importedGame(app, "The \(title) game")
        sleep(8)
        guard !promptUp(), styleSection(app, "Filters") else { return }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'styleFilter.'")).firstMatch.waitForExistence(timeout: 6),
                      "No filter pictures in Style > Filters")
        snapshot("70 Style filters gallery")
        XCTAssertTrue(open(app, "Open Filter Studio"), "No Open Filter Studio")
        XCTAssertTrue(button(app, "Show CRT").waitForExistence(timeout: 6), "No category strip")
        sleep(3)
        audit("70 Filter catalogue")
        for chip in ["Show CRT", "Show LCD and Handheld", "Show Scanlines", "Show Upscaling", "Show Smoothing", "Show Colour", "Show Sharpen", "Show Retro Looks"] {
            XCTAssertTrue(open(app, chip), "No \(chip)")
            sleep(2)
            XCTAssertTrue(app.buttons["Add "].exists || app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ' OR label BEGINSWITH 'Remove '")).firstMatch.exists, "\(chip) shows no tiles")
            snapshot("71 \(chip)")
        }
        open(app, "Show All")
        let aperture = app.buttons["Aperture Grille"].firstMatch
        let search = app.textFields["Search filters"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 4), "No search")
        search.tap()
        search.typeText("xbr")
        sleep(2)
        XCTAssertTrue(app.buttons["xBR Style"].firstMatch.exists, "Search did not find xBR Style")
        XCTAssertFalse(aperture.exists, "Search left Aperture Grille")
        snapshot("72 Filter search xbr")
        app.keyboards.buttons["search"].firstMatch.tap()
        sleep(1)
        let tile = app.buttons["xBR Style"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 4), "No xBR tile")
        tile.tap()
        sleep(2)
        XCTAssertTrue(tile.isSelected, "The tile is not marked selected")
        let star = app.buttons["Add xBR Style to favourites"].firstMatch
        XCTAssertTrue(star.exists, "No favourite control")
        star.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["Remove xBR Style from favourites"].firstMatch.exists, "The star did not turn on")
        let compare = app.buttons["Compare before and after"].firstMatch
        XCTAssertTrue(compare.exists, "No compare button")
        compare.tap()
        sleep(2)
        XCTAssertTrue(app.otherElements["Before and after divider"].firstMatch.exists || app.descendants(matching: .any)["Before and after divider"].firstMatch.exists, "No divider")
        audit("73 Filter compare")
        XCTAssertTrue(app.sliders["Softness"].firstMatch.exists, "No Softness slider for xBR Style")
        XCTAssertTrue(app.sliders["Colour"].firstMatch.exists, "No Colour slider")
        app.sliders["Softness"].firstMatch.adjust(toNormalizedSliderPosition: 0.9)
        sleep(1)
        snapshot("74 Filter slider")
        compare.tap()
        search.tap()
        search.buttons.firstMatch.exists ? search.buttons.firstMatch.tap() : search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        app.keyboards.buttons["search"].firstMatch.tap()
        sleep(1)
        XCTAssertTrue(open(app, "Show Favourites"), "No favourites chip")
        sleep(1)
        XCTAssertTrue(app.buttons["xBR Style"].firstMatch.exists, "Favourites does not list the starred filter")
        snapshot("75 Filter favourites")
        close(app)
        guard !promptUp() else { return }
        goTo(app, "Library")
        sleep(2)
        _ = game
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 6), "No game in the Library")
        library.press(forDuration: 1.2)
        sleep(1)
        XCTAssertTrue(open(app, "Choose Filter"), "No Choose Filter")
        XCTAssertTrue(button(app, "This Game").waitForExistence(timeout: 6) || app.segmentedControls["filterScope"].firstMatch.exists, "No scope picker")
        sleep(3)
        audit("76 Filter for a game")
        let system = app.buttons["System"].firstMatch
        XCTAssertTrue(system.exists, "No System scope")
        system.tap()
        sleep(1)
        XCTAssertTrue(open(app, "Show Colour"), "No Colour chip in game scope")
        // A tile in the first row: a tap on a half-visible one can land on its star.
        let tint = app.buttons["S-Video"].firstMatch
        XCTAssertTrue(tint.waitForExistence(timeout: 4), "No S-Video tile")
        tint.tap()
        sleep(1)
        XCTAssertTrue(tint.isSelected, "System filter did not select")
        XCTAssertTrue(app.buttons["Clear this system's filter"].firstMatch.exists, "No Clear for a system filter")
        snapshot("77 Filter for a system")
        app.buttons["Clear this system's filter"].firstMatch.tap()
        sleep(1)
        close(app)
    }

    /// Batch 3: RomM sign-in, the download rows, patch creation, the filter preview picture and the app icons, each
    /// upright and in landscape. An icon is never tapped: changing it raises a system notice this walk must not answer.
    func testAuditManic3() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-GagaImportTestROM", core, "-GagaSeedDownloads", "YES", "-GagaPreviewImage", "YES"]
        app.launch()
        _ = importedGame(app, "The \(title) game")
        sleep(10)
        goTo(app, "Import")
        XCTAssertTrue(app.staticTexts["Sample One.gba"].waitForExistence(timeout: 6), "No download row")
        XCTAssertTrue(app.staticTexts["Downloading"].exists, "The first download is not running")
        XCTAssertTrue(app.staticTexts["Waiting"].exists, "The second download is not waiting")
        audit("60 Add with downloads")
        XCTAssertTrue(open(app, "RomM Server"), "No RomM row")
        audit("61 RomM sign in")
        let field = app.textFields["Server address"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4), "No RomM address field")
        if !promptUp() {
            field.tap()
            field.typeText("http://example.test")
            app.keyboards.buttons["return"].firstMatch.tap()
            sleep(1)
            open(app, "Connect")
            XCTAssertTrue(app.staticTexts["This address is not encrypted. Turn on Allow Unencrypted HTTP to use it."].waitForExistence(timeout: 6),
                          "Plain HTTP was not refused")
            snapshot("61 RomM plain HTTP refused")
        }
        close(app)
        guard !promptUp() else { return }
        // A download row's Cancel removes it; the queue rows are shared, so this is the sheet's too.
        let cancelRow = app.buttons["Cancel Sample Two.gba"].firstMatch
        XCTAssertTrue(cancelRow.waitForExistence(timeout: 4), "No Cancel on the waiting download")
        cancelRow.tap()
        sleep(1)
        XCTAssertFalse(app.staticTexts["Sample Two.gba"].exists, "Cancel left the waiting download")
        XCTAssertTrue(open(app, "Patch a ROM"), "No Patch row")
        let create = app.buttons["Create"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 4), "No Create mode")
        create.tap()
        sleep(1)
        XCTAssertTrue(button(app, "Create UPS Patch").exists, "Create mode did not switch")
        audit("62 Patch create")
        close(app)
        guard !promptUp(), styleSection(app, "Filters") else { return }
        XCTAssertTrue(open(app, "Open Filter Studio"), "No Open Filter Studio")
        XCTAssertTrue(app.buttons["Choose preview image"].firstMatch.waitForExistence(timeout: 6), "No preview picture button")
        XCTAssertTrue(app.buttons["Use built-in preview image"].firstMatch.exists, "The seeded picture was not taken")
        audit("63 Filter preview picture")
        app.buttons["Use built-in preview image"].firstMatch.tap()
        sleep(1)
        XCTAssertFalse(app.buttons["Use built-in preview image"].firstMatch.exists, "The built-in picture did not come back")
        snapshot("63 Filter preview built in")
        close(app)
        guard !promptUp(), styleSection(app, "Icon and Colours") else { return }
        let icon = app.buttons["App icon, Phosphor"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 6), "No app icon choices")
        XCTAssertTrue(app.buttons["App icon, Steps"].firstMatch.isSelected, "The primary icon is not marked")
        audit("64 Display app icons")
    }

    /// The maker filter, picking discs by hand, and the BIOS list's Optional section.
    func testMakerFilterAndDiscPicker() {
        XCUIDevice.shared.orientation = .portrait
        let psp = XCUIApplication()
        psp.launchArguments = ["-GagaImportTestROM", "ppsspp"]
        psp.launch()
        _ = importedGame(psp, "The ppsspp game")
        // Another walk's game can be listed already, so the PSP one itself is waited for before the relaunch.
        _ = psp.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "PSP")).firstMatch
            .waitForExistence(timeout: importTimeout)
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

        goTo(app, "Import")
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

        goTo(app, "Settings")
        tap(app.buttons["settings.Systems"].firstMatch, "The Systems tab")
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
        tap(app.buttons["settings.Help"].firstMatch, "The Help tab")
        sleep(1)
        XCTAssertTrue(button(app, "Idioma").waitForExistence(timeout: 6), "No Idioma row")
        audit("50 Spanish Help")
    }

    /// Auto Save State: on, play, quit, and playing again offers Resume.
    func testAutoSaveOffersResume() {
        let app = launchApp()
        let game = importedGame(app, "The \(title) game")
        sleep(10)
        guard !promptUp() else { return }
        tap(app.buttons["Settings"].firstMatch, "Settings")
        sleep(1)
        guard selectTab(app, "Gameplay") else { return }
        flip(app, "Auto Save State")
        snapshot("51 Auto Save on")
        goTo(app, "Library")
        sleep(1)
        play(app, game)
        let pause = app.buttons["Pause game"]
        XCTAssertTrue(pause.waitForExistence(timeout: timeout), "The game did not start")
        sleep(4)
        pause.tap()
        tap(button(app, "Quit to Library"), "Quit to Library")
        XCTAssertTrue(game.waitForExistence(timeout: timeout), "Quit did not return to the Library")
        sleep(1)
        game.tap()
        // The game's page offers Resume itself, with no alert in between.
        let resume = app.buttons["gamePage.resume"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: timeout), "No Resume on the game's page after quitting with Auto Save on")
        XCTAssertTrue(app.buttons["gamePage.startOver"].exists, "No Start Over beside Resume")
        snapshot("51 Resume offer")
        close(app)
    }

    /// Leaves an editor whose parent sheet also has a Close button.
    private func cancel(_ app: XCUIApplication) {
        if promptUp() { return }
        app.buttons["Cancel"].firstMatch.tap()
        sleep(1)
    }

    /// Every skin picture, Core Options from Settings and from the game, and the pause menu with each of its sheets,
    /// upright and in landscape, so a redesign of them is shot before and after in one walk.
    func testAuditSkinsAndMenus() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = importedGame(app, "The \(title) game")
        sleep(2)
        if styleSection(app, "Skins") { audit("R2 01 Style Skins") }
        goTo(app, "Library")
        let cover = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        if !promptUp(), cover.waitForExistence(timeout: 6) {
            cover.tap()
            sleep(1)
            if startOnPage(app).waitForExistence(timeout: 6) {
                audit("R2 02 Game page")
                let row = app.buttons["gamePage.skin"].firstMatch
                if !promptUp(), row.waitForExistence(timeout: 4) {
                    row.tap()
                    sleep(1)
                    audit("R2 03 Game page Skin")
                    close(app)
                }
                for _ in 0..<3 where app.buttons["gamePage.delete"].exists { close(app) }
            }
        }
        goTo(app, "Settings")
        if selectTab(app, "Controllers") { audit("R2 04 Settings Controllers") }
        if selectTab(app, "Systems") {
            let row = app.buttons["core.\(core)"].firstMatch
            if !promptUp(), row.waitForExistence(timeout: 6) {
                row.tap()
                sleep(1)
                audit("R2 05 Settings Core Options")
                close(app)
            }
        }
        goTo(app, "Library")
        guard !promptUp(), cover.waitForExistence(timeout: 6) else { return }
        play(app, cover)
        let pause = app.buttons["Pause game"]
        guard pause.waitForExistence(timeout: timeout) else {
            snapshot("R2 game did not start")
            return
        }
        sleep(4)
        audit("R2 06 Playing")
        guard !promptUp() else { return }
        pause.tap()
        sleep(1)
        audit("R2 07 Pause")
        app.swipeUp()
        sleep(1)
        snapshot("R2 07 Pause scrolled portrait")
        app.swipeDown()
        if !promptUp(), app.buttons["pause.coreOptions"].firstMatch.waitForExistence(timeout: 4) {
            app.buttons["pause.coreOptions"].firstMatch.tap()
            sleep(1)
            audit("R2 08 Game Core Options")
            close(app)
        }
        auditPage(app, "Load State", as: "R2 09 Save States")
        auditPage(app, "Skin", as: "R2 10 Pause Skin")
        if open(app, "Filter") {
            sleep(2)
            audit("R2 11 Pause Filter")
            close(app)
        }
        auditPage(app, "Controls", as: "R2 12 Controls")
        auditPage(app, "Cheats", as: "R2 13 Cheats")
    }

    func testAuditGameGBA() { auditGame("mgba", platform: "Game Boy Advance", tag: "10 GBA") }
    func testAuditGameNES() { auditGame("nestopia", platform: "NES", tag: "11 NES") }
    func testAuditGameNDS() { auditGame("melonds_ds", platform: "Nintendo DS", tag: "12 NDS") }
    func testAuditGame3DS() { auditGame("azahar", platform: "Nintendo 3DS", tag: "13 3DS") }
    func testAuditGamePSP() { auditGame("ppsspp", platform: "PSP", tag: "14 PSP") }

    /// Pause > Cheats has the .cht import. With `GAGA_WALK_CHEATS` (a file in Documents) the first cheat in it
    /// is added, accepted by the core and turned on, and the game keeps running.
    func testAuditCheats() throws {
        let app = XCUIApplication()
        app.launchArguments = (environment["GAGA_WALK_ROM"].map { ["-GagaImportROM", $0] } ?? ["-GagaImportTestROM", core])
            + (environment["GAGA_WALK_CHEATS"].map { ["-GagaCheatFile", $0] } ?? [])
            + (environment["GAGA_WALK_CHEAT_TITLE"].map { ["-GagaCheatTitle", $0] } ?? [])
        app.launch()
        try guardedTap(importedGame(app, "The \(title) game"), "The game")
        try guardedTap(startOnPage(app), "Play on the game's page")
        let pause = app.buttons["Pause game"]
        try arrive(pause, "The game")
        sleep(2)
        try guardedTap(pause, "Pause game")
        try guardedTap(button(app, "Cheats"), "Cheats")
        try arrive(app.buttons["Import .cht File"], "Import .cht File")
        snapshot("Cheats landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        snapshot("Cheats portrait")
        try arrive(app.buttons["Import .cht File"], "Import .cht File upright")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        if environment["GAGA_WALK_CHEAT_TITLE"] != nil {
            try arrive(app.staticTexts["Available cheats"], "The bundled cheats")
            let bundled = app.switches.firstMatch
            try arrive(bundled, "A bundled cheat's switch")
            bundled.switches.firstMatch.tap()
            sleep(1)
            XCTAssertTrue(app.staticTexts["Add a code"].exists, "The core refused the bundled cheat")
            snapshot("Bundled cheat on")
            try guardedTap(app.buttons["Close"], "Close")
            try guardedTap(button(app, "Resume"), "Resume")
            sleep(5)
            try arrive(pause, "The running game with the bundled cheat on")
            snapshot("Running with the bundled cheat")
            return
        }
        guard environment["GAGA_WALK_CHEATS"] != nil else { return }
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ' AND NOT label == 'Add Cheat'")).firstMatch
        try guardedTap(add, "Add on the first cheat in the file")
        snapshot("Cheat added")
        XCTAssertTrue(app.staticTexts["Add a code"].waitForExistence(timeout: 5), "The core refused the code")
        let toggle = app.switches.firstMatch
        try arrive(toggle, "The added cheat's toggle")
        toggle.switches.firstMatch.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Add a code"].exists, "The core refused the code when turned on")
        snapshot("Cheat on")
        try guardedTap(app.buttons["Close"], "Close")
        try guardedTap(button(app, "Resume"), "Resume")
        sleep(5)
        try arrive(pause, "The running game with the cheat on")
        snapshot("Running with the cheat")
    }

    /// Settings > Cores > the walk's core: changes its first option there, then in the game opens Pause > Core
    /// Options and changes one again, and the game keeps running.
    func testCoreOptions() throws {
        let app = launchApp()
        let game = importedGame(app, "The \(title) game")
        sleep(2)
        try guardedTap(button(app, "Settings"), "Settings in the rail")
        guard selectTab(app, "Systems") else { return }
        try guardedTap(app.buttons["core.\(core)"].firstMatch, "The \(core) row")
        try changeFirstOption(app, "Settings")
        snapshot("Core options from Settings")
        close(app)
        goTo(app, "Library")
        try guardedTap(game, "The game")
        try guardedTap(startOnPage(app), "Play on the game's page")
        let pause = app.buttons["Pause game"]
        try arrive(pause, "The game")
        sleep(2)
        try guardedTap(pause, "Pause game")
        try guardedTap(app.buttons["pause.coreOptions"].firstMatch, "Core Options in the pause menu")
        try changeFirstOption(app, "the pause menu")
        snapshot("Core options in the game")
        close(app)
        try guardedTap(button(app, "Resume"), "Resume")
        sleep(3)
        try arrive(pause, "The running game after a core option change")
        snapshot("Running after a core option change")
    }

    /// Picks another value in the page's first option menu and checks the row shows it.
    private func changeFirstOption(_ app: XCUIApplication, _ place: String) throws {
        let picker = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'coreOption.'")).firstMatch
        try arrive(picker, "A core option from \(place)")
        let before = picker.value as? String
        picker.tap()
        sleep(1)
        // A Picker's menu lists its values in a collection view over the page.
        let other = app.collectionViews.firstMatch.buttons.matching(NSPredicate(format: "label != %@", before ?? "")).element(boundBy: 0)
        try guardedTap(other, "Another value in the option's menu")
        sleep(1)
        XCTAssertNotEqual(picker.value as? String, before, "The option did not change from \(place)")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'coreOptions.reset.'")).firstMatch.exists,
                      "No Reset after changing an option from \(place)")
    }

    /// Settings > About > Licences.
    func testOpenLicences() throws {
        let app = launchApp()
        try guardedTap(button(app, "Settings"), "Settings in the rail")
        try guardedTap(app.buttons["settings.Help"].firstMatch, "Help")
        try guardedTap(button(app, "Licences"), "Licences")
        snapshot("Licences")
    }

    /// Settings > RetroAchievements: shows the sign-in form. Types nothing and signs in to nothing.
    func testAuditRetroAchievements() throws {
        let app = launchApp()
        try guardedTap(button(app, "Settings"), "Settings in the rail")
        try guardedTap(app.buttons["settings.Profile"].firstMatch, "Profile")
        try guardedTap(button(app, "RetroAchievements"), "RetroAchievements row")
        try arrive(app.textFields["raUsername"], "Username field")
        XCTAssertTrue(app.secureTextFields["raPassword"].exists)
        XCTAssertFalse(app.buttons["raSignIn"].isEnabled, "Sign In must wait for a username and password")
        snapshot("RetroAchievements sign-in")
    }

    /// Settings > Storage: iCloud Sync is off by default, shows a clear state when turned on, and turns off again.
    /// A fresh install has no saves, so this uploads nothing.
    func testAuditICloudSync() throws {
        let app = launchApp()
        try guardedTap(button(app, "Settings"), "Settings in the rail")
        try guardedTap(app.buttons["settings.Storage and Sync"].firstMatch, "Storage and Sync")
        let toggle = app.switches["icloudSyncToggle"].firstMatch
        try arrive(toggle, "iCloud Sync switch")
        XCTAssertEqual(toggle.value as? String, "0", "iCloud Sync must be off by default")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let status = app.descendants(matching: .any)["icloudSyncStatus"]
        try arrive(status, "iCloud status row")
        sleep(3)
        try stopIfPrompt()
        snapshot("iCloud Sync on")
        print("iCloud status: \(status.label)")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(status.waitForNonExistence(timeout: timeout), "The status row must go with the switch")
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
        if element.identifier.hasPrefix("settings.") || element.identifier.hasPrefix("style.") { reveal(element) }
        element.tap()
    }

    /// Types into a field once the keyboard is up. A tap made while a tab is still changing can leave the field
    /// without focus, so the tap is made again.
    private func enter(_ app: XCUIApplication, _ field: XCUIElement, _ text: String, _ what: String) throws {
        for _ in 0..<3 {
            try guardedTap(field, what)
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { break }
            sleep(1)
        }
        field.typeText(text)
    }

    /// Play, turn the phone upright and back: the touch controls lay out again for each orientation and stay on
    /// screen, and the game keeps running, so its pause menu still opens and closes.
    func testRotation() throws {
        let app = launchApp()
        try guardedTap(importedGame(app, "The \(title) game"), "The game")
        try guardedTap(startOnPage(app), "Play on the game's page")
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
        try guardedTap(startOnPage(app), "Play on the game's page")
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
        try guardedTap(startOnPage(app), "Play on the game's page after relaunch")
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
