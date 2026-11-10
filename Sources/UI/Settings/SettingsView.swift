#if !GAGA_SIDELOAD
import StoreKit
#endif
import SwiftUI

/// Settings' categories. Visual choices (skins, filters, icon, library layout) live in the Style tab.
enum SettingsCategory: String, CaseIterable, Identifiable, ShellCategory {
    case profile = "Profile", gameplay = "Gameplay", controllers = "Controllers", screen = "Screen", systems = "Systems",
         library = "Library", storage = "Storage and Sync", gagaPlus = "Gaga Plus", help = "Help"
    var id: String { rawValue }
    var title: String { rawValue }
    var identifier: String { "settings.\(rawValue)" }
    var symbol: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .gameplay: return "play.circle"
        case .controllers: return "gamecontroller"
        case .screen: return "tv"
        case .systems: return "cpu"
        case .library: return "books.vertical"
        case .storage: return "icloud"
        case .gagaPlus: return "star.circle"
        case .help: return "questionmark.circle"
        }
    }
    /// Gaga Plus stays out of the app while the paywall gate is closed (docs/06 section 4.5).
    static var visible: [SettingsCategory] { allCases.filter { $0 != .gagaPlus || PaywallGate.isOpen } }
}

/// Settings: search on top, then the categories with icons, and the chosen one's rows, each with a picture. Only rows
/// with working behaviour appear; docs/07 says what returns when. Saved values for hidden rows stay in state.json.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var category: SettingsCategory = .profile
    @State private var query = ""
    @FocusState private var searching: Bool
    @State private var target: SettingsTarget?
    /// The last five searches that led somewhere, newest first, one per line.
    @AppStorage("settingsRecentSearches") private var recentText = ""

    private var recent: [String] { recentText.split(separator: "\n").map(String.init) }
    private var showsResults: Bool { searching || !query.isEmpty }

    var body: some View {
        CategoryShell(title: "Settings", items: SettingsCategory.visible, selection: $category,
                      detailTitle: showsResults ? "Search" : category.title) {
            SettingsSearchField(query: $query, focused: $searching)
        } detail: {
            if showsResults {
                SettingsSearchResults(query: query, recent: recent, pickRecent: { query = $0 }, pick: open)
            } else {
                detail
            }
        }
        .onChange(of: category) { query = ""; searching = false }
        .environment(\.openSetting, show)
        .sheet(item: Binding(get: { target?.fullScreen == false ? target : nil }, set: { target = $0 })) { sheet($0) }
        .fullScreenCover(item: Binding(get: { target?.fullScreen == true ? target : nil }, set: { target = $0 })) { sheet($0) }
    }

    /// A result opens its category, and its sheet or Style page when it has one.
    private func open(_ entry: SettingEntry) {
        let text = query.trimmingCharacters(in: .whitespaces)
        recentText = ([text] + recent.filter { $0 != text }).prefix(5).joined(separator: "\n")
        query = ""
        searching = false
        category = entry.category
        if let next = entry.target { show(next) }
    }

    /// The visual choices open their page in the Style tab; the rest open as sheets here.
    private func show(_ next: SettingsTarget) {
        if let section = next.style {
            // The keyboard goes first: switching tabs under it left the app busy on the device.
            searching = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { state.showStyle(section) }
        } else {
            target = next
        }
    }

    @ViewBuilder private func sheet(_ target: SettingsTarget) -> some View {
        switch target {
        case .bios: BIOSManagerView()
        case .achievements: RetroAchievementsView()
        case .skins, .filters, .layout, .look: EmptyView() // Style pages, never sheets.
        case .screen: ScreenSettingsView(store: state.screens)
        case .mapping: ControllerMappingView(platformID: nil, game: nil)
        case .macros: MacrosView()
        case .turbo: TurboView()
        case .players: PlayersView(platformID: nil)
        case .guides: GuidesView()
        case .licences: LicencesView()
        case .aboutUs: AboutUsView()
        }
    }

    @ViewBuilder private var detail: some View {
        switch category {
        case .profile: ProfilePane()
        case .gameplay: GameplayPane()
        case .controllers: ControllersPane()
        case .screen: ScreenPane()
        case .systems: SystemsPane()
        case .library: LibraryPane()
        case .storage: StoragePane()
        #if GAGA_SIDELOAD
        case .gagaPlus: EmptyView()
        #else
        case .gagaPlus: GagaPlusPane()
        #endif
        case .help: HelpPane()
        }
    }
}

// MARK: - Rows

struct ValueRow: View {
    let title: String
    let value: String
    var tile: RowTile?

