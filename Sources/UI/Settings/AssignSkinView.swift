import SwiftUI

/// What a skin picture draws for one orientation: the controls at their places on the skin's canvas, and where the
/// game picture goes. Built from the same data the touch controls use, so a custom, imported or per-game layout and
/// a device skin look as they play.
struct SkinDrawing: Equatable {
    var buttons: [TouchSkinEngine.Button]
    /// The canvas's width over its height.
    var aspect: CGFloat
    /// The game picture's place, normalised to the canvas.
    var screens: [CGRect]

    /// A built-in layout on a platform, with that platform's sticks, C buttons or keyboard key.
    static func layout(_ layout: TouchSkinEngine.Layout, platformID: String, portrait: Bool) -> SkinDrawing {
        let landscape = layout.buttons(for: platformID)
        return classic(portrait ? TouchSkinEngine.portrait(from: landscape) : landscape, portrait: portrait)
    }

    /// A loaded skin: a flex file (custom, imported or a game's own) or a device skin.
    static func skin(_ skin: TouchSkinEngine.Skin, portrait: Bool) -> SkinDrawing {
        let buttons = portrait && !skin.portraitButtons.isEmpty ? skin.portraitButtons : skin.buttons
        if let device = skin.device {
            let face = device.face(portrait: portrait)
            return SkinDrawing(buttons: buttons, aspect: face.canvas.width / max(face.canvas.height, 1), screens: face.screens)
        }
        return classic(buttons, portrait: portrait)
    }

    /// The smallest phone's canvas, with the picture between the side bands, or above the controls upright.
    private static func classic(_ buttons: [TouchSkinEngine.Button], portrait: Bool) -> SkinDrawing {
        let canvas = portrait ? TouchSkinEngine.smallestPortraitCanvas : TouchSkinEngine.smallestCanvas
        let band = TouchSkinEngine.controlBand
        let screen = portrait
            ? CGRect(x: 0, y: 0.04, width: 1, height: TouchSkinEngine.portraitControlTop - 0.08)
            : CGRect(x: band, y: 0.03, width: 1 - 2 * band, height: 0.94)
        return SkinDrawing(buttons: buttons, aspect: canvas.width / canvas.height, screens: [screen])
    }
}

/// A miniature of a touch skin: each button, D-pad arm, stick and shoulder at its real place and shape, and the
/// game picture's area, drawn with Canvas so it stays sharp at tile size. Labels show once a button is big enough.
struct SkinThumbnail: View {
    let drawing: SkinDrawing
    /// "<skin> skin for <system>, portrait"; nil when the row around it already says so.
    var label: String?

    init(drawing: SkinDrawing, label: String? = nil) {
        self.drawing = drawing
        self.label = label
    }

    /// A built-in layout in the current orientation.
    init(layout: TouchSkinEngine.Layout, platformID: String, portrait: Bool, label: String? = nil) {
        self.init(drawing: .layout(layout, platformID: platformID, portrait: portrait), label: label)
    }

    var body: some View {
        Canvas { context, size in
            let ink = GraphicsContext.Shading.color(AppTheme.onLetterbox)
            let line = max(1, size.width / 160)
            for screen in drawing.screens {
                let rect = scaled(screen, size).insetBy(dx: line, dy: line)
                let shape = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.06)
                context.fill(shape, with: .color(AppTheme.onLetterbox.opacity(0.1)))
                context.stroke(shape, with: .color(AppTheme.onLetterbox.opacity(0.3)), lineWidth: line)
            }
            for button in drawing.buttons where button.shape != .hidden {
                let rect = scaled(button.frame, size).insetBy(dx: line / 2, dy: line / 2)
                guard rect.width > 0.5, rect.height > 0.5 else { continue }
                let face = GraphicsContext.Shading.color(AppTheme.onLetterbox.opacity(0.22))
                switch button.shape {
                case .circle:
                    context.fill(Path(ellipseIn: rect), with: face)
                    context.stroke(Path(ellipseIn: rect), with: ink, lineWidth: line)
                case .stick:
                    let ring = Path(ellipseIn: rect)
                    context.fill(ring, with: .color(AppTheme.onLetterbox.opacity(0.1)))
                    context.stroke(ring, with: ink, lineWidth: line)
                    context.fill(Path(ellipseIn: rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.28)), with: face)
                case .dpup, .dpdown, .dpleft, .dpright:
                    let arm = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.18)
                    context.fill(arm, with: face)
                    context.stroke(arm, with: ink, lineWidth: line)
                    context.fill(arrow(button.shape, in: rect), with: ink)
                default:
                    let key = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.3)
                    context.fill(key, with: face)
                    context.stroke(key, with: ink, lineWidth: line)
                }
                // Text only where it can be read; a tile shows the shapes alone.
                if rect.height >= 11, let glyph = TouchSkinEngine.label(for: button).glyph {
                    let text = Text(glyph).font(.system(size: rect.height * 0.42, weight: .semibold)).foregroundColor(AppTheme.onLetterbox)
                    let resolved = context.resolve(text)
                    if resolved.measure(in: rect.size).width <= rect.width * 0.95 {
                        context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
        }
        .aspectRatio(drawing.aspect, contentMode: .fit)
        .background(AppTheme.letterbox)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
        .accessibilityElement()
        .accessibilityLabel(label ?? "")
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(label == nil)
    }

    private func scaled(_ frame: CGRect, _ size: CGSize) -> CGRect {
        CGRect(x: frame.minX * size.width, y: frame.minY * size.height, width: frame.width * size.width, height: frame.height * size.height)
    }

    /// The small triangle on a D-pad arm, pointing out from the centre.
    private func arrow(_ shape: TouchSkinEngine.Button.Shape, in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) * 0.22
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let (tip, a, b): (CGPoint, CGPoint, CGPoint)
        switch shape {
        case .dpup: (tip, a, b) = (CGPoint(x: c.x, y: c.y - s), CGPoint(x: c.x - s, y: c.y + s * 0.6), CGPoint(x: c.x + s, y: c.y + s * 0.6))
        case .dpdown: (tip, a, b) = (CGPoint(x: c.x, y: c.y + s), CGPoint(x: c.x - s, y: c.y - s * 0.6), CGPoint(x: c.x + s, y: c.y - s * 0.6))
        case .dpleft: (tip, a, b) = (CGPoint(x: c.x - s, y: c.y), CGPoint(x: c.x + s * 0.6, y: c.y - s), CGPoint(x: c.x + s * 0.6, y: c.y + s))
        default: (tip, a, b) = (CGPoint(x: c.x + s, y: c.y), CGPoint(x: c.x - s * 0.6, y: c.y - s), CGPoint(x: c.x - s * 0.6, y: c.y + s))
        }
        var path = Path()
        path.addLines([tip, a, b])
        path.closeSubpath()
        return path
    }
}

