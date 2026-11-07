import Foundation
import AudioToolbox
#if canImport(UIKit)
import UIKit
import CoreHaptics
#endif

/// Loads a `.deltaskin` (JSON layout + PNG assets) or a Manic flex skin (JSON + SVG)
/// and turns touches into button masks. Haptics fire on press when enabled.
public final class TouchSkinEngine: ObservableObject {

    public enum Format: String, Sendable { case delta, flex }

    public struct Button: Identifiable, Equatable, Sendable {
        public let id: String
        public var frame: CGRect   // normalized 0...1 inside the skin canvas
        public var mask: UInt32
        public var asset: String?  // PNG name inside the skin, or nil for a drawn shape
        public var shape: Shape
        /// `hidden` is a hit area with nothing drawn, such as a D-pad diagonal.
        public enum Shape: String, Codable, Sendable { case rect, circle, dpup, dpdown, dpleft, dpright, hidden }
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
    }

    @Published public private(set) var skin: Skin?
    @Published public var opacity: Double = 0.85
    @Published public var scale: Double = 1
    @Published public var hapticsEnabled = true
    @Published public var soundEnabled = true

    @Published public private(set) var pressed: Set<String> = []

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    #endif

    public init() {
        #if canImport(CoreHaptics)
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
            try? engine?.start()
        }
        #endif
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
                    assets: assets, svg: nil)
    }

    /// Flex skin: one JSON document with normalized frames and an inline SVG.
    public func loadFlex(from url: URL) throws {
        let decoded = try JSONDecoder().decode(FlexSkin.self, from: Data(contentsOf: url))
        let buttons = decoded.buttons.compactMap { item -> Button? in
            guard let mask = Self.mask(for: item.input) else { return nil }
            return Button(id: item.input, frame: item.frame.rect, mask: mask,
                          asset: nil, shape: Button.Shape(rawValue: item.shape ?? "circle") ?? .circle)
        }
        skin = Skin(id: url.lastPathComponent, name: decoded.name, format: .flex, buttons: buttons,
                    opacity: opacity, scale: scale, landscape: decoded.landscape ?? true,
                    assets: [:], svg: decoded.svg)
    }

    public func loadDefault() {
        loadBuiltIn(Layout.standard.id)
    }

    /// An unknown ID, say from a later build's state.json, gets the standard layout.
    public func loadBuiltIn(_ id: String, platformID: String = "") {
        let layout = Layout.builtIn.first { $0.id == id } ?? .standard
        skin = Skin(id: layout.id, name: layout.name, format: .flex, buttons: layout.buttons(for: platformID),
                    opacity: opacity, scale: scale, landscape: true, assets: [:], svg: nil)
    }

    /// Game choice, then platform choice, then standard. A choice that no longer fits the platform is skipped.
    static func layoutID(game: String?, platform: String?, platformID: String) -> String {
        let choices = Layout.choices(for: platformID).map(\.id)
        return [game, platform].compactMap { $0 }.first(where: choices.contains) ?? Layout.standard.id
    }

    // MARK: Hit testing

    /// `point` is normalized inside the canvas. Returns the mask now held.
    @discardableResult
    public func touchDown(at point: CGPoint) -> UInt32 {
        guard let hit = button(at: point), !pressed.contains(hit.id) else { return currentMask() }
        pressed.insert(hit.id)
        feedback()
        return currentMask()
    }

    /// Replaces the held set with whatever these normalized points are on, so a finger can slide
    /// between buttons and two fingers on one button release correctly. Returns the mask now held.
    @discardableResult
    public func setTouches(_ points: [CGPoint]) -> UInt32 {
        guard let skin else { return 0 }
        let held = Set(skin.buttons.filter { button in
            points.contains { scaled(button.frame).contains($0) }
        }.map(\.id))
        if !held.subtracting(pressed).isEmpty { feedback() }
        if held != pressed { pressed = held }
        return currentMask()
    }

    @discardableResult
    public func touchUp(at point: CGPoint) -> UInt32 {
        if let hit = button(at: point) { pressed.remove(hit.id) }
        return currentMask()
    }

    public func releaseAll() { pressed.removeAll() }

    public func currentMask() -> UInt32 {
        guard let skin else { return 0 }
        return skin.buttons.reduce(0) { pressed.contains($1.id) ? $0 | $1.mask : $0 }
    }

    /// Moves a button. Used by the skin customizer.
    public func move(_ id: String, to frame: CGRect) {
        guard var skin, let index = skin.buttons.firstIndex(where: { $0.id == id }) else { return }
        skin.buttons[index].frame = frame
        self.skin = skin
    }

    private func button(at point: CGPoint) -> Button? {
        guard let skin else { return nil }
        return skin.buttons.first { scaled($0.frame).contains(point) }
    }

    private func scaled(_ frame: CGRect) -> CGRect {
        let factor = CGFloat(scale)
        let grown = CGRect(x: frame.midX - frame.width * factor / 2,
                           y: frame.midY - frame.height * factor / 2,
                           width: frame.width * factor, height: frame.height * factor)
        return grown
    }

    private func feedback() {
        if hapticsEnabled { tap() }
        // Keyboard click. System sounds obey the silent switch.
        if soundEnabled { AudioServicesPlaySystemSound(1104) }
    }

    private func tap() {
        #if canImport(CoreHaptics)
        guard let engine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: 0)
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
        default: return (id, id.uppercased())
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

        private static func pad(topY: CGFloat) -> [Button] {
            let b = ControllerManager.Button.self
            let padX: CGFloat = 0.0025
            return [
                button("up", padX + w, topY, w, h, b.up, .dpup),
                button("down", padX + w, topY + 2 * h, w, h, b.down, .dpdown),
                button("left", padX, topY + h, w, h, b.left, .dpleft),
                button("right", padX + 2 * w, topY + h, w, h, b.right, .dpright),
                button("upleft", padX, topY, w, h, b.up | b.left, .hidden),
                button("upright", padX + 2 * w, topY, w, h, b.up | b.right, .hidden),
                button("downleft", padX, topY + 2 * h, w, h, b.down | b.left, .hidden),
                button("downright", padX + 2 * w, topY + 2 * h, w, h, b.down | b.right, .hidden)
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
                platforms: ["gba", "gb", "gbc", "nes", "mastersystem", "gamegear", "sg1000", "atari2600", "atari7800", "lynx", "atari5200", "atari8bit", "c64", "amiga"])
        }()

        /// DOSBox Pure opens its on-screen keyboard on L3. It sits in the space under L that every layout a
        /// typing platform can choose leaves free.
        static let keyboard = button("l3", 0.03, 0.2, 0.14, 0.12, ControllerManager.Button.l3, .rect)

        /// The layout's buttons, plus the keyboard key on a platform that types (`GameSession.typingPlatforms`).
        public func buttons(for platformID: String) -> [Button] {
            GameSession.typingPlatforms.contains(platformID) ? buttons + [Self.keyboard] : buttons
        }

        public static let builtIn: [Layout] = [.standard, .lowReach, .twoButton]

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

private struct FlexSkin: Decodable {
    let name: String
    let landscape: Bool?
    let svg: String?
    let buttons: [Button]
    struct Button: Decodable {
        let input: String
        let frame: Frame
        let shape: String?
    }
}

private struct Frame: Decodable {
    let x, y, width, height: Double
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

#if DEBUG
enum TouchSkinEngineChecks {
    static func run() {
        let engine = TouchSkinEngine()
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
