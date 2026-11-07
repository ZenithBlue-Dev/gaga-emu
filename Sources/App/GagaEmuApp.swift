import SwiftUI

@main
struct GagaEmuApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.controllers)
                .environmentObject(state.triggerPro)
                .environmentObject(state.skins)
                .environmentObject(state.store)
                .environmentObject(state.wifi)
                .tint(AppTheme.accent)
                .task {
                    GameCenter.authenticate()
                    #if DEBUG
                    state.runBenchmarkIfRequested()
                    #endif
                }
        }
    }
}

#if DEBUG
enum AppStateChecks {
    @MainActor static func run() {
        CodeGenCheck.captureBaseline()
        assert(CoreCatalog.defaultCore(for: "gba") == "mgba" || GagaCoreRegistry_IsExcluded("mgba"))
        assert(CoreCatalog.coreName("bsnes") == "bsnes")
        assert(CoreCatalog.platformID(forExtension: "gdi") == "dreamcast")
        let game = GameItem(id: UUID(), title: "Demo", platformID: "ps1", romPath: "/tmp/a.chd",
                            coverPath: nil, coreOverride: nil, playTime: 0, lastPlayed: nil,
                            isFavorite: false, shaderID: "original")
        assert(game.resolvedCoreID(defaults: [:]) == "pcsx_rearmed")
        assert(game.resolvedCoreID(defaults: ["ps1": "beetle_psx"]) == "beetle_psx")
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
