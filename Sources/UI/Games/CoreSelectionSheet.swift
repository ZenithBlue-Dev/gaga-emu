import SwiftUI

/// Per-game core picker. "Set as Global Default" writes the platform default.
struct CoreSelectionSheet: View {
    @EnvironmentObject private var state: AppState
    let game: GameItem
    @Environment(\.dismiss) private var dismiss

    private var platform: PlatformInfo? { CoreCatalog.platform(game.platformID) }
    private var selected: String {
        game.coreOverride ?? state.defaultCores[game.platformID] ?? CoreCatalog.defaultCore(for: game.platformID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Switch Core").font(.system(size: 20, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32).background(AppTheme.cardRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .foregroundStyle(.white)
            Text(platform?.name ?? game.platformID)
                .font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
            ForEach(platform?.cores ?? []) { core in
                Button { state.setCore(core.id, for: game.id, global: false) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected == core.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected == core.id ? AppTheme.accent : AppTheme.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(core.name).foregroundStyle(.white).font(.system(size: 16, weight: .semibold))
                            Text(core.recommended ? "\(core.note) · Recommended" : core.note)
                                .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .glassCard(radius: 16)
                }
                .buttonStyle(.plain)
            }
            Button {
                state.setCore(selected, for: game.id, global: true)
                dismiss()
            } label: {
                Text("Set as Global Default for \(platform?.name ?? "System")")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppTheme.brandGradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(20)
        .background(AppTheme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

/// Global platform-to-core list from Settings.
struct EmulatorCoreListView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PlatformInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Switch cores by long-pressing a game in the library.")
                        .font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(CoreCatalog.platforms) { platform in
                        Button { editing = platform } label: {
                            HStack {
                                Text(platform.name).foregroundStyle(.white)
                                Spacer()
                                Text(currentName(platform)).foregroundStyle(AppTheme.textSecondary)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 18)
                            .glassCard(radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Emulator Core")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .sheet(item: $editing) { platform in
                PlatformCorePicker(platform: platform)
            }
        }
    }

    private func currentName(_ platform: PlatformInfo) -> String {
        let id = state.defaultCores[platform.id] ?? CoreCatalog.defaultCore(for: platform.id)
        return CoreCatalog.coreName(id)
    }
}

private struct PlatformCorePicker: View {
    @EnvironmentObject private var state: AppState
    let platform: PlatformInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(platform.name).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            ForEach(platform.cores) { core in
                Button {
                    state.defaultCores[platform.id] = core.id
                    dismiss()
                } label: {
                    HStack {
                        Text(core.name).foregroundStyle(.white)
                        Spacer()
                        if (state.defaultCores[platform.id] ?? CoreCatalog.defaultCore(for: platform.id)) == core.id {
                            Image(systemName: "checkmark").foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(16).glassCard(radius: 16)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(20)
        .background(AppTheme.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
