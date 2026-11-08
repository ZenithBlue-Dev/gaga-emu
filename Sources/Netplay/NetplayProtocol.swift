import Foundation

/// Play Nearby's wire format. Every byte from the other phone is untrusted: each length is checked before it
/// is read, a state is capped at this core's own state size, an unknown type or a trailing byte is refused, and
/// a different protocol version is refused at hello. Only inputs, state checks and save states cross; never
/// game files.
///
/// A message is a 4-byte big-endian length, then that many bytes: one type byte and its fields, big-endian.
enum NetplayWire {
    static let version: UInt16 = 1
    static let magic: UInt32 = 0x4741_4741 // "GAGA"
    static let serviceType = "_gagaplay._tcp"
    /// The limit before hello has set the state size: no state can arrive yet.
    static let handshakeLimit = 4096
    static let maxBatch = 64
    static let maxString = 64
    static let hashBytes = 32
}

enum NetplayWireError: Error, Equatable {
    case truncated, tooLarge, unknownType(UInt8), malformed
}

/// One player's input for one frame: only what both phones can feed the core the same way. Pointer, motion
/// and keyboard stay local, because the other phone never sees them. Triggers travel as bit patterns, so
/// equality is exact.
struct NetInput: Equatable {
    var buttons: UInt32 = 0
    var leftX: Int16 = 0, leftY: Int16 = 0, rightX: Int16 = 0, rightY: Int16 = 0
    var triggerL: UInt32 = 0, triggerR: UInt32 = 0

    static let byteCount = 20

    init() {}

    init(_ state: GagaInputState) {
        buttons = state.buttons
        leftX = state.left_x; leftY = state.left_y; rightX = state.right_x; rightY = state.right_y
        triggerL = state.trigger_l.bitPattern; triggerR = state.trigger_r.bitPattern
    }

    var gaga: GagaInputState {
        var state = GagaInputState()
        state.buttons = buttons
        state.left_x = leftX; state.left_y = leftY; state.right_x = rightX; state.right_y = rightY
        state.trigger_l = Float(bitPattern: triggerL); state.trigger_r = Float(bitPattern: triggerR)
        return state
    }
}

struct NetplayHello: Equatable {
    var version = NetplayWire.version
    var nonce: UInt64
    var coreID: String
    var coreVersion: String
    var stateVersion: UInt32
    var stateSize: UInt32
    /// SHA-256 of the game file. Each player must own the game; it is never sent.
    var contentHash: Data
    var name: String
}

enum NetplayRefusal: UInt8, Equatable {
    case declined = 1, busy, version, core, game, unavailable

    var message: String {
        switch self {
        case .declined: return "The other player declined."
        case .busy: return "That phone is already playing with someone."
        case .version: return "The two phones have different versions of GagaEmu. Update both and try again."
        case .core: return "The two phones use a different core or core version for this game. Pick the same core on both."
        case .game: return "The two phones have different game files. Both players need the same file."
        case .unavailable: return "Play Nearby is not available for this system."
        }
    }
}

enum NetplayMessage: Equatable {
    case hello(NetplayHello)
    case accept
    case reject(NetplayRefusal)
    /// The host's state at `frame`, so both phones begin from the same point.
    case start(frame: UInt32, state: Data)
    /// This sender's inputs for `first`, `first + 1`, and on. Recent frames repeat, so one lost message stalls nothing.
    case inputs(first: UInt32, states: [NetInput])
    case checksum(frame: UInt32, hash: UInt64)
    /// The host's state at the start of `frame`, after the two phones' checks differed.
    case resync(frame: UInt32, state: Data)
    case pause(Bool)
    case ping(UInt64)
    case pong(UInt64)
    case bye

    private enum Kind: UInt8 {
        case hello = 1, accept, reject, start, inputs, checksum, resync, pause, ping, pong, bye
    }

