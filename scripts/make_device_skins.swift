// Draws GagaEmu's device skins: original vector art of a handheld or controller shell per platform, in portrait
// and landscape, with the touch layout that matches the art (docs/06 section 3.8).
//
//     swift scripts/make_device_skins.swift              write Resources/Skins/Device and build/skin-previews
//     swift scripts/make_device_skins.swift --no-preview write the skins only
//
// Output per platform, in Resources/Skins/Device/<platform>/:
//   <orientation>.json                 flex skin JSON plus the device fields (theme, canvas, screens, layers)
//   <orientation>-shell.pdf            body, bezel and buttons at rest; the picture goes on top in the screen rects
//   <orientation>-shell-<variant>.pdf  the same body in another colourway
//   <orientation>-pressed.pdf          every button drawn pressed on a clear page; clip it to a held button's frame
//
// All art is drawn here from shapes and gradients. No photo, trace, logo, wordmark or model name is used, and
// no text from a device is copied. Labels are button letters and generic captions only. Text is drawn as glyph
// outlines, so the PDFs embed no font.
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outRoot = root.appendingPathComponent("Resources/Skins/Device")
let previewRoot = root.appendingPathComponent("build/skin-previews")
let makePreviews = !CommandLine.arguments.contains("--no-preview")

// MARK: Masks (ControllerManager.Button)

let UP: UInt32 = 1 << 0, DOWN: UInt32 = 1 << 1, LEFT: UInt32 = 1 << 2, RIGHT: UInt32 = 1 << 3
let SOUTH: UInt32 = 1 << 4, EAST: UInt32 = 1 << 5, WEST: UInt32 = 1 << 6, NORTH: UInt32 = 1 << 7
let L1: UInt32 = 1 << 8, R1: UInt32 = 1 << 9, L2: UInt32 = 1 << 10, R2: UInt32 = 1 << 11
let START: UInt32 = 1 << 12, SELECT: UInt32 = 1 << 13, L3: UInt32 = 1 << 14, R3: UInt32 = 1 << 15

// MARK: Colour

func col(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
/// `f` above 0 moves toward white, below 0 toward black.
func mix(_ v: UInt32, _ f: CGFloat) -> UInt32 {
    func ch(_ s: UInt32) -> UInt32 {
        let c = CGFloat(s & 255)
        return UInt32(max(0, min(255, (f > 0 ? c + (255 - c) * f : c * (1 + f)).rounded())))
    }
    return ch(v >> 16) << 16 | ch(v >> 8) << 8 | ch(v)
}
func luminance(_ v: UInt32) -> CGFloat {
    (0.299 * CGFloat(v >> 16 & 255) + 0.587 * CGFloat(v >> 8 & 255) + 0.114 * CGFloat(v & 255)) / 255
}
func ink(on v: UInt32) -> UInt32 { luminance(v) > 0.55 ? 0x26262B : 0xF1F0EC }
func hex(_ v: UInt32) -> String { String(format: "#%06X", v) }

// MARK: Model

struct Theme { var body, trim, dpad: UInt32; var face: [UInt32]; var pill, accent: UInt32 }
enum Family { case tall, wide, clam, pad, arcade, computer }
enum PadShape { case rect, dogbone, grips }
enum DStyle { case cross, disc, dots, ball }

struct CBtn { var id: String; var mask: UInt32?; var rect: CGRect; var color: UInt32; var glyph: String; var input: String? = nil }
enum Item {
    case dpad(DStyle, cell: CGFloat, prefix: String, masks: [UInt32], color: UInt32)
    case cluster([CBtn], CGSize)
    case stick(CGFloat)
    var size: CGSize {
        switch self {
        case let .dpad(_, cell, _, _, _): return CGSize(width: 3 * cell, height: 3 * cell)
        case let .cluster(_, s): return s
        case let .stick(d): return CGSize(width: d, height: d)
        }
    }
}
struct Key { var id: String; var mask: UInt32; var caption: String }

struct Spec {
    var id: String, name: String, family: Family, pad: PadShape = .rect
    var aspects: [CGFloat]
    var theme: Theme
    var left: [Item], right: [Item]
    var shL: [Key] = [], shR: [Key] = []
    var menu: [Key]
    var bigCorner = false
    var variants: [(name: String, body: UInt32)] = []
}

struct Btn { var id: String; var input: String; var mask: UInt32?; var frame: CGRect; var shape: String }
enum Part {
    case dpad(CGRect, DStyle, UInt32)
    case round(CGRect, UInt32, String)
    case pill(CGRect, String, UInt32, slant: Bool)
    case shoulder(CGRect, String, UInt32)
    case stick(CGRect, UInt32)
}
struct Layout {
    var spec: Spec, landscape: Bool, size: CGSize
    var bezels: [CGRect] = [], screens: [CGRect] = [], hinge: CGRect? = nil
    var panel: CGRect? = nil, deco: CGRect? = nil
    var buttons: [Btn] = [], parts: [Part] = [], analog: [(String, CGRect)] = []
    var picture: CGRect { screens.dropFirst().reduce(screens[0].insetBy(dx: -3, dy: -3)) { $0.union($1.insetBy(dx: -3, dy: -3)) } }
}

// MARK: Clusters

func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }
func fc(_ t: Theme, _ i: Int) -> UInt32 { t.face[i % t.face.count] }

func dpad(_ t: Theme, _ style: DStyle = .cross, cell: CGFloat = 50) -> Item {
    .dpad(style, cell: cell, prefix: "", masks: [UP, DOWN, LEFT, RIGHT], color: t.dpad)
}
func pad2(_ t: Theme, _ masks: [UInt32], _ style: DStyle = .cross) -> Item {
    .dpad(style, cell: 50, prefix: "pad2", masks: masks, color: t.dpad)
}
func diag2(_ t: Theme, _ b: String, _ a: String) -> Item {
    .cluster([CBtn(id: "south", mask: SOUTH, rect: r(0, 34, 64, 64), color: fc(t, 0), glyph: b),
              CBtn(id: "east", mask: EAST, rect: r(74, 0, 64, 64), color: fc(t, 1), glyph: a)], CGSize(width: 138, height: 98))
}
func row2(_ t: Theme, _ a: String, _ b: String, _ ma: UInt32 = SOUTH, _ mb: UInt32 = EAST) -> Item {
    .cluster([CBtn(id: ma == SOUTH ? "south" : "west", mask: ma, rect: r(0, 0, 64, 64), color: fc(t, 0), glyph: a),
              CBtn(id: mb == EAST ? "east" : "south", mask: mb, rect: r(76, 0, 64, 64), color: fc(t, 1), glyph: b)], CGSize(width: 140, height: 64))
}
/// Glyphs and colours in the order north, east, south, west.
func diamond(_ t: Theme, _ g: [String]) -> Item {
    let c: CGFloat = 54
    let pos = [(c, 0), (2 * c, c), (c, 2 * c), (0, c)] as [(CGFloat, CGFloat)]
    let ids = [("north", NORTH), ("east", EAST), ("south", SOUTH), ("west", WEST)]
    return .cluster((0..<4).map { CBtn(id: ids[$0].0, mask: ids[$0].1, rect: r(pos[$0].0, pos[$0].1, c, c), color: fc(t, $0), glyph: g[$0]) },
                    CGSize(width: 3 * c, height: 3 * c))
}
/// Two rows of three: X Y Z over A B C. Mapping follows the libretro six-button pad (A=Y, B=B, C=A, X=L, Y=X, Z=R).
func six(_ t: Theme) -> Item {
    let c: CGFloat = 54
    return .cluster([
        CBtn(id: "l", mask: L1, rect: r(8, 0, c, c), color: fc(t, 1), glyph: "X"),
        CBtn(id: "north", mask: NORTH, rect: r(8 + c, 0, c, c), color: fc(t, 1), glyph: "Y"),
        CBtn(id: "r", mask: R1, rect: r(8 + 2 * c, 0, c, c), color: fc(t, 1), glyph: "Z"),
        CBtn(id: "west", mask: WEST, rect: r(0, 60, c, c), color: fc(t, 0), glyph: "A"),
        CBtn(id: "south", mask: SOUTH, rect: r(c, 60, c, c), color: fc(t, 0), glyph: "B"),
        CBtn(id: "east", mask: EAST, rect: r(2 * c, 60, c, c), color: fc(t, 0), glyph: "C")
    ], CGSize(width: 170, height: 114))
}
/// Arcade panel: top row RetroPad Y X L, bottom row B A R, set on a gentle curve.
func arcade6(_ t: Theme) -> Item {
    let c: CGFloat = 56, off: [CGFloat] = [8, 0, 4]
    let top = [("west", WEST), ("north", NORTH), ("l", L1)], bottom = [("south", SOUTH), ("east", EAST), ("r", R1)]
    var b: [CBtn] = []
    for i in 0..<3 {
        b.append(CBtn(id: top[i].0, mask: top[i].1, rect: r(CGFloat(i) * 58, off[i], c, c), color: fc(t, i + 3), glyph: ""))
        b.append(CBtn(id: bottom[i].0, mask: bottom[i].1, rect: r(CGFloat(i) * 58, 64 + off[i], c, c), color: fc(t, i), glyph: ""))
    }
    return .cluster(b, CGSize(width: 172, height: 128))
}
func row3(_ t: Theme, _ ids: [(String, UInt32, String)]) -> Item {
    .cluster((0..<3).map { CBtn(id: ids[$0].0, mask: ids[$0].1, rect: r(CGFloat($0) * 56, CGFloat(2 - $0) * 15, 54, 54), color: fc(t, $0), glyph: ids[$0].2) },
             CGSize(width: 166, height: 84))
}
/// Right-stick buttons. The engine has no right analog yet, so these carry no mask (docs/06 section 3.8).
func cdiamond(_ t: Theme) -> Item {
    let c: CGFloat = 50
    let p = [("cup", "rstick-up", c, CGFloat(0), "up"), ("cright", "rstick-right", 2 * c, c, "rt"),
             ("cdown", "rstick-down", c, 2 * c, "dn"), ("cleft", "rstick-left", 0, c, "lf")]
    return .cluster(p.map { CBtn(id: $0.0, mask: nil, rect: r($0.2, $0.3, c, c), color: fc(t, 2), glyph: $0.4, input: $0.1) },
                    CGSize(width: 3 * c, height: 3 * c))
}
func n64ab(_ t: Theme) -> Item {
    .cluster([CBtn(id: "west", mask: WEST, rect: r(0, 0, 60, 60), color: fc(t, 1), glyph: "B"),
              CBtn(id: "south", mask: SOUTH, rect: r(68, 40, 64, 64), color: fc(t, 0), glyph: "A")], CGSize(width: 132, height: 104))
}
func fire(_ t: Theme) -> Item {
    .cluster([CBtn(id: "south", mask: SOUTH, rect: r(0, 0, 80, 80), color: fc(t, 0), glyph: "")], CGSize(width: 80, height: 80))
}
func fire2(_ t: Theme) -> Item {
    .cluster([CBtn(id: "south", mask: SOUTH, rect: r(0, 30, 72, 72), color: fc(t, 0), glyph: "1"),
              CBtn(id: "east", mask: EAST, rect: r(80, 0, 64, 64), color: fc(t, 1), glyph: "2")], CGSize(width: 144, height: 102))
}

