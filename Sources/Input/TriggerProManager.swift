import Foundation

/// Turbo fire, hold latch, and multi-frame combo macros layered on top of raw input.
/// Call `process` once per emulated frame; it returns the state the core should see.
public final class TriggerProManager: ObservableObject {

    public enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
        case turbo, hold, combo
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .turbo: return "Turbo Fire"
            case .hold: return "Button Hold Latch"
            case .combo: return "Combo Macro"
            }
        }
    }

    /// One binding. `source` is the button the player presses; `output` is what the core sees.
    public struct Binding: Identifiable, Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var mode: Mode
        public var source: UInt32
        public var output: UInt32
        /// Turbo rate in Hz. Clamped to 5...30 at apply time.
        public var hertz: Double
        /// Combo steps. Each entry is the buttons held for `frames` frames.
        public var steps: [Step]
        public var enabled: Bool

        public struct Step: Codable, Equatable, Sendable {
            public var buttons: UInt32
            public var frames: Int
            public init(buttons: UInt32, frames: Int) {
                self.buttons = buttons
                self.frames = max(frames, 1)
            }
        }

        public init(id: UUID = UUID(), name: String, mode: Mode, source: UInt32, output: UInt32,
                    hertz: Double = 15, steps: [Step] = [], enabled: Bool = true) {
            self.id = id
            self.name = name
            self.mode = mode
            self.source = source
            self.output = output
            self.hertz = hertz
            self.steps = steps
            self.enabled = enabled
        }
    }

    @Published public var bindings: [Binding] = []

    private var latched: [UUID: Bool] = [:]
    private var wasDown: [UUID: Bool] = [:]
    private var comboCursor: [UUID: (step: Int, frame: Int)] = [:]

    public init() {}

    /// `frameRate` is the core's target FPS (60 for most). Turbo at `hertz` toggles every
    /// `frameRate / hertz / 2` frames so the pressed half of the cycle hits the requested rate.
    public func process(_ state: ControllerManager.InputState, frame: Int, frameRate: Double = 60) -> ControllerManager.InputState {
        var result = state
        for binding in bindings where binding.enabled {
            let down = state.buttons & binding.source != 0
            switch binding.mode {
            case .turbo:
                if down {
                    let hz = min(max(binding.hertz, 5), 30)
                    let period = max(Int((frameRate / hz).rounded()), 2)
                    if (frame % period) < period / 2 { result.buttons |= binding.output }
                    else { result.buttons &= ~binding.output }
                }
            case .hold:
                if down && wasDown[binding.id] != true { latched[binding.id] = !(latched[binding.id] ?? false) }
                if latched[binding.id] == true { result.buttons |= binding.output }
                else if binding.output != binding.source { result.buttons &= ~binding.output }
            case .combo:
                result.buttons = applyCombo(binding, down: down, to: result.buttons)
            }
            wasDown[binding.id] = down
        }
        return result
    }

    public func reset() {
        latched.removeAll()
        wasDown.removeAll()
        comboCursor.removeAll()
    }

    private func applyCombo(_ binding: Binding, down: Bool, to buttons: UInt32) -> UInt32 {
        guard !binding.steps.isEmpty else { return buttons }
        guard down || comboCursor[binding.id] != nil else { return buttons }
        var cursor = comboCursor[binding.id] ?? (0, 0)
        if !down && cursor == (0, 0) { return buttons }
        let step = binding.steps[cursor.step % binding.steps.count]
        var next = buttons
        next &= ~binding.output
        next |= step.buttons
        cursor.frame += 1
        if cursor.frame >= step.frames {
            cursor.frame = 0
            cursor.step += 1
            if cursor.step >= binding.steps.count { comboCursor[binding.id] = nil; return next }
        }
        comboCursor[binding.id] = cursor
        return next
    }
}

#if DEBUG
enum TriggerProManagerChecks {
    static func run() {
        let turbo = TriggerProManager()
        let south = ControllerManager.Button.south
        turbo.bindings = [.init(name: "Turbo A", mode: .turbo, source: south, output: south, hertz: 30)]
        var pressed = ControllerManager.InputState(); pressed.buttons = south
        // 30 Hz at 60 fps: on, off, on, off.
        let frames = (0..<4).map { turbo.process(pressed, frame: $0).buttons & south != 0 }
        assert(frames == [true, false, true, false])

        let hold = TriggerProManager()
        hold.bindings = [.init(name: "Run", mode: .hold, source: south, output: south)]
        var up = ControllerManager.InputState()
        _ = hold.process(pressed, frame: 0)
        let latched = hold.process(up, frame: 1)
        assert(latched.buttons & south != 0)
        _ = hold.process(pressed, frame: 2)
        let released = hold.process(up, frame: 3)
        assert(released.buttons & south == 0)

        let combo = TriggerProManager()
        combo.bindings = [.init(name: "Hadoken", mode: .combo, source: south, output: south, steps: [
            .init(buttons: ControllerManager.Button.down, frames: 2),
            .init(buttons: ControllerManager.Button.right, frames: 1)
        ])]
        assert(combo.process(pressed, frame: 0).buttons == ControllerManager.Button.down)
        assert(combo.process(pressed, frame: 1).buttons == ControllerManager.Button.down)
        assert(combo.process(pressed, frame: 2).buttons == ControllerManager.Button.right)
    }
}
#endif
