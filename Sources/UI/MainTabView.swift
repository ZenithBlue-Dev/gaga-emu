import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var state: AppState
    @State private var tab: AppTab = .games
    @State private var showControllers = false
    @State private var showHistory = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            Group {
                switch tab {
                case .games: GamesLibraryView(showControllers: $showControllers, showHistory: $showHistory)
                case .importHub: ImportHubView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            GlassTabBar(selection: $tab)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showControllers) { ControllersModalView() }
        .sheet(isPresented: $showHistory) { PlayHistoryView() }
    }
}

/// Shared top bar: controller button, wordmark, history button.
struct LibraryHeader: View {
    @Binding var showControllers: Bool
    @Binding var showHistory: Bool

    var body: some View {
        HStack {
            RoundIconButton(systemName: "gamecontroller.fill") { showControllers = true }
            Spacer()
            HStack(spacing: 6) {
                Text("GAGA")
                    .font(.system(size: 22, weight: .heavy))
                    .italic()
                Text("EMU")
                    .font(.system(size: 22, weight: .heavy))
            }
            .foregroundStyle(.white)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            RoundIconButton(systemName: "clock.arrow.circlepath") { showHistory = true }
        }
        .padding(.horizontal, 16)
    }
}