let selectKey = Key(id: "select", mask: SELECT, caption: "SELECT"), startKey = Key(id: "start", mask: START, caption: "START")
let keysKey = Key(id: "l3", mask: L3, caption: "KEYS")
func k(_ id: String, _ m: UInt32, _ c: String) -> Key { Key(id: id, mask: m, caption: c) }

// MARK: Platforms. Names are generic; colours evoke an era without copying any product or edition.

let pool: [(String, UInt32)] = [("Charcoal", 0x2F3034), ("Light Grey", 0xC6C7CB), ("Grape", 0x6A4C9C), ("Sunflower", 0xE3B23C),
                                ("Ocean", 0x2F6C9C), ("Mint", 0x8CC4AC), ("Coral", 0xD9735F)]

func specs() -> [Spec] {
    var all: [Spec] = []
    func add(_ s: Spec) { all.append(s) }

    var t = Theme(body: 0xC8C4BB, trim: 0x4E525E, dpad: 0x2A2A2E, face: [0x8A2C55], pill: 0x8D8A84, accent: 0xC0392B)
    add(Spec(id: "gb", name: "Pocket Classic", family: .tall, aspects: [10 / 9], theme: t, left: [dpad(t)], right: [diag2(t, "B", "A")],
             menu: [selectKey, startKey], bigCorner: true))
    t = Theme(body: 0x5B3E8E, trim: 0x2B2833, dpad: 0x1F1D24, face: [0x2B2930], pill: 0x3B3050, accent: 0xE0574A)
    add(Spec(id: "gbc", name: "Handheld Color", family: .tall, aspects: [10 / 9], theme: t, left: [dpad(t)], right: [diag2(t, "B", "A")],
             menu: [selectKey, startKey]))
    t = Theme(body: 0x4C4F9E, trim: 0x2C2E45, dpad: 0x22232E, face: [0xC8C9D3], pill: 0xA9ABC0, accent: 0x5BC06A)
    add(Spec(id: "gba", name: "Handheld Wide", family: .wide, aspects: [3 / 2], theme: t, left: [dpad(t)], right: [diag2(t, "B", "A")],
             shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    t = Theme(body: 0xD3D1CC, trim: 0x1E1E20, dpad: 0x1A1A1A, face: [0xB0262A], pill: 0x3A3A3A, accent: 0xB0262A)
    add(Spec(id: "nes", name: "Home Console 8-bit", family: .pad, pad: .rect, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [row2(t, "B", "A")], menu: [selectKey, startKey]))
    t = Theme(body: 0xC9C8CF, trim: 0x9E9AB0, dpad: 0x2A2A2E, face: [0xA79FC8, 0x4A3D7A, 0x4A3D7A, 0xA79FC8], pill: 0x6E6C78, accent: 0x4A3D7A)
    add(Spec(id: "snes", name: "Home Console 16-bit", family: .pad, pad: .dogbone, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [diamond(t, ["X", "A", "B", "Y"])], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    t = Theme(body: 0x5C5E66, trim: 0x484A52, dpad: 0x2E2F34, face: [0x3C5C9A, 0x4E8A5A, 0xD8B23A], pill: 0x9A3434, accent: 0x9A3434)
    add(Spec(id: "n64", name: "Home Console 64", family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [.stick(90), dpad(t)],
             right: [cdiamond(t), n64ab(t)], shL: [k("l", L1, "L"), k("l2", L2, "Z")], shR: [k("r", R1, "R")], menu: [startKey]))
    t = Theme(body: 0xC9C9CC, trim: 0xA9A9AE, dpad: 0x8E8E94, face: [0x55565C], pill: 0x55565C, accent: 0x55565C)
    add(Spec(id: "ps1", name: "Disc Console Pad", family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [diamond(t, ["tri", "cir", "crs", "sq"])], shL: [k("l2", L2, "L2"), k("l", L1, "L1")],
             shR: [k("r", R1, "R1"), k("r2", R2, "R2")], menu: [selectKey, startKey]))
    t = Theme(body: 0x1B1C1F, trim: 0x0C0C0E, dpad: 0x2C2D31, face: [0x2C2D31], pill: 0x3A3B40, accent: 0x3E8FD8)
    add(Spec(id: "psp", name: "Portable Widescreen", family: .wide, aspects: [16 / 9], theme: t, left: [dpad(t), .stick(70)],
             right: [diamond(t, ["tri", "cir", "crs", "sq"])], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    t = Theme(body: 0xB9BCC2, trim: 0x2B2D33, dpad: 0x2E3036, face: [0xD9DBE0], pill: 0xE4E6EA, accent: 0x5BC06A)
    add(Spec(id: "nds", name: "Dual Screen Fold", family: .clam, aspects: [4 / 3, 4 / 3], theme: t, left: [dpad(t)],
             right: [diamond(t, ["X", "A", "B", "Y"])], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    t = Theme(body: 0x262C3C, trim: 0x111318, dpad: 0x3A4052, face: [0x3A4052], pill: 0x535A6E, accent: 0x3E8FD8)
    add(Spec(id: "n3ds", name: "Dual Screen Fold 3D", family: .clam, aspects: [5 / 3, 4 / 3], theme: t, left: [.stick(90), dpad(t)],
             right: [diamond(t, ["X", "A", "B", "Y"])], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    for (id, name, accent) in [("megadrive", "Six Button Pad", UInt32(0xC0392B)), ("sega32x", "Six Button Pad Plus", 0xD8B23A),
                               ("megacd", "Six Button Pad Disc", 0x3E7FC8)] {
        t = Theme(body: 0x1E1E21, trim: 0x2C2C30, dpad: 0x2E2E33, face: [0x3A3A3F, 0x4A4A50], pill: 0x3A3A3F, accent: accent)
        add(Spec(id: id, name: name, family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [dpad(t)], right: [six(t)],
                 menu: [k("select", SELECT, "MODE"), startKey]))
    }
    t = Theme(body: 0x1C1C1E, trim: 0x2E2E31, dpad: 0x2E2E31, face: [0x2E2E31], pill: 0x3A3A3D, accent: 0xD84A3A)
    add(Spec(id: "mastersystem", name: "Two Button Pad 8-bit", family: .pad, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [row2(t, "1", "2")], menu: [k("start", START, "PAUSE")]))
    t = Theme(body: 0x2A2B30, trim: 0x111114, dpad: 0x3A3B40, face: [0x3A3D7A], pill: 0x3A3D7A, accent: 0x5BC06A)
    add(Spec(id: "gamegear", name: "Handheld Color Wide", family: .wide, aspects: [10 / 9], theme: t, left: [dpad(t)],
             right: [row2(t, "1", "2")], menu: [startKey]))
    t = Theme(body: 0x2A2B2F, trim: 0x1A1A1D, dpad: 0x3A3A3E, face: [0xB8322A], pill: 0x55565C, accent: 0xB8322A)
    add(Spec(id: "sg1000", name: "Early Home Pad", family: .pad, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [row2(t, "1", "2")], menu: [k("start", START, "PAUSE")]))
    t = Theme(body: 0x3A3A40, trim: 0x2A2A2F, dpad: 0x2A2A2F, face: [0x5A5A62, 0x6E6E76], pill: 0x2A2A2F, accent: 0x6E9AD8)
    add(Spec(id: "saturn", name: "Disc Console Six", family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [six(t)], shL: [k("l2", L2, "L")], shR: [k("r2", R2, "R")], menu: [startKey]))
    t = Theme(body: 0xE6E3DC, trim: 0xCFCBC2, dpad: 0x3A3A3E, face: [0x5AA06A, 0x4E7CC0, 0xC25A52, 0xD8B84A], pill: 0x8E8A82, accent: 0xE07B39)
    add(Spec(id: "dreamcast", name: "Disc Console Trigger Pad", family: .pad, pad: .grips, aspects: [4 / 3], theme: t,
             left: [.stick(90), dpad(t)], right: [diamond(t, ["Y", "B", "A", "X"])], shL: [k("l2", L2, "L")], shR: [k("r2", R2, "R")],
             menu: [startKey]))
    t = Theme(body: 0xE9E8E4, trim: 0x2B2B2E, dpad: 0x1E1E20, face: [0x2B2B2E], pill: 0x2B2B2E, accent: 0xE0572E)
    add(Spec(id: "pce", name: "Compact Card Pad", family: .pad, aspects: [4 / 3], theme: t, left: [dpad(t)], right: [row2(t, "II", "I")],
             menu: [selectKey, k("start", START, "RUN")]))
    t = Theme(body: 0x2A2A2D, trim: 0x4A4A4E, dpad: 0x1A1A1C, face: [0x6E6E74], pill: 0x4A4A4E, accent: 0xE0572E)
    add(Spec(id: "sgx", name: "Compact Card Pad Dark", family: .pad, aspects: [4 / 3], theme: t, left: [dpad(t)], right: [row2(t, "II", "I")],
             menu: [selectKey, k("start", START, "RUN")]))
    t = Theme(body: 0x1C1C1E, trim: 0x3A1212, dpad: 0x2C2C2E, face: [0x8A1A1A], pill: 0x3A3A3C, accent: 0xC02020)
    add(Spec(id: "vb", name: "Twin Grip Visor Pad", family: .pad, pad: .grips, aspects: [384 / 224], theme: t, left: [dpad(t)],
             right: [pad2(t, [L2, L3, R2, R3]), diag2(t, "B", "A")], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    t = Theme(body: 0x8FA6C8, trim: 0x2A2D38, dpad: 0x2A2D38, face: [0x2A2D38], pill: 0x5E6E8E, accent: 0xE05A4A)
    add(Spec(id: "ngp", name: "Pocket Clicky Stick", family: .tall, aspects: [160 / 152], theme: t, left: [dpad(t, .disc)],
             right: [row2(t, "A", "B")], menu: [k("start", START, "OPTION")]))
    t = Theme(body: 0xE4E2DA, trim: 0x3A3C44, dpad: 0x6E717C, face: [0x6E717C], pill: 0x9A9DA8, accent: 0x5BC06A)
    add(Spec(id: "ws", name: "Pocket Vertical", family: .wide, aspects: [224 / 144], theme: t, left: [dpad(t, .dots)],
             right: [pad2(t, [R2, L2, L1, R1], .dots), diag2(t, "B", "A")], menu: [k("select", SELECT, "TURN"), startKey]))
    t = Theme(body: 0x86B5D8, trim: 0x24303E, dpad: 0x2E3A4A, face: [0x2E3A4A], pill: 0x2E3A4A, accent: 0xE05A4A)
    add(Spec(id: "pokemini", name: "Mini Keychain", family: .tall, aspects: [3 / 2], theme: t, left: [dpad(t)],
             right: [row3(t, [("south", SOUTH, "B"), ("east", EAST, "A"), ("r", R1, "C")])], menu: []))
    t = Theme(body: 0x252527, trim: 0x111113, dpad: 0x3A3A3E, face: [0x4A4A50], pill: 0x6A6A70, accent: 0xE0B530)
    add(Spec(id: "lynx", name: "Wide Handheld Color", family: .wide, aspects: [160 / 102], theme: t, left: [dpad(t)],
             right: [diag2(t, "B", "A")], shL: [k("l", L1, "1")], shR: [k("r", R1, "2")], menu: [k("start", START, "PAUSE")]))
    t = Theme(body: 0x161618, trim: 0x26262A, dpad: 0x2E2E33, face: [0x3A3A40], pill: 0x3A3A40, accent: 0xC03030)
    add(Spec(id: "jaguar", name: "Keypad Console Pad", family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [row3(t, [("west", WEST, "A"), ("south", SOUTH, "B"), ("east", EAST, "C")])],
             menu: [k("select", SELECT, "PAUSE"), k("start", START, "OPTION")]))
    t = Theme(body: 0x1A1A1A, trim: 0x6B4A2E, dpad: 0x111111, face: [0xC0392B], pill: 0x55565C, accent: 0xC0392B)
    add(Spec(id: "atari2600", name: "Woodgrain Stick", family: .pad, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 52)],
             right: [fire(t)], menu: [selectKey, k("start", START, "RESET")]))
    t = Theme(body: 0x2A2A2E, trim: 0xB8BAC0, dpad: 0x111111, face: [0xC8C9CE], pill: 0x55565C, accent: 0xB8BAC0)
    add(Spec(id: "atari7800", name: "Two Fire Stick", family: .pad, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 52)],
             right: [fire2(t)], menu: [k("select", SELECT, "SELECT"), k("start", START, "PAUSE")]))
    t = Theme(body: 0x1C1C1E, trim: 0x3A3A3E, dpad: 0x111111, face: [0xC8952A], pill: 0x55565C, accent: 0xC8952A)
    add(Spec(id: "atari5200", name: "Keypad Stick", family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 52)],
             right: [fire2(t)], menu: [k("select", SELECT, "PAUSE"), startKey]))
    t = Theme(body: 0xD9CFBD, trim: 0x5A4E3E, dpad: 0x1A1A1A, face: [0xC0392B], pill: 0x7A6E5E, accent: 0xC0392B)
    add(Spec(id: "atari8bit", name: "Home Computer 8-bit", family: .computer, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 52)],
             right: [fire(t)], menu: [selectKey, startKey, keysKey]))
    t = Theme(body: 0x9C917E, trim: 0x4E3F35, dpad: 0x1A1A1A, face: [0xC0392B, 0xD8B23A], pill: 0x4E3F35, accent: 0xC0392B)
    add(Spec(id: "c64", name: "Breadbox Computer", family: .computer, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 52)],
             right: [fire2(t)], menu: [keysKey]))
    t = Theme(body: 0xE6E1D6, trim: 0xCFC8B8, dpad: 0x1A1A1A, face: [0xC0392B, 0x3E7FC8], pill: 0xB8B0A0, accent: 0xC0392B)
    add(Spec(id: "amiga", name: "Desktop Computer 16-bit", family: .computer, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 52)],
             right: [fire2(t)], menu: [keysKey]))
    t = Theme(body: 0xD8D2C2, trim: 0xEDE8DC, dpad: 0x3A3A3E, face: [0x5A5A62], pill: 0x8A8478, accent: 0x5BC06A)
    add(Spec(id: "dos", name: "PC Keyboard", family: .computer, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [diamond(t, ["X", "A", "B", "Y"])], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey, keysKey]))
    t = Theme(body: 0x3A3D40, trim: 0x26282B, dpad: 0x26282B, face: [0x55595E], pill: 0x26282B, accent: 0xA8321E)
    add(Spec(id: "doom", name: "Shooter Pad", family: .pad, pad: .grips, aspects: [4 / 3], theme: t, left: [dpad(t)],
             right: [diamond(t, ["X", "A", "B", "Y"])], shL: [k("l", L1, "L")], shR: [k("r", R1, "R")], menu: [selectKey, startKey]))
    t = Theme(body: 0x1C1D24, trim: 0x8A8D96, dpad: 0xC8322A, face: [0xC8322A, 0x2E6FC0, 0xE0B530, 0x3DA05A, 0xE8E8E8, 0x8A4FC0],
              pill: 0xE8E8E8, accent: 0xC8322A)
    add(Spec(id: "arcade", name: "Arcade Panel", family: .arcade, aspects: [4 / 3], theme: t, left: [dpad(t, .ball, cell: 54)],
             right: [arcade6(t)], menu: [k("select", SELECT, "COIN"), k("start", START, "1P")]))

    // Two colourways each from a shared pool, skipping any close to the platform's own body.
    for i in all.indices {
        let base = all[i].theme.body
        let picks = pool.indices.map { pool[($0 + i * 2) % pool.count] }.filter { abs(luminance($0.1) - luminance(base)) > 0.1 }
        all[i].variants = picks.prefix(2).map { (name: $0.0, body: $0.1) }
    }
    return all
}