    /// The length-prefixed bytes for the wire.
    func encoded() -> Data {
        var w = Writer()
        switch self {
        case .hello(let h):
            w.u8(Kind.hello.rawValue); w.u32(NetplayWire.magic); w.u16(h.version); w.u64(h.nonce)
            w.string(h.coreID); w.string(h.coreVersion); w.u32(h.stateVersion); w.u32(h.stateSize)
            w.bytes(h.contentHash) // SHA-256, so always hashBytes long.
            w.string(h.name)
        case .accept: w.u8(Kind.accept.rawValue)
        case .reject(let reason): w.u8(Kind.reject.rawValue); w.u8(reason.rawValue)
        case .start(let frame, let state): w.u8(Kind.start.rawValue); w.u32(frame); w.blob(state)
        case .inputs(let first, let states):
            w.u8(Kind.inputs.rawValue); w.u32(first); w.u8(UInt8(min(states.count, NetplayWire.maxBatch)))
            for s in states.prefix(NetplayWire.maxBatch) {
                w.u32(s.buttons); w.u16(UInt16(bitPattern: s.leftX)); w.u16(UInt16(bitPattern: s.leftY))
                w.u16(UInt16(bitPattern: s.rightX)); w.u16(UInt16(bitPattern: s.rightY)); w.u32(s.triggerL); w.u32(s.triggerR)
            }
        case .checksum(let frame, let hash): w.u8(Kind.checksum.rawValue); w.u32(frame); w.u64(hash)
        case .resync(let frame, let state): w.u8(Kind.resync.rawValue); w.u32(frame); w.blob(state)
        case .pause(let on): w.u8(Kind.pause.rawValue); w.u8(on ? 1 : 0)
        case .ping(let t): w.u8(Kind.ping.rawValue); w.u64(t)
        case .pong(let t): w.u8(Kind.pong.rawValue); w.u64(t)
        case .bye: w.u8(Kind.bye.rawValue)
        }
        var framed = Writer()
        framed.u32(UInt32(w.data.count))
        return framed.data + w.data
    }

    /// One message body, without its length. `maxState` is this phone's own state size: a bigger state is refused.
    static func decode(_ body: Data, maxState: Int) throws -> NetplayMessage {
        var r = Reader(Array(body))
        let type = try r.u8()
        guard let kind = Kind(rawValue: type) else { throw NetplayWireError.unknownType(type) }
        let message: NetplayMessage
        switch kind {
        case .hello:
            guard try r.u32() == NetplayWire.magic else { throw NetplayWireError.malformed }
            let version = try r.u16(), nonce = try r.u64()
            let coreID = try r.string(), coreVersion = try r.string()
            let stateVersion = try r.u32(), stateSize = try r.u32()
            let hash = Data(try r.bytes(NetplayWire.hashBytes))
            let name = try r.string()
            message = .hello(NetplayHello(version: version, nonce: nonce, coreID: coreID, coreVersion: coreVersion,
                                          stateVersion: stateVersion, stateSize: stateSize, contentHash: hash, name: name))
        case .accept: message = .accept
        case .reject:
            guard let reason = NetplayRefusal(rawValue: try r.u8()) else { throw NetplayWireError.malformed }
            message = .reject(reason)
        case .start: message = .start(frame: try r.u32(), state: try r.blob(max: maxState))
        case .inputs:
            let first = try r.u32(), count = Int(try r.u8())
            guard (1...NetplayWire.maxBatch).contains(count), UInt64(first) + UInt64(count) <= UInt64(UInt32.max) else {
                throw NetplayWireError.malformed
            }
            var states: [NetInput] = []
            for _ in 0..<count {
                var s = NetInput()
                s.buttons = try r.u32()
                s.leftX = Int16(bitPattern: try r.u16()); s.leftY = Int16(bitPattern: try r.u16())
                s.rightX = Int16(bitPattern: try r.u16()); s.rightY = Int16(bitPattern: try r.u16())
                s.triggerL = try r.u32(); s.triggerR = try r.u32()
                states.append(s)
            }
            message = .inputs(first: first, states: states)
        case .checksum: message = .checksum(frame: try r.u32(), hash: try r.u64())
        case .resync: message = .resync(frame: try r.u32(), state: try r.blob(max: maxState))
        case .pause:
            let on = try r.u8()
            guard on <= 1 else { throw NetplayWireError.malformed }
            message = .pause(on == 1)
        case .ping: message = .ping(try r.u64())
        case .pong: message = .pong(try r.u64())
        case .bye: message = .bye
        }
        guard r.atEnd else { throw NetplayWireError.malformed }
        return message
    }

