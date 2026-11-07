import SwiftUI

/// Shader picker with a live preview canvas. Premium shaders stay locked without membership.
struct ShadersSettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var tier = 0
    @State private var showPaywall = false

    private let tiers = ["Default", "RetroArch", "Import", "Custom"]

    private var shaders: [ShaderCatalog.Shader] {
        let base = tier == 0 ? ShaderCatalog.builtIn : []
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "circle.grid.3x3.fill").foregroundStyle(AppTheme.accent)
                Text("Shaders").font(.system(size: 22, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34).background(AppTheme.cardRaised, in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Close")
            }
            .foregroundStyle(.white)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textSecondary)
                TextField("Search Shaders", text: $query).foregroundStyle(.white)
            }
            .padding(10)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Search shaders")
            Picker("Source", selection: $tier) {
                ForEach(tiers.indices, id: \.self) { Text(tiers[$0]).tag($0) }
            }
            .pickerStyle(.segmented)
            ShaderPreviewCanvas(shaderID: state.shaderID)
                .frame(height: 200)
                .glassCard(radius: 18)
            ScrollView {
                VStack(spacing: 0) {
                    if shaders.isEmpty {
                        Text(tier == 0 ? "No matches." : "\(tiers[tier]) shaders are added from files.")
                            .font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    }
                    ForEach(shaders) { shader in row(shader) }
                }
                .glassCard(radius: 18)
            }
        }
        .padding(16)
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) { MembershipPaywallView() }
    }

    private func row(_ shader: ShaderCatalog.Shader) -> some View {
        let locked = shader.premium && !store.canUseShader(shader.id)
        return Button {
            if locked { showPaywall = true } else { state.shaderID = shader.id }
        } label: {
            HStack {
                Text(shader.name).foregroundStyle(.white).font(.system(size: 16))
                if shader.premium && PaywallGate.isOpen {
                    Text("PREMIUM").font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.warning)
                }
                Spacer()
                Image(systemName: state.shaderID == shader.id ? "eye.fill" : "eye")
                    .foregroundStyle(state.shaderID == shader.id ? AppTheme.accent : AppTheme.textTertiary)
                Image(systemName: state.shaderID == shader.id ? "circle.inset.filled" : "circle")
                    .foregroundStyle(state.shaderID == shader.id ? AppTheme.accent : AppTheme.textTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(shader.name), premium" : shader.name)
    }
}

/// Stand-in 16-bit scene. The filter is a SwiftUI approximation of the named shader
/// so the picker previews without a Metal pipeline. The real MSL pass replaces it.
struct ShaderPreviewCanvas: View {
    let shaderID: String
    @StateObject private var shaderManager = ShaderManager.shared

    var body: some View {
        MetalPreviewCanvas(shaderManager: shaderManager)
            .onAppear {
                shaderManager.select(shaderID: shaderID)
            }
            .onChange(of: shaderID) { newID in
                shaderManager.select(shaderID: newID)
            }
            .accessibilityLabel("Shader preview, \(shaderID)")
    }
}
