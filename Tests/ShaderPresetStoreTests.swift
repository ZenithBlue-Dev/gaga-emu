import XCTest
@testable import GagaEmu

final class ShaderPresetStoreTests: GagaTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("presets-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func values(scanlines: Float, upscaler: Upscaler = .bicubic) -> ShaderParameterValues {
        var values = ShaderParameterValues()
        values.scanlineWeight = scanlines
        values.upscaler = upscaler.rawValue
        return values
    }

    func testSaveRenameDeleteSurviveAReload() throws {
        let store = ShaderPresetStore(directory: directory)
        XCTAssertTrue(store.presets.isEmpty)
        let soft = try store.save(name: "  Soft CRT ", shaderID: "crt-v2", values: values(scanlines: 0.2))
        XCTAssertEqual(soft.name, "Soft CRT", "trimmed")
        try store.save(name: "Arcade", shaderID: "lottes-crt", values: values(scanlines: 0.9, upscaler: .nearest))
        XCTAssertEqual(store.presets.map(\.name), ["Arcade", "Soft CRT"], "kept in name order")

        try store.rename(soft.id, to: "Gentle")
        try store.delete(store.presets.first { $0.name == "Arcade" }!.id)

        let reloaded = ShaderPresetStore(directory: directory)
        XCTAssertEqual(reloaded.presets.count, 1)
        let kept = try XCTUnwrap(reloaded.presets.first)
        XCTAssertEqual(kept.id, soft.id)
        XCTAssertEqual(kept.name, "Gentle")
        XCTAssertEqual(kept.shaderID, "crt-v2")
        XCTAssertEqual(kept.values, values(scanlines: 0.2), "sliders and upscaler come back exactly")
        XCTAssertEqual(ShaderPreset.from(id: kept.shaderID), .crtV2)
    }

    func testBadNamesAreRefusedAndChangeNothing() throws {
        let store = ShaderPresetStore(directory: directory)
        let first = try store.save(name: "Night", shaderID: "film", values: ShaderParameterValues())
        let second = try store.save(name: "Day", shaderID: "film", values: ShaderParameterValues())
        XCTAssertThrowsError(try store.save(name: "   ", shaderID: "film", values: ShaderParameterValues())) {
            XCTAssertEqual($0 as? SavedPresetError, .emptyName)
        }
        XCTAssertThrowsError(try store.save(name: "night", shaderID: "film", values: ShaderParameterValues())) {
            XCTAssertEqual($0 as? SavedPresetError, .duplicateName("night"))
        }
        XCTAssertThrowsError(try store.save(name: String(repeating: "x", count: 41), shaderID: "film", values: ShaderParameterValues())) {
            XCTAssertEqual($0 as? SavedPresetError, .nameTooLong)
        }
        XCTAssertThrowsError(try store.rename(second.id, to: "NIGHT")) {
            XCTAssertEqual($0 as? SavedPresetError, .duplicateName("NIGHT"))
        }
        XCTAssertNoThrow(try store.rename(first.id, to: "night"), "a preset may change the case of its own name")
        XCTAssertThrowsError(try store.delete(UUID())) { XCTAssertEqual($0 as? SavedPresetError, .notFound) }
        XCTAssertEqual(ShaderPresetStore(directory: directory).presets.map(\.name), ["Day", "night"])
    }

    func testAnUnreadableFileIsMovedAsideNotLost() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(ShaderPresetStore.fileName)
        try Data("not json".utf8).write(to: file)
        let store = ShaderPresetStore(directory: directory)
        XCTAssertTrue(store.presets.isEmpty)
        try store.save(name: "Fresh", shaderID: "original", values: ShaderParameterValues())
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        let aside = try XCTUnwrap(names.first { $0.contains("unreadable") })
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(aside)), Data("not json".utf8))
    }

    @MainActor
    func testTheAppKeepsPresetsInDocumentsAsJSON() throws {
        let state = AppState()
        try state.presets.save(name: "Mine", shaderID: "crt-v1", values: values(scanlines: 0.7))
        XCTAssertEqual(state.presets.url.deletingLastPathComponent().lastPathComponent, "Documents")
        let decoded = try JSONDecoder().decode([SavedFilterPreset].self, from: Data(contentsOf: state.presets.url))
        XCTAssertEqual(decoded.map(\.name), ["Mine"])
    }
}