// MARK: Layout

func placeColumn(_ items: [Item], x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>, into L: inout Layout, gap: CGFloat = 8) {
    guard !items.isEmpty else { return }
    let total = items.map(\.size.height).reduce(0, +) + gap * CGFloat(items.count - 1)
    precondition(total <= y.upperBound - y.lowerBound + 0.5,
                 "\(L.spec.id) \(L.landscape ? "landscape" : "portrait"): column needs \(total), has \(y.upperBound - y.lowerBound)")
    var top = y.lowerBound + (y.upperBound - y.lowerBound - total) / 2
    let cx = (x.lowerBound + x.upperBound) / 2
    for item in items {
        let s = item.size, o = CGPoint(x: (cx - s.width / 2).rounded(), y: top.rounded())
        switch item {
        case let .dpad(style, c, prefix, masks, color):
            let names = ["up", "down", "left", "right"].map { prefix + $0 }
            let cells = [(1, 0), (1, 2), (0, 1), (2, 1)] as [(CGFloat, CGFloat)]
            let shapes = ["dpup", "dpdown", "dpleft", "dpright"]
            for i in 0..<4 {
                L.buttons.append(Btn(id: names[i], input: names[i], mask: masks[i],
                                     frame: r(o.x + cells[i].0 * c, o.y + cells[i].1 * c, c, c), shape: shapes[i]))
            }
            for (n, cx2, cy2, m) in [("upleft", 0, 0, masks[0] | masks[2]), ("upright", 2, 0, masks[0] | masks[3]),
                                     ("downleft", 0, 2, masks[1] | masks[2]), ("downright", 2, 2, masks[1] | masks[3])] as [(String, CGFloat, CGFloat, UInt32)] {
                L.buttons.append(Btn(id: prefix + n, input: prefix + n, mask: m, frame: r(o.x + cx2 * c, o.y + cy2 * c, c, c), shape: "hidden"))
            }
            L.parts.append(.dpad(r(o.x, o.y, 3 * c, 3 * c), style, color))
        case let .cluster(btns, _):
            for b in btns {
                let f = b.rect.offsetBy(dx: o.x, dy: o.y)
                L.buttons.append(Btn(id: b.id, input: b.input ?? b.id, mask: b.mask, frame: f, shape: "circle"))
                L.parts.append(.round(f, b.color, b.glyph))
            }
        case let .stick(d):
            let f = r(o.x, o.y, d, d)
            L.analog.append(("lstick", f))
            L.parts.append(.stick(f, L.spec.theme.dpad))
        }
        top += s.height + gap
    }
}

