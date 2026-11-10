import GameKit

/// The name games and Play Nearby see: Settings > Player Name, else the Game Center alias, else "GagaEmu".
enum PlayerName {
    static let key = "playerName"

    /// Letters, digits, '_' and '-', 3 to 16 of them, which every core takes (PPSSPP's rule; melonDS cuts to 10).
    static func sanitized(_ raw: String) -> String {
        let kept = String(raw.unicodeScalars.filter { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-") }.prefix(16))
        return kept.count >= 3 ? kept : "GagaEmu"
    }

    @MainActor static var effective: String {
        let chosen = UserDefaults.standard.string(forKey: key) ?? ""
        let player = GKLocalPlayer.local
        return sanitized(!chosen.isEmpty ? chosen : player.isAuthenticated ? player.alias : "")
    }

    /// For Settings > Profile. The alias only, never other Game Center details.
    @MainActor static var gameCenterStatus: String {
        GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.alias : "Not signed in"
    }
}

/// Signs in the local player in the background. No leaderboards or achievements yet.
enum GameCenter {
    @MainActor static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            // Deliberately silent: launch never waits on this, a failure shows nothing,
            // and the sign-in sheet GameKit may offer is not presented.
        }
    }
}
