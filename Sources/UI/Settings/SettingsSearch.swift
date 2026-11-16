import SwiftUI

/// A sheet or cover a Settings pane opens. Panes open them through `openSetting`, so a search result can too.
enum SettingsTarget: String, Identifiable {
    case bios, achievements, skins, filters, layout, look, screen, mapping, macros, turbo, players, guides, licences, aboutUs, jit
    var id: String { rawValue }
    var fullScreen: Bool { self == .licences }

    /// The Style page a visual choice opens instead of a sheet.
    var style: StyleSection? {
        switch self {
        case .skins: return .skins
        case .filters: return .filters
        case .layout: return .layout
        case .look: return .look
        default: return nil
        }
    }
}

private struct OpenSettingKey: EnvironmentKey {
    static let defaultValue: (SettingsTarget) -> Void = { _ in }
}

private struct SettingHighlightKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// Opens a Settings sheet. Set by `SettingsView`.
    var openSetting: (SettingsTarget) -> Void {
        get { self[OpenSettingKey.self] }
        set { self[OpenSettingKey.self] = newValue }
    }

    /// The title of the row a search result just opened, which flashes once. Set by `SettingsView`.
    var settingHighlight: String? {
        get { self[SettingHighlightKey.self] }
        set { self[SettingHighlightKey.self] = newValue }
    }
}

/// Flashes a row when a search result opens it, so the eye finds it. Skipped under Reduce Motion. The row's title is
/// also its scroll target.
private struct SearchHighlight: ViewModifier {
    let title: String
    @Environment(\.settingHighlight) private var target
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: AppTheme.corner).fill(AppTheme.accent.opacity(lit ? 0.18 : 0)).padding(-6)
            }
            .id(title)
            .task(id: target) {
                guard target == title, !reduceMotion else { return }
                withAnimation(.easeIn(duration: 0.2)) { lit = true }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.6)) { lit = false }
            }
    }
}

extension View {
    func searchHighlight(_ title: String) -> some View { modifier(SearchHighlight(title: title)) }
}

/// One searchable setting: what it is called, the words people use for it, and where it lives.
struct SettingEntry: Identifiable, Hashable {
    let title: String
    let keywords: [String]
    let category: SettingsCategory
    let symbol: String
    var target: SettingsTarget?
    /// Where it is, for a setting that lives outside Settings, such as in the pause menu.
    var hint: String?

    var id: String { title }

