import CryptoKit
import Foundation

/// What lockstep needs from a core, on its own queue. `GagaCoreWrapper` gives it; tests use a mock.
protocol LockstepCore: AnyObject {
    func captureState() throws -> Data
    func restoreState(_ state: Data) throws
}

extension GagaCoreWrapper: LockstepCore {}

/// Delay-based lockstep, as libretro netplay without rollback. Both phones run the same core from the same
/// state. Each tick a phone schedules its player's input `delay` frames ahead, sends it, and runs frame `f`
/// only once both players' inputs for `f` are known, so both phones feed the core the same inputs.
///
/// Inputs are keyed by absolute frame, so each phone may change its own delay at any time without the two
/// disagreeing: a larger delay fills the gap with the current input, a smaller one sends nothing until play
/// catches up. Every `checksumInterval` frames the joiner sends a hash of its state at the start of that
/// frame; when the host's differs, the host sends its state and the joiner loads it at that frame.
///
/// Threads: `tick` runs on the core's queue and `receive` on the network queue; one lock covers both.
/// `send` is called under it and must not block.
final class LockstepDriver {
    static let checksumInterval = 180
    static let redundancy = 8
    static let history = 600
    static let delayRange = 2...6
    /// Ticks held before resending recent inputs, in case the other phone missed them.
    static let resendAfter = 15

    let isHost: Bool
    private let lock = NSLock()
    private weak var core: LockstepCore?
    private let send: (NetplayMessage) -> Void

    private var frame = 0
    private var nextLocalFrame = 0
    private var delay = 3
    private var local: [Int: NetInput] = [:]
    private var remote: [Int: NetInput] = [:]
    private var held = 0
    private var hashedFrame = -1
    private var ownHashes: [Int: UInt64] = [:]
    private var peerHashes: [Int: UInt64] = [:]
    private var resyncWanted = false
    private var resyncFrame = -1
    private var pendingState: (frame: Int, state: Data)?
    private var desyncs = 0
    /// Each frame's inputs as run, by port. For tests.
    var onFrame: ((Int, [NetInput]) -> Void)?
    /// A resync state that would not load.
    var onFailure: ((String) -> Void)?

    init(isHost: Bool, core: LockstepCore, send: @escaping (NetplayMessage) -> Void) {
        self.isHost = isHost
        self.core = core
        self.send = send
    }

    var status: (frame: Int, delay: Int, desyncs: Int) {
        lock.lock(); defer { lock.unlock() }
        return (frame, delay, desyncs)
    }

    /// Core queue. The inputs for the next frame by port (host is port 1, joiner port 2), or nil to hold it.
    func tick(local input: GagaInputState) -> [GagaInputState]? {
        lock.lock(); defer { lock.unlock() }
        if let pending = pendingState {
            pendingState = nil
            do {
                try core?.restoreState(pending.state)
                frame = pending.frame
                nextLocalFrame = max(nextLocalFrame, frame)
                hashedFrame = -1
                held = 0
            } catch {
                onFailure?(error.localizedDescription)
            }
        }
        if resyncWanted, let state = try? core?.captureState() {
            resyncWanted = false
            resyncFrame = frame
            send(.resync(frame: UInt32(frame), state: state))
        }
        if frame % Self.checksumInterval == 0, hashedFrame != frame, let state = try? core?.captureState() {
            hashedFrame = frame
            let hash = Self.hash(state)
            if isHost {
                ownHashes[frame] = hash
                compare(frame)
            } else {
                send(.checksum(frame: UInt32(frame), hash: hash))
            }
        }
        schedule(NetInput(input))
        guard let mine = local[frame], let theirs = remote[frame] else {
            held += 1
            if held % Self.resendAfter == 0 { sendInputs(from: frame) }
            return nil
        }
        held = 0
        let ports = isHost ? [mine, theirs] : [theirs, mine]
        onFrame?(frame, ports)
        frame += 1
        if frame % 60 == 0 { prune() }
        return ports.map(\.gaga) + [GagaInputState(), GagaInputState()]
    }

