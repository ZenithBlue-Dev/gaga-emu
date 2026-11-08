import Foundation
import AudioToolbox
#if canImport(UIKit)
import UIKit
import CoreHaptics
#endif

/// Loads a `.deltaskin` (JSON layout + PNG assets) or a Manic flex skin (JSON + SVG)
/// and turns touches into button masks, stick positions and app actions. Haptics fire on press when enabled.
public final class TouchSkinEngine: ObservableObject {

    public enum Format: String, Sendable { case delta, flex }

    public struct Button: Identifiable, Equatable, Sendable {
        public let id: String
        public var frame: CGRect   // normalized 0...1 inside the skin canvas
        public var mask: UInt32
        public var asset: String?  // PNG name inside the skin, or nil for a drawn shape
        public var shape: Shape
        /// An app function, turbo or macro in place of `mask`. Nil presses `mask`.
        var action: ControlAction? = nil
        /// Multiplies the skin's opacity. Nil is 1.
        var opacity: Double? = nil
        var haptic = true
        var showsLabel = true
        /// A stick's centre zone, as a share of its radius. Nil is `defaultDeadzone`.
        var deadzone: Double? = nil
        /// `hidden` is a hit area with nothing drawn, such as a D-pad diagonal. `stick` is an analog stick: "lstick"
        /// is the left one, any other id the right.
        public enum Shape: String, Codable, Sendable { case rect, circle, dpup, dpdown, dpleft, dpright, hidden, stick }
    }