    var body: some View {
        TiledRow(tile: tile) {
            TitleValue(title: title, value: value)
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// A row's title and value side by side, or the value under the title at accessibility sizes so neither breaks
/// mid-word.
struct TitleValue: View {
    let title: String
    var value: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).fixedSize(horizontal: false, vertical: true)
                if let value { Text(value).font(.meta).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text(LocalizedStringKey(title))
                Spacer(minLength: 12)
                if let value { Text(value).font(.meta).foregroundStyle(AppTheme.muted).multilineTextAlignment(.trailing) }
            }
        }
    }
}

/// A row that opens something, with its picture. `PictureRow` in docs/ux-redesign.md.
struct ActionRow: View {
    let title: String
    var value: String?
    var symbol = "chevron.right"
    var tile: RowTile?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TiledRow(tile: tile) {
                HStack {
                    TitleValue(title: title, value: value)
                    Image(systemName: symbol).font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                }
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct LinkRow: View {
    @Environment(\.openURL) private var openURL
    let title: String
    let url: String
    var tile: RowTile?

    var body: some View {
        ActionRow(title: title, symbol: "arrow.up.right", tile: tile) {
            if let link = URL(string: url) { openURL(link) }
        }
        .accessibilityAddTraits(.isLink)
    }
}

/// A switch with its picture, which dims while off. The note shows on one line; the info button and the VoiceOver
/// hint give all of it.
struct ToggleRow: View {
    let title: String
    let note: String
    @Binding var isOn: Bool
    var tile: RowTile?

    var body: some View {
        // The Toggle stays the outermost view, so an identifier set on the row lands on the switch.
        Toggle(isOn: $isOn) {
            TiledRow(tile: tile, dimmed: !isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                    if !note.isEmpty {
                        HStack(spacing: 0) {
                            Text(LocalizedStringKey(note)).font(.footnote).foregroundStyle(AppTheme.muted).lineLimit(1)
                            NoteButton(title: title, note: note)
                        }
                    }
                }
            }
        }
        .tint(AppTheme.accentFill)
        .accessibilityHint(Text(LocalizedStringKey(note)))
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
}

/// `info.circle`, opening a row's full note in a popover.
struct NoteButton: View {
    let title: String
    let note: String
    @State private var shown = false

    var body: some View {
        Button { shown = true } label: {
            Image(systemName: "info.circle").foregroundStyle(AppTheme.accent).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(title)")
        .accessibilityHidden(true) // The row's hint reads the note already.
        .popover(isPresented: $shown) {
            Text(LocalizedStringKey(note))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(idealWidth: 320)
                .foregroundStyle(AppTheme.ink)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct PaneNote: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
    }
}

// MARK: - Panes

private struct ProfilePane: View {
    @Environment(\.openSetting) private var openSetting
    @ObservedObject private var account = RetroAchievements.shared
    @AppStorage(PlayerName.key) private var playerName = ""

    var body: some View {
        TiledRow(tile: .picture { MonogramPicture(name: PlayerName.effective) }) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Player Name", text: $playerName, prompt: Text("Player Name"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("playerName")
                    .accessibilityHint("Letters, digits, underscore and hyphen, 3 to 16 of them. Applies when the next game starts.")
                Text("Games and Play Nearby show \(PlayerName.effective). Applies at the next game start.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
        Rule()
        ValueRow(title: "Game Center", value: PlayerName.gameCenterStatus, tile: .symbol("person.2.circle"))
        Rule()
        ActionRow(title: "RetroAchievements", value: account.username ?? "Off", symbol: "chevron.right", tile: .symbol("trophy")) {
            openSetting(.achievements)
        }
        .accessibilityIdentifier("settingsRetroAchievements")
        Rule()
    }
}

/// A player's initial on the tile.
private struct MonogramPicture: View {
    let name: String
    var body: some View {
        GeometryReader { box in
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: box.size.width * 0.45, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.accent)
                .frame(width: box.size.width, height: box.size.height)
        }
    }
}

private struct GameplayPane: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @State private var showPlans = false

    var body: some View {
        ToggleRow(title: "Quick Start", note: "Opens your most recent game when the app starts.", isOn: $state.quickStart, tile: .symbol("bolt"))
        Rule()
        // Reaching the second branch needs an open paywall gate, because a closed one lifts the limit.
        if store.canUseAutoSaveState {
            ToggleRow(title: "Auto Save State", note: "Saves when you quit or leave the app, and offers to resume when you next play.",
                      isOn: $state.autoSaveStates, tile: .symbol("square.and.arrow.down"))
        } else {
            ActionRow(title: "Auto Save State", value: "Plus", symbol: "lock", tile: .symbol("square.and.arrow.down")) { showPlans = true }
                #if !GAGA_SIDELOAD
                .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
                #endif
        }
        Rule()
        ToggleRow(title: "Rewind",
                  note: "Hold the rewind button, or a controller input mapped to Rewind in Controllers, to step back through recent play. Uses up to \(RewindPolicy.standard.budgetBytes / 1_048_576) MB of memory while a game runs. Only systems with a small, quick save state can rewind; the pause menu says when one cannot.",
                  isOn: $state.rewind, tile: .symbol("backward.fill"))
        Rule()
        ToggleRow(title: "Auto Full Screen", note: "The picture fills the screen when a controller connects.", isOn: $state.autoFullScreen,
                  tile: .symbol("arrow.up.left.and.arrow.down.right"))
        Rule()
        ToggleRow(title: "Respect Silent Mode", note: "Game sound plays only when the device is not in silent mode.", isOn: $state.respectSilentMode,
                  tile: .symbol("bell.slash"))
        Rule()
        ValueRow(title: "Total play time", value: CoreCatalog.playTime(state.totalPlayTime), tile: .symbol("clock"))
        Rule()
        ValueRow(title: "Sessions", value: "\(state.history.count)", tile: .symbol("list.number"))
        Rule()
        PaneNote(text: "Save states, cheats and fast forward are in each game's pause menu and on its page in the Library.")
    }
}

private struct LibraryPane: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openSetting) private var openSetting

    var body: some View {
        ValueRow(title: "Games", value: "\(state.games.count)", tile: .symbol("books.vertical"))
        Rule()
        ToggleRow(title: "Cover Art",
                  note: "Off by default. When on, GagaEmu reads box art lists from \(LibretroThumbnails.host) and asks it for the art of each game it matches, so that server sees which games you have. Pictures are kept in the cache. Turn this off at any time.",
                  isOn: $state.coverArt, tile: .symbol("photo"))
        Rule()
        if state.coverArt {
            ActionRow(title: "Refresh Covers", symbol: "arrow.clockwise", tile: .symbol("arrow.clockwise")) { state.refetchCovers() }
            Rule()
        }
        ActionRow(title: "Library Layout", value: "In Style",
                  tile: .picture(ShelfPicture.description(state.libraryDisplay)) { ShelfPicture(display: state.libraryDisplay) }) {
            openSetting(.layout)
        }
        Rule()
        ActionRow(title: "App Icon and Colours", value: "In Style", tile: .symbol("paintpalette")) { openSetting(.look) }
        Rule()
    }
}

private struct ScreenPane: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openSetting) private var openSetting

    private var filterName: String {
        ShaderCatalog.all.first { $0.id == state.shaderID }?.name ?? state.filters.name(of: state.shaderID) ?? "Original"
    }

    var body: some View {
        ActionRow(title: "Screen", value: "Scaling and layouts",
                  tile: .picture("Scaling: Fit, \(ScalingPicture.effect(.fit))") { ScalingPicture(mode: .fit) }) {
            openSetting(.screen)
        }
        Rule()
        ActionRow(title: "Default Filter", value: filterName,
                  tile: .picture("Filter preview: \(filterName)") { FilterPicture(shaderID: state.shaderID) }) {
            openSetting(.filters)
        }
        Rule()
        // shortcut: not yet checked on a real second screen, so it stays off by default; tick docs/manic-todo.md once it is.
        ToggleRow(title: "AirPlay Full Screen",
                  note: "With a TV or display connected by AirPlay or cable, the game fills that screen and this device keeps the controls.",
                  isOn: $state.airPlayFullscreen, tile: .symbol("airplayvideo"))
        Rule()
        PaneNote(text: "Filters are in Style. A game's page and its pause menu choose one for that game.")
    }
}