    /// Network queue. Inputs, checks and resync states; other messages belong to `NetplaySession`.
    func receive(_ message: NetplayMessage) {
        lock.lock(); defer { lock.unlock() }
        switch message {
        case .inputs(let first, let states):
            for (offset, state) in states.enumerated() {
                let f = Int(first) + offset
                // A window around now bounds memory, whatever the other phone sends.
                guard abs(f - frame) <= Self.history, remote[f] == nil else { continue }
                remote[f] = state
            }
        case .checksum(let f, let hash):
            guard isHost, Int(f) > resyncFrame, abs(Int(f) - frame) <= Self.history else { return }
            peerHashes[Int(f)] = hash
            compare(Int(f))
        case .resync(let f, let state):
            guard !isHost else { return }
            pendingState = (Int(f), state)
        default:
            break
        }
    }

    /// From the round trip time: half of it in frames, plus one, within `delayRange`.
    func setDelay(roundTrip seconds: Double, fps: Double) {
        let frames = Int((seconds / 2 * fps).rounded(.up)) + 1
        lock.lock()
        delay = min(max(frames, Self.delayRange.lowerBound), Self.delayRange.upperBound)
        lock.unlock()
    }

    static func hash(_ state: Data) -> UInt64 {
        SHA256.hash(data: state).prefix(8).reduce(0) { $0 << 8 | UInt64($1) }
    }

    // Under lock.
    private func schedule(_ input: NetInput) {
        guard nextLocalFrame <= frame + delay else { return }
        while nextLocalFrame <= frame + delay {
            local[nextLocalFrame] = input
            nextLocalFrame += 1
        }
        sendInputs(from: nextLocalFrame - Self.redundancy)
    }

    // Under lock. Sends the contiguous run of this phone's inputs from `start` to the newest.
    private func sendInputs(from start: Int) {
        var first = max(start, nextLocalFrame - NetplayWire.maxBatch, 0)
        while first < nextLocalFrame, local[first] == nil { first += 1 }
        let states = (first..<nextLocalFrame).compactMap { local[$0] }
        guard !states.isEmpty, states.count == nextLocalFrame - first else { return }
        send(.inputs(first: UInt32(first), states: states))
    }

    // Under lock.
    private func compare(_ f: Int) {
        guard let own = ownHashes[f], let peer = peerHashes[f] else { return }
        ownHashes[f] = nil
        peerHashes[f] = nil
        if own != peer {
            desyncs += 1
            resyncWanted = true
        }
    }

    // Under lock.
    private func prune() {
        let oldest = frame - Self.history
        local = local.filter { $0.key >= oldest }
        remote = remote.filter { $0.key >= oldest }
        ownHashes = ownHashes.filter { $0.key >= oldest }
        peerHashes = peerHashes.filter { $0.key >= oldest }
    }
}

extension CoreCatalog {
    /// Play Nearby allow list, by platform: cores whose runs repeat exactly from the same state and inputs and
    /// that read a second controller port. Handhelds with one port (GB, GBC, GBA, DS, 3DS, PSP) are out: the
    /// second player would have nothing to press. Layer-path and GPU-timed cores are out too.
    static let playNearbyCores: [String: Set<String>] = [
        "nes": ["nestopia", "fceumm"],
        "snes": ["bsnes", "snes9x"],
        "megadrive": ["jgenesis", "genesis_plus_gx", "picodrive"],
        "mastersystem": ["gearsystem", "genesis_plus_gx", "picodrive"],
        "sg1000": ["gearsystem", "genesis_plus_gx", "picodrive"],
        "pce": ["beetle_pce_fast"],
        "sgx": ["beetle_supergrafx"],
        "n64": ["mupen64plus_next"],
        "ps1": ["pcsx_rearmed", "swanstation"]
    ]

    /// The largest state and slowest save Play Nearby takes. A state goes to the other phone at start and on a
    /// resync, and one is hashed every few seconds, so it is held looser than rewind's every-other-frame limit.
    static let playNearbyMaxStateBytes = 16 * 1024 * 1024
    static let playNearbyMaxSaveNanos: UInt64 = 8_000_000

    static let playNearbyUnavailable = "Play Nearby is not available for this system."

    static func playNearbyAllowed(platformID: String, coreID: String) -> Bool {
        playNearbyCores[platformID]?.contains(coreID) == true
    }

    /// Nil when this core's measured state fits, otherwise why not.
    static func playNearbyRefusal(stateSize: Int, saveNanos: UInt64) -> String? {
        stateSize > 0 && stateSize <= playNearbyMaxStateBytes && saveNanos <= playNearbyMaxSaveNanos ? nil
            : "\(playNearbyUnavailable) Its save states are too large or too slow to keep two phones together."
    }
}
