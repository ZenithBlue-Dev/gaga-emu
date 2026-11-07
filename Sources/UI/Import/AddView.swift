import SwiftUI
import UniformTypeIdentifiers

/// Left: Files and the drop target. Right: the other sources.
struct AddView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var wifi: WiFiTransferServer
    @State private var showFiles = false
    @State private var showMultiDisc = false
    @State private var showPatcher = false
    @State private var notice: String?
    @State private var isTargeted = false
    /// Disc images whose contents did not name a platform, asked one at a time.
    @State private var unplaced: [GameItem] = []

    private let romTypes: [UTType] = {
        var types: [UTType] = [.zip, .data, .item]
        for ext in ["gba", "gbc", "gb", "nes", "sfc", "smc", "n64", "z64", "nds", "3ds", "iso", "chd", "cue", "bin", "pbp", "cso", "gdi", "cdi", "7z", "rar", "m3u", "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf", "sms", "gg", "sg", "mv", "a26", "a78", "lnx", "a52", "xex", "atr", "xfd", "dcm", "atx", "j64", "jag", "d64", "t64", "prg", "crt", "tap"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }()

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Games").font(.screenTitle).accessibilityAddTraits(.isHeader)
                    Button { showFiles = true } label: {
                        Label("Choose from Files", systemImage: "folder").frame(minHeight: 72)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    dropTarget
                    if let notice { Text(notice).font(.footnote).foregroundStyle(AppTheme.muted) }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            Rule().ignoresSafeArea(edges: .vertical)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    wifiRow
                    Rule()
                    sourceRow("Read Clipboard", "doc.on.clipboard", "Reads the clipboard only when you tap here.", readClipboard)
                    Rule()
                    sourceRow("Multi-Disc Helper", "opticaldisc", "Joins disc files into one playlist.") { showMultiDisc = true }
                    Rule()
                    sourceRow("Patch a ROM", "bandage", "Applies an IPS, UPS or BPS patch to a copy.") { showPatcher = true }
                    Rule()
                    Text("Add only games you have the right to use. GagaEmu comes with no games.")
                        .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 12)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: romTypes, allowsMultipleSelection: true) { result in
            importFiles(result)
        }
        .sheet(isPresented: $showMultiDisc) { MultiDiscSheet() }
        .sheet(isPresented: $showPatcher) { RomPatcherSheet() }
        .onDrop(of: romTypes, isTargeted: $isTargeted) { providers in
            consume(providers)
        }
        .confirmationDialog("Which system is \(unplaced.first?.title ?? "this disc") for?",
                            isPresented: Binding(get: { !unplaced.isEmpty }, set: { if !$0, !unplaced.isEmpty { unplaced.removeFirst() } }),
                            titleVisibility: .visible) {
            ForEach(unplaced.first.flatMap { CoreCatalog.unplacedPlatforms(forExtension: URL(fileURLWithPath: $0.romPath).pathExtension) } ?? []) { platform in
                Button(platform.name) {
                    if let game = unplaced.first { state.update(game.id) { $0.platformID = platform.id } }
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("GagaEmu could not tell from the file.")
        }
    }

    /// Imports a copied file, and queues the platform question when a disc image or .zip did not say.
    private func add(_ dest: URL) {
        guard let game = state.importROM(at: dest) else { return }
        if game.platformID == "unknown", CoreCatalog.unplacedPlatforms(forExtension: dest.pathExtension) != nil {
            unplaced.append(game)
        }
    }

    private var dropTarget: some View {
        Text(isTargeted ? "Release to add" : "Or drop files here")
            .font(.subheadline.weight(isTargeted ? .bold : .regular))
            .foregroundStyle(isTargeted ? AppTheme.accent : AppTheme.muted)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner)
                .stroke(isTargeted ? AppTheme.accent : AppTheme.muted, style: StrokeStyle(lineWidth: 1, dash: [5])))
    }

    private var wifiRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi").frame(width: 24).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("WiFi Transfer")
                wifiDetail
            }
            Spacer(minLength: 0)
            Toggle("WiFi Transfer", isOn: wifiBinding).labelsHidden().tint(AppTheme.accentFill)
        }
        .padding(.vertical, 10)
    }

    private func sourceRow(_ title: String, _ symbol: String, _ detail: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail).font(.footnote).foregroundStyle(AppTheme.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var wifiBinding: Binding<Bool> {
        Binding(get: { if case .running = wifi.state { return true } else { return false } },
                set: { $0 ? wifi.start() : wifi.stop() })
    }

    @ViewBuilder private var wifiDetail: some View {
        switch wifi.state {
        case .stopped:
            Text("Off by default. Sends files from a browser over unencrypted local HTTP.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
        case .running(let host, let port, let pin):
            // Verbatim: a localized string formats the port with a thousands separator.
            Text(verbatim: "http://\(host):\(port)\nPIN \(pin)").font(.meta)
            Text("Unencrypted local HTTP. Turn off when done.").font(.footnote).foregroundStyle(AppTheme.muted)
        case .failed(let message):
            Text(message).font(.footnote).foregroundStyle(AppTheme.muted)
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
                        add(dest)
                        notice = "Imported \(dest.lastPathComponent)"
                    } catch {
                        notice = error.localizedDescription
                    }
                }
            default:
                let dest = try ClipboardImporter.persist(item, into: state.romDirectory)
                add(dest)
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
            // Copy every file before importing any, so a .cue finds the .bin picked with it.
            let copied = urls.compactMap { url -> URL? in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                return try? ClipboardImporter.persist(.file(url), into: state.romDirectory)
            }
            copied.forEach(add)
            notice = "Imported \(copied.count) file\(copied.count == 1 ? "" : "s")"
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
                        add(dest)
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
    @State private var groups: [MultiDiscHelper.Group] = []
    @State private var written: [String] = []

    var body: some View {
        PaperSheet(title: "Multi-Disc Helper") {
            VStack(alignment: .leading, spacing: 0) {
                if groups.isEmpty {
                    Text("No multi-disc games found in the ROM folder.").foregroundStyle(AppTheme.muted)
                }
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                        Text("\(group.platform.rawValue) · \(group.discs.count) discs")
                            .font(.meta).foregroundStyle(AppTheme.muted)
                    }
                    .padding(.vertical, 8)
                    Rule()
                }
                Button("Generate Playlists") {
                    written = []
                    // The discs' platform, because an .m3u alone does not name one.
                    for group in MultiDiscHelper.scan(state.romDirectory) {
                        guard let playlist = try? MultiDiscHelper.writePlaylist(for: group, into: state.romDirectory) else { continue }
                        written.append(playlist.lastPathComponent)
                        _ = state.importROM(at: playlist, title: group.title, platformID: group.platform.platformID)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(groups.isEmpty)
                .padding(.top, 16)
                if !written.isEmpty {
                    Text("Wrote \(written.joined(separator: ", "))").font(.footnote).padding(.top, 8)
                }
            }
        }
        .onAppear { groups = MultiDiscHelper.scan(state.romDirectory) }
    }
}

struct RomPatcherSheet: View {
    @EnvironmentObject private var state: AppState
    @State private var rom: URL?
    @State private var patch: URL?
    @State private var picking: Pick?
    @State private var result: String?
    enum Pick: Identifiable { case rom, patch; var id: Int { self == .rom ? 0 : 1 } }

    var body: some View {
        PaperSheet(title: "Patch a ROM") {
            VStack(alignment: .leading, spacing: 0) {
                picker("ROM", url: rom) { picking = .rom }
                Rule()
                picker("Patch (IPS, UPS, BPS)", url: patch) { picking = .patch }
                Rule()
                Button("Apply Patch") { apply() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(rom == nil || patch == nil)
                    .padding(.top, 16)
                if let result { Text(result).font(.meta).foregroundStyle(AppTheme.muted).padding(.top, 8) }
                Text("The original ROM is left untouched. The patched copy is saved next to it.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
            }
        }
        .fileImporter(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                      allowedContentTypes: [.data, .item]) { outcome in
            if case .success(let url) = outcome {
                if picking == .rom { rom = url } else { patch = url }
            }
            picking = nil
        }
    }

    private func picker(_ title: String, url: URL?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.footnote).foregroundStyle(AppTheme.muted)
                    Text(url?.lastPathComponent ?? "Choose file")
                }
                Spacer(minLength: 0)
                Image(systemName: "folder").foregroundStyle(AppTheme.muted).accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
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
