// Builds 3:4 covers (600 x 800, the Library's shape) for the store shelves from our own invented covers in
// design/store/source/cover-01..10.png (scripts/store/clean_art.swift), into design/store/source/covers-invented.
// Same cut as clean_art.swift's seed tiles: the title band over the art below it, centred on the focus, blended at
// the seam. Needs only the cleaned covers in the repo, not the owner's source images.
//
//     swift scripts/store/invented_covers.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let src = root.appendingPathComponent("design/store/source")
let out = src.appendingPathComponent("covers-invented")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

// Title box (x0, y0, x1, y1) and the art's focus x, in pixels of each cleaned cover; as clean_art.swift.
let covers: [(title: (Int, Int, Int, Int), focus: Int)] = [
    ((0, 0, 2000, 300), 970), ((60, 20, 1940, 260), 1030), ((40, 45, 800, 310), 900), ((280, 60, 1720, 310), 1030),
    ((300, 60, 1700, 220), 1000), ((40, 20, 1960, 330), 1000), ((40, 30, 1960, 270), 940), ((570, 40, 1450, 400), 1000),
    ((40, 40, 1960, 320), 700), ((20, 50, 1980, 300), 880),
]

let W = 600, H = 800
for (i, c) in covers.enumerated() {
    let name = String(format: "cover-%02d.png", i + 1)
    let s = CGImageSourceCreateWithURL(src.appendingPathComponent(name) as CFURL, nil)!
    let b = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    let tw = c.title.2 - c.title.0, th = c.title.3 - c.title.1
    let bandH = Int(Double(th) * Double(W) / Double(tw))
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    // Art: below the title band, filling the tile height under it plus the blend overlap.
    let artTop = c.title.3 - Int(Double(th) * 0.15)
    let artH = b.height - artTop
    let artDestH = H - bandH + Int(Double(bandH) * 0.25)
    let artW = Int(Double(artH) * Double(W) / Double(artDestH))
    let ax = max(0, min(b.width - artW, c.focus - artW / 2))
    ctx.draw(b.cropping(to: CGRect(x: ax, y: artTop, width: min(artW, b.width), height: artH))!,
             in: CGRect(x: 0, y: 0, width: W, height: artDestH))
    // Title band, its lower quarter faded into the art.
    let band = b.cropping(to: CGRect(x: c.title.0, y: c.title.1, width: tw, height: th))!
    let gray = CGContext(data: nil, width: W, height: bandH, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                         bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    gray.setFillColor(CGColor(gray: 1, alpha: 1)); gray.fill(CGRect(x: 0, y: 0, width: W, height: bandH))
    gray.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: Double(bandH) * 0.25), options: [.drawsAfterEndLocation])
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: H - bandH, width: W, height: bandH), mask: gray.makeImage()!)
    ctx.draw(band, in: CGRect(x: 0, y: H - bandH, width: W, height: bandH))
    ctx.restoreGState()
    let url = out.appendingPathComponent(name)
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(d), "write failed \(url.path)")
}
print("\(covers.count) covers -> \(out.path)")
