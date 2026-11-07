import SwiftUI
import Foundation

/// One imported game. `coreOverride` wins over the platform default.
struct GameItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var platformID: String
    var romPath: String
    var coverPath: String?
    var coreOverride: String?
    var playTime: TimeInterval
    var lastPlayed: Date?
    var isFavorite: Bool
    var shaderID: String

    var resolvedCoreID: String {
        coreOverride ?? CoreCatalog.defaultCore(for: platformID)
    }
}

struct PlaySession: Identifiable, Codable, Equatable {
    var id: UUID
    var gameID: UUID
    var started: Date
    var duration: TimeInterval
}

struct PlatformInfo: Identifiable, Equatable {
    var id: String
    var name: String
    var manufacturer: String
    var cores: [CoreInfo]
}

struct CoreInfo: Identifiable, Equatable {
    var id: String
    var name: String
    var note: String
    var recommended: Bool
}

/// Static registry. Defaults match docs/03 section 2; alternates are a subset of section 3.
/// IDs are the C registry's short lowercase `core_id`, the only ID scheme. No dlopen.
enum CoreCatalog {
    static let platforms: [PlatformInfo] = [
        .init(id: "ps1", name: "PlayStation", manufacturer: "Sony", cores: [
            .init(id: "beetle_psx", name: "Beetle PSX HW", note: "PGXP, Vulkan", recommended: false),
            .init(id: "pcsx_rearmed", name: "PCSX-ReARMed", note: "Fast", recommended: true)
        ]),
        .init(id: "saturn", name: "Sega Saturn", manufacturer: "Sega", cores: [
            .init(id: "beetle_saturn", name: "Beetle Saturn", note: "Cycle accuracy", recommended: true)
        ]),
        .init(id: "megacd", name: "Mega-CD", manufacturer: "Sega", cores: [
            .init(id: "jgenesis", name: "JGenesis", note: "Mega-CD accuracy", recommended: true)
        ]),
        .init(id: "megadrive", name: "Mega Drive", manufacturer: "Sega", cores: [
            .init(id: "jgenesis", name: "JGenesis", note: "Default", recommended: true)
        ]),
        .init(id: "dreamcast", name: "Dreamcast", manufacturer: "Sega", cores: [
            .init(id: "flycast", name: "Flycast", note: "JITLess", recommended: true)
        ]),
        .init(id: "n3ds", name: "Nintendo 3DS", manufacturer: "Nintendo", cores: [
            .init(id: "azahar", name: "Azahar", note: "Interpreter", recommended: true)
        ]),
        .init(id: "nds", name: "Nintendo DS", manufacturer: "Nintendo", cores: [
            .init(id: "melonds", name: "melonDS DS", note: "Software renderer", recommended: true),
            .init(id: "desmume", name: "DeSmuME", note: "Legacy hacks", recommended: false)
        ]),
        .init(id: "gba", name: "Game Boy Advance", manufacturer: "Nintendo", cores: [
            .init(id: "mgba", name: "mGBA", note: "Accuracy", recommended: true),
            .init(id: "gpsp", name: "gpSP", note: "Interpreter", recommended: false),
            .init(id: "vba_m", name: "VBA-M", note: "ROM hacks", recommended: false)
        ]),
        .init(id: "gbc", name: "Game Boy Color", manufacturer: "Nintendo", cores: [
            .init(id: "gambatte", name: "Gambatte", note: "Cycle accuracy", recommended: true),
            .init(id: "sameboy", name: "SameBoy", note: "Audio accuracy", recommended: false)
        ]),
        .init(id: "gb", name: "Game Boy", manufacturer: "Nintendo", cores: [
            .init(id: "gambatte", name: "Gambatte", note: "Default", recommended: true)
        ]),
        .init(id: "snes", name: "Super Famicom", manufacturer: "Nintendo", cores: [
            .init(id: "bsnes", name: "bsnes", note: "Cycle accuracy", recommended: true)
        ]),
        .init(id: "nes", name: "NES", manufacturer: "Nintendo", cores: [
            .init(id: "nestopia", name: "Nestopia UE", note: "Default", recommended: true),
            .init(id: "fceumm", name: "FCEUmm", note: "Broad mappers", recommended: false)
        ]),
        .init(id: "n64", name: "Nintendo 64", manufacturer: "Nintendo", cores: [
            .init(id: "mupen64plus_next", name: "Mupen64Plus-Next", note: "ParaLLEl-RDP", recommended: true)
        ]),
        .init(id: "psp", name: "PSP", manufacturer: "Sony", cores: [
            .init(id: "ppsspp", name: "PPSSPP", note: "IR interpreter", recommended: true)
        ]),
        .init(id: "arcade", name: "Arcade", manufacturer: "Arcade", cores: [
            .init(id: "mame", name: "MAME", note: "Wide catalog", recommended: true)
        ]),
        .init(id: "dos", name: "MS-DOS", manufacturer: "Vintage", cores: [
            .init(id: "dosbox_pure", name: "DOSBox Pure", note: "ZIP launch", recommended: true)
        ]),
        .init(id: "javame", name: "Java ME", manufacturer: "Vintage", cores: [
            .init(id: "j2mejs", name: "J2meJS", note: "MIDP", recommended: true)
        ]),
        .init(id: "symbian", name: "Symbian", manufacturer: "Vintage", cores: [
            .init(id: "eka2l1", name: "EKA2L1", note: "Interpreter", recommended: true)
        ])
    ]

