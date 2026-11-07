import XCTest
@testable import GagaEmu

// C function pointers cannot capture, so the rumbling core keeps its callback here.
private var rumbleEvent: (@convention(c) (GagaEventSeverity, Int32, UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void)?
private var rumbleUserdata: UnsafeMutableRawPointer?

/// Records what it was told to play, in place of a CoreHaptics engine.
private final class MockRumbleOutput: RumbleOutput {
    var plays: [(intensity: Float, sharpness: Float)] = []
    var stops = 0
    func play(intensity: Float, sharpness: Float) { plays.append((intensity, sharpness)) }
    func stop() { stops += 1 }
}

/// The host side of rumble: bridge codes, strength to intensity, throttling, and stopping on pause.
@MainActor
final class RumbleTests: GagaTestCase {
    private func manager(_ output: MockRumbleOutput, port: Int = 0, motor: RumbleManager.Motor? = nil,
                         scale: Float = 1, interval: TimeInterval = 60) -> RumbleManager {
        RumbleManager(scale: scale, interval: interval) { $0 == port ? [RumbleTarget(output: output, motor: motor)] : [] }
    }

    func testChangeDecodesTheBridgeCode() {
        // GAGA_RUMBLE_CODE(2, GAGA_RUMBLE_WEAK, 0x1234): port in bits 17-18, motor in bit 16, strength below.
        XCTAssertEqual(RumbleManager.Change(code: Int32(2 << 17 | 1 << 16 | 0x1234)), .init(port: 2, motor: .weak, strength: 0x1234))
        XCTAssertEqual(RumbleManager.Change(code: Int32(3 << 17 | 0xFFFF)), .init(port: 3, motor: .strong, strength: 0xFFFF))
        XCTAssertEqual(RumbleManager.Change(code: 0), .init(port: 0, motor: .strong, strength: 0))
    }

    func testStrengthMapsToIntensity() {
        let full = RumbleManager.level(strong: 0xFFFF, weak: 0, motor: .strong, scale: 1)
        XCTAssertEqual(full.intensity, 1)
        XCTAssertEqual(full.sharpness, 0.2, "the strong motor is the low one")
        XCTAssertEqual(RumbleManager.level(strong: 0x8000, weak: 0, motor: .strong, scale: 1).intensity, 0.5, accuracy: 0.001)
        XCTAssertEqual(RumbleManager.level(strong: 0xFFFF, weak: 0, motor: .strong, scale: 0.5).intensity, 0.5, accuracy: 0.001,
                       "Rumble Strength scales it")
        XCTAssertEqual(RumbleManager.level(strong: 0xFFFF, weak: 0xFFFF, motor: .strong, scale: 0).intensity, 0, "0 is off")
        XCTAssertEqual(RumbleManager.level(strong: 0xFFFF, weak: 0, motor: .weak, scale: 1).intensity, 0, "a handle plays its own motor")
        let weak = RumbleManager.level(strong: 0, weak: 0xFFFF, motor: .weak, scale: 1)
        XCTAssertEqual(weak.intensity, 1)
        XCTAssertEqual(weak.sharpness, 0.8)
        // One output for both motors plays the stronger, as sharp as the mix.
        let both = RumbleManager.level(strong: 0x4000, weak: 0xC000, motor: nil, scale: 1)
        XCTAssertEqual(both.intensity, Float(0xC000) / 65535, accuracy: 0.001)
        XCTAssertEqual(both.sharpness, 0.65, accuracy: 0.001)
        XCTAssertEqual(RumbleManager.level(strong: 0, weak: 0, motor: nil, scale: 1).intensity, 0)
    }

    func testFlushPlaysTheLatestStrengthWhereAPlayerHasAnOutput() {
        let pad = MockRumbleOutput()
        let rumble = manager(pad, port: 1, motor: .strong)
        rumble.receive(.init(port: 1, motor: .strong, strength: 0x4000))
        rumble.receive(.init(port: 1, motor: .strong, strength: 0xFFFF))
        rumble.receive(.init(port: 0, motor: .strong, strength: 0xFFFF)) // Nobody's output.
        rumble.flush()
        XCTAssertEqual(pad.plays.map(\.intensity), [1])
        rumble.receive(.init(port: 1, motor: .strong, strength: 0))
        rumble.flush()
        XCTAssertEqual(pad.plays.map(\.intensity), [1, 0], "a motor that goes off stops")
        rumble.flush()
        XCTAssertEqual(pad.plays.count, 2, "an output already stopped is not told again")
    }

    func testManyChangesPlayOnceAnInterval() async throws {
        let pad = MockRumbleOutput()
        let rumble = manager(pad, interval: 0.05)
        for step in 1...100 { rumble.receive(.init(port: 0, motor: .weak, strength: UInt16(step * 600))) }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(pad.plays.count, 1, "one play for a burst of changes")
        XCTAssertEqual(pad.plays.last?.intensity ?? 0, Float(60000) / 65535, accuracy: 0.001, "and it is the last one")
    }

    func testPauseStopsAndResumePlaysTheLastStrengthAgain() {
        let pad = MockRumbleOutput()
        let rumble = manager(pad)
        rumble.receive(.init(port: 0, motor: .strong, strength: 0xFFFF))
        rumble.flush()
        rumble.pause()
        XCTAssertEqual(pad.stops, 1)
        rumble.receive(.init(port: 0, motor: .weak, strength: 0xFFFF))
        rumble.flush()
        XCTAssertEqual(pad.plays.count, 1, "nothing plays while paused")
        rumble.resume()
        XCTAssertEqual(pad.plays.count, 2, "the game does not send its strength again, so resume plays it")
        XCTAssertEqual(pad.plays.last?.intensity, 1)
    }

    /// Through a session: a core's rumble events play, and pause and stop silence them.
    func testSessionPlaysRumbleAndStopsItOnPauseAndStop() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rumble-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rom = directory.appendingPathComponent("game.mock")
        try Data([1, 2, 3]).write(to: rom)

        var core = MockCore_GetInterface()!.pointee
        core.set_event_callback = { _, callback, userdata in
            rumbleEvent = callback
            rumbleUserdata = userdata
        }
        core.step_frame = { _, _, _ in rumbleEvent?(GAGA_EVENT_RUMBLE, 0xFFFF, nil, rumbleUserdata) } // Port 0, strong, full.

        let skins = TouchSkinEngine()
        skins.loadDefault()
        skins.hapticsEnabled = false
        let controllers = ControllerManager()
        controllers.devices = []
        let pad = MockRumbleOutput()
        let game = GameItem(id: UUID(), title: "Demo", platformID: "unknown", romPath: rom.path, coverPath: nil,
                            coreOverride: "mock", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        let session = try GameSession(game: game, interface: core, romPath: rom.path, audio: AudioEngineManager(),
                                      controllers: controllers, skins: skins, bindings: [], shaderID: "original",
                                      respectSilentMode: false, saveDirectory: directory,
                                      rumble: manager(pad, interval: 0.01))
        try await session.prepare()
        session.run()
        let deadline = Date().addingTimeInterval(5)
        while pad.plays.isEmpty, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(pad.plays.last?.intensity, 1)

        session.pause(.menu)
        XCTAssertEqual(pad.stops, 1)
        let played = pad.plays.count
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(pad.plays.count, played, "nothing plays while paused")
        session.resume(.menu)
        XCTAssertEqual(pad.plays.count, played + 1)
        session.stop()
        XCTAssertEqual(pad.stops, 2)
    }
}
