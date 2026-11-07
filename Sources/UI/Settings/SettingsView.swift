import SwiftUI

/// Two-pane settings. Only rows with working behaviour appear; docs/07 says what returns when.
/// Saved values for hidden rows stay in state.json.
struct SettingsView: View {
    @Environment(\.verticalSizeClass) private var verticalSize
    @State private var category: Category = .play

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
            .frame(width: verticalSize == .compact ? 170 : 240)
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
        case .gagaPlus: GagaPlusPane()
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

private struct PaneNote: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
    }
}

// MARK: - Panes

private struct PlayPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ValueRow(title: "Total play time", value: CoreCatalog.playTime(state.totalPlayTime))
        Rule()
        ValueRow(title: "Sessions", value: "\(state.history.count)")
        Rule()
        PaneNote(text: "Options for running games appear here once a core can run one.")
    }
}

private struct LibraryPane: View {
    @EnvironmentObject private var state: AppState
    @State private var showBIOS = false

    var body: some View {
        ValueRow(title: "Games", value: "\(state.games.count)")
        Rule()
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

    var body: some View {
        ActionRow(title: "Default Filter", value: ShaderCatalog.builtIn.first { $0.id == state.shaderID }?.name) {
            showFilters = true
        }
        Rule()
        PaneNote(text: "New games start with this filter. Touch and hold a game to choose one for that game.")
            .fullScreenCover(isPresented: $showFilters) { FilterPickerView() }
    }
}

private struct ControlsPane: View {
    @EnvironmentObject private var controllers: ControllerManager
    @State private var showTriggerPro = false

    var body: some View {
        ValueRow(title: "Touch Control", value: controllers.touchOwnsPlayerOne ? "Player 1" : "Unassigned")
        Rule()
        ForEach(controllers.devices) { device in
            HStack {
                Text(device.name)
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
        ActionRow(title: "TriggerPro") { showTriggerPro = true }
            .sheet(isPresented: $showTriggerPro) { TriggerProEditor() }
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

private struct GagaPlusPane: View {
    @EnvironmentObject private var store: StoreKitManager
    @State private var showPlans = false

    private var status: String {
        if store.entitlements.lifetime { return "Lifetime" }
        return store.entitlements.premium ? "Active" : "Not subscribed"
    }

    var body: some View {
        ValueRow(title: "Status", value: status)
            .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
        Rule()
        if store.entitlements.showsSubscribePrompts {
            ActionRow(title: "See Plans") { showPlans = true }
            Rule()
        }
    }
}

private struct AboutPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    var body: some View {
        ValueRow(title: "Version", value: version)
        Rule()
        LinkRow(title: "Support and FAQ", url: SiteLinks.support)
        Rule()
        LinkRow(title: "Feedback", url: SiteLinks.support)
        Rule()
        LinkRow(title: "Terms of Service", url: SiteLinks.terms)
        Rule()
        LinkRow(title: "Privacy Policy", url: SiteLinks.privacy)
        Rule()
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

    private var biosDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GagaEmu/BIOS", isDirectory: true)
    }

    private let required: [(String, String)] = [
        ("scph5501.bin", "PS1 (US)"), ("scph5502.bin", "PS1 (EU)"),
        ("bios7.bin", "DS ARM7"), ("bios9.bin", "DS ARM9"),
        ("firmware.bin", "DS firmware")
    ]

    var body: some View {
        PaperSheet(title: "BIOS Files", scrolls: false) {
            List {
                Section("Required") {
                    ForEach(required, id: \.0) { name, system in
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
