import XCTest
@testable import GagaEmu

/// Shared steps for the group-retro backlog cores (docs/07 section 8.x), each run through the shared libretro
/// adapter and the real bridge with a generated homebrew file. `GambatteCoreTests` covers the adapter itself;
/// these check the recipe per core: picture, input, audio, battery, states, refused states and no generated code.
/// Device-pending: written and built, not yet run on the iPhone.
final class RetroCoreTestKit {
    let coreID: String
    let interface: GagaCoreInterface
    let directory: URL

    /// The last frame's bytes and the audio so far. Only touched inside `step`, which is a queue barrier.
    final class Capture {
        var pixels: [UInt8] = []
        var width = 0, height = 0, pitch = 0
        var format = GagaPixelFormat(rawValue: 99)
        var left: [Int16] = []
        var sampleRate: UInt32 = 0
        var fatal: String?

        /// 8 bits per channel, from RGB565 or XRGB8888.
        func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            if format == GAGA_PIXEL_FORMAT_RGB565 {
                let i = y * pitch + x * 2
                let v = Int(pixels[i]) | Int(pixels[i + 1]) << 8
                return ((v >> 11) << 3, ((v >> 5) & 0x3F) << 2, (v & 0x1F) << 3)
            }
            let i = y * pitch + x * 4
            return (Int(pixels[i + 2]), Int(pixels[i + 1]), Int(pixels[i]))
        }

        /// The colour at the middle of the frame.
        var centre: (r: Int, g: Int, b: Int) { rgb(x: width / 2, y: height / 2) }

