import Combine
import CryptoKit
import Foundation
import Network
import UIKit

/// One Play Nearby pairing for one running game: find a phone, check both have the same game file and core,
/// confirm a six-digit code on both (`NetplayKeys`), start both from the host's state, then keep them in lockstep
/// (`LockstepDriver`). The host's players take the first ports and the joiner's the next (`NetplayPorts`). If the
/// link drops, each phone goes on alone.
///
/// Main actor. Lockstep messages go from the network queue straight to the driver; the rest come here.
@MainActor
final class NetplaySession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        case hosting
        case browsing
        case connecting
        /// Host: a phone asks to join. Accept only when both show `code`.
        case confirm(peer: String, code: String)
        /// Joiner: waiting for the host to accept.
        case waiting(peer: String, code: String)
        case connected(peer: String)
        case ended(String)
    }

    struct Peer: Identifiable, Equatable {
        let id: String
        let endpoint: NWEndpoint
    }

    /// The pairing open now, kept while its sheet is closed.
    private(set) static var current: NetplaySession?
    /// Set by the Library's Play Nearby, so the pause menu opens the sheet once that game starts.
    static var openOnStart: UUID?
    static let lostMessage = "Connection lost. The game goes on here on its own."
    static let timeout: TimeInterval = 10

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var peers: [Peer] = []
    @Published private(set) var note: String?
    @Published private(set) var pingMs: Int?
    @Published private(set) var delayFrames = 3
    @Published private(set) var isHost = false
    @Published private(set) var ports: NetplayPorts?

    let game: GameSession
    private let romPath: String
    private let queue = DispatchQueue(label: "com.zenithblue.gagaemu.netplay", qos: .userInteractive)
    private var hello: NetplayHello?
    private var peerHello: NetplayHello?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var link: NetplayLink?
    private let slot = DriverSlot()
    private var pinger: Timer?
    private var phaseWatch: AnyCancellable?
    private var applyingRemote = false

    /// The driver, read on the network queue as messages arrive.
    private final class DriverSlot: @unchecked Sendable {
        private let lock = NSLock()
        private var value: LockstepDriver?
        var driver: LockstepDriver? {
            get { lock.lock(); defer { lock.unlock() }; return value }
            set { lock.lock(); value = newValue; lock.unlock() }
        }
    }

    static func session(for game: GameSession, romPath: String) -> NetplaySession {
        if let current, current.game === game { return current }
        current?.leave()
        let next = NetplaySession(game: game, romPath: romPath)
        current = next
        return next
    }

    private init(game: GameSession, romPath: String) {
        self.game = game
        self.romPath = romPath
        phaseWatch = game.$phase.sink { [weak self] phase in self?.localPhaseChanged(phase) }
    }

    var isActive: Bool {
        switch phase {
        case .idle, .ended: return false
        default: return true
        }
    }

    /// Nil when this game may play nearby, from the allow list alone.
    var unavailableReason: String? {
        guard let core = game.netplayCore,
              CoreCatalog.playNearbyAllowed(platformID: game.game.platformID, coreID: core.coreID) else {
            return CoreCatalog.playNearbyUnavailable
        }
        return nil
    }

    // MARK: - Start

    func host() { Task { await begin(host: true) } }
    func join() { Task { await begin(host: false) } }

    /// Measures this core's state, hashes the game file, then advertises or browses.
    private func begin(host: Bool) async {
        guard !isActive, let core = game.netplayCore else { return }
        if let reason = unavailableReason { return end(reason) }
        isHost = host
        note = nil
        phase = .checking
        game.pause(.menu)
        var size = 0, nanos: [UInt64] = []
        for _ in 0..<3 {
            let start = DispatchTime.now().uptimeNanoseconds
            guard let state = try? core.saveState() else { return end(CoreCatalog.playNearbyUnavailable) }
            nanos.append(DispatchTime.now().uptimeNanoseconds - start)
            size = state.count
        }
        if let reason = CoreCatalog.playNearbyRefusal(stateSize: size, saveNanos: nanos.sorted()[1]) { return end(reason) }
        let path = romPath
        guard let hash = await Task.detached(priority: .userInitiated, operation: { NetplayContentHash.of(path) }).value else {
            return end("GagaEmu could not read this game file.")
        }
        guard phase == .checking else { return } // Left while hashing.
        hello = NetplayHello(nonce: UInt64.random(in: 1...UInt64.max), coreID: core.coreID, coreVersion: core.version,
                             stateVersion: core.stateVersion, stateSize: UInt32(size), contentHash: hash,
                             players: UInt8(min(game.netplayLocalPlayers, NetplayPorts.count)),
                             maxPlayers: UInt8(min(max(game.maxPlayers, 1), NetplayPorts.count)), name: UIDevice.current.name)
        host ? advertise() : browse()
    }

    private func advertise() {
        do {
            let listener = try NWListener(using: NetplayTransport.parameters())
            listener.service = NWListener.Service(name: UIDevice.current.name, type: NetplayWire.serviceType)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.incoming(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    Task { @MainActor in self?.end("Could not start hosting. \(error.localizedDescription)") }
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            phase = .hosting
        } catch {
            end("Could not start hosting. \(error.localizedDescription)")
        }
    }

    private func browse() {
        let browser = NWBrowser(for: .bonjour(type: NetplayWire.serviceType, domain: nil), using: NetplayTransport.parameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let peers = results.compactMap { result -> Peer? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return Peer(id: name, endpoint: result.endpoint)
            }
            Task { @MainActor in self?.peers = peers.sorted { $0.id < $1.id } }
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                Task { @MainActor in self?.end("Could not look for nearby phones. \(error.localizedDescription)") }
            }
        }
        browser.start(queue: queue)
        self.browser = browser
        phase = .browsing
    }

    func connect(to peer: Peer) {
        guard phase == .browsing, let hello else { return }
        browser?.cancel()
        browser = nil
        phase = .connecting
        let link = open(NWConnection(to: peer.endpoint, using: NetplayTransport.parameters()))
        var mine = hello
        mine.key = link.helloKey
        link.onReady = { link.send(.hello(mine)) }
        link.start()
    }

    /// Host. One phone at a time: a second is turned away.
    private func incoming(_ connection: NWConnection) {
        guard phase == .hosting, link == nil else { return connection.cancel() }
        open(connection).start()
    }

    @discardableResult
    private func open(_ connection: NWConnection) -> NetplayLink {
        let link = NetplayLink(connection, ownStateSize: Int(hello?.stateSize ?? 0), isHost: isHost, queue: queue)
        let slot = self.slot
        link.onMessage = { [weak self, weak link] message in
            switch message {
            case .inputs, .checksum, .resync: slot.driver?.receive(message)
            case .ping(let t): link?.send(.pong(t))
            default: Task { @MainActor in self?.handle(message) }
            }
        }
        let id = ObjectIdentifier(link)
        link.onClose = { [weak self] reason in
            Task { @MainActor in self?.linkClosed(id, reason) }
        }
        self.link = link
        return link
    }

    // MARK: - Handshake

    private func handle(_ message: NetplayMessage) {
        switch message {
        case .hello(let theirs): received(theirs)
        case .reveal: revealed()
        case .accept: break // The host's state follows.
        case .reject(let reason): end(reason.message)
        case .start(let frame, let state): started(frame: frame, state: state)
        case .pause(let on): applyRemotePause(on)
        case .pong(let sent): measured(sent)
        case .bye: end("The other player left. The game goes on here on its own.", notify: false)
        default: break
        }
    }

    private func received(_ theirs: NetplayHello) {
        guard let hello, peerHello == nil, phase == (isHost ? .hosting : .connecting) else { return }
        if let refusal = Self.refusal(ours: hello, theirs: theirs) {
            link?.finish(.reject(refusal))
            link = nil
            if isHost {
                note = "A phone could not join. \(refusal.message)"
            } else {
                end(refusal.message, notify: false)
            }
            return
        }
        peerHello = theirs
        if isHost {
            // The code shows once the joiner reveals the key it committed to.
            guard let link else { return }
            var mine = hello
            mine.key = link.helloKey
            link.send(.hello(mine))
        } else {
            // The link worked out the keys before passing the host's hello on.
            guard let code = link?.code else { return end("Could not pair with that phone.") }
            phase = .waiting(peer: theirs.name, code: code)
        }
    }

    /// Host: the joiner revealed its key, so both phones now show the same code.
    private func revealed() {
        guard isHost, phase == .hosting, let peerHello, let code = link?.code else { return }
        phase = .confirm(peer: peerHello.name, code: code)
    }

    nonisolated static func refusal(ours: NetplayHello, theirs: NetplayHello) -> NetplayRefusal? {
        if theirs.version != ours.version { return .version }
        if theirs.coreID != ours.coreID || theirs.coreVersion != ours.coreVersion || theirs.stateVersion != ours.stateVersion { return .core }
        if theirs.contentHash != ours.contentHash { return .game }
        if NetplayPorts.assign(host: ours, joiner: theirs) == nil { return .unavailable }
        return nil
    }

    /// Host, after the player checked the code.
    func accept() {
        guard case .confirm(let peer, _) = phase, let link, let core = game.netplayCore else { return }
        game.pause(.menu)
        do {
            let state = try core.saveState()
            link.send(.accept)
            link.send(.start(frame: 0, state: state))
            connected(peer: peer, core: core)
        } catch {
            end("Could not send this game's state. \(error.localizedDescription)")
        }
    }

    func decline() {
        guard case .confirm = phase else { return }
        link?.finish(.reject(.declined))
        link = nil
        peerHello = nil
        phase = .hosting
    }

    /// Joiner: load the host's state, then play.
    private func started(frame: UInt32, state: Data) {
        guard !isHost, case .waiting(let peer, _) = phase, frame == 0, let core = game.netplayCore else { return }
        game.pause(.menu)
        do {
            try core.loadState(state)
            connected(peer: peer, core: core)
        } catch {
            end("Could not load the host's game state. \(error.localizedDescription)")
        }
    }

    private func connected(peer: String, core: GagaCoreWrapper) {
        listener?.cancel()
        listener = nil
        guard let link, let hello, let peerHello,
              let ports = NetplayPorts.assign(host: isHost ? hello : peerHello, joiner: isHost ? peerHello : hello) else { return }
        self.ports = ports
        let driver = LockstepDriver(isHost: isHost, ports: ports, core: core) { link.send($0) }
        driver.onFailure = { [weak self] reason in
            Task { @MainActor in self?.end("The two games could not be brought back together. \(reason)") }
        }
        driver.setDelay(roundTrip: 0, fps: core.targetFPS)
        slot.driver = driver
        core.betweenFrames { core.lockstep = { driver.tick(local: $0) } }
        game.setFastForward(1)
        game.setRewindHeld(false)
        phase = .connected(peer: peer)
        let ping = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pingTick() }
        }
        RunLoop.main.add(ping, forMode: .common)
        pinger = ping
        pingTick()
    }

    // MARK: - Running

    private func pingTick() {
        guard let link else { return }
        if Date().timeIntervalSince(link.lastHeard) > Self.timeout { return end(Self.lostMessage, notify: false) }
        link.send(.ping(DispatchTime.now().uptimeNanoseconds))
    }

    private func measured(_ sent: UInt64) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard sent <= now, let driver = slot.driver else { return }
        let rtt = Double(now - sent) / 1e9
        driver.setDelay(roundTrip: rtt, fps: game.netplayCore?.targetFPS ?? 60)
        pingMs = Int((rtt * 1000).rounded())
        delayFrames = driver.status.delay
    }

    /// Pausing on one phone pauses both. A change made for the other phone is not sent back.
    private func localPhaseChanged(_ phase: GameSession.Phase) {
        guard !applyingRemote, slot.driver != nil else {
            if phase == .stopped { leave() }
            return
        }
        switch phase {
        case .paused: link?.send(.pause(true))
        case .running: link?.send(.pause(false))
        case .stopped: leave()
        default: break
        }
    }

    private func applyRemotePause(_ on: Bool) {
        guard slot.driver != nil else { return }
        applyingRemote = true
        if on { game.pause(.menu) } else { game.resume(.menu) }
        applyingRemote = false
    }

    // MARK: - End

    /// The player left, or the game ended.
    func leave() {
        guard isActive else { return }
        end(nil)
    }

    /// Back to Host or Join after an error.
    func reset() {
        guard case .ended = phase else { return }
        phase = .idle
        note = nil
    }

    /// Only the current link: one turned away earlier may close later.
    private func linkClosed(_ id: ObjectIdentifier, _ reason: String?) {
        guard let current = link, ObjectIdentifier(current) == id else { return }
        link = nil
        switch phase {
        case .connected: end(Self.lostMessage, notify: false)
        case .confirm, .waiting, .connecting, .hosting:
            if isHost {
                peerHello = nil
                phase = .hosting
            } else {
                end(reason ?? "Could not reach that phone.", notify: false)
            }
        default: break
        }
    }

    /// Unhooks lockstep first, so the game goes on alone at once.
    private func end(_ message: String?, notify: Bool = true) {
        if slot.driver != nil, let core = game.netplayCore { core.betweenFrames { core.lockstep = nil } }
        slot.driver = nil
        pinger?.invalidate()
        pinger = nil
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        if notify { link?.finish(.bye) } else { link?.finish() }
        link = nil
        hello = nil
        peerHello = nil
        peers = []
        pingMs = nil
        ports = nil
        phase = message.map { .ended($0) } ?? .idle
    }
}
