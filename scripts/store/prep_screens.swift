// Turns the device captures of UITests testStoreShots into the screens the store render puts in its frames.
//
//     swift -O scripts/store/prep_screens.swift <captures-dir> [library-dy]
//
// [library-dy] moves the Library's two painted areas up or down, in pixels: the iPhone 17 simulator draws that page
// 36 px higher than the device (-36). Default 0, the device.
//
// <captures-dir> holds the walk's shots as 01.png ... 16.png (the number after "STORE"). Writes
// design/store/screens/*.png. Each screen is the real capture with only these changes:
// - the status bar is redrawn clean (9:41, no carrier or live activity);
// - system names the test ROM's system brings in (a filter chip, a details line, a cheat format list, a skin's
//   system line) are painted over with the background beside them;
// - the test ROM's colour bars are replaced with the owner's gameplay art (design/store/source). In landscape the
//   touch controls drawn over the game are kept: each pixel is unmixed from the bars' colours and laid over the art.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
guard (2...3).contains(CommandLine.arguments.count) else { print("usage: prep_screens.swift <captures-dir> [library-dy]"); exit(2) }
let libraryDY = CommandLine.arguments.count == 3 ? Int(CommandLine.arguments[2])! : 0
let caps = URL(fileURLWithPath: CommandLine.arguments[1])
let art = root.appendingPathComponent("design/store/source")
let out = root.appendingPathComponent("design/store/screens")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

struct Bitmap {
    var w: Int, h: Int, px: [UInt8]
    init(cg: CGImage, w: Int? = nil, h: Int? = nil) {
        self.w = w ?? cg.width; self.h = h ?? cg.height
        px = [UInt8](repeating: 0, count: self.w * self.h * 4)
        let (W, H) = (self.w, self.h)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: srgb,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
        }
    }
    subscript(x: Int, y: Int) -> (Double, Double, Double) {
        get { let i = (y * w + x) * 4; return (Double(px[i]), Double(px[i + 1]), Double(px[i + 2])) }
        set {
            let i = (y * w + x) * 4
            px[i] = UInt8(max(0, min(255, newValue.0.rounded()))); px[i + 1] = UInt8(max(0, min(255, newValue.1.rounded())))
            px[i + 2] = UInt8(max(0, min(255, newValue.2.rounded()))); px[i + 3] = 255
        }
    }
    var cg: CGImage {
        var copy = px
        let (W, H) = (w, h)
        return copy.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!
        }
    }
    /// Draws with CoreGraphics on top (origin bottom-left, as CoreGraphics has it).
    mutating func draw(_ body: (CGContext) -> Void) {
        let (W, H) = (w, h)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: srgb,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            body(ctx)
        }
    }
}

func load(_ url: URL) -> Bitmap {
    let s = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return Bitmap(cg: CGImageSourceCreateImageAtIndex(s, 0, nil)!)
}
func save(_ b: Bitmap, _ name: String) {
    let d = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, b.cg, nil)
    precondition(CGImageDestinationFinalize(d))
    print("screens/\(name)")
}
func cap(_ n: Int) -> Bitmap { load(caps.appendingPathComponent(String(format: "%02d.png", n))) }

/// Paints a rectangle (top-left origin) with the colour at (sx, sy).
func cover(_ b: inout Bitmap, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, sample: (Int, Int)) {
    let c = b[sample.0, sample.1]
    for y in y0..<y1 { for x in x0..<x1 { b[x, y] = c } }
}

