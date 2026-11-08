// Composes landscape App Store screenshots in GagaEmu's Paper and Ink brand (docs/BRAND.md, docs/DESIGN.md).
//
//     swift scripts/make_screenshots.swift [--out build/store]   compose the store set
//     swift scripts/make_screenshots.swift --placeholders         redraw design/store/placeholders/
//
// Input: design/store/captions.json lists each shot's capture file and caption. The capture is read from
// design/store/captures/ (real device captures, gitignored) and falls back to design/store/placeholders/.
// Output: <out>/<folder>/NN.png per display class, RGB with no alpha, as App Store Connect requires.
//
// Sizes: Apple, "Screenshot specifications", App Store Connect Help, read 2026-11-08:
// https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
// iPhone with Dynamic Island (large display), 2868 x 1320 landscape, and (medium display), 2622 x 1206
// landscape. Apple lists the medium class as the required one. iPad 13-inch display (required because the app runs
// on iPad), 2752 x 2064 landscape (2732 x 2048 is also accepted), read 2026-11-08 on the same page.
// The folders match scripts/appstore_metadata.py.
//
// Placeholders draw this app's own screens from its tokens and labels, with the picture of the repo's homebrew
// GBATestROM (Sources/Debug/GBATestROM.swift). Replace them with real captures before release.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let store = root.appendingPathComponent("design/store")
let classes = [(folder: "iphone-6.9", w: 2868, h: 1320), (folder: "iphone-6.3", w: 2622, h: 1206),
               (folder: "ipad-13", w: 2752, h: 2064)]

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}
// Light tokens from Sources/App/AppTheme.swift (docs/DESIGN.md).
let paper = hex(0xF4EFE6), surface = hex(0xFBF8F2), ink = hex(0x1C1A17), muted = hex(0x6B655B), rule = hex(0xD9D1C2)
let accent = hex(0xBF3D18), accentFill = hex(0xE4572E), onAccent = hex(0x1C1A17), letterbox = hex(0x1C1A17), onLetterbox = hex(0xEDE6D8)

