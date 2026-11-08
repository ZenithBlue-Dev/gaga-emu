import CoreGraphics
import Foundation

/// How the picture fills its area (docs/05 section 2.6).
enum ScalingMode: String, Codable, CaseIterable, Identifiable {
    case fit, stretch, integer, zoom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fit: return "Fit"
        case .stretch: return "Stretch"
        case .integer: return "Whole Pixels"
        case .zoom: return "Zoom"
        }
    }
}

/// The part of the game view the picture may use while the touch controls show.
enum PictureArea: String, Codable, CaseIterable, Identifiable {
    case fullScreen = "full-screen", betweenControls = "between-controls"
    var id: String { rawValue }
    var title: String { self == .fullScreen ? "Full Screen" : "Between Controls" }
}

/// Arrangements for a system with two screens. Each names the screen it calls first; Swap exchanges them.
enum DualPreset: String, Codable, CaseIterable, Identifiable {
    case stacked, sideBySide = "side-by-side", largeTop = "large-top", largeBottom = "large-bottom", single, hybrid, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .stacked: return "Stacked"
        case .sideBySide: return "Side by Side"
        case .largeTop: return "Large Top"
        case .largeBottom: return "Large Bottom"
        case .single: return "One Screen"
        case .hybrid: return "Large and Both"
        case .custom: return "Custom"
        }
    }

    var usesSmallScreen: Bool { [.largeTop, .largeBottom, .hybrid].contains(self) }
}

/// Where the small screen sits against the large one.
enum SmallPlacement: String, Codable, CaseIterable, Identifiable {
    case left, right, top, bottom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .top: return "Above"
        case .bottom: return "Below"
        }
    }
}

/// A quarter turn of both screens, for games held like a book.
enum ScreenRotation: String, Codable, CaseIterable, Identifiable {
    case none, left, right
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .left: return "Turn Left"
        case .right: return "Turn Right"
        }
    }
}

enum ScreenID: String, Codable { case top, bottom }

/// One system's or one game's screen choices, saved in ScreenLayouts.json. Every field decodes on its own, so a
/// value this build does not know (from a later build, or a damaged file) falls back to its default alone.
struct ScreenSettings: Codable, Equatable {
    var scaling = ScalingMode.fit
    var area = PictureArea.fullScreen
    var preset = DualPreset.stacked
    var smallPlacement = SmallPlacement.right
    var swapped = false
    var showTop = true
    var showBottom = true
    /// The small screen's size as a share of the large one's.
    var smallScale = 0.5
    /// Between the screens, in the screens' own pixels.
    var gap = 0.0
    var rotation = ScreenRotation.none
    /// The custom layout: each screen's place as a share of the full game view.
    var customTop: CGRect?
    var customBottom: CGRect?

    static let smallScaleRange = 0.25...1.0
    static let gapRange = 0.0...64.0

    init() {}

    private enum Keys: String, CodingKey {
        case scaling, area, preset, smallPlacement, swapped, showTop, showBottom, smallScale, gap, rotation, customTop, customBottom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        func value<T: Decodable>(_ key: Keys, _ fallback: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback }
        scaling = value(.scaling, scaling)
        area = value(.area, area)
        preset = value(.preset, preset)
        smallPlacement = value(.smallPlacement, smallPlacement)
        swapped = value(.swapped, swapped)
        showTop = value(.showTop, showTop)
        showBottom = value(.showBottom, showBottom)
        smallScale = value(.smallScale, smallScale)
        gap = value(.gap, gap)
        rotation = value(.rotation, rotation)
        customTop = value(.customTop, customTop)
        customBottom = value(.customBottom, customBottom)
    }

    /// In range, with a screen to show. A file is not trusted to be either.
    func normalized() -> ScreenSettings {
        var copy = self
        copy.smallScale = smallScale.isFinite ? min(max(smallScale, Self.smallScaleRange.lowerBound), Self.smallScaleRange.upperBound) : 0.5
        copy.gap = gap.isFinite ? min(max(gap, Self.gapRange.lowerBound), Self.gapRange.upperBound) : 0
        if !showTop && !showBottom { copy.showTop = true; copy.showBottom = true }
        return copy
    }
}

