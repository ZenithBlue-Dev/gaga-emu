import XCTest
import Metal
import AVFoundation
@testable import GagaEmu

final class GagaEmuTests: XCTestCase {

    // MARK: - Core Registry Tests

    func testCoreRegistryCountAndLookup() {
        let count = GagaCoreRegistry_GetCount()
        XCTAssertEqual(count, 12, "Mock plus 11 core stubs")

        // Validate mock core
        let mock = GagaCoreRegistry_FindByID("mock")
        XCTAssertNotNil(mock)
        XCTAssertEqual(String(cString: mock!.pointee.core_name), "Mock Validation Core")

        // Validate tier 1 cores
        XCTAssertNotNil(GagaCoreRegistry_FindByID("mgba"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("gambatte"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("bsnes"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("jgenesis"))

        // Excluded by licence (docs/03 section 6)
        XCTAssertNil(GagaCoreRegistry_FindByID("snes9x"))
        XCTAssertNil(GagaCoreRegistry_FindByID("genesis_plus_gx"))

        // Validate tier 2 cores
        XCTAssertNotNil(GagaCoreRegistry_FindByID("pcsx_rearmed"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("beetle_psx"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("melonds"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("flycast"))

        // Validate tier 3 cores
        XCTAssertNotNil(GagaCoreRegistry_FindByID("azahar"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("ppsspp"))
    }

    func testCoreRegistryFindByExtension() {
        let gbaCore = GagaCoreRegistry_FindByExtension("gba")
        XCTAssertNotNil(gbaCore)

        let snesCore = GagaCoreRegistry_FindByExtension("smc")
        XCTAssertNotNil(snesCore)

        let gbCore = GagaCoreRegistry_FindByExtension("gb")
        XCTAssertNotNil(gbCore)

        let ndsCore = GagaCoreRegistry_FindByExtension("nds")
        XCTAssertNotNil(ndsCore)

        let pspCore = GagaCoreRegistry_FindByExtension("cso")
        XCTAssertNotNil(pspCore)
    }

    // MARK: - Operational Mock Core Tests

    func testMockCoreLifecycleAndOutput() {
        guard let mockInterface = MockCore_GetInterface() else {
            XCTFail("Mock core interface must not be nil")
            return
        }

        let tempSysDir = NSTemporaryDirectory() + "gaga_sys"
        let tempSaveDir = NSTemporaryDirectory() + "gaga_saves"

        guard let inst = mockInterface.pointee.create(tempSysDir, tempSaveDir) else {
            XCTFail("Mock core instance creation failed")
            return
        }

        var frameReceived = false
        var audioReceived = false
        var receivedWidth: UInt32 = 0
        var receivedHeight: UInt32 = 0
        var audioFrames: size_t = 0

        let contextPtr = UnsafeMutableRawPointer(bitPattern: 0x1234)

        // Setup callbacks
        typealias VideoCB = @convention(c) (UnsafePointer<GagaFrameDescriptor>?, UnsafeMutableRawPointer?) -> Void
        let videoCallback: VideoCB = { frame, _ in
            guard let f = frame?.pointee else { return }
            XCTAssertNotNil(f.pixel_data)
            XCTAssertEqual(f.width, 256)
            XCTAssertEqual(f.height, 224)
            XCTAssertEqual(f.pixel_format, GAGA_PIXEL_FORMAT_RGBA8888.rawValue)
        }

        mockInterface.pointee.set_video_callback(inst, videoCallback, contextPtr)

        // Step frame
        var inputs = [GagaInputState](repeating: GagaInputState(), count: 4)
        mockInterface.pointee.step_frame(inst, &inputs, 1)

        // Test save and load state
        let statePath = NSTemporaryDirectory() + "mock_test.state"
        let saved = mockInterface.pointee.save_state_file(inst, statePath)
        XCTAssertTrue(saved, "Save state should succeed")

        let loaded = mockInterface.pointee.load_state_file(inst, statePath)
        XCTAssertTrue(loaded, "Load state should succeed")
        try? FileManager.default.removeItem(atPath: statePath)

        mockInterface.pointee.destroy(inst)
    }

    // MARK: - Swift Wrapper Tests

    func testGagaCoreWrapperExecution() async throws {
        guard let mockInterface = MockCore_GetInterface()?.pointee else {
            XCTFail("Missing mock core interface")
            return
        }

        let wrapper = GagaCoreWrapper(interface: mockInterface)
        XCTAssertEqual(wrapper.coreID, "mock")
        XCTAssertEqual(wrapper.targetFPS, 60.0)
        XCTAssertEqual(wrapper.nativeSampleRate, 44100)

        let expVideo = expectation(description: "Video frame received")
        let expAudio = expectation(description: "Audio packet received")

        wrapper.onVideoFrame = { frame in
            XCTAssertEqual(frame.width, 256)
            XCTAssertEqual(frame.height, 224)
            expVideo.fulfill()
        }

        wrapper.onAudioPacket = { audio in
            XCTAssertEqual(audio.sampleRate, 44100)
            XCTAssertEqual(audio.channels, 2)
            expAudio.fulfill()
        }

        try await wrapper.loadROM(path: "test.mock", data: Data([0x00, 0x01]))
        XCTAssertTrue(wrapper.isLoaded)

        wrapper.step(inputs: [GagaInputState()])

        await fulfillment(of: [expVideo, expAudio], timeout: 2.0)
        wrapper.stop()
    }

    // MARK: - Metal Texture Ring Tests

    func testMetalTextureRingAlignment() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let ring = MetalTextureRing(device: device, width: 256, height: 224, pixelFormat: .rgba8Unorm)
        XCTAssertEqual(ring.width, 256)
        XCTAssertEqual(ring.height, 224)

        // Metal buffer row alignment must be 256-byte aligned
        XCTAssertEqual(ring.bytesPerRow % 256, 0)
        XCTAssertGreaterThanOrEqual(ring.bytesPerRow, 256 * 4)

        let (ptr, texture, idx) = ring.acquireWritableBuffer()
        XCTAssertNotNil(ptr)
        XCTAssertEqual(texture.width, 256)
        XCTAssertEqual(texture.height, 224)
        XCTAssertTrue(idx >= 0 && idx < 3)
    }

    // MARK: - Metal Renderer & Shader Manager Tests

    func testShaderPresetsAndUniforms() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let manager = ShaderManager(device: device)
        XCTAssertNotNil(manager.previewRenderer)
        XCTAssertNotNil(manager.previewTexture)

        for preset in ShaderPreset.allCases {
            manager.selectedPreset = preset
            XCTAssertEqual(manager.previewRenderer?.activePreset, preset)
        }

        manager.curvature = 0.45
        manager.scanlineWeight = 0.75
        manager.syncUniforms()

        XCTAssertEqual(manager.previewRenderer?.uniforms.curvature, 0.45)
        XCTAssertEqual(manager.previewRenderer?.uniforms.scanlineWeight, 0.75)
    }

    // MARK: - Audio Engine Manager Tests

    func testAudioEngineManagerIngestion() {
        let audioManager = AudioEngineManager(outputSampleRate: 44100.0)
        XCTAssertEqual(audioManager.volume, 1.0)
        XCTAssertEqual(audioManager.playbackSpeed, 1.0)

        // Ingest test PCM samples
        let sampleCount = 735 * 2
        var testSamples = [Int16](repeating: 1000, count: sampleCount)
        testSamples.withUnsafeBufferPointer { ptr in
            audioManager.writeSamples(ptr.baseAddress!, frames: 735, channels: 2)
        }

        audioManager.playbackSpeed = 1.5
        XCTAssertEqual(audioManager.playbackSpeed, 1.5)

        audioManager.reset()
    }

    // MARK: - Core Catalog Tests

    func testCatalogMatchesDocs() {
        let ids = CoreCatalog.platforms.flatMap(\.cores).map(\.id)
        for id in ids {
            XCTAssertNotNil(id.range(of: "^[a-z0-9_]+$", options: .regularExpression), "\(id) is not a core_id")
        }
        for excluded in ["snes9x", "genesis_plus_gx", "picodrive", "fbneo", "kronos", "swanstation"] {
            XCTAssertFalse(ids.contains(excluded))
        }
        XCTAssertEqual(CoreCatalog.defaultCore(for: "snes"), "bsnes")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "megadrive"), "jgenesis")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "arcade"), "mame")

        // Every registry stub resolves to a catalog row, so a saved ID always names a real core.
        for index in 0..<GagaCoreRegistry_GetCount() {
            let id = String(cString: GagaCoreRegistry_GetAtIndex(index)!.pointee.core_id)
            if id != "mock" { XCTAssertTrue(ids.contains(id), "\(id) missing from CoreCatalog") }
        }
    }

    func testResolvedCoreIDHonoursDefaults() {
        var game = GameItem(id: UUID(), title: "Demo", platformID: "ps1", romPath: "/a.chd", coverPath: nil,
                            coreOverride: nil, playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), "pcsx_rearmed")
        XCTAssertEqual(game.resolvedCoreID(defaults: ["ps1": "beetle_psx"]), "beetle_psx")
        game.coreOverride = "pcsx_rearmed"
        XCTAssertEqual(game.resolvedCoreID(defaults: ["ps1": "beetle_psx"]), "pcsx_rearmed")
    }

