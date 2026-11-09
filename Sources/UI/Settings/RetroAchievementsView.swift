import SwiftUI

/// The player's own RetroAchievements account. The password is sent once to get a token and is never kept.
struct RetroAchievementsView: View {
    @ObservedObject private var account = RetroAchievements.shared
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var message: String?

    var body: some View {
        PaperSheet(title: "RetroAchievements", scrolls: false) {
            List {
                if let name = account.username {
                    Section("Account") {
                        Text("Signed in as \(name)").accessibilityIdentifier("raSignedIn")
                        Button("Sign Out", role: .destructive) { account.signOut() }
                            .accessibilityIdentifier("raSignOut")
                    }
                    .paperRows()
                } else {
                    Section("Sign In") {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("raUsername")
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .accessibilityIdentifier("raPassword")
                        Button(working ? "Signing In..." : "Sign In", action: signIn)
                            .disabled(working || username.isEmpty || password.isEmpty)
                            .accessibilityIdentifier("raSignIn")
                        if let message {
                            Text(message).font(.footnote).foregroundStyle(AppTheme.muted)
                                .accessibilityIdentifier("raMessage")
                        }
                        Text("Your password goes only to retroachievements.org over HTTPS, in exchange for a token kept in the Keychain. It is not stored.")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                    .paperRows()
                }
                Section("Mode") {
                    ToggleRow(title: "Hardcore",
                              note: "Earns hardcore points. Loading states, cheats and rewind are off while a game has achievements. Turning it on during a game resets that game.",
                              isOn: Binding(get: { account.hardcore }, set: { account.setHardcore($0) }))
                        .accessibilityIdentifier("raHardcore")
                }
                .paperRows()
            }
            .paperList()
        }
    }

    private func signIn() {
        working = true
        message = nil
        account.signIn(username: username, password: password) { error in
            working = false
            password = ""
            message = error
        }
    }
}

/// The pause menu's list for the running game.
struct AchievementsSheet: View {
    @ObservedObject var session: GameSession
    @State private var items: [AchievementInfo] = []

    var body: some View {
        PaperSheet(title: "Achievements", scrolls: false) {
            List(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                    Text(item.detail).font(.meta).foregroundStyle(AppTheme.muted)
                    if item.unlocked {
                        Text("Unlocked, \(item.points) points").font(.meta).foregroundStyle(AppTheme.muted)
                    } else if item.progress.isEmpty {
                        Text("\(item.points) points").font(.meta).foregroundStyle(AppTheme.muted)
                    } else {
                        ProgressView(value: min(item.percent, 100), total: 100)
                        Text("\(item.progress), \(item.points) points").font(.meta).foregroundStyle(AppTheme.muted)
                    }
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            }
            .paperRows()
            .paperList()
        }
        .onAppear { items = session.achievementList() }
    }
}