    static func platform(_ id: String) -> PlatformInfo? { platforms.first { $0.id == id } }

    static func defaultCore(for platformID: String) -> String {
        platform(platformID)?.cores.first { $0.recommended }?.id ?? platform(platformID)?.cores.first?.id ?? ""
    }

    static func coreName(_ id: String) -> String {
        platforms.flatMap(\.cores).first { $0.id == id }?.name ?? id
    }

    /// Extension to platform. Used by import.
    static func platformID(forExtension ext: String) -> String? {
        switch ext.lowercased() {
        case "gba": return "gba"
        case "gbc": return "gbc"
        case "gb": return "gb"
        case "nes", "fds": return "nes"
        case "sfc", "smc": return "snes"
        case "n64", "z64", "v64": return "n64"
        case "nds": return "nds"
        case "3ds", "cia": return "n3ds"
        case "iso", "bin", "cue", "chd", "pbp": return "ps1"
        case "cso": return "psp"
        case "gdi", "cdi": return "dreamcast"
        case "md", "gen", "sms": return "megadrive"
        default: return nil
        }
    }
}

/// Upgrades values saved by older builds in state.json. Safe to run on every launch.
enum StateMigration {
    /// Reverse-DNS catalog IDs from before milestone 1.3.
    static let legacyCoreIDs: [String: String] = [
        "org.libretro.beetle-psx": "beetle_psx",
        "org.libretro.pcsx-rearmed": "pcsx_rearmed",
        "org.libretro.beetle-saturn": "beetle_saturn",
        "org.libretro.jgenesis": "jgenesis",
        "org.libretro.flycast": "flycast",
        "org.azahar.azahar": "azahar",
        "org.libretro.melonds": "melonds",
        "org.libretro.desmume": "desmume",
        "org.libretro.mgba": "mgba",
        "org.libretro.gpsp": "gpsp",
        "org.libretro.vba-m": "vba_m",
        "org.libretro.gambatte": "gambatte",
        "org.libretro.sameboy": "sameboy",
        "org.libretro.bsnes": "bsnes",
        "org.libretro.nestopia": "nestopia",
        "org.libretro.fceumm": "fceumm",
        "org.libretro.mupen64plus-next": "mupen64plus_next",
        "org.ppsspp.ppsspp": "ppsspp",
        "org.libretro.mame": "mame",
        "org.libretro.dosbox-pure": "dosbox_pure",
        "org.j2mejs": "j2mejs"
    ]

    /// Cores removed by docs/03 section 6. A choice of one falls back to the platform default.
    static let removedCoreIDs: Set<String> = [
        "org.libretro.swanstation", "org.libretro.kronos", "org.libretro.genesis-plus-gx",
        "org.libretro.picodrive", "org.libretro.snes9x", "org.libretro.fbneo"
    ]

    /// nil means "no saved choice". Current and unknown IDs pass through untouched.
    static func coreID(_ saved: String) -> String? {
        removedCoreIDs.contains(saved) ? nil : legacyCoreIDs[saved] ?? saved
    }

