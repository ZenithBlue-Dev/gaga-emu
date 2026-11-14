// Cuts the real box art used, small, on the store shelves into design/store/source/covers-real/cover-01..10.png
// (600 x 800, the Library's 3:4).
//
//     swift scripts/store/real_covers.swift <boxarts-dir>
//
// <boxarts-dir> holds Named_Boxarts PNGs from the libretro-thumbnails project (thumbnails.libretro.com), the same
// source the app's Cover Art uses, saved as 01.png ... by the fetch list kept with the owner. Box art only: no ROMs.
// Each crop drops the platform band, console-maker logos and rating marks, keeping the game's own art and title.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
guard CommandLine.arguments.count == 2 else { print("usage: real_covers.swift <boxarts-dir>"); exit(2) }
let src = URL(fileURLWithPath: CommandLine.arguments[1])
let out = root.appendingPathComponent("design/store/source/covers-real")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// Source file and crop (x0, y0, x1, y1) as fractions of the box art, top-left origin.
let covers: [(file: String, crop: (Double, Double, Double, Double))] = [
    ("01", (0.19, 0.00, 0.83, 0.82)),   // Game Boy Advance
    ("02", (0.00, 0.00, 0.45, 0.80)),   // Super NES
    ("03", (0.04, 0.00, 0.96, 0.84)),   // NES
    ("04", (0.10, 0.09, 0.90, 0.86)),   // Mega Drive
    ("05", (0.16, 0.00, 0.88, 1.00)),   // PlayStation
    ("06", (0.05, 0.02, 0.55, 0.98)),   // Nintendo 64
    ("07", (0.21, 0.00, 0.84, 0.76)),   // Game Boy Color
    ("08", (0.12, 0.00, 0.79, 0.90)),   // PC Engine
    ("11", (0.12, 0.00, 0.85, 0.95)),   // Dreamcast
    ("13", (0.19, 0.00, 0.78, 0.78)),   // Game Boy
]

let W = 600, H = 800
for (i, c) in covers.enumerated() {
    let s = CGImageSourceCreateWithURL(src.appendingPathComponent("\(c.file).png") as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    let (w, h) = (Double(img.width), Double(img.height))
    var r = CGRect(x: c.crop.0 * w, y: c.crop.1 * h, width: (c.crop.2 - c.crop.0) * w, height: (c.crop.3 - c.crop.1) * h)
    // Trim the crop to 3:4 about its centre, so nothing is stretched.
    if r.width / r.height > 0.75 { r = r.insetBy(dx: (r.width - r.height * 0.75) / 2, dy: 0) }
    else { r = r.insetBy(dx: 0, dy: (r.height - r.width / 0.75) / 2) }
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img.cropping(to: r.integral)!, in: CGRect(x: 0, y: 0, width: W, height: H))
    let url = out.appendingPathComponent(String(format: "cover-%02d.png", i + 1))
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(d), "write failed \(url.path)")
}
print("\(covers.count) covers -> \(out.path)")
