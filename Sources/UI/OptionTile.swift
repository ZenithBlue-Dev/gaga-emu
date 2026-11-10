import SwiftUI

/// The picture at the leading edge of a row or a choice: 56 pt, 40 pt in compact height, growing with Dynamic Type.
/// Every picture is drawn by the app. With no `label` it is decorative and hidden from VoiceOver, and the row's own
/// text carries the meaning; with one, VoiceOver reads it as an image.
struct OptionTile<Picture: View>: View {
    var label: String?
    var dimmed = false
    @ViewBuilder var picture: Picture
    @Environment(\.verticalSizeClass) private var verticalSize
    @ScaledMetric(relativeTo: .body) private var regularSide: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var compactSide: CGFloat = 40

    var body: some View {
        let side = min(verticalSize == .compact ? compactSide : regularSide, 112)
        let shape = RoundedRectangle(cornerRadius: AppTheme.corner + 4)
        picture
            .frame(width: side, height: side)
            .background(AppTheme.surface)
            .clipShape(shape)
            .overlay(shape.stroke(AppTheme.rule, lineWidth: 1))
            .opacity(dimmed ? 0.45 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label ?? "")
            .accessibilityAddTraits(.isImage)
            .accessibilityHidden(label == nil)
    }
}

extension OptionTile where Picture == SymbolPicture {
    init(symbol: String, label: String? = nil, dimmed: Bool = false) {
        self.init(label: label, dimmed: dimmed) { SymbolPicture(symbol: symbol) }
    }
}

/// An SF Symbol in the accent colour on the tile's surface: the pair passes AA in both appearances.
struct SymbolPicture: View {
    let symbol: String
    var body: some View {
        GeometryReader { box in
            Image(systemName: symbol)
                .font(.system(size: box.size.width * 0.42, weight: .regular))
                .foregroundStyle(AppTheme.accent)
                .frame(width: box.size.width, height: box.size.height)
        }
    }
}

/// A row's picture, kept type-erased so `ValueRow`, `ToggleRow` and `ActionRow` take one optional parameter.
struct RowTile {
    let picture: AnyView
    var label: String?

    static func symbol(_ name: String) -> RowTile { RowTile(picture: AnyView(SymbolPicture(symbol: name))) }

    static func picture<V: View>(_ label: String? = nil, @ViewBuilder _ content: () -> V) -> RowTile {
        RowTile(picture: AnyView(content()), label: label)
    }
}

/// Puts a row's tile before its text, or above it at accessibility text sizes, so the text never shrinks.
struct TiledRow<Content: View>: View {
    let tile: RowTile?
    var dimmed = false
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let tile {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            // The tile is hidden inside a row, so the row's label starts with its title; the alt text is the hint.
            let row = layout {
                OptionTile(dimmed: dimmed) { tile.picture }
                content
            }
            if let label = tile.label { row.accessibilityHint(label) } else { row }
        } else {
            content
        }
    }
}

// MARK: - Drawings

/// A paper frame with the game picture drawn at a scaling mode: Fit, Stretch, Whole Pixels or Zoom.
struct ScalingPicture: View {
    let mode: ScalingMode

