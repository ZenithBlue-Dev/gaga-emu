import SwiftUI

/// Profile card: nickname, play time, join date, avatar.
struct AdventurerCardView: View {
    @EnvironmentObject private var state: AppState
    @State private var editing = false
    @State private var draft = ""

    private let avatars = ["gamecontroller.fill", "flag.fill", "star.fill", "bolt.fill", "crown.fill", "pawprint.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adventurer Card")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.textSecondary)
            HStack(alignment: .center, spacing: 8) {
                VStack(spacing: 8) {
                    row("Nickname: \(state.nickname)")
                    row("Play Time: \(state.playTimeLabel)")
                    row("Joined: \(state.joinedLabel)")
                }
                Button { cycleAvatar() } label: {
                    Image(systemName: avatars[state.avatarIndex % avatars.count])
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(Circle().fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom)))
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change avatar")
            }
        }
        .padding(14)
        .glassCard()
        .onTapGesture { draft = state.nickname; editing = true }
        .alert("Nickname", isPresented: $editing) {
            TextField("Nickname", text: $draft)
            Button("Save") {
                let trimmed = draft.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { state.nickname = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(AppTheme.warning).frame(width: 3, height: 18)
            Text(text).font(.system(size: 14)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func cycleAvatar() { state.avatarIndex = (state.avatarIndex + 1) % avatars.count }
}
