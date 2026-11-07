import GameKit

/// Signs in the local player in the background. No leaderboards or achievements yet.
enum GameCenter {
    @MainActor static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            // Deliberately silent: launch never waits on this, a failure shows nothing,
            // and the sign-in sheet GameKit may offer is not presented.
        }
    }
}