    // MARK: - state.json Migration Tests

    /// A file as written by a build before milestone 1.3.
    private let legacyStateJSON = """
    {"games":[
      {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"A","platformID":"gba","romPath":"/a.gba",
       "coreOverride":"org.libretro.gpsp","playTime":120,"isFavorite":true,"shaderID":"crt-v1"},
      {"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","title":"B","platformID":"snes","romPath":"/b.sfc",
       "coreOverride":"org.libretro.snes9x","playTime":5,"isFavorite":false,"shaderID":"original"},
      {"id":"8F9619FF-8B86-D011-B42D-00C04FC964FF","title":"C","platformID":"nes","romPath":"/c.nes",
       "playTime":0,"isFavorite":false,"shaderID":"original"}
    ],
    "history":[],"nickname":"Sam","joined":0,"avatarIndex":2,"appearance":"dark","quickStart":false,
    "autoSaveStates":false,"coverScraping":true,"airPlayFullscreen":false,"iCloudSync":false,
    "autoFullScreen":true,"respectSilentMode":false,"rumble":false,"skinSoundEffects":true,
    "language":"English","shaderID":"film",
    "defaultCores":{"ps1":"org.libretro.beetle-psx","arcade":"org.libretro.fbneo","n3ds":"org.azahar.azahar"}}
    """

