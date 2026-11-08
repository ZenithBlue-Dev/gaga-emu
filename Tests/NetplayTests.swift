import CryptoKit
import XCTest
@testable import GagaEmu

/// Play Nearby: wire format, pairing keys and sealing, disc-set hashes, port mapping, lockstep over a simulated
/// slow and lossy link, desync and resync, eligibility, and two real wrappers on the mock core. Two phones running real cores are device pending: a libretro core
/// cannot run twice in one process.
final class NetplayTests: XCTestCase {

    // MARK: - Wire format

    private static let hello = NetplayHello(nonce: 0x0102_0304_0506_0708, coreID: "nestopia", coreVersion: "1.52",
                                            stateVersion: 3, stateSize: 1234, contentHash: Data(repeating: 0xAB, count: 32),
                                            key: Data(repeating: 0xCD, count: 32), players: 2, maxPlayers: 4,
                                            name: "Sam's iPhone")

    private static let samples: [NetplayMessage] = {
        var input = NetInput()
        input.buttons = 0x8001; input.leftX = -32768; input.rightY = 32767; input.triggerL = Float(0.5).bitPattern
        return [.hello(hello), .accept, .reject(.game), .start(frame: 0, state: Data([1, 2, 3])),
                .inputs(first: 77, states: [[input], [NetInput()]]), .inputs(first: 3, states: [[input, NetInput()]]),
                .reveal(Data(repeating: 7, count: 32)), .checksum(frame: 180, hash: .max),
                .resync(frame: 360, state: Data(repeating: 9, count: 100)), .pause(true), .pause(false),
                .ping(42), .pong(43), .bye]
    }()

    private func body(_ message: NetplayMessage) -> Data { Data(Array(message.encoded().dropFirst(4))) }

