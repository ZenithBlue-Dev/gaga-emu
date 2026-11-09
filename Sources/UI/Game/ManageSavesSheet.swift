import SwiftUI

/// One game's state slots and battery save. `load` throws to keep the sheet open and show why.
struct ManageSavesSheet: View {
    let title: String
    let store: SaveStore
    let load: (SaveSlot) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var slots: [SaveSlot] = []
    @State private var pendingDelete: SaveSlot?
    @State private var failure: String?

    var body: some View {
        PaperSheet(title: "Manage Saves", subtitle: title) {
            VStack(alignment: .leading, spacing: 0) {
                battery
                Rule()
                if slots.isEmpty {
                    Text("No save states yet. Use Save State in the pause menu while you play.")
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 12)
                }
                ForEach(slots) { row($0) }
            }
        }
        .onAppear(perform: reload)
        .confirmationDialog("Delete this save state?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { slot in
            Button("Delete", role: .destructive) { delete(slot) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This cannot be undone. Your game's own save is not affected.")
        }
        .alert(failure ?? "", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func reload() { slots = store.slots() }

    @ViewBuilder private var battery: some View {
        let files = store.batterySaves()
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Game save")
                Text(files.isEmpty ? "Nothing saved by the game yet" : "Written by the game itself")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 12)
            if !files.isEmpty {
                ShareLink(items: files) { Text("Export Save") }
                    .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }

    private func name(_ slot: SaveSlot) -> String {
        "\(slot.isAuto ? "Auto save" : "Save state"), \(slot.date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func row(_ slot: SaveSlot) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                thumbnail(slot)
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.isAuto ? "Auto save" : "Save state")
                    Text(slot.date.formatted(date: .abbreviated, time: .shortened)).font(.meta).foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 12)
                Button("Load") {
                    do {
                        try load(slot)
                        dismiss()
                    } catch {
                        failure = error.localizedDescription
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("Load \(name(slot))")
                Button { pendingDelete = slot } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .foregroundStyle(AppTheme.muted)
                .accessibilityLabel("Delete \(name(slot))")
            }
            .padding(.vertical, 6)
            Rule()
        }
    }

    @ViewBuilder private func thumbnail(_ slot: SaveSlot) -> some View {
        Group {
            if let image = UIImage(contentsOfFile: slot.thumbnailURL.path) {
                Image(uiImage: image).interpolation(.none).resizable().aspectRatio(contentMode: .fit)
            } else {
                AppTheme.surface
            }
        }
        .frame(width: 96, height: 64)
        .background(AppTheme.letterbox)
        .accessibilityHidden(true)
    }

    private func delete(_ slot: SaveSlot) {
        do {
            try store.delete(slot)
        } catch {
            failure = error.localizedDescription
        }
        reload()
    }
}

