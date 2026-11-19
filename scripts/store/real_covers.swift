// Cuts the real box art used, small, on the store shelves into design/store/source/covers-real/cover-01..16.png
// (600 x 800, the Library's 3:4) and the cover grids' cover-17..74.png (600 wide, each box's own shape).
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
    // Lesser-known titles only: no big franchises or console makers' mascots on the store pages.
    ("01", (0.36, 0.00, 1.00, 0.84)),   // Game Boy Advance
    ("02", (0.00, 0.06, 0.45, 0.76)),   // Super NES
    ("03", (0.00, 0.045, 1.00, 0.86)),  // NES
    ("04", (0.18, 0.09, 1.00, 0.87)),   // Mega Drive
    ("05", (0.15, 0.00, 1.00, 0.93)),   // PlayStation
    ("06", (0.00, 0.00, 0.62, 0.86)),   // Nintendo 64
    ("07", (0.22, 0.00, 1.00, 0.68)),   // Game Boy Color
    ("08", (0.00, 0.00, 0.75, 0.85)),   // PC Engine
    ("09", (0.15, 0.00, 1.00, 0.80)),   // Dreamcast
    ("10", (0.21, 0.12, 1.00, 0.80)),   // Game Boy
    // 11-16 seed the Library capture's 3DS, PSP and DS shelves.
    ("11", (0.10, 0.00, 0.88, 0.80)),   // Nintendo 3DS
    ("12", (0.00, 0.00, 0.88, 0.93)),   // Nintendo 3DS
    ("13", (0.00, 0.04, 1.00, 0.88)),   // PSP
    ("14", (0.00, 0.04, 1.00, 0.86)),   // PSP
    ("15", (0.16, 0.00, 1.00, 0.78)),   // Nintendo DS
    ("16", (0.16, 0.18, 0.95, 0.92)),   // Nintendo DS
]

// 17-74 fill the cover grids (store.html GRIDS: shots 1-2, header, search), each system's box kept at its own
// cropped shape, 600 wide. Crops drop the system band, rating box and publisher marks.
let grids: [(files: ClosedRange<Int>, crop: (Double, Double, Double, Double))] = [
    (17...26, (0.135, 0.00, 1.00, 0.84)),   // Nintendo DS
    // 35, 54, 70 and 74 were cut: no crop cleared their console-maker marks.
    (27...34, (0.00, 0.10, 1.00, 0.84)),    // PSP
    (36...36, (0.00, 0.10, 1.00, 0.84)),    // PSP
    (37...46, (0.17, 0.00, 1.00, 0.74)),    // Game Boy Advance
    (47...53, (0.12, 0.00, 1.00, 0.84)),    // PlayStation
    (55...64, (0.00, 0.00, 0.82, 0.90)),    // Nintendo 64
    (65...69, (0.00, 0.03, 0.82, 0.76)),    // Super NES
    (71...73, (0.00, 0.03, 0.82, 0.76)),    // Super NES
    // More for the wider iPad rows.
    (75...79, (0.00, 0.10, 1.00, 0.84)),    // PSP
    (80...82, (0.17, 0.00, 1.00, 0.74)),    // Game Boy Advance
    (83...91, (0.12, 0.00, 1.00, 0.84)),    // PlayStation
]
let jobs = covers.enumerated().map { (n: $0.offset + 1, file: $0.element.file, crop: $0.element.crop, keep: false) }
    + grids.flatMap { g in g.files.map { (n: $0, file: String($0), crop: g.crop, keep: true) } }

for c in jobs {
    let path = src.appendingPathComponent("\(c.file).png")
    // The boxarts folder may hold only some of the sources: the rest keep their committed covers.
    guard FileManager.default.fileExists(atPath: path.path) else { continue }
    let s = CGImageSourceCreateWithURL(path as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    let (w, h) = (Double(img.width), Double(img.height))
    var r = CGRect(x: c.crop.0 * w, y: c.crop.1 * h, width: (c.crop.2 - c.crop.0) * w, height: (c.crop.3 - c.crop.1) * h)
    // Trim the crop to 3:4 about its centre, so nothing is stretched (grid covers keep their shape).
    if !c.keep {
        if r.width / r.height > 0.75 { r = r.insetBy(dx: (r.width - r.height * 0.75) / 2, dy: 0) }
        else { r = r.insetBy(dx: 0, dy: (r.height - r.width / 0.75) / 2) }
    }
    let W = 600, H = c.keep ? Int((600 * r.height / r.width).rounded()) : 800
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img.cropping(to: r.integral)!, in: CGRect(x: 0, y: 0, width: W, height: H))
    let url = out.appendingPathComponent(String(format: "cover-%02d.png", c.n))
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(d), "write failed \(url.path)")
}
print("\(jobs.count) covers -> \(out.path)")
