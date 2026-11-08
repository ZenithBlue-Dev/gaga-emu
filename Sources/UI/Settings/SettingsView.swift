#if !GAGA_SIDELOAD
import StoreKit
#endif
import SwiftUI

/// Two-pane settings. Only rows with working behaviour appear; docs/07 says what returns when.
/// Saved values for hidden rows stay in state.json.
struct SettingsView: View {
    @Environment(\.verticalSizeClass) private var verticalSize
    @State private var category: Category = .play
    /// The category column widens with Dynamic Type so names do not break mid-word.
    @ScaledMetric(relativeTo: .body) private var columnScale: CGFloat = 1

    enum Category: String, CaseIterable, Identifiable {
        case play = "Play", library = "Library", graphics = "Graphics", controls = "Controls",
             storage = "Storage", gagaPlus = "Gaga Plus", about = "About"
        var id: String { rawValue }
        /// Gaga Plus stays out of the app while the paywall gate is closed (docs/06 section 4.5).
        static var visible: [Category] { allCases.filter { $0 != .gagaPlus || PaywallGate.isOpen } }
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings").font(.screenTitle).accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    ForEach(Category.visible) { categoryRow($0) }
                }
            }
            .frame(width: (verticalSize == .compact ? 170 : 240) * min(columnScale, 1.5))
            Rule().ignoresSafeArea(edges: .vertical)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(category.rawValue).font(.gameTitle).accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 8)
                    detail
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(category)
        }
    }

    private func categoryRow(_ item: Category) -> some View {
        let selected = category == item
        return Button { category = item } label: {
            Text(item.rawValue)
                .fontWeight(selected ? .bold : .regular)
                .foregroundStyle(selected ? AppTheme.accent : AppTheme.ink)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(alignment: .leading) {
                    if selected { Rectangle().fill(AppTheme.accent).frame(width: 3) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var detail: some View {
        switch category {
        case .play: PlayPane()
        case .library: LibraryPane()
        case .graphics: GraphicsPane()
        case .controls: ControlsPane()
        case .storage: StoragePane()
        #if GAGA_SIDELOAD
        case .gagaPlus: EmptyView()
        #else
        case .gagaPlus: GagaPlusPane()
        #endif
        case .about: AboutPane()
        }
    }
}

// MARK: - Rows

struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(value).font(.meta).foregroundStyle(AppTheme.muted).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct ActionRow: View {
    let title: String
    var value: String?
    var symbol = "chevron.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                if let value { Text(value).font(.meta).foregroundStyle(AppTheme.muted) }
                Image(systemName: symbol).font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LinkRow: View {
    @Environment(\.openURL) private var openURL
    let title: String
    let url: String

    var body: some View {
        ActionRow(title: title, symbol: "arrow.up.right") {
            if let link = URL(string: url) { openURL(link) }
        }
        .accessibilityAddTraits(.isLink)
    }
}

private struct ToggleRow: View {
    let title: String
    let note: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(note).font(.footnote).foregroundStyle(AppTheme.muted)
            }
        }
        .tint(AppTheme.accentFill)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
}

private struct PaneNote: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
    }
}

// MARK: - Panes

private struct PlayPane: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @State private var showPlans = false

    var body: some View {
        ValueRow(title: "Total play time", value: CoreCatalog.playTime(state.totalPlayTime))
        Rule()
        ValueRow(title: "Sessions", value: "\(state.history.count)")
        Rule()
        ToggleRow(title: "Quick Start", note: "Opens your most recent game when the app starts.", isOn: $state.quickStart)
        Rule()
        // Reaching the second branch needs an open paywall gate, because a closed one lifts the limit.
        if store.canUseAutoSaveState {
            ToggleRow(title: "Auto Save State", note: "Saves when you quit or leave the app, and offers to resume when you next play.", isOn: $state.autoSaveStates)
        } else {
            ActionRow(title: "Auto Save State", value: "Plus", symbol: "lock") { showPlans = true }
                #if !GAGA_SIDELOAD
                .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
                #endif
        }
        Rule()
        ToggleRow(title: "Rewind",
                  note: "Hold the rewind button, or Options and L1 on a controller, to step back through recent play. Uses up to \(RewindPolicy.standard.budgetBytes / 1_048_576) MB of memory while a game runs. Only systems with a small, quick save state can rewind; the pause menu says when one cannot.",
                  isOn: $state.rewind)
        Rule()
        ToggleRow(title: "Auto Full Screen", note: "The picture fills the screen when a controller connects.", isOn: $state.autoFullScreen)
        Rule()
        ToggleRow(title: "Respect Silent Mode", note: "Game sound plays only when the device is not in silent mode.", isOn: $state.respectSilentMode)
        Rule()
    }
}

