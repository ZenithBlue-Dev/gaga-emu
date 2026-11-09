import SwiftUI

/// Per-game core list. The bottom action writes the platform default too.
struct CorePickerSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let game: GameItem

    private var platform: PlatformInfo? { CoreCatalog.platform(game.platformID) }
    private var selected: String {
        // `game` is a copy taken when the sheet opened; read the live override.
        (state.games.first { $0.id == game.id } ?? game).resolvedCoreID(defaults: state.defaultCores)
    }

    var body: some View {
        PaperSheet(title: "Change Core", subtitle: CoreCatalog.platformName(game.platformID)) {
            VStack(alignment: .leading, spacing: 0) {
                if platform == nil {
                    Text("No cores are available for this file type yet.").foregroundStyle(AppTheme.muted)
                }
                ForEach(platform?.cores ?? []) { core in
                    let isSelected = selected == core.id
                    Button { state.setCore(core.id, for: game.id, global: false) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark").opacity(isSelected ? 1 : 0).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(core.name).fontWeight(isSelected ? .bold : .regular)
                                Text(core.recommended ? "\(core.note) · Recommended" : core.note)
                                    .font(.meta).foregroundStyle(AppTheme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    Rule()
                }
                #if GAGA_DEV_JIT
                if DevJITOption.cores.contains(selected) {
                    DevJITToggle(gameID: game.id)
                    Rule()
                }
                #endif
                if let platform {
                    Button("Use for All \(platform.name) Games") {
                        state.setCore(selected, for: game.id, global: true)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 16)
                }
            }
        }
    }
}