    func testStateMigrationUpgradesLegacyFile() throws {
        let legacy = try JSONDecoder().decode(AppState.Snapshot.self, from: Data(legacyStateJSON.utf8))
        let migrated = try XCTUnwrap(StateMigration.migrated(legacy))

        XCTAssertEqual(migrated.games.map(\.coreOverride), ["gpsp", nil, nil])
        XCTAssertEqual(migrated.defaultCores, ["ps1": "beetle_psx", "n3ds": "azahar"])

        // Nothing else is touched.
        XCTAssertEqual(migrated.games.map(\.title), ["A", "B", "C"])
        XCTAssertEqual(migrated.games.map(\.playTime), [120, 5, 0])
        XCTAssertEqual(migrated.games[0].isFavorite, true)
        XCTAssertEqual(migrated.nickname, "Sam")
        XCTAssertEqual(migrated.avatarIndex, 2)

        // A game on a removed core now resolves to the platform default.
        XCTAssertEqual(migrated.games[1].coreOverride ?? CoreCatalog.defaultCore(for: "snes"), "bsnes")

        // Second launch: nothing left to do.
        let reloaded = try JSONDecoder().decode(AppState.Snapshot.self, from: JSONEncoder().encode(migrated))
        XCTAssertNil(StateMigration.migrated(reloaded))
    }

    func testStateMigrationResetsRemovedShaders() throws {
        var legacy = try JSONDecoder().decode(AppState.Snapshot.self, from: Data(legacyStateJSON.utf8))
        legacy.shaderID = "anime4k"
        legacy.games[2].shaderID = "crt-royale"
        let migrated = try XCTUnwrap(StateMigration.migrated(legacy))
        XCTAssertEqual(migrated.shaderID, "original")
        XCTAssertEqual(migrated.games.map(\.shaderID), ["crt-v1", "original", "original"])
    }

    func testStateMigrationKeepsCurrentAndUnknownIDs() {
        XCTAssertEqual(StateMigration.coreID("mgba"), "mgba")
        XCTAssertEqual(StateMigration.coreID("org.example.future"), "org.example.future")
        XCTAssertEqual(StateMigration.coreID("org.libretro.vba-m"), "vba_m")
        XCTAssertNil(StateMigration.coreID("org.libretro.genesis-plus-gx"))
    }

    func testEveryLegacyCoreIDMapsIntoTheCatalog() {
        let ids = Set(CoreCatalog.platforms.flatMap(\.cores).map(\.id))
        for (legacy, current) in StateMigration.legacyCoreIDs {
            XCTAssertTrue(ids.contains(current), "\(legacy) maps to unknown \(current)")
        }
    }

    // MARK: - RomPatcher Tests