    private struct Writer {
        var data = Data()
        mutating func u8(_ v: UInt8) { data.append(v) }
        mutating func u16(_ v: UInt16) { withUnsafeBytes(of: v.bigEndian) { data.append(contentsOf: $0) } }
        mutating func u32(_ v: UInt32) { withUnsafeBytes(of: v.bigEndian) { data.append(contentsOf: $0) } }
        mutating func u64(_ v: UInt64) { withUnsafeBytes(of: v.bigEndian) { data.append(contentsOf: $0) } }
        mutating func bytes(_ d: Data) { data.append(d) }
        mutating func blob(_ d: Data) { u32(UInt32(d.count)); data.append(d) }
        /// Cut by whole characters, so the far side's UTF-8 check passes.
        mutating func string(_ s: String) {
            var s = s
            while s.utf8.count > NetplayWire.maxString { s.removeLast() }
            u8(UInt8(s.utf8.count)); data.append(contentsOf: s.utf8)
        }
    }

    private struct Reader {
        let buffer: [UInt8]
        var offset = 0
        init(_ buffer: [UInt8]) { self.buffer = buffer }
        var atEnd: Bool { offset == buffer.count }

        mutating func bytes(_ count: Int) throws -> ArraySlice<UInt8> {
            guard count >= 0, buffer.count - offset >= count else { throw NetplayWireError.truncated }
            defer { offset += count }
            return buffer[offset..<offset + count]
        }
        mutating func int(_ count: Int) throws -> UInt64 { try bytes(count).reduce(0) { $0 << 8 | UInt64($1) } }
        mutating func u8() throws -> UInt8 { UInt8(try int(1)) }
        mutating func u16() throws -> UInt16 { UInt16(try int(2)) }
        mutating func u32() throws -> UInt32 { UInt32(try int(4)) }
        mutating func u64() throws -> UInt64 { try int(8) }
        mutating func blob(max: Int) throws -> Data {
            let count = Int(try u32())
            guard count > 0, count <= max else { throw NetplayWireError.tooLarge }
            return Data(try bytes(count))
        }
        mutating func string() throws -> String {
            let count = Int(try u8())
            guard count <= NetplayWire.maxString else { throw NetplayWireError.malformed }
            guard let s = String(bytes: try bytes(count), encoding: .utf8) else { throw NetplayWireError.malformed }
            return s
        }
    }
}

/// Splits a TCP byte stream into message bodies. A length over `limit` ends the connection before any of it
/// is buffered.
struct NetplayFramer {
    var limit: Int
    private var buffer: [UInt8] = []

    init(limit: Int = NetplayWire.handshakeLimit) { self.limit = limit }

    mutating func append(_ data: Data) { buffer.append(contentsOf: data) }

    /// The next whole body, or nil until more bytes arrive. One at a time, so a hello can raise `limit`
    /// before the next length is checked.
    mutating func next() throws -> Data? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer[0..<4].reduce(0) { $0 << 8 | Int($1) }
        guard length >= 1, length <= limit else { throw NetplayWireError.tooLarge }
        guard buffer.count >= 4 + length else { return nil }
        defer { buffer.removeFirst(4 + length) }
        return Data(buffer[4..<4 + length])
    }
}
