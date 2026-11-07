import CoreHaptics
import Foundation
import GameController

/// Somewhere one player's rumble plays. Called on the main thread.
protocol RumbleOutput: AnyObject {
    /// Intensity and sharpness run 0 to 1. Intensity 0 stops the motor and keeps the output ready.
    func play(intensity: Float, sharpness: Float)
    /// Stops the motor and releases what keeps it ready.
    func stop()
}

/// An output and the core motor it plays. A nil motor plays the stronger of the two.
struct RumbleTarget {
    let output: RumbleOutput
    let motor: RumbleManager.Motor?
}

/// Plays a game's rumble (GAGA_EVENT_RUMBLE) on the outputs `targets` gives for each player port.
///
/// Threads: `receive` takes events on the core's queue. Everything else runs on the main thread, where the
/// latest strengths play at most once per `interval`, however often the core changes them.
final class RumbleManager: @unchecked Sendable {
    enum Motor: Int { case strong = 0, weak = 1 }

    /// One motor's new strength, decoded from a GAGA_EVENT_RUMBLE code (GagaBridge.h).
    struct Change: Equatable {
        let port: Int
        let motor: Motor
        let strength: UInt16

        init(port: Int, motor: Motor, strength: UInt16) {
            self.port = port
            self.motor = motor
            self.strength = strength
        }

        init(code: Int32) {
            let bits = UInt32(bitPattern: code)
            port = Int(bits >> 17 & 3)
            motor = bits >> 16 & 1 == 0 ? .strong : .weak
            strength = UInt16(bits & 0xFFFF)
        }
    }

    static let ports = 4

    /// The strong motor is the low, heavy one, so it plays soft-edged; the weak one buzzes.
    static func level(strong: UInt16, weak: UInt16, motor: Motor?, scale: Float) -> (intensity: Float, sharpness: Float) {
        let s = Float(strong) / 65535, w = Float(weak) / 65535
        let raw: Float, sharpness: Float
        switch motor {
        case .strong: (raw, sharpness) = (s, 0.2)
        case .weak: (raw, sharpness) = (w, 0.8)
        case nil: (raw, sharpness) = (max(s, w), s + w > 0 ? (0.2 * s + 0.8 * w) / (s + w) : 0.5)
        }
        return (min(1, max(0, raw * scale)), sharpness)
    }

    let interval: TimeInterval
    /// 0 to 1, the Rumble Strength setting.
    let scale: Float
    private let targets: (Int) -> [RumbleTarget]

    private let lock = NSLock()
    private var strengths = Array(repeating: [UInt16](repeating: 0, count: 2), count: ports) // Under lock.
    private var flushScheduled = false // Under lock.

    private var paused = false
    private var playing: [ObjectIdentifier: RumbleOutput] = [:]
    private var used: [ObjectIdentifier: RumbleOutput] = [:]

    init(scale: Float, interval: TimeInterval = 1.0 / 30, targets: @escaping (Int) -> [RumbleTarget]) {
        self.scale = scale
        self.interval = interval
        self.targets = targets
    }

    /// Any thread.
    func receive(_ change: Change) {
        guard (0..<Self.ports).contains(change.port) else { return }
        lock.lock()
        strengths[change.port][change.motor.rawValue] = change.strength
        let schedule = !flushScheduled
        flushScheduled = true
        lock.unlock()
        if schedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in self?.flush() }
        }
    }

    /// Plays the latest strengths now. Main thread.
    func flush() {
        lock.lock()
        let current = strengths
        flushScheduled = false
        lock.unlock()
        guard !paused else { return }
        var now: [ObjectIdentifier: RumbleOutput] = [:]
        for port in 0..<Self.ports {
            for target in targets(port) {
                let level = Self.level(strong: current[port][0], weak: current[port][1], motor: target.motor, scale: scale)
                guard level.intensity > 0 else { continue }
                target.output.play(intensity: level.intensity, sharpness: level.sharpness)
                now[ObjectIdentifier(target.output)] = target.output
            }
        }
        // An output whose player went quiet, moved slot or lost the device setting stops.
        for (id, output) in playing where now[id] == nil { output.play(intensity: 0, sharpness: 0) }
        playing = now
        used.merge(now) { old, _ in old }
    }

    /// Stops every motor until `resume`. For pause, the background and the end of the session. Main thread.
    func pause() {
        paused = true
        used.values.forEach { $0.stop() }
        playing = [:]
    }

    /// Plays what the game last asked for, which it does not send again. Main thread.
    func resume() {
        paused = false
        flush()
    }
}