/// Add, enable and remove one game's cheats. The core decides whether a code is valid.
struct CheatsSheet: View {
    @ObservedObject var session: GameSession
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.verticalSizeClass) private var verticalSize
    @State private var name = ""
    @State private var code = ""
    @State private var failure: String?
    @State private var importing = false
    @State private var imported: [CheatFormat.Block]?
    @State private var bundled: [CheatFormat.Block] = []
    @FocusState private var editing: Bool

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// A bundled cheat the player switched on moves to the list above, so it is not offered twice.
    private var available: [CheatFormat.Block] { bundled.filter { block in !session.cheats.contains { $0.code == block.code } } }

    var body: some View {
        // Upright on a phone the two columns stack.
        let upright = horizontalSize == .compact && verticalSize == .regular
        PaperSheet(title: "Cheats", subtitle: session.game.title) {
            AnyLayout(upright ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))) {
                VStack(alignment: .leading, spacing: 8) {
                    // The button and any error sit above the fields: the landscape keyboard covers everything
                    // below them, and an error in its own row would push the field being edited under it.
                    HStack {
                        Text(failure ?? "Add a code")
                            .font(failure == nil ? .subheadline.weight(.semibold) : .footnote)
                            .foregroundStyle(failure == nil ? AppTheme.ink : AppTheme.accent)
                            .fixedSize(horizontal: false, vertical: true) // A core's reason wraps; it is never cut off.
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        Button("Add Cheat", action: add)
                            .buttonStyle(QuietButtonStyle())
                            .disabled(trimmedCode.isEmpty)
                    }
                    TextField("Name", text: $name)
                        .frame(minHeight: 44)
                        .focused($editing)
                    Rule()
                    TextField("Code, one per line", text: $code, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(minHeight: 44)
                        .focused($editing)
                        .accessibilityLabel("Cheat code")
                        .onChange(of: code) { failure = nil }
                    Rule()
                    Text(session.cheatHint)
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cheatHint")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("This game").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        Button("Import .cht File") { importing = true }
                            .buttonStyle(QuietButtonStyle())
                    }
                    .frame(minHeight: 44) // Level with the other heading, which shares a row with its button.
                    if session.cheats.isEmpty {
                        Text("No cheats yet.").foregroundStyle(AppTheme.muted).padding(.vertical, 12)
                    }
                    ForEach(session.cheats) { row($0) }
                    if !available.isEmpty {
                        Text("Available cheats").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                            .padding(.top, 16)
                            .frame(minHeight: 44)
                        LazyVStack(spacing: 0) { // A game can have thousands.
                            ForEach(Array(available.enumerated()), id: \.offset) { bundledRow($0.element) }
                        }
                    }
                    if let imported {
                        Text("In this file").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                            .padding(.top, 16)
                            .frame(minHeight: 44)
                        if imported.isEmpty {
                            Text("This file has no cheats that can be used here.")
                                .foregroundStyle(AppTheme.muted).padding(.vertical, 12)
                                .accessibilityIdentifier("chtEmpty")
                        }
                        LazyVStack(spacing: 0) { // A file can hold thousands.
                            ForEach(Array(imported.enumerated()), id: \.offset) { importedRow($0.element) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .item]) { outcome in
            if case .success(let url) = outcome { load(url) }
        }
        .task {
            let (title, platformID, coreID) = (session.game.title, session.game.platformID, session.coreID)
            bundled = await Task.detached(priority: .userInitiated) {
                CheatDatabase.blocks(title: title, platformID: platformID, coreID: coreID)
            }.value
        }
        #if DEBUG
        .onAppear { // Device walks: Files cannot be driven, so a file put in Documents stands in for the pick.
            guard imported == nil, let path = UserDefaults.standard.string(forKey: "GagaCheatFile"),
                  let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            load(documents.appendingPathComponent(path))
        }
        #endif
    }

    /// The file's cheats are listed, not added: the player picks them, and each goes in off.
    private func load(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            imported = try CheatFormat.readCht(url, coreID: session.coreID)
            failure = nil
        } catch {
            imported = nil
            failure = error.localizedDescription
            UIAccessibility.post(notification: .announcement, argument: error.localizedDescription)
        }
    }

    private func importedRow(_ block: CheatFormat.Block) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(block.name).frame(maxWidth: .infinity, alignment: .leading)
                Button("Add") {
                    attempt { try session.addCheat(name: block.name, code: block.code, enabled: false) }
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("Add \(block.name)")
            }
            .frame(minHeight: 44)
            Rule()
        }
    }

    /// Off until the player switches it on, which adds it like any other cheat: the core and the cheat limit still judge it.
    private func bundledRow(_ block: CheatFormat.Block) -> some View {
        VStack(spacing: 0) {
            Toggle(block.name, isOn: Binding(get: { false }, set: { value in
                if value { attempt { try session.addCheat(name: block.name, code: block.code, enabled: true) } }
            }))
            .tint(AppTheme.accentFill)
            .frame(minHeight: 44)
            Rule()
        }
    }

    private func row(_ cheat: CheatEntry) -> some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(cheat.name, isOn: Binding(get: { cheat.enabled }, set: { value in
                    attempt { try session.setCheat(cheat, enabled: value) }
                }))
                .tint(AppTheme.accentFill)
                Button { attempt { try session.removeCheat(cheat) } } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .foregroundStyle(AppTheme.muted)
                .accessibilityLabel("Remove \(cheat.name)")
            }
            .frame(minHeight: 44)
            Rule()
        }
    }

    private func add() {
        let title = name.trimmingCharacters(in: .whitespaces)
        do {
            // A pasted CWCheat block holds several named cheats; each is added on its own, in order.
            let blocks = CheatFormat.cwCheatBlocks(trimmedCode)
            if blocks.isEmpty {
                try session.addCheat(name: title.isEmpty ? "Cheat \(session.cheats.count + 1)" : title, code: trimmedCode)
            } else {
                for block in blocks { try session.addCheat(name: block.name, code: block.code, enabled: block.enabled) }
            }
            name = ""
            code = ""
            failure = nil
            editing = false
        } catch {
            failure = error.localizedDescription
            UIAccessibility.post(notification: .announcement, argument: error.localizedDescription)
        }
    }

    private func attempt(_ work: () throws -> Void) {
        do {
            try work()
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}
