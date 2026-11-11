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
    @State private var nearbyReason: String?

    private enum Sheet: String, Identifiable {
        case core, skin, saves, cheats, controls, edit, delete
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
                    CurrentSkinPicture(platformID: game.platformID, game: game).padding(3)
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
                let cheats = store.cheats()
                pictureRow("Cheats", value: cheats.isEmpty ? "None yet" : "\(cheats.filter(\.enabled).count) of \(cheats.count) on", id: "cheats", tile: .symbol("wand.and.stars")) { sheet = .cheats }
                pictureRow("Controls for This Game", value: nil, id: "controls", tile: .symbol("gamecontroller")) { sheet = .controls }
                let nearby = CoreCatalog.playNearbyAllowed(platformID: game.platformID, coreID: game.resolvedCoreID(defaults: state.defaultCores))
                pictureRow("Play Nearby", value: nearby ? nil : "Not available", id: "nearby", tile: .symbol("person.2")) {
                    if nearby {
                        start(.nearby)
                        dismiss()
                    } else {
                        nearbyReason = CoreCatalog.playNearbyReason(platformID: game.platformID)
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
            case .cheats:
                GameCheatsSheet(title: game.title, store: store) {
                    start(.play)
                    dismiss()
                }
            case .controls: ControlsSheet(game: game)
            case .edit: EditDetailsSheet(game: game)
            case .delete: DeleteGameSheet(game: game)
            }
        }
        .alert("Play Nearby", isPresented: Binding(get: { nearbyReason != nil }, set: { if !$0 { nearbyReason = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(nearbyReason ?? "")
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

    private func skinName(_ game: GameItem) -> String {
        let name = state.skinDrawing(platformID: game.platformID, game: game, portrait: false).name
        return game.skinID == nil && !state.hasCustomSkin(game.platformID, gameID: game.id) ? "\(name), system" : name
    }

    private func filterName(_ game: GameItem) -> String {
        let id = state.effectiveShaderID(game)
        return ShaderCatalog.all.first { $0.id == id }?.name ?? state.filters.name(of: id) ?? "Original"
    }
}

/// A game's saved cheats from its page, without starting it: switch them on or off, or remove them. New codes need
/// the running game, as its core checks each one, so Play is offered for that.
struct GameCheatsSheet: View {
    let title: String
    let store: SaveStore
    let play: () -> Void
    @State private var cheats: [CheatEntry] = []
    @State private var failure: String?

    var body: some View {
        PaperSheet(title: "Cheats", subtitle: title) {
            VStack(alignment: .leading, spacing: 0) {
                if cheats.isEmpty {
                    Text("No cheats yet.").foregroundStyle(AppTheme.muted).padding(.vertical, 12)
                }
                ForEach(cheats) { cheat in
                    HStack {
                        Toggle(cheat.name, isOn: Binding(get: { cheat.enabled }, set: { on in
                            change { list in list.indices.filter { list[$0].id == cheat.id }.forEach { list[$0].enabled = on } }
                        }))
                        .tint(AppTheme.accentFill)
                        Button { change { $0.removeAll { $0.id == cheat.id } } } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityLabel("Remove \(cheat.name)")
                    }
                    .frame(minHeight: 44)
                    Rule()
                }
                if let failure {
                    Text(failure).font(.footnote).foregroundStyle(AppTheme.accent).padding(.top, 8)
                }
                Text("To add a code, play the game, pause it and choose Cheats: the game checks each code.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                Button { play() } label: { Label("Play", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("gameCheats.play")
            }
        }
        .onAppear { cheats = store.cheats() }
    }

    /// Saved first; the list shows the change only once it is stored.
    private func change(_ edit: (inout [CheatEntry]) -> Void) {
        var next = cheats
        edit(&next)
        do {
            try store.saveCheats(next)
            cheats = next
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}