private struct LibraryPane: View {
    @EnvironmentObject private var state: AppState
    @State private var showBIOS = false

    var body: some View {
        ValueRow(title: "Games", value: "\(state.games.count)")
        Rule()
        ToggleRow(title: "Cover Art",
                  note: "Off by default. When on, GagaEmu reads box art lists from \(LibretroThumbnails.host) and asks it for the art of each game it matches, so that server sees which games you have. Pictures are kept in the cache. Turn this off at any time.",
                  isOn: $state.coverArt)
        Rule()
        if state.coverArt {
            ActionRow(title: "Refresh Covers", symbol: "arrow.clockwise") { state.refetchCovers() }
            Rule()
        }
        ActionRow(title: "BIOS Files") { showBIOS = true }
            .sheet(isPresented: $showBIOS) { BIOSManagerView() }
        Rule()
        Text("Default core per platform")
            .font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader).padding(.top, 16).padding(.bottom, 4)
        PaneNote(text: "Touch and hold a game in the library to change the core for that game only.")
            .padding(.bottom, 4)
        Rule()
        ForEach(CoreCatalog.platforms) { platform in
            if platform.cores.count > 1 {
                HStack {
                    Text(platform.name)
                    Spacer(minLength: 12)
                    Picker(platform.name, selection: core(platform)) {
                        ForEach(platform.cores) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                }
                .frame(minHeight: 44)
            } else {
                ValueRow(title: platform.name, value: platform.cores.first?.name ?? "")
            }
            Rule()
        }
    }

    private func core(_ platform: PlatformInfo) -> Binding<String> {
        Binding(get: { state.defaultCores[platform.id] ?? CoreCatalog.defaultCore(for: platform.id) },
                set: { state.defaultCores[platform.id] = $0 })
    }
}

private struct GraphicsPane: View {
    @EnvironmentObject private var state: AppState
    @State private var showFilters = false
    @State private var showScreen = false

    var body: some View {
        ActionRow(title: "Default Filter", value: ShaderCatalog.all.first { $0.id == state.shaderID }?.name
                  ?? state.filters.name(of: state.shaderID) ?? "Original") {
            showFilters = true
        }
        Rule()
        ActionRow(title: "Screen", value: "Scaling and layouts") { showScreen = true }
            .sheet(isPresented: $showScreen) { ScreenSettingsView(store: state.screens) }
        Rule()
        // AirPlay Fullscreen (ExternalDisplay.swift) stays hidden until it is checked on a real second screen:
        // this Xcode has no Simulator app, so no external display could be attached (docs/07 milestone 3.11).
        PaneNote(text: "New games start with this filter. Touch and hold a game to choose one for that game.")
            .fullScreenCover(isPresented: $showFilters) { FilterPickerView() }
    }
}

private struct ControlsPane: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var controllers: ControllerManager
    @State private var showTriggerPro = false
    @State private var showSkins = false

    var body: some View {
        ValueRow(title: "Touch Control", value: controllers.touchOwnsPlayerOne ? "Player 1" : "Unassigned")
        Rule()
        ForEach(controllers.devices) { device in
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
            Rule()
        }
        ActionRow(title: "Assign Skin") { showSkins = true }
            .sheet(isPresented: $showSkins) { AssignSkinView() }
        Rule()
        ActionRow(title: "TriggerPro") { showTriggerPro = true }
            .sheet(isPresented: $showTriggerPro) { TriggerProEditor() }
        Rule()
        ToggleRow(title: "Rumble", note: "The device vibrates when you press a touch control, and when a game rumbles while you play on touch.", isOn: $state.rumble)
        Rule()
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
            Text("How hard a game shakes your controller or device. Off stops game rumble everywhere.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        Rule()
        ToggleRow(title: "Skin Sound Effects", note: "Touch controls click when you press them.", isOn: $state.skinSoundEffects)
        Rule()
        if controllers.devices.isEmpty {
            PaneNote(text: "No controllers connected. Pair a DualSense, DualShock 4, Xbox, Joy-Con or MFi pad in iOS Settings.")
        }
    }
}

