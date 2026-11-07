import XCTest
@testable import GagaEmu

/// Settings > About > Licences (docs/07 milestone 7.5) against what this build embeds.
final class LicenceNoticeTests: XCTestCase {
    /// Core frameworks in the app bundle. The test runner adds its own XCTest frameworks there too.
    private func embeddedCores() throws -> [String] {
        let folder = try XCTUnwrap(Bundle.main.privateFrameworksURL)
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "framework" && $0.lastPathComponent.hasSuffix("Core.framework") }
            .map { $0.deletingPathExtension().lastPathComponent }
    }

    func testEveryLinkedFrameworkHasANotice() throws {
        let linked = LicenceNotice.linked()
        let cores = try embeddedCores()
        XCTAssertFalse(cores.isEmpty, "no core framework embedded")
        for framework in cores {
            XCTAssertTrue(linked.contains { $0.framework == framework }, "\(framework) has no licence notice")
        }
        // A core left out of GAGA_CORE_SET shows no notice, and one linked always does.
        for notice in LicenceNotice.all() {
            if let framework = notice.framework { XCTAssertEqual(notice.isLinked, cores.contains(framework), notice.id) }
        }
    }

    func testSharedPartsAreInEveryBuildAndEveryTextIsBundled() throws {
        let all = LicenceNotice.all()
        XCTAssertFalse(all.isEmpty, "licences.json is not in the bundle")
        let linked = Set(LicenceNotice.linked().map(\.id))
        XCTAssertTrue(linked.isSuperset(of: ["anime4k", "community-shaders"]))
        for notice in all {
            XCTAssertFalse(notice.texts.isEmpty, notice.id)
            XCTAssertEqual(Set(notice.texts.map(\.title)).count, notice.texts.count, "\(notice.id) repeats a title")
            for text in notice.texts {
                let body = try XCTUnwrap(LicenceNotice.text(text.file), "\(notice.id): \(text.file) is not bundled")
                XCTAssertFalse(body.isEmpty)
            }
        }
        let anime4k = try XCTUnwrap(all.first { $0.id == "anime4k" })
        XCTAssertTrue(LicenceNotice.text(anime4k.texts[0].file)?.contains("Copyright (c) 2019-2021 bloc97") ?? false)
    }
}
