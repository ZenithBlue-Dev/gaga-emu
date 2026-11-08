import XCTest
@testable import GagaEmu

/// Library column widths (`LibraryMetrics`) at the widths the Library gets: the screen less the rail (73pt with its
/// rule) and, on Face ID phones in landscape, about 59pt of notch inset on each side.
final class LibraryLayoutTests: XCTestCase {
    func testLandscapePhonesLeaveMostOfTheWidthToTheShelves() {
        // iPhone SE, 16 Pro, 16 Pro Max in landscape.
        for width: CGFloat in [667 - 73, 852 - 118 - 73, 932 - 118 - 73] {
            let metrics = LibraryMetrics(width: width, compact: true)
            XCTAssertGreaterThanOrEqual(metrics.panel, 180)
            XCTAssertLessThan(metrics.panel, 240, "the old fixed panel")
            XCTAssertGreaterThanOrEqual(metrics.search, 130)
            XCTAssertGreaterThanOrEqual(width - metrics.panel, width * 0.65, "\(width)")
        }
    }

    func testWidthsGrowWithTheScreenAndStopAtTheirCaps() {
        let small = LibraryMetrics(width: 600, compact: false)
        let large = LibraryMetrics(width: 1293, compact: false)
        XCTAssertEqual(small.panel, 220)
        XCTAssertEqual(large.panel, 300)
        XCTAssertEqual(large.search, 258.6, accuracy: 0.1)
        XCTAssertEqual(LibraryMetrics(width: 3000, compact: false), LibraryMetrics(width: 2000, compact: false))
    }

    func testBeforeTheFirstMeasureTheMinimumsHold() {
        XCTAssertEqual(LibraryMetrics(width: 0, compact: true), LibraryMetrics(width: 1, compact: true))
        XCTAssertEqual(LibraryMetrics(width: 0, compact: true).panel, 200)
        XCTAssertEqual(LibraryMetrics(width: 0, compact: true).search, 130)
    }
}
