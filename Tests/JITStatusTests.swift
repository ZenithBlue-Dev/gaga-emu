import XCTest
@testable import GagaEmu

/// Settings > Help > JIT in a store build: static text, the ten sideload JIT cores by name.
final class JITStatusTests: GagaTestCase {
    func testStoreBuildShowsNotAvailableAndTenCores() {
        #if !GAGA_DEV_JIT
        XCTAssertEqual(JITStatus.status, String(localized: "Not available in this version"))
        #endif
        let rows = CoreCatalog.sideloadJITCoreRows
        XCTAssertEqual(rows.count, 10)
        XCTAssertEqual(Set(rows.map(\.name)).count, 10, "Each core once")
        for (id, row) in zip(CoreCatalog.sideloadJITCores, rows) {
            XCTAssertNotEqual(row.name, id, "\(id) has no name in the catalog")
            XCTAssertFalse(row.systems.isEmpty, "\(id) has no system")
        }
    }
}