    func testEveryMessageRoundTrips() throws {
        for message in Self.samples {
            let encoded = message.encoded()
            XCTAssertEqual(Int(encoded.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }), encoded.count - 4)
            XCTAssertEqual(try NetplayMessage.decode(Data(encoded.dropFirst(4)), maxState: 1000), message)
        }
    }

    func testEveryTruncationAndTrailingByteIsRefused() {
        for message in Self.samples {
            let full = Data(body(message))
            for length in 0..<full.count {
                XCTAssertThrowsError(try NetplayMessage.decode(full.prefix(length), maxState: 1000), "\(message) cut to \(length)")
            }
            XCTAssertThrowsError(try NetplayMessage.decode(full + [0], maxState: 1000), "\(message) with a trailing byte")
        }
    }

    func testBoundsAreChecked() {
        XCTAssertEqual(decodeError(Data([0])), .unknownType(0))
        XCTAssertEqual(decodeError(Data([200])), .unknownType(200))
        // A state over this phone's own state size, and an empty one.
        XCTAssertEqual(decodeError(body(.start(frame: 0, state: Data(count: 101))), maxState: 100), .tooLarge)
        XCTAssertEqual(decodeError(body(.resync(frame: 0, state: Data(count: 101))), maxState: 100), .tooLarge)
        XCTAssertEqual(decodeError(Data([4, 0, 0, 0, 0, 0, 0, 0, 0])), .tooLarge)
        // A state length that claims more than the message holds.
        XCTAssertEqual(decodeError(Data([7, 0, 0, 0, 0, 0, 0, 0, 50, 1, 2])), .truncated)
        // Before hello the link passes maxState 0, so no state is accepted at all.
        XCTAssertEqual(decodeError(body(.start(frame: 0, state: Data([1]))), maxState: 0), .tooLarge)
        // Input batches of 0 and over the cap, a pause that is not 0 or 1, an unknown refusal.
        XCTAssertEqual(decodeError(Data([5, 0, 0, 0, 0, 0])), .malformed)
        XCTAssertEqual(decodeError(Data([5, 0, 0, 0, 0, UInt8(NetplayWire.maxBatch + 1), 1]) + Data(count: 20 * (NetplayWire.maxBatch + 1))), .malformed)
        // Zero ports, and more ports than the core has.
        XCTAssertEqual(decodeError(Data([5, 0, 0, 0, 0, 1, 0])), .malformed)
        XCTAssertEqual(decodeError(Data([5, 0, 0, 0, 0, 1, 5]) + Data(count: 100)), .malformed)
        XCTAssertEqual(decodeError(Data([8, 2])), .malformed)
        XCTAssertEqual(decodeError(Data([3, 99])), .malformed)
        // A batch whose frames would run past UInt32.
        XCTAssertEqual(decodeError(Data([5, 0xFF, 0xFF, 0xFF, 0xFF, 2, 1]) + Data(count: 40)), .malformed)
        // Hello with the wrong magic, and with a name that is not UTF-8.
        var bad = Data(body(.hello(Self.hello)))
        bad[1] ^= 0xFF
        XCTAssertEqual(decodeError(bad), .malformed)
        var name = Data(body(.hello(Self.hello)))
        name[name.count - 1] = 0xFF
        XCTAssertEqual(decodeError(name), .malformed)
        // A player count of 0 or over four.
        var players = Self.hello
        players.players = 0
        XCTAssertEqual(decodeError(body(.hello(players))), .malformed)
        players.players = 5
        XCTAssertEqual(decodeError(body(.hello(players))), .malformed)
    }

    /// Another version's hello may be laid out differently; its version is still read, so it is refused as a version.
    func testOtherVersionsHelloDecodesToItsVersion() throws {
        var old = Data(body(.hello(Self.hello)))
        old[6] = 1 // Version, after the type byte and magic.
        guard case .hello(let back) = try NetplayMessage.decode(old, maxState: 0) else { return XCTFail() }
        XCTAssertEqual(back.version, 1)
        XCTAssertEqual(NetplaySession.refusal(ours: Self.hello, theirs: back), .version)
    }

    func testLongNamesAreCutByWholeCharacters() throws {
        var hello = Self.hello
        hello.name = String(repeating: "é", count: 100)
        guard case .hello(let back) = try NetplayMessage.decode(body(.hello(hello)), maxState: 0) else { return XCTFail() }
        XCTAssertLessThanOrEqual(back.name.utf8.count, NetplayWire.maxString)
        XCTAssertTrue(hello.name.hasPrefix(back.name))
    }

    /// Random bytes and random mutations of real messages must only ever throw or decode, never crash.
    func testFuzzedMessagesNeverCrash() {
        var rng = SplitMix(seed: 7)
        for round in 0..<20_000 {
            var bytes: Data
            if round % 2 == 0 {
                bytes = Data((0..<Int(rng.next() % 64)).map { _ in UInt8(truncatingIfNeeded: rng.next()) })
            } else {
                bytes = Data(body(Self.samples[Int(rng.next() % UInt64(Self.samples.count))]))
                for _ in 0..<(1 + rng.next() % 4) where !bytes.isEmpty {
                    bytes[Int(rng.next() % UInt64(bytes.count))] = UInt8(truncatingIfNeeded: rng.next())
                }
            }
            _ = try? NetplayMessage.decode(bytes, maxState: 256)
        }
    }

    func testFramerSplitsAStreamAndRefusesOversizeLengths() throws {
        var framer = NetplayFramer(limit: 64)
        let stream = NetplayMessage.ping(1).encoded() + NetplayMessage.pause(true).encoded()
        var bodies: [Data] = []
        for byte in stream { // One byte at a time, as TCP may deliver it.
            framer.append(Data([byte]))
            while let body = try framer.next() { bodies.append(body) }
        }
        XCTAssertEqual(try bodies.map { try NetplayMessage.decode($0, maxState: 0) }, [.ping(1), .pause(true)])

        var big = NetplayFramer(limit: 64)
        big.append(Data([0, 0, 0, 65]))
        XCTAssertThrowsError(try big.next())
        var empty = NetplayFramer(limit: 64)
        empty.append(Data([0, 0, 0, 0]))
        XCTAssertThrowsError(try empty.next())
        var huge = NetplayFramer()
        huge.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))
        XCTAssertThrowsError(try huge.next(), "A 4 GB length is refused before anything is buffered")
    }

    private func decodeError(_ data: Data, maxState: Int = 1000) -> NetplayWireError? {
        do {
            _ = try NetplayMessage.decode(data, maxState: maxState)
            return nil
        } catch {
            return error as? NetplayWireError
        }
    }

    // MARK: - Lockstep over a simulated link

    func testSlowLossyLinkGivesBothPhonesTheSameInputs() throws {
        let run = try simulate(ticks: 1500, latency: 6, jitter: 4, dropEvery: 0.15)
        XCTAssertGreaterThan(run.frames, 900, "Play keeps moving on a slow, lossy link")
        XCTAssertEqual(run.mismatchedInputs, 0)
        XCTAssertEqual(run.mismatchedStates, 0)
        XCTAssertEqual(run.desyncs, 0)
    }

    func testDelayChangesMidGameKeepInputsTheSame() throws {
        let run = try simulate(ticks: 1200, latency: 2, jitter: 1, dropEvery: 0) { tick, host, joiner in
            if tick == 300 { host.setDelay(roundTrip: 0.2, fps: 60); joiner.setDelay(roundTrip: 0.07, fps: 60) }
            if tick == 700 { host.setDelay(roundTrip: 0, fps: 60) }
        }
        XCTAssertGreaterThan(run.frames, 1000)
        XCTAssertEqual(run.mismatchedInputs, 0)
        XCTAssertEqual(run.mismatchedStates, 0)
    }

    func testDelayFollowsRoundTripWithinTwoToSixFrames() {
        let driver = LockstepDriver(isHost: true, core: MockLockstepCore()) { _ in }
        driver.setDelay(roundTrip: 0, fps: 60)
        XCTAssertEqual(driver.status.delay, 2)
        driver.setDelay(roundTrip: 0.05, fps: 60) // 1.5 frames each way, rounded up, plus one.
        XCTAssertEqual(driver.status.delay, 3)
        driver.setDelay(roundTrip: 0.15, fps: 60)
        XCTAssertEqual(driver.status.delay, 6)
        driver.setDelay(roundTrip: 2, fps: 60)
        XCTAssertEqual(driver.status.delay, 6)
    }

    func testAFrameWaitsForTheOtherPhonesInput() {
        let core = MockLockstepCore()
        let driver = LockstepDriver(isHost: true, core: core) { _ in }
        XCTAssertNil(driver.tick(local: [GagaInputState()]), "No input from the other phone yet")
        driver.receive(.inputs(first: 0, states: [[NetInput()]]))
        XCTAssertEqual(driver.tick(local: [GagaInputState()])?.count, 4)
        XCTAssertNil(driver.tick(local: [GagaInputState()]))
        // Inputs far outside the window are dropped, so memory stays bounded.
        driver.receive(.inputs(first: UInt32(LockstepDriver.history + 10), states: [[NetInput()]]))
        XCTAssertNil(driver.tick(local: [GagaInputState()]))
    }

    func testDesyncIsFoundAndTheHostsStateRepairsIt() throws {
        let run = try simulate(ticks: 1200, latency: 3, jitter: 2, dropEvery: 0) { tick, _, _ in
            if tick == 100 { self.corruptJoiner = true }
        }
        XCTAssertEqual(run.desyncs, 1, "The check at frame 180 finds it once; the one at 360 matches again")
        XCTAssertGreaterThan(run.joinerRestores, 0)
        XCTAssertEqual(run.mismatchedStatesAfter(400), 0, "Both phones agree after the resync")
        XCTAssertEqual(run.mismatchedInputs, 0)
    }

    private var corruptJoiner = false

    private struct Run {
        var frames: Int
        var mismatchedInputs: Int
        var mismatchedStates: Int
        var desyncs: Int
        var joinerRestores: Int
        var hostStates: [Int: UInt64]
        var joinerStates: [Int: UInt64]

        func mismatchedStatesAfter(_ frame: Int) -> Int {
            hostStates.filter { $0.key > frame && joinerStates[$0.key] != nil && joinerStates[$0.key] != $0.value }.count
        }
    }

    /// Two drivers, two mock cores, ticks in step. Each message goes through the real encoder and decoder,
    /// arrives `latency` plus up to `jitter` ticks later in order, or is dropped.
    private func simulate(ticks: Int, latency: Int, jitter: Int, dropEvery: Double,
                          during: ((Int, LockstepDriver, LockstepDriver) -> Void)? = nil) throws -> Run {
        corruptJoiner = false
        var rng = SplitMix(seed: 11)
        var tick = 0
        var toHost: [(Int, NetplayMessage)] = [], toJoiner: [(Int, NetplayMessage)] = []
        func carry(_ m: NetplayMessage, into queue: inout [(Int, NetplayMessage)]) {
            if Double(rng.next() % 1000) / 1000 < dropEvery { return }
            let decoded = try! NetplayMessage.decode(Data(m.encoded().dropFirst(4)), maxState: 64)
            let due = max(tick + latency + Int(rng.next() % UInt64(jitter + 1)), queue.last?.0 ?? 0) // TCP keeps order.
            queue.append((due, decoded))
        }
        let hostCore = MockLockstepCore(), joinerCore = MockLockstepCore()
        let host = LockstepDriver(isHost: true, core: hostCore) { carry($0, into: &toJoiner) }
        let joiner = LockstepDriver(isHost: false, core: joinerCore) { carry($0, into: &toHost) }
        var hostInputs: [Int: [NetInput]] = [:], joinerInputs: [Int: [NetInput]] = [:]
        var hostStates: [Int: UInt64] = [:], joinerStates: [Int: UInt64] = [:]
        host.onFrame = { hostInputs[$0] = $1 }
        joiner.onFrame = { joinerInputs[$0] = $1 }
        host.setDelay(roundTrip: Double(2 * latency) / 60, fps: 60)
        joiner.setDelay(roundTrip: Double(2 * latency) / 60, fps: 60)

        for t in 0..<ticks {
            tick = t
            while let first = toHost.first, first.0 <= t { toHost.removeFirst(); host.receive(first.1) }
            while let first = toJoiner.first, first.0 <= t { toJoiner.removeFirst(); joiner.receive(first.1) }
            during?(t, host, joiner)
            if corruptJoiner { joinerCore.value ^= 0xDEAD; corruptJoiner = false }
            var input = GagaInputState()
            input.buttons = UInt32(truncatingIfNeeded: rng.next()); input.left_x = Int16(truncatingIfNeeded: rng.next())
            let hostFrame = host.status.frame
            if let all = host.tick(local: [input]) { hostCore.step(all); hostStates[hostFrame] = hostCore.value }
            input.buttons = UInt32(truncatingIfNeeded: rng.next())
            if let all = joiner.tick(local: [input]) {
                // A resync may have moved the joiner back: the frame run is the one the driver logged last.
                joinerCore.step(all)
                joinerStates[joiner.status.frame - 1] = joinerCore.value
            }
        }
        let common = Set(hostInputs.keys).intersection(joinerInputs.keys)
        return Run(frames: min(host.status.frame, joiner.status.frame),
                   mismatchedInputs: common.filter { hostInputs[$0] != joinerInputs[$0] }.count,
                   mismatchedStates: Set(hostStates.keys).intersection(joinerStates.keys).filter { hostStates[$0] != joinerStates[$0] }.count,
                   desyncs: host.status.desyncs, joinerRestores: joinerCore.restores,
                   hostStates: hostStates, joinerStates: joinerStates)
    }

    // MARK: - Pairing and eligibility

    // MARK: - Pairing keys and sealing

    private static func keys() throws -> (host: NetplayKeys, joiner: NetplayKeys, joinerPublic: Data) {
        let host = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x11, count: 32))
        let joiner = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x22, count: 32))
        return (try NetplayKeys(own: host, peer: joiner.publicKey.rawRepresentation, isHost: true),
                try NetplayKeys(own: joiner, peer: host.publicKey.rawRepresentation, isHost: false),
                joiner.publicKey.rawRepresentation)
    }

    /// Fixed X25519 keys give a fixed code and a fixed first sealed message, on both phones.
    func testKeyDerivationVectors() throws {
        let (host, joiner, joinerPublic) = try Self.keys()
        XCTAssertEqual(host.code, "892801")
        XCTAssertEqual(joiner.code, host.code)
        XCTAssertEqual(NetplayKeys.commitment(joinerPublic).prefix(4), Data([0x65, 0xcf, 0x5c, 0x9b]))
        var seal = NetplayCipher(key: host.send)
        XCTAssertEqual(try seal.seal(NetplayMessage.ping(42).body()).map { String(format: "%02x", $0) }.joined(),
                       "9dd3321746ef7a5ae4f95b6bd2243e1c9dfbcf8704a0348417")
        // Each direction has its own key.
        var other = NetplayCipher(key: joiner.send)
        XCTAssertNotEqual(try other.seal(NetplayMessage.ping(42).body()), try NetplayCipher(key: host.send).sealCopy(NetplayMessage.ping(42).body()))
    }

    func testCodeIsSixDigitsAndChangesWithTheKeys() throws {
        let a = Curve25519.KeyAgreement.PrivateKey(), b = Curve25519.KeyAgreement.PrivateKey()
        let c = Curve25519.KeyAgreement.PrivateKey()
        let ab = try NetplayKeys(own: a, peer: b.publicKey.rawRepresentation, isHost: true)
        XCTAssertEqual(ab.code.count, 6)
        XCTAssertTrue(ab.code.allSatisfy(\.isNumber))
        XCTAssertEqual(ab.code, try NetplayKeys(own: b, peer: a.publicKey.rawRepresentation, isHost: false).code)
        // A phone in the middle has its own key, so each side sees another code.
        XCTAssertNotEqual(ab.code, try NetplayKeys(own: a, peer: c.publicKey.rawRepresentation, isHost: true).code)
        XCTAssertThrowsError(try NetplayKeys(own: a, peer: Data(count: 31), isHost: true))
    }

    func testSealedMessagesRoundTripInOrder() throws {
        let (host, joiner, _) = try Self.keys()
        var seal = NetplayCipher(key: host.send), open = NetplayCipher(key: joiner.receive)
        for message in Self.samples {
            XCTAssertEqual(try NetplayMessage.decode(try open.open(try seal.seal(message.body())), maxState: 1000), message)
        }
        var back = NetplayCipher(key: joiner.send), hostOpen = NetplayCipher(key: host.receive)
        XCTAssertEqual(try hostOpen.open(try back.seal(Data([9]))), Data([9]))
    }

    func testTamperedReplayedOrUnsealedMessagesAreRefused() throws {
        let (host, joiner, _) = try Self.keys()
        var seal = NetplayCipher(key: host.send)
        let body = NetplayMessage.ping(1).body()
        let first = try seal.seal(body), second = try seal.seal(body)
        for index in [0, first.count - 1] { // A changed byte, then a bad tag.
            var bad = first
            bad[index] ^= 1
            var open = NetplayCipher(key: joiner.receive)
            XCTAssertThrowsError(try open.open(bad))
        }
        var open = NetplayCipher(key: joiner.receive)
        XCTAssertThrowsError(try open.open(second), "Out of order")
        var inOrder = NetplayCipher(key: joiner.receive)
        XCTAssertEqual(try inOrder.open(first), body)
        XCTAssertThrowsError(try inOrder.open(first), "Repeated")
        XCTAssertThrowsError(try NetplayCipher(key: joiner.receive).openCopy(body), "Unsealed")
        XCTAssertThrowsError(try NetplayCipher(key: host.receive).openCopy(first), "The other direction's key")
    }

    // MARK: - Disc sets

    func testDiscSetHashCoversEveryTrack() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("netplay-discs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        func set(_ dir: String, newline: String, track2: UInt8) throws -> URL {
            let folder = root.appendingPathComponent(dir)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 3_000_000).write(to: folder.appendingPathComponent("Game (Track 1).bin")) // Over one read.
            try Data([track2, 2, 3]).write(to: folder.appendingPathComponent("Game (Track 2).bin"))
            let cue = ["FILE \"Game (Track 1).bin\" BINARY", "  TRACK 01 MODE2/2352", "FILE \"Game (Track 2).bin\" BINARY",
                       "  TRACK 02 AUDIO"].joined(separator: newline)
            try Data(cue.utf8).write(to: folder.appendingPathComponent("Game.cue"))
            return folder.appendingPathComponent("Game.cue")
        }
        let a = try set("a", newline: "\n", track2: 9), b = try set("b", newline: "\r\n", track2: 9), c = try set("c", newline: "\n", track2: 8)
        let hash = try XCTUnwrap(NetplayContentHash.of(a.path))
        XCTAssertEqual(NetplayContentHash.of(b.path), hash, "Another folder and line endings")
        XCTAssertNotEqual(NetplayContentHash.of(c.path), hash, "A second track that differs")
        XCTAssertNotEqual(NetplayContentHash.fileHash(a), hash, "Not the .cue alone")
        let m3u = root.appendingPathComponent("a/Game.m3u")
        try Data("#EXTM3U\nGame.cue\n".utf8).write(to: m3u)
        XCTAssertEqual(NetplayContentHash.of(m3u.path), hash, "An .m3u follows its .cue")
        try FileManager.default.removeItem(at: root.appendingPathComponent("c/Game (Track 2).bin"))
        XCTAssertNil(NetplayContentHash.of(c.path), "A missing track")
        let single = root.appendingPathComponent("a/Game (Track 2).bin")
        XCTAssertEqual(NetplayContentHash.of(single.path), Data(SHA256.hash(data: Data([9, 2, 3]))), "One file is its SHA-256")
        XCTAssertEqual(NetplayContentHash.referencedNames("FILE plain.bin BINARY\nREM x", cue: true), ["plain.bin"])
    }

    // MARK: - Ports

    func testPortsGoToTheHostFirstThenTheJoiner() throws {
        XCTAssertEqual(NetplayPorts.assign(host: 1, joiner: 1, maxPlayers: 2), NetplayPorts(host: 1, joiner: 1))
        XCTAssertEqual(NetplayPorts.assign(host: 2, joiner: 2, maxPlayers: 4), NetplayPorts(host: 2, joiner: 2))
        XCTAssertEqual(NetplayPorts.assign(host: 3, joiner: 3, maxPlayers: 4), NetplayPorts(host: 3, joiner: 1))
        XCTAssertEqual(NetplayPorts.assign(host: 4, joiner: 1, maxPlayers: 2), NetplayPorts(host: 1, joiner: 1))
        XCTAssertEqual(NetplayPorts.assign(host: 1, joiner: 4, maxPlayers: 8), NetplayPorts(host: 1, joiner: 3))
        XCTAssertNil(NetplayPorts.assign(host: 1, joiner: 1, maxPlayers: 1))
        var one = Self.hello
        one.maxPlayers = 1
        XCTAssertEqual(NetplaySession.refusal(ours: Self.hello, theirs: one), .unavailable)

        // Two host players and one joiner player, on an instant link: ports 1 and 2 are the host's, 3 the joiner's.
        let ports = NetplayPorts(host: 2, joiner: 1)
        var toHost: [NetplayMessage] = [], toJoiner: [NetplayMessage] = []
        let host = LockstepDriver(isHost: true, ports: ports, core: MockLockstepCore()) { toJoiner.append($0) }
        let joiner = LockstepDriver(isHost: false, ports: ports, core: MockLockstepCore()) { toHost.append($0) }
        func press(_ buttons: UInt32) -> GagaInputState { var s = GagaInputState(); s.buttons = buttons; return s }
        var last: ([UInt32], [UInt32])?
        for _ in 0..<20 {
            toHost.forEach(host.receive); toHost = []
            toJoiner.forEach(joiner.receive); toJoiner = []
            let h = host.tick(local: [press(1), press(2), press(64), press(64)])
            let j = joiner.tick(local: [press(4), press(64), press(64), press(64)])
            if let h, let j { last = (h.map(\.buttons), j.map(\.buttons)) }
        }
        XCTAssertEqual(last?.0, [1, 2, 4, 0], "Ports past the agreed ones stay empty")
        XCTAssertEqual(last?.1, last?.0)
        // A batch with another port count is not taken.
        let stray = LockstepDriver(isHost: true, ports: ports, core: MockLockstepCore()) { _ in }
        stray.receive(.inputs(first: 0, states: [[NetInput(), NetInput()]]))
        XCTAssertNil(stray.tick(local: [press(1), press(2)]))
    }

    func testHelloMismatchesAreRefusedWithTheRightReason() {
        let ours = Self.hello
        XCTAssertNil(NetplaySession.refusal(ours: ours, theirs: ours))
        var theirs = ours; theirs.version += 1
        XCTAssertEqual(NetplaySession.refusal(ours: ours, theirs: theirs), .version)
        theirs = ours; theirs.coreVersion = "1.53"
        XCTAssertEqual(NetplaySession.refusal(ours: ours, theirs: theirs), .core)
        theirs = ours; theirs.stateVersion += 1
        XCTAssertEqual(NetplaySession.refusal(ours: ours, theirs: theirs), .core)
        theirs = ours; theirs.contentHash = Data(repeating: 0, count: 32)
        XCTAssertEqual(NetplaySession.refusal(ours: ours, theirs: theirs), .game)
    }

    func testEligibilityList() {
        for (platform, core) in [("nes", "nestopia"), ("snes", "bsnes"), ("megadrive", "jgenesis"), ("mastersystem", "gearsystem"),
                                 ("pce", "beetle_pce_fast"), ("n64", "mupen64plus_next"), ("ps1", "pcsx_rearmed")] {
            XCTAssertTrue(CoreCatalog.playNearbyAllowed(platformID: platform, coreID: core), "\(platform) \(core)")
        }
        for (platform, core) in [("gba", "mgba"), ("gb", "gambatte"), ("gbc", "gambatte"), ("nds", "melonds_ds"), ("psp", "ppsspp"),
                                 ("n3ds", "azahar"), ("ps1", "beetle_psx"), ("gamegear", "gearsystem"), ("nes", "mgba")] {
            XCTAssertFalse(CoreCatalog.playNearbyAllowed(platformID: platform, coreID: core), "\(platform) \(core)")
        }
        // Every listed core is a real catalog core for that platform.
        for (platform, cores) in CoreCatalog.playNearbyCores {
            for core in cores {
                let all = ["nestopia", "fceumm", "bsnes", "snes9x", "jgenesis", "genesis_plus_gx", "picodrive", "gearsystem",
                           "beetle_pce_fast", "beetle_supergrafx", "mupen64plus_next", "pcsx_rearmed", "swanstation"]
                XCTAssertTrue(all.contains(core), "\(platform) \(core)")
            }
        }
        XCTAssertNil(CoreCatalog.playNearbyRefusal(stateSize: 1 << 20, saveNanos: 1_000_000))
        XCTAssertNotNil(CoreCatalog.playNearbyRefusal(stateSize: 0, saveNanos: 0))
        XCTAssertNotNil(CoreCatalog.playNearbyRefusal(stateSize: CoreCatalog.playNearbyMaxStateBytes + 1, saveNanos: 0))
        XCTAssertNotNil(CoreCatalog.playNearbyRefusal(stateSize: 1024, saveNanos: CoreCatalog.playNearbyMaxSaveNanos + 1))
    }

    // MARK: - Two wrappers in one process

    /// The real hook in `GagaCoreWrapper`, on two mock-core instances with a 5 ms link between them: both
    /// run on their own frame timers, and every frame both ran got the same inputs.
    func testTwoMockCoreWrappersStayInLockstep() async throws {
        guard let interface = MockCore_GetInterface()?.pointee else { return XCTFail("Missing mock core") }
        let a = try GagaCoreWrapper(interface: interface), b = try GagaCoreWrapper(interface: interface)
        try await a.loadROM(path: "a.mock", data: Data([1]))
        try await b.loadROM(path: "b.mock", data: Data([1]))
        let log = InputLog()
        let net = DispatchQueue(label: "netplay.test.link")
        var driverA: LockstepDriver!, driverB: LockstepDriver!
        driverA = LockstepDriver(isHost: true, core: a) { m in net.asyncAfter(deadline: .now() + 0.005) { driverB.receive(m) } }
        driverB = LockstepDriver(isHost: false, core: b) { m in net.asyncAfter(deadline: .now() + 0.005) { driverA.receive(m) } }
        driverA.onFrame = { log.add(host: true, frame: $0, $1) }
        driverB.onFrame = { log.add(host: false, frame: $0, $1) }
        let (da, db) = (driverA!, driverB!)
        a.betweenFrames { a.lockstep = { da.tick(local: $0) } }
        b.betweenFrames { b.lockstep = { db.tick(local: $0) } }
        var press = GagaInputState()
        press.buttons = 0x10
        a.setInput(player: 0, state: press)
        a.start(); b.start()
        try await Task.sleep(for: .milliseconds(700))
        a.stop(); b.stop()
        let result = log.compare()
        XCTAssertGreaterThan(result.common, 10, "Both wrappers ran frames together")
        XCTAssertEqual(result.mismatched, 0)
        XCTAssertTrue(result.sawHostPress, "Player 1's press reached port 1 on both phones")
    }
}

