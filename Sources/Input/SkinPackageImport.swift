import Foundation

/// Reads the button layout from a user's own `.manicskin` or `.deltaskin`: a flat ZIP with an `info.json`. Only
/// positions and inputs come across. The art is not read, so GagaEmu's own controls draw at those positions and no
/// PDF or image from the file is ever opened. The file is untrusted: `info.json` is size-limited and is the only
/// entry unpacked, and frames are validated.
extension TouchSkinEngine {
    enum SkinPackageError: Error { case noLayout }

    private static let infoLimit = 1 << 20
    private static let itemLimit = 64

    static func skinPackageLayout(at url: URL) throws -> (landscape: [Button]?, portrait: [Button]?) {
        guard let info = CoreCatalog.zipEntries(url).first(where: { $0.name == "info.json" }) else { throw SkinPackageError.noLayout }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("skin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try CoreCatalog.extractZipEntry(info, from: url, to: folder.appendingPathComponent("info.json"), limit: infoLimit)
        return try skinPackageLayout(info: Data(contentsOf: file))
    }

    static func skinPackageLayout(info data: Data) throws -> (landscape: [Button]?, portrait: [Button]?) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = root["representations"] as? [String: Any],
              let device = (devices["iphone"] ?? devices["ipad"]) as? [String: Any],
              let variant = (device["edgeToEdge"] ?? device["standard"]) as? [String: Any] else { throw SkinPackageError.noLayout }
        let landscape = (variant["landscape"] as? [String: Any]).flatMap(buttons(face:))
        let portrait = (variant["portrait"] as? [String: Any]).flatMap(buttons(face:))
        guard landscape != nil || portrait != nil else { throw SkinPackageError.noLayout }
        return (landscape, portrait)
    }

    private static func buttons(face: [String: Any]) -> [Button]? {
        guard let items = face["items"] as? [[String: Any]], items.count <= itemLimit,
              let size = face["mappingSize"] as? [String: Any],
              let width = number(size["width"]), let height = number(size["height"]), width > 0, height > 0 else { return nil }
        var result: [Button] = []
        for item in items {
            guard let rect = item["frame"] as? [String: Any],
                  let x = number(rect["x"]), let y = number(rect["y"]), let w = number(rect["width"]), let h = number(rect["height"]),
                  w > 0, h > 0 else { continue }
            let frame = CGRect(x: x / width, y: y / height, width: w / width, height: h / height)
            for button in buttons(inputs: item["inputs"], frame: frame) where !result.contains(where: { $0.id == button.id }) {
                result.append(button)
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = (value as? NSNumber)?.doubleValue, number.isFinite, abs(number) < 100_000 else { return nil }
        return number
    }

    private static func buttons(inputs: Any?, frame: CGRect) -> [Button] {
        if let map = inputs as? [String: String] {
            guard map["up"] != nil, map["left"] != nil else { return [] }
            if map.values.contains(where: { $0.lowercased().contains("analog") || $0.lowercased().contains("stick") }) {
                return [Button(id: "lstick", frame: frame, mask: 0, asset: nil, shape: .stick)]
            }
            let w = frame.width / 3, h = frame.height / 3
            let b = ControllerManager.Button.self
            return [
                Button(id: "up", frame: CGRect(x: frame.minX + w, y: frame.minY, width: w, height: h), mask: b.up, asset: nil, shape: .dpup),
                Button(id: "down", frame: CGRect(x: frame.minX + w, y: frame.minY + 2 * h, width: w, height: h), mask: b.down, asset: nil, shape: .dpdown),
                Button(id: "left", frame: CGRect(x: frame.minX, y: frame.minY + h, width: w, height: h), mask: b.left, asset: nil, shape: .dpleft),
                Button(id: "right", frame: CGRect(x: frame.minX + 2 * w, y: frame.minY + h, width: w, height: h), mask: b.right, asset: nil, shape: .dpright)
            ]
        }
        let names = (inputs as? [String]) ?? (inputs as? String).map { [$0] } ?? []
        guard let first = names.first?.lowercased() else { return [] }
        if names.count == 1, let function = appFunctions[first] {
            return [Button(id: first, frame: frame, mask: 0, asset: nil, shape: .rect, action: .app(function))]
        }
        let parts = names.map { packageInput($0.lowercased()) }
        guard let masks = parts.map(\.mask) as? [UInt32] else { return [] }
        let id = parts.map(\.id).joined(separator: "+")
        return [Button(id: id, frame: frame, mask: masks.reduce(0, |), asset: nil, shape: .circle)]
    }

    /// In these files "a" is the right face button, as on a Nintendo pad; `mask(for:)` reads "a" as the bottom one.
    private static func packageInput(_ name: String) -> (id: String, mask: UInt32?) {
        switch name {
        case "a": return ("east", mask(for: "a-nintendo"))
        case "b": return ("south", mask(for: "b-nintendo"))
        case "x": return ("north", mask(for: "x-nintendo"))
        case "y": return ("west", mask(for: "y-nintendo"))
        default: return (name, mask(for: name))
        }
    }

    private static let appFunctions: [String: AppFunction] = [
        "menu": .pauseMenu, "quicksave": .quickSave, "quickload": .quickLoad, "fastforward": .fastForwardHold,
        "togglefastforward": .fastForwardToggle, "reverse": .rewindHold
    ]
}