private struct ControllersPane: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var controllers: ControllerManager
    @Environment(\.openSetting) private var openSetting

    var body: some View {
        ValueRow(title: "Touch Control", value: controllers.touchOwnsPlayerOne ? "Player 1" : "Unassigned", tile: .symbol("hand.tap"))
        Rule()
        ForEach(controllers.devices) { device in
            TiledRow(tile: .symbol("gamecontroller")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                        if !device.hasSentInput {
                            Text("Touch stays on until this sends input in a game.").font(.footnote).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer(minLength: 12)
                    Menu(device.slot.map { "Player \($0 + 1)" } ?? "Unassigned") {
                        ForEach(0..<ControllerManager.slotCount, id: \.self) { index in
                            Button("Player \(index + 1)") { controllers.assign(device.id, to: index) }
                        }
                        Button("Unassign") { controllers.assign(device.id, to: nil) }
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(device.name) player slot")
                }
            }
            Rule()
        }
        ActionRow(title: "Players", value: "\(controllers.devices.count) connected", tile: .symbol("person.2")) { openSetting(.players) }
            .accessibilityIdentifier("settingsPlayers")
        Rule()
        ActionRow(title: "Skins", value: "In Style",
                  tile: .picture { CurrentSkinPicture(platformID: state.games.first?.platformID ?? "snes").padding(4) }) {
            openSetting(.skins)
        }
        Rule()
        ActionRow(title: "Controller Mapping", tile: .symbol("arrow.triangle.swap")) { openSetting(.mapping) }
        Rule()
        ActionRow(title: "Macros", value: "\(state.controls.file.macros.count)", tile: .symbol("record.circle")) { openSetting(.macros) }
        Rule()
        ActionRow(title: "Turbo", value: "\(Int(state.controls.file.turboHertz)) per second", tile: .symbol("dot.radiowaves.right")) {
            openSetting(.turbo)
        }
        Rule()
        ControlOptions().padding(.vertical, 6)
        Rule()
        ToggleRow(title: "Rumble", note: "The device vibrates when a game rumbles while you play on touch.", isOn: $state.rumble,
                  tile: .symbol("iphone.radiowaves.left.and.right"))
        Rule()
        TiledRow(tile: .symbol("waveform"), dimmed: state.rumbleStrength == 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Rumble Strength")
                    Spacer(minLength: 12)
                    Text(state.rumbleStrength == 0 ? "Off" : "\(Int((state.rumbleStrength * 100).rounded()))%")
                        .font(.meta).foregroundStyle(AppTheme.muted)
                }
                Slider(value: $state.rumbleStrength, in: 0...1, step: 0.1) { Text("Rumble Strength") }
                    .tint(AppTheme.accentFill)
                    .accessibilityValue(state.rumbleStrength == 0 ? "Off" : "\(Int((state.rumbleStrength * 100).rounded())) percent")
                    .accessibilityHint("How hard a game shakes your controller or device. Off stops game rumble everywhere.")
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        Rule()
        ToggleRow(title: "Skin Sound Effects", note: "Touch controls click when you press them.", isOn: $state.skinSoundEffects,
                  tile: .symbol("speaker.wave.2"))
        Rule()
        if controllers.devices.isEmpty {
            PaneNote(text: "No controllers connected. Pair a DualSense, DualShock 4, Xbox, Joy-Con or MFi pad in iOS Settings.")
        }
    }
}

