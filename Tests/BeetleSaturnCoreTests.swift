import XCTest
@testable import GagaEmu

/// Beetle Saturn through the shared libretro adapter and the real bridge. No Sega BIOS ships, so most tests
/// cover what a player without one sees. The rest run GagaEmu's own stand-in system ROM (`SaturnTestBIOS`),
/// written to a temporary system folder: it proves the SH-2, VDP2, backup RAM, save states and teardown on
/// generated data only. Input, sound and cheats need a real BIOS and game, so they are checked by hand.
/// Device-pending: built for the iPhone, not yet run there. A macOS build of the same sources passed these
/// checks.
final class BeetleSaturnCoreTests: GagaTestCase {
    private var directory: URL!
    private var system: URL!
    private var cuePath: String!
    private let interface = GagaCoreRegistry_FindByID("beetle_saturn")!.pointee
    private static let headerSize = 16 // The adapter's own state header, before Mednafen's "MDFNSVST".
    private static let missingBIOS = "This Saturn game needs a Saturn BIOS file (mpr-17933.bin or sega_101.bin). GagaEmu does not include one."

    override func setUpWithError() throws {
        try XCTSkipIf(GagaCoreRegistry_IsExcluded("beetle_saturn"), "GAGA_CORE_SET left this core out")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("saturn-\(UUID().uuidString)")
        system = directory.appendingPathComponent("System")
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        cuePath = try writeDisc(named: "homebrew").path
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func writeDisc(named name: String) throws -> URL {
        let disc = SaturnTestBIOS.disc()
        try disc.bin.write(to: directory.appendingPathComponent("\(name).bin"))
        let cue = directory.appendingPathComponent("\(name).cue")
        try Data(disc.cue("\(name).bin").utf8).write(to: cue)
        return cue
    }

    private func addStandInBIOS() throws {
        try SaturnTestBIOS.build().write(to: system.appendingPathComponent(SaturnTestBIOS.fileName))
    }

    /// The last frame's bytes and the audio so far. Only touched inside `step`, which is a queue barrier.
    private final class Capture {
        var pixels: [UInt8] = []
        var width = 0
        var height = 0
        var pitch = 0
        var format = GagaPixelFormat(rawValue: 99)
        var audioFrames = 0
        var nonZero = 0
        var sampleRate: UInt32 = 0
        var channels: UInt8 = 0
        var fatal: String?

        /// XRGB8888, little endian.
        func rgb(x: Int, y: Int) -> [UInt8] {
            let i = y * pitch + x * 4
            return [pixels[i + 2], pixels[i + 1], pixels[i]]
        }
    }

    private func makeCore(saveDirectory: String? = nil) throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: system.path, saveDirectory: saveDirectory ?? directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            capture.width = frame.width
            capture.height = frame.height
            capture.pitch = frame.pitch
            capture.format = frame.pixelFormat
            guard let bytes = frame.pixelData else { return }
            capture.pixels = Array(UnsafeRawBufferPointer(start: bytes, count: frame.pitch * frame.height))
        }
        core.onAudioPacket = { packet in
            capture.sampleRate = packet.sampleRate
            capture.channels = packet.channels
            capture.audioFrames += packet.samples.count / max(Int(packet.channels), 1)
            capture.nonZero += packet.samples.filter { $0 != 0 }.count
        }
        core.onEvent = { event in
            if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message }
        }
        return (core, capture)
    }

    private func loaded(path: String? = nil) async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore()
        try await core.loadROM(path: path ?? cuePath)
        return (core, capture)
    }

    private func run(_ core: GagaCoreWrapper, frames: Int) {
        for _ in 0..<frames { core.step(inputs: [GagaInputState()]) }
    }

    private func assertRefused(_ path: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let (core, _) = try makeCore()
        do {
            try await core.loadROM(path: path)
            XCTFail("loaded \(path)", file: file, line: line)
        } catch {
            XCTAssertEqual(error.localizedDescription, message, file: file, line: line)
        }
        core.stop()
    }

    /// Every pixel of the 320 by 224 picture is the back colour; Mednafen pads the line to 330 with black.
    private func assertBackColour(_ capture: Capture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(capture.format, GAGA_PIXEL_FORMAT_XRGB8888, file: file, line: line)
        guard capture.width >= 320, capture.height == 224 else {
            return XCTFail("frame is \(capture.width) by \(capture.height)", file: file, line: line)
        }
        var back = 0, other: Set<[UInt8]> = []
        for y in 0..<capture.height {
            for x in 0..<capture.width {
                let rgb = capture.rgb(x: x, y: y)
                if rgb == SaturnTestBIOS.backRGB { back += 1 } else { other.insert(rgb) }
            }
        }
        XCTAssertEqual(back, 320 * 224, "back colour pixels", file: file, line: line)
        XCTAssertTrue(other.isSubset(of: [[0, 0, 0]]), "only black padding besides: \(other)", file: file, line: line)
    }

    // MARK: - Core

    func testRegistryResolvesTheRealCore() throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID("beetle_saturn")).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION)
        XCTAssertEqual(String(cString: found.core_version), "1.32.1 30f4c120")
        XCTAssertEqual(found.native_sample_rate, 44100)
        XCTAssertEqual(found.target_fps, 59.8265, accuracy: 0.001)
        XCTAssertEqual(found.capabilities, 0, "texture path")
        XCTAssertNil(found.attach_metal_layer)
        XCTAssertNil(found.detach_metal_layer)
        XCTAssertNil(found.read_layer_pixels)
        XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension("ccd")).pointee.core_id), "beetle_saturn")
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count))
        XCTAssertEqual(CoreCatalog.defaultCore(for: "saturn"), "beetle_saturn")
    }

    // MARK: - Without a BIOS

    func testADiscWithoutABIOSSaysWhatIsMissing() async throws {
        try await assertRefused(cuePath, Self.missingBIOS)
        // A file of the right name but not 512 KiB is no BIOS either.
        try Data(repeating: 0, count: 16).write(to: system.appendingPathComponent("mpr-17933.bin"))
        try Data(repeating: 0, count: 256 * 1024).write(to: system.appendingPathComponent("sega_101.bin"))
        try await assertRefused(cuePath, Self.missingBIOS)
        let left = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(Set(left), ["System", "homebrew.bin", "homebrew.cue"], "a refused game must not leave a save behind")
    }

    func testATrackFileIsRefusedWithWhatToOpen() async throws {
        try addStandInBIOS()
        let message = "Open this Saturn disc's .cue, .ccd, .chd, .toc or .m3u file. Beetle Saturn cannot start a disc from its track file."
        try await assertRefused(directory.appendingPathComponent("homebrew.bin").path, message)
        let iso = directory.appendingPathComponent("homebrew.iso")
        try SaturnTestBIOS.disc().bin.write(to: iso)
        try await assertRefused(iso.path, message)
    }

    func testTheBIOSFilesScreenListsTheSaturnNames() {
        let names = BIOSManagerView.required.map(\.0)
        XCTAssertTrue(names.contains("mpr-17933.bin"))
        XCTAssertTrue(names.contains("sega_101.bin"))
    }

    func testASaturnDiscIsImportedAsSaturn() throws {
        XCTAssertEqual(CoreCatalog.platformID(forFile: URL(fileURLWithPath: cuePath)), "saturn")
        XCTAssertEqual(CoreCatalog.platformID(forFile: directory.appendingPathComponent("homebrew.bin")), "saturn")
        XCTAssertTrue(CoreCatalog.discPlatforms.map(\.id).contains("saturn"))
    }

    func testAnUnwritableSaveFolderRefusesToRun() async throws {
        try addStandInBIOS()
        let (core, _) = try makeCore(saveDirectory: "/nonexistent/saves")
        do {
            try await core.loadROM(path: cuePath)
            XCTFail("loaded with no way to save")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The save file for this game could not be opened.")
        }
        core.stop()
    }

    // MARK: - On the stand-in BIOS

    func testTheStandInBIOSDrawsItsBackColour() async throws {
        try addStandInBIOS()
        let (core, capture) = try await loaded()
        run(core, frames: 30)
        assertBackColour(capture)
        XCTAssertNil(capture.fatal)
        XCTAssertEqual(capture.sampleRate, 44100)
        XCTAssertEqual(capture.channels, 2)
        XCTAssertEqual(Double(capture.audioFrames), 30 * 44100 / 59.8265, accuracy: 800, "a frame's worth of audio per frame")
        core.stop()
    }

    func testBackupRAMReachesItsFileAndSurvivesARestart() async throws {
        try addStandInBIOS()
        let save = directory.appendingPathComponent("homebrew.sav")
        // With no save yet, Mednafen formats backup RAM, which starts with "BackUpRam Format". The program adds
        // one to its first byte at each boot.
        for boot in 1...3 {
            let (core, _) = try await loaded()
            run(core, frames: 10)
            core.flushBatterySave()
            let flushed = [UInt8](try Data(contentsOf: save))
            XCTAssertEqual(flushed.count, SaturnTestBIOS.backupSize)
            XCTAssertEqual(Int(flushed[0]), Int(UInt8(ascii: "B")) + boot, "on disk when the flush returns")
            XCTAssertEqual(Array(flushed[1..<16]), Array("ackUpRam Format".utf8))
            core.stop()
            XCTAssertEqual(Int((try Data(contentsOf: save))[0]), Int(UInt8(ascii: "B")) + boot)
        }
        for name in ["homebrew.bcr", "homebrew.smpc"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path),
                          "\(name), which the core writes itself, is per game in the save folder")
        }
    }

    func testStateVersionIsTheOneInTheCoresBytes() async throws {
        try addStandInBIOS()
        let (core, _) = try await loaded()
        run(core, frames: 2)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8))
        XCTAssertEqual(Array(state[Self.headerSize..<(Self.headerSize + 8)]), Array("MDFNSVST".utf8))
        let version = (0..<4).reduce(UInt32(0)) { $0 | UInt32(state[Self.headerSize + 16 + $1]) << ($1 * 8) }
        XCTAssertEqual(version, core.stateVersion)
        core.stop()
    }

    func testRoundTripRestoresBackupRAM() async throws {
        try addStandInBIOS()
        let save = directory.appendingPathComponent("homebrew.sav")
        let (core, capture) = try await loaded()
        run(core, frames: 10)
        let state = try core.saveState()
        run(core, frames: 10)
        try core.loadState(state)
        run(core, frames: 10)
        assertBackColour(capture)
        XCTAssertNil(capture.fatal)
        core.flushBatterySave()
        XCTAssertEqual(Int((try Data(contentsOf: save))[0]), Int(UInt8(ascii: "B")) + 1, "the state's backup RAM, booted once")
        XCTAssertEqual(try core.saveState().count, state.count)
        core.stop()
    }

    func testRefusedStatesLeaveTheGameRunning() async throws {
        try addStandInBIOS()
        let other = try writeDisc(named: "other")
        let (foreign, _) = try await loaded(path: other.path)
        run(foreign, frames: 2)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded()
        run(core, frames: 10)
        let state = try core.saveState()

        let wrongSize = "This save state is the wrong size for Beetle Saturn."
        let otherOwner = "This save state belongs to another game or another version of this game."
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        var tooOld = state // Past the adapter's checks: Mednafen refuses versions below 0x900.
        tooOld.replaceSubrange((Self.headerSize + 16)..<(Self.headerSize + 20), with: [0, 1, 0, 0])
        var noMagic = state
        noMagic[Self.headerSize] ^= 0xFF
        let cases: [(Data, String)] = [
            (otherGame, otherOwner),
            (wrongMagic, otherOwner),
            (state.prefix(state.count - 1), wrongSize),
            (state + [0], wrongSize),
            (Data(), wrongSize),
            (tooOld, "Beetle Saturn could not load this save state."),
            (noMagic, "Beetle Saturn could not load this save state."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad)) {
                XCTAssertEqual($0.localizedDescription, message)
            }
            run(core, frames: 3)
            XCTAssertNil(capture.fatal)
            assertBackColour(capture)
        }
        core.stop()
    }

    func testCheatCodesAreCheckedBeforeTheCoreSeesThem() async throws {
        try addStandInBIOS()
        let (core, capture) = try await loaded()
        run(core, frames: 2)
        try core.addCheat(id: 1, code: "16060000 FFFF", enabled: true) // Pro Action Replay, 16-bit work RAM write.
        for bad in ["nonsense", "1606000 FFFF", "16060000 FFFFF", "16060000-FFFF"] {
            XCTAssertThrowsError(try core.addCheat(id: 3, code: bad, enabled: true)) {
                XCTAssertEqual($0.localizedDescription, "Beetle Saturn does not recognise this code: \(bad)")
            }
        }
        run(core, frames: 3)
        XCTAssertNil(capture.fatal)
        core.stop()
    }

    func testASecondSessionStartsAfterTheFirst() async throws {
        try addStandInBIOS()
        for _ in 0..<3 {
            let (core, capture) = try await loaded()
            run(core, frames: 5)
            assertBackColour(capture)
            core.stop()
        }
    }
}