    /// Every word of the query is in the title or a keyword.
    func matches(_ query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return false }
        let text = ([title] + keywords).joined(separator: " ").lowercased()
        return words.allSatisfy { text.contains($0) }
    }

    /// Titles that start with the query first, then the index order.
    static func search(_ query: String) -> [SettingEntry] {
        let found = all.filter { $0.matches(query) && SettingsCategory.visible.contains($0.category) }
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return found.filter { $0.title.lowercased().hasPrefix(q) } + found.filter { !$0.title.lowercased().hasPrefix(q) }
    }

    static let all: [SettingEntry] = [
        .init(title: "Player Name", keywords: ["name", "username", "user", "nickname", "profile", "firmware"], category: .profile, symbol: "person.crop.circle"),
        .init(title: "Game Center", keywords: ["account", "profile", "alias", "sign in"], category: .profile, symbol: "person.2.circle"),
        .init(title: "RetroAchievements", keywords: ["achievements", "trophy", "account", "sign in", "hardcore", "cheevos"], category: .profile, symbol: "trophy", target: .achievements),
        .init(title: "Quick Start", keywords: ["launch", "open", "recent", "startup"], category: .gameplay, symbol: "bolt"),
        .init(title: "Auto Save State", keywords: ["save", "resume", "state", "auto"], category: .gameplay, symbol: "square.and.arrow.down"),
        .init(title: "Rewind", keywords: ["back", "undo", "time"], category: .gameplay, symbol: "backward.fill"),
        .init(title: "Auto Full Screen", keywords: ["controller", "full screen", "fill"], category: .gameplay, symbol: "arrow.up.left.and.arrow.down.right"),
        .init(title: "Respect Silent Mode", keywords: ["sound", "mute", "audio", "silent", "volume"], category: .gameplay, symbol: "bell.slash"),
        .init(title: "Play Time", keywords: ["sessions", "stats", "statistics", "hours"], category: .gameplay, symbol: "clock"),
        .init(title: "Save States", keywords: ["save", "load", "slot", "state"], category: .gameplay, symbol: "tray.full", hint: "In a game: Pause, then Save State or Load State. Or a game's page in the Library."),
        .init(title: "Cheats", keywords: ["cheat", "code", "game genie", "action replay", "gameshark"], category: .gameplay, symbol: "wand.and.stars", hint: "In a game: Pause, then Cheats. Or a game's page in the Library."),
        .init(title: "Fast Forward", keywords: ["speed", "turbo", "fast"], category: .gameplay, symbol: "forward.fill", hint: "In a game: the fast forward button, or Pause, then Fast Forward."),
        .init(title: "Skins", keywords: ["skin", "touch", "layout", "buttons", "controller look", "overlay", "editor"], category: .controllers, symbol: "gamecontroller", target: .skins),
        .init(title: "Controllers and Players", keywords: ["controller", "pad", "gamepad", "player", "slot", "dualsense", "xbox", "joy-con", "mfi"], category: .controllers, symbol: "person.2", target: .players),
        .init(title: "Controller Mapping", keywords: ["controller", "map", "remap", "buttons", "keys"], category: .controllers, symbol: "gamecontroller", target: .mapping),
        .init(title: "Macros", keywords: ["macro", "record", "sequence"], category: .controllers, symbol: "record.circle", target: .macros),
        .init(title: "Turbo", keywords: ["turbo", "rapid", "auto fire"], category: .controllers, symbol: "dot.radiowaves.right", target: .turbo),
        .init(title: "Rumble", keywords: ["vibrate", "vibration", "haptic", "shake", "strength"], category: .controllers, symbol: "iphone.radiowaves.left.and.right"),
        .init(title: "Touch Haptics", keywords: ["haptic", "vibrate", "feedback", "hide touch"], category: .controllers, symbol: "hand.tap"),
        .init(title: "Skin Sound Effects", keywords: ["click", "sound", "touch"], category: .controllers, symbol: "speaker.wave.2"),
        .init(title: "Filters", keywords: ["filter", "shader", "crt", "scanlines", "lcd", "look", "smooth", "upscale"], category: .screen, symbol: "camera.filters", target: .filters),
        .init(title: "Screen Scaling and Layouts", keywords: ["scale", "scaling", "fit", "stretch", "zoom", "pixel", "dual", "ds", "3ds", "layout"], category: .screen, symbol: "rectangle.inset.filled", target: .screen),
        .init(title: "AirPlay Full Screen", keywords: ["tv", "airplay", "external", "display", "hdmi"], category: .screen, symbol: "airplayvideo"),
        .init(title: "BIOS Files", keywords: ["bios", "firmware", "system files", "boot rom"], category: .systems, symbol: "doc", target: .bios),
        .init(title: "Cores", keywords: ["core", "emulator", "options", "settings", "engine"], category: .systems, symbol: "cpu"),
        .init(title: "Default Core", keywords: ["core", "emulator", "platform", "system"], category: .systems, symbol: "cpu"),
        .init(title: "Cover Art", keywords: ["cover", "box art", "artwork", "thumbnail", "image"], category: .library, symbol: "photo"),
        .init(title: "Library Layout", keywords: ["shelf", "grid", "per row", "covers", "sort", "titles", "layout"], category: .library, symbol: "square.grid.2x2", target: .layout),
        .init(title: "App Icon and Colours", keywords: ["icon", "appearance", "dark", "light", "accent", "colour", "color", "theme"], category: .library, symbol: "paintpalette", target: .look),
        .init(title: "iCloud Sync", keywords: ["icloud", "sync", "cloud", "backup", "devices"], category: .storage, symbol: "icloud"),
        .init(title: "Clear Cache", keywords: ["cache", "space", "storage", "free"], category: .storage, symbol: "trash"),
        .init(title: "Game Files", keywords: ["storage", "size", "space", "roms"], category: .storage, symbol: "internaldrive"),
        .init(title: "GagaEmu Pro", keywords: ["pro", "plus", "subscription", "subscribe", "premium", "purchase", "buy", "restore", "forever"],
              category: .gagaPlus, symbol: "star.circle"),
        .init(title: "Guides", keywords: ["help", "how", "guide", "tutorial", "faq"], category: .help, symbol: "book", target: .guides),
        .init(title: "About Us", keywords: ["about", "version", "build"], category: .help, symbol: "info.circle", target: .aboutUs),
        .init(title: "JIT", keywords: ["jit", "speed", "fast", "sideload", "stikdebug", "debugger", "dynarec", "recompiler"],
              category: .help, symbol: "bolt", target: .jit),
        .init(title: "Licences", keywords: ["licence", "license", "open source", "credits", "gpl"], category: .help, symbol: "doc.text", target: .licences),
        .init(title: "Support and Feedback", keywords: ["support", "feedback", "contact", "privacy", "terms"], category: .help, symbol: "envelope"),
        .init(title: "Reset Tips", keywords: ["tips", "hints"], category: .help, symbol: "lightbulb")
    ]
}