    public struct Skin: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let format: Format
        public var buttons: [Button]
        public var opacity: Double
        public var scale: Double
        public var landscape: Bool
        public var assets: [String: Data] // PNG bytes, keyed by asset name
        public var svg: String?           // flex skins ship one SVG document
        /// The layout used while the device is upright.
        var portraitButtons: [Button] = []
        /// Controls may sit over the picture.
        var overlay = false
    }

    @Published public private(set) var skin: Skin?
    @Published public var opacity: Double = TouchSkinEngine.defaultOpacity
    @Published public var scale: Double = 1
    @Published public var hapticsEnabled = true
    @Published public var soundEnabled = true
    @Published var hapticStrength = HapticStrength.light
    /// The upright layout is in use.
    @Published public var portrait = false {
        didSet { if portrait != oldValue { releaseAll() } }
    }

    @Published public private(set) var pressed: Set<String> = []
    public struct Sticks: Equatable, Sendable {
        public var lx: Int16 = 0, ly: Int16 = 0, rx: Int16 = 0, ry: Int16 = 0
    }
    /// Both sticks, in the same scale and direction as a controller's (`ControllerManager.InputState`).
    @Published public private(set) var analog = Sticks()
    /// The app actions of the elements held now.
    private(set) var heldActions: Set<ControlAction> = []
    private var stickZones: [String: Int] = [:]

    #if canImport(UIKit)
    private lazy var pressGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var releaseGenerator = UIImpactFeedbackGenerator(style: .soft)
    private lazy var tickGenerator = UISelectionFeedbackGenerator()
    private let deviceHasHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    #endif
    private var lastHaptic: CFTimeInterval = 0

    public init() {}

    /// The buttons of the layout for the current orientation.
    public var buttons: [Button] {
        guard let skin else { return [] }
        return portrait && !skin.portraitButtons.isEmpty ? skin.portraitButtons : skin.buttons
    }

    // MARK: Loading

    /// `directory` is an unpacked `.deltaskin`: `info.json` plus PNG assets.
    public func loadDelta(from directory: URL) throws {
        let info = try Data(contentsOf: directory.appendingPathComponent("info.json"))
        let decoded = try JSONDecoder().decode(DeltaInfo.self, from: info)
        var assets: [String: Data] = [:]
        for representation in decoded.representations {
            for item in representation.items {
                guard let asset = item.asset else { continue }
                let url = directory.appendingPathComponent(asset)
                if let data = try? Data(contentsOf: url) { assets[asset] = data }
            }
        }
        let buttons = decoded.representations.first?.items.compactMap { item -> Button? in
            guard let mask = Self.mask(for: item.inputs) else { return nil }
            return Button(id: item.inputs, frame: item.frame.rect, mask: mask,
                          asset: item.asset, shape: .circle)
        } ?? []
        skin = Skin(id: directory.lastPathComponent, name: decoded.name ?? directory.lastPathComponent,
                    format: .delta, buttons: buttons, opacity: opacity, scale: scale,
                    landscape: decoded.representations.first?.orientation == "landscape",
                    assets: assets, svg: nil, portraitButtons: Self.portrait(from: buttons))
    }

    /// Flex skin: one JSON document with normalized frames and an inline SVG. Its opacity, when it has one,
    /// replaces the drawn controls' opacity.
    public func loadFlex(from url: URL) throws {
        let loaded = try Self.decodeFlex(Data(contentsOf: url), id: url.lastPathComponent)
        opacity = loaded.opacity
        skin = loaded
    }

    /// The flex skin format version the editor writes. 1 had landscape buttons only.
    static let flexVersion = 2

    /// Reads a flex skin. `id` and `mask` are optional per button, so a skin that has only `input` names still
    /// loads; the skin editor writes them so diagonals and second pads keep their combined masks. A version 1
    /// file has no portrait layout, so it gets one made from its landscape buttons, which keeps its edits.
    static func decodeFlex(_ data: Data, id: String) throws -> Skin {
        let decoded = try JSONDecoder().decode(FlexSkin.self, from: data)
        guard (decoded.version ?? 1) <= flexVersion else { throw CocoaError(.fileReadCorruptFile) }
        func buttons(_ items: [FlexSkin.Button]) -> [Button] {
            items.compactMap { item -> Button? in
                let action = item.action
                guard let mask = item.mask ?? Self.mask(for: item.input) ?? (action != nil || item.shape == "stick" ? 0 : nil) else { return nil }
                return Button(id: item.id ?? item.input, frame: item.frame.rect, mask: mask, asset: nil,
                              shape: Button.Shape(rawValue: item.shape ?? "circle") ?? .circle, action: action,
                              opacity: item.opacity, haptic: item.haptic ?? true, showsLabel: item.label ?? true,
                              deadzone: item.deadzone)
            }
        }
        let landscape = buttons(decoded.buttons)
        let upright = decoded.portraitButtons.map(buttons) ?? portrait(from: landscape)
        return Skin(id: id, name: decoded.name, format: .flex, buttons: landscape,
                    opacity: min(max(decoded.opacity ?? defaultOpacity, minimumOpacity), 1), scale: 1,
                    landscape: decoded.landscape ?? true, assets: [:], svg: decoded.svg,
                    portraitButtons: upright, overlay: decoded.overlay ?? false)
    }

    /// Writes the flex skin the skin editor saves: both orientations, no SVG, so controls draw as on a built-in.
    static func encodeFlex(name: String, buttons: [Button], portraitButtons: [Button]? = nil, opacity: Double,
                           overlay: Bool = false) throws -> Data {
        func items(_ list: [Button]) -> [FlexSkin.Button] {
            list.map {
                FlexSkin.Button(input: $0.id, frame: Frame($0.frame), shape: $0.shape.rawValue, id: $0.id, mask: $0.mask,
                                action: $0.action, opacity: $0.opacity, haptic: $0.haptic ? nil : false,
                                label: $0.showsLabel ? nil : false, deadzone: $0.deadzone)
            }
        }
        let skin = FlexSkin(version: flexVersion, name: name, landscape: true, svg: nil, opacity: opacity,
                            overlay: overlay ? true : nil, buttons: items(buttons),
                            portraitButtons: items(portraitButtons ?? portrait(from: buttons)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(skin)
    }

    public static let defaultOpacity = 0.85
    /// Below this the outlines are too faint to find on the letterbox.
    public static let minimumOpacity = 0.3
    static let defaultDeadzone = 0.15
    /// The Assign Skin choice that loads the platform's saved custom layout.
    public static let customID = "custom"

    public func loadDefault() {
        loadBuiltIn(Layout.standard.id)
    }

    /// An unknown ID, say from a later build's state.json, gets the standard layout.
    public func loadBuiltIn(_ id: String, platformID: String = "") {
        let layout = Layout.builtIn.first { $0.id == id } ?? .standard
        opacity = Self.defaultOpacity
        let buttons = layout.buttons(for: platformID)
        skin = Skin(id: layout.id, name: layout.name, format: .flex, buttons: buttons,
                    opacity: opacity, scale: scale, landscape: true, assets: [:], svg: nil,
                    portraitButtons: Self.portrait(from: buttons))
    }

    /// The smallest landscape phone's safe canvas in points (iPhone 17e), which sizes the 44pt check.
    public static let smallestCanvas = CGSize(width: 750, height: 369)
    /// The same phone upright.
    static let smallestPortraitCanvas = CGSize(width: smallestCanvas.height, height: smallestCanvas.width)
    /// Upright, the picture keeps the top of the screen and the controls everything below this share of the height.
    static let portraitControlTop: CGFloat = 0.5

    /// The upright layout made from a landscape one: each band keeps its side and every button its size in points
    /// on the smallest phone, so a layout that passes `problems` in landscape passes upright too.
    static func portrait(from landscape: [Button]) -> [Button] {
        let land = smallestCanvas, upright = smallestPortraitCanvas
        let kx = land.width / upright.width, ky = land.height / upright.height
        return landscape.map { button in
            var moved = button
            let f = button.frame
            let x = f.midX < 0.5 ? f.minX * kx : 1 - (1 - f.minX) * kx
            moved.frame = CGRect(x: x, y: portraitControlTop + f.minY * ky, width: f.width * kx, height: f.height * ky)
            return moved
        }
    }

    /// Why a touch layout cannot be used, empty when it can: every button inside the canvas and, unless `overlay`,
    /// outside the picture (the left and right `controlBand`, or below `portraitControlTop` upright), at least 44pt on
    /// the smallest phone, ids unique, and no two buttons overlapping.
    static func problems(in buttons: [Button], portrait: Bool = false, overlay: Bool = false) -> [String] {
        var found: [String] = []
        let band = controlBand
        let canvas = portrait ? smallestPortraitCanvas : smallestCanvas
        for button in buttons {
            let name = label(for: button).spoken
            let frame = button.frame
            if frame.minX < 0 || frame.minY < 0 || frame.maxX > 1 || frame.maxY > 1 {
                found.append("\(name) is off the screen.")
            } else if !overlay, portrait ? frame.minY < portraitControlTop - 0.0001 : !(frame.maxX <= band || frame.minX >= 1 - band) {
                found.append("\(name) covers the picture.")
            }
            if frame.width * canvas.width < 44 || frame.height * canvas.height < 44 {
                found.append("\(name) is smaller than 44 points.")
            }
        }
        if Set(buttons.map(\.id)).count != buttons.count { found.append("Two buttons share a name.") }
        for (index, a) in buttons.enumerated() {
            for b in buttons[(index + 1)...] where a.frame.insetBy(dx: 0.0001, dy: 0.0001).intersects(b.frame) {
                found.append("\(label(for: a).spoken) overlaps \(label(for: b).spoken).")
            }
        }
        return found
    }

    /// Game choice, then platform choice, then the platform's own layout. A choice that no longer fits the
    /// platform is skipped.
    static func layoutID(game: String?, platform: String?, platformID: String) -> String {
        let choices = Layout.choices(for: platformID).map(\.id)
        return [game, platform].compactMap { $0 }.first(where: choices.contains) ?? Layout.defaultID(for: platformID)
    }

    // MARK: Hit testing

    /// `point` is normalized inside the canvas. Returns the mask now held.
    @discardableResult
    public func touchDown(at point: CGPoint) -> UInt32 {
        guard let hit = button(at: point), !pressed.contains(hit.id) else { return currentMask() }
        pressed.insert(hit.id)
        if hit.haptic { haptic(.press) }
        click()
        return currentMask()
    }

    /// Replaces the held set with whatever these normalized points are on, so a finger can slide
    /// between buttons and two fingers on one button release correctly. Returns the mask now held.
    @discardableResult
    public func setTouches(_ points: [CGPoint]) -> UInt32 {
        guard skin != nil else { return 0 }
        let list = buttons
        var held = Set<String>()
        var sticks: [Bool: (Int16, Int16)] = [:]
        for button in list {
            if button.shape == .stick {
                // A finger keeps the stick a little past its rim, so a hard push does not drop it.
                let reach = scaled(button.frame).insetBy(dx: -button.frame.width * 0.25, dy: -button.frame.height * 0.25)
                guard let point = points.first(where: { reach.contains($0) }) else { stickZones[button.id] = 0; continue }
                held.insert(button.id)
                let value = Self.stickValue(point, in: button.frame, deadzone: button.deadzone ?? Self.defaultDeadzone)
                sticks[button.id != "lstick"] = (value.x, value.y)
                let zone = value.zone
                if zone != stickZones[button.id], button.haptic { haptic(.tick) }
                stickZones[button.id] = zone
            } else if points.contains(where: { scaled(button.frame).contains($0) }) {
                held.insert(button.id)
            }
        }
        // C buttons push the right stick all the way, the way the N64 core reads them.
        // shortcut: one C button at a time; two held push toward the first by name. Sum them if a game needs both.
        let cPush = held.sorted().lazy.compactMap(Self.cPush).first
        let moved = Sticks(lx: sticks[false]?.0 ?? 0, ly: sticks[false]?.1 ?? 0,
                           rx: sticks[true]?.0 ?? cPush?.0 ?? 0, ry: sticks[true]?.1 ?? cPush?.1 ?? 0)
        if moved != analog { analog = moved }
        let added = held.subtracting(pressed), removed = pressed.subtracting(held)
        let pads: Set<String> = ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"]
        let byID = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if added.contains(where: { byID[$0]?.haptic == true && byID[$0]?.shape != .stick }) {
            // A thumb rolling round the pad ticks on each new direction instead of a full press.
            haptic(!pressed.isDisjoint(with: pads) && added.isSubset(of: pads) ? .tick : .press)
            click()
        } else if removed.contains(where: { byID[$0]?.haptic == true && byID[$0]?.shape != .stick }) {
            haptic(.release)
        }
        if held != pressed { pressed = held }
        heldActions = Set(list.filter { held.contains($0.id) }.compactMap(\.action))
        return currentMask()
    }

    /// The direction a C button pushes the right stick, or nil for any other id.
    static func cPush(_ id: String) -> (Int16, Int16)? {
        switch id {
        case "cup": return (0, 32767)
        case "cdown": return (0, -32768)
        case "cleft": return (-32768, 0)
        case "cright": return (32767, 0)
        default: return nil
        }
    }

    /// A finger's place on a stick as stick values, up positive, and its zone: 0 inside the deadzone, 1 between,
    /// 2 at the rim.
    static func stickValue(_ point: CGPoint, in frame: CGRect, deadzone: Double) -> (x: Int16, y: Int16, zone: Int) {
        var dx = (point.x - frame.midX) / (frame.width / 2), dy = -(point.y - frame.midY) / (frame.height / 2)
        let length = (dx * dx + dy * dy).squareRoot()
        if length > 1 { dx /= length; dy /= length }
        let zone = length < deadzone ? 0 : length >= 0.95 ? 2 : 1
        guard zone > 0 else { return (0, 0, 0) }
        return (PadMapper.axis(Float(dx)), PadMapper.axis(Float(dy)), zone)
    }

    @discardableResult
    public func touchUp(at point: CGPoint) -> UInt32 {
        if let hit = button(at: point) { pressed.remove(hit.id) }
        return currentMask()
    }

    public func releaseAll() {
        pressed.removeAll()
        heldActions = []
        if analog != Sticks() { analog = Sticks() }
        stickZones = [:]
    }

    public func currentMask() -> UInt32 {
        buttons.reduce(0) { pressed.contains($1.id) && $1.action == nil ? $0 | $1.mask : $0 }
    }

    /// Moves a button. Used by the skin customizer.
    public func move(_ id: String, to frame: CGRect) {
        guard var skin else { return }
        if portrait, let index = skin.portraitButtons.firstIndex(where: { $0.id == id }) {
            skin.portraitButtons[index].frame = frame
        } else if let index = skin.buttons.firstIndex(where: { $0.id == id }) {
            skin.buttons[index].frame = frame
        } else { return }
        self.skin = skin
    }

    private func button(at point: CGPoint) -> Button? {
        buttons.first { scaled($0.frame).contains(point) }
    }

    private func scaled(_ frame: CGRect) -> CGRect {
        let factor = CGFloat(scale)
        let grown = CGRect(x: frame.midX - frame.width * factor / 2,
                           y: frame.midY - frame.height * factor / 2,
                           width: frame.width * factor, height: frame.height * factor)
        return grown
    }

    // MARK: Feedback

    enum HapticKind { case press, release, tick }

    /// Keyboard click. System sounds obey the silent switch.
    private func click() {
        if soundEnabled { AudioServicesPlaySystemSound(1104) }
    }

    /// A press is firm, a release soft, a tick the lightest. Throttled, so a finger sliding over many buttons does
    /// not buzz, and nothing on a device without haptics. Turbo and macros never come through here.
    func haptic(_ kind: HapticKind) {
        #if canImport(UIKit)
        guard hapticsEnabled, hapticStrength != .off, deviceHasHaptics else { return }
        let now = CACurrentMediaTime()
        guard now - lastHaptic > 0.03 else { return }
        lastHaptic = now
        let intensity: CGFloat = hapticStrength == .light ? 0.4 : hapticStrength == .medium ? 0.7 : 1
        switch kind {
        case .press: pressGenerator.impactOccurred(intensity: intensity); pressGenerator.prepare()
        case .release: releaseGenerator.impactOccurred(intensity: intensity * 0.5); releaseGenerator.prepare()
        case .tick: tickGenerator.selectionChanged(); tickGenerator.prepare()
        }
        #endif
    }

    /// Wakes the generators before the first touch, so it has no lag.
    func prepareHaptics() {
        #if canImport(UIKit)
        guard hapticsEnabled, hapticStrength != .off, deviceHasHaptics else { return }
        pressGenerator.prepare(); releaseGenerator.prepare(); tickGenerator.prepare()
        #endif
    }

    // MARK: Mapping

    static func mask(for input: String) -> UInt32? {
        switch input.lowercased() {
        case "up", "dpadup": return ControllerManager.Button.up
        case "down", "dpaddown": return ControllerManager.Button.down
        case "left", "dpadleft": return ControllerManager.Button.left
        case "right", "dpadright": return ControllerManager.Button.right
        case "a", "b-nintendo", "cross": return ControllerManager.Button.south
        case "b", "a-nintendo", "circle": return ControllerManager.Button.east
        case "x", "y-nintendo", "square": return ControllerManager.Button.west
        case "y", "x-nintendo", "triangle": return ControllerManager.Button.north
        case "l", "l1": return ControllerManager.Button.l1
        case "r", "r1": return ControllerManager.Button.r1
        case "zl", "l2": return ControllerManager.Button.l2
        case "zr", "r2": return ControllerManager.Button.r2
        case "start": return ControllerManager.Button.start
        case "select": return ControllerManager.Button.select
        case "l3": return ControllerManager.Button.l3
        case "r3": return ControllerManager.Button.r3
        default: return nil
        }
    }

    /// Fraction of the canvas width each side keeps for controls. The picture sits between the bands.
    public static let controlBand: CGFloat = 0.2

    /// Spoken name for VoiceOver, and the visible text for buttons that carry one.
    static func label(for id: String) -> (spoken: String, glyph: String?) {
        switch id {
        case "up": return ("D-pad up", nil)
        case "down": return ("D-pad down", nil)
        case "left": return ("D-pad left", nil)
        case "right": return ("D-pad right", nil)
        case "north": return ("X button", "X")
        case "south": return ("B button", "B")
        case "east": return ("A button", "A")
        case "west": return ("Y button", "Y")
        case "l": return ("L button", "L")
        case "r": return ("R button", "R")
        case "start": return ("Start", "Start")
        case "select": return ("Select", "Select")
        case "l3": return ("Keyboard", "Keyboard")
        case "lstick": return ("Left stick", nil)
        case "rstick": return ("Right stick", nil)
        case "cup": return ("C up", "C▲")
        case "cdown": return ("C down", "C▼")
        case "cleft": return ("C left", "C◀")
        case "cright": return ("C right", "C▶")
        default: return (id, id.uppercased())
        }
    }

    /// An element's name, from its action when it has one.
    static func label(for button: Button, macros: [Macro] = []) -> (spoken: String, glyph: String?) {
        switch button.action {
        case .app(let function): return (function.title, function.glyph)
        case .turbo(let mask, let toggle):
            let names = ControlAction.buttonNames(mask)
            return ("Turbo \(names)\(toggle ? ", toggle" : "")", "T\(names)")
        case .macro(let id):
            let name = macros.first { $0.id == id }?.name ?? "Macro"
            return ("Macro \(name)", String(name.prefix(6)))
        case .buttons(let mask):
            let names = ControlAction.buttonNames(mask)
            return (names, names)
        case nil: return label(for: button.id)
        }
    }

    /// A built-in touch layout (Assign Skin, docs/06 section 3.3). Every button stays inside the left and
    /// right `controlBand`. Sizes hold 44pt on the smallest landscape phone. Face labels follow the
    /// header's Nintendo names for each position.
    public struct Layout: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let note: String
        public let buttons: [Button]
        /// Nil means it suits every platform.
        let platforms: Set<String>?

        private static let w: CGFloat = 0.065, h: CGFloat = 0.13

        private static func button(_ id: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat,
                                   _ mask: UInt32, _ shape: Button.Shape) -> Button {
            Button(id: id, frame: CGRect(x: x, y: y, width: width, height: height), mask: mask, asset: nil, shape: shape)
        }

        static func pad(topY: CGFloat, padX: CGFloat = 0.0025) -> [Button] {
            let b = ControllerManager.Button.self
            return [
                button("up", padX + w, topY, w, h, b.up, .dpup),
                button("down", padX + w, topY + 2 * h, w, h, b.down, .dpdown),
                button("left", padX, topY + h, w, h, b.left, .dpleft),
                button("right", padX + 2 * w, topY + h, w, h, b.right, .dpright)
            ] + diagonals(topY: topY, padX: padX)
        }

        /// The D-pad's hidden corner areas, which press two directions at once.
        static func diagonals(topY: CGFloat, padX: CGFloat, width: CGFloat = w, height: CGFloat = h) -> [Button] {
            let b = ControllerManager.Button.self
            return [
                button("upleft", padX, topY, width, height, b.up | b.left, .hidden),
                button("upright", padX + 2 * width, topY, width, height, b.up | b.right, .hidden),
                button("downleft", padX, topY + 2 * height, width, height, b.down | b.left, .hidden),
                button("downright", padX + 2 * width, topY + 2 * height, width, height, b.down | b.right, .hidden)
            ]
        }

        private static func face(topY: CGFloat) -> [Button] {
            let b = ControllerManager.Button.self
            let faceX: CGFloat = 0.8025
            return [
                button("north", faceX + w, topY, w, h, b.north, .circle),
                button("south", faceX + w, topY + 2 * h, w, h, b.south, .circle),
                button("west", faceX, topY + h, w, h, b.west, .circle),
                button("east", faceX + 2 * w, topY + h, w, h, b.east, .circle)
            ]
        }

        private static func shoulders(y: CGFloat) -> [Button] {
            let b = ControllerManager.Button.self
            return [button("l", 0.07, y, 0.125, h, b.l1, .rect), button("r", 0.805, y, 0.125, h, b.r1, .rect)]
        }

        private static func menu(y: CGFloat) -> [Button] {
            let b = ControllerManager.Button.self
            return [button("select", 0.03, y, 0.14, 0.12, b.select, .rect), button("start", 0.83, y, 0.14, 0.12, b.start, .rect)]
        }

        public static let standard = Layout(
            id: "standard", name: "Standard", note: "Pad and buttons at mid height, Select and Start below.",
            buttons: pad(topY: 0.405) + face(topY: 0.405) + shoulders(y: 0.02) + menu(y: 0.85), platforms: nil)

        public static let lowReach = Layout(
            id: "low-reach", name: "Low Reach", note: "Pad and buttons at the bottom edge, Select and Start above them.",
            buttons: pad(topY: 0.60) + face(topY: 0.60) + shoulders(y: 0.02) + menu(y: 0.42), platforms: nil)

        /// For systems with two face buttons. Larger targets, set on a slant.
        public static let twoButton: Layout = {
            let b = ControllerManager.Button.self
            return Layout(
                id: "two-button", name: "Two Button", note: "A and B alone, larger and on a slant. For systems with two face buttons.",
                buttons: pad(topY: 0.405) + shoulders(y: 0.02) + menu(y: 0.85) + [
                    button("east", 0.895, 0.33, 0.1, 0.2, b.east, .circle),
                    button("south", 0.805, 0.55, 0.1, 0.2, b.south, .circle)
                ],
                platforms: ["gba", "gb", "gbc", "nes", "pce", "sgx", "ngp", "pokemini", "mastersystem", "gamegear", "sg1000", "atari2600",
                            "atari7800", "lynx", "atari5200", "atari8bit", "c64", "amiga"])
        }()

        /// A second D-pad on the right, sending the RetroPad buttons the core reads it from, with A and B above.
        private static func secondPad(up: UInt32, down: UInt32, left: UInt32, right: UInt32) -> [Button] {
            let b = ControllerManager.Button.self
            let x: CGFloat = 0.8025, y: CGFloat = 0.405
            return [
                button("pad2up", x + w, y, w, h, up, .dpup),
                button("pad2down", x + w, y + 2 * h, w, h, down, .dpdown),
                button("pad2left", x, y + h, w, h, left, .dpleft),
                button("pad2right", x + 2 * w, y + h, w, h, right, .dpright),
                button("south", 0.8, 0.19, 0.08, 0.15, b.south, .circle),
                button("east", 0.9, 0.19, 0.08, 0.15, b.east, .circle)
            ]
        }

        /// The Virtual Boy's right pad: L2 up, L3 down, R2 left, R3 right.
        public static let twinPad: Layout = {
            let b = ControllerManager.Button.self
            return Layout(
                id: "twin-pad", name: "Twin Pad", note: "A second pad on the right, with A and B above it.",
                buttons: pad(topY: 0.405) + shoulders(y: 0.02) + menu(y: 0.85)
                    + secondPad(up: b.l2, down: b.l3, left: b.r2, right: b.r3),
                platforms: ["vb"])
        }()

        /// The WonderSwan's X pad on the left and Y pad on the right (R2 up, L2 down, L1 left, R1 right), A and
        /// B, and Start. Select turns a vertical game upright; the console has no such key.
        public static let xyPad: Layout = {
            let b = ControllerManager.Button.self
            return Layout(
                id: "xy-pad", name: "X and Y Pads", note: "Both cursor pads, A and B. Select turns the picture.",
                buttons: pad(topY: 0.405) + menu(y: 0.85) + secondPad(up: b.r2, down: b.l2, left: b.l1, right: b.r1),
                platforms: ["ws"])
        }()

        /// DOSBox Pure opens its on-screen keyboard on L3. It sits in the space under L that every layout a
        /// typing platform can choose leaves free.
        static let keyboard = button("l3", 0.03, 0.2, 0.14, 0.12, ControllerManager.Button.l3, .rect)

        /// Square on the smallest phone: 0.11 of its width is 0.2236 of its height.
        private static let stickSize = CGSize(width: 0.11, height: 0.11 * 750 / 369)

        /// Systems with a left analog stick (N64, PSP, PlayStation analog, 3DS circle pad). It sits between L and the
        /// D-pad, which every layout these systems can choose leaves free.
        static let leftStickPlatforms: Set<String> = ["n64", "psp", "ps1", "n3ds"]
        static let leftStick = button("lstick", 0.045, 0.165, stickSize.width, stickSize.height, 0, .stick)
        /// The PlayStation's right stick, between R and the face buttons.
        static let rightStick = button("rstick", 0.845, 0.165, stickSize.width, stickSize.height, 0, .stick)

        /// The N64's C buttons, between R and the face buttons: C up above C left, C down and C right.
        static let cButtons: [Button] = [
            button("cup", 0.8675, 0.155, w, 0.12, 0, .rect),
            button("cleft", 0.8025, 0.28, w, 0.12, 0, .rect),
            button("cdown", 0.8675, 0.28, w, 0.12, 0, .rect),
            button("cright", 0.9325, 0.28, w, 0.12, 0, .rect)
        ]

        /// The layout's buttons, plus the keyboard key on a platform that types (`GameSession.typingPlatforms`),
        /// and the sticks and C buttons of the systems that have them.
        public func buttons(for platformID: String) -> [Button] {
            var list = buttons
            if GameSession.typingPlatforms.contains(platformID) { list.append(Self.keyboard) }
            if Self.leftStickPlatforms.contains(platformID) { list.append(Self.leftStick) }
            if platformID == "ps1" { list.append(Self.rightStick) }
            if platformID == "n64" { list += Self.cButtons }
            return list
        }

        public static let builtIn: [Layout] = [.standard, .lowReach, .twoButton, .twinPad, .xyPad]

        /// The layout a platform starts on when the player has chosen none: the one shaped like its controller.
        /// Platforms added before milestone 8.x keep Standard.
        static let platformDefaults: [String: String] = ["pce": "two-button", "sgx": "two-button", "vb": "twin-pad", "ngp": "two-button", "ws": "xy-pad",
                                                              "pokemini": "two-button"]

        static func defaultID(for platformID: String) -> String { platformDefaults[platformID] ?? standard.id }

        public static func choices(for platformID: String) -> [Layout] {
            builtIn.filter { $0.platforms?.contains(platformID) ?? true }
        }
    }
}

