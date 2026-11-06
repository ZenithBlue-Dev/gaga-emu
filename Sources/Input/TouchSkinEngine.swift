import Foundation
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
        public enum Shape: String, Codable, Sendable { case rect, circle, dpup, dpdown, dpleft, dpright }
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

    public private(set) var pressed: Set<String> = []

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
        skin = Skin(id: "default", name: "Default", format: .flex, buttons: Self.defaultLayout,
                    opacity: opacity, scale: scale, landscape: true, assets: [:], svg: nil)
    }

    // MARK: Hit testing

    /// `point` is normalized inside the canvas. Returns the mask now held.
    @discardableResult
    public func touchDown(at point: CGPoint) -> UInt32 {
        guard let hit = button(at: point), !pressed.contains(hit.id) else { return currentMask() }
        pressed.insert(hit.id)
        if hapticsEnabled { tap() }
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
        default: return nil
        }
    }

    static let defaultLayout: [Button] = [
        .init(id: "up", frame: .init(x: 0.06, y: 0.55, width: 0.09, height: 0.12), mask: ControllerManager.Button.up, asset: nil, shape: .dpup),
        .init(id: "down", frame: .init(x: 0.06, y: 0.79, width: 0.09, height: 0.12), mask: ControllerManager.Button.down, asset: nil, shape: .dpdown),
        .init(id: "left", frame: .init(x: 0.00, y: 0.67, width: 0.09, height: 0.12), mask: ControllerManager.Button.left, asset: nil, shape: .dpleft),
        .init(id: "right", frame: .init(x: 0.12, y: 0.67, width: 0.09, height: 0.12), mask: ControllerManager.Button.right, asset: nil, shape: .dpright),
        .init(id: "a", frame: .init(x: 0.86, y: 0.66, width: 0.10, height: 0.14), mask: ControllerManager.Button.south, asset: nil, shape: .circle),
        .init(id: "b", frame: .init(x: 0.74, y: 0.74, width: 0.10, height: 0.14), mask: ControllerManager.Button.east, asset: nil, shape: .circle),
        .init(id: "start", frame: .init(x: 0.55, y: 0.82, width: 0.08, height: 0.07), mask: ControllerManager.Button.start, asset: nil, shape: .rect),
        .init(id: "select", frame: .init(x: 0.45, y: 0.82, width: 0.08, height: 0.07), mask: ControllerManager.Button.select, asset: nil, shape: .rect)
    ]
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