func placeKeys(_ keys: [Key], row: CGRect, alignRight: Bool, into L: inout Layout, shoulder: Bool) {
    guard !keys.isEmpty else { return }
    let gap: CGFloat = 8
    let w = shoulder ? min(110, (row.width - gap * CGFloat(keys.count - 1)) / CGFloat(keys.count)) : 72
    let total = w * CGFloat(keys.count) + gap * CGFloat(keys.count - 1)
    var x = alignRight ? row.maxX - total : (shoulder ? row.minX : row.midX - total / 2)
    let slant = !shoulder && [.tall, .wide].contains(L.spec.family) && !L.landscape
    for key in keys {
        let f = r(x.rounded(), row.minY, w.rounded(), row.height)
        L.buttons.append(Btn(id: key.id, input: key.id, mask: key.mask, frame: f, shape: "rect"))
        L.parts.append(shoulder ? .shoulder(f, key.caption, mix(L.spec.theme.body, -0.22)) : .pill(f, key.caption, L.spec.theme.pill, slant: slant))
        x += w + gap
    }
}

func screenBlock(aspect: CGFloat, center: CGFloat, top: CGFloat, maxW: CGFloat, maxH: CGFloat,
                 pad: (s: CGFloat, t: CGFloat, b: CGFloat)) -> (bezel: CGRect, screen: CGRect) {
    var w = maxW - 2 * pad.s, h = w / aspect
    if h > maxH { h = maxH; w = h * aspect }
    w = w.rounded(); h = h.rounded()
    let bezelW = min(maxW, max(w + 2 * pad.s, maxW * 0.0 + w + 2 * pad.s))
    let bezel = r((center - bezelW / 2).rounded(), top, bezelW.rounded(), pad.t + h + pad.b)
    return (bezel, r((center - w / 2).rounded(), top + pad.t, w, h))
}

/// Portrait: 393 x 852 pt, buttons between y 59 and 818 (Dynamic Island and home indicator stay clear).
func layoutPortrait(_ s: Spec) -> Layout {
    let W: CGFloat = 393, H: CGFloat = 852
    var L = Layout(spec: s, landscape: false, size: CGSize(width: W, height: H))
    let tv = [.pad, .arcade, .computer].contains(s.family)
    var top: CGFloat
    if s.family == .clam {
        let h: CGFloat = s.aspects[0] > 1.5 ? 162 : 192
        let a = screenBlock(aspect: s.aspects[0], center: W / 2, top: 60, maxW: W - 40, maxH: h, pad: (16, 14, 14))
        let b1 = r(20, 60, W - 40, a.bezel.height)
        L.bezels.append(b1); L.screens.append(a.screen)
        L.hinge = r(3, b1.maxY + 4, W - 6, 14)
        let w2 = (h * s.aspects[1]).rounded()
        let b2 = r((W / 2 - w2 / 2 - 14).rounded(), L.hinge!.maxY + 8, w2 + 28, h + 24)
        L.bezels.append(b2); L.screens.append(r(b2.minX + 14, b2.minY + 12, w2, h))
        top = b2.maxY + 12
    } else {
        let a = screenBlock(aspect: s.aspects[0], center: W / 2, top: 60, maxW: tv ? W - 24 : W - 40, maxH: tv ? 260 : 300,
                            pad: (16, 16, 26))
        let bezel = tv ? r(12, 60, W - 24, a.bezel.height) : r(20, 60, W - 40, a.bezel.height)
        L.bezels.append(bezel); L.screens.append(a.screen)
        top = bezel.maxY + (tv ? 18 : 16)
        if tv { L.panel = r(8, bezel.maxY + 10, W - 16, H - 6 - bezel.maxY - 10) }
        if s.family == .computer { L.deco = r(20, top, W - 40, 40); top += 50 }
    }
    let bottom: CGFloat = 818
    let menuTop = s.family == .clam
    if !s.shL.isEmpty || !s.shR.isEmpty || (menuTop && !s.menu.isEmpty) {
        let row = r(16, top, W - 32, 50)
        let per = s.shL.count > 1 || s.shR.count > 1 ? 84 : 100
        placeKeys(s.shL, row: r(row.minX, row.minY, CGFloat(per * s.shL.count + 8 * max(0, s.shL.count - 1)), 50), alignRight: false, into: &L, shoulder: true)
        placeKeys(s.shR, row: r(row.maxX - CGFloat(per * s.shR.count + 8 * max(0, s.shR.count - 1)), row.minY,
                               CGFloat(per * s.shR.count + 8 * max(0, s.shR.count - 1)), 50), alignRight: true, into: &L, shoulder: true)
        if menuTop { placeKeys(s.menu, row: row, alignRight: false, into: &L, shoulder: false) }
        top += 58
    }
    var colBottom = bottom
    if !menuTop && !s.menu.isEmpty {
        placeKeys(s.menu, row: r(16, bottom - 50, W - 32, 50), alignRight: false, into: &L, shoulder: false)
        colBottom = bottom - 58
    }
    placeColumn(s.left, x: 12...196, y: top...colBottom, into: &L)
    placeColumn(s.right, x: 197...381, y: top...colBottom, into: &L)
    return L
}

