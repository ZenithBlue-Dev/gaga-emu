import SwiftUI
import UniformTypeIdentifiers

/// Filter list left, live preview and its controls right. With a game it sets that game's filter,
/// otherwise the default for new games. Premium filters stay locked without Gaga Plus.
struct FilterPickerView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSize
    @Environment(\.horizontalSizeClass) private var horizontalSize
    var game: GameItem?
    @State private var showPlans = false
    @State private var showImporter = false
    @State private var importKind = ImportKind.metal
    @State private var importing = false
    @State private var importFailure: ImportFailure?
    @State private var imported: [ImportedFilterStore.Entry] = []
    @State private var presets: [SavedFilterPreset] = []
    @State private var query = ""
    @FocusState private var searching: Bool
    @State private var showNaming = false
    @State private var nameField = ""
    /// The preset being renamed, or nil while naming a new one.
    @State private var renaming: SavedFilterPreset?
    @State private var deleting: SavedFilterPreset?
    @StateObject private var shaderManager = ShaderManager.shared

    private struct ImportFailure: Identifiable {
        let id = UUID()
        var title = "Filter Not Imported"
        var subtitle: String? = "Original is selected"
        let message: String
    }

    private enum ImportKind { case metal, slang }

    private var selected: String {
        guard let game else { return state.shaderID }
        return state.games.first { $0.id == game.id }?.shaderID ?? game.shaderID
    }

    /// A layer-path core that cannot hand its frames to the filter chain, so no filter runs on this game.
    private var filtersSkipped: Bool {
        guard let game else { return false }
        return !CoreCatalog.filtersAvailable((state.games.first { $0.id == game.id } ?? game).resolvedCoreID(defaults: state.defaultCores))
    }

    private var selectedName: String { filterName(selected) }

    private func filterName(_ id: String) -> String {
        ShaderCatalog.all.first { $0.id == id }?.name ?? imported.first { $0.id == id }?.name ?? "Original"
    }

    private func startNaming(_ preset: SavedFilterPreset?) {
        renaming = preset
        nameField = preset?.name ?? selectedName
        showNaming = true
    }

    /// The filter list. Its own padding, so it can share a scroll with the controls upright.
    private var filterList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Filter").font(.screenTitle).accessibilityAddTraits(.isHeader)
            if let game { Text(game.title).font(.meta).foregroundStyle(AppTheme.muted) }
            if filtersSkipped {
                Text("Filters are not available for this system")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                    .padding(.top, 4)
                    .accessibilityIdentifier("filtersSkippedNote")
            }
            Rule().padding(.top, 8)
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                TextField("Search", text: $query)
                    .submitLabel(.search)
                    .focused($searching)
                    .accessibilityLabel("Search filters")
            }
            .frame(minHeight: 44)
            .disabled(filtersSkipped)
            Rule()
            Group {
                ForEach(ShaderCatalog.builtIn.filter { matches($0.name) }) { shader in
                    row(shader)
                    Rule()
                }
                if ShaderCatalog.community.contains(where: { matches($0.name) }) {
                    sectionHeader("Community")
                    Rule()
                    ForEach(ShaderCatalog.community.filter { matches($0.name) }) { shader in
                        row(shader)
                        Rule()
                    }
                }
                if query.isEmpty || presets.contains(where: { matches($0.name) }) { savedSection }
                if query.isEmpty || imported.contains(where: { matches($0.name) }) { importedSection }
                if noMatches {
                    Text("No filters match.").font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                }
            }
            .disabled(filtersSkipped)
        }
        .padding(16)
    }

    private func matches(_ name: String) -> Bool { query.isEmpty || name.localizedCaseInsensitiveContains(query) }

    private var noMatches: Bool {
        !ShaderCatalog.all.contains { matches($0.name) } && !presets.contains { matches($0.name) } && !imported.contains { matches($0.name) }
    }

    private var previewHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedName).font(.gameTitle)
            Spacer(minLength: 0)
            Button("Save Preset") { startNaming(nil) }
                .buttonStyle(QuietButtonStyle())
                .disabled(filtersSkipped)
            Button("Close") { dismiss() }.buttonStyle(QuietButtonStyle())
        }
    }

    private var preview: some View {
        MetalPreviewCanvas(shaderManager: shaderManager)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
            .accessibilityLabel("Filter preview, \(selectedName)")
    }

    var body: some View {
        Group {
            // Upright on a phone: preview on top, then the controls (they scroll themselves), then the list.
            if horizontalSize == .compact && verticalSize == .regular {
                VStack(alignment: .leading, spacing: 8) {
                    previewHeader.padding(.horizontal, 16).padding(.top, 8)
                    // While typing the keyboard would leave the results no room below these.
                    if !searching {
                        preview.frame(height: 190).padding(.horizontal, 16)
                        FilterControls(shaderID: selected, shaderManager: shaderManager)
                            .frame(height: 120).padding(.horizontal, 16)
                    }
                    Rule()
                    ScrollView { filterList }
                }
            } else {
                HStack(spacing: 0) {
                    ScrollView { filterList }
                        .frame(width: verticalSize == .compact ? 240 : 320)
                    Rule().ignoresSafeArea(edges: .vertical)
                    VStack(alignment: .leading, spacing: 8) {
                        previewHeader
                        HStack(alignment: .top, spacing: 12) {
                            preview
                            FilterControls(shaderID: selected, shaderManager: shaderManager)
                                .frame(width: verticalSize == .compact ? 190 : 240)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 8)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        #if !GAGA_SIDELOAD
        .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
        #endif
        // One importer for both kinds: two on one view do not both work on every iOS version.
        .fileImporter(isPresented: $showImporter, allowedContentTypes: importKind == .metal ? Self.importTypes : Self.slangTypes,
                      allowsMultipleSelection: importKind == .slang) { result in
            switch result {
            case .success(let urls) where importKind == .slang: importSlang(urls)
            case .success(let urls): if let url = urls.first { importFilter(url) }
            case .failure(let error): importFailure = ImportFailure(message: error.localizedDescription)
            }
        }
        .sheet(item: $importFailure) { failure in
            PaperSheet(title: failure.title, subtitle: failure.subtitle) {
                Text(failure.message)
                    .font(.meta)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("filterImportError")
            }
        }
        .alert(renaming == nil ? "Save Preset" : "Rename Preset", isPresented: $showNaming) {
            TextField("Name", text: $nameField)
            Button("Save", action: commitName)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(renaming == nil ? "Saves \(selectedName) with its sliders and upscaler." : "A new name for this preset.")
        }
        .confirmationDialog(deleting.map { "Delete \($0.name)?" } ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { preset in
            Button("Delete", role: .destructive) { deletePreset(preset) }
        } message: { _ in
            Text("The filter it uses stays.")
        }
        .onAppear {
            imported = state.filters.entries
            presets = state.presets.presets
            preview(selected)
        }
        .onChange(of: selected) { _, newID in preview(newID) }
    }

    /// `.metal` has no system type on every OS version, so plain text and source code stay pickable too.
    private static let importTypes: [UTType] = [UTType(filenameExtension: "metal"), .sourceCode, .plainText].compactMap { $0 }
    /// The preset and, when the system will not open its folder, its .slang and include files with it.
    private static let slangTypes: [UTType] = [UTType(filenameExtension: "slangp"), UTType(filenameExtension: "slang"),
                                               UTType(filenameExtension: "inc"), .sourceCode, .plainText, .data].compactMap { $0 }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 16).padding(.bottom, 4)
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Saved")
            Rule()
            if presets.isEmpty {
                Text("Set a filter's sliders, then Save Preset to keep them under a name.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                    .padding(.vertical, 8)
            }
            ForEach(presets.filter { matches($0.name) }) { preset in
                let base = ShaderCatalog.all.first { $0.id == preset.shaderID }
                let locked = base.map { $0.premium && !store.canUseShader($0.id) } ?? false
                let isOn = selected == preset.shaderID && (state.shaderParameters[preset.shaderID] ?? ShaderParameterValues()) == preset.values
                HStack(spacing: 0) {
                    Button { if locked { showPlans = true } else { apply(preset) } } label: {
                        rowLabel(preset.name, credit: filterName(preset.shaderID), selected: isOn, locked: locked, premium: base?.premium ?? false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(locked ? "\(preset.name), needs Gaga Plus" : "\(preset.name), \(filterName(preset.shaderID))")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    iconButton("pencil", label: "Rename \(preset.name)") { startNaming(preset) }
                    iconButton("trash", label: "Delete \(preset.name)") { deleting = preset }
                }
                Rule()
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).foregroundStyle(AppTheme.muted).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// A preset of an imported filter whose file was deleted falls back like any missing filter: to Original.
    private func apply(_ preset: SavedFilterPreset) {
        state.shaderParameters[preset.shaderID] = preset.values
        select(preset.shaderID)
    }

    private func commitName() {
        do {
            if let preset = renaming {
                try state.presets.rename(preset.id, to: nameField)
            } else {
                try state.presets.save(name: nameField, shaderID: selected,
                                       values: state.shaderParameters[selected] ?? ShaderParameterValues())
            }
            presets = state.presets.presets
        } catch {
            importFailure = ImportFailure(title: "Preset Not Saved", subtitle: nil, message: error.localizedDescription)
        }
    }

    private func deletePreset(_ preset: SavedFilterPreset) {
        do {
            try state.presets.delete(preset.id)
        } catch {
            importFailure = ImportFailure(title: "Preset Not Deleted", subtitle: nil, message: error.localizedDescription)
        }
        presets = state.presets.presets
    }

    private var importedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Imported")
            Rule()
            ForEach(imported.filter { matches($0.name) }) { entry in
                HStack(spacing: 8) {
                    Button { select(entry.id) } label: { rowLabel(entry.name, credit: nil, selected: selected == entry.id, locked: false, premium: false) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(entry.name)
                        .accessibilityAddTraits(selected == entry.id ? .isSelected : [])
                    Button { delete(entry) } label: {
                        Image(systemName: "trash").foregroundStyle(AppTheme.muted).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(entry.name)")
                }
                Rule()
            }
            Button(importing ? "Checking" : "Import .metal File") {
                importKind = .metal
                showImporter = true
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(importing)
            Text("Runs your own Metal shader. It needs a fragment function named \(ImportedFilter.entryPoint).")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            Button(importing ? "Translating" : "Import .slangp Preset") {
                importKind = .slang
                showImporter = true
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(importing)
            Text("Translates a RetroArch slang preset to Metal once, now. Choose the .slangp with its .slang files. Lookup textures, history and feedback passes are not supported yet.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
        }
    }

    private func rowLabel(_ name: String, credit: String?, selected isSelected: Bool, locked: Bool, premium: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").opacity(isSelected ? 1 : 0).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).fontWeight(isSelected ? .bold : .regular)
                if let credit { Text(credit).font(.caption2).foregroundStyle(AppTheme.muted) }
            }
            Spacer(minLength: 0)
            if premium && PaywallGate.isOpen {
                Label("Plus", systemImage: locked ? "lock" : "checkmark.seal")
                    .font(.meta).foregroundStyle(AppTheme.muted)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func row(_ shader: ShaderCatalog.Shader) -> some View {
        let locked = shader.premium && !store.canUseShader(shader.id)
        let isSelected = selected == shader.id
        return Button {
            if locked { showPlans = true } else { select(shader.id) }
        } label: {
            rowLabel(shader.name, credit: shader.credit, selected: isSelected, locked: locked, premium: shader.premium)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(shader.name), needs Gaga Plus" : shader.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ id: String) {
        if let game {
            state.update(game.id) { $0.shaderID = id }
        } else {
            state.shaderID = id
        }
    }

    private func preview(_ id: String) {
        guard ImportedFilter.isImported(id) || ImportedFilter.isSlang(id) else {
            shaderManager.select(shaderID: id)
            return
        }
        Task {
            do {
                if ImportedFilter.isSlang(id) {
                    shaderManager.selectSlang(try await state.filters.slangChain(for: id, device: shaderManager.device))
                } else {
                    shaderManager.selectImported(try await state.filters.pipeline(for: id, device: shaderManager.device))
                }
            } catch {
                importFailure = ImportFailure(message: error.localizedDescription)
                select("original")
            }
        }
    }

    private func importFilter(_ url: URL) {
        importing = true
        Task {
            defer { importing = false }
            do {
                let entry = try await state.filters.add(file: url, device: shaderManager.device)
                imported = state.filters.entries
                select(entry.id)
                preview(entry.id)
            } catch {
                importFailure = ImportFailure(message: error.localizedDescription)
                select("original")
            }
        }
    }

    private func importSlang(_ urls: [URL]) {
        importing = true
        Task {
            defer { importing = false }
            do {
                let entry = try await state.filters.addSlang(files: urls, device: shaderManager.device)
                imported = state.filters.entries
                select(entry.id)
                preview(entry.id)
            } catch {
                importFailure = ImportFailure(title: "Preset Not Imported", message: error.localizedDescription)
                select("original")
            }
        }
    }

    /// Games and the default that used this filter go back to Original.
    private func delete(_ entry: ImportedFilterStore.Entry) {
        state.filters.delete(entry)
        imported = state.filters.entries
        state.shaderParameters[entry.id] = nil
        for item in state.games where item.shaderID == entry.id {
            state.update(item.id) { $0.shaderID = "original" }
        }
        if state.shaderID == entry.id { state.shaderID = "original" }
    }
}

/// Upscaler and sliders for one filter, saved per filter. The preview follows every change; the
/// file is written when a drag ends, not on each step of it.
private struct FilterControls: View {
    @EnvironmentObject private var state: AppState
    let shaderID: String
    @ObservedObject var shaderManager: ShaderManager
    @State private var values = ShaderParameterValues()
    /// The selected `.slangp`'s own parameters. Empty for every other filter.
    @State private var slangParameters: [SlangFilter.Parameter] = []

    private var isImported: Bool { ImportedFilter.isImported(shaderID) }
    private var isSlang: Bool { ImportedFilter.isSlang(shaderID) }
    private var preset: ShaderPreset { ShaderPreset.from(id: shaderID) }
    private var kinds: [ShaderParameterKind] { isSlang ? [] : isImported ? ShaderParameterKind.allCases : preset.parameters }
    private var usesUpscaler: Bool { !isSlang && (isImported || preset.usesUpscaler) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if usesUpscaler { upscalerRow }
                ForEach(kinds) { kind in slider(kind) }
                ForEach(slangParameters) { parameter in slangSlider(parameter) }
                Button("Reset") {
                    values = ShaderParameterValues()
                    commit()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .onAppear(perform: load)
        .onChange(of: shaderID) { load() }
        // Applying a saved preset can change the values of the filter already selected.
        .onChange(of: state.shaderParameters[shaderID]) { load() }
    }

    private func load() {
        values = state.shaderParameters[shaderID] ?? ShaderParameterValues()
        slangParameters = isSlang ? state.filters.slangFilter(for: shaderID)?.parameters ?? [] : []
        shaderManager.apply(values)
    }

    /// A slang parameter on its own range and step. Unset means the preset's value.
    private func slangSlider(_ parameter: SlangFilter.Parameter) -> some View {
        let binding = Binding<Double>(get: { Double(values.slang?[parameter.name] ?? parameter.initial) }, set: {
            values.slang = (values.slang ?? [:]).merging([parameter.name: Float($0)]) { $1 }
            shaderManager.apply(values)
        })
        let text = binding.wrappedValue.formatted(.number.precision(.fractionLength(0...3)))
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(parameter.title).font(.footnote).lineLimit(2)
                Spacer(minLength: 4)
                Text(text).font(.meta).foregroundStyle(AppTheme.muted)
            }
            Group {
                if parameter.step > 0, parameter.maximum > parameter.minimum {
                    Slider(value: binding, in: Double(parameter.minimum)...Double(parameter.maximum), step: Double(parameter.step)) {
                        Text(parameter.title)
                    } onEditingChanged: { if !$0 { commit() } }
                } else {
                    Slider(value: binding, in: Double(parameter.minimum)...Double(max(parameter.maximum, parameter.minimum + 0.001))) {
                        Text(parameter.title)
                    } onEditingChanged: { if !$0 { commit() } }
                }
            }
            .tint(AppTheme.accentFill)
            .frame(minHeight: 44)
            .accessibilityValue(text)
        }
    }

    private func commit() {
        shaderManager.apply(values)
        state.shaderParameters[shaderID] = values
    }

    private var upscalerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Upscale").font(.footnote.weight(.semibold)).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(Upscaler.allCases) { option in
                    let isOn = values.resolvedUpscaler == option
                    Button {
                        values.upscaler = option.rawValue
                        commit()
                    } label: {
                        Text(option.displayName)
                            .font(.footnote.weight(isOn ? .bold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(isOn ? AppTheme.onAccent : AppTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isOn ? AppTheme.accentFill : Color.clear, in: RoundedRectangle(cornerRadius: AppTheme.corner))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(isOn ? Color.clear : AppTheme.rule, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Upscale \(option.displayName)")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    private func slider(_ kind: ShaderParameterKind) -> some View {
        let binding = Binding<Double>(get: { Double(values[keyPath: kind.keyPath]) }, set: {
            values[keyPath: kind.keyPath] = Float($0)
            shaderManager.apply(values)
        })
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(kind.title).font(.footnote)
                Spacer(minLength: 4)
                Text("\(Int((binding.wrappedValue * 100).rounded()))").font(.meta).foregroundStyle(AppTheme.muted)
            }
            Slider(value: binding, in: 0...1) { Text(kind.title) } onEditingChanged: { editing in
                if !editing { commit() }
            }
            .tint(AppTheme.accentFill)
            .frame(minHeight: 44)
            .accessibilityValue("\(Int((binding.wrappedValue * 100).rounded())) percent")
        }
    }
}
