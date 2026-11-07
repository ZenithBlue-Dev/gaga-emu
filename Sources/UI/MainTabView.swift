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
        .overlay {
            SidePanel(edge: .leading, isPresented: $showControllers) {
                ControllersModalView { showControllers = false }
            }
        }
        .overlay {
            SidePanel(edge: .trailing, isPresented: $showHistory) {
                PlayHistoryView(onClose: { showHistory = false },
                                onImport: { showHistory = false; tab = .importHub })
            }
        }
    }
}

/// Slides in from one edge. The main view stays visible, dimmed, at the other edge; tapping it closes the panel.
struct SidePanel<Content: View>: View {
    let edge: HorizontalEdge
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: edge == .leading ? .leading : .trailing) {
                if isPresented {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .accessibilityLabel("Close panel")
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)
                    content()
                        .frame(width: min(proxy.size.width * 0.86, 420))
                        .background(AppTheme.background.ignoresSafeArea())
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) { isPresented = false }
                        .transition(.move(edge: edge == .leading ? .leading : .trailing))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(isPresented)
        .animation(.easeOut(duration: 0.25), value: isPresented)
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
