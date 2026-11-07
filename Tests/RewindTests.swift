import XCTest
@testable import GagaEmu

/// The rewind ring and its policy, with no core. The mGBA run is in `MgbaCoreTests`.
final class RewindTests: GagaTestCase {
    private func push(_ buffer: RewindBuffer, _ byte: UInt8, count: Int) {
        // Random bytes do not compress, so each snapshot costs its full size.
        var bytes = (0..<count).map { _ in UInt8.random(in: 0...255) }
        bytes[0] = byte
        bytes.withUnsafeBytes { buffer.push($0) }
    }

    private func pop(_ buffer: RewindBuffer, count: Int) -> [UInt8]? {
        var out = [UInt8](repeating: 0, count: count)
        guard let size = out.withUnsafeMutableBytes({ buffer.popLatest(into: $0) }) else { return nil }
        return Array(out.prefix(size))
    }

    func testRingWrapsAndKeepsTheNewest() {
        let buffer = RewindBuffer(budget: 5 * 1100)
        for index in 0..<12 { push(buffer, UInt8(index), count: 1000) }
        XCTAssertEqual(buffer.count, 5, "the oldest went to make room")
        XCTAssertLessThanOrEqual(buffer.usedBytes, buffer.budget)
        // Newest first, back to the oldest kept: 11, 10, 9, 8, 7.
        for expected in (7...11).reversed() { XCTAssertEqual(pop(buffer, count: 1000)?.first, UInt8(expected)) }
        XCTAssertNil(pop(buffer, count: 1000), "nothing older than the budget held")
        XCTAssertEqual(buffer.usedBytes, 0)
    }

    func testBudgetHoldsOverManyWraps() {
        let budget = 64 * 1024
        let buffer = RewindBuffer(budget: budget)
        for index in 0..<2000 {
            push(buffer, UInt8(index & 0xFF), count: 700 + index % 300)
            XCTAssertLessThanOrEqual(buffer.usedBytes, budget)
        }
        XCTAssertGreaterThan(buffer.count, 50)
    }

    func testCompressibleStatesRoundTripExactly() {
        let buffer = RewindBuffer(budget: 1024 * 1024)
        let state = [UInt8](repeating: 0x5A, count: 200_000) + Array(0..<255)
        state.withUnsafeBytes { buffer.push($0) }
        XCTAssertLessThan(buffer.usedBytes, state.count / 10, "LZ4 shrinks a mostly constant state")
        XCTAssertEqual(pop(buffer, count: state.count), state)
    }

    func testASnapshotLargerThanTheBudgetIsNotKept() {
        let buffer = RewindBuffer(budget: 500)
        push(buffer, 1, count: 400)
        push(buffer, 2, count: 600)
        XCTAssertEqual(buffer.count, 1)
        XCTAssertEqual(pop(buffer, count: 600)?.first, 1)
    }

    func testPolicyRefusesLargeOrSlowStates() {
        let policy = RewindPolicy.standard
        XCTAssertNil(policy.refusal(stateSize: 400_000, serializeNanos: 300_000))
        XCTAssertNotNil(policy.refusal(stateSize: 3 * 1024 * 1024, serializeNanos: 300_000))
        XCTAssertNotNil(policy.refusal(stateSize: 400_000, serializeNanos: 2_500_000))
        XCTAssertNotNil(policy.refusal(stateSize: 0, serializeNanos: 0), "no states, no rewind")
    }
}
