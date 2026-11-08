import Foundation

/// An app feature a touch element or a controller input can trigger. Never reaches a core.
enum AppFunction: String, Codable, CaseIterable, Identifiable, Sendable {
    case quickSave, quickLoad, fastForwardHold, fastForwardToggle, rewindHold, swapScreens, screenshot,
         pauseMenu, mute, nextSlot, previousSlot, reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickSave: return "Quick Save"
        case .quickLoad: return "Quick Load"
        case .fastForwardHold: return "Fast Forward (Hold)"
        case .fastForwardToggle: return "Fast Forward (Toggle)"
        case .rewindHold: return "Rewind (Hold)"
        case .swapScreens: return "Swap Screens"
        case .screenshot: return "Screenshot"
        case .pauseMenu: return "Pause Menu"
        case .mute: return "Mute"
        case .nextSlot: return "Next Save Slot"
        case .previousSlot: return "Previous Save Slot"
        case .reset: return "Reset Game"
        }
    }

    /// Short text for a touch element.
    var glyph: String {
        switch self {
        case .quickSave: return "Save"
        case .quickLoad: return "Load"
        case .fastForwardHold, .fastForwardToggle: return "FF"
        case .rewindHold: return "Back"
        case .swapScreens: return "Swap"
        case .screenshot: return "Shot"
        case .pauseMenu: return "Menu"
        case .mute: return "Mute"
        case .nextSlot: return "Slot+"
        case .previousSlot: return "Slot-"
        case .reset: return "Reset"
        }
    }

    /// Acts while held, and stops on release.
    var isHold: Bool { self == .fastForwardHold || self == .rewindHold }
}

/// What one touch element or controller input does.
enum ControlAction: Codable, Hashable, Sendable {
    /// Core buttons, as `ControllerManager.Button` masks.
    case buttons(UInt32)
    case app(AppFunction)
    /// Fires the buttons on and off at the turbo rate, while held or, with `toggle`, until pressed again.
    case turbo(UInt32, toggle: Bool)
    case macro(UUID)

    var app: AppFunction? { if case .app(let function) = self { return function }; return nil }

    func title(macros: [Macro]) -> String {
        switch self {
        case .buttons(let mask): return ControlAction.buttonNames(mask)
        case .app(let function): return function.title
        case .turbo(let mask, let toggle): return "Turbo \(ControlAction.buttonNames(mask))\(toggle ? " (Toggle)" : "")"
        case .macro(let id): return "Macro: \(macros.first { $0.id == id }?.name ?? "Missing")"
        }
    }

    /// The core buttons in RetroPad order, by the names the touch controls use.
    static let coreButtons: [(name: String, mask: UInt32)] = {
        let b = ControllerManager.Button.self
        return [("Up", b.up), ("Down", b.down), ("Left", b.left), ("Right", b.right), ("A", b.east), ("B", b.south),
                ("X", b.north), ("Y", b.west), ("L", b.l1), ("R", b.r1), ("L2", b.l2), ("R2", b.r2),
                ("Start", b.start), ("Select", b.select), ("L3", b.l3), ("R3", b.r3)]
    }()

    static func buttonNames(_ mask: UInt32) -> String {
        let names = coreButtons.filter { mask & $0.mask != 0 }.map(\.name)
        return names.isEmpty ? "Nothing" : names.joined(separator: "+")
    }
}

/// A named run of steps, each a set of core buttons held for a number of frames.
struct Macro: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var steps: [Step]
    /// Starts again from the first step until pressed again.
    var loops = false

    struct Step: Codable, Equatable, Sendable {
        var buttons: UInt32
        var frames: Int
    }

    static let maxFrames = 600

    /// Run-length steps from one button mask per frame, as recorded. Leading and trailing idle frames are dropped.
    static func steps(recorded frames: [UInt32]) -> [Step] {
        var steps: [Step] = []
        for buttons in frames {
            if let last = steps.last, last.buttons == buttons, last.frames < maxFrames {
                steps[steps.count - 1].frames += 1
            } else {
                steps.append(Step(buttons: buttons, frames: 1))
            }
        }
        while steps.first?.buttons == 0 { steps.removeFirst() }
        while steps.last?.buttons == 0 { steps.removeLast() }
        return steps
    }
}

