import SwiftUI

@main
struct GagaEmuApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(state)
                .environmentObject(state.controllers)
                .environmentObject(state.triggerPro)
                .environmentObject(state.skins)
                .environmentObject(state.store)
                .preferredColorScheme(state.appearance.colorScheme)
                .tint(AppTheme.accent)
        }
    }
}

#if DEBUG
enum AppStateChecks {
    @MainActor static func run() {
        assert(CoreCatalog.defaultCore(for: "gba") == "org.libretro.mgba")
        assert(CoreCatalog.coreName("org.libretro.bsnes") == "bsnes")
        assert(CoreCatalog.platformID(forExtension: "gdi") == "dreamcast")
        let game = GameItem(id: UUID(), title: "Demo", platformID: "ps1", romPath: "/tmp/a.chd",
                            coverPath: nil, coreOverride: nil, playTime: 0, lastPlayed: nil,
                            isFavorite: false, shaderID: "original")
        assert(game.resolvedCoreID == "org.libretro.pcsx-rearmed")
        WiFiTransferServerChecks.run()
        ClipboardImporterChecks.run()
        MultiDiscHelperChecks.run()
        RomPatcherChecks.run()
        ControllerManagerChecks.run()
        TriggerProManagerChecks.run()
        TouchSkinEngineChecks.run()
        StoreKitManagerChecks.run()
    }
}
#endif
