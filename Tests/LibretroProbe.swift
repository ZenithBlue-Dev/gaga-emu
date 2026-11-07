import XCTest
@testable import GagaEmu

/// One libretro core through the real bridge, for the handheld and console cores of docs/07 milestone 8.x.
/// Their test programs are checked by what changes on screen, not by exact pixels: the cores crop and scale
/// differently, and a changed picture is what each recipe test needs to prove.
final class LibretroProbe {
    let interface: GagaCoreInterface
    let directory: URL
    let romPath: String
    var savePath: String { (romPath as NSString).deletingPathExtension + ".sav" }

    private(set) var core: GagaCoreWrapper!
    /// Touched only inside `step`, which is a queue barrier.
    private final class Capture {
        var pixels: [UInt8] = []
        var width = 0, height = 0, pitch = 0
        var format = GAGA_PIXEL_FORMAT_RGB565
        var left: [Int16] = []
        var fatal: String?
    }
    private var capture = Capture()

    init(coreID: String, rom: Data, name: String) throws {
        interface = try XCTUnwrap(GagaCoreRegistry_FindByID(coreID)).pointee
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("\(coreID)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try rom.write(to: url)
        romPath = url.path
    }

    func cleanUp() {
        core?.stop()
        try? FileManager.default.removeItem(at: directory)
    }

    func write(_ data: Data, name: String) throws -> String {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    func makeCore() throws -> GagaCoreWrapper {
        let core = try GagaCoreWrapper(interface: interface, systemDirectory: directory.path, saveDirectory: directory.path)
        let capture = Capture()
        core.onVideoFrame = { frame in
            guard let bytes = frame.pixelData else { return }
            capture.width = frame.width
            capture.height = frame.height
            capture.pitch = frame.pitch
            capture.format = frame.pixelFormat
            capture.pixels = Array(UnsafeRawBufferPointer(start: bytes, count: frame.pitch * frame.height))
        }
        core.onAudioPacket = { packet in
            for index in stride(from: 0, to: packet.samples.count, by: Int(packet.channels)) { capture.left.append(packet.samples[index]) }
        }
        core.onEvent = { event in if event.severity == GAGA_EVENT_FATAL { capture.fatal = event.message } }
        self.capture = capture
        self.core = core
        return core
    }

    /// Stops any earlier core first: a libretro framework has one live instance.
    func load(path: String? = nil) async throws {
        core?.stop()
        try await makeCore().loadROM(path: path ?? romPath)
    }

    func stop() {
        core?.stop()
        core = nil
    }

    func run(_ frames: Int, buttons: GagaButtonMask...) {
        var input = GagaInputState()
        input.buttons = buttons.reduce(0) { $0 | $1.rawValue }
        for _ in 0..<frames { core.step(inputs: [input]) }
    }

    var size: (width: Int, height: Int) { (capture.width, capture.height) }
    var fatal: String? { capture.fatal }
    var samples: [Int16] { capture.left }

    private func rgb(_ x: Int, _ y: Int) -> UInt32 {
        let row = y * capture.pitch
        if capture.format == GAGA_PIXEL_FORMAT_RGB565 {
            let value = UInt32(capture.pixels[row + x * 2]) | UInt32(capture.pixels[row + x * 2 + 1]) << 8
            return value
        }
        let i = row + x * 4
        return UInt32(capture.pixels[i]) | UInt32(capture.pixels[i + 1]) << 8 | UInt32(capture.pixels[i + 2]) << 16
    }

    /// FNV-1a over the visible pixels, so padding past the width never counts.
    var frameHash: UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for y in 0..<capture.height {
            for x in 0..<capture.width { hash = (hash ^ UInt64(rgb(x, y))) &* 0x100000001b3 }
        }
        return hash
    }

    var colourCount: Int {
        var seen = Set<UInt32>()
        for y in stride(from: 0, to: capture.height, by: 2) {
            for x in stride(from: 0, to: capture.width, by: 2) { seen.insert(rgb(x, y)) }
        }
        return seen.count
    }

    /// The battery file's bytes, as on disk now.
    func battery() throws -> [UInt8] { [UInt8](try Data(contentsOf: URL(fileURLWithPath: savePath))) }

    // MARK: - Shared recipe checks

    /// Each button changes the picture while held, and letting go puts it back.
    func assertEachButtonChangesThePicture(_ buttons: [GagaButtonMask], settle: Int = 3,
                                           file: StaticString = #filePath, line: UInt = #line) {
        run(settle)
        let idle = frameHash
        for button in buttons {
            run(settle, buttons: button)
            XCTAssertNotEqual(frameHash, idle, "button \(button.rawValue) changed nothing", file: file, line: line)
            run(settle)
            XCTAssertEqual(frameHash, idle, "button \(button.rawValue) left the picture changed", file: file, line: line)
        }
    }

    func assertAudioIsNotSilent(frames: Int = 60, file: StaticString = #filePath, line: UInt = #line) {
        run(frames)
        let tone = samples.dropFirst(samples.count / 2)
        XCTAssertGreaterThan(tone.count, 0, "no audio", file: file, line: line)
        XCTAssertGreaterThan(Int(tone.max() ?? 0) - Int(tone.min() ?? 0), 1000, "silent", file: file, line: line)
    }

    /// The program counts its boots in battery RAM. The count on disk after each flush is the boot number.
    func assertBootCounterSurvivesRestarts(magic: [UInt8], magicOffset: Int, counterOffset: Int, frames: Int = 10,
                                           file: StaticString = #filePath, line: UInt = #line) async throws {
        for boot in 1...3 {
            try await load()
            run(frames)
            core.flushBatterySave()
            let bytes = try battery()
            XCTAssertEqual(Array(bytes[magicOffset..<(magicOffset + magic.count)]), magic, file: file, line: line)
            XCTAssertEqual(Int(bytes[counterOffset]), boot, "on disk when the flush returns", file: file, line: line)
            stop()
        }
    }

    /// `chord` flips a flag the program keeps in RAM. A state taken with it on loads back with it on, and a
    /// refused state leaves the game running as it was.
    func assertStateRoundTripAndRefusal(chord: [GagaButtonMask], file: StaticString = #filePath, line: UInt = #line) throws {
        func flip() {
            var input = GagaInputState()
            input.buttons = chord.reduce(0) { $0 | $1.rawValue }
            for _ in 0..<2 { core.step(inputs: [input]) }
            run(3)
        }
        run(4)
        let before = frameHash
        flip()
        let flipped = frameHash
        XCTAssertNotEqual(flipped, before, "the chord flipped nothing", file: file, line: line)
        let state = try core.saveState()
        flip()
        XCTAssertEqual(frameHash, before, "the second flip did not undo the first", file: file, line: line)
        try core.loadState(state)
        run(2)
        XCTAssertEqual(frameHash, flipped, "the state did not restore the flag", file: file, line: line)
        XCTAssertThrowsError(try core.loadState(Data(repeating: 0, count: 3)), file: file, line: line)
        var otherGame = state
        otherGame[8] ^= 0xFF // The adapter's ROM hash.
        XCTAssertThrowsError(try core.loadState(otherGame), file: file, line: line)
        run(2)
        XCTAssertEqual(frameHash, flipped, "a refused state changed the game", file: file, line: line)
        XCTAssertNil(fatal, file: file, line: line)
    }

    /// A RAM code the program clears every frame shows only while it is on.
    func assertCheatHasItsEffectAndStops(_ code: String, refused: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        run(4)
        let idle = frameHash
        try core.addCheat(id: 1, code: code, enabled: true)
        run(3)
        XCTAssertNotEqual(frameHash, idle, "the code had no effect", file: file, line: line)
        core.setCheat(id: 1, enabled: false)
        run(3)
        XCTAssertEqual(frameHash, idle, "the code kept its effect after it was turned off", file: file, line: line)
        for (index, bad) in refused.enumerated() {
            XCTAssertThrowsError(try core.addCheat(id: UInt32(10 + index), code: bad, enabled: true), bad, file: file, line: line)
        }
    }

    /// The Mednafen state format starts with its own header, whose version field is the interface's.
    func assertMednafenStateVersion(file: StaticString = #filePath, line: UInt = #line) throws {
        let state = [UInt8](try core.saveState())
        let header = 16 // The adapter's.
        XCTAssertEqual(Array(state[header..<(header + 16)]), Array("MEDNAFENSVESTATE".utf8), file: file, line: line)
        let version = state[(header + 16)..<(header + 20)].reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        XCTAssertEqual(version, interface.state_version, file: file, line: line)
    }

    func assertNoGeneratedCode(buttons: GagaButtonMask, file: StaticString = #filePath, line: UInt = #line) async throws {
        CodeGenCheck.captureBaseline()
        try await load()
        run(240, buttons: buttons)
        stop()
        XCTAssertEqual(CodeGenCheck.violations(), [], file: file, line: line)
    }

    /// Each file is refused with `message`, and leaves no battery file behind.
    func assertRefused(_ files: [(name: String, data: Data)], message: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        for bad in files {
            let path = try write(bad.data, name: bad.name)
            do {
                try await load(path: path)
                XCTFail("loaded \(bad.name)", file: file, line: line)
            } catch {
                XCTAssertEqual(error.localizedDescription, message, bad.name, file: file, line: line)
            }
            stop()
        }
    }

    /// An upload with each extension lands on `platformID` and plays on `coreID`. The saved Library is put back.
    @MainActor
    static func assertUploadsPick(_ coreID: String, platforms: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        let state = AppState()
        let saved = state.games
        defer { state.games = saved; state.save() }
        for (ext, platformID) in platforms {
            let name = "upload-\(UUID().uuidString).\(ext)"
            state.addUploads([name])
            let added = state.games.first { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }
            XCTAssertEqual(added?.platformID, platformID, ext, file: file, line: line)
            XCTAssertEqual(added?.resolvedCoreID(defaults: [:]), coreID, ext, file: file, line: line)
        }
    }
}
