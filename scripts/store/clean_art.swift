// Cleans the owner-generated store art (AI images) into design/store/source/ and builds the 3:4 Library cover
// tiles used to seed the device capture.
//
//     swift -O scripts/store/clean_art.swift <images-dir> [tiles-dir]
//
// <images-dir> holds the owner's 9.webp ... 26.webp. Each one is mapped below. Cleanup:
// - the generator's sparkle watermark (bottom-right) is lifted by reversing its alpha blend; the alpha map is
//   measured on the flat navy corner of 22.webp and fitted per image (scale and position);
// - the gamepad's coloured, lettered face buttons are repainted plain dark grey;
// - the racing cover's hood badge is painted out;
// - the dual-screen shot is cut to its two screen interiors, with no device bezel;
// - the top-down shot's coloured A/B HUD icons are greyed.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: clean_art.swift <images-dir> [tiles-dir]"); exit(2) }
let src = URL(fileURLWithPath: args[1])
let out = root.appendingPathComponent("design/store/source")
let tilesDir = args.count > 2 ? URL(fileURLWithPath: args[2]) : nil
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

struct Bitmap {
    var w: Int, h: Int, px: [UInt8]   // RGBA, opaque
    init(w: Int, h: Int) { self.w = w; self.h = h; px = [UInt8](repeating: 255, count: w * h * 4) }
    init(cg: CGImage) {
        w = cg.width; h = cg.height; px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
    }
    func get(_ x: Int, _ y: Int, _ c: Int) -> Double { Double(px[(y * w + x) * 4 + c]) }
    mutating func set(_ x: Int, _ y: Int, _ r: Double, _ g: Double, _ b: Double) {
        let i = (y * w + x) * 4
        px[i] = UInt8(max(0, min(255, r.rounded()))); px[i + 1] = UInt8(max(0, min(255, g.rounded())))
        px[i + 2] = UInt8(max(0, min(255, b.rounded()))); px[i + 3] = 255
    }
    var cg: CGImage {
        var copy = px
        return copy.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!
        }
    }
    func crop(_ x: Int, _ y: Int, _ cw: Int, _ ch: Int) -> Bitmap { Bitmap(cg: cg.cropping(to: CGRect(x: x, y: y, width: cw, height: ch))!) }
}

func load(_ n: Int) -> Bitmap {
    let s = CGImageSourceCreateWithURL(src.appendingPathComponent("\(n).webp") as CFURL, nil)!
    return Bitmap(cg: CGImageSourceCreateImageAtIndex(s, 0, nil)!)
}
func save(_ b: Bitmap, _ url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, b.cg, nil)
    precondition(CGImageDestinationFinalize(d), "write failed \(url.path)")
}

// MARK: Watermark

/// Alpha map of the sparkle (white, alpha-blended), measured on 22.webp's flat navy corner.
func measureMask() -> (a: [Double], n: Int) {
    let b = load(22)
    let n = 140, x0 = b.w - n, y0 = b.h - n
    var bg = [0.0, 0.0, 0.0]
    var count = 0.0
    for i in 0..<n { for (x, y) in [(x0 + i, y0), (x0, y0 + i)] { for c in 0..<3 { bg[c] += b.get(x, y, c) }; count += 1 } }
    bg = bg.map { $0 / count }
    var a = [Double](repeating: 0, count: n * n)
    for y in 0..<n { for x in 0..<n {
        var s = 0.0
        for c in 0..<3 { s += (b.get(x0 + x, y0 + y, c) - bg[c]) / (255 - bg[c]) }
        let v = s / 3
        a[y * n + x] = v < 0.03 ? 0 : min(v, 0.95)
    } }
    return (a, n)
}
let mask = measureMask()

/// The mask scaled by `s` with its bottom-right corner at (cx, cy) (subpixel), sampled bilinearly onto image pixels.
struct Placed { let x0: Int, y0: Int, m: Int, a: [Double] }
func place(_ s: Double, _ cx: Double, _ cy: Double) -> Placed {
    let n = mask.n, size = Double(n) * s
    let x0 = Int((cx - size).rounded(.down)) - 1, y0 = Int((cy - size).rounded(.down)) - 1, m = Int(size.rounded(.up)) + 3
    func at(_ x: Int, _ y: Int) -> Double { x < 0 || y < 0 || x >= n || y >= n ? 0 : mask.a[y * n + x] }
    var a = [Double](repeating: 0, count: m * m)
    for gy in 0..<m { for gx in 0..<m {
        let u = (Double(x0 + gx) + 0.5 - cx) / s + Double(n) - 0.5, v = (Double(y0 + gy) + 0.5 - cy) / s + Double(n) - 0.5
        let iu = Int(u.rounded(.down)), iv = Int(v.rounded(.down)), fu = u - Double(iu), fv = v - Double(iv)
        a[gy * m + gx] = (at(iu, iv) * (1 - fu) + at(iu + 1, iv) * fu) * (1 - fv) + (at(iu, iv + 1) * (1 - fu) + at(iu + 1, iv + 1) * fu) * fv
    } }
    return Placed(x0: x0, y0: y0, m: m, a: a)
}

