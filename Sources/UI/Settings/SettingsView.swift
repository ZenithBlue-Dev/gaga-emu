import SwiftUI

/// Settings. Order matches 44F4AEE0, C4E3779B, 8A17681E, 9EFF77AC.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @State private var showPaywall = false
    @State private var showShaders = false
    @State private var showCores = false
    @State private var showTriggerPro = false
    @State private var showBIOS = false
    @State private var showClearConfirm = false
    @State private var cacheNote: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                membershipBanner
                AdventurerCardView()
                section("General") {
                    appearanceRow
                    navRow("paintpalette.fill", .orange, "Theme", "App Icons, Theme Colors, Boxart Settings, Console Ordering") {}
                    toggleRow("paperplane.fill", .yellow, "Quick Start", "Skip preparation page", $state.quickStart)
                    toggleRow("arrow.down.doc.fill", .green, "Auto Save States", nil, $state.autoSaveStates)
                    navRow("tshirt.fill", .pink, "Assign Skin", nil) {}
                    navRow("photo.fill", .blue, "Cover Scraping", nil) {}
                }
                section("Advanced") {
                    toggleRow("dot.radiowaves.left.and.right", .blue, "AirPlay Fullscreen", "Enable fullscreen mirroring", $state.airPlayFullscreen)
                    navRow("icloud.fill", .orange, "iCloud Sync", state.iCloudSync ? "On" : "iCloud Not Enabled") { state.iCloudSync.toggle() }
                    toggleRow("arrow.up.left.and.arrow.down.right.circle", .teal, "Auto Full Screen",
                              "Automatically enter full screen when a controller is connected for gaming", $state.autoFullScreen)
                    navRow("cpu.fill", .red, "BIOS", "BIOS required for some platforms") { showBIOS = true }
                    toggleRow("bell.fill", .purple, "Respect Silent Mode",
                              "When enabled, Gaga-Emu will only play audio when not in silent mode.", $state.respectSilentMode)
                    navRow("globe", .orange, "Online Play Settings", nil) {}
                    toggleRow("waveform", .green, "Rumble",
                              "The device vibrates during certain events", $state.rumble)
                    toggleRow("tshirt.fill", .pink, "Skin Sound Effects", nil, $state.skinSoundEffects)
                    navRow("rosette", .blue, "RetroAchievements", nil) {}
                    navRow("square.grid.2x2", .yellow, "TriggerPro", "Create and manage advanced custom buttons.") { showTriggerPro = true }
                    navRow("circle.grid.3x3.fill", AppTheme.accent, "Shaders", nil) { showShaders = true }
                    navRow("atom", .purple, "Emulator Core", nil) { showCores = true }
                }
                section("Support") {
                    linkRow("questionmark.circle.fill", .orange, "FAQ", "https://gagaemu.app/faq")
                    linkRow("envelope.fill", .green, "Feedback", "mailto:support@gagaemu.app")
                    linkRow("bubble.left.fill", .blue, "Join QQ Channel", "https://gagaemu.app/qq")
                    linkRow("bubble.left.and.bubble.right.fill", .purple, "Join Discord", "https://discord.com")
                }
                section("Others") {
                    navRow("person.2.fill", .pink, "About Us", nil) {}
                    navRow("square.and.arrow.up", .blue, "Share Gaga-Emu", nil) {}
                    navRow("trash.fill", .yellow, "Clear Cache", cacheNote) { showClearConfirm = true }
                    navRow("bubble.left.fill", .green, "Reset Tips", "Show previously dismissed alerts and tips again") {}
                    HStack {
                        Image(systemName: "globe").foregroundStyle(.teal).frame(width: 28)
                        Text("Language").foregroundStyle(.white)
                        Spacer()
                        Text(state.language).foregroundStyle(AppTheme.textSecondary)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.vertical, 8)
                    linkRow("doc.text.fill", .red, "Terms of Service", "https://gagaemu.app/terms")
                    linkRow("lock.shield.fill", .purple, "Privacy Policy", "https://gagaemu.app/privacy")
                    navRow("shippingbox.fill", .orange, "Featured Items", nil) {}
                }
                rateCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showPaywall) { MembershipPaywallView() }
        .sheet(isPresented: $showShaders) { ShadersSettingsView() }
        .sheet(isPresented: $showCores) { EmulatorCoreListView() }
        .sheet(isPresented: $showTriggerPro) { TriggerProEditor() }
        .sheet(isPresented: $showBIOS) { BIOSManagerView() }
        .confirmationDialog("Clear cached covers, temp ROMs, and shader caches?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear Cache", role: .destructive) { state.clearCache(); cacheNote = "Cleared" }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder private var membershipBanner: some View {
        if PaywallGate.isOpen { membershipCard }
    }

    private var membershipCard: some View {
        Button { if store.entitlements.showsSubscribePrompts { showPaywall = true } } label: {
            VStack(spacing: 8) {
                Text(store.entitlements.premium ? "GAGA-EMU Membership Active" : "Unlock GAGA-EMU membership")
                    .font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
                Text("You are the protagonist of this story")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppTheme.membershipGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var appearanceRow: some View {
        HStack {
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(.blue).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Appearance").foregroundStyle(.white)
                Text(state.appearance.label).font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button { state.appearance = mode } label: {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(state.appearance == mode ? .white : AppTheme.textSecondary)
                            .frame(width: 32, height: 28)
                            .background(state.appearance == mode ? AppTheme.cardRaised : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.label)
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.3), in: Capsule())
        }
        .padding(.vertical, 6)
    }

    private var rateCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").foregroundStyle(.yellow) }
            }
            Text("Rate Us").font(.system(size: 15, weight: .bold)).foregroundStyle(AppTheme.warning)
            Text("Your 5-star rating means the world to us!")
                .font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).glassCard()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary).padding(.leading, 4)
            VStack(spacing: 4) { content() }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassCard()
        }
    }

    private func toggleRow(_ symbol: String, _ tint: Color, _ title: String, _ subtitle: String?, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            label(symbol, tint, title, subtitle)
        }
        .tint(AppTheme.accent)
        .padding(.vertical, 4)
    }

    private func navRow(_ symbol: String, _ tint: Color, _ title: String, _ subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                label(symbol, tint, title, subtitle)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ symbol: String, _ tint: Color, _ title: String, _ url: String) -> some View {
        navRow(symbol, tint, title, nil) {
            if let link = URL(string: url) { UIApplication.shared.open(link) }
        }
    }

    private func label(_ symbol: String, _ tint: Color, _ title: String, _ subtitle: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// TriggerPro editor: turbo rate, hold latch, and a combo of up to four steps.
struct TriggerProEditor: View {
    @EnvironmentObject private var triggerPro: TriggerProManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Turbo"
    @State private var mode: TriggerProManager.Mode = .turbo
    @State private var hertz = 15.0

    private let buttons: [(String, UInt32)] = [
        ("A", ControllerManager.Button.south), ("B", ControllerManager.Button.east),
        ("X", ControllerManager.Button.west), ("Y", ControllerManager.Button.north),
        ("L", ControllerManager.Button.l1), ("R", ControllerManager.Button.r1)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Bindings") {
                    ForEach(triggerPro.bindings) { binding in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(binding.name)
                                Text(binding.mode.label).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: bindingEnabled(binding.id)).labelsHidden()
                        }
                    }
                    .onDelete { triggerPro.bindings.remove(atOffsets: $0) }
                }
                Section("New") {
                    TextField("Name", text: $name)
                    Picker("Mode", selection: $mode) {
                        ForEach(TriggerProManager.Mode.allCases) { Text($0.label).tag($0) }
                    }
                    if mode == .turbo {
                        Stepper("Rate \(Int(hertz)) Hz", value: $hertz, in: 5...30, step: 1)
                    }
                    ForEach(buttons, id: \.1) { label, mask in
                        Button("Bind \(label)") { add(mask) }
                    }
                }
            }
            .navigationTitle("TriggerPro")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
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
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            List {
                Section("Required") {
                    ForEach(required, id: \.0) { name, system in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                Text(system).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: present(name) ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(present(name) ? .green : .secondary)
                        }
                    }
                }
                Section("Imported") {
                    if files.isEmpty { Text("No BIOS files yet.").foregroundStyle(.secondary) }
                    ForEach(files, id: \.path) { url in
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                            if let data = try? Data(contentsOf: url) {
                                Text("SHA1 \(RomPatcher.checksums(data).sha1.prefix(12))…")
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("BIOS")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                try? FileManager.default.createDirectory(at: biosDirectory, withIntermediateDirectories: true)
                files = (try? FileManager.default.contentsOfDirectory(at: biosDirectory, includingPropertiesForKeys: nil)) ?? []
            }
        }
    }

    private func present(_ name: String) -> Bool {
        files.contains { $0.lastPathComponent.lowercased() == name.lowercased() }
    }
}