/// BIOS files, every core and its options, and the default core per system.
private struct SystemsPane: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openSetting) private var openSetting
    @State private var biosFound = 0

    private var biosNeeded: Int { BIOSManagerView.required.filter { !$0.1.contains("optional") }.count }

    var body: some View {
        ActionRow(title: "BIOS Files", value: "\(biosFound) of \(biosNeeded) found",
                  tile: .picture("BIOS files: \(biosFound) of \(biosNeeded) found") { FilePicture(found: biosFound > 0) }) {
            openSetting(.bios)
        }
        .task { biosFound = BIOSManagerView.foundCount() }
        Rule()
        Text("Cores").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader).padding(.top, 16).padding(.bottom, 4)
        CoresPane()
        Text("Default core per system")
            .font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader).padding(.top, 16).padding(.bottom, 4)
        PaneNote(text: "A game's page in the Library changes the core for that game only.")
            .padding(.bottom, 4)
        Rule()
        ForEach(CoreCatalog.platforms) { platform in
            let tile = RowTile.picture { PlatformPicture(platformID: platform.id) }
            if platform.cores.count > 1 {
                TiledRow(tile: tile) {
                    HStack {
                        Text(platform.name)
                        Spacer(minLength: 12)
                        Picker(platform.name, selection: core(platform)) {
                            ForEach(platform.cores) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                }
                .frame(minHeight: 44)
            } else {
                ValueRow(title: platform.name, value: platform.cores.first?.name ?? "", tile: tile)
            }
            Rule()
        }
    }

    private func core(_ platform: PlatformInfo) -> Binding<String> {
        Binding(get: { state.defaultCores[platform.id] ?? CoreCatalog.defaultCore(for: platform.id) },
                set: { state.defaultCores[platform.id] = $0 })
    }
}

private struct CloudStatusRow: View {
    @ObservedObject var cloud: CloudSync

    var body: some View {
        ValueRow(title: "iCloud", value: cloud.status.text, tile: .symbol("icloud.and.arrow.up")).accessibilityIdentifier("icloudSyncStatus")
    }
}

private struct StoragePane: View {
    @EnvironmentObject private var state: AppState
    @State private var romBytes: Int64 = 0
    @State private var showClearConfirm = false
    @State private var cleared = false