/// Landscape: 852 x 393 pt, one wide handheld body edge to edge. Buttons stay between x 44 and 808.
func layoutLandscape(_ s: Spec) -> Layout {
    let W: CGFloat = 852, H: CGFloat = 393
    var L = Layout(spec: s, landscape: true, size: CGSize(width: W, height: H))
    let bandL = r(52, 12, 176, 369), bandR = r(624, 12, 176, 369)
    if s.family == .clam {
        let h: CGFloat = 158
        var y: CGFloat = 12
        for (i, a) in s.aspects.enumerated() {
            let w = (h * a).rounded()
            let b = r((W / 2 - w / 2 - 12).rounded(), y, w + 24, h + 16)
            L.bezels.append(b); L.screens.append(r(b.minX + 12, b.minY + 8, w, h))
            y = b.maxY + (i == 0 ? 6 : 0)
            if i == 0 { L.hinge = r(236, b.maxY, 380, 6) }
        }
    } else {
        let a = screenBlock(aspect: s.aspects[0], center: W / 2, top: 14, maxW: 380, maxH: 339, pad: (14, 12, 22))
        let bh = a.screen.height + 34, bezel = r(a.screen.minX - 14, ((H - bh) / 2).rounded(), a.screen.width + 28, bh)
        L.bezels.append(bezel)
        L.screens.append(r(a.screen.minX, bezel.minY + 12, a.screen.width, a.screen.height))
    }
    var topL = bandL.minY, topR = bandR.minY
    if !s.shL.isEmpty { placeKeys(s.shL, row: r(bandL.minX, bandL.minY, bandL.width, 50), alignRight: false, into: &L, shoulder: true); topL += 58 }
    if !s.shR.isEmpty { placeKeys(s.shR, row: r(bandR.minX, bandR.minY, bandR.width, 50), alignRight: true, into: &L, shoulder: true); topR += 58 }
    // Start and Select sit under the pad on the left; a third key (Keys) goes under the face buttons.
    let leftKeys = Array(s.menu.prefix(2)), rightKeys = Array(s.menu.dropFirst(2))
    var botL = bandL.maxY, botR = bandR.maxY
    if !leftKeys.isEmpty { placeKeys(leftKeys, row: r(bandL.minX, bandL.maxY - 50, bandL.width, 50), alignRight: false, into: &L, shoulder: false); botL -= 58 }
    if !rightKeys.isEmpty { placeKeys(rightKeys, row: r(bandR.minX, bandR.maxY - 50, bandR.width, 50), alignRight: false, into: &L, shoulder: false); botR -= 58 }
    placeColumn(s.left, x: bandL.minX...bandL.maxX, y: topL...botL, into: &L, gap: 6)
    placeColumn(s.right, x: bandR.minX...bandR.maxX, y: topR...botR, into: &L, gap: 6)
    return L
}

// MARK: Self-check (44 pt targets at 0.9 scale, inside the safe area, no overlaps, clear of the picture)

func check(_ L: Layout) -> [String] {
    var bad: [String] = []
    let tag = "\(L.spec.id) \(L.landscape ? "landscape" : "portrait")"
    let safe = L.landscape ? r(44, 8, 764, 377) : r(0, 59, 393, 759)
    for b in L.buttons {
        if min(b.frame.width, b.frame.height) * 0.9 < 44 { bad.append("\(tag): \(b.id) under 44 pt at 0.9 scale") }
        if !safe.contains(b.frame) { bad.append("\(tag): \(b.id) outside safe area \(b.frame)") }
        if b.frame.intersects(L.picture) { bad.append("\(tag): \(b.id) covers the picture") }
    }
    for (i, a) in L.buttons.enumerated() {
        for b in L.buttons[(i + 1)...] where a.frame.insetBy(dx: 0.5, dy: 0.5).intersects(b.frame) { bad.append("\(tag): \(a.id) overlaps \(b.id)") }
        for (_, f) in L.analog where a.frame.insetBy(dx: 0.5, dy: 0.5).intersects(f) { bad.append("\(tag): \(a.id) overlaps the stick") }
    }
    if Set(L.buttons.map(\.id)).count != L.buttons.count { bad.append("\(tag): duplicate ids") }
    return bad
}

// MARK: Drawing helpers

let space = CGColorSpace(name: CGColorSpace.sRGB)!
func linear(_ ctx: CGContext, _ path: CGPath, _ a: UInt32, _ b: UInt32, _ rect: CGRect, vertical: Bool = true) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [col(a), col(b)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: vertical ? rect.midX : rect.minX, y: vertical ? rect.minY : rect.midY),
                           end: CGPoint(x: vertical ? rect.midX : rect.maxX, y: vertical ? rect.maxY : rect.midY), options: [])
    ctx.restoreGState()
}
func radialFill(_ ctx: CGContext, _ rect: CGRect, _ c: UInt32, light: CGFloat = 0.28, dark: CGFloat = -0.18) {
    ctx.saveGState(); ctx.addEllipse(in: rect); ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [col(mix(c, light)), col(c), col(mix(c, dark))] as CFArray, locations: [0, 0.55, 1])!
    let p = CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY - rect.height * 0.22)
    ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.62, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func shadow(_ ctx: CGContext, _ y: CGFloat = 3, _ blur: CGFloat = 6, _ a: CGFloat = 0.45) {
    ctx.setShadow(offset: CGSize(width: 0, height: -y), blur: blur, color: col(0, a))
}
func rounded(_ rect: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: min(rad, rect.width / 2), cornerHeight: min(rad, rect.height / 2), transform: nil) }
/// Rounded rect with its own bottom-right radius.
func bodyPath(_ rect: CGRect, _ rad: CGFloat, br: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: rect.minX + rad, y: rect.minY))
    p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: rad)
    p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: br)
    p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: rad)
    p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: rad)
    p.closeSubpath()
    return p
}

func textPath(_ s: String, size: CGFloat) -> CGPath {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    let font = (base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base) as CTFont
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &pos)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        for i in 0..<n {
            if let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) { path.addPath(g, transform: CGAffineTransform(translationX: pos[i].x, y: pos[i].y)) }
        }
    }
    return path
}
func text(_ ctx: CGContext, _ s: String, _ c: CGPoint, _ size: CGFloat, _ color: CGColor) {
    let p = textPath(s, size: size), b = p.boundingBoxOfPath
    var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: c.x - b.midX, ty: c.y + b.midY)
    guard let flipped = p.copy(using: &t) else { return }
    ctx.addPath(flipped); ctx.setFillColor(color); ctx.fillPath()
}

/// Button face glyph: a letter, a plain neutral shape (tri, cir, crs, sq) or a small arrow (up, dn, lf, rt).
func glyph(_ ctx: CGContext, _ g: String, _ rect: CGRect, _ color: CGColor) {
    guard !g.isEmpty else { return }
    let c = CGPoint(x: rect.midX, y: rect.midY), s = rect.width * 0.2
    ctx.saveGState()
    ctx.setStrokeColor(color); ctx.setFillColor(color); ctx.setLineWidth(max(2, rect.width * 0.045)); ctx.setLineJoin(.round)
    switch g {
    case "tri":
        ctx.move(to: CGPoint(x: c.x, y: c.y - s)); ctx.addLine(to: CGPoint(x: c.x + s * 1.05, y: c.y + s * 0.75))
        ctx.addLine(to: CGPoint(x: c.x - s * 1.05, y: c.y + s * 0.75)); ctx.closePath(); ctx.strokePath()
    case "cir": ctx.strokeEllipse(in: r(c.x - s, c.y - s, 2 * s, 2 * s))
    case "crs":
        ctx.move(to: CGPoint(x: c.x - s, y: c.y - s)); ctx.addLine(to: CGPoint(x: c.x + s, y: c.y + s))
        ctx.move(to: CGPoint(x: c.x + s, y: c.y - s)); ctx.addLine(to: CGPoint(x: c.x - s, y: c.y + s)); ctx.strokePath()
    case "sq": ctx.stroke(r(c.x - s * 0.85, c.y - s * 0.85, 1.7 * s, 1.7 * s))
    case "up", "dn", "lf", "rt":
        let a: CGFloat = ["up": -.pi / 2, "dn": .pi / 2, "lf": .pi, "rt": 0][g]!
        ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: a)
        ctx.move(to: CGPoint(x: s * 0.8, y: 0)); ctx.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.7)); ctx.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.7))
        ctx.closePath(); ctx.fillPath()
    default: text(ctx, g, c, rect.width * (g.count > 1 ? 0.3 : 0.38), color)
    }
    ctx.restoreGState()
}

// MARK: Parts

func crossPath(_ rect: CGRect) -> CGPath {
    let c = rect.width / 3, p = CGMutablePath()
    p.addPath(rounded(r(rect.minX + 2, rect.minY + c, rect.width - 4, c), 8))
    p.addPath(rounded(r(rect.minX + c, rect.minY + 2, c, rect.height - 4), 8))
    return p
}