    /// Returns the upgraded snapshot, or nil when nothing needed changing. Other fields are kept.
    static func migrated(_ snapshot: AppState.Snapshot) -> AppState.Snapshot? {
        var next = snapshot
        var changed = false
        for index in next.games.indices {
            guard let saved = next.games[index].coreOverride, coreID(saved) != saved else { continue }
            next.games[index].coreOverride = coreID(saved)
            changed = true
        }
        let cores = next.defaultCores.compactMapValues(coreID)
        if cores != next.defaultCores {
            next.defaultCores = cores
            changed = true
        }
        return changed ? next : nil
    }
}

enum ShaderCatalog {
    struct Shader: Identifiable, Equatable {
        let id: String
        let name: String
        let premium: Bool
    }
    static let builtIn: [Shader] = [
        .init(id: "original", name: "Original", premium: false),
        .init(id: "cartoon", name: "Cartoon", premium: false),
        .init(id: "crt-v1", name: "CRT v1", premium: false),
        .init(id: "crt-v2", name: "CRT v2", premium: false),
        .init(id: "geom-crt-border", name: "Geom CRT Border", premium: true),
        .init(id: "geom-crt", name: "Geom CRT", premium: true),
        .init(id: "film", name: "Film", premium: false),
        .init(id: "anime4k", name: "Anime4K / xBRZ", premium: true)
    ]
}

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case dark, light, system
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark: return "Dark Mode"
        case .light: return "Light Mode"
        case .system: return "System"
        }
    }
    var symbol: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// Single source of truth for the shell. Persists to Application Support as JSON.
@MainActor
final class AppState: ObservableObject {
    @Published var games: [GameItem] = []
    @Published var history: [PlaySession] = []
    @Published var activeGameID: UUID?
    @Published var loadedCoreID: String = ""

    @Published var nickname: String { didSet { save() } }
    @Published var joined: Date
    @Published var avatarIndex: Int { didSet { save() } }
    @Published var appearance: AppearanceMode { didSet { save() } }
    @Published var quickStart: Bool { didSet { save() } }
    @Published var autoSaveStates: Bool { didSet { save() } }
    @Published var coverScraping: Bool { didSet { save() } }
    @Published var airPlayFullscreen: Bool { didSet { save() } }
    @Published var iCloudSync: Bool { didSet { save() } }
    @Published var autoFullScreen: Bool { didSet { save() } }
    @Published var respectSilentMode: Bool { didSet { save() } }
    @Published var rumble: Bool { didSet { save() } }
    @Published var skinSoundEffects: Bool { didSet { save() } }
    @Published var language: String { didSet { save() } }
    @Published var shaderID: String { didSet { save() } }
    @Published var defaultCores: [String: String] { didSet { save() } }
    @Published var platformFilter: String = "all"
    @Published var search: String = ""

    let controllers = ControllerManager()
    let triggerPro = TriggerProManager()
    let skins = TouchSkinEngine()
    let store = StoreKitManager()
    let wifi: WiFiTransferServer

    var romDirectory: URL
    private let storeURL: URL

