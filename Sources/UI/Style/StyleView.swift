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
    @ScaledMetric(relativeTo: .footnote) private var thumbWidth: CGFloat = 132

    private struct EditTarget: Identifiable { let id: String }

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(TouchSkinEngine.Layout.choices(for: platform.id)) { layout in
                                choice(platform, id: layout.id, name: layout.name) {
                                    SkinThumbnail(layout: layout, platformID: platform.id, portrait: upright)
                                }
                            }
                            if state.hasCustomSkin(platform.id) {
                                if let skin = state.flexSkin(state.customSkinURL(platform.id)) {
                                    choice(platform, id: TouchSkinEngine.customID, name: "Custom") {
                                        SkinThumbnail(drawing: .skin(skin, portrait: upright))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    SkinStyleRows(platformID: platform.id)
                }
                .padding(.vertical, 8)
                Rule()
            }
        }
        .fullScreenCover(item: $editing) { SkinEditorView(platformID: $0.id) }
    }

    private func choice<Picture: View>(_ platform: PlatformInfo, id: String, name: String, @ViewBuilder picture: () -> Picture) -> some View {
        let selected = current(platform.id) == id
        return Button { state.platformSkins[platform.id] = id } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Upright the box is tall, as the upright layouts are.
                picture()
                    .frame(width: min(thumbWidth, 220), height: min(thumbWidth, 220) * (upright ? 1.2 : 0.6))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(selected ? AppTheme.ink : AppTheme.rule, lineWidth: selected ? 2 : 1))
                HStack(spacing: 2) {
                    if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                    Text(name).font(.caption).fontWeight(selected ? .bold : .regular).lineLimit(2)
                }
            }
            .frame(width: min(thumbWidth, 220), alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(platform.name) skin: \(name), \(upright ? "portrait" : "landscape") layout")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var upright: Bool { SkinThumbnail.upright(horizontal, vertical) }

    /// Custom shows only while its file exists; otherwise the platform's built-in choice.
    private func current(_ platformID: String) -> String {
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(tileMin, 180)), spacing: 10)], spacing: 12) {
            ForEach(ShaderCatalog.all) { tile($0) }
        }
        .padding(.top, 10)
        .fullScreenCover(isPresented: $studio) { FilterPickerView() }
    }

    private func tile(_ shader: ShaderCatalog.Shader) -> some View {
        let locked = shader.premium && !store.canUseShader(shader.id)
        let selected = state.shaderID == shader.id
        return Button { if locked { studio = true } else { state.shaderID = shader.id } } label: {
            VStack(alignment: .leading, spacing: 4) {
                FilterPicture(shaderID: shader.id)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(selected ? AppTheme.ink : AppTheme.rule, lineWidth: selected ? 2 : 1))
                HStack(spacing: 2) {
                    if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                    if locked { Image(systemName: "lock").font(.caption2) }
                    Text(shader.name).font(.caption).fontWeight(selected ? .bold : .regular).lineLimit(2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filter preview: \(shader.name)\(locked ? ", needs Gaga Plus" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("styleFilter.\(shader.id)")
    }
}