func lum(_ b: Bitmap, _ x: Int, _ y: Int) -> Double { 0.3 * b.get(x, y, 0) + 0.59 * b.get(x, y, 1) + 0.11 * b.get(x, y, 2) }

/// Edge energy of a fixed window after reversing the blend: lowest when the mask is aligned. The window is the same
/// for every candidate, so scales compare fairly.
func score(_ b: Bitmap, _ p: Placed, window: (Int, Int, Int, Int)) -> Double {
    func rev(_ x: Int, _ y: Int) -> Double {
        let gx = x - p.x0, gy = y - p.y0
        let a = gx >= 0 && gy >= 0 && gx < p.m && gy < p.m ? p.a[gy * p.m + gx] : 0
        return (lum(b, x, y) - a * 255) / (1 - a)
    }
    var e = 0.0
    for y in window.1..<window.3 { for x in window.0..<window.2 {
        let v = rev(x, y)
        e += abs(rev(x + 1, y) - v) + abs(rev(x, y + 1) - v)
    } }
    return e
}

/// `hint` (scale, corner x, corner y) for an image whose sparkle is not on the corner rule.
func unwatermark(_ b: inout Bitmap, hint: (Double, Double, Double)? = nil) {
    // The sparkle's box ends on the image corner and scales with the square root of the area (measured on 22.webp,
    // 2000 x 1116); a small search around that settles scale and subpixel position.
    let k = (Double(b.w * b.h) / (2000 * 1116)).squareRoot()
    let start = hint ?? (k, Double(b.w), Double(b.h))
    let reach = hint == nil ? 3.0 : 8.0, sReach = hint == nil ? 0.04 : 0.08
    let big = Double(mask.n) * (start.0 + sReach)
    let window = (max(0, Int(start.1 - big - reach) - 4), max(0, Int(start.2 - big - reach) - 4),
                  min(b.w - 1, Int(start.1 + reach) + 2), min(b.h - 1, Int(start.2 + reach) + 2))
    var best = (s: start.0, x: start.1, y: start.2, e: Double.infinity)
    for si in stride(from: start.0 - sReach, through: start.0 + sReach, by: 0.01) {
        for cy in stride(from: start.2 - reach, through: start.2 + reach, by: 1) { for cx in stride(from: start.1 - reach, through: start.1 + reach, by: 1) {
            let e = score(b, place(si, cx, cy), window: window)
            if e < best.e { best = (si, cx, cy, e) }
        } }
    }
    let whole = best
    for si in stride(from: whole.s - 0.01, through: whole.s + 0.01, by: 0.0025) {
        for cy in stride(from: whole.y - 0.75, through: whole.y + 0.75, by: 0.25) { for cx in stride(from: whole.x - 0.75, through: whole.x + 0.75, by: 0.25) {
            let e = score(b, place(si, cx, cy), window: window)
            if e < best.e { best = (si, cx, cy, e) }
        } }
    }
    let p = place(best.s, best.x, best.y)
    for gy in 0..<p.m { for gx in 0..<p.m {
        let a = p.a[gy * p.m + gx], x = p.x0 + gx, y = p.y0 + gy
        guard a > 0, x >= 0, y >= 0, x < b.w, y < b.h else { continue }
        b.set(x, y, (b.get(x, y, 0) - a * 255) / (1 - a), (b.get(x, y, 1) - a * 255) / (1 - a), (b.get(x, y, 2) - a * 255) / (1 - a))
    } }
    // A resized sparkle leaves a hairline at its edge: a 5 x 5 median over the edge band clears it.
    if abs(best.s - 1) > 0.02 {
        let src = b
        for gy in 1..<p.m - 1 { for gx in 1..<p.m - 1 {
            let a = p.a[gy * p.m + gx], x = p.x0 + gx, y = p.y0 + gy
            let edge = abs(p.a[gy * p.m + gx + 1] - p.a[gy * p.m + gx - 1]) + abs(p.a[(gy + 1) * p.m + gx] - p.a[(gy - 1) * p.m + gx])
            guard a > 0 || edge > 0, edge > 0.04, x >= 2, y >= 2, x < b.w - 2, y < b.h - 2 else { continue }
            var ch = [[Double]](repeating: [], count: 3)
            for yy in y - 2...y + 2 { for xx in x - 2...x + 2 { for c in 0..<3 { ch[c].append(src.get(xx, yy, c)) } } }
            let med = ch.map { $0.sorted()[12] }
            b.set(x, y, med[0], med[1], med[2])
        } }
    }
    print("  sparkle scale \(String(format: "%.3f", best.s)) corner \(best.x),\(best.y)")
}