    var body: some View {
        ValueRow(title: "Game files", value: romBytes.formatted(.byteCount(style: .file)), tile: .symbol("internaldrive"))
            .task { romBytes = folderSize(state.romDirectory) }
        Rule()
        ToggleRow(title: "iCloud Sync", note: "Keeps saves and save states the same on your devices, when you quit a game or leave the app. If two devices changed a save, the newest is used and the older stays as a copy. Deleting a save on one device does not delete it on another.",
                  isOn: $state.iCloudSync, tile: .symbol("icloud"))
            .accessibilityIdentifier("icloudSyncToggle")
        Rule()
        if state.iCloudSync {
            ToggleRow(title: "Include Game Files", note: "Game files are large and count against your iCloud storage.", isOn: $state.iCloudSyncROMs,
                      tile: .symbol("externaldrive.badge.icloud"))
            Rule()
            CloudStatusRow(cloud: state.cloud)
            Rule()
        }
        ActionRow(title: "Clear Cache", value: cleared ? "Cleared" : nil, symbol: "trash", tile: .symbol("trash")) { showClearConfirm = true }
            .confirmationDialog("Clear cached files?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Cache", role: .destructive) {
                    state.clearCache()
                    cleared = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your games and library stay.")
            }
        Rule()
    }

    private func folderSize(_ folder: URL) -> Int64 {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])
        return (files?.allObjects as? [URL] ?? []).reduce(0) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}

#if !GAGA_SIDELOAD
private struct GagaPlusPane: View {
    @EnvironmentObject private var store: StoreKitManager
    @State private var showPlans = false

    private var status: String {
        if store.entitlements.lifetime { return "Lifetime" }
        return store.entitlements.premium ? "Active" : "Not subscribed"
    }

    var body: some View {
        ValueRow(title: "Status", value: status, tile: .symbol("star.circle"))
            #if !GAGA_SIDELOAD
            .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
            #endif
        Rule()
        if store.entitlements.showsSubscribePrompts {
            ActionRow(title: "See Plans", tile: .symbol("star")) { showPlans = true }
            Rule()
        }
    }
}
#endif

private struct HelpPane: View {
    // App Store review is StoreKit; a sideload build is not on the App Store.
    #if !GAGA_SIDELOAD
    @Environment(\.requestReview) private var requestReview
    #endif
    @Environment(\.openSetting) private var openSetting
    @State private var tipsReset = false
    #if DEBUG
    @EnvironmentObject private var state: AppState
    #endif

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    /// The Language row appears only once a second localisation ships; today the app is English only.
    private var hasLanguages: Bool { Bundle.main.localizations.filter { $0 != "Base" }.count > 1 }

