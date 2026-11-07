// Build options.png from the rendered options, in Apple's continuous-corner mask.
//     swiftc -O contact_sheet.swift -o /tmp/contact_sheet && /tmp/contact_sheet design/icons
import AppKit
import SwiftUI

let root = CommandLine.arguments[1]
let options = [(1, "two-beats", "Two Beats"), (2, "folio", "Folio"), (3, "shelf", "Shelf"),
               (4, "steps", "Steps"), (5, "well", "Well"), (6, "phosphor", "Phosphor")]

let paper = NSColor(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE6 / 255, alpha: 1)
let dark = NSColor(red: 0x16 / 255, green: 0x14 / 255, blue: 0x0F / 255, alpha: 1)
let ink = NSColor(red: 0x1C / 255, green: 0x1A / 255, blue: 0x17 / 255, alpha: 1)

let panel = (w: 400, h: 500)
let scale = 2  // retina, so the 60pt icons show at the pixels a phone uses
let columns = 2, rows = 3
let header = 90
let width = panel.w * 2 * columns, height = panel.h * rows + header

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current!.imageInterpolation = .high

func serif(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .semibold)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.serif)!, size: size)!
}

func text(_ string: String, _ x: Int, _ yTop: Int, _ font: NSFont, _ color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = (string as NSString).size(withAttributes: attributes)
    (string as NSString).draw(at: NSPoint(x: CGFloat(x), y: CGFloat(height - yTop) - size.height), withAttributes: attributes)
}

func icon(_ path: String, _ x: Int, _ yTop: Int, _ side: Int) {
    guard let image = NSImage(contentsOfFile: path) else { fatalError("missing \(path)") }
    let rect = CGRect(x: x, y: height - yTop - side, width: side, height: side)
    let mask = RoundedRectangle(cornerRadius: CGFloat(side) * 0.2237, style: .continuous).path(in: rect).cgPath
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(cgPath: mask)
    clip.addClip()
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

paper.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
text("GagaEmu icon options", 40, 22, serif(34), ink)
text("Each pair: default appearance on paper, then dark variant on dark. Small row is 60pt: default, dark, tinted.",
     440, 40, .systemFont(ofSize: 15), ink.withAlphaComponent(0.65))

for (index, option) in options.enumerated() {
    let (number, slug, name) = option
    let dir = "\(root)/option-\(number)-\(slug)/"
    let x0 = (index % columns) * panel.w * 2, y0 = header + (index / columns) * panel.h
    let big = 300, inset = (panel.w - big) / 2

    paper.setFill(); NSRect(x: x0, y: height - y0 - panel.h, width: panel.w, height: panel.h).fill()
    dark.setFill(); NSRect(x: x0 + panel.w, y: height - y0 - panel.h, width: panel.w, height: panel.h).fill()

    text("\(number)  \(name)", x0 + inset, y0 + 14, serif(24), ink)
    icon(dir + "icon-1024.png", x0 + inset, y0 + 60, big)
    icon(dir + "icon-1024.png", x0 + inset, y0 + 60 + big + 30, 60)
    text("60pt", x0 + inset + 72, y0 + 60 + big + 50, .monospacedSystemFont(ofSize: 13, weight: .regular), ink.withAlphaComponent(0.6))

    icon(dir + "icon-1024-dark.png", x0 + panel.w + inset, y0 + 60, big)
    for (i, file) in ["icon-1024.png", "icon-1024-dark.png", "icon-1024-tinted.png"].enumerated() {
        icon(dir + file, x0 + panel.w + inset + i * 76, y0 + 60 + big + 30, 60)
    }
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: root + "/options.png"))
