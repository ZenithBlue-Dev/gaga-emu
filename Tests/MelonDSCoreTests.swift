import XCTest
@testable import GagaEmu

/// melonDS DS through the shared libretro adapter and the real bridge, running the generated homebrew ROM
/// (`NDSTestROM`) on melonDS's free BIOS and built-in firmware.
final class MelonDSCoreTests: GagaTestCase {
    private var directory: URL!
    private var romPath: String!
    private let interface = GagaCoreRegistry_FindByID("melonds_ds")!.pointee
    private static let headerSize = 16

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("melonds_ds"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("melonds-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("homebrew.nds")
        try NDSTestROM.build().write(to: rom)
        romPath = rom.path
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// The last frame's bytes and the audio so far. Only touched inside `step`, which is a queue barrier.
    private final class Capture {
        var pixels: [UInt8] = []
        var width = 0
        var height = 0
        var pitch = 0
        var format = GagaPixelFormat(rawValue: 99)
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var channels: UInt8 = 0
        var fatal: String?

        /// XRGB8888, little endian, cut to 5 bits per channel: melonDS widens 5 bits by shifting.
        func pixel(x: Int, y: Int) -> UInt16 {
            let i = y * pitch + x * 4
            return UInt16(pixels[i + 2] >> 3) | UInt16(pixels[i + 1] >> 3) << 5 | UInt16(pixels[i] >> 3) << 10
        }
    }

    private func makeCore(saveDirectory: String? = nil) throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: saveDirectory ?? directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            capture.width = frame.width
            capture.height = frame.height
            capture.pitch = frame.pitch
            capture.format = frame.pixelFormat
            guard let bytes = frame.pixelData else { return }
            capture.pixels = Array(UnsafeRawBufferPointer(start: bytes, count: frame.pitch * frame.height))
        }
        core.onAudioPacket = { packet in
            capture.sampleRate = packet.sampleRate
            capture.channels = packet.channels
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) {
                capture.left.append(packet.samples[index])
            }
        }
        core.onEvent = { event in
            if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message }
        }
        return (core, capture)
    }

    private func loaded(path: String? = nil) async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: path ?? romPath)
        return (core, capture)
    }

    /// A finger on lower-screen pixel `touch`, in libretro's pointer scale over the whole frame.
    private func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0, touch: (x: Int, y: Int)? = nil) {
        var input = GagaInputState()
        input.buttons = buttons
        if let touch {
            func scale(_ pixel: Int, _ size: Int) -> Int16 { Int16(((Double(pixel) + 0.5) / Double(size) * 65534 - 32767).rounded()) }
            input.pointer_x = scale(NDSTestROM.screenWidth + touch.x, NDSTestROM.frameWidth)
            input.pointer_y = scale(touch.y, NDSTestROM.screenHeight)
            input.pointer_down = true
        }
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    private func assertPicture(_ capture: Capture, keys: UInt32 = 0, toggle: Bool = false, cheat: Bool = false,
                               touch: (x: Int, y: Int)? = nil, file: StaticString = #filePath, line: UInt = #line) {
        var wrong = 0
        var first: String?
        for y in 0..<NDSTestROM.screenHeight {
            for x in 0..<NDSTestROM.frameWidth {
                let want = NDSTestROM.expectedColor(x: x, y: y, keys: keys, toggle: toggle, cheat: cheat, touch: touch)
                let got = capture.pixel(x: x, y: y)
                if got != want {
                    wrong += 1
                    if first == nil { first = "(\(x), \(y)): \(String(got, radix: 16)) not \(String(want, radix: 16))" }
                }
            }
        }
        XCTAssertEqual(wrong, 0, "pixels that differ from the expected picture, first \(first ?? "none")", file: file, line: line)
    }

    private let chord = UInt32(GAGA_BTN_L1.rawValue | GAGA_BTN_R1.rawValue)

    /// Press and release L and R, then leave frames for the program to draw the result.
    private func flipToggle(_ core: GagaCoreWrapper) {
        run(core, frames: 2, buttons: chord)
        run(core, frames: 3)
    }

    // MARK: - ROM generator

    func testGeneratedHeaderChecks() {
        let rom = [UInt8](NDSTestROM.build())
        XCTAssertEqual(rom.count, 0x10000)
        XCTAssertEqual(UInt16(rom[0x15E]) | UInt16(rom[0x15F]) << 8, NDSTestROM.crc16(rom[0..<0x15E]))
        XCTAssertEqual(NDSTestROM.crc16([0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]), 0x4B37, "CRC-16/MODBUS check value")
        XCTAssertTrue(rom[0xC0..<0x15C].allSatisfy { $0 == 0 }, "no Nintendo logo in the ROM")
        XCTAssertEqual(Array(rom[0x0C..<0x10]), Array(NDSTestROM.gameCode.utf8))
        XCTAssertEqual(UInt32(rom[0x20]) | UInt32(rom[0x21]) << 8, 0x8000, "ARM9 past the secure area")
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("melonds_ds")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertTrue(String(cString: found.core_version).hasPrefix("1.4.0"))
        XCTAssertEqual(found.native_sample_rate, 32728)
        XCTAssertEqual(found.target_fps, 59.8261, accuracy: 0.001)
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("nds")).pointee.core_id), "melonds_ds")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "nds"), "melonds_ds")
    }

    func testBootsDirectlyAndDrawsBothScreensSideBySide() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        XCTAssertEqual(capture.width, NDSTestROM.frameWidth)
        XCTAssertEqual(capture.height, NDSTestROM.screenHeight)
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888)
        XCTAssertNil(capture.fatal)
        assertPicture(capture)
        core.stop()
    }

    func testEachButtonLightsItsCell() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        // KEYINPUT order, then X and Y. Touch A is the bridge's EAST, and B is its SOUTH.
        let order: [GagaButtonMask] = [GAGA_BTN_EAST, GAGA_BTN_SOUTH, GAGA_BTN_SELECT, GAGA_BTN_START,
                                       GAGA_BTN_RIGHT, GAGA_BTN_LEFT, GAGA_BTN_UP, GAGA_BTN_DOWN,
                                       GAGA_BTN_R1, GAGA_BTN_L1, GAGA_BTN_NORTH, GAGA_BTN_WEST]
        for (bit, button) in order.enumerated() {
            run(core, frames: 3, buttons: UInt32(button.rawValue))
            assertPicture(capture, keys: 1 << UInt32(bit))
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    /// The pointer covers the whole side-by-side frame, and the core maps it onto the lower screen only.
    func testTouchLandsUnderTheFingerOnTheLowerScreen() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        for point in [(x: 0, y: 0), (x: 100, y: 50), (x: 255, y: 191), (x: 130, y: 180)] {
            run(core, frames: 4, touch: point)
            assertPicture(capture, touch: point)
        }
        run(core, frames: 4)
        assertPicture(capture)
        core.stop()
    }

    @MainActor
    func testAFingerMapsThroughTheFittedPicture() throws {
        let bounds = CGSize(width: 1000, height: 300), content = CGSize(width: 512, height: 192)
        // Scale 300 / 192, so the picture is 800 wide from x = 100.
        let corner = try XCTUnwrap(GameSession.libretroPointer(CGPoint(x: 100, y: 0), bounds: bounds, content: content))
        XCTAssertEqual(corner.x, -32767)
        XCTAssertEqual(corner.y, -32767)
        let middle = try XCTUnwrap(GameSession.libretroPointer(CGPoint(x: 500, y: 150), bounds: bounds, content: content))
        XCTAssertEqual(middle.x, 0)
        XCTAssertEqual(middle.y, 0)
        let lowerScreen = try XCTUnwrap(GameSession.libretroPointer(CGPoint(x: 700, y: 75), bounds: bounds, content: content))
        XCTAssertEqual(lowerScreen.x, 16384, accuracy: 1)
        XCTAssertEqual(lowerScreen.y, -16384, accuracy: 1)
        XCTAssertNil(GameSession.libretroPointer(CGPoint(x: 99, y: 150), bounds: bounds, content: content), "letterbox")
        XCTAssertNil(GameSession.libretroPointer(CGPoint(x: 900, y: 150), bounds: bounds, content: content), "letterbox")
    }

    /// Device pending (docs/07 5.7): the frame melonDS DS sends with GagaEmu's options is the arrangement
    /// ScreenLayout cuts, top screen left and bottom screen right with no gap.
    func testTheFrameIsTheArrangementScreenLayoutCuts() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        let regions = try XCTUnwrap(ScreenLayout.regions(platformID: "nds", frame: CGSize(width: capture.width, height: capture.height)))
        XCTAssertEqual(regions.map(\.pixels), [CGSize(width: NDSTestROM.screenWidth, height: NDSTestROM.screenHeight),
                                               CGSize(width: NDSTestROM.screenWidth, height: NDSTestROM.screenHeight)])
        for region in regions {
            let left = Int(region.rect.minX * CGFloat(capture.width))
            for (x, y) in [(0, 0), (region.pixels.width - 1, 0), (0, region.pixels.height - 1), (region.pixels.width / 2, region.pixels.height / 2)] {
                let fx = left + Int(x), fy = Int(y)
                XCTAssertEqual(capture.pixel(x: fx, y: fy), NDSTestROM.expectedColor(x: fx, y: fy, keys: 0, toggle: false, cheat: false, touch: nil),
                               "\(region.id) screen at (\(fx), \(fy))")
            }
        }
        core.stop()
    }

    /// Device pending (docs/07 5.7): a finger on the bottom screen drawn stacked, smaller, swapped and turned
    /// still reaches the core under the finger.
    func testAFingerOnAPlacedBottomScreenLandsUnderIt() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        var settings = ScreenSettings()
        settings.preset = .largeTop
        settings.swapped = true
        settings.rotation = .left
        let placements = ScreenLayout.placements(frame: CGSize(width: NDSTestROM.frameWidth, height: NDSTestROM.screenHeight),
                                                 canvas: CGSize(width: 2556, height: 1179), platformID: "nds", settings: settings)
        let bottom = try XCTUnwrap(placements.first { $0.id == .bottom })
        let touch = (x: 100, y: 50)
        // Where that pixel's centre is drawn: Turn Left shows source (sx, sy) at (sy, 1 - sx).
        let sx = (Double(touch.x) + 0.5) / Double(NDSTestROM.screenWidth), sy = (Double(touch.y) + 0.5) / Double(NDSTestROM.screenHeight)
        let finger = CGPoint(x: bottom.dest.minX + sy * bottom.dest.width, y: bottom.dest.minY + (1 - sx) * bottom.dest.height)
        let pointer = try XCTUnwrap(ScreenLayout.pointer(at: finger, placements: placements))
        var input = GagaInputState()
        input.pointer_x = pointer.x
        input.pointer_y = pointer.y
        input.pointer_down = true
        for _ in 0..<4 { core.step(inputs: [input]) }
        assertPicture(capture, touch: touch)
        core.stop()
    }

    func testAudioIsTheExpectedTone() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 120)
        XCTAssertEqual(capture.sampleRate, 32728)
        XCTAssertEqual(capture.channels, 2)
        XCTAssertEqual(Double(capture.left.count), 120 * 32728 / 59.8261, accuracy: 1100)
        let tone = capture.left.dropFirst(capture.left.count / 2)
        XCTAssertGreaterThan(Int(tone.max() ?? 0) - Int(tone.min() ?? 0), 500, "not silent")
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        let hertz = Double(crossings) / 2 / (Double(tone.count) / 32728)
        XCTAssertEqual(hertz, NDSTestROM.toneHertz, accuracy: NDSTestROM.toneHertz * 0.05)
        core.stop()
    }

    func testRunningTheCoreCreatesNoGeneratedCode() async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded()
        run(core, frames: 300, buttons: UInt32(GAGA_BTN_EAST.rawValue), touch: (x: 10, y: 10))
        core.stop()
        XCTAssertEqual(capture.width, NDSTestROM.frameWidth)
        XCTAssertEqual(CodeGenCheck.violations(), [])
    }

    func testSessionPerLaunchIsFreshEachTime() async throws {
        for _ in 0..<3 {
            let (core, capture) = try await loaded()
            run(core, frames: 12)
            assertPicture(capture)
            core.stop()
        }
    }

    // MARK: - Bad files

    func testBadFilesGiveAMessageForThePlayer() async throws {
        let empty = directory.appendingPathComponent("empty.nds")
        try Data().write(to: empty)
        let noise = directory.appendingPathComponent("noise.nds")
        try Data((0..<0x10000).map { UInt8(truncatingIfNeeded: $0 &* 73) }).write(to: noise)
        var damaged = [UInt8](NDSTestROM.build())
        damaged[0x00] ^= 1
        let badHeader = directory.appendingPathComponent("damaged.nds")
        try Data(damaged).write(to: badHeader)
        var outside = [UInt8](NDSTestROM.build())
        outside[0x3E] = 0x01 // ARM7 size past the end of the file, with the header CRC fixed.
        let crc = NDSTestROM.crc16(outside[0..<0x15E])
        outside[0x15E] = UInt8(crc & 0xFF); outside[0x15F] = UInt8(crc >> 8)
        let badBinary = directory.appendingPathComponent("outside.nds")
        try Data(outside).write(to: badBinary)

        let notAGame = "This file is not a Nintendo DS game."
        let cases = [(empty.path, notAGame), (noise.path, notAGame), (badHeader.path, notAGame), (badBinary.path, notAGame),
                     (directory.appendingPathComponent("gone.nds").path, "The game file could not be opened.")]
        for (path, message) in cases {
            let (core, _) = try makeCore()
            do {
                try await core.loadROM(path: path)
                XCTFail("loaded \(path)")
            } catch {
                XCTAssertEqual(error.localizedDescription, message)
            }
            core.stop()
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("noise.sav").path),
                       "a refused file must not leave a save behind")
    }

    // MARK: - Battery saves

    func testBatterySaveReachesItsFileAndSurvivesARestart() async throws {
        let save = directory.appendingPathComponent("homebrew.sav")
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 12)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, NDSTestROM.saveSize)
            XCTAssertEqual(Array(flushed[0..<4]), NDSTestROM.eepromMagic)
            XCTAssertEqual(Int(flushed[NDSTestROM.eepromBootCounterOffset]), boot, "on disk when the flush returns")
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[NDSTestROM.eepromBootCounterOffset]), boot)
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [])
    }

    // MARK: - Save states

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<Self.headerSize + 4]), Array("MELN".utf8))
        XCTAssertEqual(UInt32(state[Self.headerSize + 4]) | UInt32(state[Self.headerSize + 5]) << 8, core.stateVersion)
        core.stop()
    }

    func testRoundTripPlaysBackExactlyAndRestoresTheCPU() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        assertPicture(capture, toggle: true)
        let state = try core.saveState()

        // The same scripted input from the same state must give the same frames, byte for byte.
        func script() -> [[UInt8]] {
            (0..<30).map { frame in
                run(core, frames: 1, buttons: frame == 15 ? chord : frame % 7 == 0 ? UInt32(GAGA_BTN_START.rawValue) : 0,
                    touch: frame % 5 == 0 ? (x: frame * 8, y: frame * 6) : nil)
                return capture.pixels
            }
        }
        let first = script()
        run(core, frames: 3)
        assertPicture(capture, toggle: false)
        try core.loadState(state)
        let second = script()
        XCTAssertEqual(first, second)

        // The flag is only in an ARM9 register, so this proves the CPU came back, not just memory.
        try core.loadState(state)
        run(core, frames: 3)
        assertPicture(capture, toggle: true)
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        var other = [UInt8](NDSTestROM.build())
        other[other.count - 1] = 0x55
        let otherROM = directory.appendingPathComponent("other.nds")
        try Data(other).write(to: otherROM)
        let (foreign, _) = try await loaded(path: otherROM.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 12)
        flipToggle(core)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for melonDS DS."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var wrongVersion = state // Past the adapter's checks: melonDS itself must refuse this one.
        wrongVersion[Self.headerSize + 4] ^= 0xFF
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (wrongVersion, "melonDS DS could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertPicture(capture, toggle: true)
        }
        flipToggle(core)
        assertPicture(capture, toggle: false)
        core.stop()
    }

    // MARK: - Cheats

    /// Action Replay DS 0XXXXXXX YYYYYYYY: write the word Y to X, each time the ARM7 takes an interrupt.
    private let replay = "02200000 00000001"

    func testCheatsHaveTheirEffectAndStop() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        assertPicture(capture)

        try core.addCheat(id: 1, code: replay, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.setCheat(id: 1, enabled: false)
        run(core, frames: 3)
        assertPicture(capture)
        core.setCheat(id: 1, enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.removeCheat(id: 1)
        run(core, frames: 3)
        assertPicture(capture)

        // Several lines are one cheat, so a two-line code (here a write, then a harmless one) works as a unit.
        try core.addCheat(id: 2, code: " \(replay.lowercased()) \n\n02300100 00000000\n", enabled: true)
        run(core, frames: 3)
        assertPicture(capture, cheat: true)
        core.removeCheat(id: 2)
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()

        let (next, nextCapture) = try await loaded()
        run(next, frames: 12)
        assertPicture(nextCapture)
        next.stop()
    }

    func testBadCodesAreRefusedAndAddNothing() async throws {
        let (core, capture) = try await loaded()
        run(core, frames: 12)
        let cases = [("", "Enter a cheat code."), (" \n ", "Enter a cheat code."),
                     ("ZZZZZZZZ YYYYYYYY", "melonDS DS does not recognise this code: ZZZZZZZZ YYYYYYYY"),
                     ("02200000", "melonDS DS does not recognise this code: 02200000"),
                     ("\(replay)\nnope", "melonDS DS does not recognise this code: nope")]
        for (code, message) in cases {
            XCTAssertThrowsError(try core.addCheat(id: 9, code: code, enabled: true)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
        }
        run(core, frames: 3)
        assertPicture(capture)
        core.stop()
    }

    @MainActor
    func testUploadedGamesPickThisCore() async {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() } // Leaves no upload- entry in the saved Library.
        let name = "upload-\(UUID().uuidString).nds"
        await state.addUploads([name])
        let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
        XCTAssertEqual(added?.platformID, "nds")
        XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), "melonds_ds")
    }

    // MARK: - Debug launch arguments

    /// `-GagaBenchmarkCore melonds_ds` with no ROM: the generated DS ROM and a record named for this core.
    @MainActor
    func testBenchmarkRunsOnThisCore() async throws {
        let rom = try BenchmarkRun.writeTestROM(platformID: "nds", to: directory)
        XCTAssertEqual(rom.pathExtension, "nds")
        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let game = GameItem(id: UUID(), title: "Benchmark", platformID: "nds", romPath: rom.path, coverPath: nil,
                            coreOverride: "melonds_ds", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let session = try GameSession(game: game, interface: interface, romPath: rom.path, audio: AudioEngineManager(),
                                      controllers: controllers, skins: skins, bindings: [], shaderID: "original",
                                      respectSilentMode: false)
        try await session.prepare()
        let run = BenchmarkRun(session: session, interface: interface, romURL: rom, seconds: 2, warmup: 0.2)
        run.attach()
        var written: URL?
        run.onWritten = { written = $0 }
        session.run()
        await run.drive()

        let url = try XCTUnwrap(written)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(url.lastPathComponent.hasPrefix("melonds_ds-"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((record["core"] as? [String: Any])?["id"] as? String, "melonds_ds")
        XCTAssertGreaterThan(try XCTUnwrap(record["frames"] as? Int), 30)
        XCTAssertEqual(record["codeGenViolations"] as? [String], [])
    }

    /// `-GagaImportROM <path>`: copied into the ROM folder, added once however often the app relaunches.
    @MainActor
    func testDebugImportAddsTheGameOnce() async throws {
        let state = AppState()
        let saved = Set(state.games.map(\.id))
        let source = directory.appendingPathComponent("debug-import-\(UUID().uuidString).nds")
        try NDSTestROM.build().write(to: source)
        let dest = state.romDirectory.appendingPathComponent(source.lastPathComponent)
        defer {
            for game in state.games where !saved.contains(game.id) { state.delete(game) }
            try? FileManager.default.removeItem(at: dest)
        }
        try await state.importDebugROM(at: source)
        try await state.importDebugROM(at: source)
        let added = state.games.filter { URL(fileURLWithPath: $0.romPath).lastPathComponent == source.lastPathComponent }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.platformID, "nds")
        XCTAssertEqual(added.first?.resolvedCoreID(defaults: [:]), "melonds_ds")
        XCTAssertEqual(try Data(contentsOf: dest), try Data(contentsOf: source))
    }
}
