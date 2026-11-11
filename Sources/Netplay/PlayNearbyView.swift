import SwiftUI

/// The pause menu's Play Nearby row and its sheet. On every system: where it cannot play nearby, the sheet says why.
struct PlayNearbyRow: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var state: AppState
    @State private var shown: NetplaySession?

    var body: some View {
        let allowed = session.netplayCore.map { CoreCatalog.playNearbyAllowed(platformID: session.game.platformID, coreID: $0.coreID) } ?? false
        Button(action: open) {
            HStack {
                Text("Play Nearby")
                Spacer(minLength: 8)
                if !allowed {
                    Text("Not available").font(.meta).foregroundStyle(AppTheme.muted)
                } else if let current = NetplaySession.current, current.game === session, case .connected = current.phase {
                    Text("On").font(.meta).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("playNearby")
        .sheet(item: $shown) { PlayNearbySheet(net: $0) }
        .onAppear {
            // From the Library's Play Nearby: open once this game is paused for it.
            if allowed, NetplaySession.openOnStart == session.game.id {
                NetplaySession.openOnStart = nil
                open()
            }
        }
    }

    private func open() {
        let path = session.game.resolvedROMPath(romDirectory: state.romDirectory) ?? session.game.romPath
        shown = NetplaySession.session(for: session, romPath: path)
    }
}

extension NetplaySession: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

/// The Library game menu's entry: starts the game, pauses it once running, and the pause menu opens the sheet.
struct PlayNearbyMenuItem: View {
    let game: GameItem
    @EnvironmentObject private var state: AppState

    var body: some View {
        Button(action: start) { Label("Play Nearby", systemImage: "person.2") }
    }

    private func start() { Self.begin(game, state: state) }

    /// Starts the game, pauses it once running, and the pause menu opens Play Nearby. Also from the game's page.
    @MainActor static func begin(_ game: GameItem, state: AppState) {
        guard CoreCatalog.playNearbyAllowed(platformID: game.platformID, coreID: game.resolvedCoreID(defaults: state.defaultCores)) else {
            state.launchFailure = .init(title: "Play Nearby", message: CoreCatalog.playNearbyReason(platformID: game.platformID))
            return
        }
        NetplaySession.openOnStart = game.id
        state.launch(game)
        let id = game.id
        Task { @MainActor [weak state] in
            // Up to a minute, for the resume question and the core's load.
            for _ in 0..<600 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let state, NetplaySession.openOnStart == id else { return }
                if let session = state.session, session.game.id == id, session.phase == .running {
                    session.pause(.menu)
                    return
                }
            }
            NetplaySession.openOnStart = nil
        }
    }
}

struct PlayNearbySheet: View {
    @ObservedObject var net: NetplaySession

    var body: some View {
        PaperSheet(title: "Play Nearby", subtitle: net.game.game.title) {
            VStack(alignment: .leading, spacing: 12) {
                content
                if let note = net.note {
                    Text(note).font(.footnote).foregroundStyle(AppTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch net.phase {
        case .idle:
            if let reason = net.unavailableReason {
                para(reason)
            } else {
                para("Two phones near each other play this game together, each with its own controls. Both players need the same game file. It works on the same Wi-Fi, or directly between phones with no Wi-Fi.")
                Button("Host", action: net.host).buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("This phone's players come first, from player 1, and it waits for the other phone.")
                Button("Join", action: net.join).buttonStyle(QuietButtonStyle())
                    .accessibilityHint("This phone's players follow the host's, and it looks for a phone that is hosting.")
            }
        case .checking:
            ProgressView("Checking this game")
        case .hosting:
            para("Waiting for a nearby phone. On the other phone, open this game, then Play Nearby, then Join.")
            ProgressView().accessibilityLabel("Waiting")
            cancel
        case .browsing:
            Text("Nearby phones").font(.headline).accessibilityAddTraits(.isHeader)
            if net.peers.isEmpty {
                para("Looking for a phone that is hosting. Keep both phones close.")
            }
            ForEach(net.peers) { peer in
                Button { net.connect(to: peer) } label: {
                    HStack {
                        Image(systemName: "iphone").accessibilityHidden(true)
                        Text(peer.id)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Asks this phone to play together.")
                Rule()
            }
            cancel
        case .connecting:
            ProgressView("Connecting")
            cancel
        case .confirm(let peer, let code):
            para("\(peer) wants to join. Accept only if both phones show this code.")
            codeView(code)
            Button("Accept", action: net.accept).buttonStyle(PrimaryButtonStyle())
            Button("Decline", action: net.decline).buttonStyle(QuietButtonStyle())
        case .waiting(let peer, let code):
            para("Check that both phones show this code. Waiting for \(peer) to accept.")
            codeView(code)
            cancel
        case .connected(let peer):
            para("Playing with \(peer). Pausing on one phone pauses both. Fast-forward and rewind are off while you play together.")
            if let ports = net.ports {
                let first = net.isHost ? 1 : ports.host + 1, count = net.isHost ? ports.host : ports.joiner
                status(count == 1 ? "You are" : "This phone", count == 1 ? "Player \(first)" : "Players \(first) to \(first + count - 1)")
                status("Players", "\(ports.host + ports.joiner)")
            }
            status("Ping", net.pingMs.map { "\($0) ms" } ?? "Measuring")
            status("Input delay", "\(net.delayFrames) frames")
            Button("Leave", action: net.leave).buttonStyle(QuietButtonStyle())
                .accessibilityHint("Both phones go on playing alone.")
        case .ended(let message):
            para(message)
            Button("Try Again", action: net.reset).buttonStyle(QuietButtonStyle())
        }
    }

    private var cancel: some View {
        Button("Cancel", action: net.leave).buttonStyle(QuietButtonStyle())
    }

    private func para(_ text: String) -> some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }

    private func codeView(_ code: String) -> some View {
        Text(code)
            .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
            .padding(.vertical, 8)
            .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")
    }

    private func status(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Text(value).font(.meta).foregroundStyle(AppTheme.muted)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
    }
}