// MARK: Paint helpers

/// Fills an ellipse with the average colour of the ring just outside it, feathered at the edge.
func paintOut(_ b: inout Bitmap, cx: Double, cy: Double, r: Double) {
    var sum = [0.0, 0.0, 0.0], n = 0.0
    for t in stride(from: 0.0, to: 2 * Double.pi, by: 0.05) {
        let x = Int(cx + cos(t) * r * 1.3), y = Int(cy + sin(t) * r * 1.3)
        for c in 0..<3 { sum[c] += b.get(x, y, c) }; n += 1
    }
    for y in Int(cy - r)...Int(cy + r) { for x in Int(cx - r)...Int(cx + r) {
        let d = hypot(Double(x) - cx, Double(y) - cy) / r
        guard d < 1 else { continue }
        let f = min(1, (1 - d) * 4)
        b.set(x, y, b.get(x, y, 0) * (1 - f) + sum[0] / n * f, b.get(x, y, 1) * (1 - f) + sum[1] / n * f, b.get(x, y, 2) * (1 - f) + sum[2] / n * f)
    } }
}

/// A plain dark grey cap over a face button: no letter, no colour, shaded top-light like the rest of the pad.
func plainButton(_ b: inout Bitmap, cx: Double, cy: Double, rx: Double, ry: Double) {
    for y in Int(cy - ry - 2)...Int(cy + ry + 2) { for x in Int(cx - rx - 2)...Int(cx + rx + 2) {
        let nx = (Double(x) - cx) / rx, ny = (Double(y) - cy) / ry
        let d = sqrt(nx * nx + ny * ny)
        guard d < 1.04 else { continue }
        // Top-left light, darker rim, soft specular.
        var v = 62 - 22 * ny - 8 * nx
        if d > 0.86 { v -= (d - 0.86) * 160 }
        let spec = max(0, 1 - hypot(nx + 0.35, ny + 0.45) / 0.35)
        v += spec * 55
        let f = d < 1 ? 1 : max(0, (1.04 - d) / 0.04)
        b.set(x, y, b.get(x, y, 0) * (1 - f) + v * f, b.get(x, y, 1) * (1 - f) + v * f, b.get(x, y, 2) * (1 - f) + (v + 3) * f)
    } }
}

/// Copies the square from `fromDY` rows away over (x, y), feathered over its outer 10 pixels.
func clone(_ b: inout Bitmap, x: Int, y: Int, size: Int, fromDY: Int) {
    let src = b
    for yy in 0..<size { for xx in 0..<size {
        let edge = Double(min(xx, yy, size - 1 - xx, size - 1 - yy))
        let f = min(1, edge / 10)
        let px = x + xx, py = y + yy
        let v = (0..<3).map { src.get(px, py, $0) * (1 - f) + src.get(px, py + fromDY, $0) * f }
        b.set(px, py, v[0], v[1], v[2])
    } }
}

/// Greys a circle: keeps light and shade, drops the hue.
func grey(_ b: inout Bitmap, cx: Int, cy: Int, r: Int) {
    for y in cy - r...cy + r { for x in cx - r...cx + r where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r {
        let l = lum(b, x, y)
        b.set(x, y, l, l, l)
    } }
}

// MARK: Map

func clean(_ n: Int, _ name: String, _ edit: (inout Bitmap) -> Void = { _ in }) -> Bitmap {
    print("\(n).webp -> \(name)")
    var b = load(n)
    // 10 is on white: the sparkle cannot show there. 24 (1376 x 768) has a fainter one further in: it is covered
    // with the starfield just below it.
    if n == 24 { clone(&b, x: 1222, y: 614, size: 60, fromDY: 66) } else if n != 10 { unwatermark(&b) }
    edit(&b)
    save(b, out.appendingPathComponent(name))
    return b
}

