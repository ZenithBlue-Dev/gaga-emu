import Foundation
import GameController
import os

/// Tracks MFi, DualShock 4, DualSense, Xbox, Joy-Con (paired or split), and keyboards.
/// Assigns each physical controller to one of four player slots. Player 1 falls
/// back to the on-screen touch skin when its slot is empty.
public final class ControllerManager: ObservableObject {

    public static let slotCount = 4

    public enum Kind: String, Sendable {
        case touch, keyboard, mfi, dualShock4, dualSense, xbox, joyConPair, joyConLeft, joyConRight, unknown

        var label: String {
            switch self {
            case .touch: return "Touch Control"
            case .keyboard: return "Keyboard"
            case .mfi: return "MFi Controller"
            case .dualShock4: return "DualShock 4"
            case .dualSense: return "DualSense"
            case .xbox: return "Xbox Wireless Controller"
            case .joyConPair: return "Joy-Con Pair"
            case .joyConLeft: return "Joy-Con (L)"
            case .joyConRight: return "Joy-Con (R)"
            case .unknown: return "Controller"
            }
        }
    }

    public struct Device: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let kind: Kind
        public let vendor: String
        public var slot: Int? // 0...3, nil = unassigned
        /// The Simulator reports a "Gamepad" that nobody is holding, and a pad can connect in a bag.
        /// A device takes over from touch only once it has sent something.
        public var hasSentInput = false
        public var isTouch: Bool { kind == .touch }
    }

    /// One frame of input for a single player, matching `GagaInputState`.
    public struct InputState: Equatable, Sendable {
        public var buttons: UInt32 = 0
        public var leftX: Int16 = 0
        public var leftY: Int16 = 0
        public var rightX: Int16 = 0
        public var rightY: Int16 = 0
        public var triggerL: Float = 0
        public var triggerR: Float = 0
        /// Menu and Options together, or Home where the system passes it on. Never reaches a core.
        public var openMenu = false
        public static let zero = InputState()

        /// Past stick and trigger drift, which a pad nobody is holding can report.
        var isDeliberate: Bool {
            let half: Int32 = 16384
            return buttons != 0 || openMenu || triggerL > 0.5 || triggerR > 0.5
                || [leftX, leftY, rightX, rightY].contains { abs(Int32($0)) > half }
        }
    }

    public enum Button {
        public static let up: UInt32     = 1 << 0
        public static let down: UInt32   = 1 << 1
        public static let left: UInt32   = 1 << 2
        public static let right: UInt32  = 1 << 3
        public static let south: UInt32  = 1 << 4
        public static let east: UInt32   = 1 << 5
        public static let west: UInt32   = 1 << 6
        public static let north: UInt32  = 1 << 7
        public static let l1: UInt32     = 1 << 8
        public static let r1: UInt32     = 1 << 9
        public static let l2: UInt32     = 1 << 10
        public static let r2: UInt32     = 1 << 11
        public static let start: UInt32  = 1 << 12
        public static let select: UInt32 = 1 << 13
        public static let l3: UInt32     = 1 << 14
        public static let r3: UInt32     = 1 << 15
    }

    /// Keyboard defaults for computer cores (DOSBox, EKA2L1, J2meJS).
    public struct KeyMap: Equatable, Sendable {
        public var bindings: [GCKeyCode: UInt32]
        public static let standard = KeyMap(bindings: [
            .keyW: Button.up, .upArrow: Button.up,
            .keyS: Button.down, .downArrow: Button.down,
            .keyA: Button.left, .leftArrow: Button.left,
            .keyD: Button.right, .rightArrow: Button.right,
            .keyJ: Button.south, .keyK: Button.east, .keyU: Button.west, .keyI: Button.north,
            .keyQ: Button.l1, .keyE: Button.r1,
            .returnOrEnter: Button.start, .rightShift: Button.select
        ])
    }

    @Published public var devices: [Device] = []
    @Published public var keyMap: KeyMap = .standard

    private var controllers: [String: GCController] = [:]
    private var observers: [NSObjectProtocol] = []
    public var onChange: (() -> Void)?
    private let defaults: UserDefaults
    private static let unassignedKey = "GagaUnassignedControllers"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
                guard let controller = note.object as? GCController else { return }
                self?.attach(controller)
            },
            center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
                guard let controller = note.object as? GCController else { return }
                self?.detach(controller)
            }
        ]
        GCController.startWirelessControllerDiscovery {}
        GCController.controllers().forEach { attach($0) }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    // MARK: Slots

    /// Player 1 uses touch until a physical device bound to slot 0 has sent input.
    public var touchOwnsPlayerOne: Bool {
        !devices.contains { $0.slot == 0 && !$0.isTouch && $0.hasSentInput }
    }

    public func device(inSlot slot: Int) -> Device? {
        devices.first { $0.slot == slot }
    }

    /// Binds `deviceID` to `slot`, evicting whoever held it. Pass nil to unbind.
    public func assign(_ deviceID: String, to slot: Int?) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        if let slot {
            for i in devices.indices where devices[i].slot == slot && devices[i].id != deviceID {
                devices[i].slot = nil
            }
            devices[index].slot = min(max(slot, 0), Self.slotCount - 1)
        } else {
            devices[index].slot = nil
        }
        // The system re-announces controllers each launch, so an Unassign has to outlive this object.
        var unassigned = Set(defaults.stringArray(forKey: Self.unassignedKey) ?? [])
        if slot == nil { unassigned.insert(devices[index].name) } else { unassigned.remove(devices[index].name) }
        defaults.set(unassigned.sorted(), forKey: Self.unassignedKey)
        onChange?()
    }

    /// First free slot, or nil when all four are taken.
    public func firstFreeSlot() -> Int? {
        let taken = Set(devices.compactMap(\.slot))
        return (0..<Self.slotCount).first { !taken.contains($0) }
    }

    // MARK: Sampling

    /// Current state for players 1-4. Empty slots read as zero.
    public func sample() -> [InputState] {
        var states = Array(repeating: InputState.zero, count: Self.slotCount)
        for index in devices.indices {
            guard let controller = controllers[devices[index].id] else { continue }
            let state = read(controller)
            if !devices[index].hasSentInput, state.isDeliberate { devices[index].hasSentInput = true }
            if let slot = devices[index].slot { states[slot] = state }
        }
        return states
    }

    /// Keyboard overlay for the slot a keyboard is assigned to.
    public func sampleKeyboard(_ pressed: Set<GCKeyCode>) -> InputState {
        var state = InputState.zero
        for (code, mask) in keyMap.bindings where pressed.contains(code) {
            state.buttons |= mask
        }
        return state
    }

    /// Buttons from the connected keyboard, through `keyMap`.
    public func keyboardButtons() -> UInt32 {
        guard let keyboard = GCKeyboard.coalesced?.keyboardInput, keyboard.isAnyKeyPressed else { return 0 }
        return keyMap.bindings.reduce(0) { keyboard.button(forKeyCode: $1.key)?.isPressed == true ? $0 | $1.value : $0 }
    }

    // MARK: Discovery

    func attach(_ controller: GCController) {
        let id = stableID(controller)
        guard controllers[id] == nil else { return }
        controllers[id] = controller
        let kind = Self.classify(controller)
        let name = controller.vendorName ?? kind.label
        let slot = defaults.stringArray(forKey: Self.unassignedKey)?.contains(name) == true ? nil : firstFreeSlot()
        #if DEBUG
        Logger(subsystem: "com.zenithblue.gagaemu", category: "controllers").notice(
            "attach name=\(name, privacy: .public) category=\(controller.productCategory, privacy: .public) extended=\(controller.extendedGamepad != nil, privacy: .public) snapshot=\(controller.isSnapshot, privacy: .public) attached=\(controller.isAttachedToDevice, privacy: .public) slot=\(String(describing: slot), privacy: .public)")
        #endif
        let device = Device(id: id, name: name, kind: kind, vendor: controller.vendorName ?? "", slot: slot)
        devices.append(device)
        controller.playerIndex = slot.flatMap { GCControllerPlayerIndex(rawValue: $0) } ?? .indexUnset
        onChange?()
    }

    private func detach(_ controller: GCController) {
        let id = stableID(controller)
        controllers[id] = nil
        devices.removeAll { $0.id == id }
        onChange?()
    }

    private func stableID(_ controller: GCController) -> String {
        if let vendor = controller.vendorName, !vendor.isEmpty {
            return "\(vendor)#\(ObjectIdentifier(controller).hashValue)"
        }
        return "controller#\(ObjectIdentifier(controller).hashValue)"
    }

    static func classify(_ controller: GCController) -> Kind {
        let vendor = (controller.vendorName ?? "").lowercased()
        let product = controller.productCategory.lowercased()
        if product.contains("keyboard") { return .keyboard }
        if product.contains("joy-con") || vendor.contains("joy-con") {
            if product.contains("(l)") || product.contains("left") { return .joyConLeft }
            if product.contains("(r)") || product.contains("right") { return .joyConRight }
            return .joyConPair
        }
        if vendor.contains("dualsense") || product.contains("dualsense") { return .dualSense }
        if vendor.contains("dualshock") || product.contains("dualshock") { return .dualShock4 }
        if vendor.contains("xbox") || product.contains("xbox") { return .xbox }
        if controller.extendedGamepad != nil { return .mfi }
        return .unknown
    }

    private func read(_ controller: GCController) -> InputState {
        guard let pad = controller.extendedGamepad else { return .zero }
        var state = InputState()
        func set(_ mask: UInt32, _ pressed: Bool) { if pressed { state.buttons |= mask } }
        set(Button.up, pad.dpad.up.isPressed)
        set(Button.down, pad.dpad.down.isPressed)
        set(Button.left, pad.dpad.left.isPressed)
        set(Button.right, pad.dpad.right.isPressed)
        set(Button.south, pad.buttonA.isPressed)
        set(Button.east, pad.buttonB.isPressed)
        set(Button.west, pad.buttonX.isPressed)
        set(Button.north, pad.buttonY.isPressed)
        set(Button.l1, pad.leftShoulder.isPressed)
        set(Button.r1, pad.rightShoulder.isPressed)
        set(Button.l2, pad.leftTrigger.isPressed)
        set(Button.r2, pad.rightTrigger.isPressed)
        set(Button.start, pad.buttonMenu.isPressed)
        set(Button.select, pad.buttonOptions?.isPressed ?? false)
        set(Button.l3, pad.leftThumbstickButton?.isPressed ?? false)
        set(Button.r3, pad.rightThumbstickButton?.isPressed ?? false)
        // Menu and Options are Start and Select, and a game needs both, so only the pair means the app.
        let pair = pad.buttonMenu.isPressed && pad.buttonOptions?.isPressed == true
        state.openMenu = pair || pad.buttonHome?.isPressed == true
        if pair { state.buttons &= ~(Button.start | Button.select) }
        state.leftX = axis(pad.leftThumbstick.xAxis.value)
        state.leftY = axis(pad.leftThumbstick.yAxis.value)
        state.rightX = axis(pad.rightThumbstick.xAxis.value)
        state.rightY = axis(pad.rightThumbstick.yAxis.value)
        state.triggerL = pad.leftTrigger.value
        state.triggerR = pad.rightTrigger.value
        return state
    }

    private func axis(_ value: Float) -> Int16 {
        let clamped = min(max(value, -1), 1)
        return Int16(clamped * (clamped < 0 ? 32768 : 32767))
    }
}

#if DEBUG
enum ControllerManagerChecks {
    static func run() {
        let manager = ControllerManager()
        assert(manager.touchOwnsPlayerOne)
        assert(manager.firstFreeSlot() == 0)
        manager.devices = [
            .init(id: "a", name: "DualSense", kind: .dualSense, vendor: "Sony", slot: 0),
            .init(id: "b", name: "Xbox", kind: .xbox, vendor: "Microsoft", slot: nil)
        ]
        assert(!manager.touchOwnsPlayerOne)
        manager.assign("b", to: 0)
        assert(manager.device(inSlot: 0)?.id == "b")
        assert(manager.devices.first { $0.id == "a" }?.slot == nil)
        let keys = manager.sampleKeyboard([.keyW, .keyJ])
        assert(keys.buttons & ControllerManager.Button.up != 0)
        assert(keys.buttons & ControllerManager.Button.south != 0)
    }
}
#endif