// MARK: - Physical controllers

/// One element of a game controller, by its position on an Xbox-style pad.
enum PadInput: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b, x, y, l1, r1, l2, r2, l3, r3, up, down, left, right, menu, options, home
    var id: String { rawValue }

    /// The name printed on the controller.
    func title(for kind: ControllerManager.Kind) -> String {
        let playStation = kind == .dualSense || kind == .dualShock4
        switch self {
        case .a: return playStation ? "Cross" : "A"
        case .b: return playStation ? "Circle" : "B"
        case .x: return playStation ? "Square" : "X"
        case .y: return playStation ? "Triangle" : "Y"
        case .l1: return playStation ? "L1" : "LB"
        case .r1: return playStation ? "R1" : "RB"
        case .l2: return playStation ? "L2" : "LT"
        case .r2: return playStation ? "R2" : "RT"
        case .l3: return "Left Stick Press"
        case .r3: return "Right Stick Press"
        case .up: return "D-pad Up"
        case .down: return "D-pad Down"
        case .left: return "D-pad Left"
        case .right: return "D-pad Right"
        case .menu: return playStation ? "Options" : "Menu"
        case .options: return playStation ? "Share" : "View"
        case .home: return "Home"
        }
    }
}

/// One mapping: an input, or several held together, and what it does.
struct PadBinding: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var inputs: [PadInput]
    var action: ControlAction

    /// Equal by what it does. `id` only tells the editor's rows apart, and each fresh default gets new ones.
    static func == (lhs: PadBinding, rhs: PadBinding) -> Bool { lhs.inputs == rhs.inputs && lhs.action == rhs.action }
}

/// A controller's mapping for one platform, or one game, and one controller type.
struct PadProfile: Codable, Equatable, Sendable {
    var bindings: [PadBinding]
    /// The left stick also presses the D-pad.
    var stickAsDpad = false
    /// Share of the stick's travel that reads as centred.
    var deadzone = 0.1
    /// Multiplies the stick's travel past the deadzone.
    var sensitivity = 1.0
    /// Seconds Menu (Start) is held to open the pause menu; 0 is off. Start reaches the game at once and a short
    /// press is just Start. Home also opens the menu, where iOS passes it through.
    var menuHold = 1.0

    static let deadzoneRange = 0.0...0.5
    static let sensitivityRange = 0.5...2.0
    static let menuHoldRange = 0.5...2.0

    /// RetroPad by position, Home opens the menu, and so does holding Menu. No default combo: a combo takes its
    /// buttons from the game, so Menu and Options (Start and Select) would eat soft resets, and Options with L1 or
    /// R1 game combos. Players add combos in Controls.
    static func standard(for kind: ControllerManager.Kind = .mfi) -> PadProfile {
        let b = ControllerManager.Button.self
        let single: [(PadInput, UInt32)] = [(.a, b.south), (.b, b.east), (.x, b.west), (.y, b.north), (.l1, b.l1), (.r1, b.r1),
                                            (.l2, b.l2), (.r2, b.r2), (.l3, b.l3), (.r3, b.r3), (.up, b.up), (.down, b.down),
                                            (.left, b.left), (.right, b.right), (.menu, b.start), (.options, b.select)]
        return PadProfile(bindings: single.map { PadBinding(inputs: [$0.0], action: .buttons($0.1)) } + [
            PadBinding(inputs: [.home], action: .app(.pauseMenu))
        ])
    }