extension AppState {
    /// The skin a game plays with (or a platform's, with no game), in the same order as `applySkin`: the device
    /// skin, the game's own edit, the custom layout, then the built-in choice. Also its name.
    func skinDrawing(platformID: String, game: GameItem?, portrait: Bool) -> (drawing: SkinDrawing, name: String) {
        if controls.file.style(platformID: platformID, gameID: game?.id) == .device,
           let root = TouchSkinEngine.deviceRoot,
           let skin = try? TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent(platformID)) {
            return (.skin(skin, portrait: portrait), "Device")
        }
        if let game, hasCustomSkin(platformID, gameID: game.id), let skin = flexSkin(customSkinURL(platformID, gameID: game.id)) {
            return (.skin(skin, portrait: portrait), "This game's own")
        }
        let platform = platformSkins[platformID]
        if (game?.skinID ?? platform) == TouchSkinEngine.customID, let skin = flexSkin(customSkinURL(platformID)) {
            return (.skin(skin, portrait: portrait), "Custom")
        }
        let id = TouchSkinEngine.layoutID(game: game?.skinID, platform: platform, platformID: platformID)
        let choices = TouchSkinEngine.Layout.choices(for: platformID)
        let layout = choices.first { $0.id == id } ?? choices.first ?? TouchSkinEngine.Layout.builtIn[0]
        return (.layout(layout, platformID: platformID, portrait: portrait), layout.name)
    }

    func flexSkin(_ url: URL) -> TouchSkinEngine.Skin? {
        (try? Data(contentsOf: url)).flatMap { try? TouchSkinEngine.decodeFlex($0, id: url.lastPathComponent) }
    }
}

/// The skin a game (or a platform) plays with now, in the current orientation: upright on a phone held upright.
struct CurrentSkinPicture: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.verticalSizeClass) private var vertical
    @Environment(\.horizontalSizeClass) private var horizontal
    let platformID: String
    var game: GameItem?
    /// Off where the row around it names the skin already.
    var labelled = false

    var body: some View {
        let upright = SkinThumbnail.upright(horizontal, vertical)
        let skin = state.skinDrawing(platformID: platformID, game: game, portrait: upright)
        SkinThumbnail(drawing: skin.drawing,
                      label: labelled ? SkinThumbnail.spoken(skin.name, platformID: platformID, upright: upright) : nil)
    }
}

extension SkinThumbnail {
    /// A phone held upright uses a skin's portrait layout; landscape and iPad use the landscape one.
    static func upright(_ horizontal: UserInterfaceSizeClass?, _ vertical: UserInterfaceSizeClass?) -> Bool {
        horizontal == .compact && vertical == .regular
    }

    static func spoken(_ name: String, platformID: String, upright: Bool) -> String {
        "\(name) skin for \(CoreCatalog.platformName(platformID)), \(upright ? "portrait" : "landscape") layout"
    }
}

/// The long-press choice for one game. Platform Default clears the game's own choice.
struct GameSkinSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vertical
    @Environment(\.horizontalSizeClass) private var horizontal
    let game: GameItem

    private var current: String? { state.games.first { $0.id == game.id }?.skinID }

    var body: some View {
        PaperSheet(title: "Assign Skin", subtitle: game.title) {
            VStack(alignment: .leading, spacing: 0) {
                choice(title: "Platform Default", note: CoreCatalog.platformName(game.platformID), layout: nil)
                Rule()
                ForEach(TouchSkinEngine.Layout.choices(for: game.platformID)) { layout in
                    choice(title: layout.name, note: layout.note, layout: layout)
                    Rule()
                }
            }
        }
    }

    private func choice(title: String, note: String, layout: TouchSkinEngine.Layout?) -> some View {
        let isSelected = current == layout?.id
        return Button {
            state.update(game.id) { $0.skinID = layout?.id }
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").opacity(isSelected ? 1 : 0).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(isSelected ? .bold : .regular)
                    Text(note).font(.footnote).foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 8)
                picture(layout).frame(width: 110, height: 64)
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The layout itself, or with none the platform's own skin (a custom or device one too).
    @ViewBuilder private func picture(_ layout: TouchSkinEngine.Layout?) -> some View {
        let upright = SkinThumbnail.upright(horizontal, vertical)
        if let layout {
            SkinThumbnail(layout: layout, platformID: game.platformID, portrait: upright,
                          label: SkinThumbnail.spoken(layout.name, platformID: game.platformID, upright: upright))
        } else {
            CurrentSkinPicture(platformID: game.platformID, labelled: true)
        }
    }
}