        /// Distinct colours on a coarse grid, enough to tell a blank frame from a drawn one.
        var sampledColours: Int {
            var seen = Set<Int>()
            for y in stride(from: 0, to: height, by: max(1, height / 24)) {
                for x in stride(from: 0, to: width, by: max(1, width / 32)) {
                    let c = rgb(x: x, y: y)
                    seen.insert(c.r << 16 | c.g << 8 | c.b)
                }
            }
            return seen.count
        }
    }

    init(coreID: String, directory: URL) {
        self.coreID = coreID
        self.interface = GagaCoreRegistry_FindByID(coreID)!.pointee
        self.directory = directory
    }

    func makeCore(systemDirectory: String? = nil, saveDirectory: String? = nil) throws -> (GagaCoreWrapper, Capture) {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: systemDirectory ?? directory.path,
                                       saveDirectory: saveDirectory ?? directory.path)
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
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) {
                capture.left.append(packet.samples[index])
            }
        }
        core.onEvent = { event in
            if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message }
        }
        return (core, capture)
    }

    func loaded(path: String, systemDirectory: String? = nil) async throws -> (GagaCoreWrapper, Capture) {
        let (core, capture) = try makeCore(systemDirectory: systemDirectory)
        try await core.loadROM(path: path)
        return (core, capture)
    }

    func run(_ core: GagaCoreWrapper, frames: Int, buttons: UInt32 = 0, keys: [Int] = [], finger: (Int16, Int16)? = nil) {
        var input = GagaInputState()
        input.buttons = buttons
        withUnsafeMutableBytes(of: &input.keys) { bytes in
            for usage in keys { bytes[usage >> 3] |= UInt8(1 << (usage & 7)) }
        }
        if let finger {
            input.pointer_x = finger.0
            input.pointer_y = finger.1
            input.pointer_down = true
        }
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    func assertRegistry(version: String, extensions: [String], platforms: [String],
                        file: StaticString = #filePath, line: UInt = #line) throws {
        let found = try XCTUnwrap(GagaCoreRegistry_FindByID(coreID)).pointee
        XCTAssertEqual(found.abi_version, GAGA_BRIDGE_ABI_VERSION, file: file, line: line)
        XCTAssertEqual(found.capabilities, 0, "a software core uses the texture path", file: file, line: line)
        XCTAssertEqual(String(cString: found.core_version), version, file: file, line: line)
        for ext in extensions {
            XCTAssertEqual(String(cString: try XCTUnwrap(GagaCoreRegistry_FindByExtension(ext)).pointee.core_id), coreID,
                           ext, file: file, line: line)
        }
        var error = [CChar](repeating: 0, count: 64)
        XCTAssertTrue(found.self_test(&error, error.count), file: file, line: line)
        for platform in platforms {
            XCTAssertEqual(CoreCatalog.defaultCore(for: platform), coreID, platform, file: file, line: line)
        }
    }

    /// Round trip: the same input from the same state gives the same frames, byte for byte, and a refused
    /// state (another game, wrong size, damaged header) leaves the game running.
    func assertStates(romPath: String, otherROMPath: String, warmup: Int = 60, script: (Int) -> UInt32,
                      file: StaticString = #filePath, line: UInt = #line) async throws {
        let (foreign, _) = try await loaded(path: otherROMPath)
        run(foreign, frames: warmup)
        let otherGame = try foreign.saveState()
        foreign.stop()

        let (core, capture) = try await loaded(path: romPath)
        run(core, frames: warmup)
        let state = try core.saveState()
        XCTAssertEqual(Array(state.prefix(4)), Array("GLR1".utf8), file: file, line: line)
        func playback() -> [[UInt8]] {
            (0..<30).map { frame in
                run(core, frames: 1, buttons: script(frame))
                return capture.pixels
            }
        }
        let first = playback()
        try core.loadState(state)
        let second = playback()
        XCTAssertEqual(first, second, "the same input from a loaded state gives the same frames", file: file, line: line)

        try core.loadState(state)
        run(core, frames: 2)
        let before = capture.pixels
        var wrongMagic = state
        wrongMagic[0] ^= 0xFF
        let name = String(cString: interface.core_name)
        let cases: [(Data, String)] = [
            (otherGame, "This save state belongs to another game or another version of this game."),
            (wrongMagic, "This save state belongs to another game or another version of this game."),
            (state.prefix(state.count - 1), "This save state is the wrong size for \(name)."),
            (state + [0], "This save state is the wrong size for \(name)."),
            (Data(), "This save state is the wrong size for \(name)."),
        ]
        for (bad, message) in cases {
            XCTAssertThrowsError(try core.loadState(bad), file: file, line: line) {
                XCTAssertEqual($0.localizedDescription, message, file: file, line: line)
            }
        }
        XCTAssertNil(capture.fatal, file: file, line: line)
        try core.loadState(state)
        run(core, frames: 2)
        XCTAssertEqual(capture.pixels, before, "the game kept running from the same place", file: file, line: line)
        core.stop()
    }

    func assertNoGeneratedCode(romPath: String, frames: Int = 300, file: StaticString = #filePath, line: UInt = #line) async throws {
        CodeGenCheck.captureBaseline()
        let (core, capture) = try await loaded(path: romPath)
        run(core, frames: frames, buttons: UInt32(GAGA_BTN_EAST.rawValue))
        core.stop()
        XCTAssertGreaterThan(capture.width, 0, file: file, line: line)
        XCTAssertEqual(CodeGenCheck.violations(), [], file: file, line: line)
    }

    /// Peak to peak of the second half of what played, so start-up silence does not count.
    static func loudness(_ samples: [Int16]) -> Int {
        let tail = samples.dropFirst(samples.count / 2)
        guard let low = tail.min(), let high = tail.max() else { return 0 }
        return Int(high) - Int(low)
    }

    /// Zero crossings over time, for a steady square tone.
    static func hertz(_ samples: [Int16], rate: UInt32) -> Double {
        let tone = samples.dropFirst(samples.count / 2)
        guard !tone.isEmpty else { return 0 }
        let mean = tone.reduce(0) { $0 + Int($1) } / tone.count
        var crossings = 0
        var previous = tone.first! >= mean
        for sample in tone {
            let positive = Int(sample) >= mean
            if positive != previous { crossings += 1 }
            previous = positive
        }
        return Double(crossings) / 2 / (Double(tone.count) / Double(rate))
    }

    @MainActor
    func assertUploadsPick(_ cases: [(ext: String, platform: String)], file: StaticString = #filePath, line: UInt = #line) {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() } // Leaves no upload- entry in the saved Library.
        for (ext, platform) in cases {
            let name = "upload-\(UUID().uuidString).\(ext)"
            state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, platform, ext, file: file, line: line)
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), coreID, ext, file: file, line: line)
        }
    }
}
