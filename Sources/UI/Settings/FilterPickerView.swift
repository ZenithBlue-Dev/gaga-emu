import SwiftUI

/// Filter list left, large live preview right. With a game it sets that game's filter,
/// otherwise the default for new games. Premium filters stay locked without Gaga Plus.
struct FilterPickerView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSize
    var game: GameItem?
    @State private var showPlans = false

    private var selected: String {
        guard let game else { return state.shaderID }
        return state.games.first { $0.id == game.id }?.shaderID ?? game.shaderID
    }

    private var selectedName: String { ShaderCatalog.builtIn.first { $0.id == selected }?.name ?? selected }

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
                ShaderPreviewCanvas(shaderID: selected)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
    }

    private func row(_ shader: ShaderCatalog.Shader) -> some View {
        let locked = shader.premium && !store.canUseShader(shader.id)
        let isSelected = selected == shader.id
        return Button {
            if locked {
                showPlans = true
            } else if let game {
                state.update(game.id) { $0.shaderID = shader.id }
            } else {
                state.shaderID = shader.id
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").opacity(isSelected ? 1 : 0).accessibilityHidden(true)
                Text(shader.name).fontWeight(isSelected ? .bold : .regular)
                Spacer(minLength: 0)
                if shader.premium && PaywallGate.isOpen {
                    Label("Plus", systemImage: locked ? "lock" : "checkmark.seal")
                        .font(.meta).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(shader.name), needs Gaga Plus" : shader.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Live preview: the selected MSL preset runs on a procedural texture through `MetalRenderer`.
struct ShaderPreviewCanvas: View {
    let shaderID: String
    @StateObject private var shaderManager = ShaderManager.shared

    var body: some View {
        MetalPreviewCanvas(shaderManager: shaderManager)
            .onAppear { shaderManager.select(shaderID: shaderID) }
            .onChange(of: shaderID) { _, newID in shaderManager.select(shaderID: newID) }
            .accessibilityLabel("Filter preview, \(shaderID)")
    }
}
