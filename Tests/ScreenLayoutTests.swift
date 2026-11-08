import XCTest
@testable import GagaEmu

/// Scaling modes, two-screen layouts, the custom layout editor's checks, touch mapping and ScreenLayouts.json
/// (docs/05 section 2.6). Pure math and files: no core, no GPU.
final class ScreenLayoutTests: XCTestCase {
    private let ds = CGSize(width: 512, height: 192)
    private let n3ds = CGSize(width: 720, height: 240)

    private func placed(_ settings: ScreenSettings, canvas: CGSize = CGSize(width: 384, height: 192), frame: CGSize? = nil,
                        platform: String = "nds") -> [ScreenPlacement] {
        ScreenLayout.placements(frame: frame ?? ds, canvas: canvas, platformID: platform, settings: settings)
    }

    private func settings(_ preset: DualPreset, _ change: (inout ScreenSettings) -> Void = { _ in }) -> ScreenSettings {
        var s = ScreenSettings()
        s.preset = preset
        change(&s)
        return s
    }

    private func dest(_ placements: [ScreenPlacement], _ id: ScreenID) -> CGRect? { placements.first { $0.id == id }?.dest }

    /// The frame pixel the pointer names, from libretro's scale over the whole frame.
    private func framePixel(_ pointer: (x: Int16, y: Int16), frame: CGSize) -> CGPoint {
        CGPoint(x: (CGFloat(pointer.x) + 32767) / 65534 * frame.width, y: (CGFloat(pointer.y) + 32767) / 65534 * frame.height)
    }

    // MARK: Scaling modes

    func testFitFillsTheShorterSideCompletely() {
        let rect = ScreenLayout.scaledRect(content: CGSize(width: 256, height: 224), canvas: CGSize(width: 2556, height: 1179), mode: .fit)
        XCTAssertEqual(rect.height, 1179)
        XCTAssertEqual(rect.width, 1347)
        XCTAssertEqual(rect.minX, 604)
        XCTAssertEqual(rect.minY, 0)
    }

    func testStretchFillsTheWholeArea() {
        let canvas = CGSize(width: 2556, height: 1179)
        XCTAssertEqual(ScreenLayout.scaledRect(content: CGSize(width: 256, height: 224), canvas: canvas, mode: .stretch),
                       CGRect(origin: .zero, size: canvas))
    }

    func testIntegerScaleIsTheLargestWholeMultiple() {
        let rect = ScreenLayout.scaledRect(content: CGSize(width: 256, height: 224), canvas: CGSize(width: 2556, height: 1179), mode: .integer)
        XCTAssertEqual(rect, CGRect(x: 638, y: 29, width: 1280, height: 1120), "5x, centred")
        let exact = ScreenLayout.scaledRect(content: CGSize(width: 160, height: 144), canvas: CGSize(width: 480, height: 432), mode: .integer)
        XCTAssertEqual(exact, CGRect(x: 0, y: 0, width: 480, height: 432), "exactly 3x")
        let small = ScreenLayout.scaledRect(content: CGSize(width: 1000, height: 1000), canvas: CGSize(width: 500, height: 400), mode: .integer)
        XCTAssertEqual(small, CGRect(x: 50, y: 0, width: 400, height: 400), "below 1x falls back to Fit")
    }

    func testZoomKeepsTheShapeAndCropsTheOverflow() {
        let rect = ScreenLayout.scaledRect(content: CGSize(width: 256, height: 224), canvas: CGSize(width: 2556, height: 1179), mode: .zoom)
        XCTAssertEqual(rect.width, 2556)
        XCTAssertEqual(rect.height, 2237)
        XCTAssertEqual(rect.minY, -529)
        XCTAssertEqual(rect.midY, 1179.0 / 2, accuracy: 1)
    }

