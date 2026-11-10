import SwiftUI

/// One core in this build, for Settings > Cores.
struct CoreListing: Identifiable, Hashable {
    let id: String
    let name: String
    let version: String
    let systems: [String]

    /// Every core this build runs a game on, by name. A stub for a core left out has no save states, so it is skipped.
    static var installed: [CoreListing] {
        (0..<GagaCoreRegistry_GetCount()).compactMap { index in
            guard let core = GagaCoreRegistry_GetAtIndex(index)?.pointee, core.state_size != nil else { return nil }
            return listing(core)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func listing(coreID: String) -> CoreListing? {
        GagaCoreRegistry_FindByID(coreID).flatMap { listing($0.pointee) }
    }

    private static func listing(_ core: GagaCoreInterface) -> CoreListing? {
        let id = String(cString: core.core_id)
        let systems = CoreCatalog.platforms.filter { $0.cores.contains { $0.id == id } }.map(\.name)
        guard !systems.isEmpty, !GagaCoreRegistry_IsExcluded(id) else { return nil }
        return CoreListing(id: id, name: String(cString: core.core_name), version: String(cString: core.core_version), systems: systems)
    }
}

/// Settings > Cores: every core, with the systems it runs.
struct CoresPane: View {
    @State private var open: CoreListing?

    var body: some View {
        Text("Each core's own settings. A game's pause menu has the same page under Core Options, where changes can be kept for that game only.")
            .font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 8)
        Rule()
        ForEach(CoreListing.installed) { core in
            Button { open = core } label: {
                HStack(spacing: 12) {
                    if let platform = CoreCatalog.platforms.first(where: { $0.cores.contains { $0.id == core.id } }) {
                        OptionTile { PlatformPicture(platformID: platform.id) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(core.name)
                        Text(core.systems.joined(separator: ", ")).font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                }
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens \(core.name)'s options")
            .accessibilityIdentifier("core.\(core.id)")
            Rule()
        }
        .sheet(item: $open) { CoreOptionsView(core: $0, session: nil) }
    }
}

/// One core's options, grouped as the core groups them. From Settings it sets the core's values for every game; in a
/// game (`session`) it changes the running core too, and can keep the values for that game only.
struct CoreOptionsView: View {
    let core: CoreListing
    let session: GameSession?
    @EnvironmentObject private var state: AppState
    @State private var probed: CoreOptionSet?
    @State private var loading = true
    @State private var confirmRestart = false
    @State private var revision = 0 // Redraws after a change to the store, which this view reads through AppState.

    private var store: CoreOptionsStore { state.coreOptions }
    private var gameID: UUID? { session?.game.id }
    /// Values go to the game's own set while it has one.
    private var scopeGameID: UUID? { gameID.flatMap { store.hasGameValues(coreID: core.id, gameID: $0) || gameOnlyChosen ? $0 : nil } }
    @State private var gameOnlyChosen = false

    private var locked: String? { session?.coreOptionsLockedReason }

    private var declared: CoreOptionSet? { session?.coreOptions ?? probed ?? store.declaration(coreID: core.id) }

    var body: some View {
        PaperSheet(title: core.name, subtitle: core.systems.joined(separator: ", ")) {
            VStack(alignment: .leading, spacing: 0) {
                let _ = revision
                if let reason = locked {
                    Text(reason).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.accent).padding(.bottom, 12)
                        .accessibilityIdentifier("coreOptions.netplayLock")
                }
                if let session, !session.optionsNeedRestart.isEmpty { restartBanner(session) }
                if loading && declared == nil {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 88)
                } else if let declared, !declared.options.isEmpty {
                    if gameID != nil { scopeToggle }
                    ForEach(declared.sections, id: \.key) { section in
                        Text(section.title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                            .padding(.top, 16).padding(.bottom, 4)
                        if let info = section.info { Text(info).font(.footnote).foregroundStyle(AppTheme.muted) }
                        Rule()
                        ForEach(section.options) { option in
                            row(option)
                            Rule()
                        }
                    }
                    Button("Reset All to Defaults") { resetAll(declared) }
                        .buttonStyle(QuietButtonStyle())
                        .disabled(locked != nil)
                        .frame(minHeight: 44)
                        .padding(.top, 12)
                        .accessibilityIdentifier("coreOptions.resetAll")
                } else {
                    // Some cores (melonDS DS) declare their options only when a game loads.
                    Text(session == nil ? "\(core.name) lists its options once a game has started on it. Start one, then come back here or open Core Options from its pause menu."
                                        : "\(core.name) takes no settings of its own. GagaEmu sets everything it needs.")
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("coreOptions.none")
                }
                Text("Version \(core.version)").font(.meta).foregroundStyle(AppTheme.muted).padding(.top, 16)
            }
        }
        .task { await probe() }
        .confirmationDialog("Restart the game?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart Game") { if let session { state.restart(session) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The game saves as when you quit, then starts again from the beginning.")
        }
    }

    /// Settings asks the core with no game, off the main thread; a game's page already has the running core's.
    private func probe() async {
        defer { loading = false }
        guard session == nil else { return }
        let id = core.id
        let found = await Task.detached(priority: .userInitiated) {
            GagaCoreRegistry_FindByID(id).flatMap { GagaCoreWrapper.probeOptions($0.pointee) }
        }.value
        if let found {
            store.remember(found, coreID: id)
            probed = found
        }
    }

    private var scopeToggle: some View {
        ToggleRow(title: "This Game Only",
                  note: "On: changes here are kept for this game. Off: they are for every game on \(core.name), and this game's own are dropped.",
                  isOn: Binding(get: { scopeGameID != nil }, set: setGameOnly))
            .disabled(locked != nil)
            .accessibilityIdentifier("coreOptions.gameOnly")
    }

    private func setGameOnly(_ on: Bool) {
        guard let session, let gameID else { return }
        gameOnlyChosen = on
        if !on {
            store.reset(coreID: core.id, gameID: gameID)
            for option in declared?.options ?? [] where !option.locked {
                session.setCoreOption(option.key, store.value(option.key, coreID: core.id, gameID: nil))
            }
        }
        revision += 1
    }

    private func current(_ option: CoreOptionSet.Option) -> String? {
        store.value(option.key, coreID: core.id, gameID: scopeGameID ?? gameID) ?? option.default
    }

    @ViewBuilder private func row(_ option: CoreOptionSet.Option) -> some View {
        let value = current(option)
        let chosen = store.value(option.key, coreID: core.id, gameID: scopeGameID ?? gameID) != nil
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                OptionTile(symbol: Self.symbol(key: option.key, label: option.label), dimmed: option.locked)
                Text(option.label).frame(maxWidth: .infinity, alignment: .leading)
                if option.locked {
                    Text(option.label(of: value)).font(.meta).foregroundStyle(AppTheme.muted)
                } else {
                    Picker(option.label, selection: Binding(get: { value ?? "" }, set: { choose($0, option) })) {
                        ForEach(option.values, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .labelsHidden()
                    .disabled(locked != nil)
                    .tint(AppTheme.accent)
                    .accessibilityLabel(option.label)
                    .accessibilityValue(option.label(of: value))
                    .accessibilityIdentifier("coreOption.\(option.key)")
                }
            }
            if let info = option.info, !info.isEmpty {
                Text(info).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                if let note = note(option) {
                    Text(note).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.accent)
                }
                Spacer(minLength: 0)
                if chosen, !option.locked {
                    Button("Reset") { choose(nil, option) }
                        .buttonStyle(QuietButtonStyle())
                        .disabled(locked != nil)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Reset \(option.label) to default, \(option.label(of: option.default))")
                        .accessibilityIdentifier("coreOptions.reset.\(option.key)")
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: option.locked ? .combine : .contain)
    }

    /// A picture for an option from words in its key and label; options with no match get a slider.
    static func symbol(key: String, label: String) -> String {
        let text = (key + " " + label).lowercased()
        let table: [([String], String)] = [
            (["resolution", "upscal", "internal", "scale"], "arrow.up.left.and.arrow.down.right"),
            (["audio", "sound", "volume", "sample", "reverb"], "speaker.wave.2"),
            (["color", "colour", "palette", "gamma", "bright"], "paintpalette"),
            (["aspect", "crop", "overscan", "border", "widescreen"], "aspectratio"),
            (["frame", "skip", "speed", "fps", "cpu", "clock", "overclock", "cycle"], "speedometer"),
            (["texture", "filter", "smooth", "blend", "interlac", "dither"], "camera.filters"),
            (["bios", "region", "language", "system"], "globe"),
            (["controller", "input", "pad", "mouse", "gun", "analog", "rumble", "turbo"], "gamecontroller"),
            (["save", "memory", "card", "cartridge"], "sdcard"),
            (["renderer", "render", "gpu", "vulkan", "opengl", "shader"], "cpu"),
            (["screen", "layout", "display", "rotat"], "rectangle.split.2x1"),
            (["cheat", "hack", "patch"], "wand.and.stars"),
        ]
        return table.first { $0.0.contains(where: text.contains) }?.1 ?? "slider.horizontal.3"
    }

    private func note(_ option: CoreOptionSet.Option) -> String? {
        if option.locked { return "Set by GagaEmu" }
        if session?.optionsNeedRestart.contains(option.label) == true { return "Restart to apply" }
        switch store.appliesLive(option, coreID: core.id) {
        case false?: return "Needs restart"
        case true?: return session == nil ? nil : "Applies live"
        case nil: return nil
        }
    }

    private func choose(_ value: String?, _ option: CoreOptionSet.Option) {
        guard store.set(value, for: option, coreID: core.id, gameID: scopeGameID) else { return }
        session?.setCoreOption(option.key, store.value(option.key, coreID: core.id, gameID: gameID))
        revision += 1
    }

    private func resetAll(_ declared: CoreOptionSet) {
        store.reset(coreID: core.id, gameID: scopeGameID)
        if let session {
            for option in declared.options where !option.locked {
                session.setCoreOption(option.key, store.value(option.key, coreID: core.id, gameID: gameID))
            }
        }
        revision += 1
    }

    private func restartBanner(_ session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restart to apply: \(session.optionsNeedRestart.joined(separator: ", ")).")
                .fixedSize(horizontal: false, vertical: true)
            Button("Restart Game") { confirmRestart = true }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("coreOptions.restart")
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(.bottom, 12)
    }
}
