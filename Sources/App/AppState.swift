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

    /// Resolution order: game override, platform default, catalog recommendation.
    func resolvedCoreID(defaults: [String: String]) -> String {
        coreOverride ?? defaults[platformID] ?? CoreCatalog.defaultCore(for: platformID)
    }

    /// The saved absolute path goes stale when iOS moves the app container, so also look in the ROM folder.
    func resolvedROMPath(romDirectory: URL) -> String? {
        let name = URL(fileURLWithPath: romPath).lastPathComponent
        return [romPath, romDirectory.appendingPathComponent(name).path]
            .first(where: FileManager.default.fileExists(atPath:))
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
    /// Without the cores this build left out (`GAGA_CORE_SET`), or any platform with none left.
    static let platforms: [PlatformInfo] = allPlatforms.compactMap { platform in
        let cores = platform.cores.filter { !GagaCoreRegistry_IsExcluded($0.id) }
        return cores.isEmpty ? nil : PlatformInfo(id: platform.id, name: platform.name,
                                                  manufacturer: platform.manufacturer, cores: cores)
    }

    private static let allPlatforms: [PlatformInfo] = [
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

    static func platformName(_ id: String) -> String { platform(id)?.name ?? "Other" }

    /// Short label for chips and metadata.
    static func platformCode(_ id: String) -> String {
        let special = ["saturn": "SAT", "megacd": "MCD", "megadrive": "MD", "dreamcast": "DC", "n3ds": "3DS",
                       "arcade": "ARC", "javame": "JME", "symbian": "SYM", "unknown": "ETC"]
        return special[id] ?? id.uppercased()
    }

    static func playTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

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

    /// Not implemented (milestone 3.4), so never offered. A saved choice falls back to Original.
    static let removedShaderIDs: Set<String> = ["anime4k", "crt-royale"]

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
        for index in next.games.indices where removedShaderIDs.contains(next.games[index].shaderID) {
            next.games[index].shaderID = "original"
            changed = true
        }
        if removedShaderIDs.contains(next.shaderID) {
            next.shaderID = "original"
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

/// The app's one web host, the same one the App Store metadata uses.
enum SiteLinks {
    private static let host = "https://zenithblue-oss.github.io/gaga-emu-site"
    /// The site's page is "Support & FAQ", and it is also the feedback route.
    static let support = "\(host)/support.html"
    static let privacy = "\(host)/privacy.html"
    /// shortcut: the site has no terms.html (404), so this is Apple's standard EULA; replace when the site has one.
    static let terms = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
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
        .init(id: "film", name: "Film", premium: false)
    ]
}

/// Saved value only. The app follows the system appearance; this keeps old state.json files decoding.
enum AppearanceMode: String, Codable {
    case dark, light, system
}

/// Single source of truth for the shell. Persists to Application Support as JSON.
@MainActor
final class AppState: ObservableObject {
    @Published var games: [GameItem] = []
    @Published var history: [PlaySession] = []
    @Published var activeGameID: UUID?
    @Published var loadedCoreID: String = ""
    /// Non-nil while a game is on screen.
    @Published var session: GameSession?
    /// A launch is preparing the core, before any game view is on screen.
    @Published private(set) var launching = false
    @Published var launchFailure: LaunchFailure?
    /// A game waiting on the player's answer: resume its auto save, or start from the battery save.
    @Published var resumeOffer: GameItem?
    /// Waits for the game view to finish dismissing, because an alert cannot present during that.
    private var pendingFailure: LaunchFailure?

    struct LaunchFailure: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String

        var heading: String {
            #if DEBUG
            // A finished benchmark ends its session the same way a failure does.
            if message.hasPrefix("Benchmark saved") { return "Benchmark finished" }
            #endif
            return "Could not play \(title)"
        }
    }

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
        wifi.onUploaded = { [weak self] names in
            MainActor.assumeIsolated { self?.addUploads(names) }
        }
    }

    /// A file uploaded again replaces its bytes on disk, so it must not become a second shelf entry.
    func addUploads(_ names: [String]) {
        for name in names where !games.contains(where: { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }) {
            importROM(at: romDirectory.appendingPathComponent(name))
        }
    }

    var totalPlayTime: TimeInterval { games.reduce(0) { $0 + $1.playTime } }

    var activeGame: GameItem? { games.first { $0.id == activeGameID } }

    /// `platformFilter` is "all", "recent" or a platform ID.
    var filteredGames: [GameItem] {
        (platformFilter == "recent" ? recentGames : games).filter { game in
            (platformFilter == "all" || platformFilter == "recent" || game.platformID == platformFilter)
                && (search.isEmpty || game.title.localizedCaseInsensitiveContains(search))
        }
    }

    var recentGames: [GameItem] {
        games.filter { $0.lastPlayed != nil }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    func coreName(for game: GameItem) -> String {
        CoreCatalog.coreName(game.resolvedCoreID(defaults: defaultCores))
    }

    func setCore(_ coreID: String, for gameID: UUID, global: Bool) {
        guard let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index].coreOverride = coreID
        if global { defaultCores[games[index].platformID] = coreID }
        save()
    }

    /// A saved value from the old free toggle must not get past the gate (docs/07 2.6).
    var autoSaveEnabled: Bool { autoSaveStates && store.canUseAutoSaveState }

    /// Offers to resume first when there is an auto save to resume.
    func launch(_ game: GameItem) {
        if autoSaveEnabled, saveStore(for: game).autoSlot != nil {
            resumeOffer = game
        } else {
            start(game)
        }
    }

    func saveStore(for game: GameItem) -> SaveStore {
        SaveStore(romPath: game.resolvedROMPath(romDirectory: romDirectory) ?? game.romPath)
    }

    /// Loads the core off screen first, so a failure stays on the Library with a message. A state that
    /// will not load is not a failed launch: the game still starts, and says why.
    func start(_ game: GameItem, loading slot: SaveSlot? = nil) {
        guard session == nil, !launching else { return }
        launching = true
        Task {
            defer { launching = false }
            do {
                let next = try makeSession(for: game)
                try await next.prepare()
                if let slot {
                    do {
                        try next.loadState(slot)
                    } catch {
                        next.notice = error.localizedDescription
                    }
                }
                next.onStarted = { [weak self] in self?.recordStart(of: game) }
                next.onPlayTime = { [weak self] in self?.recordPlay(gameID: game.id, seconds: $0) }
                next.onFinish = { [weak self] message in self?.endSession(game: game, message: message) }
                session = next
            } catch {
                launchFailure = LaunchFailure(title: game.title, message: error.localizedDescription)
            }
        }
    }

    #if DEBUG
    /// Runs the benchmark on `rom`, or on the generated test ROM. It stays out of the Library and play history.
    func runBenchmark(rom: URL? = nil, seconds: TimeInterval = BenchmarkRun.defaultSeconds) {
        guard session == nil, !launching else { return }
        launching = true
        Task {
            defer { launching = false }
            do {
                let romURL = try rom ?? BenchmarkRun.writeTestROM(to: romDirectory)
                let game = GameItem(id: UUID(), title: "Benchmark", platformID: "gba", romPath: romURL.path,
                                    coverPath: nil, coreOverride: "mgba", playTime: 0, lastPlayed: nil,
                                    isFavorite: false, shaderID: "original")
                let next = try makeSession(for: game)
                next.autoSaveEnabled = { false }
                try await next.prepare()
                guard let interface = GagaCoreRegistry_FindByID("mgba")?.pointee else { return }
                let run = BenchmarkRun(session: next, interface: interface, romURL: romURL, seconds: seconds)
                run.attach()
                next.onFinish = { [weak self] message in self?.endSession(game: game, message: message) }
                session = next
                Task { await run.drive() }
            } catch {
                launchFailure = LaunchFailure(title: "Benchmark", message: error.localizedDescription)
            }
        }
    }

    func runBenchmarkIfRequested() {
        let defaults = UserDefaults.standard
        guard ProcessInfo.processInfo.arguments.contains("-GagaBenchmark") else { return }
        let seconds = defaults.double(forKey: "GagaBenchmarkSeconds")
        runBenchmark(rom: defaults.string(forKey: "GagaBenchmarkROM").map { romDirectory.appendingPathComponent($0) },
                     seconds: seconds > 0 ? seconds : BenchmarkRun.defaultSeconds)
    }
    #endif

    func makeSession(for game: GameItem) throws -> GameSession {
        let coreID = game.resolvedCoreID(defaults: defaultCores)
        guard !coreID.isEmpty else { throw GameLaunchError.noCore }
        guard let interface = GagaCoreRegistry_FindByID(coreID)?.pointee else {
            throw GameLaunchError.coreNotBuilt(CoreCatalog.coreName(coreID))
        }
        guard let romPath = game.resolvedROMPath(romDirectory: romDirectory) else {
            throw GameLaunchError.romMissing(URL(fileURLWithPath: game.romPath).lastPathComponent)
        }
        skins.hapticsEnabled = rumble
        skins.soundEnabled = skinSoundEffects
        let shader = store.canUseShader(game.shaderID) ? game.shaderID : "original"
        let session = try GameSession(game: game, interface: interface, romPath: romPath, controllers: controllers,
                                      skins: skins, bindings: triggerPro.bindings, shaderID: shader,
                                      respectSilentMode: respectSilentMode,
                                      entitlements: { [store] in store.entitlements })
        session.autoSaveEnabled = { [weak self] in self?.autoSaveEnabled ?? false }
        return session
    }

    private func recordStart(of game: GameItem) {
        activeGameID = game.id
        loadedCoreID = game.resolvedCoreID(defaults: defaultCores)
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index].lastPlayed = Date()
        }
        history.insert(PlaySession(id: UUID(), gameID: game.id, started: Date(), duration: 0), at: 0)
        save()
    }

    private func endSession(game: GameItem, message: String?) {
        pendingFailure = message.map { LaunchFailure(title: game.title, message: $0) }
        activeGameID = nil
        session = nil
    }

    func showPendingFailure() {
        launchFailure = pendingFailure
        pendingFailure = nil
    }

    /// Adds play time to the game and to its newest history entry. A session calls this several times.
    func recordPlay(gameID: UUID, seconds: TimeInterval) {
        guard seconds > 0, let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index].playTime += seconds
        games[index].lastPlayed = Date()
        if let session = history.firstIndex(where: { $0.gameID == gameID }) {
            history[session].duration += seconds
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