    var body: some View {
        ActionRow(title: "Guides", tile: .symbol("book")) { openSetting(.guides) }
        Rule()
        LinkRow(title: "Support and FAQ", url: SiteLinks.support, tile: .symbol("questionmark.bubble"))
        Rule()
        ActionRow(title: "About Us", tile: .symbol("info.circle")) { openSetting(.aboutUs) }
        Rule()
        ValueRow(title: "Version", value: version, tile: .symbol("number"))
        Rule()
        if let link = URL(string: SiteLinks.appStore) {
            ShareLink(item: link, message: Text("GagaEmu plays your own game files on iPhone and iPad.")) {
                TiledRow(tile: .symbol("square.and.arrow.up")) {
                    HStack {
                        Text("Share GagaEmu")
                        Spacer(minLength: 12)
                        Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rule()
        }
        ActionRow(title: "Reset Tips", value: tipsReset ? "Tips will show again" : nil, symbol: "arrow.counterclockwise", tile: .symbol("lightbulb")) {
            Tip.reset()
            tipsReset = true
        }
        Rule()
        if hasLanguages {
            LinkRow(title: "Language", url: UIApplication.openSettingsURLString, tile: .symbol("globe"))
            Rule()
        }
        LinkRow(title: "Feedback", url: SiteLinks.support, tile: .symbol("envelope"))
        Rule()
        LinkRow(title: "Terms of Service", url: SiteLinks.terms, tile: .symbol("doc.plaintext"))
        Rule()
        LinkRow(title: "Privacy Policy", url: SiteLinks.privacy, tile: .symbol("hand.raised"))
        Rule()
        #if !GAGA_SIDELOAD
        ActionRow(title: "Rate GagaEmu", symbol: "star", tile: .symbol("star")) { requestReview() }
        Rule()
        #endif
        ActionRow(title: "Licences", tile: .symbol("doc.text")) { openSetting(.licences) }
        Rule()
        #if DEBUG
        ActionRow(title: "Run Benchmark", value: "Debug build", symbol: "speedometer", tile: .symbol("speedometer")) { state.runBenchmark() }
        Rule()
        #endif
    }
}

/// Settings > About > About Us: what GagaEmu is, its version and build, and where to read more.
struct AboutUsView: View {
    @State private var showLicences = false

    private func info(_ key: String) -> String { Bundle.main.infoDictionary?[key] as? String ?? "?" }

    var body: some View {
        PaperSheet(title: "About Us") {
            VStack(alignment: .leading, spacing: 0) {
                Text("GagaEmu").font(.gameTitle).accessibilityAddTraits(.isHeader)
                Text("A multi-system emulator for iPhone and iPad, with no JIT in any core. It plays homebrew and backups you legally own, and includes no games, ROMs or BIOS.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                Rule()
                ValueRow(title: "Version", value: info("CFBundleShortVersionString"))
                Rule()
                ValueRow(title: "Build", value: info("CFBundleVersion"))
                Rule()
                LinkRow(title: "Website", url: SiteLinks.site)
                Rule()
                LinkRow(title: "Privacy Policy", url: SiteLinks.privacy)
                Rule()
                ActionRow(title: "Licences") { showLicences = true }
                    .fullScreenCover(isPresented: $showLicences) { LicencesView() }
                Rule()
                Text("GagaEmu is an independent project. It is not affiliated with, endorsed by or sponsored by any console maker. All trademarks belong to their owners.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
            }
        }
    }
}

// MARK: - Tools

/// TriggerPro editor: turbo rate, hold latch, and a combo of up to four steps.
struct TriggerProEditor: View {
    @EnvironmentObject private var triggerPro: TriggerProManager
    @State private var name = "Turbo"
    @State private var mode: TriggerProManager.Mode = .turbo
    @State private var hertz = 15.0

    private let buttons: [(String, UInt32)] = [
        ("A", ControllerManager.Button.south), ("B", ControllerManager.Button.east),
        ("X", ControllerManager.Button.west), ("Y", ControllerManager.Button.north),
        ("L", ControllerManager.Button.l1), ("R", ControllerManager.Button.r1)
    ]

    var body: some View {
        PaperSheet(title: "TriggerPro", scrolls: false) {
            List {
                Section("Bindings") {
                    if triggerPro.bindings.isEmpty {
                        Text("No bindings yet.").foregroundStyle(AppTheme.muted)
                    }
                    ForEach(triggerPro.bindings) { binding in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(binding.name)
                                Text(binding.mode.label).font(.meta).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Toggle(binding.name, isOn: bindingEnabled(binding.id)).labelsHidden().tint(AppTheme.accentFill)
                        }
                    }
                    .onDelete { triggerPro.bindings.remove(atOffsets: $0) }
                }
                .paperRows()
                Section("New") {
                    TextField("Name", text: $name)
                    Picker("Mode", selection: $mode) {
                        ForEach(TriggerProManager.Mode.allCases) { Text($0.label).tag($0) }
                    }
                    if mode == .turbo {
                        Stepper("Rate \(Int(hertz)) Hz", value: $hertz, in: 5...30, step: 1)
                    }
                    ForEach(buttons, id: \.1) { label, mask in
                        Button("Bind \(label)") { add(mask) }.foregroundStyle(AppTheme.accent)
                    }
                }
                .paperRows()
            }
            .paperList()
        }
    }

    private func bindingEnabled(_ id: UUID) -> Binding<Bool> {
        Binding(get: { triggerPro.bindings.first { $0.id == id }?.enabled ?? false },
                set: { value in
                    guard let index = triggerPro.bindings.firstIndex(where: { $0.id == id }) else { return }
                    triggerPro.bindings[index].enabled = value
                })
    }

    private func add(_ mask: UInt32) {
        let steps: [TriggerProManager.Binding.Step] = mode == .combo
            ? [.init(buttons: ControllerManager.Button.down, frames: 2),
               .init(buttons: ControllerManager.Button.down | ControllerManager.Button.right, frames: 2),
               .init(buttons: mask, frames: 2)]
            : []
        triggerPro.bindings.append(.init(name: name.isEmpty ? "Binding" : name, mode: mode,
                                          source: mask, output: mask, hertz: hertz, steps: steps))
    }
}

/// BIOS presence list. Checksums are shown once a file is imported into the BIOS folder.
struct BIOSManagerView: View {
    @State private var files: [URL] = []
    /// The name of the row whose Import button opened the file picker.
    @State private var importing: String?
    @State private var failure: String?

    /// The cores' system folder, so a file listed here is the file a core opens.
    private var biosDirectory: URL { GagaCoreWrapper.systemDirectory }

    /// File name, then the system it serves. The names are the ones each core opens in the system folder.
    static let required: [(String, String)] = [
        // SwanStation and Beetle PSX HW also read scph5500.bin; without one they boot their own OpenBIOS.
        // Beetle starts a PS-EXE only on scph5501.bin.
        ("scph5500.bin", "PS1 (JP)"), ("scph5501.bin", "PS1 (US)"), ("scph5502.bin", "PS1 (EU)"),
        ("bios7.bin", "DS ARM7"), ("bios9.bin", "DS ARM9"),
        ("firmware.bin", "DS firmware"),
        ("mpr-17933.bin", "Saturn (US, EU)"), ("sega_101.bin", "Saturn (JP)"),
        // JGenesis and Genesis Plus GX read the same names.
        ("bios_CD_U.bin", "Mega-CD (US)"), ("bios_CD_E.bin", "Mega-CD (EU)"), ("bios_CD_J.bin", "Mega-CD (JP)"),
        ("disksys.rom", "Famicom Disk System (Nestopia UE)"),
        ("syscard3.pce", "PC Engine CD (System Card 3)"),
        ("bios.min", "Pokémon Mini (optional: a free BIOS is built in)"),
        ("lynxboot.img", "Lynx boot ROM (optional: Handy emulates it)"),
        ("5200.rom", "Atari 5200 BIOS (optional: AltirraOS built in)"),
        ("atarixl.rom", "Atari XL/XE OS (optional: AltirraOS built in)"),
        ("jagboot.rom", "Jaguar boot ROM (optional: Virtual Jaguar boots carts without it)"),
        ("kernal-901227-03.bin", "C64 KERNAL"), ("basic-901226-01.bin", "C64 BASIC"),
        ("chargen-901225-01.bin", "C64 character ROM"),
        ("kick34005.A500", "Amiga Kickstart 1.3 (optional: AROS built in)"),
        ("kick40068.A1200", "Amiga Kickstart 3.1 for A1200 hard disks (optional: AROS built in)")
    ]

    /// The byte sizes each name's core reads: PS1 and Saturn 512 KiB, DS ARM7 16 KiB, ARM9 4 KiB, DS firmware
    /// 128, 256 or 512 KiB (melonDS), Mega-CD 128 KiB, FDS 8 KiB, PC Engine System Card 256 KiB, Pokemon Mini 4 KiB, Lynx 512, 5200 2 KiB, XL/XE 16 KiB, Jaguar 128 KiB, C64 KERNAL and BASIC 8 KiB, character ROM 4 KiB, Kickstart 1.3 256 KiB and 3.1 512 KiB. Import treats a file of another size under that name as a game.
    static let sizes: [String: Set<Int>] = [
        "scph5500.bin": [512 << 10], "scph5501.bin": [512 << 10], "scph5502.bin": [512 << 10],
        "bios7.bin": [16 << 10], "bios9.bin": [4 << 10],
        "firmware.bin": [128 << 10, 256 << 10, 512 << 10],
        "mpr-17933.bin": [512 << 10], "sega_101.bin": [512 << 10],
        "bios_CD_U.bin": [128 << 10], "bios_CD_E.bin": [128 << 10], "bios_CD_J.bin": [128 << 10],
        "disksys.rom": [8 << 10],
        "syscard3.pce": [256 << 10], "bios.min": [4 << 10],
        "lynxboot.img": [512], "5200.rom": [2 << 10], "atarixl.rom": [16 << 10], "jagboot.rom": [128 << 10],
        "kernal-901227-03.bin": [8 << 10], "basic-901226-01.bin": [8 << 10], "chargen-901225-01.bin": [4 << 10],
        "kick34005.A500": [256 << 10], "kick40068.A1200": [512 << 10]
    ].merging(snesFirmware.map { ($0.0, Set([$0.2])) }) { listed, _ in listed }

    /// The exact name a core reads for a file name in any letter case, or nil when no BIOS has that name.
    static func canonicalName(_ file: String) -> String? {
        sizes.keys.first { $0.caseInsensitiveCompare(file) == .orderedSame }
    }

    /// bsnes's coprocessor firmware: file name, chip and part, bytes. bsnes opens <chip>.program.rom and
    /// <chip>.data.rom in the system folder for a game with that chip; Snes9x emulates the chips without them.
    static let snesFirmware: [(String, String, Int)] = [
        ("dsp1.program.rom", "DSP-1 program", 6 << 10), ("dsp1.data.rom", "DSP-1 data", 2 << 10),
        ("dsp1b.program.rom", "DSP-1B program", 6 << 10), ("dsp1b.data.rom", "DSP-1B data", 2 << 10),
        ("dsp2.program.rom", "DSP-2 program", 6 << 10), ("dsp2.data.rom", "DSP-2 data", 2 << 10),
        ("dsp3.program.rom", "DSP-3 program", 6 << 10), ("dsp3.data.rom", "DSP-3 data", 2 << 10),
        ("dsp4.program.rom", "DSP-4 program", 6 << 10), ("dsp4.data.rom", "DSP-4 data", 2 << 10),
        ("st010.program.rom", "ST010 program", 48 << 10), ("st010.data.rom", "ST010 data", 4 << 10),
        ("st011.program.rom", "ST011 program", 48 << 10), ("st011.data.rom", "ST011 data", 4 << 10),
        ("st018.program.rom", "ST018 program", 128 << 10), ("st018.data.rom", "ST018 data", 32 << 10),
        ("cx4.data.rom", "Cx4 data", 3 << 10)
    ]

    var body: some View {
        PaperSheet(title: "BIOS Files", scrolls: false) {
            List {
                Section("Required") {
                    ForEach(Self.required.filter { !$0.1.contains("optional") }, id: \.0) { name, system in row(name, note: system) }
                }
                .paperRows()
                Section("Optional") {
                    ForEach(Self.required.filter { $0.1.contains("optional") }, id: \.0) { name, system in row(name, note: system) }
                }
                .paperRows()
                Section("SNES chip firmware (bsnes; Snes9x needs none)") {
                    ForEach(Self.snesFirmware, id: \.0) { name, part, bytes in
                        row(name, note: "\(part), \(bytes >> 10) KiB (\(bytes) bytes)")
                    }
                }
                .paperRows()
                Section("Imported") {
                    if files.isEmpty { Text("No BIOS files yet.").foregroundStyle(AppTheme.muted) }
                    ForEach(files, id: \.path) { url in
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                            if let data = try? Data(contentsOf: url) {
                                Text("SHA1 \(RomPatcher.checksums(data).sha1.prefix(12))…")
                                    .font(.meta).foregroundStyle(AppTheme.muted)
                            }
                        }
                    }
                }
                .paperRows()
            }
            .paperList()
        }
        .onAppear(perform: refresh)
        .fileImporter(isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } }),
                      allowedContentTypes: [.data, .item]) { outcome in
            defer { importing = nil }
            guard let name = importing, case .success(let url) = outcome else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try Self.install(url, as: name, in: biosDirectory)
                failure = nil
                refresh()
            } catch {
                failure = "\(name) was not imported: \(error.localizedDescription)"
            }
        }
        .alert("BIOS Not Imported", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func refresh() {
        try? FileManager.default.createDirectory(at: biosDirectory, withIntermediateDirectories: true)
        files = (try? FileManager.default.contentsOfDirectory(at: biosDirectory, includingPropertiesForKeys: nil)) ?? []
    }

    /// How many required BIOS files are in the system folder, for the Systems row.
    static func foundCount() -> Int {
        let names = Set(((try? FileManager.default.contentsOfDirectory(atPath: GagaCoreWrapper.systemDirectory.path)) ?? []).map { $0.lowercased() })
        return required.filter { !$0.1.contains("optional") && names.contains($0.0.lowercased()) }.count
    }

    private func row(_ name: String, note: String) -> some View {
        HStack {
            OptionTile(label: "\(name): \(present(name) ? "found" : note.contains("optional") ? "optional" : "missing")") {
                FilePicture(found: present(name), optional: note.contains("optional"))
            }
            VStack(alignment: .leading) {
                Text(name)
                Text(note).font(.meta).foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Label(present(name) ? "Found" : "Missing",
                  systemImage: present(name) ? "checkmark.circle" : "xmark.circle")
                .font(.footnote).foregroundStyle(present(name) ? AppTheme.ink : AppTheme.muted)
            Button(present(name) ? "Replace" : "Import") { importing = name }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("\(present(name) ? "Replace" : "Import") \(name)")
        }
    }

    /// Copies `file` in under the exact name its core opens, after the size check every other import route makes.
    /// A wrong file never touches one already there: it is copied aside first.
    static func install(_ file: URL, as name: String, in folder: URL) throws {
        let size = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int
        guard let size, sizes[name]?.contains(size) == true else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "Its size does not match this BIOS."])
        }
        let part = try ClipboardImporter.partFile(in: folder)
        defer { try? FileManager.default.removeItem(at: part) }
        try FileManager.default.copyItem(at: file, to: part)
        let dest = folder.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            _ = try FileManager.default.replaceItemAt(dest, withItemAt: part)
        } else {
            try FileManager.default.moveItem(at: part, to: dest)
        }
    }

    private func present(_ name: String) -> Bool {
        files.contains { $0.lastPathComponent.lowercased() == name.lowercased() }
    }
}

extension View {
    func paperList() -> some View {
        listStyle(.plain).scrollContentBackground(.hidden)
    }

    func paperRows() -> some View {
        listRowBackground(Color.clear).listRowSeparatorTint(AppTheme.rule)
    }
}