/// The search field above the categories. Recent searches show while it is empty and focused.
struct SettingsSearchField: View {
    @Binding var query: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.muted).accessibilityHidden(true)
            TextField("Search settings, like skin or BIOS", text: $query)
                .submitLabel(.search)
                .focused(focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search settings")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.muted).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
    }
}

/// Results for the query, or recent searches while it is empty.
struct SettingsSearchResults: View {
    let query: String
    let recent: [String]
    /// The area the results are limited to; nil for all.
    @Binding var scope: SettingsCategory?
    let pickRecent: (String) -> Void
    let pick: (SettingEntry) -> Void

    var body: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            if !recent.isEmpty {
                Text("Recent Searches").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader).padding(.bottom, 4)
                ForEach(recent, id: \.self) { text in
                    Button { pickRecent(text) } label: {
                        Label(text, systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rule()
                }
            }
        } else {
            let all = SettingEntry.search(query)
            let found = all.filter { scope == nil || $0.category == scope }
            let areas = SettingsCategory.visible.filter { area in area == scope || all.contains { $0.category == area } }
            if !all.isEmpty { scopeBar(areas) }
            if found.isEmpty {
                Text("No settings match \u{201C}\(query)\u{201D}.").foregroundStyle(AppTheme.muted).padding(.vertical, 8)
            }
            ForEach(found) { entry in
                Button { pick(entry) } label: {
                    HStack(spacing: 12) {
                        OptionTile(symbol: entry.symbol)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(entry.title))
                            Text(entry.hint ?? entry.category.title).font(.footnote).foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                    }
                    .padding(.vertical, 6)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settingsResult.\(entry.title)")
                Rule()
            }
        }
    }

    /// All, then each area with a match: a tap limits the results to that area.
    private func scopeBar(_ areas: [SettingsCategory]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                scopeChip("All", symbol: "square.grid.2x2", id: "all", selected: scope == nil) { scope = nil }
                ForEach(areas) { area in
                    scopeChip(area.title, symbol: area.symbol, id: area.rawValue, selected: scope == area) { scope = area }
                }
            }
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search in")
    }

    private func scopeChip(_ title: String, symbol: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.footnote.weight(selected ? .bold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? AppTheme.accent : AppTheme.ink)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(selected ? AppTheme.accent : AppTheme.rule, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("searchScope.\(id)")
    }
}
