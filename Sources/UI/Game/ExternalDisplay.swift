import SwiftUI
import UIKit

/// AirPlay Fullscreen (docs/06 section 3.3). While a game runs with the setting on and a second screen
/// connected, the picture goes to a window on that screen and `GameView` keeps the controls.
/// With no window on the scene, iOS mirrors the device as usual.
@MainActor
final class ExternalDisplay: ObservableObject {
    static let shared = ExternalDisplay()

    @Published private(set) var session: GameSession?
    private var scene: UIWindowScene?
    private var window: UIWindow?

    /// True when the external screen has the picture, so the device must not draw it too.
    /// A ring slot releases once per draw, and one delegate on two views would draw twice per frame.
    var showsPicture: Bool { window != nil }

    func connect(_ scene: UIWindowScene) {
        self.scene = scene
        update()
    }

    func disconnect(_ scene: UIWindowScene) {
        guard self.scene === scene else { return }
        self.scene = nil
        update()
    }

    /// `session` is nil when no game is on screen or the setting is off.
    func present(_ session: GameSession?) {
        self.session = session
        update()
    }

    private func update() {
        objectWillChange.send()
        window?.isHidden = true
        window = nil
        guard let scene, let session else { return }
        let next = UIWindow(windowScene: scene)
        next.rootViewController = UIHostingController(rootView: ExternalPicture(session: session))
        next.isHidden = false
        window = next
    }
}

private struct ExternalPicture: View {
    @ObservedObject var session: GameSession

    var body: some View {
        GamePicture(session: session)
            .ignoresSafeArea()
            .background(AppTheme.letterbox.ignoresSafeArea())
    }
}

final class ExternalSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        MainActor.assumeIsolated { ExternalDisplay.shared.connect(windowScene) }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        MainActor.assumeIsolated { ExternalDisplay.shared.disconnect(windowScene) }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        if session.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalSceneDelegate.self
        }
        return configuration
    }
}
