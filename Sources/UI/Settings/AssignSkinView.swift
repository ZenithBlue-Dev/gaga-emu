import SwiftUI

/// What a skin picture draws for one orientation: the controls at their places on the skin's canvas, and where the
/// game picture goes. Built from the same data the touch controls use, so a custom, imported or per-game layout and
/// a device skin look as they play.
struct SkinDrawing: Equatable {
    var buttons: [TouchSkinEngine.Button]
    /// The canvas in points: the smallest phone's safe area for a classic skin, a device skin's own canvas.
    var canvas: CGSize
    /// The game picture's place, normalised to the canvas.
    var screens: [CGRect]
    /// The controls' opacity in game.
    var opacity = TouchSkinEngine.defaultOpacity
    /// A device skin's face in its chosen colourway, and the folder its PDFs are in.
    var face: TouchSkinEngine.DeviceArt.Face?
    var folder: URL?
    /// An imported package's own art for this orientation, drawn in place of the controls.
    var art: UIImage?

    /// The canvas's width over its height.
    var aspect: CGFloat { canvas.width / max(canvas.height, 1) }

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
            return SkinDrawing(buttons: buttons, canvas: face.canvas, screens: face.screens, opacity: 1, face: face, folder: device.folder)
        }
        var drawing = classic(buttons, portrait: portrait)
        drawing.opacity = skin.opacity
        drawing.art = skin.artImage(portrait: portrait)
        return drawing
    }

    /// The smallest phone's canvas, with the picture between the side bands, or above the controls upright, as
    /// `GameView` places it.
    private static func classic(_ buttons: [TouchSkinEngine.Button], portrait: Bool) -> SkinDrawing {
        let canvas = portrait ? TouchSkinEngine.smallestPortraitCanvas : TouchSkinEngine.smallestCanvas
        let band = TouchSkinEngine.controlBand
        let screen = portrait
            ? CGRect(x: 0, y: 0, width: 1, height: TouchSkinEngine.portraitControlTop)
            : CGRect(x: band, y: 0, width: 1 - 2 * band, height: 1)
        return SkinDrawing(buttons: buttons, canvas: canvas, screens: [screen])
    }
}

/// A made-up game scene for skin pictures: sky, sun, hills, ground and a figure, drawn here, at a 3:2 screen's shape.
struct SampleGamePicture: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(rgb: 0x3A7BD5), Color(rgb: 0x8FD3F4)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.74, y: h * 0.1, width: h * 0.16, height: h * 0.16)), with: .color(Color(rgb: 0xFFE066)))
            var hills = Path()
            hills.move(to: CGPoint(x: 0, y: h * 0.72))
            hills.addCurve(to: CGPoint(x: w, y: h * 0.66), control1: CGPoint(x: w * 0.3, y: h * 0.48), control2: CGPoint(x: w * 0.6, y: h * 0.8))
            hills.addLine(to: CGPoint(x: w, y: h)); hills.addLine(to: CGPoint(x: 0, y: h)); hills.closeSubpath()
            context.fill(hills, with: .color(Color(rgb: 0x4CAF50)))
            let ground = h * 0.8, block = h * 0.1
            for i in 0..<Int(w / block + 1) {
                context.fill(Path(CGRect(x: CGFloat(i) * block, y: ground, width: block, height: h - ground)),
                             with: .color(Color(rgb: i % 2 == 0 ? 0xA0522D : 0x8B4513)))
            }
            context.fill(Path(roundedRect: CGRect(x: w * 0.3, y: ground - block * 1.6, width: block, height: block * 1.6), cornerRadius: block * 0.2),
                         with: .color(Color(rgb: 0xE4572E)))
            for i in 0..<3 {
                context.fill(Path(CGRect(x: w * (0.52 + 0.08 * CGFloat(i)), y: h * 0.42, width: block, height: block)), with: .color(Color(rgb: 0xF2C14E)))
            }
        }
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
    }
}