func drawPart(_ ctx: CGContext, _ part: Part, pressed: Bool, body: UInt32) {
    switch part {
    case let .dpad(rect, style, color):
        let c = rect.width / 3
        let arms = [r(rect.minX + c, rect.minY, c, c), r(rect.minX + c, rect.minY + 2 * c, c, c),
                    r(rect.minX, rect.minY + c, c, c), r(rect.minX + 2 * c, rect.minY + c, c, c)]
        switch style {
        case .cross:
            let p = crossPath(rect)
            if pressed {
                ctx.saveGState(); ctx.addPath(p); ctx.setFillColor(col(mix(color, -0.35))); ctx.fillPath(); ctx.restoreGState()
                for a in arms { ctx.setFillColor(col(0xFFFFFF, 0.12)); ctx.fillEllipse(in: a.insetBy(dx: c * 0.2, dy: c * 0.2)) }
            } else {
                ctx.saveGState(); ctx.addPath(rounded(rect.insetBy(dx: -6, dy: -6), rect.width / 2)); ctx.setFillColor(col(mix(body, -0.14))); ctx.fillPath(); ctx.restoreGState()
                ctx.saveGState(); shadow(ctx); ctx.addPath(p); ctx.setFillColor(col(color)); ctx.fillPath(); ctx.restoreGState()
                linear(ctx, p, mix(color, 0.18), mix(color, -0.2), rect)
                ctx.setFillColor(col(mix(color, -0.25))); ctx.fillEllipse(in: r(rect.midX - c * 0.28, rect.midY - c * 0.28, c * 0.56, c * 0.56))
                for (i, a) in arms.enumerated() { glyph(ctx, ["up", "dn", "lf", "rt"][i], a.insetBy(dx: c * 0.15, dy: c * 0.15), col(mix(color, 0.35), 0.8)) }
            }
        case .disc:
            let d = rect.insetBy(dx: c * 0.12, dy: c * 0.12)
            if pressed {
                ctx.setFillColor(col(mix(color, -0.35))); ctx.fillEllipse(in: d)
                for a in arms { ctx.setFillColor(col(0xFFFFFF, 0.14)); ctx.fillEllipse(in: a.insetBy(dx: c * 0.18, dy: c * 0.18)) }
            } else {
                ctx.saveGState(); shadow(ctx); ctx.setFillColor(col(color)); ctx.fillEllipse(in: d); ctx.restoreGState()
                radialFill(ctx, d, color, light: 0.2)
                ctx.saveGState(); ctx.addEllipse(in: d); ctx.clip()
                ctx.setStrokeColor(col(mix(color, -0.4))); ctx.setLineWidth(3)
                ctx.move(to: CGPoint(x: d.midX, y: d.minY + 10)); ctx.addLine(to: CGPoint(x: d.midX, y: d.maxY - 10))
                ctx.move(to: CGPoint(x: d.minX + 10, y: d.midY)); ctx.addLine(to: CGPoint(x: d.maxX - 10, y: d.midY)); ctx.strokePath()
                ctx.restoreGState()
            }
        case .dots:
            for a in arms {
                let d = a.insetBy(dx: c * 0.12, dy: c * 0.12)
                if pressed { ctx.setFillColor(col(mix(color, -0.35))); ctx.fillEllipse(in: d.offsetBy(dx: 0, dy: 1)) } else {
                    ctx.saveGState(); shadow(ctx, 2, 4); ctx.setFillColor(col(color)); ctx.fillEllipse(in: d); ctx.restoreGState()
                    radialFill(ctx, d, color)
                }
            }
        case .ball:
            if pressed {
                for a in arms { ctx.setFillColor(col(0xFFFFFF, 0.2)); ctx.fillEllipse(in: a.insetBy(dx: c * 0.25, dy: c * 0.25)) }
            } else {
                let plate = rect.insetBy(dx: 4, dy: 4)
                ctx.saveGState(); shadow(ctx, 2, 5); ctx.setFillColor(col(0x141416)); ctx.fillEllipse(in: plate); ctx.restoreGState()
                radialFill(ctx, plate, 0x26262A, light: 0.1, dark: -0.4)
                ctx.setStrokeColor(col(0x000000, 0.6)); ctx.setLineWidth(2); ctx.strokeEllipse(in: plate.insetBy(dx: c * 0.55, dy: c * 0.55))
                for a in arms { glyph(ctx, ["up", "dn", "lf", "rt"][arms.firstIndex(of: a)!], a.insetBy(dx: c * 0.3, dy: c * 0.3), col(0xFFFFFF, 0.25)) }
                ctx.setFillColor(col(0x050505)); ctx.fillEllipse(in: r(rect.midX - 9, rect.midY - 4, 18, 18))
                let ball = r(rect.midX - c * 0.55, rect.midY - c * 0.62, c * 1.1, c * 1.1)
                ctx.saveGState(); shadow(ctx, 5, 8, 0.55); ctx.setFillColor(col(color)); ctx.fillEllipse(in: ball); ctx.restoreGState()
                radialFill(ctx, ball, color, light: 0.45, dark: -0.3)
            }
        }
    case let .round(rect, color, g):
        let d = min(rect.width, rect.height) * 0.92
        var e = r(rect.midX - d / 2, rect.midY - d / 2, d, d)
        if pressed {
            e = e.insetBy(dx: 1.5, dy: 1.5).offsetBy(dx: 0, dy: 1.5)
            ctx.setFillColor(col(mix(color, -0.3))); ctx.fillEllipse(in: e)
            ctx.saveGState(); ctx.addEllipse(in: e); ctx.clip()
            ctx.setStrokeColor(col(0, 0.35)); ctx.setLineWidth(5); ctx.strokeEllipse(in: e.offsetBy(dx: 0, dy: 2)); ctx.restoreGState()
            glyph(ctx, g, e, col(ink(on: color), 0.6))
        } else {
            ctx.setFillColor(col(mix(body, -0.2))); ctx.fillEllipse(in: e.insetBy(dx: -3, dy: -3))
            ctx.saveGState(); shadow(ctx); ctx.setFillColor(col(color)); ctx.fillEllipse(in: e); ctx.restoreGState()
            radialFill(ctx, e, color)
            ctx.setStrokeColor(col(0, 0.3)); ctx.setLineWidth(1); ctx.strokeEllipse(in: e)
            glyph(ctx, g, e, col(ink(on: color), 0.9))
        }
    case let .pill(rect, caption, color, slant):
        let cap = r(rect.midX - 26, rect.midY - 15, 52, 16)
        ctx.saveGState()
        ctx.translateBy(x: cap.midX, y: cap.midY); if slant { ctx.rotate(by: -0.35) }
        let p = rounded(r(-26, -8, 52, 16), 8)
        if pressed { ctx.addPath(p); ctx.setFillColor(col(mix(color, -0.35))); ctx.fillPath() } else {
            ctx.addPath(rounded(r(-29, -11, 58, 22), 11)); ctx.setFillColor(col(mix(body, -0.18))); ctx.fillPath()
            ctx.saveGState(); shadow(ctx, 2, 3); ctx.addPath(p); ctx.setFillColor(col(color)); ctx.fillPath(); ctx.restoreGState()
            linear(ctx, p, mix(color, 0.2), mix(color, -0.15), r(-26, -8, 52, 16))
        }
        ctx.restoreGState()
        if !pressed { text(ctx, caption, CGPoint(x: rect.midX, y: rect.maxY - 9), 9, col(ink(on: body), 0.75)) }
    case let .shoulder(rect, caption, color):
        let s = rect.insetBy(dx: 2, dy: 3), p = rounded(s, 16)
        if pressed {
            ctx.addPath(p); ctx.setFillColor(col(mix(color, -0.35))); ctx.fillPath()
            text(ctx, caption, CGPoint(x: s.midX, y: s.midY + 1), 17, col(ink(on: color), 0.6))
        } else {
            ctx.saveGState(); shadow(ctx); ctx.addPath(p); ctx.setFillColor(col(color)); ctx.fillPath(); ctx.restoreGState()
            linear(ctx, p, mix(color, 0.2), mix(color, -0.2), s)
            ctx.addPath(p); ctx.setStrokeColor(col(0, 0.3)); ctx.setLineWidth(1); ctx.strokePath()
            text(ctx, caption, CGPoint(x: s.midX, y: s.midY), 17, col(ink(on: color), 0.9))
        }
    case let .stick(rect, color):
        guard !pressed else { return }
        let well = rect.insetBy(dx: 2, dy: 2)
        radialFill(ctx, well, mix(body, -0.45), light: -0.2, dark: 0.1)
        ctx.setStrokeColor(col(0, 0.4)); ctx.setLineWidth(1.5); ctx.strokeEllipse(in: well)
        let cap = rect.insetBy(dx: rect.width * 0.2, dy: rect.width * 0.2)
        ctx.saveGState(); shadow(ctx, 4, 7, 0.5); ctx.setFillColor(col(color)); ctx.fillEllipse(in: cap); ctx.restoreGState()
        radialFill(ctx, cap, color, light: 0.22)
        ctx.setStrokeColor(col(0, 0.25)); ctx.setLineWidth(1)
        for f in [0.18, 0.32] as [CGFloat] { ctx.strokeEllipse(in: cap.insetBy(dx: cap.width * f, dy: cap.width * f)) }
    }
}

// MARK: Body

func free(_ rect: CGRect, _ L: Layout) -> Bool {
    !L.buttons.contains { $0.frame.insetBy(dx: -4, dy: -4).intersects(rect) } && !L.analog.contains { $0.1.intersects(rect) }
        && !L.bezels.contains { $0.intersects(rect) }
}

