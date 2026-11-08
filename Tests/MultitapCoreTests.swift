import XCTest
@testable import GagaEmu

/// The multiplayer adapter per core (`GagaLibretroMultitap` in each core's C file), on the generated homebrew: more
/// ports than the console's own plug it in, fewer take it out again. Each core keeps running and drawing, a state
/// saves and loads with it in, and where player 1 stays on the console's own port the game still reads player 1.
final class MultitapCoreTests: GagaTestCase {
    private var directory: URL!
    private let b = ControllerManager.Button.self

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("multitap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func step(_ core: GagaCoreWrapper, ports: Int, frames: Int, buttons: UInt32 = 0) {
        var first = GagaInputState()
        first.buttons = buttons
        let inputs = [first] + Array(repeating: GagaInputState(), count: ports - 1)
        for _ in 0..<frames { core.step(inputs: inputs) }
    }

    /// `playerOneReads`: player 1 is on the console's own port with the adapter in, so its presses change the picture.
    private func check(_ coreID: String, file name: String, _ bytes: Data, ports: Int, playerOneReads: Bool,
                       systemDirectory: String? = nil, line: UInt = #line) async throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded(coreID), "GAGA_CORE_SET left this core out")
        let path = directory.appendingPathComponent(name)
        try bytes.write(to: path)
        let kit = RetroCoreTestKit(coreID: coreID, directory: directory)
        let (core, capture) = try await kit.loaded(path: path.path, systemDirectory: systemDirectory)
        defer { core.stop() }
        step(core, ports: 1, frames: 60)

        step(core, ports: ports, frames: 30)
        let idle = capture.pixels
        if playerOneReads {
            step(core, ports: ports, frames: 10, buttons: b.south | b.start)
            XCTAssertNotEqual(capture.pixels, idle, "\(coreID): player 1 still plays with the adapter in", line: line)
            step(core, ports: ports, frames: 10)
        }
        let state = try core.saveState()
        step(core, ports: ports, frames: 5)
        try core.loadState(state)
        step(core, ports: ports, frames: 5)

        step(core, ports: 1, frames: 30)
        XCTAssertGreaterThan(capture.width, 0, "\(coreID) drew with the adapter out again", line: line)
        XCTAssertNil(capture.fatal, "\(coreID)", line: line)
    }

    func testNestopiaFourScore() async throws {
        try await check("nestopia", file: "homebrew.nes", NESTestROM.build(), ports: 4, playerOneReads: true)
    }

    func testBsnesSuperMultitap() async throws {
        try await check("bsnes", file: "homebrew.sfc", SNESTestROM.build(), ports: 5, playerOneReads: true)
    }

    func testSnes9xSuperMultitap() async throws {
        try await check("snes9x", file: "homebrew.sfc", SNESTestROM.build(), ports: 5, playerOneReads: true)
    }

    func testGenesisPlusGXTeamPlayer() async throws {
        try await check("genesis_plus_gx", file: "homebrew.md", MDTestROM.build(), ports: 5, playerOneReads: true)
    }

    func testPicodriveTeamPlayer() async throws {
        try await check("picodrive", file: "homebrew.md", MDTestROM.build(), ports: 4, playerOneReads: true)
    }

    /// Player 1 is on the tap's first socket here, so the picture is not compared.
    func testPcsxReArmedMultitap() async throws {
        try await check("pcsx_rearmed", file: "homebrew.exe", PS1TestEXE.build(), ports: 5, playerOneReads: false)
    }

    func testSwanStationMultitap() async throws {
        try await check("swanstation", file: "homebrew.exe", PS1TestEXE.build(), ports: 5, playerOneReads: false)
    }

    func testBeetleSaturnSixPlayer() async throws {
        let system = directory.appendingPathComponent("System")
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        try SaturnTestBIOS.build().write(to: system.appendingPathComponent(SaturnTestBIOS.fileName))
        let disc = SaturnTestBIOS.disc()
        try disc.bin.write(to: directory.appendingPathComponent("homebrew.bin"))
        try await check("beetle_saturn", file: "homebrew.cue", Data(disc.cue("homebrew.bin").utf8), ports: 5,
                        playerOneReads: false, systemDirectory: system.path)
    }

    /// One port, always on the five-player tap: the fifth port is read and does not stop the core.
    func testBeetlePceFastReadsFivePorts() async throws {
        try await check("beetle_pce_fast", file: "homebrew.pce", PCETestROM.build(), ports: 5, playerOneReads: false)
    }
}
