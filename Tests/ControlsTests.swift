import GameController
import XCTest
@testable import GagaEmu

/// Touch layouts in both orientations, controller mapping, turbo, macros, toggles, Controls.json, local players and
/// rotation during play.
@MainActor
final class ControlsTests: GagaTestCase {
    private let b = ControllerManager.Button.self

    // MARK: Layouts

    func testEveryBuiltInLayoutPassesInBothOrientationsOnEveryPlatform() {
        let platforms = CoreCatalog.platforms.map(\.id) + ["n64", "psp", "ps1", "n3ds", "dos"]
        for platform in platforms {
            for layout in TouchSkinEngine.Layout.choices(for: platform) {
                let landscape = layout.buttons(for: platform)
                XCTAssertEqual(TouchSkinEngine.problems(in: landscape), [], "\(platform) \(layout.id) landscape")
                XCTAssertEqual(TouchSkinEngine.problems(in: TouchSkinEngine.portrait(from: landscape), portrait: true), [],
                               "\(platform) \(layout.id) upright")
            }
        }
    }

    func testSticksAndCButtonsComeWithTheirSystems() {
        let ids = { (platform: String) in Set(TouchSkinEngine.Layout.standard.buttons(for: platform).map(\.id)) }
        XCTAssertTrue(ids("n64").isSuperset(of: ["lstick", "cup", "cdown", "cleft", "cright"]))
        XCTAssertTrue(ids("psp").contains("lstick"))
        XCTAssertTrue(ids("n3ds").contains("lstick"))
        XCTAssertTrue(ids("ps1").isSuperset(of: ["lstick", "rstick"]))
        XCTAssertFalse(ids("snes").contains("lstick"))
    }

    func testUprightChecksKeepThePictureClear() {
        var upright = TouchSkinEngine.portrait(from: TouchSkinEngine.Layout.standard.buttons)
        let index = upright.firstIndex { $0.id == "start" }!
        upright[index].frame.origin.y = 0.1
        XCTAssertTrue(TouchSkinEngine.problems(in: upright, portrait: true).contains { $0.contains("covers the picture") })
        XCTAssertFalse(TouchSkinEngine.problems(in: upright, portrait: true, overlay: true).contains { $0.contains("covers the picture") },
                       "Overlay lets a control sit over the picture")
    }

    func testDiagonalsComeOffAndBackOnWithThePad() {
        let standard = TouchSkinEngine.Layout.standard.buttons
        let without = TouchSkinEngine.withDiagonals(standard, false)
        XCTAssertFalse(without.contains { $0.id == "upleft" })
        let back = TouchSkinEngine.withDiagonals(without, true)
        XCTAssertEqual(Set(back.map(\.id)), Set(standard.map(\.id)))
        XCTAssertEqual(back.first { $0.id == "downright" }?.mask, b.down | b.right)
    }