func grille(_ ctx: CGContext, _ rect: CGRect, _ body: UInt32, slots: Bool) {
    ctx.saveGState()
    if slots {
        ctx.translateBy(x: rect.midX, y: rect.midY); ctx.rotate(by: -0.5)
        for i in 0..<6 {
            let p = rounded(r(-6 - 3, CGFloat(i) * 11 - 30, 6, 46), 3)
            ctx.addPath(p.copy(using: [CGAffineTransform(translationX: CGFloat(i) * 11 - 24, y: 0)])!)
        }
        ctx.setFillColor(col(mix(body, -0.4))); ctx.fillPath()
    } else {
        for y in stride(from: rect.minY + 4, to: rect.maxY - 4, by: 9) {
            for x in stride(from: rect.minX + 4, to: rect.maxX - 4, by: 9) {
                ctx.setFillColor(col(mix(body, -0.45))); ctx.fillEllipse(in: r(x, y, 4.5, 4.5))
            }
        }
    }
    ctx.restoreGState()
}
func screw(_ ctx: CGContext, _ c: CGPoint, _ body: UInt32) {
    let e = r(c.x - 6, c.y - 6, 12, 12)
    radialFill(ctx, e, mix(body, -0.25), light: 0.3, dark: -0.3)
    ctx.setStrokeColor(col(0, 0.5)); ctx.setLineWidth(1.6)
    ctx.move(to: CGPoint(x: c.x - 3.5, y: c.y - 3.5)); ctx.addLine(to: CGPoint(x: c.x + 3.5, y: c.y + 3.5))
    ctx.move(to: CGPoint(x: c.x + 3.5, y: c.y - 3.5)); ctx.addLine(to: CGPoint(x: c.x - 3.5, y: c.y + 3.5)); ctx.strokePath()
}

func bezel(_ ctx: CGContext, _ b: CGRect, _ screen: CGRect, _ L: Layout, trim: UInt32, led: Bool) {
    let s = L.spec
    let rad: CGFloat = s.family == .computer ? 18 : 14
    let path = s.bigCorner && !L.landscape ? bodyPath(b, rad, br: 44) : rounded(b, rad)
    ctx.saveGState(); shadow(ctx, 1, 3, 0.35); ctx.addPath(path); ctx.setFillColor(col(trim)); ctx.fillPath(); ctx.restoreGState()
    linear(ctx, path, mix(trim, 0.1), mix(trim, -0.12), b)
    if s.family == .arcade { ctx.addPath(path); ctx.setStrokeColor(col(s.theme.trim)); ctx.setLineWidth(4); ctx.strokePath() }
    let recess = screen.insetBy(dx: -4, dy: -4)
    ctx.addPath(rounded(recess, 5)); ctx.setFillColor(col(0x050506)); ctx.fillPath()
    ctx.setFillColor(col(0x030303)); ctx.fill(screen)
    if led && b.maxY - screen.maxY >= 18 {
        let c = CGPoint(x: b.minX + 18, y: (screen.maxY + b.maxY) / 2 + 2)
        ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 6, color: col(s.theme.accent, 0.9))
        ctx.setFillColor(col(s.theme.accent)); ctx.fillEllipse(in: r(c.x - 3.5, c.y - 3.5, 7, 7)); ctx.restoreGState()
    }
}

func drawBody(_ ctx: CGContext, _ L: Layout, body: UInt32) {
    let s = L.spec, W = L.size.width, H = L.size.height, full = r(0, 0, W, H)
    ctx.setFillColor(col(0x0C0C0E)); ctx.fill(full)
    let handheld = L.landscape || [.tall, .wide, .clam].contains(s.family)
    if handheld {
        let shell = full.insetBy(dx: 3, dy: 3)
        let path = s.bigCorner && !L.landscape ? bodyPath(shell, 50, br: 150) : rounded(shell, L.landscape ? 120 : 52)
        linear(ctx, path, mix(body, 0.1), mix(body, -0.12), shell)
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        ctx.addPath(path); ctx.setStrokeColor(col(0xFFFFFF, 0.22)); ctx.setLineWidth(3); ctx.strokePath()
        ctx.restoreGState()
        let inner = shell.insetBy(dx: 10, dy: 10)
        ctx.addPath(s.bigCorner && !L.landscape ? bodyPath(inner, 42, br: 140) : rounded(inner, L.landscape ? 110 : 44))
        ctx.setStrokeColor(col(0, 0.12)); ctx.setLineWidth(1); ctx.strokePath()
        if let h = L.hinge {
            linear(ctx, CGPath(rect: h, transform: nil), mix(body, -0.35), mix(body, -0.1), h)
            ctx.setFillColor(col(0, 0.25)); ctx.fill(r(h.minX, h.minY, h.width, 1)); ctx.fill(r(h.minX, h.maxY - 1, h.width, 1))
        }
        // Era detail on landscape shells of home systems: a contrasting band under the picture.
        if L.landscape && [.pad, .arcade, .computer].contains(s.family) {
            let band = r(L.bezels[0].minX - 8, H - 12, L.bezels[0].width + 16, 6)
            ctx.addPath(rounded(band, 3)); ctx.setFillColor(col(s.family == .pad ? s.theme.accent : s.theme.trim, 0.85)); ctx.fillPath()
        }
    } else {
        // Portrait home systems: a screen surround up top, the controller, panel or keyboard below.
        linear(ctx, CGPath(rect: full, transform: nil), 0x1C1B21, 0x0B0B0E, full)
        if let p = L.panel {
            let path: CGPath
            switch (s.family, s.pad) {
            case (.pad, .grips):
                let m = CGMutablePath()
                m.addPath(rounded(r(p.minX, p.minY, p.width, p.height - 40), 46))
                m.addEllipse(in: r(p.minX, p.maxY - 200, 215, 200)); m.addEllipse(in: r(p.maxX - 215, p.maxY - 200, 215, 200))
                path = m
            case (.pad, .dogbone):
                let m = CGMutablePath()
                m.addPath(rounded(r(p.minX + 20, p.minY, p.width - 40, p.height), 60))
                m.addEllipse(in: r(p.minX, p.minY + 40, 200, p.height - 40)); m.addEllipse(in: r(p.maxX - 200, p.minY + 40, 200, p.height - 40))
                path = m
            case (.arcade, _):
                let m = CGMutablePath()
                m.move(to: CGPoint(x: p.minX + 14, y: p.minY)); m.addLine(to: CGPoint(x: p.maxX - 14, y: p.minY))
                m.addLine(to: CGPoint(x: p.maxX, y: p.maxY)); m.addLine(to: CGPoint(x: p.minX, y: p.maxY)); m.closeSubpath()
                path = m
            default: path = rounded(p, s.family == .computer ? 22 : 34)
            }
            ctx.saveGState(); shadow(ctx, 6, 14, 0.6); ctx.addPath(path); ctx.setFillColor(col(body)); ctx.fillPath(); ctx.restoreGState()
            linear(ctx, path, mix(body, 0.12), mix(body, -0.14), p)
            if s.family == .arcade { ctx.addPath(path); ctx.setStrokeColor(col(s.theme.trim)); ctx.setLineWidth(6); ctx.strokePath() }
            if s.family == .pad && s.pad == .rect {
                let inset = r(p.minX + 16, p.minY + 18, p.width - 32, p.height - 54)
                ctx.addPath(rounded(inset, 18)); ctx.setFillColor(col(s.theme.trim, 0.9)); ctx.fillPath()
            }
            if s.family != .pad {
                for c in [CGPoint(x: p.minX + 22, y: p.minY + 18), CGPoint(x: p.maxX - 22, y: p.minY + 18),
                          CGPoint(x: p.minX + 18, y: p.maxY - 24), CGPoint(x: p.maxX - 18, y: p.maxY - 24)] where free(r(c.x - 8, c.y - 8, 16, 16), L) {
                    screw(ctx, c, body)
                }
            }
        }
    }
    // Computer key rows: a hint of a keyboard, not a working one.
    if s.family == .computer {
        let rows: [CGRect] = L.deco.map { [$0] } ?? [r(56, 338, 176, 40), r(620, 338, 176, 40)].filter { free($0, L) }
        for d in rows {
            for row in 0..<2 {
                let n = Int(d.width / 26)
                let kw = (d.width - CGFloat(n - 1) * 3) / CGFloat(n)
                for i in 0..<n {
                    let kr = r(d.minX + CGFloat(i) * (kw + 3) + (row == 1 ? kw / 2 : 0), d.minY + CGFloat(row) * 20, kw, 17)
                    guard kr.maxX <= d.maxX else { continue }
                    ctx.saveGState(); shadow(ctx, 1, 1.5, 0.35); ctx.addPath(rounded(kr, 3)); ctx.setFillColor(col(s.theme.trim)); ctx.fillPath(); ctx.restoreGState()
                }
            }
        }
    }
    // Trim colour for the screen surround: home systems in portrait use a dark frame, handhelds their trim.
    let trim = handheld ? s.theme.trim : (s.family == .computer ? mix(body, -0.08) : 0x232227)
    for (i, b) in L.bezels.enumerated() { bezel(ctx, b, L.screens[i], L, trim: trim, led: i == 0) }
    // Speaker grilles and screws where the controls leave room.
    if handheld {
        let spots: [CGRect] = L.landscape
            ? [r(70, 300, 70, 60), r(712, 300, 70, 60), r(150, 330, 60, 40), r(642, 330, 60, 40), r(704, 22, 80, 40)]
            : [r(W - 120, H - 120, 80, 72), r(30, H - 100, 70, 60)]
        var drawn = 0
        for spot in spots where drawn < 2 && free(spot, L) {
            grille(ctx, spot, body, slots: s.bigCorner && !L.landscape); drawn += 1
        }
        if L.landscape {
            for c in [CGPoint(x: 24, y: H / 2), CGPoint(x: W - 24, y: H / 2)] { screw(ctx, c, body) }
        }
    }
}

