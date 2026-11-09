import SwiftUI
import UniformTypeIdentifiers

/// Left: Files and the drop target. Right: the other sources.
struct AddView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var wifi: WiFiTransferServer
    @State private var showFiles = false
    @State private var showMultiDisc = false
    @State private var showPatcher = false
    @State private var showWebDAV = false
    @State private var showRomM = false
    @State private var notice: String?
    @State private var isTargeted = false
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.verticalSizeClass) private var verticalSize

    var body: some View {
        // Upright on a phone the two columns stack. A landscape phone other than a Max also has a compact width, so
        // the height class decides: compact width alone stacked them in landscape too.
        let upright = horizontalSize == .compact && verticalSize == .regular
        Group {
            if upright {
                // One scroll: two half-height scrolls left each cramped.
                ScrollView {
                    VStack(spacing: 0) {
                        filesColumn
                        Rule()
                        sourcesColumn
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ScrollView { filesColumn }.frame(maxWidth: .infinity)
                    Rule(vertical: true).ignoresSafeArea(edges: .vertical)
                    ScrollView { sourcesColumn }.frame(maxWidth: .infinity)
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: GameFileTypes.all, allowsMultipleSelection: true) { result in
            importFiles(result)
        }
        .sheet(isPresented: $showMultiDisc) { MultiDiscSheet() }
        .sheet(isPresented: $showPatcher) { RomPatcherSheet() }
        .sheet(isPresented: $showWebDAV) { WebDAVSheet() }
        .sheet(isPresented: $showRomM) { RomMSheet() }
        .gameFileDrop(isTargeted: $isTargeted) { line, _ in notice = line }
        #if DEBUG
        .onAppear { DownloadQueue.shared.seedForWalk() }
        #endif
    }

    private var filesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Games").font(.screenTitle).accessibilityAddTraits(.isHeader)
            Button { showFiles = true } label: {
                Label("Choose from Files", systemImage: "folder").frame(minHeight: 72)
            }
            .buttonStyle(PrimaryButtonStyle())
            dropTarget
            TipLine(tip: .dropFiles)
            ImportProgressRows()
            DownloadRows()
            if let notice { Text(notice).font(.footnote).foregroundStyle(AppTheme.muted) }
        }
        .padding(16)
    }

    private var sourcesColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            wifiRow
            Rule()
            sourceRow("Read Clipboard", "doc.on.clipboard", "Reads the clipboard only when you tap here.", readClipboard)
            Rule()
            sourceRow("WebDAV Server", "externaldrive.connected.to.line.below", "Browse your own server and copy games in.") { showWebDAV = true }
            Rule()
            sourceRow("RomM Server", "books.vertical", "Browse your own RomM library and copy games in.") { showRomM = true }
            Rule()
            sourceRow("SMB Share", "server.rack", "Connect to it in the Files app first, then pick your games here.") { showFiles = true }
            Rule()
            sourceRow("Multi-Disc Helper", "opticaldisc", "Joins disc files into one playlist.") { showMultiDisc = true }
            Rule()
            sourceRow("Patch a ROM", "bandage", "Applies an IPS, UPS, BPS, PPF, APS or RUP patch to a copy.") { showPatcher = true }
            Rule()
            Text("Add only games you have the right to use. GagaEmu comes with no games.")
                .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 12)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
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
                    Text(LocalizedStringKey(title))
                    Text(LocalizedStringKey(detail)).font(.footnote).foregroundStyle(AppTheme.muted).multilineTextAlignment(.leading)
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
            let dest = try ClipboardImporter.persist(item, into: state.romDirectory)
            Task { notice = await state.importChosen(dest) ?? "Imported \(dest.lastPathComponent)" }
        } catch {
            notice = error.localizedDescription
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): notice = error.localizedDescription
        case .success(let urls):
            let romDirectory = state.romDirectory
            Task {
                // Copy every file before importing any, so a .cue finds the .bin picked with it. Off the main
                // thread: a copy can be gigabytes.
                let copied = await Task.detached {
                    urls.compactMap { url -> URL? in
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        return try? ClipboardImporter.persist(.file(url), into: romDirectory)
                    }
                }.value
                var notes: [String] = []
                for dest in copied { if let note = await state.importChosen(dest) { notes.append(note) } }
                notice = (["Imported \(copied.count) file\(copied.count == 1 ? "" : "s")"] + notes).joined(separator: "\n")
            }
        }
    }
}

