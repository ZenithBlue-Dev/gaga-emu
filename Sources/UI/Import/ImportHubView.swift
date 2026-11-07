import SwiftUI
import UniformTypeIdentifiers

/// Import tab. Layout matches screenshot A59F001A: Files banner, WiFi and clipboard
/// tiles, MultiDisc and RomPatcher tiles, drag-and-drop strip.
struct ImportHubView: View {
    @EnvironmentObject private var state: AppState
    @State private var showFiles = false
    @State private var showMultiDisc = false
    @State private var showPatcher = false
    @State private var notice: String?
    @State private var isTargeted = false

    private let romTypes: [UTType] = {
        var types: [UTType] = [.zip, .data, .item]
        for ext in ["gba", "gbc", "gb", "nes", "sfc", "smc", "n64", "z64", "nds", "3ds", "iso", "chd", "cue", "bin", "pbp", "cso", "gdi", "cdi", "7z", "rar", "m3u"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                hero
                filesCard
                HStack(spacing: 12) {
                    wifiCard
                    clipboardCard
                }
                HStack(alignment: .top, spacing: 12) {
                    toolCard(symbol: "opticaldisc.fill", tint: .pink, title: "MultiDisc Helper") { showMultiDisc = true }
                    toolCard(symbol: "cpu", tint: .cyan, title: "RomPatcher") { showPatcher = true }
                }
                dropStrip
                if let notice {
                    Text(notice).font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: romTypes, allowsMultipleSelection: true) { result in
            importFiles(result)
        }
        .sheet(isPresented: $showMultiDisc) { MultiDiscSheet() }
        .sheet(isPresented: $showPatcher) { RomPatcherSheet() }
        .onDrop(of: romTypes, isTargeted: $isTargeted) { providers in
            consume(providers)
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 150)
            VStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill").font(.system(size: 42)).foregroundStyle(.white)
                Text("Your adventure begins here!")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.9))
            }
        }
        .accessibilityHidden(true)
    }

    private var filesCard: some View {
        Button { showFiles = true } label: {
            HStack(spacing: 14) {
                icon("folder.fill", .blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Files").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    Text("Import games, skins, game saves from files or iCloud")
                        .font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [AppTheme.card, Color.blue.opacity(0.25)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var wifiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                icon("wifi", .green)
                Spacer()
                Toggle("WiFi transfer", isOn: wifiBinding)
                    .labelsHidden()
                    .tint(AppTheme.accent)
            }
            Text("WiFi").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text(wifiDetail)
                .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .glassCard()
    }

    private var clipboardCard: some View {
        Button { readClipboard() } label: {
            VStack(alignment: .leading, spacing: 10) {
                icon("doc.on.clipboard.fill", .blue)
                Text("Read Clipboard").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Text("Supports files copied from macOS or Files app")
                    .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private func toolCard(symbol: String, tint: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                icon(symbol, tint)
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var dropStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill").foregroundStyle(AppTheme.warning)
                .frame(width: 28, height: 28).background(AppTheme.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Drag & Drop").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                Text(isTargeted ? "Release to import" : "Drag files to any Gaga-Emu interface for transfer")
                    .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
            .foregroundStyle(isTargeted ? AppTheme.accent : AppTheme.stroke))
    }

    private func icon(_ symbol: String, _ tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var wifiBinding: Binding<Bool> {
        Binding(get: { if case .running = state.wifi.state { return true } else { return false } },
                set: { $0 ? state.wifi.start() : state.wifi.stop() })
    }

    private var wifiDetail: String {
        switch state.wifi.state {
        case .stopped: return "Off by default. Transfers files by browser on your network over unencrypted local HTTP."
        case .running(let host, let port, let pin): return "http://\(host):\(port)\nPIN \(pin)\nUnencrypted local HTTP. Turn off when done."
        case .failed(let message): return message
        }
    }

    /// Only runs from the button. Clipboard is never read otherwise.
    private func readClipboard() {
        do {
            let item = try ClipboardImporter.scan()
            switch item {
            case .remote(let url):
                notice = "Downloading \(url.lastPathComponent)…"
                Task {
                    do {
                        let dest = try await ClipboardImporter.download(url, into: state.romDirectory)
                        _ = state.importROM(at: dest)
                        notice = "Imported \(dest.lastPathComponent)"
                    } catch {
                        notice = error.localizedDescription
                    }
                }
            default:
                let dest = try ClipboardImporter.persist(item, into: state.romDirectory)
                _ = state.importROM(at: dest)
                notice = "Imported \(dest.lastPathComponent)"
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): notice = error.localizedDescription
        case .success(let urls):
            var count = 0
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let dest = try? ClipboardImporter.persist(.file(url), into: state.romDirectory) {
                    _ = state.importROM(at: dest)
                    count += 1
                }
            }
            notice = "Imported \(count) file\(count == 1 ? "" : "s")"
        }
    }

    private func consume(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    if let dest = try? ClipboardImporter.persist(.file(url), into: state.romDirectory) {
                        _ = state.importROM(at: dest)
                        notice = "Imported \(dest.lastPathComponent)"
                    }
                }
            }
        }
        return accepted
    }
}

struct MultiDiscSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [MultiDiscHelper.Group] = []
    @State private var written: [String] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if groups.isEmpty {
                    Text("No multi-disc games found in the ROM folder.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        Text("\(group.platform.rawValue) · \(group.discs.count) discs")
                            .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).glassCard(radius: 16)
                }
                Button {
                    written = (try? MultiDiscHelper.generateAll(in: state.romDirectory))?.map(\.lastPathComponent) ?? []
                    for name in written {
                        _ = state.importROM(at: state.romDirectory.appendingPathComponent(name), title: name.replacingOccurrences(of: ".m3u", with: ""))
                    }
                } label: {
                    Text("Generate Playlists")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(groups.isEmpty ? AnyShapeStyle(AppTheme.card) : AnyShapeStyle(AppTheme.brandGradient), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(groups.isEmpty)
                if !written.isEmpty {
                    Text("Wrote \(written.joined(separator: ", "))").font(.system(size: 13)).foregroundStyle(AppTheme.accentGreen)
                }
                Spacer()
            }
            .padding(20)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("MultiDisc Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { groups = MultiDiscHelper.scan(state.romDirectory) }
        }
    }
}

struct RomPatcherSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var rom: URL?
    @State private var patch: URL?
    @State private var picking: Pick?
    @State private var result: String?
    enum Pick: Identifiable { case rom, patch; var id: Int { self == .rom ? 0 : 1 } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                picker("ROM", url: rom) { picking = .rom }
                picker("Patch (IPS, UPS, BPS)", url: patch) { picking = .patch }
                Button { apply() } label: {
                    Text("Apply Patch")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(rom != nil && patch != nil ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.card), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(rom == nil || patch == nil)
                if let result { Text(result).font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary) }
                Text("The original ROM is left untouched. The patched copy is saved next to it.")
                    .font(.system(size: 12)).foregroundStyle(AppTheme.textTertiary)
                Spacer()
            }
            .padding(20)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("RomPatcher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                          allowedContentTypes: [.data, .item]) { outcome in
                if case .success(let url) = outcome {
                    if picking == .rom { rom = url } else { patch = url }
                }
                picking = nil
            }
        }
    }

    private func picker(_ title: String, url: URL?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
                    Text(url?.lastPathComponent ?? "Choose file").foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "folder").foregroundStyle(AppTheme.textSecondary)
            }
            .padding(14).glassCard(radius: 16)
        }
        .buttonStyle(.plain)
    }

    private func apply() {
        guard let rom, let patch else { return }
        let scopedROM = rom.startAccessingSecurityScopedResource()
        let scopedPatch = patch.startAccessingSecurityScopedResource()
        defer {
            if scopedROM { rom.stopAccessingSecurityScopedResource() }
            if scopedPatch { patch.stopAccessingSecurityScopedResource() }
        }
        let dest = state.romDirectory.appendingPathComponent("patched-\(rom.lastPathComponent)")
        do {
            let sums = try RomPatcher.apply(patch: patch, toSource: rom, writingTo: dest)
            _ = state.importROM(at: dest, title: "\(rom.deletingPathExtension().lastPathComponent) (patched)")
            result = "Saved. CRC32 \(String(format: "%08X", sums.crc32)) · MD5 \(sums.md5)"
        } catch {
            result = error.localizedDescription
        }
    }
}