_ = clean(9, "background.png")
_ = clean(10, "gamepad.png") { b in
    // Measured on the 2000 x 1493 source: Y top, X left, B right, A bottom. The cluster is greyed first, so the
    // coloured skirts under the caps go too.
    for (x, y) in [(120, 62), (65, 155), (208, 155), (165, 242)] { grey(&b, cx: 1250 + x, cy: 265 + y + 8, r: 60) }
    plainButton(&b, cx: 1250 + 120, cy: 265 + 62, rx: 40, ry: 37)
    plainButton(&b, cx: 1250 + 65, cy: 265 + 155, rx: 42, ry: 39)
    plainButton(&b, cx: 1250 + 208, cy: 265 + 155, rx: 36, ry: 38)
    plainButton(&b, cx: 1250 + 165, cy: 265 + 242, rx: 40, ry: 38)
}
_ = clean(11, "game-shooter.png")
_ = clean(12, "game-3d.png")
let dual = clean(13, "game-dual-full.png")
save(dual.crop(223, 103, 1044, 804), out.appendingPathComponent("game-dual-top.png"))
save(dual.crop(223, 1133, 1044, 779), out.appendingPathComponent("game-dual-bottom.png"))
try? FileManager.default.removeItem(at: out.appendingPathComponent("game-dual-full.png"))
_ = clean(14, "game-handheld.png") { b in grey(&b, cx: 1712, cy: 290, r: 30); grey(&b, cx: 1890, cy: 290, r: 30) }
_ = clean(15, "game-16bit.png")
_ = clean(16, "game-8bit.png")

// Covers, in the Library's title order, with the title box (x0, y0, x1, y1) and the art's focus x, in source pixels.
let covers: [(n: Int, title: (Int, Int, Int, Int), focus: Int)] = [
    (26, (0, 0, 2000, 300), 970),      // TINY JUMP QUEST
    (25, (60, 20, 1940, 260), 1030),    // CHRONICLES OF ELDON
    (24, (40, 45, 800, 310), 900),      // NEON STARFIRE (1376 x 768)
    (23, (280, 60, 1720, 310), 1030),   // TURBO DASH
    (22, (300, 60, 1700, 220), 1000),   // CEREBRAL GRID
    (21, (40, 20, 1960, 330), 1000),    // ARENA OF RAGE
    (20, (40, 30, 1960, 270), 940),     // SHADOW OF ASHES
    (19, (570, 40, 1450, 400), 1000),   // SPROUT'S BIG JOURNEY
    (18, (40, 40, 1960, 320), 700),     // RED PLANET OUTPOST
    (17, (20, 50, 1980, 300), 880),     // WHISPERS IN THE DARK
]
var cleanedCovers: [Bitmap] = []
for (i, c) in covers.enumerated() {
    let b = clean(c.n, String(format: "cover-%02d.png", i + 1)) { b in
        if c.n == 23 { paintOut(&b, cx: 500, cy: 783, r: 15) }   // hood badge
    }
    cleanedCovers.append(b)
}

// MARK: 3:4 tiles

/// The Library draws covers 3:4 (scaled to fill), so a 16:9 cover would lose its title. Each tile is the title band
/// over the art below it, centred on the focus, blended at the seam.
if let tilesDir {
    try FileManager.default.createDirectory(at: tilesDir, withIntermediateDirectories: true)
    let W = 900, H = 1200
    for (i, c) in covers.enumerated() {
        let b = cleanedCovers[i]
        let tw = c.title.2 - c.title.0, th = c.title.3 - c.title.1
        let bandH = Int(Double(th) * Double(W) / Double(tw))
        let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
        // Art: below the title band, filling the tile height under it plus the blend overlap.
        let artTop = c.title.3 - Int(Double(th) * 0.15)
        let artH = b.h - artTop
        let artDestH = H - bandH + Int(Double(bandH) * 0.25)
        let artW = Int(Double(artH) * Double(W) / Double(artDestH))
        let ax = max(0, min(b.w - artW, c.focus - artW / 2))
        ctx.draw(b.cg.cropping(to: CGRect(x: ax, y: artTop, width: min(artW, b.w), height: artH))!,
                 in: CGRect(x: 0, y: 0, width: W, height: artDestH))
        // Title band, its lower quarter faded into the art.
        let band = b.cg.cropping(to: CGRect(x: c.title.0, y: c.title.1, width: tw, height: th))!
        let fade = CGContext(data: nil, width: W, height: bandH, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        fade.interpolationQuality = .high
        fade.draw(band, in: CGRect(x: 0, y: 0, width: W, height: bandH))
        let gray = CGContext(data: nil, width: W, height: bandH, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                             bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray, locations: [0, 1])!
        gray.setFillColor(CGColor(gray: 1, alpha: 1)); gray.fill(CGRect(x: 0, y: 0, width: W, height: bandH))
        gray.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: Double(bandH) * 0.25), options: [.drawsAfterEndLocation])
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: H - bandH, width: W, height: bandH), mask: gray.makeImage()!)
        ctx.draw(fade.makeImage()!, in: CGRect(x: 0, y: H - bandH, width: W, height: bandH))
        ctx.restoreGState()
        var tile = Bitmap(cg: ctx.makeImage()!)
        tile.w = W
        save(tile, tilesDir.appendingPathComponent(String(format: "cover-%02d.png", i + 1)))
    }
    print("tiles -> \(tilesDir.path)")
}