/// Where one screen goes: the part of the core's frame it shows, turned, into a rectangle of the canvas.
struct ScreenPlacement: Equatable {
    var id: ScreenID?
    /// Normalized in the frame.
    var source: CGRect
    var rotation: ScreenRotation
    /// In canvas units, normally pixels. May reach past the canvas (Zoom).
    var dest: CGRect
    var takesTouch: Bool

    var isWholeFrame: Bool { source == CGRect(x: 0, y: 0, width: 1, height: 1) && rotation == .none }
}

/// The picture's geometry, for every core (docs/05 section 2.6). Pure math: the renderer, the layer-path view
/// and touch all place the picture through here, so a finger always lands where the screen is drawn.
enum ScreenLayout {
    struct Region: Equatable {
        let id: ScreenID
        /// Normalized in the frame.
        let rect: CGRect
        let pixels: CGSize
    }

    static let dualPlatforms: Set<String> = ["nds", "n3ds"]
    static func isDual(_ platformID: String) -> Bool { dualPlatforms.contains(platformID) }

    /// The frame each two-screen core sends, fixed by its core options: melonDS DS `left-right` with no gap
    /// (256 + 256 by 192) and Azahar `side_by_side` (400 + 320 by 240), top screen on the left in both.
    static func nominalFrame(_ platformID: String) -> CGSize? {
        switch platformID {
        case "nds": return CGSize(width: 512, height: 192)
        case "n3ds": return CGSize(width: 720, height: 240)
        default: return nil
        }
    }

    /// The two screens' places in a frame, or nil when the frame is not the expected arrangement, so a core
    /// that ever sends something else is shown whole instead of cut in the wrong place.
    static func regions(platformID: String, frame: CGSize) -> [Region]? {
        guard let nominal = nominalFrame(platformID), frame.width > 0, frame.height > 0 else { return nil }
        let expected = nominal.width / nominal.height
        guard abs(frame.width / frame.height - expected) <= expected * 0.02 else { return nil }
        let topShare: CGFloat = platformID == "nds" ? 0.5 : 400 / 720
        return [Region(id: .top, rect: CGRect(x: 0, y: 0, width: topShare, height: 1),
                       pixels: CGSize(width: (frame.width * topShare).rounded(), height: frame.height)),
                Region(id: .bottom, rect: CGRect(x: topShare, y: 0, width: 1 - topShare, height: 1),
                       pixels: CGSize(width: frame.width - (frame.width * topShare).rounded(), height: frame.height))]
    }

    /// `content` placed in `canvas`, centred. Whole Pixels falls back to Fit when the canvas is smaller than one.
    /// shortcut: treats core pixels as square, add a display aspect to the frame descriptor when a core needs it (SNES 8:7).
    static func scaledRect(content: CGSize, canvas: CGSize, mode: ScalingMode) -> CGRect {
        guard content.width > 0, content.height > 0, canvas.width > 0, canvas.height > 0 else {
            return CGRect(origin: .zero, size: canvas)
        }
        if mode == .stretch { return CGRect(origin: .zero, size: canvas) }
        let fit = min(canvas.width / content.width, canvas.height / content.height)
        var scale = mode == .zoom ? max(canvas.width / content.width, canvas.height / content.height) : fit
        if mode == .integer, fit >= 1 { scale = fit.rounded(.down) }
        let width = (content.width * scale).rounded(), height = (content.height * scale).rounded()
        return CGRect(x: ((canvas.width - width) / 2).rounded(.down), y: ((canvas.height - height) / 2).rounded(.down),
                      width: width, height: height)
    }