    /// In range. A file is not trusted to be.
    func normalized() -> PadProfile {
        var copy = self
        copy.deadzone = deadzone.isFinite ? min(max(deadzone, Self.deadzoneRange.lowerBound), Self.deadzoneRange.upperBound) : 0.1
        copy.sensitivity = sensitivity.isFinite ? min(max(sensitivity, Self.sensitivityRange.lowerBound), Self.sensitivityRange.upperBound) : 1
        copy.menuHold = !menuHold.isFinite ? 1 : menuHold <= 0 ? 0
            : min(max(menuHold, Self.menuHoldRange.lowerBound), Self.menuHoldRange.upperBound)
        copy.bindings = bindings.filter { !$0.inputs.isEmpty }
        return copy
    }
}

/// A file from before a field existed still decodes. In an extension, so the memberwise init stays.
extension PadProfile {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bindings = try c.decode([PadBinding].self, forKey: .bindings)
        stickAsDpad = try c.decodeIfPresent(Bool.self, forKey: .stickAsDpad) ?? false
        deadzone = try c.decodeIfPresent(Double.self, forKey: .deadzone) ?? 0.1
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 1
        menuHold = try c.decodeIfPresent(Double.self, forKey: .menuHold) ?? 1
    }
}

/// Times a hold of Menu (Start). It fires once after `seconds`, then stays `fired` until Start is released, so
/// the caller keeps Start from the core only after the trigger. Time is a parameter, for tests.
struct MenuHold {
    private var since: TimeInterval?
    private(set) var fired = false

    /// True once, when the hold passes `seconds`. A `seconds` of 0 is off.
    mutating func update(held: Bool, seconds: Double, now: TimeInterval) -> Bool {
        guard held else { since = nil; fired = false; return false }
        let start = since ?? now
        since = start
        guard seconds > 0, !fired, now - start >= seconds else { return false }
        fired = true
        return true
    }
}

/// A controller's raw state, before any mapping. Sticks and triggers are -1...1 and 0...1, up positive.
struct PadState: Equatable, Sendable {
    var held: Set<PadInput> = []
    var leftX: Float = 0, leftY: Float = 0, rightX: Float = 0, rightY: Float = 0
    var triggerL: Float = 0, triggerR: Float = 0
}

enum PadMapper {
    /// Combos win over their parts: a binding of several inputs fires when all are held and takes them, so they do
    /// not also fire alone. Longer combos are matched first.
    static func resolve(_ pad: PadState, profile: PadProfile) -> ControllerManager.InputState {
        var state = ControllerManager.InputState()
        var taken = Set<PadInput>()
        for binding in profile.bindings.sorted(by: { $0.inputs.count > $1.inputs.count }) {
            let inputs = Set(binding.inputs)
            guard !inputs.isEmpty, inputs.isSubset(of: pad.held) else { continue }
            if inputs.count > 1 {
                guard inputs.isDisjoint(with: taken) else { continue }
                taken.formUnion(inputs)
            } else if !inputs.isDisjoint(with: taken) {
                continue
            }
            if case .buttons(let mask) = binding.action { state.buttons |= mask } else { state.actions.insert(binding.action) }
        }
        let left = stick(pad.leftX, pad.leftY, profile), right = stick(pad.rightX, pad.rightY, profile)
        state.leftX = axis(left.x); state.leftY = axis(left.y)
        state.rightX = axis(right.x); state.rightY = axis(right.y)
        if profile.stickAsDpad {
            let b = ControllerManager.Button.self
            if left.x < -0.5 { state.buttons |= b.left } else if left.x > 0.5 { state.buttons |= b.right }
            if left.y > 0.5 { state.buttons |= b.up } else if left.y < -0.5 { state.buttons |= b.down }
        }
        state.triggerL = pad.triggerL
        state.triggerR = pad.triggerR
        return state
    }

    /// A radial deadzone, so diagonals keep their angle, then the sensitivity, capped at full travel.
    static func stick(_ x: Float, _ y: Float, _ profile: PadProfile) -> (x: Float, y: Float) {
        let length = (x * x + y * y).squareRoot()
        let zone = Float(profile.deadzone)
        guard length > zone, length > 0 else { return (0, 0) }
        let scaled = min((length - zone) / max(1 - zone, 0.01) * Float(profile.sensitivity), 1)
        return (x / length * scaled, y / length * scaled)
    }

