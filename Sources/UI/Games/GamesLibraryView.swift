import SwiftUI

struct GamesLibraryView: View {
    @EnvironmentObject private var state: AppState
    @Binding var showControllers: Bool
    @Binding var showHistory: Bool
    @State private var contextGame: GameItem?
    @State private var showCorePicker = false
    @State private var showShaders = false
    @State private var renaming = false
    @State private var draftTitle = ""

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            LibraryHeader(showControllers: $showControllers, showHistory: $showHistory)
                .padding(.top, 8)
            if state.games.isEmpty {
                empty
            } else {
                populated
            }
        }
        .confirmationDialog(contextGame?.title ?? "Game", isPresented: contextPresented, titleVisibility: .visible) {
            Button("Launch") { if let game = contextGame { state.launch(game) } }
            Button("Switch Core") { showCorePicker = true }
            Button("Select Shader") { showShaders = true }
            Button("Rename") { draftTitle = contextGame?.title ?? ""; renaming = true }
            Button("Toggle Favorite") { toggleFavorite() }
            Button("Delete", role: .destructive) { if let game = contextGame { state.delete(game) } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCorePicker) {
            if let game = contextGame { CoreSelectionSheet(game: game) }
        }
        .sheet(isPresented: $showShaders) { ShadersSettingsView() }
        .alert("Rename", isPresented: $renaming) {
            TextField("Title", text: $draftTitle)
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var contextPresented: Binding<Bool> {
        Binding(get: { contextGame != nil && !showCorePicker && !showShaders && !renaming },
                set: { if !$0 { contextGame = nil } })
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Welcome to GAGA EMU's World")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            HStack(spacing: 6) {
                Text("Tap the").foregroundStyle(AppTheme.textSecondary)
                Image(systemName: "square.and.arrow.down").foregroundStyle(.white)
                Text("button to import").foregroundStyle(AppTheme.textSecondary)
            }
            .font(.system(size: 15))
            divider
            Link(destination: URL(string: "https://discord.com")!) {
                Text("Join ").foregroundStyle(AppTheme.textSecondary)
                + Text("Discord").foregroundStyle(.blue)
                + Text(" for assistance").foregroundStyle(AppTheme.textSecondary)
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(AppTheme.card, in: Capsule())
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(AppTheme.warning)
                Text("Ensure game ROMs are legally obtained")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.warning)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(AppTheme.card, in: Capsule())
            .padding(.bottom, 92)
        }
        .padding(.horizontal, 24)
    }

    private var populated: some View {
        VStack(spacing: 12) {
            filterBar
            ScrollView {
                if !state.recentGames.isEmpty && state.search.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recently Played").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(state.recentGames.prefix(8)) { game in
                                    card(game, width: 120)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(state.filteredGames) { game in card(game, width: 150) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .padding(.top, 12)
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textSecondary)
                TextField("Search", text: $state.search)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Search games")
            }
            .padding(10)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", id: "all")
                    ForEach(CoreCatalog.platforms) { platform in chip(platform.name, id: platform.id) }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func chip(_ title: String, id: String) -> some View {
        Button { state.platformFilter = id } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(state.platformFilter == id ? .white : AppTheme.textSecondary)
                .background(state.platformFilter == id ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.card),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func card(_ game: GameItem, width: CGFloat) -> some View {
        GameCardView(game: game, width: width)
            .onTapGesture { state.launch(game) }
            .onLongPressGesture { contextGame = game }
            .accessibilityAddTraits(.isButton)
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
            Image(systemName: "sparkle").foregroundStyle(AppTheme.textTertiary)
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private func toggleFavorite() {
        guard let id = contextGame?.id else { return }
        state.update(id) { $0.isFavorite.toggle() }
    }

    private func rename() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let id = contextGame?.id else { return }
        state.update(id) { $0.title = trimmed }
    }
}