/// One row per archive unpacking: its name, how far it has got, and Cancel. Polled, as `Progress` is
/// written off the main thread.
struct ImportProgressRows: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if !state.importJobs.isEmpty {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.importJobs) { job in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unpacking \(job.name)").font(.footnote).lineLimit(1).truncationMode(.middle)
                                ProgressView(value: job.progress.fractionCompleted).tint(AppTheme.accent)
                            }
                            Button("Cancel") { state.cancelImport(job) }
                                .font(.footnote)
                                .frame(minHeight: 44)
                                .accessibilityLabel("Cancel unpacking \(job.name)")
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct MultiDiscSheet: View {
    @EnvironmentObject private var state: AppState
    @State private var groups: [MultiDiscHelper.Group] = []
    @State private var written: [String] = []
    @State private var discs: [URL] = []
    @State private var picked: [URL] = []
    @State private var manualTitle = ""
    @State private var manualPlatform = MultiDiscHelper.Platform.ps1

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
                manualPicker.padding(.top, 24)
            }
        }
        .onAppear {
            groups = MultiDiscHelper.scan(state.romDirectory)
            discs = MultiDiscHelper.discFiles(in: state.romDirectory)
        }
    }

    /// For discs whose names do not group: tap them in play order.
    private var manualPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick Discs Yourself").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text("Tap the discs in the order they play.").font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 4)
            Rule()
            if discs.isEmpty {
                Text("No disc files in the ROM folder.").font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
            }
            ForEach(discs, id: \.path) { disc in
                let order = picked.firstIndex(of: disc)
                Button {
                    if let order { picked.remove(at: order) } else { picked.append(disc) }
                } label: {
                    HStack {
                        Text(verbatim: disc.lastPathComponent).multilineTextAlignment(.leading)
                        Spacer(minLength: 12)
                        if let order { Text(verbatim: "\(order + 1)").font(.meta.bold()).foregroundStyle(AppTheme.accent) }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(order.map { "Disc \($0 + 1)" } ?? "Not picked")
                Rule()
            }
            TextField("Game title", text: $manualTitle).frame(minHeight: 44).accessibilityLabel("Game title")
            Rule()
            Picker("System", selection: $manualPlatform) {
                ForEach(MultiDiscHelper.Platform.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .frame(minHeight: 44)
            Rule()
            Button("Create Playlist") {
                let title = manualTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let group = MultiDiscHelper.Group(id: title, title: title, platform: manualPlatform, discs: picked)
                guard let playlist = try? MultiDiscHelper.writePlaylist(for: group, into: state.romDirectory) else { return }
                written = [playlist.lastPathComponent]
                _ = state.importROM(at: playlist, title: title, platformID: manualPlatform.platformID)
                picked = []
                manualTitle = ""
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(picked.count < 2 || manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.top, 16)
        }
    }
}

struct RomPatcherSheet: View {
    @EnvironmentObject private var state: AppState
    @State private var rom: URL?
    @State private var patch: URL?
    @State private var picking: Pick?
    @State private var result: String?
    @State private var creating = false
    @State private var working = false
    @State private var created: URL?
    enum Pick: Identifiable { case rom, patch; var id: Int { self == .rom ? 0 : 1 } }

    var body: some View {
        PaperSheet(title: "Patch a ROM") {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Task", selection: $creating) {
                    Text("Apply").tag(false)
                    Text("Create").tag(true)
                }
                .pickerStyle(.segmented).frame(minHeight: 44)
                picker(creating ? "Original ROM" : "ROM", url: rom) { picking = .rom }
                Rule()
                picker(creating ? "Changed ROM" : "Patch (IPS, UPS, BPS, PPF, APS, RUP)", url: patch) { picking = .patch }
                Rule()
                Button(creating ? "Create UPS Patch" : "Apply Patch") { creating ? create() : apply() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(rom == nil || patch == nil || working)
                    .padding(.top, 16)
                if working { ProgressView().padding(.top, 8) }
                if let result { Text(result).font(.meta).foregroundStyle(AppTheme.muted).padding(.top, 8) }
                if creating, let created {
                    ShareLink(item: created) { Text("Share or Save Patch") }.frame(minHeight: 44).padding(.top, 8)
                }
                Text(creating ? "Compares two versions of your own ROM and writes only the differences. Neither ROM is changed."
                              : "The original ROM is left untouched. The patched copy is saved next to it.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
            }
        }
        .onChange(of: creating) {
            rom = nil
            patch = nil
            result = nil
            created = nil
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

    private func create() {
        guard let rom, let changed = patch else { return }
        working = true
        result = nil
        created = nil
        Task {
            defer { working = false }
            do {
                let output = try await Task.detached { () throws -> URL in
                    let scopedOriginal = rom.startAccessingSecurityScopedResource()
                    let scopedChanged = changed.startAccessingSecurityScopedResource()
                    defer {
                        if scopedOriginal { rom.stopAccessingSecurityScopedResource() }
                        if scopedChanged { changed.stopAccessingSecurityScopedResource() }
                    }
                    let data = try RomPatcher.createUPS(from: Data(contentsOf: rom, options: .alwaysMapped),
                                                        to: Data(contentsOf: changed, options: .alwaysMapped))
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let file = folder.appendingPathComponent(changed.deletingPathExtension().lastPathComponent + ".ups")
                    try data.write(to: file, options: .atomic)
                    return file
                }.value
                created = output
                result = "Patch created."
            } catch {
                result = error.localizedDescription
            }
        }
    }

    private func apply() {
        guard let rom, let patch else { return }
        let scopedROM = rom.startAccessingSecurityScopedResource()
        let scopedPatch = patch.startAccessingSecurityScopedResource()
        defer {
            if scopedROM { rom.stopAccessingSecurityScopedResource() }
            if scopedPatch { patch.stopAccessingSecurityScopedResource() }
        }
        do {
            let part = try ClipboardImporter.partFile(in: state.romDirectory)
            defer { try? FileManager.default.removeItem(at: part) }
            let sums = try RomPatcher.apply(patch: patch, toSource: rom, writingTo: part)
            let dest = try ClipboardImporter.place(part, named: "patched-\(rom.lastPathComponent)", in: state.romDirectory)
            _ = state.importROM(at: dest, title: "\(rom.deletingPathExtension().lastPathComponent) (patched)")
            result = "Saved. CRC32 \(String(format: "%08X", sums.crc32)) · MD5 \(sums.md5)"
        } catch {
            result = error.localizedDescription
        }
    }
}