    static func axis(_ value: Float) -> Int16 {
        let clamped = min(max(value, -1), 1)
        return Int16(clamped * (clamped < 0 ? 32768 : 32767))
    }
}

// MARK: - Turbo and macros

/// Turbo and macro playback for player 1, stepped once per emulated frame on the core's queue, so timing is in
/// frames and holds at any speed. The main thread sets what is held; `process` reads it under the lock.
final class FrameInputProcessor: @unchecked Sendable {
    private let lock = NSLock()
    private var turboMask: UInt32 = 0
    private var hertz: Double
    private let frameRate: Double
    private var running: [(macro: Macro, step: Int, frame: Int)] = []
    private var recorded: [UInt32]?

    init(hertz: Double = 15, frameRate: Double = 60) {
        self.hertz = hertz
        self.frameRate = frameRate
    }

    static let hertzRange = 2.0...30.0

    /// Frames per on-and-off cycle at `hertz`, at least two.
    static func period(hertz: Double, frameRate: Double) -> Int {
        let hz = min(max(hertz, hertzRange.lowerBound), hertzRange.upperBound)
        return max(Int((frameRate / hz).rounded()), 2)
    }

    func setTurbo(_ mask: UInt32, hertz: Double? = nil) {
        lock.lock(); defer { lock.unlock() }
        turboMask = mask
        if let hertz { self.hertz = hertz }
    }

    /// Starts a macro, or stops it when it is already running.
    func toggle(_ macro: Macro) {
        lock.lock(); defer { lock.unlock() }
        if let index = running.firstIndex(where: { $0.macro.id == macro.id }) {
            running.remove(at: index)
        } else if macro.steps.contains(where: { $0.frames > 0 }) {
            running.append((macro, 0, 0))
        }
    }

    var runningMacros: Set<UUID> {
        lock.lock(); defer { lock.unlock() }
        return Set(running.map(\.macro.id))
    }

    /// Pause stops every macro, so none carries on into the menu or past a load.
    func cancelMacros() {
        lock.lock(); defer { lock.unlock() }
        running.removeAll()
    }

    func startRecording() {
        lock.lock(); defer { lock.unlock() }
        recorded = []
    }

    /// The buttons held each frame since `startRecording`, or nil when it was not recording.
    func stopRecording() -> [UInt32]? {
        lock.lock(); defer { lock.unlock() }
        defer { recorded = nil }
        return recorded
    }

    var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }
        return recorded != nil
    }

    /// `buttons` are what the player holds this frame; the result is what the core sees.
    func process(_ buttons: UInt32, frame: Int) -> UInt32 {
        lock.lock(); defer { lock.unlock() }
        if recorded != nil, (recorded?.count ?? 0) < 60 * 60 { recorded?.append(buttons) }
        var result = buttons & ~turboMask
        let period = Self.period(hertz: hertz, frameRate: frameRate)
        if frame % period < period / 2 { result |= turboMask }
        var index = 0
        while index < running.count {
            var entry = running[index]
            let steps = entry.macro.steps
            while entry.step < steps.count, steps[entry.step].frames <= 0 { entry.step += 1 }
            guard entry.step < steps.count else { running.remove(at: index); continue }
            result |= steps[entry.step].buttons
            entry.frame += 1
            if entry.frame >= steps[entry.step].frames {
                entry.frame = 0
                entry.step += 1
                if entry.step >= steps.count {
                    if entry.macro.loops { entry.step = 0 } else { running.remove(at: index); continue }
                }
            }
            running[index] = entry
            index += 1
        }
        return result
    }
}

// MARK: - Store