// MARK: Render

enum Layer { case shell, pressed }
func draw(_ ctx: CGContext, _ L: Layout, _ layer: Layer, body: UInt32) {
    ctx.translateBy(x: 0, y: L.size.height); ctx.scaleBy(x: 1, y: -1)
    if layer == .shell { drawBody(ctx, L, body: body) }
    // Flat pads in portrait carry their controls on the inset face panel, so wells and captions sit on its colour.
    let s = L.spec, under = !L.landscape && s.family == .pad && s.pad == .rect ? s.theme.trim : body
    for p in L.parts { ctx.saveGState(); drawPart(ctx, p, pressed: layer == .pressed, body: under); ctx.restoreGState() }
}

func writePDF(_ url: URL, _ L: Layout, _ layer: Layer, body: UInt32) {
    var box = CGRect(origin: .zero, size: L.size)
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, [kCGPDFContextCreator: "GagaEmu make_device_skins.swift"] as CFDictionary) else {
        fatalError("cannot write \(url.path)")
    }
    ctx.beginPDFPage(nil); draw(ctx, L, layer, body: body); ctx.endPDFPage(); ctx.closePDF()
}

func round4(_ v: CGFloat) -> Double { (Double(v) * 10000).rounded() / 10000 }
func norm(_ f: CGRect, _ s: CGSize) -> [String: Double] {
    ["x": round4(f.minX / s.width), "y": round4(f.minY / s.height), "width": round4(f.width / s.width), "height": round4(f.height / s.height)]
}

func json(_ L: Layout, prefix: String) -> [String: Any] {
    let s = L.spec
    // The colour at the canvas edge, for filling a taller or wider screen than the canvas.
    let handheld = L.landscape || [.tall, .wide, .clam].contains(s.family)
    func edge(_ body: UInt32) -> String { hex(handheld ? body : 0x0B0B0E) }
    var buttons: [[String: Any]] = []
    for b in L.buttons {
        var o: [String: Any] = ["id": b.id, "input": b.input, "frame": norm(b.frame, L.size), "shape": b.shape]
        if let m = b.mask { o["mask"] = m }
        buttons.append(o)
    }
    return [
        "name": s.name, "platform": s.id, "theme": "device", "landscape": L.landscape, "opacity": 1,
        "canvas": ["width": L.size.width, "height": L.size.height],
        "fill": edge(s.theme.body),
        "background": "\(prefix)-shell.pdf", "pressed": "\(prefix)-pressed.pdf",
        "variants": s.variants.map { ["name": $0.name, "background": "\(prefix)-shell-\(slug($0.name)).pdf", "fill": edge($0.body)] },
        "screens": L.screens.map { norm($0, L.size) },
        "pictureArea": norm(L.picture, L.size),
        "buttons": buttons,
        "analog": L.analog.map { ["id": $0.0, "input": $0.0, "frame": norm($0.1, L.size)] }
    ]
}
func slug(_ s: String) -> String { s.lowercased().replacingOccurrences(of: " ", with: "-") }

/// Mirror of TouchSkinEngine's private FlexSkin, to prove the engine's decoder reads these files.
struct FlexMirror: Decodable {
    let name: String; let landscape: Bool?; let svg: String?; let opacity: Double?
    let buttons: [B]
    struct B: Decodable { let input: String; let frame: F; let shape: String?; let id: String?; let mask: UInt32? }
    struct F: Decodable { let x, y, width, height: Double }
}

func previewPNG(_ url: URL, _ L: Layout, scale: CGFloat, held: [String]) {
    let w = Int(L.size.width * scale), h = Int(L.size.height * scale)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.saveGState(); draw(ctx, L, .shell, body: L.spec.theme.body); ctx.restoreGState()
    // Stand-in picture: a gradient with a grid, so the screen rect is visible.
    ctx.saveGState(); ctx.translateBy(x: 0, y: L.size.height); ctx.scaleBy(x: 1, y: -1)
    for sr in L.screens {
        linear(ctx, CGPath(rect: sr, transform: nil), 0x3E6E9E, 0xE4572E, sr)
        ctx.setStrokeColor(col(0xFFFFFF, 0.2)); ctx.setLineWidth(1)
        for x in stride(from: sr.minX, through: sr.maxX, by: sr.width / 8) { ctx.move(to: CGPoint(x: x, y: sr.minY)); ctx.addLine(to: CGPoint(x: x, y: sr.maxY)) }
        for y in stride(from: sr.minY, through: sr.maxY, by: sr.height / 6) { ctx.move(to: CGPoint(x: sr.minX, y: y)); ctx.addLine(to: CGPoint(x: sr.maxX, y: y)) }
        ctx.strokePath()
    }
    ctx.restoreGState()
    // Pressed layer clipped to the held buttons' frames, the way the engine should show presses.
    let frames = L.buttons.filter { held.contains($0.id) }.map(\.frame)
    if !frames.isEmpty {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: L.size.height); ctx.scaleBy(x: 1, y: -1)
        ctx.addRects(frames); ctx.clip()
        ctx.scaleBy(x: 1, y: -1); ctx.translateBy(x: 0, y: -L.size.height)
        draw(ctx, L, .pressed, body: L.spec.theme.body)
        ctx.restoreGState()
    }
    let image = ctx.makeImage()!
    savePNG(image, url)
    sheetImages[L.landscape, default: []].append(image)
}
func savePNG(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
}
var sheetImages: [Bool: [CGImage]] = [:]
/// One contact sheet per orientation, for a quick look at every platform.
func writeSheets() {
    for (landscape, images) in sheetImages {
        let (w, h, cols) = landscape ? (426, 197, 5) : (197, 426, 9)
        let rows = (images.count + cols - 1) / cols
        let ctx = CGContext(data: nil, width: cols * w, height: rows * h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(col(0xFFFFFF)); ctx.fill(r(0, 0, CGFloat(cols * w), CGFloat(rows * h)))
        for (i, im) in images.enumerated() {
            ctx.draw(im, in: r(CGFloat(i % cols * w), CGFloat((rows - 1 - i / cols) * h), CGFloat(w), CGFloat(h)))
        }
        savePNG(ctx.makeImage()!, previewRoot.appendingPathComponent("sheet-\(landscape ? "landscape" : "portrait").png"))
    }
}

// MARK: Main

let fm = FileManager.default
var problems: [String] = []
var count = 0
for spec in specs() {
    let dir = outRoot.appendingPathComponent(spec.id)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    for L in [layoutPortrait(spec), layoutLandscape(spec)] {
        let prefix = L.landscape ? "landscape" : "portrait"
        problems += check(L)
        writePDF(dir.appendingPathComponent("\(prefix)-shell.pdf"), L, .shell, body: spec.theme.body)
        writePDF(dir.appendingPathComponent("\(prefix)-pressed.pdf"), L, .pressed, body: spec.theme.body)
        for v in spec.variants { writePDF(dir.appendingPathComponent("\(prefix)-shell-\(slug(v.name)).pdf"), L, .shell, body: v.body) }
        let data = try JSONSerialization.data(withJSONObject: json(L, prefix: prefix), options: [.prettyPrinted, .sortedKeys])
        try data.write(to: dir.appendingPathComponent("\(prefix).json"))
        let decoded = try JSONDecoder().decode(FlexMirror.self, from: data)
        precondition(decoded.buttons.count == L.buttons.count && decoded.landscape == L.landscape, "\(spec.id) \(prefix) does not round-trip")
        if makePreviews {
            try fm.createDirectory(at: previewRoot, withIntermediateDirectories: true)
            let held = ["up", "east", "start"]
            previewPNG(previewRoot.appendingPathComponent("\(spec.id)-\(prefix).png"), L, scale: 2, held: held)
        }
        count += 1
    }
}
if makePreviews { writeSheets() }
if problems.isEmpty { print("ok: \(count) skins in \(outRoot.path)") } else { problems.forEach { print($0) }; exit(1) }
