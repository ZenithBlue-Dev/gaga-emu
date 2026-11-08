import XCTest
@testable import GagaEmu

/// Device skins (docs/06 section 3.8): every shipped JSON decodes and passes the device checks in both orientations,
/// its masks are ones the core reads, its screens sit inside the canvas, the picture and pressed art line up with
/// touch, and no PDF holds text or a font.
@MainActor
final class DeviceSkinTests: GagaTestCase {
    private var root: URL {
        TouchSkinEngine.deviceRoot ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Skins/Device")
    }

    private var platforms: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).filter { TouchSkinEngine.hasDevice($0, root: root) }.sorted()
    }

    func testEveryCatalogPlatformHasADeviceSkin() {
        XCTAssertEqual(platforms.count, 35)
        for platform in CoreCatalog.platforms where platform.id != "vktest" {
            XCTAssertTrue(TouchSkinEngine.hasDevice(platform.id, root: root), platform.id)
        }
    }

    func testEverySkinDecodesAndPassesTheDeviceChecksInBothOrientations() throws {
        for platform in platforms {
            let skin = try TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent(platform))
            let art = try XCTUnwrap(skin.device, platform)
            XCTAssertTrue(skin.overlay)
            for (upright, buttons) in [(false, skin.buttons), (true, skin.portraitButtons)] {
                let face = art.face(portrait: upright)
                let tag = "\(platform) \(upright ? "portrait" : "landscape")"
                XCTAssertFalse(buttons.isEmpty, tag)
                XCTAssertEqual(TouchSkinEngine.deviceProblems(buttons, canvas: face.canvas, portrait: upright), [], tag)
                XCTAssertEqual(face.screens.count, ScreenLayout.isDual(platform) ? 2 : 1, tag)
                for screen in face.screens {
                    XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(screen), "\(tag) screen \(screen)")
                    for button in buttons { XCTAssertFalse(button.frame.intersects(screen), "\(tag) \(button.id) covers the picture") }
                }
                for name in [face.background, face.pressed] + face.variants.map(\.background) {
                    XCTAssertNotNil(CGPDFDocument(art.folder.appendingPathComponent(name) as CFURL), "\(tag) \(name)")
                }
                XCTAssertNotNil(TouchSkinEngine.DeviceArt.rgba(face.fill), tag)
                for label in face.labels {
                    XCTAssertNotNil(TouchSkinEngine.DeviceArt.rgba(label.color), "\(tag) \(label.text)")
                    XCTAssertTrue((0...1).contains(label.x) && (0...1).contains(label.y), "\(tag) \(label.text)")
                }
            }
        }
    }

    /// Every mask is RetroPad bits the shared adapter passes on. Mask 0 is only a stick or a C button, which move the
    /// sticks instead. Platforms whose mapping was corrected from the core's input code are pinned.
    func testMasksAreOnesTheCoreReads() throws {
        let b = ControllerManager.Button.self
        let pinned: [String: [String: UInt32]] = [
            "saturn": ["west": b.west, "north": b.north, "l": b.l1, "south": b.south, "east": b.east, "r": b.r1, "l2": b.l2, "r2": b.r2],
            "jaguar": ["east": b.east, "south": b.south, "west": b.west],
            "atari5200": ["south": b.south, "north": b.north, "select": b.select],
            "c64": ["l3": b.select], "amiga": ["l3": b.select], "atari8bit": ["l3": b.l3], "dos": ["l3": b.l3],
            "n64": ["south": b.south, "west": b.west, "l2": b.l2, "start": b.start, "cup": 0, "cdown": 0, "cleft": 0, "cright": 0]
        ]
        for platform in platforms {
            let skin = try TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent(platform))
            for buttons in [skin.buttons, skin.portraitButtons] {
                for button in buttons {
                    XCTAssertEqual(button.mask & ~0xFFFF, 0, "\(platform) \(button.id)")
                    if button.mask == 0 {
                        XCTAssertTrue(button.shape == .stick || TouchSkinEngine.cPush(button.id) != nil, "\(platform) \(button.id) does nothing")
                    }
                    if let want = pinned[platform]?[button.id] { XCTAssertEqual(button.mask, want, "\(platform) \(button.id)") }
                }
            }
        }
        let n64 = try TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent("n64"))
        XCTAssertEqual(n64.buttons.filter { $0.shape == .stick }.map(\.id), ["lstick"])
        for platform in ["psp", "dreamcast", "n3ds"] {
            let skin = try TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent(platform))
            XCTAssertTrue(skin.buttons.contains { $0.shape == .stick } && skin.portraitButtons.contains { $0.shape == .stick }, platform)
        }
    }

    func testTouchPressesTheButtonUnderTheFingerAndSticksAndCButtonsMove() throws {
        let engine = TouchSkinEngine()
        engine.hapticsEnabled = false
        engine.soundEnabled = false
        try engine.loadDevice(platformID: "n64", variant: nil, root: root)
        for button in engine.buttons where button.shape != .hidden && button.shape != .stick && button.mask != 0 {
            XCTAssertEqual(engine.setTouches([CGPoint(x: button.frame.midX, y: button.frame.midY)]), button.mask, button.id)
        }
        let cUp = try XCTUnwrap(engine.buttons.first { $0.id == "cup" })
        engine.setTouches([CGPoint(x: cUp.frame.midX, y: cUp.frame.midY)])
        XCTAssertEqual(engine.analog.ry, 32767)
        let stick = try XCTUnwrap(engine.buttons.first { $0.id == "lstick" })
        engine.setTouches([CGPoint(x: stick.frame.maxX, y: stick.frame.midY)])
        XCTAssertGreaterThan(engine.analog.lx, 30000)
        engine.portrait = true
        XCTAssertEqual(engine.buttons, engine.skin?.portraitButtons, "Turning upright switches to the portrait file")
    }

    func testPressedClipsAreTheTouchRects() throws {
        let skin = try TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent("snes"))
        for button in skin.buttons where button.shape != .hidden && button.shape != .stick {
            XCTAssertEqual(TouchSkinEngine.pressedFrames(held: [button.id], in: skin.buttons), [button.frame], button.id)
        }
        let frame = { (id: String) in skin.buttons.first { $0.id == id }!.frame }
        XCTAssertEqual(Set(TouchSkinEngine.pressedFrames(held: ["upleft"], in: skin.buttons).map { "\($0)" }),
                       Set([frame("up"), frame("left")].map { "\($0)" }), "A diagonal shows its two directions")
    }

    func testPicturePlacementMath() {
        let fit = TouchSkinEngine.DeviceArt.fitted(CGSize(width: 852, height: 393), in: CGSize(width: 1000, height: 393))
        XCTAssertEqual(fit, CGRect(x: 74, y: 0, width: 852, height: 393))
        let tall = TouchSkinEngine.DeviceArt.fitted(CGSize(width: 393, height: 852), in: CGSize(width: 393, height: 1000))
        XCTAssertEqual(tall.minY, 74, accuracy: 0.001)
        let top = CGRect(x: 0.3, y: 0.1, width: 0.4, height: 0.3), bottom = CGRect(x: 0.35, y: 0.5, width: 0.3, height: 0.3)
        XCTAssertEqual(TouchSkinEngine.DeviceArt.pictureRect([top, bottom]), CGRect(x: 0.3, y: 0.1, width: 0.4, height: 0.7))
        XCTAssertNil(TouchSkinEngine.DeviceArt.screenPlaces([top]))
        let places = TouchSkinEngine.DeviceArt.screenPlaces([top, bottom])!
        XCTAssertEqual(places[0].minX, 0, accuracy: 1e-9); XCTAssertEqual(places[0].width, 1, accuracy: 1e-9)
        XCTAssertEqual(places[1].minY, 0.4 / 0.7, accuracy: 1e-9); XCTAssertEqual(places[1].maxY, 1, accuracy: 1e-9)
        // The renderer places each screen exactly in its rect through the custom layout.
        var settings = ScreenSettings()
        settings.preset = .custom; settings.customTop = places[0]; settings.customBottom = places[1]
        let placed = ScreenLayout.placements(frame: CGSize(width: 512, height: 192), canvas: CGSize(width: 400, height: 700),
                                             platformID: "nds", settings: settings)
        XCTAssertEqual(placed.map(\.dest), [CGRect(x: 0, y: 0, width: 400, height: 300), CGRect(x: 50, y: 400, width: 300, height: 300)])
    }

    func testColourVariantsAndHex() throws {
        var art = try XCTUnwrap(TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent("gb")).device)
        let names = TouchSkinEngine.deviceVariants("gb", root: root)
        XCTAssertFalse(names.isEmpty)
        let own = art.face(portrait: false).background
        art.variant = names[0]
        XCTAssertNotEqual(art.face(portrait: false).background, own)
        XCTAssertNotEqual(art.face(portrait: true).background, art.portrait.background)
        art.variant = "Nope"
        XCTAssertEqual(art.face(portrait: false).background, own)
        XCTAssertEqual(TouchSkinEngine.DeviceArt.rgba("#FF000080")?.a ?? 0, 128.0 / 255, accuracy: 1e-9)
        XCTAssertNil(TouchSkinEngine.DeviceArt.rgba("red"))
    }

    func testStyleDefaultsToClassicAndGameOverridesSystem() {
        var file = ControlsStore.File()
        let id = UUID()
        XCTAssertEqual(file.style(platformID: "gb", gameID: id), .classic)
        file.skinStyle["platform:gb"] = "device"
        XCTAssertEqual(file.style(platformID: "gb", gameID: id), .device)
        file.skinStyle["game:\(id.uuidString)"] = "classic"
        XCTAssertEqual(file.style(platformID: "gb", gameID: id), .classic)
        file.skinStyle["platform:nes"] = "later"
        XCTAssertEqual(file.style(platformID: "nes", gameID: nil), .classic)
    }

    /// The labels are drawn by the app, so no PDF may hold a font or any text operator.
    func testNoPDFHoldsAFontOrText() throws {
        var checked = 0
        for platform in platforms {
            for name in try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(platform).path) where name.hasSuffix(".pdf") {
                let url = root.appendingPathComponent("\(platform)/\(name)")
                let page = try XCTUnwrap(CGPDFDocument(url as CFURL)?.page(at: 1), name)
                XCTAssertFalse(Self.hasFont(page.dictionary), "\(platform)/\(name) holds a font")
                XCTAssertFalse(Self.hasText(page), "\(platform)/\(name) draws text")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 280)
        let generator = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scripts/make_device_skins.swift")
        if let source = try? String(contentsOf: generator, encoding: .utf8) {
            XCTAssertFalse(source.contains("CTFontCreatePathForGlyph"), "The generator must not draw glyph outlines")
        }
    }

    /// A Font resource on the page or any form inside it.
    private static func hasFont(_ dictionary: CGPDFDictionaryRef?) -> Bool {
        var resources: CGPDFDictionaryRef?
        guard let dictionary, CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources else { return false }
        var fonts: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fonts) { return true }
        var objects: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &objects), let objects else { return false }
        var found = false
        CGPDFDictionaryApplyBlock(objects, { _, value, _ in
            var stream: CGPDFStreamRef?
            if CGPDFObjectGetValue(value, .stream, &stream), let stream, hasFont(CGPDFStreamGetDictionary(stream)) { found = true }
            return !found
        }, nil)
        return found
    }

    private static func hasText(_ page: CGPDFPage) -> Bool {
        var seen = false
        let table = CGPDFOperatorTableCreate()!
        for op in ["BT", "Tj", "TJ", "'", "\""] {
            CGPDFOperatorTableSetCallback(table, op) { _, info in info!.assumingMemoryBound(to: Bool.self).pointee = true }
        }
        withUnsafeMutablePointer(to: &seen) { pointer in
            let scanner = CGPDFScannerCreate(CGPDFContentStreamCreateWithPage(page), table, pointer)
            CGPDFScannerScan(scanner)
            CGPDFScannerRelease(scanner)
        }
        return seen
    }
}
