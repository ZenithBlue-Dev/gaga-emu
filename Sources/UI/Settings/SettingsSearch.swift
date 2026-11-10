import SwiftUI

/// A sheet or cover a Settings pane opens. Panes open them through `openSetting`, so a search result can too.
enum SettingsTarget: String, Identifiable {
    case bios, achievements, skins, filters, layout, look, screen, mapping, macros, turbo, players, guides, licences, aboutUs
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

extension EnvironmentValues {
    /// Opens a Settings sheet. Set by `SettingsView`.
    var openSetting: (SettingsTarget) -> Void {
        get { self[OpenSettingKey.self] }
        set { self[OpenSettingKey.self] = newValue }
    }
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
        .init(title: "Gaga Plus", keywords: ["plus", "subscription", "premium", "purchase", "restore"], category: .gagaPlus, symbol: "star.circle"),
        .init(title: "Guides", keywords: ["help", "how", "guide", "tutorial", "faq"], category: .help, symbol: "book", target: .guides),
        .init(title: "About Us", keywords: ["about", "version", "build"], category: .help, symbol: "info.circle", target: .aboutUs),
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
            let found = SettingEntry.search(query)
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
}
