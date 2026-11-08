import Foundation
import GameController
import os

/// Tracks MFi, DualShock 4, DualSense, Xbox, Joy-Con (paired or split), and keyboards.
/// Assigns each physical controller to one of five player slots: four ports, and a fifth through a multiplayer
/// adapter (`CoreCatalog.multitap`). Player 1 falls back to the on-screen touch skin when its slot is empty.
public final class ControllerManager: ObservableObject {

    public static let slotCount = 5

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
        /// App functions, turbo and macros held this frame through the mapping (`PadProfile`). Never reach a core.
        var actions: Set<ControlAction> = []
        public static let zero = InputState()

        /// Past stick and trigger drift, which a pad nobody is holding can report.
        var isDeliberate: Bool {
            let half: Int32 = 16384
            return buttons != 0 || !actions.isEmpty || triggerL > 0.5 || triggerR > 0.5
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

    @Published public var devices: [Device] = []
    /// The hardware keyboard's mapping. The running game sets it from Controls.json (`ControlsStore.keyProfile`).
    var keyProfile: () -> KeyProfile = { .standard }

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

    /// The physical controller in `slot`, for its haptics.
    func controller(inSlot slot: Int) -> GCController? {
        device(inSlot: slot).flatMap { controllers[$0.id] }
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

    /// Current state for players 1-5. Empty slots read as zero.
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

    /// Player 1's buttons and actions from the held keys, through `keyProfile`.
    func sampleKeyboard(_ held: Set<Int>) -> InputState {
        KeyMapper.resolve(held: held, profile: keyProfile())
    }

    /// The HID usages held on the connected keyboard, which are GCKeyCode's raw values. Letters through right GUI.
    func keyboardHeld() -> Set<Int> {
        guard let keyboard = GCKeyboard.coalesced?.keyboardInput, keyboard.isAnyKeyPressed else { return [] }
        return Set((0x04...0xE7).filter { keyboard.button(forKeyCode: GCKeyCode(rawValue: $0))?.isPressed == true })
    }

    /// Every key held on the connected keyboard, for a core that types: bit (u & 7) of byte u >> 3 for HID usage u.
    static func keyBits(_ held: Set<Int>) -> [UInt8] {
        var keys = [UInt8](repeating: 0, count: 32)
        for usage in held where (0..<256).contains(usage) { keys[usage >> 3] |= 1 << (usage & 7) }
        return keys
    }

    // MARK: System gestures

    private var gesturesReserved = false

    /// Home, Menu and Options (Share) may belong to iOS (Control Center, the app switcher, screen recording).
    /// While a game runs the app asks for them; `false` hands them back. Also applies to a pad that joins later.
    func reserveSystemGestures(_ reserve: Bool) {
        gesturesReserved = reserve
        controllers.values.forEach(applyGestures)
    }

    private func applyGestures(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        let state: GCControllerElement.SystemGestureState = gesturesReserved ? .disabled : .enabled
        for button in [pad.buttonHome, pad.buttonMenu, pad.buttonOptions] { button?.preferredSystemGestureState = state }
    }

    // MARK: Discovery

    func attach(_ controller: GCController) {
        let id = stableID(controller)
        guard controllers[id] == nil else { return }
        controllers[id] = controller
        applyGestures(controller)
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

    /// The mapping for a controller type. The running game sets it from its Controls.json profiles; the
    /// defaults are the RetroPad by position, with Home for the menu.
    var profile: (Kind) -> PadProfile = { .standard(for: $0) }

    /// Seconds Menu is held on player 1's controller to open the pause menu; 0 when off or none is assigned.
    func menuHoldSeconds() -> Double {
        guard let kind = device(inSlot: 0)?.kind else { return 0 }
        return profile(kind).menuHold
    }

    private func read(_ controller: GCController) -> InputState {
        guard let pad = controller.extendedGamepad else { return .zero }
        let kind = devices.first { $0.id == stableID(controller) }?.kind ?? .mfi
        return PadMapper.resolve(Self.padState(pad), profile: profile(kind))
    }

    static func padState(_ pad: GCExtendedGamepad) -> PadState {
        var state = PadState()
        let elements: [(PadInput, GCControllerButtonInput?)] = [
            (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
            (.l1, pad.leftShoulder), (.r1, pad.rightShoulder), (.l2, pad.leftTrigger), (.r2, pad.rightTrigger),
            (.l3, pad.leftThumbstickButton), (.r3, pad.rightThumbstickButton),
            (.up, pad.dpad.up), (.down, pad.dpad.down), (.left, pad.dpad.left), (.right, pad.dpad.right),
            (.menu, pad.buttonMenu), (.options, pad.buttonOptions), (.home, pad.buttonHome)
        ]
        state.held = Set(elements.compactMap { $0.1?.isPressed == true ? $0.0 : nil })
        state.leftX = pad.leftThumbstick.xAxis.value
        state.leftY = pad.leftThumbstick.yAxis.value
        state.rightX = pad.rightThumbstick.xAxis.value
        state.rightY = pad.rightThumbstick.yAxis.value
        state.triggerL = pad.leftTrigger.value
        state.triggerR = pad.rightTrigger.value
        return state
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
        let keys = manager.sampleKeyboard([Int(GCKeyCode.keyW.rawValue), Int(GCKeyCode.keyJ.rawValue)])
        assert(keys.buttons & ControllerManager.Button.up != 0)
        assert(keys.buttons & ControllerManager.Button.south != 0)
    }
}
#endif