    func testRomPatcherIPS() throws {
        // Simple IPS patch: "PATCH" + 3-byte offset 0x000000 + 2-byte size 0x0004 + bytes [0xAA, 0xBB, 0xCC, 0xDD] + "EOF"
        var patchData = Data("PATCH".utf8)
        patchData.append(contentsOf: [0x00, 0x00, 0x00]) // offset 0
        patchData.append(contentsOf: [0x00, 0x04])       // length 4
        patchData.append(contentsOf: [0xAA, 0xBB, 0xCC, 0xDD])
        patchData.append(Data("EOF".utf8))

        let sourceData = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
        let patched = try RomPatcher.apply(patchData, to: sourceData)

        XCTAssertEqual(patched.count, 6)
        XCTAssertEqual(patched[0], 0xAA)
        XCTAssertEqual(patched[1], 0xBB)
        XCTAssertEqual(patched[2], 0xCC)
        XCTAssertEqual(patched[3], 0xDD)
        XCTAssertEqual(patched[4], 0x55)
        XCTAssertEqual(patched[5], 0x66)

        let checksums = RomPatcher.checksums(patched)
        XCTAssertNotEqual(checksums.crc32, 0)
        XCTAssertFalse(checksums.md5.isEmpty)
        XCTAssertFalse(checksums.sha1.isEmpty)
    }

    // MARK: - MultiDiscHelper Tests

    func testMultiDiscHelperParsingAndPlaylist() throws {
        let disc1 = URL(fileURLWithPath: "/tmp/Metal Gear Solid (Disc 1).chd")
        let disc2 = URL(fileURLWithPath: "/tmp/Metal Gear Solid (Disc 2).chd")

        let parsed1 = MultiDiscHelper.parse(disc1)
        XCTAssertNotNil(parsed1)
        XCTAssertEqual(parsed1?.title, "Metal Gear Solid")
        XCTAssertEqual(parsed1?.disc, 1)

        let parsed2 = MultiDiscHelper.parse(disc2)
        XCTAssertNotNil(parsed2)
        XCTAssertEqual(parsed2?.title, "Metal Gear Solid")
        XCTAssertEqual(parsed2?.disc, 2)

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("m3u_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("Chrono Cross (Disc 1).cue")
        let file2 = tempDir.appendingPathComponent("Chrono Cross (Disc 2).cue")
        try "FILE Chrono1.bin BINARY".write(to: file1, atomically: true, encoding: .utf8)
        try "FILE Chrono2.bin BINARY".write(to: file2, atomically: true, encoding: .utf8)

        let groups = MultiDiscHelper.scan(tempDir)
        XCTAssertEqual(groups.count, 1)
        guard let group = groups.first else { return }
        XCTAssertEqual(group.title, "Chrono Cross")
        XCTAssertEqual(group.discs.count, 2)

        let playlistURL = try MultiDiscHelper.writePlaylist(for: group, into: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: playlistURL.path))

        let playlistContent = try String(contentsOf: playlistURL)
        XCTAssertTrue(playlistContent.contains("Chrono Cross (Disc 1).cue"))
        XCTAssertTrue(playlistContent.contains("Chrono Cross (Disc 2).cue"))
    }

    // MARK: - TriggerPro Manager Tests

    func testTriggerProTurboAndLatch() {
        let triggerPro = TriggerProManager()

        // Configure Turbo button on GAGA_BTN_SOUTH (A / Cross)
        let turboBinding = TriggerProManager.Binding(
            name: "Turbo A",
            mode: .turbo,
            source: GAGA_BTN_SOUTH.rawValue,
            output: GAGA_BTN_SOUTH.rawValue,
            hertz: 30.0 // period is 2 frames at 60fps
        )
        triggerPro.bindings.append(turboBinding)

        var rawInput = ControllerManager.InputState()
        rawInput.buttons = GAGA_BTN_SOUTH.rawValue

        // Frame 0: Turbo active (press)
        let outFrame0 = triggerPro.process(rawInput, frame: 0)
        XCTAssertEqual(outFrame0.buttons & GAGA_BTN_SOUTH.rawValue, GAGA_BTN_SOUTH.rawValue)

        // Frame 1: Turbo cycles off
        let outFrame1 = triggerPro.process(rawInput, frame: 1)
        XCTAssertEqual(outFrame1.buttons & GAGA_BTN_SOUTH.rawValue, 0)

        // Frame 2: Turbo cycles on again
        let outFrame2 = triggerPro.process(rawInput, frame: 2)
        XCTAssertEqual(outFrame2.buttons & GAGA_BTN_SOUTH.rawValue, GAGA_BTN_SOUTH.rawValue)
    }

