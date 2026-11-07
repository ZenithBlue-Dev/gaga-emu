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

    /// Settings > About > Licences.
    func testOpenLicences() {
        let app = launchApp()
        tap(button(app, "Settings"), "Settings in the rail")
        tap(button(app, "About"), "About")
        tap(button(app, "Licences"), "Licences")
        snapshot("Licences")
    }

    /// Play, press a touch control, pause, resume, save a state, load it, quit, relaunch, check the battery save.
    func testWalk() {
        var app = launchApp()
        snapshot("Library")
        let play = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        tap(play, "The \(title) game")
        let pause = app.buttons["Pause game"]
        XCTAssertTrue(pause.waitForExistence(timeout: timeout), "The game did not start")
        sleep(2)
        snapshot("Playing, touch layout")

        // Touch input: the glyph passes the touch to the layer under it, which presses the button.
        let control = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@",
            ["A button", "B button", "Start", "D-pad right"])).firstMatch
        tap(control, "A touch control")
        snapshot("After input")

        pause.tap()
        tap(button(app, "Resume"), "Resume")
        pause.tap()
        tap(button(app, "Save State"), "Save State")
        tap(button(app, "Load State"), "Load State")
        let load = button(app, "Load Save state")
        tap(load, "The saved state")
        XCTAssertTrue(pause.waitForExistence(timeout: timeout), "The game did not resume after loading the state")
        snapshot("Loaded state")

        pause.tap()
        tap(button(app, "Quit to Library"), "Quit to Library")
        XCTAssertTrue(play.waitForExistence(timeout: timeout), "Quit did not return to the Library")

        app.terminate()
        app = launchApp()
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch, "The game after relaunch")
        tap(app.buttons["Pause game"], "Pause game after relaunch")
        tap(button(app, "Load State"), "Load State after relaunch")
        snapshot("Saves after relaunch")
        XCTAssertTrue(button(app, "Load Save state").exists,
                      "The save state did not survive a relaunch")
        if environment["GAGA_WALK_BATTERY"] != "0" {
            XCTAssertTrue(app.staticTexts["Written by the game itself"].exists, "No battery save after quit and relaunch")
        }
    }
}