private struct StoragePane: View {
    @EnvironmentObject private var state: AppState
    @State private var romBytes: Int64 = 0
    @State private var showClearConfirm = false
    @State private var cleared = false

    var body: some View {
        ValueRow(title: "Game files", value: romBytes.formatted(.byteCount(style: .file)))
            .task { romBytes = folderSize(state.romDirectory) }
        Rule()
        ActionRow(title: "Clear Cache", value: cleared ? "Cleared" : nil, symbol: "trash") { showClearConfirm = true }
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
        ValueRow(title: "Status", value: status)
            #if !GAGA_SIDELOAD
            .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
            #endif
        Rule()
        if store.entitlements.showsSubscribePrompts {
            ActionRow(title: "See Plans") { showPlans = true }
            Rule()
        }
    }
}
#endif

private struct AboutPane: View {
    // App Store review is StoreKit; a sideload build is not on the App Store.
    #if !GAGA_SIDELOAD
    @Environment(\.requestReview) private var requestReview
    #endif
    @State private var showLicences = false
    @State private var showAboutUs = false
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
        ValueRow(title: "Version", value: version)
        Rule()
        ActionRow(title: "About Us") { showAboutUs = true }
            .sheet(isPresented: $showAboutUs) { AboutUsView() }
        Rule()
        if let link = URL(string: SiteLinks.appStore) {
            ShareLink(item: link, message: Text("GagaEmu plays your own game files on iPhone and iPad.")) {
                HStack {
                    Text("Share GagaEmu")
                    Spacer(minLength: 12)
                    Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                }
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rule()
        }
        ActionRow(title: "Reset Tips", value: tipsReset ? "Tips will show again" : nil, symbol: "arrow.counterclockwise") {
            Tip.reset()
            tipsReset = true
        }
        Rule()
        if hasLanguages {
            LinkRow(title: "Language", url: UIApplication.openSettingsURLString)
            Rule()
        }
        LinkRow(title: "Support and FAQ", url: SiteLinks.support)
        Rule()
        LinkRow(title: "Feedback", url: SiteLinks.support)
        Rule()
        LinkRow(title: "Terms of Service", url: SiteLinks.terms)
        Rule()
        LinkRow(title: "Privacy Policy", url: SiteLinks.privacy)
        Rule()
        #if !GAGA_SIDELOAD
        ActionRow(title: "Rate GagaEmu", symbol: "star") { requestReview() }
        Rule()
        #endif
        ActionRow(title: "Licences") { showLicences = true }
            .fullScreenCover(isPresented: $showLicences) { LicencesView() }
        Rule()
        #if DEBUG
        ActionRow(title: "Run Benchmark", value: "Debug build", symbol: "speedometer") { state.runBenchmark() }
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
                    ForEach(Self.required, id: \.0) { name, system in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                Text(system).font(.meta).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Label(present(name) ? "Found" : "Missing",
                                  systemImage: present(name) ? "checkmark.circle" : "xmark.circle")
                                .font(.footnote).foregroundStyle(present(name) ? AppTheme.ink : AppTheme.muted)
                        }
                    }
                }
                .paperRows()
                Section("SNES chip firmware (bsnes; Snes9x needs none)") {
                    ForEach(Self.snesFirmware, id: \.0) { name, part, bytes in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                Text("\(part), \(bytes >> 10) KiB (\(bytes) bytes)").font(.meta).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Label(present(name) ? "Found" : "Missing",
                                  systemImage: present(name) ? "checkmark.circle" : "xmark.circle")
                                .font(.footnote).foregroundStyle(present(name) ? AppTheme.ink : AppTheme.muted)
                        }
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
        .onAppear {
            try? FileManager.default.createDirectory(at: biosDirectory, withIntermediateDirectories: true)
            files = (try? FileManager.default.contentsOfDirectory(at: biosDirectory, includingPropertiesForKeys: nil)) ?? []
        }
    }

    private func present(_ name: String) -> Bool {
        files.contains { $0.lastPathComponent.lowercased() == name.lowercased() }
    }
}

private extension View {
    func paperList() -> some View {
        listStyle(.plain).scrollContentBackground(.hidden)
    }

    func paperRows() -> some View {
        listRowBackground(Color.clear).listRowSeparatorTint(AppTheme.rule)
    }
}