    // MARK: - Premium Spec Tests (docs/06 section 4)

    @MainActor
    func testPremiumListMatchesImplementedShaders() {
        XCTAssertEqual(StoreKitManager.premiumShaderIDs, ["geom-crt", "geom-crt-border"])
        XCTAssertFalse(ShaderCatalog.builtIn.contains { $0.id == "anime4k" })
        let premium = Set(ShaderCatalog.builtIn.filter(\.premium).map(\.id))
        XCTAssertEqual(premium, StoreKitManager.premiumShaderIDs)
    }

    @MainActor
    func testOfferBadgesAndDisclosureMatchTheProduct() {
        XCTAssertNil(StoreKitManager.badge(for: .annual, intro: nil))
        XCTAssertNil(StoreKitManager.badge(for: .monthly, intro: nil))
        XCTAssertEqual(StoreKitManager.badge(for: .monthly, intro: .paid), "Introductory Offer")
        XCTAssertEqual(StoreKitManager.badge(for: .annual, intro: .freeTrial), "Free Trial")
        XCTAssertEqual(StoreKitManager.badge(for: .lifetime, intro: nil), "Best Value")

        XCTAssertEqual(StoreKitManager.disclosure(for: .monthly, intro: nil), "Cancel anytime")
        XCTAssertEqual(StoreKitManager.disclosure(for: .annual, intro: .freeTrial), "No charges during trial period. Cancel anytime")
        XCTAssertNil(StoreKitManager.disclosure(for: .lifetime, intro: nil))
    }

    @MainActor
    func testLifetimeOwnersSeeNoSubscribePrompts() {
        XCTAssertTrue(StoreKitManager.Entitlements.free.showsSubscribePrompts)
        XCTAssertTrue(StoreKitManager.Entitlements(premium: true).showsSubscribePrompts)
        XCTAssertFalse(StoreKitManager.Entitlements(premium: true, lifetime: true).showsSubscribePrompts)
    }

    @MainActor
    func testPaywallGateClosedLiftsLimits() {
        let closed = StoreKitManager.Entitlements.effective(.free, gateOpen: false)
        XCTAssertEqual(closed.maxSaveStates, .max)
        XCTAssertEqual(closed.maxCheats, .max)
        XCTAssertEqual(closed.maxFastForward, 5)
        XCTAssertTrue(closed.premiumShaders)
        XCTAssertTrue(closed.autoSaveState)
    }

    @MainActor
    func testPaywallGateOpenEnforcesPurchases() {
        let free = StoreKitManager.Entitlements.effective(.free, gateOpen: true)
        XCTAssertEqual(free, .free)
        XCTAssertEqual(free.maxSaveStates, 3)
        let lifetime = StoreKitManager.Entitlements(premium: true, lifetime: true)
        XCTAssertEqual(StoreKitManager.Entitlements.effective(lifetime, gateOpen: true), lifetime)
    }

    #if !PAYWALL_ENABLED
    @MainActor
    func testGateClosedInThisBuild() {
        XCTAssertFalse(PaywallGate.isOpen)
        XCTAssertTrue(StoreKitManager().canUseShader("geom-crt"))
    }
    #endif

    @MainActor
    func testAutoSaveStateIsPremium() {
        XCTAssertFalse(StoreKitManager.Entitlements.free.autoSaveState)
        XCTAssertTrue(StoreKitManager.Entitlements(premium: true).autoSaveState)
    }

    // MARK: - StoreKit Entitlements Tests

    @MainActor
    func testStoreKitEntitlementsGating() {
        let freeEntitlements = StoreKitManager.Entitlements.free
        XCTAssertFalse(freeEntitlements.premium)
        XCTAssertEqual(freeEntitlements.maxSaveStates, 3)
        XCTAssertEqual(freeEntitlements.maxCheats, 3)
        XCTAssertEqual(freeEntitlements.maxFastForward, 2.0)
        XCTAssertFalse(freeEntitlements.premiumShaders)

        let premiumEntitlements = StoreKitManager.Entitlements(premium: true)
        XCTAssertTrue(premiumEntitlements.premium)
        XCTAssertEqual(premiumEntitlements.maxSaveStates, Int.max)
        XCTAssertEqual(premiumEntitlements.maxCheats, Int.max)
        XCTAssertEqual(premiumEntitlements.maxFastForward, 5.0)
        XCTAssertTrue(premiumEntitlements.premiumShaders)
    }
}