func serif(_ size: CGFloat, _ weight: NSFont.Weight = .semibold) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.serif)!, size: size)!
}
func sans(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont { .systemFont(ofSize: size, weight: weight) }
func mono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont { .monospacedSystemFont(ofSize: size, weight: weight) }

/// Draws into an opaque sRGB bitmap with a top-left origin, in points of `scale` pixels, and returns the image.
func render(_ w: Int, _ h: Int, scale: CGFloat = 1, _ draw: () -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.interpolationQuality = .high
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    draw()
    NSGraphicsContext.current = nil
    return ctx.makeImage()!
}

func save(_ image: CGImage, _ url: URL) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest), "could not write \(url.path)")
}

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func fill(_ r: CGRect, _ c: NSColor, corner: CGFloat = 0) {
    c.setFill()
    NSBezierPath(roundedRect: r, xRadius: corner, yRadius: corner).fill()
}
func stroke(_ r: CGRect, _ c: NSColor, corner: CGFloat = 0, width: CGFloat = 1) {
    c.setStroke()
    let p = NSBezierPath(roundedRect: r.insetBy(dx: width / 2, dy: width / 2), xRadius: corner, yRadius: corner)
    p.lineWidth = width
    p.stroke()
}
@discardableResult
func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ font: NSFont, _ c: NSColor, width: CGFloat? = nil,
          center: Bool = false) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.alignment = center ? .center : .left
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: c, .paragraphStyle: style]
    let s = s as NSString
    let box = s.boundingRect(with: NSSize(width: width ?? 10_000, height: 10_000),
                             options: [.usesLineFragmentOrigin], attributes: attributes)
    s.draw(with: CGRect(x: x, y: y, width: width ?? ceil(box.width), height: ceil(box.height)),
           options: [.usesLineFragmentOrigin], attributes: attributes)
    return ceil(box.height)
}
func symbol(_ name: String, _ r: CGRect, _ c: NSColor, weight: NSFont.Weight = .regular) {
    let config = NSImage.SymbolConfiguration(pointSize: r.height, weight: weight).applying(.init(paletteColors: [c]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    else { return }
    let s = image.size, k = min(r.width / s.width, r.height / s.height)
    let fit = CGRect(x: r.midX - s.width * k / 2, y: r.midY - s.height * k / 2, width: s.width * k, height: s.height * k)
    image.draw(in: fit, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}
func hline(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) { fill(CGRect(x: x, y: y, width: w, height: 1), rule) }
func vline(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat) { fill(CGRect(x: x, y: y, width: 1, height: h), rule) }

// MARK: Placeholders: this app's screens on an iPhone 17 Pro Max (956 x 440 pt at 3x), light appearance.

let pw: CGFloat = 956, ph: CGFloat = 440, safe: CGFloat = 59, home: CGFloat = 21

/// The repo's homebrew GBA test picture: four 40-row bands (`GBATestROM.bandColors`, BGR555) and the key cells,
/// white while held. `held` is the KEYINPUT bit index (0 is A).
func gbaPicture(_ r: CGRect, held: Int? = 0) {
    let bands: [UInt16] = [0x001F, 0x03E0, 0x7C00, 0x3FFF]
    let k = r.width / 240
    for (i, v) in bands.enumerated() {
        let c = NSColor(srgbRed: CGFloat(v & 31) / 31, green: CGFloat(v >> 5 & 31) / 31, blue: CGFloat(v >> 10 & 31) / 31, alpha: 1)
        fill(CGRect(x: r.minX, y: r.minY + CGFloat(i * 40) * k, width: r.width, height: 40 * k), c)
    }
    for cell in -1..<10 {  // -1 is the toggle cell at x 0.
        let x = cell < 0 ? 0 : 40 + cell * 16
        fill(CGRect(x: r.minX + CGFloat(x) * k, y: r.minY + 8 * k, width: 16 * k, height: 8 * k), cell == held ? .white : .black)
    }
}

func rail(selected: Int) {
    fill(CGRect(x: 0, y: 0, width: safe + 72, height: ph), surface)
    vline(safe + 72, 0, ph)
    for (i, item) in [("Library", "books.vertical"), ("Add", "plus"), ("Settings", "gearshape")].enumerated() {
        let y = 16 + CGFloat(i) * 64, on = i == selected, c = on ? accent : muted
        if on { fill(CGRect(x: safe, y: y + 12, width: 3, height: 40), accent) }
        symbol(item.1, CGRect(x: safe + 24, y: y + 8, width: 24, height: 22), c, weight: on ? .semibold : .regular)
        text(item.0, safe, y + 36, sans(11, on ? .bold : .regular), c, width: 72, center: true)
    }
}

func cover(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, title: String, code: String, hue: CGFloat) {
    let r = CGRect(x: x, y: y, width: w, height: w * 4 / 3)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6).addClip()
    fill(r, surface)
    fill(CGRect(x: x, y: y, width: 3, height: r.height), NSColor(hue: hue, saturation: 0.6, brightness: 0.7, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    stroke(r, rule, corner: 6)
    text(String(title.prefix(1)), x, r.midY - w * 0.28, serif(w * 0.42), ink, width: w, center: true)
    text(code, x, r.maxY - 20, mono(11, .medium), muted, width: w, center: true)
}

func library() {
    fill(CGRect(x: 0, y: 0, width: pw, height: ph), paper)
    rail(selected: 0)
    // Continue panel, 240 pt in a compact height.
    let px = safe + 73 + 16
    text("Continue", px, 16, serif(22), ink)
    cover(px, 56, 84, title: "Four Bands", code: "GBA", hue: 0.62)
    text("Four Bands", px, 176, serif(20), ink, width: 208)
    text("GBA · 12 min", px, 204, mono(12), muted)
    text("Last played today", px, 222, sans(13), muted)
    fill(CGRect(x: px, y: 252, width: 208, height: 40), accentFill, corner: 6)
    symbol("play.fill", CGRect(x: px + 72, y: 264, width: 16, height: 16), onAccent)
    text("Play", px + 94, 261, sans(17, .semibold), onAccent)
    vline(safe + 73 + 240, 0, ph)
    // Chips, search and shelves.
    let cx = safe + 73 + 241 + 16
    var x = cx
    for (i, chip) in ["All", "Recent", "GBA", "NES", "MD"].enumerated() {
        let w = chip.size(withAttributes: [.font: sans(14, .semibold)]).width + 24
        if i == 0 { fill(CGRect(x: x, y: 13, width: w, height: 30), accentFill, corner: 6) }
        else { stroke(CGRect(x: x, y: 13, width: w, height: 30), rule, corner: 6) }
        text(chip, x, 19, sans(14, i == 0 ? .semibold : .regular), i == 0 ? onAccent : ink, width: w, center: true)
        x += w + 8
    }
    let sx = x + 8, sw = pw - safe - 16 - sx
    stroke(CGRect(x: sx, y: 11, width: sw, height: 34), rule, corner: 6)
    symbol("magnifyingglass", CGRect(x: sx + 10, y: 20, width: 16, height: 16), muted)
    text("Search", sx + 32, 19, sans(14), muted)
    hline(safe + 73 + 241, 56, pw - safe - 73 - 241)
    let shelves: [(String, String, CGFloat, [String])] = [
        ("GBA", "GBA", 0.62, ["Four Bands", "Key Cells", "Boot Count"]),
        ("NES", "NES", 0.05, ["Square Tone", "Toggle Cell", "Battery Save", "Pulse"])]
    for (i, shelf) in shelves.enumerated() {
        let y = 68 + CGFloat(i) * 176
        text(shelf.0, cx, y, sans(15, .semibold), ink)
        text("\(shelf.3.count)", cx + 44, y + 2, mono(12), muted)
        for (j, title) in shelf.3.enumerated() {
            let gx = cx + CGFloat(j) * 106
            cover(gx, y + 24, 90, title: title, code: shelf.1, hue: shelf.2)
            text(title, gx, y + 148, sans(12), ink, width: 96)
        }
    }
}

func game(held: Int? = 0) {
    fill(CGRect(x: 0, y: 0, width: pw, height: ph), letterbox)
    let picture = CGRect(x: (pw - 660) / 2, y: 0, width: 660, height: 440)
    gbaPicture(picture, held: held)
    let band = picture.minX, right = picture.maxX
    // D-pad on the left band, face buttons on the right, shoulders on top: outlined, filled while held.
    let d = CGPoint(x: (safe + band) / 2 - 2, y: 290), arm: CGFloat = 26
    for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)] {
        stroke(CGRect(x: d.x - arm / 2 + CGFloat(dx) * arm, y: d.y - arm / 2 + CGFloat(dy) * arm, width: arm, height: arm),
               onLetterbox, corner: 4, width: 1.5)
    }
    let fx = (right + pw - safe) / 2 - 2
    for (label, x, y, on) in [("A", fx + 22, 270.0, held == 0), ("B", fx - 16, 310.0, false)] {
        let r = CGRect(x: x - 21, y: y - 21, width: 42, height: 42)
        if on { fill(r, accentFill, corner: 21) }
        stroke(r, onLetterbox, corner: 21, width: 1.5)
        text(label, r.minX, r.minY + 11, sans(16, .semibold), on ? onAccent : onLetterbox, width: 42, center: true)
    }
    for (label, x) in [("L", (safe + band) / 2), ("R", fx)] {
        let r = CGRect(x: x - 30, y: 28, width: 60, height: 28)
        stroke(r, onLetterbox, corner: 6, width: 1.5)
        text(label, r.minX, r.minY + 5, sans(14, .semibold), onLetterbox, width: 60, center: true)
    }
    for (label, x) in [("Select", (safe + band) / 2), ("Start", fx)] {
        let r = CGRect(x: x - 30, y: 390, width: 60, height: 22)
        stroke(r, onLetterbox, corner: 6, width: 1.5)
        text(label, r.minX, r.minY + 4, sans(11, .medium), onLetterbox, width: 60, center: true)
    }
    stroke(CGRect(x: (safe + band) / 2 - 18, y: 80, width: 36, height: 36), onLetterbox, corner: 18, width: 1.5)
    symbol("pause.fill", CGRect(x: (safe + band) / 2 - 8, y: 90, width: 16, height: 16), onLetterbox)
}

func paused() {
    game(held: nil)
    let x = pw - safe - 280, w: CGFloat = 280
    fill(CGRect(x: x, y: 0, width: pw - x, height: ph), paper)
    vline(x, 0, ph)
    let cx = x + 20, cw = w - 40
    text("Paused", cx, 20, serif(22), ink)
    fill(CGRect(x: cx, y: 60, width: cw, height: 44), accentFill, corner: 6)
    text("Resume", cx, 71, sans(17, .semibold), onAccent, width: cw, center: true)
    var y: CGFloat = 116
    for (label, meta) in [("Save State", "Saved 9:41"), ("Load State", ""), ("Cheats", "0")] {
        text(label, cx, y + 12, sans(17), ink)
        if !meta.isEmpty { text(meta, cx + cw - 120, y + 15, mono(12), muted, width: 120) }
        hline(cx, y + 44, cw)
        y += 45
    }
    text("Fast Forward", cx, y + 12, sans(15, .semibold), ink)
    for (i, speed) in ["1x", "2x"].enumerated() {
        let r = CGRect(x: cx + CGFloat(i) * 60, y: y + 40, width: 52, height: 30)
        if i == 0 { fill(r, accentFill, corner: 6) } else { stroke(r, rule, corner: 6) }
        text(speed, r.minX, r.minY + 6, mono(13, .semibold), i == 0 ? onAccent : ink, width: 52, center: true)
    }
    text("Rewind: hold the rewind button, or Options and L1 on a controller.", cx, y + 82, sans(12), muted, width: cw)
    text("Quit to Library", cx, ph - home - 40, sans(17), accent)
}

func add() {
    fill(CGRect(x: 0, y: 0, width: pw, height: ph), paper)
    rail(selected: 1)
    let left = safe + 73 + 20, colW = (pw - safe - 20 - left - 24) / 2
    text("Add Games", left, 16, serif(22), ink)
    fill(CGRect(x: left, y: 56, width: colW, height: 72), accentFill, corner: 6)
    symbol("folder", CGRect(x: left + colW / 2 - 92, y: 80, width: 26, height: 24), onAccent)
    text("Choose from Files", left + colW / 2 - 58, 81, sans(17, .semibold), onAccent)
    let drop = CGRect(x: left, y: 144, width: colW, height: 150)
    rule.setStroke()
    let dash = NSBezierPath(roundedRect: drop.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
    dash.lineWidth = 1.5
    dash.setLineDash([6, 4], count: 2, phase: 0)
    dash.stroke()
    text("Or drop files here", drop.minX, drop.midY - 10, sans(15), muted, width: colW, center: true)
    text("Add only games you have the right to use. GagaEmu comes with no games.", left, 312, sans(13), muted, width: colW)
    let rx = left + colW + 24
    var y: CGFloat = 56
    for (glyph, title, note) in [("wifi", "WiFi Transfer", "Off by default. Sends files from a browser over unencrypted local HTTP."),
                                 ("doc.on.clipboard", "Read Clipboard", "Reads the clipboard only when you tap here."),
                                 ("opticaldisc", "Multi-Disc Helper", "Joins disc files into one playlist."),
                                 ("bandage", "Patch a ROM", "Applies an IPS, UPS or BPS patch to a copy.")] {
        symbol(glyph, CGRect(x: rx, y: y + 4, width: 22, height: 20), accent)
        text(title, rx + 34, y + 2, sans(17), ink)
        let h = text(note, rx + 34, y + 26, sans(13), muted, width: colW - 34 - (glyph == "wifi" ? 60 : 0))
        if glyph == "wifi" {  // The switch, off.
            fill(CGRect(x: rx + colW - 51, y: y + 2, width: 51, height: 31), rule, corner: 15.5)
            fill(CGRect(x: rx + colW - 49, y: y + 4, width: 27, height: 27), .white, corner: 13.5)
        }
        y += 26 + h + 14
        hline(rx, y, colW)
        y += 14
    }
}

// MARK: Composition

struct Shot: Decodable { let capture: String; let caption: String }

func compose(_ capture: CGImage, caption: String, w: Int, h: Int) -> CGImage {
    let W = CGFloat(w), H = CGFloat(h), u = H / 1320  // layout unit: 1 at the 6.9" height
    let icon = load(root.appendingPathComponent("Sources/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))!
    return render(w, h) {
        fill(CGRect(x: 0, y: 0, width: W, height: H), paper)
        // Header: icon, wordmark and caption, on paper with no art behind the icon (docs/BRAND.md).
        let side = 96 * u, top = 64 * u, margin = 120 * u
        let tile = CGRect(x: margin, y: top, width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: tile, xRadius: side * 0.2237, yRadius: side * 0.2237).addClip()
        drawUpright(icon, tile)
        NSGraphicsContext.restoreGraphicsState()
        text("GagaEmu", margin + side + 28 * u, top + 4 * u, serif(40 * u), ink)
        text(caption, margin + side + 28 * u, top + 52 * u, sans(36 * u, .medium), muted, width: W - 2 * margin - side)
        // The capture, aspect fit under the header, with the phone's rounded corners and a hairline.
        let area = CGRect(x: margin, y: top + side + 56 * u, width: W - 2 * margin, height: H - (top + side + 56 * u) - 72 * u)
        let cw = CGFloat(capture.width), ch = CGFloat(capture.height), k = min(area.width / cw, area.height / ch)
        let r = CGRect(x: area.midX - cw * k / 2, y: area.midY - ch * k / 2, width: cw * k, height: ch * k)
        let corner = r.height * 0.13
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: r, xRadius: corner, yRadius: corner).addClip()
        drawUpright(capture, r)
        NSGraphicsContext.restoreGraphicsState()
        stroke(r.insetBy(dx: -3 * u, dy: -3 * u), ink, corner: corner + 3 * u, width: 3 * u)
    }
}

/// CGContext.draw puts row 0 at the bottom of `r`; undo the flip so the image is upright.
func drawUpright(_ image: CGImage, _ r: CGRect) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: 0, y: r.minY + r.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: r)
    ctx.restoreGState()
}

let args = CommandLine.arguments.dropFirst()
if args.contains("--placeholders") {
    for (name, draw) in [("01-library", library), ("02-game", { game() }), ("03-paused", paused), ("04-add", add)] {
        let url = store.appendingPathComponent("placeholders/\(name).png")
        save(render(Int(pw * 3), Int(ph * 3), scale: 3, draw), url)
        print(url.path)
    }
    exit(0)
}
let outIndex = args.firstIndex(of: "--out")
let out = outIndex.map { URL(fileURLWithPath: args[args.index(after: $0)]) } ?? root.appendingPathComponent("build/store")
let shots = try! JSONDecoder().decode([Shot].self, from: Data(contentsOf: store.appendingPathComponent("captions.json")))
precondition((1...10).contains(shots.count), "App Store Connect takes 1 to 10 screenshots per class")
for (i, shot) in shots.enumerated() {
    let real = store.appendingPathComponent("captures/\(shot.capture)")
    let source = FileManager.default.fileExists(atPath: real.path) ? real : store.appendingPathComponent("placeholders/\(shot.capture)")
    guard let capture = load(source) else { fatalError("missing capture \(shot.capture) in captures/ and placeholders/") }
    precondition(capture.width > capture.height, "\(shot.capture): captures must be landscape")
    for c in classes {
        let image = compose(capture, caption: shot.caption, w: c.w, h: c.h)
        precondition(image.width == c.w && image.height == c.h && image.alphaInfo == .noneSkipLast)
        let url = out.appendingPathComponent("\(c.folder)/\(String(format: "%02d", i + 1)).png")
        save(image, url)
        print(url.path, source.deletingLastPathComponent().lastPathComponent)
    }
}