    /// Every screen to draw, back to front.
    static func placements(frame: CGSize, canvas: CGSize, platformID: String, settings raw: ScreenSettings) -> [ScreenPlacement] {
        guard frame.width > 0, frame.height > 0, canvas.width > 0, canvas.height > 0 else { return [] }
        let settings = raw.normalized()
        guard let regions = regions(platformID: platformID, frame: frame) else {
            return [ScreenPlacement(id: nil, source: CGRect(x: 0, y: 0, width: 1, height: 1), rotation: .none,
                                    dest: scaledRect(content: frame, canvas: canvas, mode: settings.scaling), takesTouch: true)]
        }
        var arranged = settings
        if settings.preset == .custom {
            if let custom = customPlacements(regions, canvas: canvas, settings: settings) { return custom }
            arranged.preset = .stacked // Never edited yet, or a place lost from the file.
        }
        let (pieces, box) = arrangement(regions, settings: arranged)
        let target = scaledRect(content: box, canvas: canvas, mode: settings.scaling)
        let sx = target.width / box.width, sy = target.height / box.height
        return pieces.map { region, local in
            let minX = (target.minX + local.minX * sx).rounded(), maxX = (target.minX + local.maxX * sx).rounded()
            let minY = (target.minY + local.minY * sy).rounded(), maxY = (target.minY + local.maxY * sy).rounded()
            return ScreenPlacement(id: region.id, source: region.rect, rotation: settings.rotation,
                                   dest: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
                                   takesTouch: region.id == .bottom)
        }
    }

    /// Each shown screen's rectangle in the screens' own pixels, and the box around them all.
    static func arrangement(_ regions: [Region], settings: ScreenSettings) -> ([(Region, CGRect)], CGSize) {
        let top = regions[0], bottom = regions[1]
        func size(_ region: Region, _ scale: CGFloat = 1) -> CGSize {
            let s = settings.rotation == .none ? region.pixels : CGSize(width: region.pixels.height, height: region.pixels.width)
            return CGSize(width: s.width * scale, height: s.height * scale)
        }
        let (first, second) = settings.swapped ? (bottom, top) : (top, bottom)
        let shown = [first, second].filter { $0.id == .top ? settings.showTop : settings.showBottom }
        let gap = CGFloat(settings.gap), small = CGFloat(settings.smallScale)
        let preset = shown.count == 1 ? .single : settings.preset == .custom ? .stacked : settings.preset

        switch preset {
        case .single, .custom:
            let only = shown.first ?? first
            return ([(only, CGRect(origin: .zero, size: size(only)))], size(only))
        case .stacked:
            let a = size(first), b = size(second), width = max(a.width, b.width)
            return ([(first, CGRect(x: (width - a.width) / 2, y: 0, width: a.width, height: a.height)),
                     (second, CGRect(x: (width - b.width) / 2, y: a.height + gap, width: b.width, height: b.height))],
                    CGSize(width: width, height: a.height + gap + b.height))
        case .sideBySide:
            let a = size(first), b = size(second), height = max(a.height, b.height)
            return ([(first, CGRect(x: 0, y: (height - a.height) / 2, width: a.width, height: a.height)),
                     (second, CGRect(x: a.width + gap, y: (height - b.height) / 2, width: b.width, height: b.height))],
                    CGSize(width: a.width + gap + b.width, height: height))
        case .largeTop, .largeBottom:
            let (large, other) = (preset == .largeTop) != settings.swapped ? (top, bottom) : (bottom, top)
            let big = size(large), little = size(other, small)
            let (bigRect, littleRects, box) = beside(big, [little], placement: settings.smallPlacement, gap: gap)
            return ([(large, bigRect), (other, littleRects[0])], box)
        case .hybrid:
            let big = size(first)
            let (bigRect, littleRects, box) = beside(big, [size(top, small), size(bottom, small)], placement: settings.smallPlacement, gap: gap)
            return ([(first, bigRect), (top, littleRects[0]), (bottom, littleRects[1])], box)
        }
    }

