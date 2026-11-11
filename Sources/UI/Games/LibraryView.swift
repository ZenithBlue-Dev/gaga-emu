import SwiftUI

/// Continue panel on the left, filter row and platform shelves on the right.
struct LibraryView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.verticalSizeClass) private var verticalSize
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.dynamicTypeSize) private var typeSize
    var onAdd: () -> Void
    @State private var sheet: GameSheet?
    @State private var filterGame: GameItem?
    @State private var pendingLoad: (GameItem, SaveSlot)?
    /// What the game's page asked for, done once the page has gone.
    @State private var pendingStart: (GameItem, GamePageStart)?
    @State private var dropTargeted = false
    /// Tiles widen with Dynamic Type so titles do not break mid-word.
    @ScaledMetric(relativeTo: .footnote) private var tileScale: CGFloat = 1
    /// The Library's own width, inside the safe area and beside the rail.
    @State private var width: CGFloat = 0
    /// How far the Library could extend into the side safe areas: in landscape the trailing notch inset, with the
    /// rail on the leading side.
    @State private var sides = EdgeInsets()
    /// The shelves' own width, under the side safe areas, for a chosen number of games per row.
    @State private var shelfWidth: CGFloat = 0
    private var display: LibraryDisplay { state.libraryDisplay }
    private var gridTile: CGFloat {
        let count = CGFloat(display.perRow)
        return max(44, (shelfWidth - lead - trail - 12 * (count - 1)) / count)
    }
    /// Shelf column gutters. The column runs under the side safe areas so covers scroll through them; at rest
    /// everything starts inside them.
    private var lead: CGFloat { 16 + sides.leading }
    private var trail: CGFloat { 16 + sides.trailing }

    private enum GameSheet: Identifiable {
        case page(GameItem), core(GameItem), saves(GameItem), edit(GameItem), skin(GameItem), delete(GameItem)
        var id: String {
            switch self {
            case .page(let game): return "page\(game.id)"
            case .core(let game): return "core\(game.id)"
            case .saves(let game): return "saves\(game.id)"
            case .edit(let game): return "edit\(game.id)"
            case .skin(let game): return "skin\(game.id)"
            case .delete(let game): return "delete\(game.id)"
            }
        }
    }

    private var compact: Bool { verticalSize == .compact }
    /// A phone held upright: Continue sits above the shelves, which keep the full width.
    private var upright: Bool { horizontalSize == .compact && verticalSize == .regular }
    private var metrics: LibraryMetrics { LibraryMetrics(width: width, compact: compact) }

    var body: some View {
        Group {
            if state.games.isEmpty {
                empty
            } else {
                AnyLayout(upright ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))) {
                    if upright {
                        uprightContinue
                        Rule()
                    } else if !compact {
                        continuePanel.frame(width: metrics.panel)
                        Rule(vertical: true).ignoresSafeArea(edges: .vertical)
                    }
                    VStack(spacing: 0) {
                        // Landscape on a phone: Continue is one strip of recent games, so the shelves keep the width.
                        if compact && !upright {
                            continueStrip
                            Rule()
                        }
                        ImportProgressRows().padding(.leading, lead).padding(.trailing, trail)
                        filterRow
                        Rule()
                        shelvesList
                    }
                    // The rail and Continue stay inside the safe area; the shelves and their rules run to the edge.
                    .ignoresSafeArea(.container, edges: .horizontal)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { sides = $0 }
        // A dropped game lands on its shelf; only a problem needs words.
        .gameFileDrop(isTargeted: $dropTargeted) { line, problem in
            if problem { state.launchFailure = .init(title: AppState.LaunchFailure.importTitle, message: line) }
        }
        .dropHighlight(dropTargeted)
        .sheet(item: $sheet, onDismiss: startPendingLoad) { sheet in
            switch sheet {
            case .page(let game): GamePage(game: game) { pendingStart = (game, $0) }
            case .core(let game): CorePickerSheet(game: game)
            case .saves(let game):
                ManageSavesSheet(title: game.title, store: state.saveStore(for: game)) { pendingLoad = (game, $0) }
            case .edit(let game): EditDetailsSheet(game: game)
            case .skin(let game): GameSkinSheet(game: game)
            case .delete(let game): DeleteGameSheet(game: game)
            }
        }
        .fullScreenCover(item: $filterGame) { FilterPickerView(game: $0) }
    }

    /// A game view cannot present until the sheet has gone.
    private func startPendingLoad() {
        if let (game, how) = pendingStart {
            pendingStart = nil
            switch how {
            case .play: state.launch(game)
            case .startOver: state.start(game)
            case .slot(let slot): state.start(game, loading: slot)
            case .nearby: PlayNearbyMenuItem.begin(game, state: state)
            }
        }
        guard let (game, slot) = pendingLoad else { return }
        pendingLoad = nil
        state.start(game, loading: slot)
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Text("The shelf is empty.")
                .font(.system(.largeTitle, design: .serif))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Button("Add Games", action: onAdd)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Continue

    /// Most recently played, or the newest import when nothing has been played.
    private var continueGame: GameItem? { state.recentGames.first ?? state.games.last }

    private var continuePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue").font(.screenTitle).accessibilityAddTraits(.isHeader)
                if let game = continueGame {
                    CoverArt(game: game, width: compact ? 84 : 150)
                        .contextMenu { menu(game) }
                    Text(game.title).font(.gameTitle).lineLimit(3)
                    Text(continueMeta(game)).font(.meta).foregroundStyle(AppTheme.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            // Pinned, so large text can scroll the details without hiding Play.
            if let game = continueGame {
                Button { state.launch(game) } label: {
                    Label("Play", systemImage: "play.fill").frame(minHeight: 36)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Play \(game.title)")
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(AppTheme.paper)
            }
        }
    }

    /// Upright the panel is a row, cover beside title and Play: stacked, Play hid the title in the height it gets.
    @ViewBuilder private var uprightContinue: some View {
        if let game = continueGame {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue").font(.screenTitle).accessibilityAddTraits(.isHeader)
                HStack(alignment: .top, spacing: 12) {
                    CoverArt(game: game, width: 84).contextMenu { menu(game) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title).font(.gameTitle).lineLimit(2)
                        Text(continueMeta(game)).font(.meta).foregroundStyle(AppTheme.muted).lineLimit(2)
                        Button { state.launch(game) } label: { Label("Play", systemImage: "play.fill") }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityLabel("Play \(game.title)")
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1) // Above this the row would take the shelves' height.
        }
    }

    /// Recent games in one sideways row, newest first, each with Play. The newest import when nothing has been played.
    @ViewBuilder private var continueStrip: some View {
        let games = state.recentGames.isEmpty ? continueGame.map { [$0] } ?? [] : Array(state.recentGames.prefix(8))
        if !games.isEmpty {
            HStack(spacing: 12) {
                Text("Continue").font(.headline).accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(games) { game in
                            Button { state.launch(game) } label: {
                                HStack(spacing: 8) {
                                    CoverArt(game: game, width: 36)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(game.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text(CoreCatalog.platformCode(game.platformID)).font(.meta).foregroundStyle(AppTheme.muted)
                                    }
                                    .frame(maxWidth: 160, alignment: .leading)
                                    Image(systemName: "play.fill").foregroundStyle(AppTheme.accent).accessibilityHidden(true)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .frame(minHeight: 44)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.corner))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu { menu(game) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Play \(game.title)")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("continue.\(game.id)")
                        }
                    }
                }
                .accessibilityIdentifier("continueStrip")
            }
            .padding(.leading, lead).padding(.trailing, trail).padding(.vertical, 6)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1) // One row: larger text would take the shelves' height.
        }
    }

    private func continueMeta(_ game: GameItem) -> String {
        let played = game.lastPlayed.map { "Last played " + $0.formatted(.relative(presentation: .named)) }
        return "\(CoreCatalog.platformCode(game.platformID)) · \(CoreCatalog.playTime(game.playTime))\n"
            + (played ?? "Not played yet")
    }

    // MARK: Filter row

    private var platformIDs: [String] {
        let present = Set(state.games.map(\.platformID))
        let known = CoreCatalog.platforms.map(\.id)
        return known.filter(present.contains) + present.subtracting(known).sorted()
    }

    private var makers: [String] {
        Array(Set(platformIDs.compactMap { CoreCatalog.platform($0)?.manufacturer })).sorted()
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("All", id: "all", label: "All games")
                    if !state.recentGames.isEmpty { chip("Recent", id: "recent", label: "Recently played") }
                    ForEach(platformIDs, id: \.self) { id in
                        chip(CoreCatalog.platformCode(id), id: id, label: CoreCatalog.platformName(id))
                    }
                }
                .padding(.leading, lead)
            }
            Menu {
                Picker("Sort By", selection: $state.libraryDisplay.sort) {
                    ForEach(LibraryDisplay.Sort.allCases) { Text($0.label).tag($0) }
                }
                Picker("Order", selection: $state.libraryDisplay.descending) {
                    Text("Ascending").tag(false)
                    Text("Descending").tag(true)
                }
                Picker("Maker", selection: $state.platformFilter) {
                    Text("All Makers").tag("all")
                    ForEach(makers, id: \.self) { Text(verbatim: $0).tag("maker:" + $0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down").foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Sort games, filter by maker")
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                TextField("Search", text: $state.search)
                    .submitLabel(.search)
                    .accessibilityLabel("Search games")
            }
            .padding(.horizontal, 8)
            .frame(width: metrics.search)
            .frame(minHeight: 34)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
            .padding(.trailing, trail)
        }
        .frame(minHeight: 44)
    }

    private func chip(_ title: String, id: String, label: String) -> some View {
        let selected = state.platformFilter == id
        return Button { state.platformFilter = id } label: {
            Text(title)
                .font(id == "all" || id == "recent" ? .footnote.weight(selected ? .bold : .regular)
                                                    : .system(.footnote, design: .monospaced).weight(selected ? .bold : .regular))
                .foregroundStyle(selected ? AppTheme.onAccent : AppTheme.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(selected ? AppTheme.accentFill : Color.clear,
                            in: RoundedRectangle(cornerRadius: AppTheme.corner))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.corner)
                    .stroke(selected ? Color.clear : AppTheme.rule, lineWidth: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Shelves

    private var shelves: [(id: String, title: String, games: [GameItem])] {
        let games = state.filteredGames
        if state.platformFilter == "recent" { return games.isEmpty ? [] : [(id: "recent", title: "Recent", games: games)] }
        let groups = Dictionary(grouping: games, by: \.platformID)
        return platformIDs.compactMap { id in
            groups[id].map { (id: id, title: display.heading(id), games: display.sorted($0)) }
        }
    }

    private var shelvesList: some View {
        ScrollView {
            let list = shelves
            if list.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No games match.").font(.gameTitle)
                    Button("Show All Games") {
                        state.search = ""
                        state.platformFilter = "all"
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                .padding(.vertical, 16).padding(.leading, lead).padding(.trailing, trail)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(list, id: \.id) { shelf in
                    VStack(alignment: .leading, spacing: 6) {
                        if !display.hideGroup {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(shelf.title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                                Text("\(shelf.games.count)").font(.meta).foregroundStyle(AppTheme.muted)
                                    .accessibilityLabel("\(shelf.games.count) games")
                            }
                            .padding(.leading, lead).padding(.trailing, trail)
                        }
                        if display.perRow > 0 {
                            // One column of rows at accessibility sizes, as every card grid (`choiceColumns`).
                            LazyVGrid(columns: typeSize.isAccessibilitySize ? choiceColumns(minimum: 0, large: true)
                                          : Array(repeating: GridItem(.fixed(gridTile), spacing: 12, alignment: .top), count: display.perRow),
                                      alignment: .leading, spacing: 12) {
                                ForEach(shelf.games) { tile($0) }
                            }
                            .padding(.leading, lead).padding(.trailing, trail)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 12) {
                                    ForEach(shelf.games) { tile($0) }
                                }
                                .padding(.leading, lead).padding(.trailing, trail)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(display.hideIndicators ? .hidden : .automatic)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { shelfWidth = $0 }
    }

    private func tile(_ game: GameItem) -> some View {
        let row = display.perRow > 0 && typeSize.isAccessibilitySize
        let width = row ? 96 : display.perRow > 0 ? gridTile : (compact ? 120 : 140) * min(tileScale, 1.8)
        return Button { sheet = .page(game) } label: {
            // As `ChoiceCard`: one cover shape, two title lines and one detail line even when shorter, so every card
            // on a shelf is the same size. A row beside the cover at accessibility sizes.
            AnyLayout(row ? AnyLayout(HStackLayout(alignment: .center, spacing: 12)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))) {
                CoverArt(game: game, width: width)
                VStack(alignment: .leading, spacing: 4) {
                    if !display.hideTitle {
                        Text(game.title).font(.footnote.weight(.medium)).lineLimit(2, reservesSpace: !row)
                            .multilineTextAlignment(.leading)
                    }
                    if !display.hideDetails {
                        HStack(spacing: 4) {
                            if game.isFavorite { Image(systemName: "star.fill").imageScale(.small) }
                            Text(tileMeta(game)).font(.system(.caption2, design: .monospaced)).lineLimit(1, reservesSpace: !row)
                        }
                        .foregroundStyle(AppTheme.muted)
                    }
                }
                .frame(maxWidth: row ? .infinity : nil, alignment: .leading)
            }
            .frame(width: row ? nil : width, alignment: .topLeading)
            .frame(maxWidth: row ? .infinity : nil, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { menu(game) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel(game))
        .accessibilityHint("Opens the game's page: play, skin, filter, core and saves. Touch and hold for a quick menu.")
        .accessibilityAddTraits(.isButton)
    }

    private func tileMeta(_ game: GameItem) -> String {
        "\(CoreCatalog.platformCode(game.platformID)) · \(game.playTime > 0 ? CoreCatalog.playTime(game.playTime) : "new")"
    }

    private func a11yLabel(_ game: GameItem) -> String {
        "\(game.title), \(CoreCatalog.platformName(game.platformID))\(game.isFavorite ? ", favorite" : "")"
    }

    @ViewBuilder private func menu(_ game: GameItem) -> some View {
        Button { state.launch(game) } label: { Label("Play", systemImage: "play") }
        PlayNearbyMenuItem(game: game)
        Button { sheet = .core(game) } label: { Label("Change Core", systemImage: "cpu") }
        Button { filterGame = game } label: { Label("Choose Filter", systemImage: "camera.filters") }
        Button { sheet = .skin(game) } label: { Label("Assign Skin", systemImage: "gamecontroller") }
        Button { sheet = .saves(game) } label: { Label("Manage Saves", systemImage: "tray.full") }
        Button { sheet = .edit(game) } label: { Label("Edit Details", systemImage: "pencil") }
        Button(role: .destructive) { sheet = .delete(game) } label: { Label("Delete", systemImage: "trash") }
    }
}

/// Says what Delete removes from the device before it does: a disc set's folder and its files, or only the
/// Library entry. Saves always stay. A folder a playlist game plays from is not deleted until that game goes.
struct DeleteGameSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let game: GameItem

    var body: some View {
        let folder = state.folderDeleted(with: game)
        let playlists = folder.map(state.playlists(into:)) ?? []
        PaperSheet(title: "Delete \(game.title)?") {
            VStack(alignment: .leading, spacing: 12) {
                if let folder {
                    let count = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.count
                    Text("This deletes the folder \u{201C}\(folder.lastPathComponent)\u{201D} and its \(count) \(count == 1 ? "file" : "files") from this device, and removes the game and its play history from your library.")
                } else {
                    Text("This removes the game and its play history from your library. The game file stays in the ROMs folder.")
                }
                Text("Its saves and save states stay on this device, and return if you add the same game again.")
                    .foregroundStyle(AppTheme.muted)
                if !playlists.isEmpty {
                    Rule()
                    Label {
                        Text("The playlist \(playlists.map { "\u{201C}\($0.title)\u{201D}" }.formatted()) plays discs from this folder. Delete that game first, so its playlist does not lose a disc.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(AppTheme.accent)
                    }
                }
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle())
                    Button(folder == nil ? "Remove from Library" : "Delete Folder") {
                        state.delete(game)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!playlists.isEmpty)
                }
                .padding(.top, 8)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Title and favorite are editable. The rest is read-only metadata.
struct EditDetailsSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let game: GameItem
    @State private var title: String
    @State private var favorite: Bool

    init(game: GameItem) {
        self.game = game
        _title = State(initialValue: game.title)
        _favorite = State(initialValue: game.isFavorite)
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    private var fileSize: String {
        let path = game.resolvedROMPath(romDirectory: state.romDirectory)
        let bytes = path.flatMap { try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? Int64 }
        return bytes.map { $0.formatted(.byteCount(style: .file)) } ?? "Unknown"
    }

    var body: some View {
        PaperSheet(title: "Edit Details") {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Title", text: $title)
                    .font(.gameTitle)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Game title")
                Rule()
                Toggle("Favorite", isOn: $favorite).frame(minHeight: 44).tint(AppTheme.accentFill)
                Rule()
                ValueRow(title: "Platform", value: CoreCatalog.platformName(game.platformID))
                Rule()
                ValueRow(title: "Core", value: state.coreName(for: game))
                Rule()
                ValueRow(title: "File size", value: fileSize)
                Rule()
                ValueRow(title: "Play time", value: CoreCatalog.playTime(game.playTime))
                Button("Save") {
                    state.update(game.id) {
                        $0.title = trimmed
                        $0.isFavorite = favorite
                    }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmed.isEmpty)
                .padding(.top, 16)
            }
        }
    }
}

/// Continue panel and search widths from the Library's width (inside the safe area, beside the rail). Fixed 240pt
/// and 130pt took about half of a landscape phone once the rail and both notch insets were gone, so the shelves were
/// cramped. Now they take a share of the width, within limits that keep Play and the cover readable.
struct LibraryMetrics: Equatable {
    var panel: CGFloat
    var search: CGFloat

    init(width: CGFloat, compact: Bool) {
        // 200pt in landscape: a 13-letter title in the serif title face fits one line once the 16pt padding is off.
        panel = min(max(width * 0.27, compact ? 200 : 220), 300)
        search = min(max(width * 0.2, 130), 260)
    }
}