    func testTouchStickAndActionElements() {
        let engine = TouchSkinEngine()
        engine.hapticsEnabled = false
        engine.soundEnabled = false
        engine.loadBuiltIn("standard", platformID: "n64")
        let stick = engine.buttons.first { $0.id == "lstick" }!.frame
        engine.setTouches([CGPoint(x: stick.midX, y: stick.minY)])
        XCTAssertGreaterThan(engine.analog.ly, 30000, "Top of the stick is up")
        XCTAssertEqual(engine.currentMask(), 0, "A stick presses no button")
        let cUp = engine.buttons.first { $0.id == "cup" }!.frame
        engine.setTouches([CGPoint(x: cUp.midX, y: cUp.midY)])
        XCTAssertEqual(engine.analog.ry, 32767)

        var buttons = engine.buttons
        var save = TouchSkinEngine.newElement(.app(.quickSave), in: buttons, portrait: false)
        save.frame = CGRect(x: 0.03, y: 0.2, width: 0.065, height: 0.13)
        buttons.append(save)
        let data = try! TouchSkinEngine.encodeFlex(name: "t", buttons: buttons, opacity: 0.8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("skin-\(UUID().uuidString).json")
        try! data.write(to: url)
        try! engine.loadFlex(from: url)
        engine.setTouches([CGPoint(x: save.frame.midX, y: save.frame.midY)])
        XCTAssertEqual(engine.heldActions, [.app(.quickSave)])
        XCTAssertEqual(engine.currentMask(), 0, "An action element presses no core button")
    }

    // MARK: Skin files

    func testVersionOneSkinMigratesWithAnUprightLayout() throws {
        let json = #"{"name":"Old","landscape":true,"buttons":[{"input":"a","id":"south","frame":{"x":0.85,"y":0.5,"width":0.1,"height":0.2}}]}"#
        let skin = try TouchSkinEngine.decodeFlex(Data(json.utf8), id: "old")
        XCTAssertEqual(skin.buttons.count, 1)
        XCTAssertEqual(skin.portraitButtons.count, 1)
        XCTAssertGreaterThanOrEqual(skin.portraitButtons[0].frame.minY, TouchSkinEngine.portraitControlTop)
    }

    func testVersionTwoRoundTripKeepsEveryField() throws {
        var buttons = TouchSkinEngine.Layout.standard.buttons(for: "n64")
        buttons[0].opacity = 0.5
        buttons[0].haptic = false
        buttons[0].showsLabel = false
        let upright = TouchSkinEngine.portrait(from: buttons)
        let data = try TouchSkinEngine.encodeFlex(name: "C", buttons: buttons, portraitButtons: upright, opacity: 0.7, overlay: true)
        let skin = try TouchSkinEngine.decodeFlex(data, id: "n64")
        XCTAssertEqual(skin.buttons, buttons)
        XCTAssertEqual(skin.portraitButtons, upright)
        XCTAssertTrue(skin.overlay)
    }

    func testALaterSkinVersionIsRefused() {
        let json = #"{"version":99,"name":"Next","buttons":[]}"#
        XCTAssertThrowsError(try TouchSkinEngine.decodeFlex(Data(json.utf8), id: "next"))
    }

    func testGameLayoutWinsOverThePlatformAndResetsAlone() throws {
        let state = AppState()
        let game = GameItem(id: UUID(), title: "t", platformID: "snes", romPath: "/nowhere", coverPath: nil, coreOverride: nil,
                            playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let moved = TouchSkinEngine.moving(TouchSkinEngine.Layout.standard.buttons, group: "pad", by: CGSize(width: 0, height: -0.1))
        try state.saveCustomSkin(moved, opacity: 0.6, platformID: "snes", gameID: game.id)
        XCTAssertNil(state.platformSkins["snes"], "A game's layout leaves the platform's choice")
        state.applySkin(for: game)
        XCTAssertEqual(state.skins.skin?.buttons, moved)
        state.resetCustomSkin("snes", gameID: game.id)
        state.applySkin(for: game)
        XCTAssertEqual(state.skins.skin?.id, "standard")
    }

    // MARK: Mapping

    func testGameMappingWinsOverPlatformWhichWinsOverDefault() {
        var file = ControlsStore.File()
        let game = UUID()
        XCTAssertEqual(ControlsStore.profile(in: file, kind: .xbox, platformID: "snes", gameID: game), PadProfile.standard(for: .xbox))
        let platform = PadProfile(bindings: [PadBinding(inputs: [.a], action: .buttons(b.east))])
        file.pads[ControlsStore.key(platformID: "snes", kind: .xbox)] = platform
        XCTAssertEqual(ControlsStore.profile(in: file, kind: .xbox, platformID: "snes", gameID: game), platform)
        XCTAssertEqual(ControlsStore.profile(in: file, kind: .dualSense, platformID: "snes", gameID: game), .standard(for: .dualSense),
                       "Each controller type has its own")
        let own = PadProfile(bindings: [PadBinding(inputs: [.a], action: .app(.quickSave))])
        file.pads[ControlsStore.key(gameID: game, kind: .xbox)] = own
        XCTAssertEqual(ControlsStore.profile(in: file, kind: .xbox, platformID: "snes", gameID: game), own)
        XCTAssertEqual(ControlsStore.profile(in: file, kind: .xbox, platformID: "snes", gameID: UUID()), platform)
    }

    func testDefaultCombosTakeTheirButtons() {
        let standard = PadProfile.standard()
        let menu = PadMapper.resolve(PadState(held: [.menu, .options]), profile: standard)
        XCTAssertEqual(menu.actions, [.app(.pauseMenu)])
        XCTAssertEqual(menu.buttons, 0, "The pair is not Start and Select")
        let rewind = PadMapper.resolve(PadState(held: [.options, .l1]), profile: standard)
        XCTAssertEqual(rewind.actions, [.app(.rewindHold)])
        XCTAssertEqual(rewind.buttons, 0)
        let swap = PadMapper.resolve(PadState(held: [.options, .r1, .a]), profile: standard)
        XCTAssertEqual(swap.actions, [.app(.swapScreens)])
        XCTAssertEqual(swap.buttons, b.south, "Buttons outside the combo still reach the game")
        XCTAssertEqual(PadMapper.resolve(PadState(held: [.options]), profile: standard).buttons, b.select)
    }

    func testRemappedInputsAndStickOptions() {
        var profile = PadProfile(bindings: [PadBinding(inputs: [.a], action: .turbo(b.south, toggle: false)),
                                            PadBinding(inputs: [.b], action: .buttons(b.north | b.west))])
        let state = PadMapper.resolve(PadState(held: [.a, .b]), profile: profile)
        XCTAssertEqual(state.buttons, b.north | b.west)
        XCTAssertEqual(state.actions, [.turbo(b.south, toggle: false)])

        profile.deadzone = 0.2
        XCTAssertEqual(PadMapper.resolve(PadState(leftX: 0.15), profile: profile).leftX, 0, "Inside the deadzone")
        XCTAssertEqual(PadMapper.resolve(PadState(leftX: 1), profile: profile).leftX, 32767)
        profile.stickAsDpad = true
        XCTAssertEqual(PadMapper.resolve(PadState(leftX: -0.9, leftY: 0.9), profile: profile).buttons, b.left | b.up)
        profile.sensitivity = 2
        XCTAssertEqual(PadMapper.resolve(PadState(leftX: 0.6), profile: profile).leftX, 32767, "Sensitivity caps at full travel")
    }

    func testControlsFileRoundTripsAndABrokenFileReadsAsDefaults() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("controls-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ControlsStore(url: url)
        store.file.macros = [Macro(name: "Jump", steps: [.init(buttons: b.south, frames: 3)], loops: true)]
        store.file.pads[ControlsStore.key(platformID: "nes", kind: .xbox)] = PadProfile(bindings: [
            PadBinding(inputs: [.l1, .r1], action: .macro(store.file.macros[0].id))
        ])
        store.file.touchHaptics = .strong
        XCTAssertEqual(ControlsStore(url: url).file, store.file)

        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(ControlsStore(url: url).file, ControlsStore.File())
        try Data(#"{"version":99}"#.utf8).write(to: url)
        XCTAssertEqual(ControlsStore(url: url).file, ControlsStore.File(), "A later version is not guessed at")
        try Data(#"{"version":1,"turboHertz":20}"#.utf8).write(to: url)
        XCTAssertEqual(ControlsStore(url: url).file.turboHertz, 20, "Missing fields take their defaults")
    }

    // MARK: Turbo and macros

    func testTurboFollowsTheFrameCount() {
        let processor = FrameInputProcessor(hertz: 15, frameRate: 60)
        processor.setTurbo(b.south)
        let frames = (0..<8).map { processor.process(0, frame: $0) & b.south != 0 }
        XCTAssertEqual(frames, [true, true, false, false, true, true, false, false])
        XCTAssertEqual(FrameInputProcessor.period(hertz: 30, frameRate: 60), 2)
        XCTAssertEqual(FrameInputProcessor.period(hertz: 1000, frameRate: 60), 2, "Clamped to on one frame, off the next")
        processor.setTurbo(0)
        XCTAssertEqual(processor.process(b.east, frame: 2), b.east, "Without turbo the input passes")
    }

    func testMacroStepsRunFrameByFrameAndLoopUntilStopped() {
        let processor = FrameInputProcessor()
        let macro = Macro(name: "Hadoken", steps: [.init(buttons: b.down, frames: 2), .init(buttons: b.down | b.right, frames: 1),
                                                   .init(buttons: b.south, frames: 1)])
        processor.toggle(macro)
        let out = (0..<5).map { processor.process(0, frame: $0) }
        XCTAssertEqual(out, [b.down, b.down, b.down | b.right, b.south, 0])
        XCTAssertTrue(processor.runningMacros.isEmpty)

        var looping = macro
        looping.loops = true
        processor.toggle(looping)
        let looped = (0..<6).map { processor.process(0, frame: $0) }
        XCTAssertEqual(looped[4], b.down, "Starts again")
        processor.cancelMacros()
        XCTAssertEqual(processor.process(0, frame: 6), 0, "Pause stops it")
    }

    func testRecordingBecomesSteps() {
        let processor = FrameInputProcessor()
        processor.startRecording()
        for buttons in [0, b.up, b.up, b.up | b.south, 0, 0] { _ = processor.process(buttons, frame: 0) }
        let steps = Macro.steps(recorded: processor.stopRecording() ?? [])
        XCTAssertEqual(steps, [.init(buttons: b.up, frames: 2), .init(buttons: b.up | b.south, frames: 1)])
        XCTAssertNil(processor.stopRecording())
    }

    // MARK: Session

    private func session(platformID: String = "unknown") throws -> (GameSession, ControllerManager, TouchSkinEngine) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("controls-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("game.mock")
        try Data([1, 2, 3]).write(to: rom)
        let skins = TouchSkinEngine()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        skins.loadDefault()
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Demo", platformID: platformID, romPath: rom.path, coverPath: nil,
                            coreOverride: "mock", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let session = try GameSession(game: game, interface: MockCore_GetInterface()!.pointee, romPath: rom.path,
                                      audio: AudioEngineManager(), controllers: controllers, skins: skins, bindings: [],
                                      shaderID: "original", respectSilentMode: false, saveDirectory: directory)
        return (session, controllers, skins)
    }

    func testTogglesShowTheirState() async throws {
        let (session, _, _) = try session()
        try await session.prepare()
        session.run()
        defer { session.stop() }
        session.applyActions([.turbo(b.south, toggle: true)])
        session.applyActions([])
        XCTAssertEqual(session.turboToggled, b.south, "Toggled on by the press")
        session.applyActions([.turbo(b.south, toggle: true)])
        XCTAssertEqual(session.turboToggled, 0, "Off again by the next press")
        session.applyActions([.app(.mute)])
        XCTAssertTrue(session.muted)
        session.applyActions([])
        session.applyActions([.app(.fastForwardHold)])
        XCTAssertGreaterThan(session.fastForward, 1)
        session.applyActions([])
        XCTAssertEqual(session.fastForward, 1, "Hold ends on release")
        session.applyActions([.app(.nextSlot)])
        XCTAssertEqual(session.quickSlot, 2)
    }

    func testQuickSaveAndLoadUseTheChosenSlot() async throws {
        let (session, _, _) = try session()
        try await session.prepare()
        session.run()
        defer { session.stop() }
        try XCTSkipUnless(session.supportsSaveStates, "The mock core has no save states")
        session.setQuickSlot(3)
        session.quickSave()
        XCTAssertNotNil(session.saves.quickSlot(3))
        session.quickSave()
        XCTAssertEqual(session.saves.slots().count, 1, "Saving again replaces the slot")
        session.quickLoad()
        XCTAssertEqual(session.phase, .running)
    }

    func testRotationKeepsTheSessionRunning() async throws {
        let (session, _, skins) = try session(platformID: "nds")
        var asked: [Bool] = []
        session.screenForOrientation = { upright in
            asked.append(upright)
            return ScreenLayoutStore.defaults(portrait: upright)
        }
        try await session.prepare()
        session.run()
        defer { session.stop() }
        let before = session.stats.frames
        session.setPortrait(true)
        XCTAssertTrue(skins.portrait)
        XCTAssertEqual(session.screen.preset, .stacked, "Two screens stack upright")
        XCTAssertEqual(session.screen.area, .betweenControls)
        session.setPortrait(false)
        XCTAssertEqual(asked, [true, false])
        XCTAssertEqual(session.phase, .running)
        let deadline = Date().addingTimeInterval(5)
        while session.stats.frames <= before + 3, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertGreaterThan(session.stats.frames, before + 3, "The core kept stepping through both turns")
    }

    func testScreenSettingsAreKeptPerOrientation() {
        let store = ScreenLayoutStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("screens-\(UUID().uuidString).json"))
        var sideBySide = ScreenSettings()
        sideBySide.preset = .sideBySide
        store.save(sideBySide, platformID: "nds", gameID: nil)
        XCTAssertEqual(store.settings(platformID: "nds", gameID: nil).preset, .sideBySide)
        XCTAssertEqual(store.settings(platformID: "nds", gameID: nil, portrait: true).preset, .stacked)
    }

    // MARK: Players

    func testPlayersPastTheSystemsCountReachNoPort() {
        var four = Array(repeating: ControllerManager.InputState.zero, count: 4)
        for index in four.indices { four[index].buttons = b.south }
        let capped = GameSession.capped(four, maxPlayers: 2)
        XCTAssertEqual(capped.map(\.buttons), [b.south, b.south, 0, 0])
        XCTAssertEqual(GameSession.capped(four, maxPlayers: 0)[0].buttons, b.south, "Player 1 always plays")
        XCTAssertEqual(CoreCatalog.maxPlayers("n64"), 4)
        XCTAssertEqual(CoreCatalog.maxPlayers("snes"), 2)
        XCTAssertEqual(CoreCatalog.maxPlayers("gba"), 1)
        XCTAssertLessThanOrEqual(CoreCatalog.maxPlayers.values.max() ?? 0, ControllerManager.slotCount)
    }

    func testAControllerJoiningMidGameTakesTheNextPlayer() {
        let controllers = ControllerManager(defaults: UserDefaults(suiteName: "players-\(UUID().uuidString)")!)
        controllers.devices = [.init(id: "a", name: "Xbox", kind: .xbox, vendor: "Microsoft", slot: 0)]
        XCTAssertEqual(controllers.firstFreeSlot(), 1)
        controllers.devices.append(.init(id: "b", name: "DualSense", kind: .dualSense, vendor: "Sony", slot: controllers.firstFreeSlot()))
        XCTAssertEqual(controllers.device(inSlot: 1)?.id, "b")
        controllers.assign("b", to: 3)
        XCTAssertEqual(controllers.device(inSlot: 3)?.id, "b")
        XCTAssertNil(controllers.device(inSlot: 1))
        controllers.devices.removeAll { $0.id == "a" }
        XCTAssertTrue(controllers.touchOwnsPlayerOne, "Touch takes Player 1 back when its controller leaves")
    }

    func testAPadAttachedMidGameReadsThroughItsMappingAsTheNextPlayer() throws {
        let controllers = ControllerManager(defaults: try XCTUnwrap(UserDefaults(suiteName: "hotplug-\(UUID().uuidString)")))
        controllers.devices = []
        let first = GCController.withExtendedGamepad(), second = GCController.withExtendedGamepad()
        controllers.attach(first)
        controllers.attach(second)
        XCTAssertEqual(controllers.devices.map(\.slot), [0, 1])
        controllers.profile = { _ in PadProfile(bindings: [PadBinding(inputs: [.a], action: .buttons(ControllerManager.Button.north))]) }
        try XCTUnwrap(second.extendedGamepad).buttonA.setValue(1)
        let states = controllers.sample()
        XCTAssertEqual(states[1].buttons, ControllerManager.Button.north, "Player 2 reads through the mapping")
        XCTAssertEqual(states[0].buttons, 0)
    }

    func testEachPortReachesARealCore() throws {
        throw XCTSkip("device-pending: needs a two-player core and two controllers on a device (docs/07)")
    }
}