    /// The large screen with the small ones beside it on one side, centred along that side. Several small ones
    /// line up along the side: a column to the left or right, a row above or below.
    private static func beside(_ big: CGSize, _ smalls: [CGSize], placement: SmallPlacement, gap: CGFloat) -> (CGRect, [CGRect], CGSize) {
        let horizontal = placement == .left || placement == .right
        // The small group's size: a column beside, a row above or below.
        let groupAlong = smalls.map { horizontal ? $0.height : $0.width }.reduce(0, +) + gap * CGFloat(smalls.count - 1)
        let groupAcross = smalls.map { horizontal ? $0.width : $0.height }.max() ?? 0
        let group = horizontal ? CGSize(width: groupAcross, height: groupAlong) : CGSize(width: groupAlong, height: groupAcross)
        let box = horizontal ? CGSize(width: big.width + gap + group.width, height: max(big.height, group.height))
                             : CGSize(width: max(big.width, group.width), height: big.height + gap + group.height)
        let bigOrigin: CGPoint, groupOrigin: CGPoint
        switch placement {
        case .right: bigOrigin = CGPoint(x: 0, y: (box.height - big.height) / 2)
                     groupOrigin = CGPoint(x: big.width + gap, y: (box.height - group.height) / 2)
        case .left: groupOrigin = CGPoint(x: 0, y: (box.height - group.height) / 2)
                    bigOrigin = CGPoint(x: group.width + gap, y: (box.height - big.height) / 2)
        case .bottom: bigOrigin = CGPoint(x: (box.width - big.width) / 2, y: 0)
                      groupOrigin = CGPoint(x: (box.width - group.width) / 2, y: big.height + gap)
        case .top: groupOrigin = CGPoint(x: (box.width - group.width) / 2, y: 0)
                   bigOrigin = CGPoint(x: (box.width - big.width) / 2, y: group.height + gap)
        }
        var along: CGFloat = 0
        let rects = smalls.map { s -> CGRect in
            defer { along += (horizontal ? s.height : s.width) + gap }
            return horizontal ? CGRect(x: groupOrigin.x + (group.width - s.width) / 2, y: groupOrigin.y + along, width: s.width, height: s.height)
                              : CGRect(x: groupOrigin.x + along, y: groupOrigin.y + (group.height - s.height) / 2, width: s.width, height: s.height)
        }
        return (CGRect(origin: bigOrigin, size: big), rects, box)
    }

    /// The custom layout, scaled to the canvas. Swap exchanges the two places. Nil when a shown screen has none.
    private static func customPlacements(_ regions: [Region], canvas: CGSize, settings: ScreenSettings) -> [ScreenPlacement]? {
        var result: [ScreenPlacement] = []
        for region in regions where region.id == .top ? settings.showTop : settings.showBottom {
            let ownsTopPlace = (region.id == .top) != settings.swapped
            guard let rect = ownsTopPlace ? settings.customTop : settings.customBottom else { return nil }
            let minX = (rect.minX * canvas.width).rounded(), maxX = (rect.maxX * canvas.width).rounded()
            let minY = (rect.minY * canvas.height).rounded(), maxY = (rect.maxY * canvas.height).rounded()
            result.append(ScreenPlacement(id: region.id, source: region.rect, rotation: settings.rotation,
                                          dest: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
                                          takesTouch: region.id == .bottom))
        }
        return result
    }

    // MARK: Turning

    /// The point of the screen's own picture shown at `(u, v)` of its rectangle, both normalized. Turn Left shows
    /// the picture a quarter turn anticlockwise.
    static func sourcePoint(u: CGFloat, v: CGFloat, rotation: ScreenRotation) -> CGPoint {
        switch rotation {
        case .none: return CGPoint(x: u, y: v)
        case .left: return CGPoint(x: 1 - v, y: u)
        case .right: return CGPoint(x: v, y: 1 - u)
        }
    }