    func testAOneScreenSystemDrawsTheWholeFrameAndTakesTouch() {
        let placements = placed(ScreenSettings(), canvas: CGSize(width: 1000, height: 500), frame: CGSize(width: 320, height: 240), platform: "snes")
        XCTAssertEqual(placements.count, 1)
        XCTAssertTrue(placements[0].isWholeFrame)
        XCTAssertTrue(placements[0].takesTouch)
        XCTAssertEqual(placements[0].dest, CGRect(x: 166, y: 0, width: 667, height: 500))
    }

    @MainActor
    func testTheOldFitPointerStillLandsTheSame() throws {
        let corner = try XCTUnwrap(GameSession.libretroPointer(CGPoint(x: 100, y: 0), bounds: CGSize(width: 1000, height: 300), content: ds))
        XCTAssertEqual(corner.x, -32767)
        XCTAssertNil(GameSession.libretroPointer(CGPoint(x: 99, y: 150), bounds: CGSize(width: 1000, height: 300), content: ds))
    }

    // MARK: Regions

    func testRegionsMatchTheCoreOptionsFrames() throws {
        let dsRegions = try XCTUnwrap(ScreenLayout.regions(platformID: "nds", frame: ds))
        XCTAssertEqual(dsRegions.map(\.rect), [CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)])
        XCTAssertEqual(dsRegions.map(\.pixels), [CGSize(width: 256, height: 192), CGSize(width: 256, height: 192)])
        let threeDS = try XCTUnwrap(ScreenLayout.regions(platformID: "n3ds", frame: n3ds))
        XCTAssertEqual(threeDS.map(\.pixels), [CGSize(width: 400, height: 240), CGSize(width: 320, height: 240)])
        let scaled = try XCTUnwrap(ScreenLayout.regions(platformID: "n3ds", frame: CGSize(width: 1440, height: 480)))
        XCTAssertEqual(scaled.map(\.pixels), [CGSize(width: 800, height: 480), CGSize(width: 640, height: 480)])
        XCTAssertNil(ScreenLayout.regions(platformID: "nds", frame: CGSize(width: 256, height: 384)), "another arrangement is shown whole")
        XCTAssertNil(ScreenLayout.regions(platformID: "snes", frame: ds))
        XCTAssertEqual(placed(ScreenSettings(), frame: CGSize(width: 256, height: 384)).count, 1)
    }

    // MARK: Presets

    func testStacked() {
        let p = placed(settings(.stacked), canvas: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(p.map(\.id), [.top, .bottom])
        XCTAssertEqual(dest(p, .top), CGRect(x: 166, y: 0, width: 667, height: 500))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 166, y: 500, width: 667, height: 500))
        XCTAssertEqual(p.map(\.takesTouch), [false, true])
        XCTAssertEqual(p.first?.source, CGRect(x: 0, y: 0, width: 0.5, height: 1))
    }

    func testStackedWithAGap() {
        let p = placed(settings(.stacked) { $0.gap = 16 }, canvas: CGSize(width: 256, height: 400))
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 0, y: 208, width: 256, height: 192))
    }

    func testSideBySide() {
        let p = placed(settings(.sideBySide), canvas: CGSize(width: 1024, height: 192))
        XCTAssertEqual(dest(p, .top), CGRect(x: 256, y: 0, width: 256, height: 192))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 512, y: 0, width: 256, height: 192))
    }

    func testThe3DSScreensKeepTheirOwnWidths() {
        let p = placed(settings(.stacked), canvas: CGSize(width: 400, height: 480), frame: n3ds, platform: "n3ds")
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 0, width: 400, height: 240))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 40, y: 240, width: 320, height: 240))
    }

    func testLargeTopWithTheSmallScreenOnEachSide() {
        var p = placed(settings(.largeTop))
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 256, y: 48, width: 128, height: 96))
        p = placed(settings(.largeTop) { $0.smallPlacement = .left })
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 0, y: 48, width: 128, height: 96))
        XCTAssertEqual(dest(p, .top), CGRect(x: 128, y: 0, width: 256, height: 192))
        p = placed(settings(.largeTop) { $0.smallPlacement = .bottom }, canvas: CGSize(width: 256, height: 288))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 64, y: 192, width: 128, height: 96))
        p = placed(settings(.largeTop) { $0.smallPlacement = .top }, canvas: CGSize(width: 256, height: 288))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 64, y: 0, width: 128, height: 96))
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 96, width: 256, height: 192))
    }

    func testLargeBottomAndTheSmallScreenSize() {
        let p = placed(settings(.largeBottom) { $0.smallScale = 0.25 }, canvas: CGSize(width: 320, height: 192))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(dest(p, .top), CGRect(x: 256, y: 72, width: 64, height: 48))
    }

    func testSwapExchangesTheScreens() {
        var p = placed(settings(.stacked) { $0.swapped = true }, canvas: CGSize(width: 256, height: 384))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 192, width: 256, height: 192))
        p = placed(settings(.largeTop) { $0.swapped = true })
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 0, y: 0, width: 256, height: 192), "Large Top swapped is the large bottom screen")
    }

    func testOneScreenShowsTheFirstAndSwapPicksTheOther() {
        var p = placed(settings(.single), canvas: CGSize(width: 512, height: 384))
        XCTAssertEqual(p.map(\.id), [.top])
        XCTAssertEqual(p.first?.dest, CGRect(x: 0, y: 0, width: 512, height: 384))
        XCTAssertFalse(ScreenLayout.showsTouchScreen(settings(.single)))
        p = placed(settings(.single) { $0.swapped = true }, canvas: CGSize(width: 512, height: 384))
        XCTAssertEqual(p.map(\.id), [.bottom])
        XCTAssertTrue(ScreenLayout.showsTouchScreen(settings(.single) { $0.swapped = true }))
    }

    func testHidingAScreenShowsTheOtherAloneAndTouchStops() throws {
        let hidden = settings(.stacked) { $0.showBottom = false }
        let p = placed(hidden, canvas: CGSize(width: 512, height: 384))
        XCTAssertEqual(p.map(\.id), [.top])
        XCTAssertEqual(p.first?.dest, CGRect(x: 0, y: 0, width: 512, height: 384))
        XCTAssertFalse(ScreenLayout.showsTouchScreen(hidden))
        XCTAssertNil(ScreenLayout.pointer(at: CGPoint(x: 256, y: 192), placements: p), "touch is off")
        let topHidden = placed(settings(.sideBySide) { $0.showTop = false }, canvas: CGSize(width: 512, height: 384))
        XCTAssertEqual(topHidden.map(\.id), [.bottom])
        XCTAssertTrue(ScreenLayout.showsTouchScreen(settings(.sideBySide) { $0.showTop = false }))
    }

    func testBothHiddenIsNeverSaved() {
        let both = settings(.stacked) { $0.showTop = false; $0.showBottom = false }
        XCTAssertEqual(both.normalized().showTop, true)
        XCTAssertEqual(placed(both).count, 2)
    }

    func testHybridShowsOneLargeAndBothSmall() {
        let p = placed(settings(.hybrid))
        XCTAssertEqual(p.map(\.id), [.top, .top, .bottom])
        XCTAssertEqual(p[0].dest, CGRect(x: 0, y: 0, width: 256, height: 192))
        XCTAssertEqual(p[1].dest, CGRect(x: 256, y: 0, width: 128, height: 96))
        XCTAssertEqual(p[2].dest, CGRect(x: 256, y: 96, width: 128, height: 96))
        XCTAssertEqual(p.map(\.takesTouch), [false, false, true])
        let swapped = placed(settings(.hybrid) { $0.swapped = true })
        XCTAssertEqual(swapped.map(\.takesTouch), [true, false, true], "large bottom and small bottom both take touch")
    }

    func testRotationTurnsEachScreen() {
        let p = placed(settings(.sideBySide) { $0.rotation = .left }, canvas: CGSize(width: 384, height: 256))
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 0, width: 192, height: 256))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 192, y: 0, width: 192, height: 256))
        let top = p[0]
        // Turn Left: the frame's top-right corner of the top screen shows at the rectangle's top-left.
        XCTAssertEqual(ScreenLayout.cropCorners(top), [SIMD2(0.5, 0), SIMD2(0.5, 1), SIMD2(0, 0), SIMD2(0, 1)])
        let right = placed(settings(.sideBySide) { $0.rotation = .right }, canvas: CGSize(width: 384, height: 256))
        XCTAssertEqual(ScreenLayout.cropCorners(right[0]), [SIMD2(0, 1), SIMD2(0, 0), SIMD2(0.5, 1), SIMD2(0.5, 0)])
        let none = placed(settings(.sideBySide))
        XCTAssertEqual(ScreenLayout.cropCorners(none[1]), [SIMD2(0.5, 0), SIMD2(1, 0), SIMD2(0.5, 1), SIMD2(1, 1)])
    }

    func testEveryPresetScalesWithEveryMode() {
        let canvas = CGSize(width: 2556, height: 1179)
        for preset in DualPreset.allCases {
            for mode in ScalingMode.allCases {
                let p = placed(settings(preset) { $0.scaling = mode }, canvas: canvas)
                XCTAssertFalse(p.isEmpty, "\(preset) \(mode)")
                for placement in p {
                    XCTAssertGreaterThan(placement.dest.width, 0)
                    if mode != .zoom {
                        XCTAssertTrue(CGRect(origin: .zero, size: canvas).contains(placement.dest), "\(preset) \(mode) \(placement.dest)")
                    }
                }
            }
        }
    }

    // MARK: Touch

    /// The bottom screen's centre, and a point off centre, land on the same frame pixel in every preset, swapped
    /// or not, turned or not.
    func testTouchLandsOnTheBottomScreenInEveryLayout() throws {
        let canvas = CGSize(width: 2556, height: 1179)
        for preset in DualPreset.allCases where preset != .custom {
            for swapped in [false, true] {
                for rotation in ScreenRotation.allCases {
                    let s = settings(preset) { $0.swapped = swapped; $0.rotation = rotation; $0.gap = 8 }
                    guard ScreenLayout.showsTouchScreen(s) else {
                        XCTAssertNil(placed(s, canvas: canvas).first { $0.takesTouch }, "\(preset)")
                        continue
                    }
                    let p = placed(s, canvas: canvas)
                    let bottom = try XCTUnwrap(p.last { $0.takesTouch }, "\(preset) \(swapped) \(rotation)")
                    // A quarter in from the bottom screen's own top-left, wherever that is drawn.
                    let (u, v): (CGFloat, CGFloat) = switch rotation {
                    case .none: (0.25, 0.25)
                    case .left: (0.25, 0.75)
                    case .right: (0.75, 0.25)
                    }
                    let finger = CGPoint(x: bottom.dest.minX + u * bottom.dest.width, y: bottom.dest.minY + v * bottom.dest.height)
                    let pointer = try XCTUnwrap(ScreenLayout.pointer(at: finger, placements: p))
                    let pixel = framePixel(pointer, frame: ds)
                    XCTAssertEqual(pixel.x, 256 + 64, accuracy: 1, "\(preset) \(swapped) \(rotation)")
                    XCTAssertEqual(pixel.y, 48, accuracy: 1, "\(preset) \(swapped) \(rotation)")
                }
            }
        }
    }

    func testTouchOnTheTopScreenOrTheLetterboxIsIgnored() {
        let p = placed(settings(.stacked), canvas: CGSize(width: 1000, height: 1000))
        XCTAssertNil(ScreenLayout.pointer(at: CGPoint(x: 500, y: 250), placements: p), "top screen")
        XCTAssertNil(ScreenLayout.pointer(at: CGPoint(x: 50, y: 750), placements: p), "letterbox")
    }

    func testTouchOnACustomLayout() throws {
        let s = settings(.custom) {
            $0.customTop = CGRect(x: 0, y: 0, width: 0.5, height: 1)
            $0.customBottom = CGRect(x: 0.5, y: 0.25, width: 0.25, height: 0.5)
        }
        let p = placed(s, canvas: CGSize(width: 1000, height: 400))
        XCTAssertEqual(dest(p, .bottom), CGRect(x: 500, y: 100, width: 250, height: 200))
        XCTAssertEqual(dest(p, .top), CGRect(x: 0, y: 0, width: 500, height: 400))
        let pixel = framePixel(try XCTUnwrap(ScreenLayout.pointer(at: CGPoint(x: 625, y: 200), placements: p)), frame: ds)
        XCTAssertEqual(pixel.x, 384, accuracy: 1)
        XCTAssertEqual(pixel.y, 96, accuracy: 1)
        let swapped = placed(settings(.custom) { $0.customTop = s.customTop; $0.customBottom = s.customBottom; $0.swapped = true },
                             canvas: CGSize(width: 1000, height: 400))
        XCTAssertEqual(dest(swapped, .bottom), CGRect(x: 0, y: 0, width: 500, height: 400), "swap exchanges the places")
    }

    func testACustomLayoutNeverEditedIsStacked() {
        XCTAssertEqual(placed(settings(.custom), canvas: CGSize(width: 1000, height: 1000)), placed(settings(.stacked), canvas: CGSize(width: 1000, height: 1000)))
    }

    // MARK: Editor

    func testEditorValidation() {
        let canvas = CGSize(width: 852, height: 393)
        var s = settings(.custom)
        XCTAssertEqual(ScreenLayout.problems(s, canvas: canvas), ["Place the top screen.", "Place the bottom screen."])
        s.customTop = CGRect(x: 0, y: 0, width: 0.5, height: 1)
        s.customBottom = CGRect(x: 0.6, y: 0.2, width: 0.3, height: 0.6)
        XCTAssertEqual(ScreenLayout.problems(s, canvas: canvas), [])
        s.customBottom = CGRect(x: 0.8, y: 0.2, width: 0.3, height: 0.6)
        XCTAssertEqual(ScreenLayout.problems(s, canvas: canvas), ["Keep the whole bottom screen on the display."])
        s.customBottom = CGRect(x: 0.6, y: 0.2, width: 0.05, height: 0.6)
        XCTAssertEqual(ScreenLayout.problems(s, canvas: canvas), ["Make the bottom screen larger."])
        s.showBottom = false
        XCTAssertEqual(ScreenLayout.problems(s, canvas: canvas), [], "a hidden screen is not checked")
        s.showTop = false
        XCTAssertEqual(ScreenLayout.problems(s, canvas: canvas), ["Show at least one screen."])
    }

    func testEditorMovesAndSizesWithinTheCanvas() {
        let r = CGRect(x: 0.6, y: 0.2, width: 0.3, height: 0.6)
        let moved = ScreenLayout.moved(r, by: CGSize(width: 0.5, height: -0.5))
        XCTAssertEqual(moved.maxX, 1, accuracy: 1e-9, "stopped at the right edge")
        XCTAssertEqual(moved.minY, 0, accuracy: 1e-9, "stopped at the top edge")
        XCTAssertEqual(moved.size, r.size)
        let grown = ScreenLayout.resized(r, sx: 1.5, sy: 1.5)
        XCTAssertEqual(grown.width, 0.45, accuracy: 1e-9)
        XCTAssertEqual(grown.maxY, 0.95, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(grown.maxX, 1)
        XCTAssertEqual(ScreenLayout.resized(r, sx: 2, sy: 2), r, "larger than the canvas is refused")
        let stretched = ScreenLayout.resized(r, sx: 1.1, sy: 1)
        XCTAssertEqual(stretched.height, r.height)
    }

    func testEditorStartsFromThePresetAndTracksSwap() throws {
        let canvas = CGSize(width: 1000, height: 1000)
        let places = ScreenLayout.customRects(platformID: "nds", canvas: canvas, from: settings(.stacked))
        XCTAssertEqual(places.top, CGRect(x: 0.166, y: 0, width: 0.667, height: 0.5))
        XCTAssertEqual(places.bottom, CGRect(x: 0.166, y: 0.5, width: 0.667, height: 0.5))
        var s = settings(.custom) { $0.swapped = true }
        ScreenLayout.setCustomRect(&s, for: .bottom, CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        XCTAssertEqual(s.customTop, CGRect(x: 0, y: 0, width: 0.5, height: 0.5), "swapped, the bottom screen fills the top place")
        XCTAssertEqual(ScreenLayout.customRect(s, for: .bottom), s.customTop)
        XCTAssertEqual(ScreenLayout.problems(settings(.custom) {
            $0.customTop = places.top
            $0.customBottom = places.bottom
        }, canvas: canvas), [])
    }

    // MARK: Settings file

    @MainActor
    func testSettingsRoundTripPerSystemAndPerGame() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("screens-\(UUID().uuidString)/ScreenLayouts.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let game = UUID()
        let store = ScreenLayoutStore(url: url)
        XCTAssertEqual(store.settings(platformID: "nds", gameID: game), ScreenSettings(), "nothing saved: the defaults")
        var system = settings(.largeTop) { $0.smallPlacement = .left; $0.gap = 12; $0.scaling = .integer; $0.area = .betweenControls }
        system.customTop = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        store.save(system, platformID: "nds", gameID: nil)
        store.save(settings(.single) { $0.swapped = true }, platformID: "nds", gameID: game)
        let reloaded = ScreenLayoutStore(url: url)
        XCTAssertEqual(reloaded.settings(platformID: "nds", gameID: nil), system)
        XCTAssertEqual(reloaded.settings(platformID: "nds", gameID: UUID()), system, "a game without its own uses the system's")
        XCTAssertEqual(reloaded.settings(platformID: "nds", gameID: game).preset, .single)
        XCTAssertTrue(reloaded.hasOverride(game))
        reloaded.removeOverride(game)
        XCTAssertEqual(ScreenLayoutStore(url: url).settings(platformID: "nds", gameID: game), system)
        XCTAssertEqual(reloaded.file.version, ScreenLayoutStore.File.currentVersion)
    }

    @MainActor
    func testABrokenOrLaterFileFallsBackToTheDefaults() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("screens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("ScreenLayouts.json")
        try Data("{ not json".utf8).write(to: url)
        XCTAssertEqual(ScreenLayoutStore(url: url).file, ScreenLayoutStore.File())
        try Data(#"{"version": 99, "systems": {"nds": {"preset": "single"}}, "games": {}}"#.utf8).write(to: url)
        XCTAssertEqual(ScreenLayoutStore(url: url).settings(platformID: "nds", gameID: nil), ScreenSettings())
        // One unknown value falls back alone; the rest of the entry, and out-of-range numbers, survive clamped.
        try Data(#"{"version": 1, "systems": {"nds": {"preset": "spiral", "scaling": "zoom", "gap": 900, "smallScale": 0}}, "games": {}}"#.utf8).write(to: url)
        let loaded = ScreenLayoutStore(url: url).settings(platformID: "nds", gameID: nil)
        XCTAssertEqual(loaded.preset, .stacked)
        XCTAssertEqual(loaded.scaling, .zoom)
        XCTAssertEqual(loaded.gap, 64)
        XCTAssertEqual(loaded.smallScale, 0.25)
    }
}