    var body: some View {
        GeometryReader { box in
            let w = box.size.width, h = box.size.height
            let frame = CGRect(x: w * 0.12, y: h * 0.22, width: w * 0.76, height: h * 0.56)
            // A 4:3 picture in a wider frame.
            let picture: CGRect = switch mode {
            case .fit: CGRect(x: frame.midX - frame.height * 0.667, y: frame.minY, width: frame.height * 1.333, height: frame.height)
            case .stretch: frame
            case .integer: CGRect(x: frame.midX - frame.height * 0.5, y: frame.midY - frame.height * 0.375, width: frame.height, height: frame.height * 0.75)
            case .zoom: frame.insetBy(dx: -w * 0.04, dy: -h * 0.12)
            }
            ZStack {
                Rectangle().fill(AppTheme.letterbox).frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
                Rectangle().fill(AppTheme.accent.opacity(0.85))
                    .frame(width: picture.width, height: picture.height).position(x: picture.midX, y: picture.midY)
                    .mask(Rectangle().frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY))
                if mode == .integer {
                    // Pixel grid, so whole pixels read as whole pixels.
                    Path { path in
                        for i in 1..<4 {
                            let x = picture.minX + picture.width * CGFloat(i) / 4
                            path.move(to: CGPoint(x: x, y: picture.minY)); path.addLine(to: CGPoint(x: x, y: picture.maxY))
                            let y = picture.minY + picture.height * CGFloat(i) / 4
                            path.move(to: CGPoint(x: picture.minX, y: y)); path.addLine(to: CGPoint(x: picture.maxX, y: y))
                        }
                    }
                    .stroke(AppTheme.surface.opacity(0.6), lineWidth: 0.5)
                }
                RoundedRectangle(cornerRadius: 2).stroke(AppTheme.ink, lineWidth: 1)
                    .frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
            }
        }
    }

    static func effect(_ mode: ScalingMode) -> String {
        switch mode {
        case .fit: return "as large as fits, in its own shape"
        case .stretch: return "fills the area and changes shape"
        case .integer: return "every pixel the same size"
        case .zoom: return "fills the area, edges cut off"
        }
    }
}

/// Two screens in a dual-screen preset's arrangement.
struct DualLayoutPicture: View {
    let preset: DualPreset

    var body: some View {
        GeometryReader { box in
            let w = box.size.width, h = box.size.height
            let rects: [CGRect] = switch preset {
            case .stacked: [CGRect(x: 0.3, y: 0.12, width: 0.4, height: 0.36), CGRect(x: 0.3, y: 0.52, width: 0.4, height: 0.36)]
            case .sideBySide: [CGRect(x: 0.08, y: 0.32, width: 0.4, height: 0.36), CGRect(x: 0.52, y: 0.32, width: 0.4, height: 0.36)]
            case .largeTop: [CGRect(x: 0.08, y: 0.2, width: 0.6, height: 0.6), CGRect(x: 0.72, y: 0.6, width: 0.2, height: 0.2)]
            case .largeBottom: [CGRect(x: 0.72, y: 0.2, width: 0.2, height: 0.2), CGRect(x: 0.08, y: 0.2, width: 0.6, height: 0.6)]
            case .single: [CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.5)]
            case .hybrid: [CGRect(x: 0.08, y: 0.2, width: 0.6, height: 0.6), CGRect(x: 0.72, y: 0.2, width: 0.2, height: 0.28), CGRect(x: 0.72, y: 0.52, width: 0.2, height: 0.28)]
            case .custom: [CGRect(x: 0.12, y: 0.18, width: 0.45, height: 0.4), CGRect(x: 0.45, y: 0.5, width: 0.42, height: 0.34)]
            }
            ZStack {
                ForEach(Array(rects.enumerated()), id: \.offset) { index, rect in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index == 0 ? AppTheme.accent.opacity(0.85) : AppTheme.muted.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(AppTheme.ink, lineWidth: 1))
                        .frame(width: rect.width * w, height: rect.height * h)
                        .position(x: rect.midX * w, y: rect.midY * h)
                }
            }
        }
    }
}

/// A mini shelf drawn at the Library's chosen layout: games per row, cover style, corner, square covers and titles.
struct ShelfPicture: View {
    let display: LibraryDisplay