    /// Frame UVs at the rectangle's top-left, top-right, bottom-left and bottom-right, for the crop pass.
    static func cropCorners(_ placement: ScreenPlacement) -> [SIMD2<Float>] {
        [(0, 0), (1, 0), (0, 1), (1, 1)].map { u, v in
            let p = sourcePoint(u: u, v: v, rotation: placement.rotation)
            return SIMD2(Float(placement.source.minX + p.x * placement.source.width),
                         Float(placement.source.minY + p.y * placement.source.height))
        }
    }

    // MARK: Touch

    /// False when the settings draw no bottom screen, so a finger has nothing to touch.
    static func showsTouchScreen(_ raw: ScreenSettings) -> Bool {
        let settings = raw.normalized()
        guard settings.showBottom else { return false }
        // One Screen shows the first screen only, and that is the bottom one only when swapped.
        return settings.preset != .single || !settings.showTop || settings.swapped
    }

    /// libretro's pointer, -32767 to 32767 across the whole frame, for a finger at `point` in canvas units. The
    /// topmost screen that takes touch under the finger wins. Nil anywhere else, and when no such screen shows.
    static func pointer(at point: CGPoint, placements: [ScreenPlacement]) -> (x: Int16, y: Int16)? {
        for placement in placements.reversed() where placement.takesTouch {
            let d = placement.dest
            guard d.width > 0, d.height > 0 else { continue }
            let u = (point.x - d.minX) / d.width, v = (point.y - d.minY) / d.height
            guard (0..<1).contains(u), (0..<1).contains(v) else { continue }
            let p = sourcePoint(u: u, v: v, rotation: placement.rotation)
            let fx = placement.source.minX + p.x * placement.source.width
            let fy = placement.source.minY + p.y * placement.source.height
            return (Int16((fx * 65534 - 32767).rounded()), Int16((fy * 65534 - 32767).rounded()))
        }
        return nil
    }

    // MARK: Custom layout editor

    /// The shortest side a custom screen may have, as a share of the game view's height.
    static let minimumShare: CGFloat = 0.2

    /// Why a custom layout cannot be saved, in the order to fix them. Empty means it can.
    static func problems(_ settings: ScreenSettings, canvas: CGSize) -> [String] {
        guard settings.showTop || settings.showBottom else { return ["Show at least one screen."] }
        var found: [String] = []
        for (id, rect) in [(ScreenID.top, settings.customTop), (.bottom, settings.customBottom)]
        where id == .top ? settings.showTop : settings.showBottom {
            let name = id == .top ? "top" : "bottom"
            guard let rect else { found.append("Place the \(name) screen."); continue }
            let inside = rect.minX >= -0.001 && rect.minY >= -0.001 && rect.maxX <= 1.001 && rect.maxY <= 1.001
            if !inside { found.append("Keep the whole \(name) screen on the display.") }
            let minimum = minimumShare * canvas.height
            if rect.width * canvas.width < minimum - 0.5 || rect.height * canvas.height < minimum - 0.5 {
                found.append("Make the \(name) screen larger.")
            }
        }
        return found
    }

    /// A preset's places as a share of `canvas`, to start the editor or reset it.
    static func customRects(platformID: String, canvas: CGSize, from settings: ScreenSettings) -> (top: CGRect?, bottom: CGRect?) {
        guard let frame = nominalFrame(platformID) else { return (nil, nil) }
        var source = settings
        if source.preset == .custom { source.preset = .stacked }
        source.showTop = true
        source.showBottom = true
        source.swapped = false
        source.scaling = .fit
        let placed = placements(frame: frame, canvas: canvas, platformID: platformID, settings: source)
        func share(_ id: ScreenID) -> CGRect? {
            placed.first { $0.id == id }.map {
                CGRect(x: $0.dest.minX / canvas.width, y: $0.dest.minY / canvas.height,
                       width: $0.dest.width / canvas.width, height: $0.dest.height / canvas.height)
            }
        }
        return (share(.top), share(.bottom))
    }
}
