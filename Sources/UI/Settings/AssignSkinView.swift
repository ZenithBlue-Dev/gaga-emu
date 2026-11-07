import SwiftUI

/// A small drawing of a touch layout, from its button frames.
struct SkinThumbnail: View {
    let layout: TouchSkinEngine.Layout

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                AppTheme.letterbox
                ForEach(layout.buttons.filter { $0.shape != .hidden }) { button in
                    Group {
                        if button.shape == .circle {
                            Circle().stroke(AppTheme.onLetterbox, lineWidth: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 2).stroke(AppTheme.onLetterbox, lineWidth: 1)
                        }
                    }
                    .frame(width: button.frame.width * geometry.size.width, height: button.frame.height * geometry.size.height)
                    .position(x: button.frame.midX * geometry.size.width, y: button.frame.midY * geometry.size.height)
                }
            }
        }
        .aspectRatio(2.1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
        .accessibilityHidden(true)
    }
}

/// Settings > Controls: the touch layout for each platform, drawn so the choice is visible.
struct AssignSkinView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        PaperSheet(title: "Assign Skin") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(TouchSkinEngine.Layout.builtIn) { layout in
                        VStack(alignment: .leading, spacing: 4) {
                            SkinThumbnail(layout: layout)
                            Text(layout.name).font(.footnote.weight(.semibold))
                            Text(layout.note).font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 12)
                Text("Touch and hold a game in the library to choose a skin for that game only.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 8)
                Rule()
                ForEach(CoreCatalog.platforms) { platform in
                    HStack {
                        Text(platform.name)
                        Spacer(minLength: 12)
                        Picker(platform.name, selection: skin(platform.id)) {
                            ForEach(TouchSkinEngine.Layout.choices(for: platform.id)) { Text($0.name).tag($0.id) }
                            if state.hasCustomSkin(platform.id) { Text("Custom").tag(TouchSkinEngine.customID) }
                        }
                        .labelsHidden()
                        Button("Edit") { editing = EditTarget(id: platform.id) }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityLabel("Edit \(platform.name) skin")
                    }
                    .frame(minHeight: 44)
                    Rule()
                }
            }
        }
        .fullScreenCover(item: $editing) { SkinEditorView(platformID: $0.id) }
    }

    @State private var editing: EditTarget?
    private struct EditTarget: Identifiable { let id: String }

    /// Custom shows only while its file exists; otherwise the platform's built-in choice.
    private func skin(_ platformID: String) -> Binding<String> {
        Binding(get: {
                    let chosen = state.platformSkins[platformID]
                    return chosen == TouchSkinEngine.customID && state.hasCustomSkin(platformID)
                        ? TouchSkinEngine.customID
                        : TouchSkinEngine.layoutID(game: nil, platform: chosen, platformID: platformID)
                },
                set: { state.platformSkins[platformID] = $0 })
    }
}

/// The long-press choice for one game. Platform Default clears the game's own choice.
struct GameSkinSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
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
                if let layout { SkinThumbnail(layout: layout).frame(width: 110) }
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
