import AVFoundation
import Metal
import XCTest
@testable import GagaEmu

// C function pointers cannot capture, so the fatal-event core keeps its callback here.
private var injectedEvent: (@convention(c) (GagaEventSeverity, Int32, UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void)?
private var injectedUserdata: UnsafeMutableRawPointer?

@MainActor
final class GameSessionTests: XCTestCase {
    private var directory: URL!
    private var romPath: String!
    private var skins: TouchSkinEngine!
    private var controllers: ControllerManager!
    private let mock = MockCore_GetInterface()!.pointee

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rom = directory.appendingPathComponent("game.mock")
        try Data([1, 2, 3]).write(to: rom)
        romPath = rom.path
        skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        skins.soundEnabled = false
        // The simulator can report a "Gamepad" controller, which would own player 1.
        controllers = ControllerManager()
        controllers.devices = []
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func game(path: String? = nil) -> GameItem {
        GameItem(id: UUID(), title: "Demo", platformID: "unknown", romPath: path ?? romPath, coverPath: nil,
                 coreOverride: "mock", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "crt-v1")
    }

    private func makeSession(interface: GagaCoreInterface? = nil, path: String? = nil,
                             bindings: [TriggerProManager.Binding] = []) throws -> GameSession {
        try GameSession(game: game(), interface: interface ?? mock, romPath: path ?? romPath,
                        audio: AudioEngineManager(), controllers: controllers, skins: skins,
                        bindings: bindings, shaderID: "crt-v1", respectSilentMode: false)
    }

    private func started(interface: GagaCoreInterface? = nil, bindings: [TriggerProManager.Binding] = []) async throws -> GameSession {
        let session = try makeSession(interface: interface, bindings: bindings)
        try await session.prepare()
        session.run()
        return session
    }

    private func waitForFrames(_ session: GameSession, _ count: Int, file: StaticString = #filePath, line: UInt = #line) async throws {
        let start = session.stats.frames
        let deadline = Date().addingTimeInterval(5)
        while session.stats.frames < start + count {
            if Date() > deadline {
                XCTFail("Frames did not advance", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func center(of id: String) throws -> CGPoint {
        let frame = try XCTUnwrap(skins.skin?.buttons.first { $0.id == id }).frame
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: - Lifecycle

    func testStartPauseResumeStopRestart() async throws {
        for _ in 0..<2 {
            let session = try await started()
            XCTAssertEqual(session.phase, .running)
            try await waitForFrames(session, 5)
            let running = session.stats
            XCTAssertGreaterThan(running.videoWritten, 0)
            XCTAssertGreaterThan(running.audioWritten, 0)

            session.pause(.menu)
            XCTAssertEqual(session.phase, .paused)
            XCTAssertTrue(session.menuOpen)
            let paused = session.stats.frames
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(session.stats.frames, paused, "No frame may run while paused")

            session.resume(.menu)
            XCTAssertEqual(session.phase, .running)
            try await waitForFrames(session, 5)

            session.stop()
            XCTAssertEqual(session.phase, .stopped)
            session.stop() // Safe twice.
        }
    }

    func testFrameRateMatchesTheCore() async throws {
        let session = try await started()
        try await waitForFrames(session, 2)
        let begin = session.stats.frames
        let start = Date()
        try await Task.sleep(for: .seconds(1))
        let rate = Double(session.stats.frames - begin) / Date().timeIntervalSince(start)
        session.stop()
        XCTAssertEqual(rate, 60, accuracy: 6)
    }

    func testPauseReasonsAllHaveToClear() async throws {
        let session = try await started()
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertEqual(session.phase, .paused)
        session.pause(.menu)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(session.phase, .paused, "The menu is still open")
        session.resume(.menu)
        XCTAssertEqual(session.phase, .running)
        session.stop()
    }

    func testInterruptionPausesAndResumes() async throws {
        let session = try await started()
        func post(_ type: AVAudioSession.InterruptionType, _ options: AVAudioSession.InterruptionOptions = []) {
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
                AVAudioSessionInterruptionTypeKey: type.rawValue,
                AVAudioSessionInterruptionOptionKey: options.rawValue
            ])
        }
        post(.began)
        XCTAssertEqual(session.phase, .paused)
        post(.ended, .shouldResume)
        XCTAssertEqual(session.phase, .running)

        // Without shouldResume the player decides, from the menu.
        post(.began)
        post(.ended)
        XCTAssertEqual(session.phase, .paused)
        XCTAssertTrue(session.menuOpen)
        session.stop()
    }

    func testStoppedSessionIsReleased() async throws {
        weak var released: GameSession?
        for _ in 0..<10 {
            let session = try await started()
            released = session
            try await waitForFrames(session, 1)
            session.stop()
        }
        await Task.yield()
        XCTAssertNil(released)
    }

    /// Exercises teardown with a frame in flight. Most useful under Thread Sanitizer.
    func testTeardownWhileFramesRun() async throws {
        for index in 0..<30 {
            let session = try await started()
            if index % 3 == 0 { session.pause(.menu) }
            if index % 3 == 1 { try await Task.sleep(for: .milliseconds(Int.random(in: 0...20))) }
            session.stop()
        }
    }

    func testPlayTimeCountsOnlyWhileRunningAndUpdatesOnEveryPause() async throws {
        let session = try await started()
        var total: TimeInterval = 0
        var finished: [String?] = []
        session.onPlayTime = { total += $0 }
        session.onFinish = { finished.append($0) }
        try await Task.sleep(for: .milliseconds(100))
        session.pause(.menu)
        let atPause = total
        XCTAssertGreaterThan(atPause, 0)
        try await Task.sleep(for: .milliseconds(100))
        session.stop()
        XCTAssertEqual(total, atPause, "Paused time does not count")
        XCTAssertEqual(finished.count, 1)
        XCTAssertNil(finished[0] ?? nil)
    }

    func testRecordPlayAddsToGameAndNewestHistoryEntry() {
        let state = AppState()
        let saved = (state.games, state.history)
        defer { state.games = saved.0; state.history = saved.1 }
        let item = game()
        state.games = [item]
        state.history = [PlaySession(id: UUID(), gameID: item.id, started: Date(), duration: 0)]
        state.recordPlay(gameID: item.id, seconds: 3)
        state.recordPlay(gameID: item.id, seconds: 2)
        XCTAssertEqual(state.games[0].playTime, 5)
        XCTAssertEqual(state.history[0].duration, 5)
        XCTAssertNotNil(state.games[0].lastPlayed)
        XCTAssertEqual(state.recentGames.first?.id, item.id, "Continue finds it")
    }

    // MARK: - Failures

    func testEmptyROMFailsWithTheCoresMessage() async throws {
        let empty = directory.appendingPathComponent("empty.mock")
        try Data().write(to: empty)
        let session = try makeSession(path: empty.path)
        do {
            try await session.prepare()
            XCTFail("Should have failed")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The game file is empty or unreadable.")
        }
        XCTAssertEqual(session.phase, .idle)
        session.run() // Nothing prepared: must do nothing.
        XCTAssertEqual(session.phase, .idle)
        session.stop()
    }

    func testMissingFileAndMissingCoreHaveClearMessages() throws {
        let state = AppState()
        var item = game(path: "/nowhere/gone.mock")
        XCTAssertThrowsError(try state.makeSession(for: item)) {
            XCTAssertTrue($0.localizedDescription.contains("gone.mock"))
        }
        item.coreOverride = "nestopia"
        XCTAssertThrowsError(try state.makeSession(for: item)) {
            XCTAssertEqual($0.localizedDescription, "Nestopia UE is not part of this build yet.")
        }
        item.coreOverride = nil
        XCTAssertThrowsError(try state.makeSession(for: item)) {
            XCTAssertEqual($0.localizedDescription, GameLaunchError.noCore.localizedDescription)
        }
    }

    func testWrongABIIsRejectedWithClearError() async throws {
        var wrong = mock
        wrong.abi_version = GAGA_BRIDGE_ABI_VERSION + 1
        XCTAssertThrowsError(try GagaCoreWrapper(interface: wrong)) {
            XCTAssertEqual($0.localizedDescription, "This core was built for bridge version 4, but the app needs version 3.")
        }

        let session = try makeSession(interface: wrong)
        do {
            try await session.prepare()
            XCTFail("Should have failed")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("bridge version"))
        }
    }

    func testFailingSelfTestIsRejected() throws {
        var failing = mock
        failing.self_test = { error, capacity in
            _ = "Broken".withCString { strlcpy(error, $0, capacity) }
            return false
        }
        XCTAssertThrowsError(try GagaCoreWrapper(interface: failing)) {
            XCTAssertEqual($0.localizedDescription, "Broken")
        }
    }

    func testStubCoresFailInsteadOfShowingBlack() throws {
        let stub = try XCTUnwrap(GagaCoreRegistry_FindByID("bsnes")).pointee
        XCTAssertEqual(stub.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertThrowsError(try GagaCoreWrapper(interface: stub)) {
            XCTAssertEqual($0.localizedDescription, "This core is not part of this build yet.")
        }
    }

    func testEveryRegistryEntryHasTheBridgeAdditions() throws {
        for index in 0..<GagaCoreRegistry_GetCount() {
            let core = try XCTUnwrap(GagaCoreRegistry_GetAtIndex(index)).pointee
            XCTAssertEqual(core.abi_version, GAGA_BRIDGE_ABI_VERSION)
            XCTAssertNotNil(core.self_test)
            XCTAssertNotNil(core.pause)
            XCTAssertNotNil(core.resume)
            XCTAssertNotNil(core.set_event_callback)
        }
    }

    func testFatalEventEndsTheSessionWithItsMessage() async throws {
        var failing = mock
        failing.set_event_callback = { _, callback, userdata in
            injectedEvent = callback
            injectedUserdata = userdata
        }
        failing.step_frame = { _, _, _ in
            "Core crashed.".withCString { injectedEvent?(GAGA_EVENT_FATAL, 9, $0, injectedUserdata) }
        }
        let session = try await started(interface: failing)
        let finished = expectation(description: "Finished")
        session.onFinish = { message in
            XCTAssertEqual(message, "Core crashed.")
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(session.phase, .stopped)
    }

    // MARK: - Bridge

    func testPauseAndResumeReachTheCore() async throws {
        let wrapper = try GagaCoreWrapper(interface: mock)
        let lock = NSLock()
        var events: [Int32] = []
        wrapper.onEvent = { event in
            lock.lock()
            events.append(event.code)
            lock.unlock()
        }
        try await wrapper.loadROM(path: romPath)
        wrapper.start()
        try await Task.sleep(for: .milliseconds(50))
        wrapper.pause()
        wrapper.resume()
        try await Task.sleep(for: .milliseconds(50))
        wrapper.stop()
        // 3 would be the mock's step-while-paused report.
        XCTAssertEqual(events, [1, 2])
    }

    func testInputReachesTheMockCore() async throws {
        let wrapper = try GagaCoreWrapper(interface: mock)
        try await wrapper.loadROM(path: romPath)
        var centre: UInt32 = 0
        wrapper.onVideoFrame = { frame in
            let row = frame.pixelData!.advanced(by: frame.height / 2 * frame.pitch)
            centre = row.advanced(by: frame.width / 2 * 4).load(as: UInt32.self)
        }
        var pressed = GagaInputState()
        pressed.buttons = GAGA_BTN_UP.rawValue
        wrapper.step(inputs: [pressed])
        XCTAssertEqual(centre, 0xFFFF_FFFF, "D-pad draws a white box")
        wrapper.step(inputs: [GagaInputState()])
        XCTAssertNotEqual(centre, 0xFFFF_FFFF)
        wrapper.stop()
    }

    // MARK: - Video

    func testShaderPresetAppliesToRenderer() throws {
        XCTAssertEqual(try makeSession().renderer.activePreset, .crtV1)
    }

    func testAspectFitLetterboxesAndPillarboxes() {
        let wide = MetalRenderer.fittedViewport(contentWidth: 256, contentHeight: 224, drawable: CGSize(width: 2000, height: 1000))
        XCTAssertEqual(wide.height, 1000)
        XCTAssertEqual(wide.width, 1143)
        XCTAssertEqual(wide.originX, 428.5)
        XCTAssertEqual(wide.originY, 0)

        let tall = MetalRenderer.fittedViewport(contentWidth: 240, contentHeight: 160, drawable: CGSize(width: 600, height: 1000))
        XCTAssertEqual(tall.width, 600)
        XCTAssertEqual(tall.height, 400)
        XCTAssertEqual(tall.originY, 300)
    }

    func testRingMapsEveryBridgeFormat() throws {
        XCTAssertEqual(MetalTextureRing.metalFormat(for: GAGA_PIXEL_FORMAT_RGB565), .b5g6r5Unorm)
        XCTAssertEqual(MetalTextureRing.metalFormat(for: GAGA_PIXEL_FORMAT_XRGB8888), .bgra8Unorm)
        XCTAssertEqual(MetalTextureRing.metalFormat(for: GAGA_PIXEL_FORMAT_RGBA8888), .rgba8Unorm)
        XCTAssertNil(MetalTextureRing.metalFormat(for: GagaPixelFormat(rawValue: 9)))
    }

    func testRingCopiesRowsWhenPitchIsWiderThanTheFrame() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let ring = MetalTextureRing(device: device, width: 2, height: 2)
        let source: [UInt32] = [1, 2, 0xDEAD, 3, 4, 0xDEAD] // Pitch of three pixels.
        let texture = try source.withUnsafeBytes {
            try XCTUnwrap(ring.writeFrame(pixelData: $0.baseAddress!, width: 2, height: 2, pitch: 12, pixelFormat: .rgba8Unorm))
        }
        var result = [UInt32](repeating: 0, count: 4)
        result.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0)
        }
        XCTAssertEqual(result, [1, 2, 3, 4])
    }

    #if targetEnvironment(simulator)
    func testSimulatorExpands565() {
        let source: [UInt16] = [0xF800, 0x07E0, 0x001F, 0x0000]
        var result = [UInt32](repeating: 0, count: 4)
        source.withUnsafeBytes { input in
            result.withUnsafeMutableBytes { output in
                MetalTextureRing.expand565(input.baseAddress!, to: output.baseAddress!, pixels: 4)
            }
        }
        XCTAssertEqual(result, [0xFFFF_0000, 0xFF00_FF00, 0xFF00_00FF, 0xFF00_0000])
    }
    #endif

    /// Start cycles the mock's format and Select its size. Follows touch to core to ring.
    func testFormatAndSizeChangesReachTheRing() async throws {
        let session = try await started()
        try await waitForFrames(session, 2)
        XCTAssertEqual(session.ring.stats.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(session.ring.stats.width, 256)

        session.setTouches([try center(of: "start")])
        try await waitForFrames(session, 3)
        session.setTouches([])
        #if targetEnvironment(simulator)
        // No 16-bit formats on the simulator's GPU, so the ring expands them. Real size stays.
        XCTAssertEqual(session.ring.stats.pixelFormat, .bgra8Unorm)
        XCTAssertEqual(session.ring.stats.width, 256)
        #else
        XCTAssertEqual(session.ring.stats.pixelFormat, .b5g6r5Unorm)
        #endif

        try await waitForFrames(session, 2)
        session.setTouches([try center(of: "start")])
        try await waitForFrames(session, 3)
        session.setTouches([])
        XCTAssertEqual(session.ring.stats.pixelFormat, .bgra8Unorm)

        try await waitForFrames(session, 2)
        session.setTouches([try center(of: "select")])
        try await waitForFrames(session, 3)
        session.setTouches([])
        XCTAssertEqual(session.ring.stats.width, 160)
        XCTAssertEqual(session.ring.stats.height, 144)
        session.stop()
    }

    // MARK: - Input

    func testTouchFeedsTheCoreAndClearsOnMenu() async throws {
        let session = try await started()
        session.setTouches([try center(of: "up")])
        try await waitForFrames(session, 2)
        XCTAssertEqual(session.stats.buttons, ControllerManager.Button.up)

        session.pause(.menu)
        XCTAssertTrue(skins.pressed.isEmpty, "Opening the menu releases held controls")
        session.resume(.menu)
        try await waitForFrames(session, 2)
        XCTAssertEqual(session.stats.buttons, 0)
        session.stop()
    }

    func testControllerInPlayerOneSlotTakesOverFromTouch() async throws {
        let session = try await started()
        controllers.devices = [.init(id: "pad", name: "Pad", kind: .mfi, vendor: "", slot: 0, hasSentInput: true)]
        XCTAssertFalse(controllers.touchOwnsPlayerOne, "GameView hides the controls on this")
        session.setTouches([try center(of: "up")])
        try await waitForFrames(session, 2)
        XCTAssertEqual(session.stats.buttons, 0)
        session.stop()
    }

    func testTriggerProProcessesInputOnTheFrameLoop() async throws {
        let south = ControllerManager.Button.south
        let hold = TriggerProManager.Binding(name: "Run", mode: .hold, source: south, output: south)
        let session = try await started(bindings: [hold])
        session.setTouches([try center(of: "south")])
        try await waitForFrames(session, 2)
        session.setTouches([])
        try await waitForFrames(session, 2)
        XCTAssertEqual(session.stats.buttons & south, south, "Latched after release")
        session.stop()
    }

    func testSkinHoldsDiagonalsSlidesAndMultitouch() throws {
        let b = ControllerManager.Button.self
        XCTAssertEqual(skins.setTouches([try center(of: "upright")]), b.up | b.right)
        XCTAssertEqual(skins.setTouches([try center(of: "up")]), b.up, "Slide off the diagonal")
        XCTAssertEqual(skins.setTouches([try center(of: "up"), try center(of: "south")]), b.up | b.south)
        XCTAssertEqual(skins.setTouches([try center(of: "up"), try center(of: "up")]), b.up, "Two fingers, one button")
        XCTAssertEqual(skins.setTouches([]), 0)
    }

    func testDefaultLayoutStaysInTheBandsWithLargeTargets() throws {
        let band = TouchSkinEngine.controlBand
        let buttons = TouchSkinEngine.Layout.standard.buttons
        for button in buttons {
            let inLeft = button.frame.maxX <= band
            let inRight = button.frame.minX >= 1 - band
            XCTAssertTrue(inLeft || inRight, "\(button.id) overlaps the picture")
            XCTAssertLessThanOrEqual(button.frame.maxY, 1)
            // iPhone 17e landscape safe canvas: 750 by 369 points.
            XCTAssertGreaterThanOrEqual(button.frame.width * 750, 44, button.id)
            XCTAssertGreaterThanOrEqual(button.frame.height * 369, 44, button.id)
        }
        XCTAssertEqual(Set(buttons.map(\.id)).count, buttons.count)
    }

    func testControllerStatesKeepAllFields() {
        var state = ControllerManager.InputState()
        state.buttons = 7
        state.leftX = -5
        state.rightY = 9
        state.triggerR = 0.5
        let converted = GagaInputState(state)
        XCTAssertEqual(converted.buttons, 7)
        XCTAssertEqual(converted.left_x, -5)
        XCTAssertEqual(converted.right_y, 9)
        XCTAssertEqual(converted.trigger_r, 0.5)
    }

    // MARK: - Stale path

    func testResolveROMPathSurvivesAContainerMove() throws {
        let stale = "/var/mobile/Containers/Data/Application/OLD-UUID/Library/Application Support/GagaEmu/ROMs/game.mock"
        XCTAssertEqual(game(path: stale).resolvedROMPath(romDirectory: directory), romPath)
        XCTAssertEqual(game().resolvedROMPath(romDirectory: directory), romPath, "A valid path wins")
        XCTAssertNil(game(path: "/gone/other.mock").resolvedROMPath(romDirectory: directory))
    }

    // MARK: - Audio

    /// Counts rising zero crossings of the left channel.
    private func measuredFrequency(_ stereo: [Int16], rate: Double) -> Double {
        var crossings = 0
        var previous = stereo[0]
        for index in stride(from: 2, to: stereo.count, by: 2) {
            if previous < 0 && stereo[index] >= 0 { crossings += 1 }
            previous = stereo[index]
        }
        return Double(crossings) / (Double(stereo.count / 2) / rate)
    }

    private func sine(hz: Double, rate: Double, frames: Int) -> [Int16] {
        (0..<frames).flatMap { index -> [Int16] in
            let value = Int16(sin(2 * .pi * hz * Double(index) / rate) * 8000)
            return [value, value]
        }
    }

    func testResamplerKeepsPitchAcrossCoreRates() {
        for rate in [32040.0, 32768, 44100, 48000] {
            var resampler = LinearResampler(inputRate: rate, outputRate: 48000)
            let input = sine(hz: 440, rate: rate, frames: Int(rate) * 2)
            var output: [Int16] = []
            // Packets the size of one frame's audio.
            let packet = Int(rate / 60)
            input.withUnsafeBufferPointer { buffer in
                for start in stride(from: 0, to: input.count / 2, by: packet) {
                    resampler.process(buffer.baseAddress! + start * 2, frames: min(packet, input.count / 2 - start),
                                      channels: 2, into: &output)
                }
            }
            XCTAssertEqual(output.count / 2, 96000, accuracy: 2, "Two seconds in, two seconds out at \(rate)")
            XCTAssertEqual(measuredFrequency(output, rate: 48000), 440, accuracy: 1, "Pitch at \(rate)")
        }
    }

    func testResamplerIgnoresChunking() {
        let input = sine(hz: 1000, rate: 32768, frames: 2000)
        func run(packet: Int) -> [Int16] {
            var resampler = LinearResampler(inputRate: 32768, outputRate: 48000)
            var output: [Int16] = []
            input.withUnsafeBufferPointer { buffer in
                for start in stride(from: 0, to: 2000, by: packet) {
                    resampler.process(buffer.baseAddress! + start * 2, frames: min(packet, 2000 - start), channels: 2, into: &output)
                }
            }
            return output
        }
        XCTAssertEqual(run(packet: 2000), run(packet: 137))
    }

    func testResamplerDuplicatesMono() {
        var resampler = LinearResampler(inputRate: 48000, outputRate: 48000)
        let input: [Int16] = [100, 200, 300]
        var output: [Int16] = []
        resampler.process(input, frames: 3, channels: 1, into: &output)
        // Equal rates pass through, one frame behind, because the first output starts from the state.
        XCTAssertEqual(output, [0, 0, 100, 100, 200, 200])
    }

    func testAudioRingPrimesThenPlaysThenRunsDry() {
        let audio = AudioEngineManager(outputSampleRate: 48000)
        var left = [Float](repeating: 1, count: 1024)
        var right = [Float](repeating: 1, count: 1024)
        audio.render(left: &left, right: &right, frames: 1024)
        XCTAssertEqual(left[0], 0, "Silence until primed")

        let samples = [Int16](repeating: 16384, count: 4096)
        audio.writeSamples(samples, frames: 2048, channels: 2)
        audio.render(left: &left, right: &right, frames: 1024)
        XCTAssertEqual(left[100], 0.5, accuracy: 0.01)
        XCTAssertEqual(right[100], 0.5, accuracy: 0.01)
        XCTAssertEqual(audio.stats.rendered, 1024)

        audio.render(left: &left, right: &right, frames: 1024)
        audio.render(left: &left, right: &right, frames: 1024)
        XCTAssertEqual(left[1000], 0, "Runs dry to silence, not stale samples")
    }

    func testAudioRingKeepsNewestWhenItOverflows() {
        let audio = AudioEngineManager(outputSampleRate: 48000)
        audio.writeSamples([Int16](repeating: 1000, count: 2 * 8192), frames: 8192, channels: 2)
        audio.writeSamples([Int16](repeating: 16384, count: 2 * 8192), frames: 8192, channels: 2)
        var left = [Float](repeating: 0, count: 256)
        var right = left
        audio.render(left: &left, right: &right, frames: 256)
        XCTAssertEqual(left[200], 0.5, accuracy: 0.01)
    }

    func testSilentModeChoosesTheCategory() {
        XCTAssertEqual(AudioEngineManager.sessionCategory(respectSilentMode: true), .ambient)
        XCTAssertEqual(AudioEngineManager.sessionCategory(respectSilentMode: false), .playback)
    }
}
