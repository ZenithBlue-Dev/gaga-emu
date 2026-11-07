import Compression
import Foundation

/// When a core may rewind, and how much memory it gets (docs/02, Other enhancements). Rewind is built only
/// for cores whose state is small and quick to take, because one is taken every `interval` frames while a
/// game runs. The first `probeCount` snapshots decide: the median save time and the state size must both
/// fit, or rewind turns off for that session and the pause menu says why.
struct RewindPolicy: Equatable {
    var maxStateBytes = 2 * 1024 * 1024
    var maxSerializeNanos: UInt64 = 2_000_000
    var budgetBytes = 64 * 1024 * 1024
    /// Frames between snapshots, so holding rewind runs back at this many times normal speed.
    var interval = 2
    var probeCount = 5

    static let standard = RewindPolicy()

    /// A reason for the player, or nil when the core qualifies.
    func refusal(stateSize: Int, serializeNanos: UInt64) -> String? {
        if stateSize <= 0 { return "This core has no save states, so it cannot rewind." }
        if stateSize > maxStateBytes {
            return "This core's state is \(Self.megabytes(stateSize)), over the \(Self.megabytes(maxStateBytes)) rewind limit."
        }
        if serializeNanos > maxSerializeNanos {
            let ms = Double(serializeNanos) / 1_000_000
            return "This core takes \(ms.formatted(.number.precision(.fractionLength(1)))) ms to save its state, over the \(Double(maxSerializeNanos) / 1_000_000) ms rewind limit."
        }
        return nil
    }

    private static func megabytes(_ bytes: Int) -> String {
        "\((Double(bytes) / 1_048_576).formatted(.number.precision(.fractionLength(1)))) MB"
    }
}

/// Snapshots for rewind, newest last, in a fixed byte budget: a new one pushes out the oldest until it fits.
/// Each is LZ4 compressed when that makes it smaller. Not thread safe: the core's queue owns it.
final class RewindBuffer {
    private struct Snapshot {
        let bytes: Data
        let rawSize: Int
        let compressed: Bool
    }

    let budget: Int
    private var snapshots: [Snapshot] = []
    private var head = 0 // Index of the oldest live snapshot; evicted ones before it are dropped in batches.
    private(set) var usedBytes = 0
    private var scratch = Data()

    init(budget: Int) {
        self.budget = budget
    }

    var count: Int { snapshots.count - head }

    func push(_ state: UnsafeRawBufferPointer) {
        guard state.count > 0, let base = state.baseAddress else { return }
        if scratch.count < state.count { scratch = Data(count: state.count) }
        let packed = scratch.withUnsafeMutableBytes { destination in
            compression_encode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!, state.count,
                                      base.assumingMemoryBound(to: UInt8.self), state.count, nil, COMPRESSION_LZ4)
        }
        // 0 means it did not fit in the raw size, so it would not have saved anything. A copy, not a slice:
        // a slice would keep the whole scratch buffer alive and break the budget.
        let snapshot = packed > 0
            ? Snapshot(bytes: scratch.withUnsafeBytes { Data(bytes: $0.baseAddress!, count: packed) }, rawSize: state.count, compressed: true)
            : Snapshot(bytes: Data(state), rawSize: state.count, compressed: false)
        guard snapshot.bytes.count <= budget else { return }
        while usedBytes + snapshot.bytes.count > budget, count > 0 { dropOldest() }
        snapshots.append(snapshot)
        usedBytes += snapshot.bytes.count
    }

    /// Writes the newest snapshot's state into `buffer` and forgets it. Nil when empty or it does not fit.
    func popLatest(into buffer: UnsafeMutableRawBufferPointer) -> Int? {
        guard count > 0, let snapshot = snapshots.popLast() else { return nil }
        usedBytes -= snapshot.bytes.count
        guard snapshot.rawSize <= buffer.count, let destination = buffer.baseAddress else { return nil }
        guard snapshot.compressed else {
            snapshot.bytes.copyBytes(to: destination.assumingMemoryBound(to: UInt8.self), count: snapshot.rawSize)
            return snapshot.rawSize
        }
        let written = snapshot.bytes.withUnsafeBytes { source in
            compression_decode_buffer(destination.assumingMemoryBound(to: UInt8.self), snapshot.rawSize,
                                      source.bindMemory(to: UInt8.self).baseAddress!, source.count, nil, COMPRESSION_LZ4)
        }
        return written == snapshot.rawSize ? written : nil
    }

    func clear() {
        snapshots = []
        head = 0
        usedBytes = 0
    }

    private func dropOldest() {
        usedBytes -= snapshots[head].bytes.count
        head += 1
        if head >= 64, head * 2 >= snapshots.count {
            snapshots.removeFirst(head)
            head = 0
        }
    }
}
