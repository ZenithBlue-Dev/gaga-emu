import Foundation
import GameController

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
        public static let zero = InputState()
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

    public init() {
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

    /// Player 1 uses touch whenever nothing physical is bound to slot 0.
    public var touchOwnsPlayerOne: Bool {
        !devices.contains { $0.slot == 0 && !$0.isTouch }
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
        for device in devices {
            guard let slot = device.slot, let controller = controllers[device.id] else { continue }
            states[slot] = read(controller)
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

    // MARK: Discovery

    private func attach(_ controller: GCController) {
        let id = stableID(controller)
        guard controllers[id] == nil else { return }
        controllers[id] = controller
        let kind = Self.classify(controller)
        let slot = firstFreeSlot()
        let device = Device(id: id, name: controller.vendorName ?? kind.label, kind: kind,
                            vendor: controller.vendorName ?? "", slot: slot)
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
