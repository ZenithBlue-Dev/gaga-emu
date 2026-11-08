import SwiftUI

enum AppScreen: String, CaseIterable, Identifiable {
    case library, add, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .library: return "Library"
        case .add: return "Add"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .library: return "books.vertical"
        case .add: return "plus"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var screen: AppScreen = .library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.verticalSizeClass) private var verticalSize

    var body: some View {
        // Upright on a phone the rail becomes a bar along the bottom, where the width is short and the height long.
        let upright = horizontalSize == .compact && verticalSize == .regular
        AnyLayout(upright ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))) {
            if !upright {
                LeftRail(selection: $screen)
                Rule().ignoresSafeArea(edges: .vertical)
            }
            Group {
                switch screen {
                case .library: LibraryView { screen = .add }
                case .add: AddView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if upright {
                Rule()
                LeftRail(selection: $screen, horizontal: true)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: screen)
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .overlay {
            if state.launching {
                ProgressView("Starting")
                    .padding(16)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.corner))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
            }
        }
        .unplacedQuestion()
        .fullScreenCover(item: $state.session, onDismiss: state.showPendingFailure) { GameView(session: $0) }
        .alert(state.launchFailure?.heading ?? "Could not play this game",
               isPresented: Binding(get: { state.launchFailure != nil }, set: { if !$0 { state.launchFailure = nil } }),
               presenting: state.launchFailure) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
        .alert("Resume \(state.resumeOffer?.title ?? "game")?",
               isPresented: Binding(get: { state.resumeOffer != nil }, set: { if !$0 { state.resumeOffer = nil } }),
               presenting: state.resumeOffer) { game in
            Button("Resume") { state.start(game, loading: state.saveStore(for: game).autoSlot) }
            Button("Start Over") { state.start(game) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Resume continues from your auto save. Start Over uses the game's own save, and replaces the auto save when you next leave the game.")
        }
        .task {
            // Runs once, when the app starts.
            if state.quickStart, let game = state.recentGames.first { state.launch(game) }
        }
    }
}

/// Replaces a tab bar: persistent chrome costs width, which landscape has, not height. Upright it runs along the
/// bottom instead.
private struct LeftRail: View {
    @Binding var selection: AppScreen
    var horizontal = false

    var body: some View {
        AnyLayout(horizontal ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: 4))) {
            ForEach(AppScreen.allCases) { item in
                let selected = selection == item
                Button { selection = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.title3.weight(selected ? .semibold : .regular))
                        Text(item.title)
                            .font(.caption2.weight(selected ? .bold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                    .foregroundStyle(selected ? AppTheme.accent : AppTheme.muted)
                    .overlay(alignment: .leading) {
                        if selected { Rectangle().fill(AppTheme.accent).frame(width: 3) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityShowsLargeContentViewer()
            }
            if !horizontal { Spacer(minLength: 0) }
        }
        .padding(horizontal ? .bottom : .top, horizontal ? 0 : 8)
        .frame(width: horizontal ? nil : 72)
        // The rail stays one fixed width; the large content viewer covers larger text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .background(AppTheme.surface.ignoresSafeArea())
    }
}