    var body: some View {
        GeometryReader { box in
            let count = display.perRow == 0 ? 3 : display.perRow
            let gap = box.size.width * 0.04
            let tile = (box.size.width - gap * CGFloat(count + 1)) / CGFloat(count)
            let coverHeight = display.square ? tile : tile * 1.35
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: display.corner * tile / 120)
                                .fill(AppTheme.muted.opacity(0.35 + 0.1 * Double(index % 3)))
                            if display.coverStyle == .spine {
                                Rectangle().fill(AppTheme.accent).frame(width: max(2, tile * 0.08))
                            }
                        }
                        .frame(width: tile, height: coverHeight)
                        .clipShape(RoundedRectangle(cornerRadius: display.corner * tile / 120))
                        .overlay {
                            if display.coverStyle == .framed {
                                RoundedRectangle(cornerRadius: display.corner * tile / 120).stroke(AppTheme.ink, lineWidth: 1)
                            }
                        }
                        if !display.hideTitle {
                            Capsule().fill(AppTheme.ink.opacity(0.7)).frame(width: tile * 0.8, height: max(2, tile * 0.07))
                        }
                        if !display.hideDetails {
                            Capsule().fill(AppTheme.muted.opacity(0.7)).frame(width: tile * 0.5, height: max(2, tile * 0.05))
                        }
                    }
                }
            }
            .padding(.horizontal, gap)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, gap)
        }
    }

    static func description(_ display: LibraryDisplay) -> String {
        let row = display.perRow == 0 ? "one sideways row" : "\(display.perRow) per row"
        return "Shelf preview: \(row), \(display.coverStyle.label) covers\(display.square ? ", square" : "")"
    }
}

/// A file glyph with its state: found, missing or optional.
struct FilePicture: View {
    let found: Bool
    var optional = false

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "doc.fill").font(.system(size: box.size.width * 0.42)).foregroundStyle(AppTheme.muted)
                    .frame(width: box.size.width, height: box.size.height)
                Image(systemName: found ? "checkmark.circle.fill" : optional ? "minus.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: box.size.width * 0.28, weight: .bold))
                    .foregroundStyle(found ? AppTheme.ink : AppTheme.accent)
                    .padding(box.size.width * 0.1)
            }
        }
    }
}

/// A system's spine colour with its short code, for a core row.
struct PlatformPicture: View {
    let platformID: String

    var body: some View {
        HStack(spacing: 0) {
            AppTheme.spine(platformID).frame(width: 8)
            Text(CoreCatalog.platformCode(platformID))
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .minimumScaleFactor(0.5).lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The app's look in one appearance: a paper page with ink lines, or the dark version.
struct AppearancePicture: View {
    let mode: AppearanceMode

    var body: some View {
        GeometryReader { box in
            let half = box.size.width / 2
            ZStack(alignment: .leading) {
                switch mode {
                case .light: swatch(paper: Palette.paper.light, ink: Palette.ink.light)
                case .dark: swatch(paper: Palette.paper.dark, ink: Palette.ink.dark)
                case .system:
                    HStack(spacing: 0) {
                        swatch(paper: Palette.paper.light, ink: Palette.ink.light).frame(width: half)
                        swatch(paper: Palette.paper.dark, ink: Palette.ink.dark).frame(width: half)
                    }
                }
            }
        }
    }

    private func swatch(paper: Int, ink: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Color(rgb: paper)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(Color(rgb: ink)).frame(height: 3)
                Capsule().fill(Color(rgb: ink).opacity(0.6)).frame(height: 3).padding(.trailing, 8)
                Capsule().fill(AppTheme.accentFill).frame(width: 12, height: 3)
            }
            .padding(8)
        }
    }
}

extension Color {
    /// A fixed sRGB colour from a 0xRRGGBB value.
    init(rgb: Int) {
        self.init(red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

/// A filter's own picture: the catalogue tile, rendered once and cached, on the current preview picture.
struct FilterPicture: View {
    let shaderID: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFill()
            } else {
                SymbolPicture(symbol: "camera.filters")
            }
        }
        .task(id: shaderID) {
            await Task.yield()
            image = ShaderManager.shared.cachedTile(presetID: shaderID)
        }
    }
}

/// A save state's own screenshot.
struct SaveStatePicture: View {
    let slot: SaveSlot?

    var body: some View {
        if let slot, let image = UIImage(contentsOfFile: slot.thumbnailURL.path) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFill()
        } else {
            SymbolPicture(symbol: "tray.full")
        }
    }
}