/// A CoreHaptics engine playing one looping continuous event, its intensity and sharpness changed live.
final class HapticRumbleOutput: RumbleOutput {
    private let engine: CHHapticEngine
    private var player: CHHapticAdvancedPatternPlayer?

    init?(engine: CHHapticEngine?) {
        guard let engine else { return nil }
        self.engine = engine
        engine.playsHapticsOnly = true
        // The system stops the engine in the background and resets it if its server restarts. Either way the player is gone.
        let forget: () -> Void = { [weak self] in DispatchQueue.main.async { self?.player = nil } }
        engine.stoppedHandler = { _ in forget() }
        engine.resetHandler = forget
    }

    deinit { engine.stop(completionHandler: nil) }

    func play(intensity: Float, sharpness: Float) {
        guard intensity > 0 else {
            try? player?.stop(atTime: CHHapticTimeImmediate)
            player = nil
            return
        }
        do {
            if player == nil {
                try engine.start()
                let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ], relativeTime: 0, duration: 30)
                let made = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [event], parameters: []))
                made.loopEnabled = true
                try made.start(atTime: CHHapticTimeImmediate)
                player = made
            }
            // Intensity control multiplies the event's 1. Sharpness control adds to its 0.5.
            try player?.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
                CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness - 0.5, relativeTime: 0),
            ], atTime: CHHapticTimeImmediate)
        } catch {
            player = nil // Tried again on the next change.
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine.stop(completionHandler: nil)
    }
}

/// Where each port's rumble plays in the app: the controller in that player's slot, with its handles as the
/// two motors where it has them (Xbox, DualSense), or for player 1 on touch the device itself when `device`
/// is on. Engines are made on first use and kept for the session. Main thread.
final class HapticRumbleTargets {
    private let controllers: ControllerManager
    private let device: Bool
    private var made: [ObjectIdentifier: [RumbleTarget]] = [:]
    private lazy var deviceTargets: [RumbleTarget] = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let output = HapticRumbleOutput(engine: try? CHHapticEngine()) else { return [] }
        return [RumbleTarget(output: output, motor: nil)]
    }()

    init(controllers: ControllerManager, device: Bool) {
        self.controllers = controllers
        self.device = device
    }

    func targets(port: Int) -> [RumbleTarget] {
        if port == 0, controllers.touchOwnsPlayerOne { return device ? deviceTargets : [] }
        guard let controller = controllers.controller(inSlot: port) else { return [] }
        let key = ObjectIdentifier(controller)
        if let known = made[key] { return known }
        let targets = Self.make(controller)
        made[key] = targets
        return targets
    }

    private static func make(_ controller: GCController) -> [RumbleTarget] {
        guard let haptics = controller.haptics else { return [] }
        let localities = haptics.supportedLocalities
        if localities.contains(.leftHandle), localities.contains(.rightHandle) {
            // The left handle holds the big low motor, as on Xbox and DualSense pads.
            return [(GCHapticsLocality.leftHandle, RumbleManager.Motor.strong), (.rightHandle, .weak)].compactMap { locality, motor in
                HapticRumbleOutput(engine: haptics.createEngine(withLocality: locality)).map { RumbleTarget(output: $0, motor: motor) }
            }
        }
        return HapticRumbleOutput(engine: haptics.createEngine(withLocality: .default)).map { [RumbleTarget(output: $0, motor: nil)] } ?? []
    }
}
