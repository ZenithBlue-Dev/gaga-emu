import SwiftUI

/// What the Game page asks the Library to do once the page has gone: a game view cannot present over a sheet.
enum GamePageStart: Equatable {
    case play, startOver, slot(SaveSlot), nearby
}

/// A game's own page, from a tap on its cover: play, and every choice for this game, each with its picture. Touch and
/// hold on a cover keeps the same actions as a menu.
struct GamePage: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let game: GameItem
    /// Called before the page dismisses itself; the Library starts the game once it has gone.
    let start: (GamePageStart) -> Void
    @State private var sheet: Sheet?
    @State private var filtering = false

    private enum Sheet: String, Identifiable {
        case core, skin, saves, controls, edit, delete
        var id: String { rawValue }
    }

    /// The live entry: the page's copy is from when it opened.
    private var live: GameItem? { state.games.first { $0.id == game.id } }

    var body: some View {
        let game = live ?? self.game
        let store = state.saveStore(for: game)
        let slots = store.slots()
        let resume = state.autoSaveEnabled ? store.autoSlot : nil
        PaperSheet(title: game.title, subtitle: CoreCatalog.platformName(game.platformID)) {
            VStack(alignment: .leading, spacing: 0) {
                header(game, resume: resume)
                Rule().padding(.top, 12)
                pictureRow("Skin", value: skinName(game), id: "skin", tile: .picture("\(CoreCatalog.platformName(game.platformID)) skin: \(skinName(game))") {
                    SkinThumbnail(layout: skinLayout(game)).padding(3)
                }) { sheet = .skin }
                pictureRow("Filter", value: filterName(game), id: "filter", tile: .picture("Filter preview: \(filterName(game))") {
                    FilterPicture(shaderID: state.effectiveShaderID(game))
                }) { filtering = true }
                pictureRow("Core", value: state.coreName(for: game), id: "core", tile: .picture("\(state.coreName(for: game)) for \(CoreCatalog.platformName(game.platformID))") {
                    PlatformPicture(platformID: game.platformID)
                }) { sheet = .core }
                pictureRow("Save States", value: slots.isEmpty ? "None yet" : "\(slots.count)", id: "saves", tile: .picture(slots.first.map { "Save state, \($0.date.formatted(date: .abbreviated, time: .shortened))" }) {
                    SaveStatePicture(slot: slots.first)
                }) { sheet = .saves }
                if slots.count > 1 { saveStrip(Array(slots.prefix(3))) }
                pictureRow("Cheats", value: "In the pause menu", id: "cheats", tile: .symbol("wand.and.stars")) { start(.play); dismiss() }
                    .accessibilityHint("Starts the game. Pause it, then choose Cheats.")
                pictureRow("Controls for This Game", value: nil, id: "controls", tile: .symbol("gamecontroller")) { sheet = .controls }
                if CoreCatalog.playNearbyAllowed(platformID: game.platformID, coreID: game.resolvedCoreID(defaults: state.defaultCores)) {
                    pictureRow("Play Nearby", value: nil, id: "nearby", tile: .symbol("person.2")) {
                        start(.nearby)
                        dismiss()
                    }
                }
                pictureRow("Edit Details", value: nil, id: "edit", tile: .symbol("pencil")) { sheet = .edit }
                Button(role: .destructive) { sheet = .delete } label: {
                    Label("Delete", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
                .accessibilityIdentifier("gamePage.delete")
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .core: CorePickerSheet(game: game)
            case .skin: GameSkinSheet(game: game)
            case .saves:
                ManageSavesSheet(title: game.title, store: store) { slot in
                    start(.slot(slot))
                    dismiss()
                }
            case .controls: ControlsSheet(game: game)
            case .edit: EditDetailsSheet(game: game)
            case .delete: DeleteGameSheet(game: game)
            }
        }
        .fullScreenCover(isPresented: $filtering) { FilterPickerView(game: game) }
        // Deleted from its own page: nothing is left to show.
        .onChange(of: live == nil) { _, gone in if gone { dismiss() } }
    }

    private func header(_ game: GameItem, resume: SaveSlot?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                CoverArt(game: game, width: 110)
                details(game, resume: resume)
            }
            VStack(alignment: .leading, spacing: 12) {
                CoverArt(game: game, width: 110)
                details(game, resume: resume)
            }
        }
    }

    private func details(_ game: GameItem, resume: SaveSlot?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CoreCatalog.playTime(game.playTime)).font(.meta).foregroundStyle(AppTheme.muted)
            Text(game.lastPlayed.map { "Last played " + $0.formatted(.relative(presentation: .named)) } ?? "Not played yet")
                .font(.meta).foregroundStyle(AppTheme.muted)
            if let resume {
                Button { start(.slot(resume)); dismiss() } label: { Label("Resume", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Resume \(game.title)")
                    .accessibilityIdentifier("gamePage.resume")
                Button("Start Over") { start(.startOver); dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityHint("Uses the game's own save, and replaces the auto save when you next leave the game.")
                    .accessibilityIdentifier("gamePage.startOver")
            } else {
                Button { start(.startOver); dismiss() } label: { Label("Play", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Play \(game.title)")
                    .accessibilityIdentifier("gamePage.play")
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
    }

    private func pictureRow(_ title: String, value: String?, id: String, tile: RowTile, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            ActionRow(title: title, value: value, tile: tile, action: action)
                .accessibilityIdentifier("gamePage.\(id)")
            Rule()
        }
    }

    /// The latest three save states' own pictures, newest first.
    private func saveStrip(_ slots: [SaveSlot]) -> some View {
        HStack(spacing: 8) {
            ForEach(slots) { slot in
                Button { start(.slot(slot)); dismiss() } label: {
                    SaveStatePicture(slot: slot)
                        .frame(width: 96, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Load save state, \(slot.date.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .padding(.vertical, 8)
    }

    private func skinLayout(_ game: GameItem) -> TouchSkinEngine.Layout {
        let id = TouchSkinEngine.layoutID(game: game.skinID, platform: state.platformSkins[game.platformID], platformID: game.platformID)
        let choices = TouchSkinEngine.Layout.choices(for: game.platformID)
        return choices.first { $0.id == id } ?? choices.first ?? TouchSkinEngine.Layout.builtIn[0]
    }

    private func skinName(_ game: GameItem) -> String {
        if game.skinID == nil, state.platformSkins[game.platformID] == TouchSkinEngine.customID, state.hasCustomSkin(game.platformID) { return "Custom" }
        return game.skinID == nil ? "\(skinLayout(game).name), system" : skinLayout(game).name
    }

    private func filterName(_ game: GameItem) -> String {
        let id = state.effectiveShaderID(game)
        return ShaderCatalog.all.first { $0.id == id }?.name ?? state.filters.name(of: id) ?? "Original"
    }
}