/// Classic is GagaEmu's own outlined controls; Device draws the console-style shell (docs/06 section 3.8).
enum SkinStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, device
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Touch haptic strength for presses on the touch controls. Separate from game rumble.
enum HapticStrength: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, light, medium, strong
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Controller mappings, macros and control options in Controls.json beside the Skins folder. A missing, damaged
/// or later-version file reads as the defaults; it is replaced on the next change.
@MainActor
final class ControlsStore: ObservableObject {
    struct File: Codable, Equatable {
        static let currentVersion = 1
        var version = currentVersion
        /// By `ControlsStore.key`: "platform:<id>|<kind>" or "game:<uuid>|<kind>".
        var pads: [String: PadProfile] = [:]
        var macros: [Macro] = []
        var turboHertz = 15.0
        /// The speed Fast Forward buttons use.
        var fastForwardSpeed = 2
        var quickSlot = 1
        var touchHaptics = HapticStrength.light
        var hideTouchWithController = true
        /// By game ID: "portrait" or "landscape". Missing follows the device.
        var orientation: [String: String] = [:]
        /// Touch skin style by "platform:<id>" or "game:<uuid>", a `SkinStyle` raw value. Missing is Classic.
        var skinStyle: [String: String] = [:]
        /// A device skin's colourway name by platform ID. Missing is the skin's own.
        var skinVariant: [String: String] = [:]

        init() {}

        private enum Keys: String, CodingKey {
            case version, pads, macros, turboHertz, fastForwardSpeed, quickSlot, touchHaptics, hideTouchWithController, orientation,
                 skinStyle, skinVariant
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            func value<T: Decodable>(_ key: Keys, _ fallback: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback }
            version = value(.version, version)
            pads = value(.pads, pads)
            macros = value(.macros, macros)
            turboHertz = value(.turboHertz, turboHertz)
            fastForwardSpeed = value(.fastForwardSpeed, fastForwardSpeed)
            quickSlot = value(.quickSlot, quickSlot)
            touchHaptics = value(.touchHaptics, touchHaptics)
            hideTouchWithController = value(.hideTouchWithController, hideTouchWithController)
            orientation = value(.orientation, orientation)
            skinStyle = value(.skinStyle, skinStyle)
            skinVariant = value(.skinVariant, skinVariant)
        }

        /// The game's own style, then its platform's, then Classic. An unknown value reads as Classic.
        func style(platformID: String, gameID: UUID?) -> SkinStyle {
            (gameID.flatMap { skinStyle["game:\($0.uuidString)"] } ?? skinStyle["platform:\(platformID)"])
                .flatMap(SkinStyle.init) ?? .classic
        }
    }

    static let quickSlots = 1...9

    @Published var file: File { didSet { if file != oldValue { write() } } }
    let url: URL

    init(url: URL) {
        self.url = url
        let decoded = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(File.self, from: $0) }
        file = decoded.flatMap { $0.version <= File.currentVersion ? $0 : nil } ?? File()
    }

    static func key(platformID: String, kind: ControllerManager.Kind) -> String { "platform:\(platformID)|\(kind.rawValue)" }
    static func key(gameID: UUID, kind: ControllerManager.Kind) -> String { "game:\(gameID.uuidString)|\(kind.rawValue)" }

    /// The game's own mapping, then its platform's, then the controller type's defaults.
    static func profile(in file: File, kind: ControllerManager.Kind, platformID: String, gameID: UUID?) -> PadProfile {
        (gameID.flatMap { file.pads[key(gameID: $0, kind: kind)] } ?? file.pads[key(platformID: platformID, kind: kind)]
            ?? .standard(for: kind)).normalized()
    }

    func profile(kind: ControllerManager.Kind, platformID: String, gameID: UUID?) -> PadProfile {
        Self.profile(in: file, kind: kind, platformID: platformID, gameID: gameID)
    }

    func macro(_ id: UUID) -> Macro? { file.macros.first { $0.id == id } }

    /// Losing a mapping is not worth stopping play for, so a failed write keeps it for this launch only.
    private func write() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(file) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
