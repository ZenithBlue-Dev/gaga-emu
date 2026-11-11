import Foundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// Reads the button layout from a user's own `.manicskin` or `.deltaskin`: a flat ZIP with an `info.json`, and the
/// art each orientation names. The file is untrusted: `info.json` and each art file are size-limited and are the
/// only entries unpacked, frames are validated, and the art is decoded by ImageIO or Core Graphics into a new PNG of
/// bounded size, so only GagaEmu's own re-encoded copy is kept.
extension TouchSkinEngine {
    enum SkinPackageError: Error { case noLayout }

    private static let infoLimit = 1 << 20
    private static let itemLimit = 64
    /// The largest art file unpacked, and the largest PNG kept.
    static let artLimit = 16 << 20
    /// The kept art's long side in pixels.
    static let artSide = 2048
    /// A bitmap wider or taller than this is refused before it is decoded.
    private static let artSourceSide = 16_384

    /// A package's own art, as `Skin.assets` keys it: "landscape" and "portrait", PNG bytes. Empty when the package
    /// has none GagaEmu can read; the layout still imports.
    static func skinPackageArt(at url: URL) -> [String: Data] {
        let entries = CoreCatalog.zipEntries(url)
        guard let info = entries.first(where: { $0.name == "info.json" }) else { return [:] }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("skin-\(UUID().uuidString)", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return [:] }
        defer { try? FileManager.default.removeItem(at: folder) }
        guard let file = try? CoreCatalog.extractZipEntry(info, from: url, to: folder.appendingPathComponent("info.json"), limit: infoLimit),
              let data = try? Data(contentsOf: file), let variant = try? packageVariant(data) else { return [:] }
        var art: [String: Data] = [:]
        for orientation in ["landscape", "portrait"] {
            guard let face = variant[orientation] as? [String: Any], let name = assetName(face["assets"]),
                  let entry = entries.first(where: { $0.name == name }),
                  let source = try? CoreCatalog.extractZipEntry(entry, from: url, to: folder.appendingPathComponent(orientation), limit: artLimit),
                  let png = packageArtPNG(source, canvas: mappingSize(face)) else { continue }
            art[orientation] = png
        }
        return art
    }

    /// The art file an orientation names: the vector one, else the largest bitmap. A name with a folder in it is refused.
    static func assetName(_ assets: Any?) -> String? {
        guard let assets = assets as? [String: Any] else { return nil }
        for key in ["resizable", "large", "medium", "small"] {
            if let name = assets[key] as? String, !name.isEmpty, name.count < 256, !name.hasPrefix("."),
               !name.contains("/"), !name.contains("\\") { return name }
        }
        return nil
    }

    private static func mappingSize(_ face: [String: Any]) -> CGSize? {
        guard let size = face["mappingSize"] as? [String: Any], let w = number(size["width"]), let h = number(size["height"]),
              w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    /// A PDF's first page drawn at the layout's shape, or a bitmap downsampled by ImageIO, as a new PNG whose long
    /// side is at most `artSide`. Nil for anything else, or a result over `artLimit`.
    static func packageArtPNG(_ file: URL, canvas: CGSize?) -> Data? {
        guard let head = try? FileHandle(forReadingFrom: file).read(upToCount: 5) else { return nil }
        let image: CGImage?
        if head == Data("%PDF-".utf8) {
            image = pdfImage(file, canvas: canvas)
        } else {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil), CGImageSourceGetCount(source) > 0,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
                  let h = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
                  w > 0, h > 0, w <= artSourceSide, h <= artSourceSide else { return nil }
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(artSide, max(w, h))
            ] as CFDictionary)
        }
        guard let image else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), out.length > 0, out.length <= artLimit else { return nil }
        return out as Data
    }

    private static func pdfImage(_ file: URL, canvas: CGSize?) -> CGImage? {
        guard let page = CGPDFDocument(file as CFURL)?.page(at: 1) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        let shape = canvas ?? box.size
        guard box.width > 0, box.height > 0, shape.width > 0, shape.height > 0 else { return nil }
        let k = CGFloat(artSide) / max(shape.width, shape.height)
        let width = max(1, Int((shape.width * k).rounded())), height = max(1, Int((shape.height * k).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Stretched to the layout's shape, as the buttons' frames are normalised to it.
        context.scaleBy(x: CGFloat(width) / box.width, y: CGFloat(height) / box.height)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    /// Where a saved custom skin keeps its art, beside its JSON.
    static func artURL(beside json: URL, portrait: Bool) -> URL {
        json.deletingPathExtension().appendingPathExtension(portrait ? "portrait.png" : "landscape.png")
    }

    /// The art saved beside a custom skin, as `Skin.assets` keys it.
    static func savedArt(beside json: URL) -> [String: Data] {
        var art: [String: Data] = [:]
        for portrait in [false, true] {
            let url = artURL(beside: json, portrait: portrait)
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= artLimit,
               let data = try? Data(contentsOf: url) { art[portrait ? "portrait" : "landscape"] = data }
        }
        return art
    }

    /// Writes the art beside a custom skin, and removes any an orientation no longer has.
    static func writeArt(_ art: [String: Data], beside json: URL) throws {
        for portrait in [false, true] {
            let url = artURL(beside: json, portrait: portrait)
            if let data = art[portrait ? "portrait" : "landscape"] {
                try data.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    static func skinPackageLayout(at url: URL) throws -> (landscape: [Button]?, portrait: [Button]?) {
        guard let info = CoreCatalog.zipEntries(url).first(where: { $0.name == "info.json" }) else { throw SkinPackageError.noLayout }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("skin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try CoreCatalog.extractZipEntry(info, from: url, to: folder.appendingPathComponent("info.json"), limit: infoLimit)
        return try skinPackageLayout(info: Data(contentsOf: file))
    }

    /// The iPhone's (else the iPad's) edge-to-edge (else standard) representation.
    private static func packageVariant(_ data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = root["representations"] as? [String: Any],
              let device = (devices["iphone"] ?? devices["ipad"]) as? [String: Any],
              let variant = (device["edgeToEdge"] ?? device["standard"]) as? [String: Any] else { throw SkinPackageError.noLayout }
        return variant
    }

    static func skinPackageLayout(info data: Data) throws -> (landscape: [Button]?, portrait: [Button]?) {
        let variant = try packageVariant(data)
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

#if canImport(UIKit)
extension TouchSkinEngine.Skin {
    private static let artImages = NSCache<NSData, UIImage>()

    /// The skin's own art for an orientation, decoded once. Nil for a skin without it.
    func artImage(portrait: Bool) -> UIImage? {
        guard let data = assets[portrait ? "portrait" : "landscape"] else { return nil }
        let key = data as NSData
        if let hit = Self.artImages.object(forKey: key) { return hit }
        guard let image = UIImage(data: data) else { return nil }
        Self.artImages.setObject(image, forKey: key)
        return image
    }
}
#endif
