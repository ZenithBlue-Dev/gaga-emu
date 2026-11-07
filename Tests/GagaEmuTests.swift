import XCTest
import Metal
import AVFoundation
@testable import GagaEmu

final class GagaEmuTests: XCTestCase {

    // MARK: - Core Registry Tests

    func testCoreRegistryCountAndLookup() {
        let count = GagaCoreRegistry_GetCount()
        XCTAssertEqual(count, 21,"Mock, the real cores, the stubs, the Vulkan test core, MAME, Mupen64Plus-Next and the milestone 8.x cores")

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
        XCTAssertNotNil(GagaCoreRegistry_FindByID("melonds_ds"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("flycast"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("mame"))

        // Validate tier 3 cores
        XCTAssertNotNil(GagaCoreRegistry_FindByID("azahar"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("ppsspp"))
        XCTAssertNotNil(GagaCoreRegistry_FindByID("dosbox_pure"))
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
        let size = mockInterface.pointee.state_size(inst)
        XCTAssertGreaterThan(size, 0)
        var state = [UInt8](repeating: 0, count: size)
        XCTAssertTrue(mockInterface.pointee.save_state(inst, &state, size), "Save state should succeed")
        XCTAssertTrue(mockInterface.pointee.load_state(inst, state, size, nil, 0), "Load state should succeed")
        XCTAssertFalse(mockInterface.pointee.load_state(inst, state, size - 1, nil, 0), "A short state is refused")

        mockInterface.pointee.destroy(inst)
    }

    // MARK: - Swift Wrapper Tests

    func testGagaCoreWrapperExecution() async throws {
        guard let mockInterface = MockCore_GetInterface()?.pointee else {
            XCTFail("Missing mock core interface")
            return
        }

        let wrapper = try GagaCoreWrapper(interface: mockInterface)
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

    func testMetalTextureRingAlignment() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let ring = MetalTextureRing(device: device, width: 256, height: 224, pixelFormat: .rgba8Unorm)
        XCTAssertEqual(ring.width, 256)
        XCTAssertEqual(ring.height, 224)

        // Row alignment comes from the device.
        XCTAssertEqual(ring.bytesPerRow % device.minimumLinearTextureAlignment(for: .rgba8Unorm), 0)
        XCTAssertGreaterThanOrEqual(ring.bytesPerRow, 256 * 4)

        let (_, texture, idx) = try XCTUnwrap(ring.acquireWritableBuffer())
        XCTAssertEqual(texture.width, 256)
        XCTAssertEqual(texture.height, 224)
        XCTAssertTrue(idx >= 0 && idx < 3)
    }

    func testMetalTextureRingPairsEachAcquireWithOneCompletion() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return }
        let ring = MetalTextureRing(device: device, width: 16, height: 16)

        // Nothing acquired: a draw must not signal.
        XCTAssertFalse(ring.attachCompletion(to: try XCTUnwrap(queue.makeCommandBuffer())))

        _ = ring.acquireWritableBuffer()
        let first = try XCTUnwrap(queue.makeCommandBuffer())
        XCTAssertTrue(ring.attachCompletion(to: first))
        // A repeat draw of the same frame must not signal twice.
        XCTAssertFalse(ring.attachCompletion(to: try XCTUnwrap(queue.makeCommandBuffer())))
        first.commit()
        first.waitUntilCompleted()

        // The slot came back: all three acquire without blocking.
        for _ in 0..<3 { XCTAssertNotNil(ring.acquireWritableBuffer()) }
        // All three out: the frame drops instead of blocking emulation.
        XCTAssertNil(ring.acquireWritableBuffer())
        for _ in 0..<3 { XCTAssertTrue(ring.attachCompletion(to: try XCTUnwrap(queue.makeCommandBuffer()))) }
        XCTAssertFalse(ring.attachCompletion(to: try XCTUnwrap(queue.makeCommandBuffer())))
    }

    func testGPUFloorChecksApple7() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        XCTAssertEqual(GPUFloor.supportsLayerPathCores(device), device.supportsFamily(.apple7))
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
        XCTAssertEqual(CoreCatalog.defaultCore(for: "snes"), GagaCoreRegistry_IsExcluded("bsnes") ? "" : "bsnes")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "megadrive"), "jgenesis")
        XCTAssertEqual(CoreCatalog.defaultCore(for: "arcade"), GagaCoreRegistry_IsExcluded("mame") ? "" : "mame")

        // Every registry stub resolves to a catalog row, so a saved ID always names a real core.
        for index in 0..<GagaCoreRegistry_GetCount() {
            let id = String(cString: GagaCoreRegistry_GetAtIndex(index)!.pointee.core_id)
            if id != "mock" { XCTAssertEqual(ids.contains(id), !GagaCoreRegistry_IsExcluded(id), "\(id) in CoreCatalog") }
        }
    }

    func testResolvedCoreIDHonoursDefaults() {
        var game = GameItem(id: UUID(), title: "Demo", platformID: "ps1", romPath: "/a.chd", coverPath: nil,
                            coreOverride: nil, playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "original")
        // A build without PCSX-ReARMed (GAGA_CORE_SET) falls back to the platform's other core.
        XCTAssertEqual(game.resolvedCoreID(defaults: [:]), GagaCoreRegistry_IsExcluded("pcsx_rearmed") ? "beetle_psx" : "pcsx_rearmed")
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
        XCTAssertNil(migrated.games[1].coreOverride)
        XCTAssertEqual(CoreCatalog.defaultCore(for: "snes"), GagaCoreRegistry_IsExcluded("bsnes") ? "" : "bsnes")

        // Second launch: nothing left to do.
        let reloaded = try JSONDecoder().decode(AppState.Snapshot.self, from: JSONEncoder().encode(migrated))
        XCTAssertNil(StateMigration.migrated(reloaded))
    }

    func testStateMigrationResetsRemovedShaders() throws {
        var legacy = try JSONDecoder().decode(AppState.Snapshot.self, from: Data(legacyStateJSON.utf8))
        legacy.shaderID = "crt-royale"
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
        for (legacy, current) in StateMigration.legacyCoreIDs where !GagaCoreRegistry_IsExcluded(current) {
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

    func testRomPatcherIPSRLE() throws {
        func ips(_ records: [UInt8]...) -> Data {
            var patch = Data("PATCH".utf8)
            for record in records { patch.append(contentsOf: record) }
            patch.append(Data("EOF".utf8))
            return patch
        }
        let source = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])

        // Offset 1, size 0 marks RLE, run 3, value 0xEE.
        let rle: [UInt8] = [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0xEE]
        XCTAssertEqual(try RomPatcher.apply(ips(rle), to: source), Data([0x11, 0xEE, 0xEE, 0xEE, 0x55, 0x66]))

        // RLE mixed with a normal record, applied in order.
        let normal: [UInt8] = [0x00, 0x00, 0x05, 0x00, 0x01, 0x99]
        XCTAssertEqual(try RomPatcher.apply(ips(rle, normal), to: source), Data([0x11, 0xEE, 0xEE, 0xEE, 0x55, 0x99]))

        // A run past the end grows the image.
        let grow: [UInt8] = [0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0xAB]
        XCTAssertEqual(try RomPatcher.apply(ips(grow), to: source), Data([0x11, 0x22, 0x33, 0x44, 0xAB, 0xAB, 0xAB, 0xAB]))

        // A run past a gap zero-fills the gap.
        let gap: [UInt8] = [0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x02, 0xCD]
        XCTAssertEqual(try RomPatcher.apply(ips(gap), to: source),
                       Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x00, 0x00, 0xCD, 0xCD]))

        // Source is untouched, and a cut-off RLE record throws.
        XCTAssertEqual(source, Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66]))
        var cut = Data("PATCH".utf8)
        cut.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03])
        XCTAssertThrowsError(try RomPatcher.apply(cut, to: source)) {
            XCTAssertEqual($0 as? RomPatcher.PatchError, .truncated)
        }
    }

    // MARK: - WiFi Transfer Tests

    func testPINLimiterLocksThenExhausts() {
        var limiter = PINAttemptLimiter()
        var now = Date(timeIntervalSince1970: 1000)
        let pin = "1234"

        XCTAssertEqual(limiter.check(supplied: pin, pin: pin, now: now), .allow)
        for _ in 0..<4 { XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .reject) }
        XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .locked)

        // During the lockout even the right PIN is refused, and a guess costs nothing.
        XCTAssertEqual(limiter.check(supplied: pin, pin: pin, now: now), .locked)
        now += PINAttemptLimiter.lockoutSeconds - 1
        XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .locked)

        // Lockout over. A correct PIN works and does not refund earlier failures.
        now += 1
        XCTAssertEqual(limiter.check(supplied: pin, pin: pin, now: now), .allow)
        for _ in 0..<4 { XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .reject) }
        XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .locked)

        now += PINAttemptLimiter.lockoutSeconds
        for _ in 0..<4 { XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .reject) }
        XCTAssertEqual(limiter.check(supplied: "0000", pin: pin, now: now), .exhausted)

        // Exhausted is final, whatever the clock or the PIN.
        now += 86_400
        XCTAssertEqual(limiter.check(supplied: pin, pin: pin, now: now), .exhausted)
    }

    func testPINLimiterIgnoresRequestsWithoutAPIN() {
        var limiter = PINAttemptLimiter()
        for _ in 0..<100 { XCTAssertEqual(limiter.check(supplied: "", pin: "1234"), .reject) }
        XCTAssertEqual(limiter.check(supplied: "1234", pin: "1234"), .allow)
        // A stopped server has an empty PIN, which nothing may match.
        XCTAssertEqual(limiter.check(supplied: "1234", pin: ""), .reject)
    }

    /// Runs the real listener on loopback.
    @MainActor
    func testWiFiServerTakesPINOnlyFromTheHeaderAndLocksOut() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gaga-wifi-\(UUID().uuidString)")
        let server = WiFiTransferServer(romDirectory: dir, port: 18473)
        server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(at: dir)
        }

        var pin = ""
        for _ in 0..<100 where pin.isEmpty {
            if case .running(_, _, let running) = server.state { pin = running } else {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        XCTAssertFalse(pin.isEmpty, "Listener did not start")

        let boundary = "gagaBoundary"
        let body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"game.gba\"\r\n\r\nROMDATA\r\n--\(boundary)--\r\n".utf8)
        func post(path: String, header: String?) async throws -> Int {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:18473\(path)")!)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let header { request.setValue(header, forHTTPHeaderField: "X-Gaga-Pin") }
            let (_, response) = try await URLSession(configuration: .ephemeral).upload(for: request, from: body)
            return (response as? HTTPURLResponse)?.statusCode ?? -1
        }
        let saved = dir.appendingPathComponent("game.gba")

        let inQuery = try await post(path: "/upload?pin=\(pin)", header: nil)
        XCTAssertEqual(inQuery, 401)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))

        let inHeader = try await post(path: "/upload", header: pin)
        XCTAssertEqual(inHeader, 200)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path))

        let wrong = pin == "0000" ? "1111" : "0000"
        for _ in 0..<4 {
            let status = try await post(path: "/upload", header: wrong)
            XCTAssertEqual(status, 401)
        }
        let locked = try await post(path: "/upload", header: wrong)
        XCTAssertEqual(locked, 429)
        let rightButLocked = try await post(path: "/upload", header: pin)
        XCTAssertEqual(rightButLocked, 429)
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
        XCTAssertEqual(StoreKitManager.premiumShaderIDs, ["geom-crt", "geom-crt-border", "crt-deluxe", "anime4k"])
        XCTAssertFalse(ShaderCatalog.all.contains { $0.id == "crt-royale" })
        let premium = Set(ShaderCatalog.builtIn.filter(\.premium).map(\.id))
        XCTAssertEqual(premium, StoreKitManager.premiumShaderIDs)
    }

    @MainActor
    func testOfferBadgesAndDisclosureMatchTheProduct() {
        XCTAssertNil(StoreKitManager.badge(for: .annual, intro: nil))
        XCTAssertNil(StoreKitManager.badge(for: .monthly, intro: nil))
        XCTAssertEqual(StoreKitManager.badge(for: .monthly, intro: .paid), "Introductory Offer")
        XCTAssertEqual(StoreKitManager.badge(for: .annual, intro: .freeTrial), "Free Trial")
        XCTAssertEqual(StoreKitManager.badge(for: .lifetime, intro: nil), "One payment")

        XCTAssertEqual(StoreKitManager.disclosure(for: .monthly, intro: nil), "Renews until you cancel. Cancel anytime.")
        XCTAssertEqual(StoreKitManager.disclosure(for: .annual, intro: .freeTrial),
                       "The trial is free. Renews after it ends unless you cancel. Cancel anytime.")
        XCTAssertNil(StoreKitManager.disclosure(for: .lifetime, intro: nil))
    }

    // MARK: - Design system

    /// WCAG relative luminance contrast of two sRGB hex colours.
    private func contrast(_ a: Int, _ b: Int) -> Double {
        func luminance(_ hex: Int) -> Double {
            let channels = [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { value -> Double in
                let c = Double(value) / 255
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        }
        let (high, low) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (high + 0.05) / (low + 0.05)
    }

    func testPaletteTextMeetsAA() {
        for text in [Palette.ink, Palette.muted, Palette.accent] {
            for background in [Palette.paper, Palette.surface] {
                XCTAssertGreaterThanOrEqual(contrast(text.light, background.light), 4.5)
                XCTAssertGreaterThanOrEqual(contrast(text.dark, background.dark), 4.5)
            }
        }
        XCTAssertGreaterThanOrEqual(contrast(Palette.onAccent, Palette.accentFill), 4.5)
    }

    // MARK: - BIOS folder

    func testBIOSFolderMovesIntoTheCoresSystemFolderWithoutLoss() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("bios-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let old = base.appendingPathComponent("BIOS"), system = base.appendingPathComponent("System")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        try Data("bios9".utf8).write(to: old.appendingPathComponent("bios9.bin"))
        try Data("old".utf8).write(to: old.appendingPathComponent("scph5501.bin"))
        try Data("new".utf8).write(to: system.appendingPathComponent("scph5501.bin"))

        XCTAssertEqual(GagaCoreWrapper.migrateBIOSFolder(base: base), system)
        XCTAssertEqual(try Data(contentsOf: system.appendingPathComponent("bios9.bin")), Data("bios9".utf8))
        XCTAssertEqual(try Data(contentsOf: system.appendingPathComponent("scph5501.bin")), Data("new".utf8), "not overwritten")
        XCTAssertEqual(try Data(contentsOf: old.appendingPathComponent("scph5501.bin")), Data("old".utf8), "kept, not lost")

        try FileManager.default.removeItem(at: old.appendingPathComponent("scph5501.bin"))
        GagaCoreWrapper.migrateBIOSFolder(base: base)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path), "an empty old folder goes")
        XCTAssertEqual(GagaCoreWrapper.systemDirectory.lastPathComponent, "System", "Settings lists the cores' folder")
    }

    // MARK: - Disc images

    func testDiscImagesArePlacedByContent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("discs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func platform(_ name: String, _ data: Data) throws -> String? {
            try data.write(to: dir.appendingPathComponent(name))
            return CoreCatalog.platformID(forFile: dir.appendingPathComponent(name))
        }
        func image(_ bytes: [UInt8], at offset: Int, size: Int = 40_000) -> Data {
            var data = [UInt8](repeating: 0, count: size)
            data.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
            return Data(data)
        }
        let disc = PS1TestEXE.disc()
        XCTAssertEqual(try platform("ps.bin", disc.bin), "ps1", "SYSTEM.CNF in the root")
        XCTAssertEqual(try platform("ps.cue", Data(disc.cue("ps.bin").utf8)), "ps1", "through the first FILE")
        XCTAssertEqual(try platform("ps.m3u", Data("# list\nps.cue\n".utf8)), "ps1", "through the first entry")
        XCTAssertEqual(try platform("ps.iso", image(Array("PLAYSTATION".utf8), at: 32768 + 8)), "ps1", "system ID")
        XCTAssertEqual(try platform("cd.iso", image(Array("SEGADISCSYSTEM  ".utf8), at: 0)), "megacd")
        XCTAssertEqual(try platform("cd.bin", image(Array("SEGADISCSYSTEM  ".utf8), at: 16)), "megacd", "raw sector")
        XCTAssertEqual(try platform("cd.cue", Data("FILE cd.bin BINARY\n  TRACK 01 MODE1/2352\n".utf8)), "megacd")
        XCTAssertNil(try platform("saturn.iso", image(Array("SEGA SEGASATURN ".utf8), at: 0)))
        XCTAssertEqual(try platform("pc.iso", image(Array("CD001".utf8), at: 32769)), "dos")
        XCTAssertEqual(try platform("disk.img", Data(count: 1024)), "dos")
        XCTAssertEqual(try platform("pc.bin", image(Array("CD001".utf8), at: 16 * 2352 + 17)), "dos", "ISO 9660, Mode 1")
        XCTAssertNil(try platform("blank.bin", Data(count: 1024)), "asks")
        XCTAssertNil(try platform("game.chd", Data("MComprHD".utf8)), "compressed, asks")
        XCTAssertNil(try platform("lost.cue", Data("FILE \"gone.bin\" BINARY\n".utf8)), "asks")
        XCTAssertEqual(CoreCatalog.discPlatforms.map(\.id).first, "ps1")
    }

    func testZipsArePlacedByContent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("zips-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func platform(_ name: String, _ data: Data) throws -> String? {
            try data.write(to: dir.appendingPathComponent(name))
            return CoreCatalog.platformID(forFile: dir.appendingPathComponent(name))
        }
        let text = Data("text".utf8)
        XCTAssertEqual(try platform("gridlee.zip", GridleeTestSet.build()), "arcade", "a machine in the driver list")
        XCTAssertEqual(try platform("Gridlee.zip", GridleeTestSet.zip([("readme.txt", text)])), "arcade", "by name alone")
        XCTAssertEqual(try platform("set.zip", GridleeTestSet.zip([("pacman.6e", text), ("82s123", text)])), "arcade", "ROM-like names")
        XCTAssertEqual(try platform("game.zip", GridleeTestSet.zip([("GAME.EXE", text), ("README.TXT", text)])), "dos")
        XCTAssertEqual(try platform("gridlee2.zip", GridleeTestSet.zip([("gridlee.1", text), ("dosbox.conf", text)])), "dos",
                       "a DOS file wins over ROM-like names")
        XCTAssertNil(try platform("unclear.zip", GridleeTestSet.zip([("readme.txt", text)])), "asks")
        XCTAssertNil(try platform("broken.zip", Data("PK".utf8)), "asks")
        XCTAssertEqual(CoreCatalog.unplacedPlatforms(forExtension: "ZIP")?.map(\.id), ["arcade", "dos"])
        XCTAssertEqual(CoreCatalog.platformID(forExtension: "7z"), "arcade")
    }

    @MainActor
    func testImportKeepsAnExplicitPlatformAndTestEntriesLeaveTheSavedLibrary() {
        let state = AppState()
        let saved = state.games
        let name = "upload-\(UUID().uuidString).iso"
        XCTAssertEqual(state.importROM(at: URL(fileURLWithPath: "/roms/\(name)"), platformID: "megacd")?.platformID, "megacd")
        state.games = saved
        state.save()
        XCTAssertFalse(AppState().games.contains { $0.romPath.hasSuffix(name) }, "restored on disk, not only in memory")
    }

    // MARK: - Library filter

    @MainActor
    func testRecentFilterListsOnlyPlayedGamesNewestFirst() {
        let state = AppState()
        func game(_ title: String, _ played: Date?) -> GameItem {
            GameItem(id: UUID(), title: title, platformID: "gba", romPath: "/tmp/\(title)", coverPath: nil,
                     coreOverride: nil, playTime: 0, lastPlayed: played, isFavorite: false, shaderID: "original")
        }
        state.games = [game("Old", Date(timeIntervalSince1970: 1)), game("Never", nil), game("New", Date())]
        state.platformFilter = "recent"
        XCTAssertEqual(state.filteredGames.map(\.title), ["New", "Old"])
        state.search = "old"
        XCTAssertEqual(state.filteredGames.map(\.title), ["Old"])
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