/// A touch skin as it looks in game, at picture size: the game's own touch controls (`TouchButtonFace`) at the skin's
/// opacity over a sample game picture, laid out on the skin's canvas and scaled down; a device skin's shell, colourway
/// and labels; or an imported skin's own art.
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
        GeometryReader { box in
            Group {
                if let face = drawing.face, let folder = drawing.folder {
                    device(face, folder: folder, size: box.size)
                } else {
                    // Laid out at the phone's size, so every font and stroke is the game's, then scaled to the box.
                    classic
                        .frame(width: drawing.canvas.width, height: drawing.canvas.height)
                        .scaleEffect(box.size.width / max(drawing.canvas.width, 1), anchor: .topLeading)
                }
            }
            .frame(width: box.size.width, height: box.size.height, alignment: .topLeading)
        }
        .aspectRatio(drawing.aspect, contentMode: .fit)
        .background(AppTheme.letterbox)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
        .drawingGroup()
        .accessibilityElement()
        .accessibilityLabel(label ?? "")
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(label == nil)
    }

    private var classic: some View {
        let size = drawing.canvas
        return ZStack(alignment: .topLeading) {
            if let art = drawing.art {
                Image(uiImage: art).resizable().frame(width: size.width, height: size.height)
            }
            ForEach(drawing.screens.indices, id: \.self) { index in
                let r = Self.place(drawing.screens[index], in: CGRect(origin: .zero, size: size))
                SampleGamePicture().frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
            }
            // An imported skin's art carries its own buttons.
            if drawing.art == nil {
                ForEach(drawing.buttons.filter { $0.shape != .hidden }) { button in
                    TouchButtonFace(button: button, label: button.showsLabel ? TouchSkinEngine.label(for: button).glyph : nil)
                        .opacity(drawing.opacity * (button.opacity ?? 1))
                        .frame(width: button.frame.width * size.width, height: button.frame.height * size.height)
                        .position(x: button.frame.midX * size.width, y: button.frame.midY * size.height)
                }
            }
        }
    }

    /// The shell PDF in its colourway on the fill colour, the picture in its screens and the labels, as `DeviceSkinView` draws them.
    private func device(_ face: TouchSkinEngine.DeviceArt.Face, folder: URL, size: CGSize) -> some View {
        let box = CGRect(origin: .zero, size: size)
        let k = size.width / max(face.canvas.width, 1)
        return ZStack(alignment: .topLeading) {
            DeviceSkinView.color(face.fill)
            if let image = DevicePDF.image(folder.appendingPathComponent(face.background), size: size) {
                Image(uiImage: image).resizable().frame(width: size.width, height: size.height)
            }
            ForEach(face.screens.indices, id: \.self) { index in
                let r = Self.place(face.screens[index], in: box)
                ZStack { AppTheme.letterbox; SampleGamePicture() }
                    .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
            }
            ForEach(face.labels.indices, id: \.self) { index in
                let label = face.labels[index]
                Text(label.text)
                    .font(.system(size: label.size * k, weight: .heavy, design: .rounded))
                    .foregroundStyle(DeviceSkinView.color(label.onBody == true ? face.ink : label.color))
                    .fixedSize()
                    .position(x: label.x * size.width, y: label.y * size.height)
            }
        }
    }

    private static func place(_ rect: CGRect, in box: CGRect) -> CGRect {
        CGRect(x: box.minX + rect.minX * box.width, y: box.minY + rect.minY * box.height,
               width: rect.width * box.width, height: rect.height * box.height)
    }
}

extension AppState {
    /// The skin a game plays with (or a platform's, with no game), in the same order as `applySkin`: the device
    /// skin, the game's own edit, the custom layout, then the built-in choice. Also its name.
    func skinDrawing(platformID: String, game: GameItem?, portrait: Bool) -> (drawing: SkinDrawing, name: String) {
        if controls.file.style(platformID: platformID, gameID: game?.id) == .device,
           let device = deviceDrawing(platformID: platformID, portrait: portrait) {
            return (device, "Device")
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

    /// A platform's device skin in the colourway its players chose. Nil where the platform has none.
    func deviceDrawing(platformID: String, portrait: Bool) -> SkinDrawing? {
        guard let root = TouchSkinEngine.deviceRoot, TouchSkinEngine.hasDevice(platformID, root: root),
              var skin = try? TouchSkinEngine.decodeDevice(folder: root.appendingPathComponent(platformID)) else { return nil }
        skin.device?.variant = controls.file.skinVariant[platformID]
        return .skin(skin, portrait: portrait)
    }

    func flexSkin(_ url: URL) -> TouchSkinEngine.Skin? {
        guard var skin = (try? Data(contentsOf: url)).flatMap({ try? TouchSkinEngine.decodeFlex($0, id: url.lastPathComponent) }) else { return nil }
        skin.assets = TouchSkinEngine.savedArt(beside: url)
        return skin
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