/// A clean status bar: 9:41, full signal and battery, a plain Dynamic Island.
func statusBar(_ b: inout Bitmap) {
    cover(&b, 0, 0, b.w, 172, sample: (6, 6))
    let H = Double(b.h), cx = Double(b.w) / 2
    b.draw { ctx in
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.addPath(CGPath(roundedRect: CGRect(x: cx - 187, y: H - 38 - 111, width: 374, height: 111), cornerWidth: 55.5, cornerHeight: 55.5, transform: nil))
        ctx.fillPath()
        let white = CGColor(gray: 1, alpha: 1)
        ctx.setFillColor(white)
        // Signal: four bars.
        for i in 0..<4 {
            let bh = 14.0 + Double(i) * 8
            ctx.addPath(CGPath(roundedRect: CGRect(x: 893 + Double(i) * 15, y: H - 116, width: 10, height: bh), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
        }
        ctx.fillPath()
        // Battery: outline, full fill, cap.
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.45)); ctx.setLineWidth(3)
        ctx.addPath(CGPath(roundedRect: CGRect(x: 968, y: H - 120, width: 76, height: 38), cornerWidth: 11, cornerHeight: 11, transform: nil))
        ctx.strokePath()
        ctx.addPath(CGPath(roundedRect: CGRect(x: 973, y: H - 115, width: 66, height: 28), cornerWidth: 7, cornerHeight: 7, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.45))
        ctx.addPath(CGPath(roundedRect: CGRect(x: 1047, y: H - 108, width: 5, height: 14), cornerWidth: 2, cornerHeight: 2, transform: nil))
        ctx.fillPath()
        // Time.
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
        let text = NSAttributedString(string: "9:41", attributes: [.font: NSFont.systemFont(ofSize: 51, weight: .semibold), .foregroundColor: NSColor.white])
        let size = text.size()
        text.draw(at: NSPoint(x: 178 - size.width / 2, y: H - 93 - size.height / 2))
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// The test ROM's bars inside `rect` (x0, y0, x1, y1), found by their pure colours.
func barsRect(_ b: Bitmap, within r: (Int, Int, Int, Int)) -> (Int, Int, Int, Int) {
    var x0 = Int.max, y0 = Int.max, x1 = 0, y1 = 0
    for y in r.1..<r.3 { for x in r.0..<r.2 {
        let (R, G, B) = b[x, y]
        let pure = (R > 230 && G < 40 && B < 40) || (G > 230 && R < 40 && B < 40) || (B > 230 && R < 40 && G < 40) || (R > 230 && G > 230 && B < 160 && B > 100)
        if pure { x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y) }
    } }
    return (x0, y0, x1 + 1, y1 + 1)
}

/// The art scaled to fill the rect, centred, as a bitmap of the rect's size. `stretch` fits it whole instead, as the
/// app's Stretch screen setting would, so a 16:9 picture keeps its HUD on a 3:2 screen.
func fill(_ name: String, _ w: Int, _ h: Int, stretch: Bool = false) -> Bitmap {
    let s = CGImageSourceCreateWithURL(art.appendingPathComponent(name) as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    if stretch { return Bitmap(cg: img, w: w, h: h) }
    let scale = max(Double(w) / Double(img.width), Double(h) / Double(img.height))
    let cw = Int(Double(w) / scale), ch = Int(Double(h) / scale)
    return Bitmap(cg: img.cropping(to: CGRect(x: (img.width - cw) / 2, y: (img.height - ch) / 2, width: cw, height: ch))!, w: w, h: h)
}

/// Puts the art over the bars. With `unmix`, a light overlay (touch controls) drawn over the bars is kept: each pixel is
/// the nearest bar colour mixed with the overlay colour, and that mix is laid over the art instead.
func game(_ b: inout Bitmap, _ r: (Int, Int, Int, Int), _ name: String, unmix: Bool) {
    let a = fill(name, r.2 - r.0, r.3 - r.1, stretch: unmix)
    let palette: [(Double, Double, Double)] = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 128), (0, 0, 0)]
    let ink = (237.0, 230.0, 216.0)   // AppTheme onLetterbox, the touch controls' colour
    for y in r.1..<r.3 { for x in r.0..<r.2 {
        let artPx = a[x - r.0, y - r.1]
        guard unmix else { b[x, y] = artPx; continue }
        let c = b[x, y]
        var best = (alpha: 0.0, err: Double.infinity)
        for p in palette {
            // Least squares alpha for c = p + alpha (ink - p).
            let d = (ink.0 - p.0, ink.1 - p.1, ink.2 - p.2), e = (c.0 - p.0, c.1 - p.1, c.2 - p.2)
            let al = max(0, min(1, (d.0 * e.0 + d.1 * e.1 + d.2 * e.2) / (d.0 * d.0 + d.1 * d.1 + d.2 * d.2)))
            let err = pow(e.0 - al * d.0, 2) + pow(e.1 - al * d.1, 2) + pow(e.2 - al * d.2, 2)
            if err < best.err { best = (al, err) }
        }
        let al = best.alpha < 0.04 ? 0 : best.alpha
        b[x, y] = (artPx.0 * (1 - al) + ink.0 * al, artPx.1 * (1 - al) + ink.1 * al, artPx.2 * (1 - al) + ink.2 * al)
    } }
}

/// The capture turned upright for a landscape-left shot (the screenshot keeps the portrait buffer).
func upright(_ b: Bitmap) -> Bitmap {
    let img = b.cg
    let W = b.h, H = b.w
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x: CGFloat(W), y: 0)
    ctx.rotate(by: .pi / 2)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: b.w, height: b.h))
    return Bitmap(cg: ctx.makeImage()!)
}

// Library: no system chip, no details line on the Continue card.
var library = cap(1)
statusBar(&library)
cover(&library, 330, 428 + libraryDY, 530, 482 + libraryDY, sample: (322, 455 + libraryDY))
cover(&library, 374, 716 + libraryDY, 524, 826 + libraryDY, sample: (364, 700 + libraryDY))
save(library, "library.png")

// Playing upright: the touch controls below the game.
var play = cap(4)
game(&play, barsRect(play, within: (0, 0, play.w, play.h / 2)), "game-16bit.png", unmix: false)
save(play, "play-portrait.png")

// Playing in landscape, the controls over the game, twice: the hero shot and the controller shot.
let land = upright(cap(5))
let landBars = barsRect(land, within: (0, 0, land.w, land.h))
for (artName, name) in [("game-shooter.png", "play-landscape.png"), ("game-3d.png", "play-landscape-3d.png")] {
    var b = land
    game(&b, landBars, artName, unmix: true)
    save(b, name)
}

// Filter: the large preview shows the art; the small previews keep the test bars.
var filter = cap(8)
statusBar(&filter)
game(&filter, barsRect(filter, within: (0, 180, filter.w, 1100)), "game-handheld.png", unmix: false)
save(filter, "filter.png")

var saves = cap(7)
save(saves, "saves.png")

var cheats = cap(9)
cover(&cheats, 50, 912, 1156, 980, sample: (40, 945))
save(cheats, "cheats.png")

var skin = cap(10)
cover(&skin, 130, 506, 510, 564, sample: (120, 535))
save(skin, "skin.png")

for (n, name) in [(14, "controllers.png"), (15, "sync.png")] {
    var b = cap(n)
    statusBar(&b)
    save(b, name)
}
