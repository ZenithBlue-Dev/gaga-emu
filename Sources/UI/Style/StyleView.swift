import SwiftUI

/// The Style tab's pages: the visual choices, each shown as pictures.
enum StyleSection: String, CaseIterable, Identifiable, ShellCategory {
    case skins = "Skins", filters = "Filters", look = "Icon and Colours", layout = "Library Layout"
    var id: String { rawValue }
    var title: String { rawValue }
    var identifier: String { "style.\(rawValue)" }
    var symbol: String {
        switch self {
        case .skins: return "gamecontroller"
        case .filters: return "camera.filters"
        case .look: return "paintpalette"
        case .layout: return "square.grid.2x2"
        }
    }
}

/// Style: skins, filters, the app's icon and colours, and the Library's layout. Picking a look is browsing, so every
/// choice here is a picture.
struct StyleView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        CategoryShell(title: "Style", items: StyleSection.allCases, selection: $state.styleSection, detailTitle: state.styleSection.title) {
            EmptyView()
        } detail: {
            switch state.styleSection {
            case .skins: SkinsGallery()
            case .filters: FiltersGallery()
            case .look: AppearancePane()
            case .layout: LibraryLayoutPane()
            }
        }
    }
}

/// Every system's touch skins, drawn. A tap uses one for every game on that system; Edit opens the editor.
struct SkinsGallery: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: EditTarget?
    @Environment(\.verticalSizeClass) private var vertical
    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .footnote) private var thumbWidth: CGFloat = 150

    private struct EditTarget: Identifiable { let id: String }
    private static let deviceID = "device"

    var body: some View {
        Text("Tap a picture to use that skin for every game on the system. A game's page chooses one for that game only.")
            .font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 8)
        TipLine(tip: .editSkin).padding(.bottom, 8)
        Rule()
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(CoreCatalog.platforms) { platform in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(platform.name).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        Button("Edit") { editing = EditTarget(id: platform.id) }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityLabel("Edit \(platform.name) skin")
                    }
                    // At accessibility sizes a list, so no card grows past the others.
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) { choices(platform) }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 10) { choices(platform) }.padding(.vertical, 2)
                        }
                    }
                    SkinStyleRows(platformID: platform.id)
                }
                .padding(.vertical, 8)
                Rule()
            }
        }
        .fullScreenCover(item: $editing) { SkinEditorView(platformID: $0.id) }
    }

    @ViewBuilder private func choices(_ platform: PlatformInfo) -> some View {
        ForEach(TouchSkinEngine.Layout.choices(for: platform.id)) { layout in
            choice(platform, id: layout.id, name: layout.name) {
                SkinThumbnail(layout: layout, platformID: platform.id, portrait: upright)
            }
        }
        if state.hasCustomSkin(platform.id), let skin = state.flexSkin(state.customSkinURL(platform.id)) {
            choice(platform, id: TouchSkinEngine.customID, name: "Custom") {
                SkinThumbnail(drawing: .skin(skin, portrait: upright))
            }
        }
        if let device = state.deviceDrawing(platformID: platform.id, portrait: upright) {
            choice(platform, id: Self.deviceID, name: "Device") { SkinThumbnail(drawing: device) }
        }
    }

    private func choice<Picture: View>(_ platform: PlatformInfo, id: String, name: String, @ViewBuilder picture: () -> Picture) -> some View {
        let selected = current(platform.id) == id
        return Button { choose(id, platformID: platform.id) } label: {
            // Upright the frame is tall, as the upright layouts are. Every card on the strip has this one shape.
            ChoiceCard(title: name, aspect: upright ? 0.55 : 2, selected: selected, picture: picture)
                .frame(width: typeSize.isAccessibilitySize ? nil : min(thumbWidth, 220) * (upright ? 0.7 : 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(platform.name) skin: \(name), \(upright ? "portrait" : "landscape") layout")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Device sets the system's Skin Style; a layout sets Classic and that layout.
    private func choose(_ id: String, platformID: String) {
        let key = "platform:\(platformID)"
        if id == Self.deviceID {
            state.controls.file.skinStyle[key] = SkinStyle.device.rawValue
        } else {
            state.controls.file.skinStyle[key] = nil
            state.platformSkins[platformID] = id
        }
    }

    private var upright: Bool { SkinThumbnail.upright(horizontal, vertical) }

    /// Device while the system uses it; Custom only while its file exists; otherwise the platform's built-in choice.
    private func current(_ platformID: String) -> String {
        if state.controls.file.style(platformID: platformID, gameID: nil) == .device { return Self.deviceID }
        let chosen = state.platformSkins[platformID]
        return chosen == TouchSkinEngine.customID && state.hasCustomSkin(platformID)
            ? TouchSkinEngine.customID
            : TouchSkinEngine.layoutID(game: nil, platform: chosen, platformID: platformID)
    }
}

/// The default filter as a grid of each filter's own picture. The studio has sliders, compare, presets and import.
struct FiltersGallery: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @State private var studio = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var tileMin: CGFloat = 104

    private var currentName: String {
        ShaderCatalog.all.first { $0.id == state.shaderID }?.name ?? state.filters.name(of: state.shaderID) ?? "Original"
    }

    var body: some View {
        HStack(spacing: 12) {
            OptionTile(label: "Filter preview: \(currentName)") { FilterPicture(shaderID: state.shaderID) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Default Filter")
                Text(currentName).font(.meta).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        Button("Open Filter Studio") { studio = true }
            .buttonStyle(QuietButtonStyle())
            .accessibilityHint("Sliders, before and after, presets, search and importing filters")
        Text("New games start with this filter. A game's page and its pause menu choose one for that game.")
            .font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 8)
        Rule()
        LazyVGrid(columns: choiceColumns(minimum: min(tileMin, 180), large: typeSize.isAccessibilitySize), spacing: 12) {
            ForEach(ShaderCatalog.all) { tile($0) }
        }
        .padding(.top, 10)
        .fullScreenCover(isPresented: $studio) { FilterPickerView() }
    }

    private func tile(_ shader: ShaderCatalog.Shader) -> some View {
        let locked = shader.premium && !store.canUseShader(shader.id)
        let selected = state.shaderID == shader.id
        return Button { if locked { studio = true } else { state.shaderID = shader.id } } label: {
            ChoiceCard(title: shader.name, detail: locked ? "Gaga Plus" : nil, reservesDetail: PaywallGate.isOpen,
                       aspect: 4.0 / 3.0, selected: selected) { FilterPicture(shaderID: shader.id) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filter preview: \(shader.name)\(locked ? ", needs Gaga Plus" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("styleFilter.\(shader.id)")
    }
}