    struct Snapshot: Codable {
        var games: [GameItem]
        var history: [PlaySession]
        var nickname: String
        var joined: Date
        var avatarIndex: Int
        var appearance: AppearanceMode
        var quickStart: Bool
        var autoSaveStates: Bool
        var coverScraping: Bool
        var airPlayFullscreen: Bool
        var iCloudSync: Bool
        var autoFullScreen: Bool
        var respectSilentMode: Bool
        var rumble: Bool
        var skinSoundEffects: Bool
        var language: String
        var shaderID: String
        var defaultCores: [String: String]
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("GagaEmu", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        romDirectory = root.appendingPathComponent("ROMs", isDirectory: true)
        storeURL = root.appendingPathComponent("state.json")
        wifi = WiFiTransferServer(romDirectory: romDirectory)
        let stored = (try? Data(contentsOf: storeURL)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        let migrated = stored.flatMap(StateMigration.migrated)
        let snapshot = migrated ?? stored
        games = snapshot?.games ?? []
        history = snapshot?.history ?? []
        nickname = snapshot?.nickname ?? "Adventurer"
        joined = snapshot?.joined ?? Date()
        avatarIndex = snapshot?.avatarIndex ?? 0
        appearance = snapshot?.appearance ?? .dark
        quickStart = snapshot?.quickStart ?? false
        autoSaveStates = snapshot?.autoSaveStates ?? false
        coverScraping = snapshot?.coverScraping ?? true
        airPlayFullscreen = snapshot?.airPlayFullscreen ?? false
        iCloudSync = snapshot?.iCloudSync ?? false
        autoFullScreen = snapshot?.autoFullScreen ?? true
        respectSilentMode = snapshot?.respectSilentMode ?? false
        rumble = snapshot?.rumble ?? false
        skinSoundEffects = snapshot?.skinSoundEffects ?? true
        language = snapshot?.language ?? "English"
        shaderID = snapshot?.shaderID ?? "original"
        defaultCores = snapshot?.defaultCores ?? [:]
        skins.loadDefault()
        if migrated != nil { save() }
    }

    var totalPlayTime: TimeInterval { games.reduce(0) { $0 + $1.playTime } }

    var playTimeLabel: String {
        let seconds = Int(totalPlayTime)
        guard seconds > 0 else { return "Start your adventure now" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var joinedLabel: String {
        joined.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var activeGame: GameItem? { games.first { $0.id == activeGameID } }

    var filteredGames: [GameItem] {
        games.filter { game in
            (platformFilter == "all" || game.platformID == platformFilter)
                && (search.isEmpty || game.title.localizedCaseInsensitiveContains(search))
        }
    }

    var recentGames: [GameItem] {
        games.filter { $0.lastPlayed != nil }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    func coreName(for game: GameItem) -> String {
        let id = game.coreOverride ?? defaultCores[game.platformID] ?? CoreCatalog.defaultCore(for: game.platformID)
        return CoreCatalog.coreName(id)
    }

    func setCore(_ coreID: String, for gameID: UUID, global: Bool) {
        guard let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index].coreOverride = coreID
        if global { defaultCores[games[index].platformID] = coreID }
        save()
    }

    func launch(_ game: GameItem) {
        activeGameID = game.id
        loadedCoreID = game.coreOverride ?? defaultCores[game.platformID] ?? CoreCatalog.defaultCore(for: game.platformID)
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index].lastPlayed = Date()
        }
        history.insert(PlaySession(id: UUID(), gameID: game.id, started: Date(), duration: 0), at: 0)
        save()
    }

    /// Adds play time. Called when a session ends.
    func recordPlay(gameID: UUID, seconds: TimeInterval) {
        guard seconds > 0, let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index].playTime += seconds
        games[index].lastPlayed = Date()
        if let session = history.firstIndex(where: { $0.gameID == gameID && $0.duration == 0 }) {
            history[session].duration = seconds
        }
        save()
    }

    @discardableResult
    func importROM(at url: URL, title: String? = nil) -> GameItem? {
        let ext = url.pathExtension.lowercased()
        let platform = CoreCatalog.platformID(forExtension: ext) ?? "unknown"
        let name = title ?? url.deletingPathExtension().lastPathComponent
        let item = GameItem(id: UUID(), title: name, platformID: platform, romPath: url.path,
                            coverPath: nil, coreOverride: nil, playTime: 0, lastPlayed: nil,
                            isFavorite: false, shaderID: shaderID)
        games.append(item)
        save()
        return item
    }

    /// Element writes on `games` do not trigger persistence. All edits go through here.
    func update(_ id: UUID, _ change: (inout GameItem) -> Void) {
        guard let index = games.firstIndex(where: { $0.id == id }) else { return }
        change(&games[index])
        save()
        objectWillChange.send()
    }

    func delete(_ game: GameItem) {
        games.removeAll { $0.id == game.id }
        history.removeAll { $0.gameID == game.id }
        save()
    }

    func clearCache() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let caches { try? FileManager.default.removeItem(at: caches) }
    }

    private func save() {
        let snapshot = Snapshot(games: games, history: history, nickname: nickname, joined: joined,
                                avatarIndex: avatarIndex, appearance: appearance, quickStart: quickStart,
                                autoSaveStates: autoSaveStates, coverScraping: coverScraping,
                                airPlayFullscreen: airPlayFullscreen, iCloudSync: iCloudSync,
                                autoFullScreen: autoFullScreen, respectSilentMode: respectSilentMode,
                                rumble: rumble, skinSoundEffects: skinSoundEffects, language: language,
                                shaderID: shaderID, defaultCores: defaultCores)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