private final class InputLog: @unchecked Sendable {
    private let lock = NSLock()
    private var host: [Int: [NetInput]] = [:], joiner: [Int: [NetInput]] = [:]

    func add(host isHost: Bool, frame: Int, _ inputs: [NetInput]) {
        lock.lock(); defer { lock.unlock() }
        if isHost { host[frame] = inputs } else { joiner[frame] = inputs }
    }

    func compare() -> (common: Int, mismatched: Int, sawHostPress: Bool) {
        lock.lock(); defer { lock.unlock() }
        let common = Set(host.keys).intersection(joiner.keys)
        return (common.count, common.filter { host[$0] != joiner[$0] }.count,
                common.contains { joiner[$0]?.first?.buttons == 0x10 })
    }
}

/// A deterministic stand-in core: its state is a hash of every input it has run.
private final class MockLockstepCore: LockstepCore {
    var value: UInt64 = 0xCBF2_9CE4_8422_2325
    var restores = 0

    func step(_ inputs: [GagaInputState]) {
        for input in inputs.prefix(2) {
            value = (value ^ UInt64(input.buttons)) &* 0x100_0000_01B3
            value = (value ^ UInt64(UInt16(bitPattern: input.left_x))) &* 0x100_0000_01B3
        }
    }

    func captureState() throws -> Data { withUnsafeBytes(of: value) { Data($0) } }

    func restoreState(_ state: Data) throws {
        guard state.count == 8 else { throw EmulatorCoreError.loadStateFailed("wrong size") }
        value = state.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        restores += 1
    }
}

private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private extension NetplayCipher {
    /// One seal or open on a copy, for checks that need no counter afterwards.
    func sealCopy(_ body: Data) throws -> Data { var copy = self; return try copy.seal(body) }
    func openCopy(_ sealed: Data) throws -> Data { var copy = self; return try copy.open(sealed) }
}
