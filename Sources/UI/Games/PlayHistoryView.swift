import SwiftUI

/// Chronological sessions. Tap a row to resume.
struct PlayHistoryView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var sessions: [PlaySession] {
        state.history.sorted { $0.started > $1.started }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                            Section(dayLabel(day)) {
                                ForEach(grouped[day] ?? []) { session in
                                    if let game = state.games.first(where: { $0.id == session.gameID }) {
                                        Button { state.launch(game); dismiss() } label: { row(game, session) }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Play History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 18) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(AppTheme.cardRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("No Play History").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Button { dismiss() } label: {
                Text("Import Games")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26).padding(.vertical, 12)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ game: GameItem, _ session: PlaySession) -> some View {
        HStack(spacing: 12) {
            GameCardView(game: game, width: 46).frame(width: 46, height: 62).clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(game.title).foregroundStyle(.white).font(.system(size: 15, weight: .semibold))
                Text(session.started.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(duration(session.duration))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(AppTheme.textSecondary)
            Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(AppTheme.accent)
        }
        .accessibilityLabel("Resume \(game.title)")
    }

    private var grouped: [Date: [PlaySession]] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.started) }
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s >= 60 ? "\(s / 60)m" : "\(s)s"
    }
}