private struct DeltaInfo: Decodable {
    let name: String?
    let representations: [Representation]
    struct Representation: Decodable {
        let orientation: String?
        let items: [Item]
    }
    struct Item: Decodable {
        let inputs: String
        let frame: Frame
        let asset: String?
    }
}

/// Version 2 adds `portraitButtons`, `overlay` and the per-button fields after `mask`. Version 1 files still read.
private struct FlexSkin: Codable {
    var version: Int?
    let name: String
    let landscape: Bool?
    let svg: String?
    var opacity: Double?
    var overlay: Bool?
    let buttons: [Button]
    var portraitButtons: [Button]?
    struct Button: Codable {
        let input: String
        let frame: Frame
        let shape: String?
        var id: String?
        var mask: UInt32?
        var action: ControlAction?
        var opacity: Double?
        var haptic: Bool?
        var label: Bool?
        var deadzone: Double?
    }
}

private struct Frame: Codable {
    let x, y, width, height: Double
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

private extension Frame {
    init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

#if DEBUG
enum TouchSkinEngineChecks {
    static func run() {
        let engine = TouchSkinEngine()
        engine.hapticsEnabled = false
        engine.soundEnabled = false
        engine.loadDefault()
        let mask = engine.touchDown(at: CGPoint(x: 0.90, y: 0.72))
        assert(mask & ControllerManager.Button.south != 0)
        assert(engine.touchUp(at: CGPoint(x: 0.90, y: 0.72)) == 0)
        assert(TouchSkinEngine.mask(for: "cross") == ControllerManager.Button.south)
        assert(TouchSkinEngine.mask(for: "nope") == nil)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gaga-skin-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = #"{"name":"Test","representations":[{"orientation":"landscape","items":[{"inputs":"a","frame":{"x":0.8,"y":0.6,"width":0.1,"height":0.1},"asset":null}]}]}"#
        try? json.data(using: .utf8)?.write(to: dir.appendingPathComponent("info.json"))
        try? engine.loadDelta(from: dir)
        assert(engine.skin?.buttons.count == 1)
        assert(engine.skin?.format == .delta)
    }
}
#endif
