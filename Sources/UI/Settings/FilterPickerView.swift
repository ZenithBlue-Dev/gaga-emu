import SwiftUI
import UniformTypeIdentifiers

/// Filter list left, live preview and its controls right. With a game it sets that game's filter,
/// otherwise the default for new games. Premium filters stay locked without Gaga Plus.
struct FilterPickerView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSize
    var game: GameItem?
    @State private var showPlans = false
    @State private var showImporter = false
    @State private var importing = false
    @State private var importFailure: ImportFailure?
    @State private var imported: [ImportedFilterStore.Entry] = []
    @StateObject private var shaderManager = ShaderManager.shared

    private struct ImportFailure: Identifiable {
        let id = UUID()
        let message: String
    }

    private var selected: String {
        guard let game else { return state.shaderID }
        return state.games.first { $0.id == game.id }?.shaderID ?? game.shaderID
    }

    private var selectedName: String {
        ShaderCatalog.all.first { $0.id == selected }?.name ?? imported.first { $0.id == selected }?.name ?? "Original"
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Filter").font(.screenTitle).accessibilityAddTraits(.isHeader)
                    if let game { Text(game.title).font(.meta).foregroundStyle(AppTheme.muted) }
                    Rule().padding(.top, 8)
                    ForEach(ShaderCatalog.builtIn) { shader in
                        row(shader)
                        Rule()
                    }
                    sectionHeader("Community")
                    Rule()
                    ForEach(ShaderCatalog.community) { shader in
                        row(shader)
                        Rule()
                    }
                    importedSection
                }
                .padding(16)
            }
            .frame(width: verticalSize == .compact ? 240 : 320)
            Rule().ignoresSafeArea(edges: .vertical)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedName).font(.gameTitle)
                    Spacer(minLength: 0)
                    Button("Close") { dismiss() }.buttonStyle(QuietButtonStyle())
                }
                HStack(alignment: .top, spacing: 12) {
                    MetalPreviewCanvas(shaderManager: shaderManager)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
                        .accessibilityLabel("Filter preview, \(selectedName)")
                    FilterControls(shaderID: selected, shaderManager: shaderManager)
                        .frame(width: verticalSize == .compact ? 190 : 240)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.importTypes) { result in
            switch result {
            case .success(let url): importFilter(url)
            case .failure(let error): importFailure = ImportFailure(message: error.localizedDescription)
            }
        }
        .sheet(item: $importFailure) { failure in
            PaperSheet(title: "Filter Not Imported", subtitle: "Original is selected") {
                Text(failure.message)
                    .font(.meta)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("filterImportError")
            }
        }
        .onAppear {
            imported = state.filters.entries
            preview(selected)
        }
        .onChange(of: selected) { _, newID in preview(newID) }
    }

    /// `.metal` has no system type on every OS version, so plain text and source code stay pickable too.
    private static let importTypes: [UTType] = [UTType(filenameExtension: "metal"), .sourceCode, .plainText].compactMap { $0 }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 16).padding(.bottom, 4)
    }

    private var importedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Imported")
            Rule()
            ForEach(imported) { entry in
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
            Button(importing ? "Checking" : "Import .metal File") { showImporter = true }
                .buttonStyle(QuietButtonStyle())
                .disabled(importing)
            Text("Runs your own Metal shader. It needs a fragment function named \(ImportedFilter.entryPoint).")
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
        guard ImportedFilter.isImported(id) else {
            shaderManager.select(shaderID: id)
            return
        }
        Task {
            do {
                shaderManager.selectImported(try await state.filters.pipeline(for: id, device: shaderManager.device))
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

    private var isImported: Bool { ImportedFilter.isImported(shaderID) }
    private var preset: ShaderPreset { ShaderPreset.from(id: shaderID) }
    private var kinds: [ShaderParameterKind] { isImported ? ShaderParameterKind.allCases : preset.parameters }
    private var usesUpscaler: Bool { isImported || preset.usesUpscaler }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if usesUpscaler { upscalerRow }
                ForEach(kinds) { kind in slider(kind) }
                Button("Reset") {
                    values = ShaderParameterValues()
                    commit()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .onAppear(perform: load)
        .onChange(of: shaderID) { load() }
    }

    private func load() {
        values = state.shaderParameters[shaderID] ?? ShaderParameterValues()
        shaderManager.apply(values)
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
