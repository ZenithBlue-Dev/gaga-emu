import XCTest
@testable import GagaEmu

/// Core options through the real bridge (GagaBridge.h `options`, `set_option`; docs/06 section 2.4). For each release
/// core: the options enumerate, a changed value is what the core reads back through GET_VARIABLE (or its own config),
/// and a value the core did not declare is refused. A few cores also show the change in their picture.
final class CoreOptionsTests: GagaTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("options-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// The option each test changes, where the first readable one would stop the test game from starting (a model that
    /// needs firmware, say). Every other core uses its first unlocked option the core reads.
    private static let chosen: [String: (key: String, value: String)] = [
        "beetle_saturn": ("beetle_saturn_autortc_lang", "german"), // A forced region refuses the stand-in disc.
    ]

    /// A game for the core and a System folder it starts with.
    @MainActor private func content(_ coreID: String) throws -> (rom: String, system: String) {
        let system = directory.appendingPathComponent("System", isDirectory: true)
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        switch coreID {
        case "vice":
            for file in C64TestROM.standInSystemFiles {
                try Data(count: file.size).write(to: system.appendingPathComponent(file.name))
            }
        case "beetle_saturn":
            try SaturnTestBIOS.build().write(to: system.appendingPathComponent(SaturnTestBIOS.fileName))
            let disc = SaturnTestBIOS.disc()
            try disc.bin.write(to: directory.appendingPathComponent("homebrew.bin"))
            let cue = directory.appendingPathComponent("homebrew.cue")
            try Data(disc.cue("homebrew.bin").utf8).write(to: cue)
            return (cue.path, system.path)
        case "beetle_psx":
            // A PS-EXE needs a Sony BIOS here; the disc boots on the OpenBIOS the core embeds.
            let disc = PS1TestEXE.disc()
            try disc.bin.write(to: directory.appendingPathComponent("homebrew.bin"))
            let cue = directory.appendingPathComponent("homebrew.cue")
            try disc.cue("homebrew.bin").write(to: cue, atomically: true, encoding: .utf8)
            return (cue.path, system.path)
        default: break
        }
        let platforms = ["atari800": "atari8bit", "gambatte": "gb", "swanstation": "ps1", "jgenesis": "megadrive"]
        guard let platform = platforms[coreID] ?? CoreCatalog.platforms.first(where: { $0.cores.contains { $0.id == coreID } })?.id else {
            throw XCTSkip("\(coreID) runs no platform in this build")
        }
        return (try BenchmarkRun.writeTestROM(platformID: platform, to: directory).path, system.path)
    }

    private func makeCore(_ coreID: String, system: String) throws -> GagaCoreWrapper {
        try GagaCoreWrapper(interface: GagaCoreRegistry_FindByID(coreID)!.pointee, systemDirectory: system, saveDirectory: directory.path)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int) {
        for _ in 0..<frames { core.step(inputs: [GagaInputState()]) }
    }

    /// Enumerate, change, read back, refuse. Prints one `[core-options]` line for the report.
    private func checkCore(_ coreID: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded(coreID), "GAGA_CORE_SET left this core out")
        let interface = GagaCoreRegistry_FindByID(coreID)!.pointee
        XCTAssertNotNil(interface.options, "\(coreID) has no options entry point", file: file, line: line)
        XCTAssertNotNil(interface.set_option, file: file, line: line)
        let probed = GagaCoreWrapper.probeOptions(interface)
        let (rom, system) = try await content(coreID)

        // A game with no player values: what the core declares and reads.
        var first: CoreOptionSet?
        do {
            let core = try makeCore(coreID, system: system)
            try await core.loadROM(path: rom)
            run(core, frames: 10)
            first = core.options()
            core.stop()
        }
        let declared = try XCTUnwrap(first ?? probed, "\(coreID) declares no options", file: file, line: line)
        XCTAssertGreaterThan(declared.options.count, 0, file: file, line: line)
        for option in declared.options where !option.locked {
            XCTAssertFalse(option.values.isEmpty, "\(coreID) \(option.key) has no values", file: file, line: line)
        }

        // The option to change: the override, else the first unlocked one the core read with a second value.
        let pick: (option: CoreOptionSet.Option, value: String)
        if let forced = Self.chosen[coreID], let option = declared.option(forced.key) {
            pick = (option, forced.value)
        } else {
            let option = try XCTUnwrap(declared.options.first { !$0.locked && $0.values.count > 1 && $0.served != nil },
                                       "\(coreID) read none of its unlocked options", file: file, line: line)
            pick = (option, option.values.first { $0.value != option.served }!.value)
        }

        // A new game with the player's value set before it loads: the core reads that value.
        let core = try makeCore(coreID, system: system)
        XCTAssertTrue(core.setOption(pick.option.key, pick.value), "\(coreID) refused \(pick.option.key)=\(pick.value)", file: file, line: line)
        if let locked = declared.options.first(where: \.locked), let any = locked.values.first?.value {
            XCTAssertFalse(core.setOption(locked.key, any), "\(coreID) let the player change locked \(locked.key)", file: file, line: line)
        }
        try await core.loadROM(path: rom)
        run(core, frames: 10)
        // Checked once the game runs: a core that declares in retro_init has no list to check against before.
        XCTAssertFalse(core.setOption(pick.option.key, "gaga-not-a-value"), "\(coreID) took an undeclared value", file: file, line: line)
        let after = try XCTUnwrap(core.options()?.option(pick.option.key), file: file, line: line)
        XCTAssertEqual(after.value, pick.value, file: file, line: line)
        XCTAssertEqual(after.served, pick.value, "\(coreID) did not read \(pick.option.key) back", file: file, line: line)

        // Back to the default while the game runs: live when the core reads it within half a second of play.
        let back = pick.option.served ?? pick.option.default
        XCTAssertTrue(core.setOption(pick.option.key, nil), file: file, line: line)
        run(core, frames: 30)
        let live = core.options()?.option(pick.option.key)?.served == back
        core.stop()

        let locked = declared.options.filter(\.locked).count
        print("[core-options] \(coreID) options=\(declared.options.count) probe=\(probed?.options.count ?? 0) locked=\(locked) "
              + "categories=\(declared.categories.count) changed=\(pick.option.key) live=\(live)")
    }

    func testAtari800() async throws { try await checkCore("atari800") }
    func testAzahar() async throws { try await checkCore("azahar") }
    func testBeetleNgp() async throws { try await checkCore("beetle_ngp") }
    func testBeetlePceFast() async throws { try await checkCore("beetle_pce_fast") }
    func testBeetlePsx() async throws { try await checkCore("beetle_psx") }
    func testBeetleSaturn() async throws { try await checkCore("beetle_saturn") }
    func testBeetleSupergrafx() async throws { try await checkCore("beetle_supergrafx") }
    func testBeetleVb() async throws { try await checkCore("beetle_vb") }
    func testBeetleWswan() async throws { try await checkCore("beetle_wswan") }
    func testBsnes() async throws { try await checkCore("bsnes") }
    func testDosboxPure() async throws { try await checkCore("dosbox_pure") }
    func testFlycast() async throws { try await checkCore("flycast") }
    func testGambatte() async throws { try await checkCore("gambatte") }
    func testGearsystem() async throws { try await checkCore("gearsystem") }
    func testHandy() async throws { try await checkCore("handy") }
    func testJgenesis() async throws { try await checkCore("jgenesis") }
    func testMame() async throws { try await checkCore("mame") }
    func testMelonDS() async throws { try await checkCore("melonds_ds") }
    func testMgba() async throws { try await checkCore("mgba") }
    func testMupen64PlusNext() async throws { try await checkCore("mupen64plus_next") }
    func testNestopia() async throws { try await checkCore("nestopia") }
    func testPcsxReArmed() async throws { try await checkCore("pcsx_rearmed") }
    func testPokeMini() async throws { try await checkCore("pokemini") }
    func testPpsspp() async throws { try await checkCore("ppsspp") }
    func testPrboom() async throws { try await checkCore("prboom") }
    func testProSystem() async throws { try await checkCore("prosystem") }
    func testPuae() async throws { try await checkCore("puae") }
    func testStella() async throws { try await checkCore("stella") }
    func testSwanStation() async throws { try await checkCore("swanstation") }
    func testVice() async throws { try await checkCore("vice") }
    func testVirtualJaguar() async throws { try await checkCore("virtualjaguar") }

    // MARK: - The picture changes

    /// FNV-1a over the last frame's bytes.
    private func frameHash(_ coreID: String, options: [String: String], frames: Int = 60) async throws -> UInt64 {
        let (rom, system) = try await content(coreID)
        let core = try makeCore(coreID, system: system)
        var hash: UInt64 = 0
        core.onVideoFrame = { frame in
            guard let bytes = frame.pixelData else { return }
            hash = 0xcbf29ce484222325
            for byte in UnsafeRawBufferPointer(start: bytes, count: frame.pitch * frame.height) { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        }
        for (key, value) in options { XCTAssertTrue(core.setOption(key, value), "\(coreID) refused \(key)=\(value)") }
        try await core.loadROM(path: rom)
        run(core, frames: frames)
        core.stop()
        return hash
    }

    private func assertPictureChanges(_ coreID: String, _ options: [String: String]) async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded(coreID), "GAGA_CORE_SET left this core out")
        let plain = try await frameHash(coreID, options: [:])
        let changed = try await frameHash(coreID, options: options)
        XCTAssertNotEqual(plain, 0, "\(coreID) drew nothing")
        XCTAssertNotEqual(plain, changed, "\(coreID) drew the same picture with \(options)")
    }

    func testNestopiaPaletteChangesThePicture() async throws {
        try await assertPictureChanges("nestopia", ["nestopia_palette": "consumer"])
    }

    func testGambatteColourisationChangesThePicture() async throws {
        try await assertPictureChanges("gambatte", ["gambatte_gb_colorization": "internal"])
    }

    /// The test cartridge's colours sit on steps both scales share, so its layers are what changes.
    func testJgenesisLayersChangeThePicture() async throws {
        try await assertPictureChanges("jgenesis", ["plane_a_enabled": "off", "plane_b_enabled": "off", "sprites_enabled": "off", "window_enabled": "off"])
    }

    /// JGenesis takes most of its settings in a running game: the next frame already has the new colours.
    func testJgenesisChangesLive() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("jgenesis"), "GAGA_CORE_SET left this core out")
        let (rom, system) = try await content("jgenesis")
        let core = try makeCore("jgenesis", system: system)
        try await core.loadROM(path: rom)
        run(core, frames: 2)
        XCTAssertEqual(core.options()?.option("non_linear_color_scale")?.served, "on")
        XCTAssertTrue(core.setOption("non_linear_color_scale", "off"))
        XCTAssertEqual(core.options()?.option("non_linear_color_scale")?.served, "off")
        XCTAssertTrue(core.setOption("region", "japan"))
        XCTAssertEqual(core.options()?.option("region")?.served, "auto", "Region applies only to a new machine")
        XCTAssertEqual(core.options()?.option("region")?.restart, true)
        core.stop()
    }

    // MARK: - Store

    @MainActor
    func testStoreKeepsOnlyDeclaredValuesAndGameValuesWin() throws {
        let store = CoreOptionsStore(url: directory.appendingPathComponent("CoreOptions.json"),
                                     cacheFolder: directory.appendingPathComponent("Declarations"))
        let json = """
        {"categories":[],"options":[
         {"key":"pal","label":"Palette","info":null,"category":null,"default":"a","value":null,"served":null,"visible":true,"locked":false,
          "values":[{"value":"a","label":"A"},{"value":"b","label":"B"}]},
         {"key":"cpu_dyna","label":"CPU","info":null,"category":null,"default":"off","value":null,"served":null,"visible":true,"locked":true,
          "values":[{"value":"off","label":"Off"},{"value":"on","label":"On"}]}]}
        """
        let set = try XCTUnwrap(json.withCString { CoreOptionSet.decode($0) })
        store.remember(set, coreID: "test")
        let palette = try XCTUnwrap(set.option("pal")), cpu = try XCTUnwrap(set.option("cpu_dyna"))
        XCTAssertFalse(store.set("c", for: palette, coreID: "test", gameID: nil), "an undeclared value")
        XCTAssertFalse(store.set("on", for: cpu, coreID: "test", gameID: nil), "a locked option")
        XCTAssertTrue(store.set("b", for: palette, coreID: "test", gameID: nil))
        let game = UUID()
        XCTAssertEqual(store.values(coreID: "test", gameID: game), ["pal": "b"])
        XCTAssertTrue(store.set("a", for: palette, coreID: "test", gameID: game))
        XCTAssertEqual(store.values(coreID: "test", gameID: game), ["pal": "a"])
        XCTAssertEqual(store.values(coreID: "test", gameID: nil), ["pal": "b"])

        // Read back from disk, as at the next launch.
        let again = CoreOptionsStore(url: directory.appendingPathComponent("CoreOptions.json"),
                                     cacheFolder: directory.appendingPathComponent("Declarations"))
        XCTAssertEqual(again.values(coreID: "test", gameID: game), ["pal": "a"])
        XCTAssertEqual(again.declaration(coreID: "test")?.options.count, 2)
        again.reset(coreID: "test", gameID: game)
        XCTAssertEqual(again.values(coreID: "test", gameID: game), ["pal": "b"])
    }

    /// The CPU core and renderer are GagaEmu's: the player cannot pick a JIT or another graphics path.
    func testCPUAndRendererOptionsAreLocked() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("ppsspp"), "GAGA_CORE_SET left this core out")
        let set = try XCTUnwrap(GagaCoreWrapper.probeOptions(GagaCoreRegistry_FindByID("ppsspp")!.pointee))
        let cpu = try XCTUnwrap(set.option("ppsspp_cpu_core"))
        XCTAssertTrue(cpu.locked)
        for option in set.options where option.key.contains("backend") || option.key.contains("renderer") {
            XCTAssertTrue(option.locked, option.key)
        }
    }

    // MARK: - Player name

    func testPlayerNameIsSanitised() {
        XCTAssertEqual(PlayerName.sanitized(""), "GagaEmu")
        XCTAssertEqual(PlayerName.sanitized("🎮🎮🎮🎮"), "GagaEmu")
        XCTAssertEqual(PlayerName.sanitized("ab"), "GagaEmu")
        XCTAssertEqual(PlayerName.sanitized("Ab c"), "Abc")
        XCTAssertEqual(PlayerName.sanitized("Zoë_the-1st"), "Zo_the-1st")
        XCTAssertEqual(PlayerName.sanitized("a\"b;c%00d/../e"), "abc00de")
        XCTAssertEqual(PlayerName.sanitized(String(repeating: "x", count: 40)), String(repeating: "x", count: 16))
    }

    /// RETRO_ENVIRONMENT_GET_USERNAME: melonDS DS writes the name it is given into the DS firmware, which direct boot
    /// copies to main RAM at 0x027FFC80 (nickname, UTF-16, at +6; length at +0x1A).
    func testMelonDSTakesThePlayerName() async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("melonds_ds"), "GAGA_CORE_SET left this core out")
        let (rom, system) = try await content("melonds_ds")
        let previous = getenv("GAGA_USERNAME").map { String(cString: $0) }
        defer { if let previous { setenv("GAGA_USERNAME", previous, 1) } else { unsetenv("GAGA_USERNAME") } }
        setenv("GAGA_USERNAME", "Tester_9", 1)
        let core = try makeCore("melonds_ds", system: system)
        try await core.loadROM(path: rom)
        run(core, frames: 10)
        let ram = try XCTUnwrap(core.memoryForTest(region: 2), "melonDS DS exposes no system RAM")
        core.stop()
        let base = 0x027F_FC80 % ram.count
        let length = Int(ram[base + 0x1A])
        let units = (0..<length).map { UInt16(ram[base + 6 + 2 * $0]) | UInt16(ram[base + 7 + 2 * $0]) << 8 }
        XCTAssertEqual(String(decoding: units, as: UTF16.self), "Tester_9")
    }
}
