import Foundation

/// A core's options as it declares them: GagaBridge.h's `options` JSON, docs/06 section 2.4.
struct CoreOptionSet: Codable, Equatable {
    struct Category: Codable, Equatable {
        let key: String
        let label: String
        let info: String?
    }

    struct Value: Codable, Equatable, Hashable {
        let value: String
        let label: String
    }

    struct Option: Codable, Equatable, Identifiable {
        let key: String
        let label: String
        let info: String?
        let category: String?
        /// What GagaEmu runs with when the player chooses nothing.
        let `default`: String?
        /// The player's value as the core holds it, or nil.
        let value: String?
        /// What the core last read, or nil before it reads this option.
        let served: String?
        let visible: Bool
        /// GagaEmu fixes it: code generation, renderer, saves, network, or what the host drives.
        let locked: Bool
        /// Nil when the core cannot say whether a change reaches a running game.
        let restart: Bool?
        let values: [Value]

        var id: String { key }
        func allows(_ value: String) -> Bool { values.contains { $0.value == value } }
        func label(of value: String?) -> String { values.first { $0.value == value }?.label ?? value ?? "" }
    }

    let categories: [Category]
    let options: [Option]

    /// Nil for NULL, which is a core with no options, or text that is not the bridge's JSON.
    static func decode(_ text: UnsafePointer<CChar>?) -> CoreOptionSet? {
        guard let text else { return nil }
        return try? JSONDecoder().decode(CoreOptionSet.self, from: Data(String(cString: text).utf8))
    }

    func option(_ key: String) -> Option? { options.first { $0.key == key } }

    /// The core's categories in its order, each with its visible options, then the uncategorised ones.
    var sections: [(key: String, title: String, info: String?, options: [Option])] {
        let shown = options.filter(\.visible)
        var result = categories.compactMap { category -> (String, String, String?, [Option])? in
            let members = shown.filter { $0.category == category.key }
            return members.isEmpty ? nil : (category.key, category.label, category.info, members)
        }
        let known = Set(categories.map(\.key))
        let rest = shown.filter { $0.category.map { !known.contains($0) } ?? true }
        if !rest.isEmpty { result.append(("", result.isEmpty ? "Options" : "Other", nil, rest)) }
        return result
    }
}

/// The player's core options: per core, and per game on top. Values are checked against what the core declared before
/// they are kept, and the core checks them again (LibretroAdapter.c). Saved in CoreOptions.json beside Saves.
@MainActor
final class CoreOptionsStore: ObservableObject {
    struct File: Codable, Equatable {
        var cores: [String: [String: String]] = [:]
        /// By "<game UUID>/<core ID>": a game may switch cores, and each core's keys are its own.
        var games: [String: [String: String]] = [:]
        /// Keys a running game took without a restart, and keys it did not, learned in play.
        var live: [String: [String]] = [:]
        var restart: [String: [String]] = [:]
    }

    @Published private(set) var file: File
    /// Each core's last declaration, so Settings can show a core that declares options only once a game loads.
    @Published private(set) var declarations: [String: CoreOptionSet] = [:]
    private let url: URL
    private let cacheFolder: URL

    init(url: URL = GagaCoreWrapper.savesDirectory.deletingLastPathComponent().appendingPathComponent("CoreOptions.json"),
         cacheFolder: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("CoreOptions")) {
        self.url = url
        self.cacheFolder = cacheFolder
        file = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(File.self, from: $0) } ?? File()
    }

    private static func gameKey(_ gameID: UUID, _ coreID: String) -> String { "\(gameID.uuidString)/\(coreID)" }

    /// What the core gets at load: the core's values with the game's on top, each one the core declared when known.
    func values(coreID: String, gameID: UUID?) -> [String: String] {
        var merged = file.cores[coreID] ?? [:]
        if let gameID { merged.merge(file.games[Self.gameKey(gameID, coreID)] ?? [:]) { $1 } }
        guard let declared = declaration(coreID: coreID) else { return merged }
        return merged.filter { key, value in declared.option(key).map { !$0.locked && $0.allows(value) } ?? true }
    }

    /// The player's value for key in this scope, or nil for the default. A game without its own falls back to the core's.
    func value(_ key: String, coreID: String, gameID: UUID?) -> String? {
        if let gameID, let own = file.games[Self.gameKey(gameID, coreID)]?[key] { return own }
        return file.cores[coreID]?[key]
    }

    func hasGameValues(coreID: String, gameID: UUID) -> Bool { !(file.games[Self.gameKey(gameID, coreID)] ?? [:]).isEmpty }

    /// False for a locked option or a value it does not declare: nothing is kept. Nil value goes back to the default.
    @discardableResult
    func set(_ value: String?, for option: CoreOptionSet.Option, coreID: String, gameID: UUID?) -> Bool {
        guard !option.locked, value.map(option.allows) ?? true else { return false }
        if let gameID {
            file.games[Self.gameKey(gameID, coreID), default: [:]][option.key] = value
        } else {
            file.cores[coreID, default: [:]][option.key] = value
        }
        save()
        return true
    }

    /// Every value in that scope back to the default.
    func reset(coreID: String, gameID: UUID?) {
        if let gameID { file.games[Self.gameKey(gameID, coreID)] = nil } else { file.cores[coreID] = nil }
        save()
    }

    /// Learned in play: whether a running game took this key's change.
    func record(coreID: String, key: String, live: Bool) {
        var yes = Set(file.live[coreID] ?? []), no = Set(file.restart[coreID] ?? [])
        if live { yes.insert(key); no.remove(key) } else { no.insert(key); yes.remove(key) }
        file.live[coreID] = yes.sorted()
        file.restart[coreID] = no.sorted()
        save()
    }

    /// True: applies live. False: needs a restart. Nil: not known yet.
    func appliesLive(_ option: CoreOptionSet.Option, coreID: String) -> Bool? {
        if let restart = option.restart { return !restart }
        if file.live[coreID]?.contains(option.key) == true { return true }
        if file.restart[coreID]?.contains(option.key) == true { return false }
        return nil
    }

    func declaration(coreID: String) -> CoreOptionSet? {
        if let known = declarations[coreID] { return known }
        let cached = (try? Data(contentsOf: cacheFolder.appendingPathComponent("\(coreID).json")))
            .flatMap { try? JSONDecoder().decode(CoreOptionSet.self, from: $0) }
        if let cached { declarations[coreID] = cached }
        return cached
    }

    /// Keeps the fuller of what the core declares now and what it declared before.
    func remember(_ set: CoreOptionSet, coreID: String) {
        if let known = declaration(coreID: coreID), known.options.count > set.options.count { return }
        declarations[coreID] = set
        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(set) {
            try? data.write(to: cacheFolder.appendingPathComponent("\(coreID).json"), options: .atomic)
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(file).write(to: url, options: .atomic)
        } catch {
            // The values stay for this run; the next change tries again.
        }
    }
}
