import CryptoKit
import Foundation
import Network

/// Bonjour over TCP with peer-to-peer on, so two phones find each other on the same Wi-Fi or with no router at
/// all. Local only: no servers, no relays, no accounts.
enum NetplayTransport {
    static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true // One small input message a frame: Nagle would hold them.
        tcp.connectionTimeout = 10
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = true
        return parameters
    }
}

/// One connection to the other phone, framed, and sealed once the pairing keys are known (`NetplayKeys`). Before
/// that only hello, reveal, reject and bye are taken. Messages and the close arrive on `queue`.
final class NetplayLink {
    let queue: DispatchQueue
    let isHost: Bool
    private let connection: NWConnection
    private let ownStateSize: Int
    private let privateKey = Curve25519.KeyAgreement.PrivateKey()
    // Queue only.
    private var framer = NetplayFramer()
    private var maxState = 0
    private var closed = false
    private var peerHello = false
    private var peerCommitment: Data?
    private var opener: NetplayCipher?
    // Under sendLock, so the nonce counter follows the order sends reach the connection.
    private let sendLock = NSLock()
    private var sealer: NetplayCipher?
    // Under heardLock.
    private let heardLock = NSLock()
    private var heard = Date()
    private var pairing: String?

    var onReady: (() -> Void)?
    var onMessage: ((NetplayMessage) -> Void)?
    /// Once. Nil for a clean close.
    var onClose: ((String?) -> Void)?

    /// `ownStateSize` caps every state the other phone sends.
    init(_ connection: NWConnection, ownStateSize: Int, isHost: Bool, queue: DispatchQueue) {
        self.connection = connection
        self.ownStateSize = ownStateSize
        self.isHost = isHost
        self.queue = queue
    }

    /// What this phone's hello carries: the host's public key, or the joiner's commitment to its own.
    var helloKey: Data {
        let key = privateKey.publicKey.rawRepresentation
        return isHost ? key : NetplayKeys.commitment(key)
    }

    /// The six-digit code, once the keys are known: before the host's reveal message or the joiner's hello
    /// message reaches `onMessage`.
    var code: String? {
        heardLock.lock(); defer { heardLock.unlock() }
        return pairing
    }

    var lastHeard: Date {
        heardLock.lock(); defer { heardLock.unlock() }
        return heard
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onReady?()
                self?.receive()
            case .failed(let error): self?.close(error.localizedDescription)
            case .cancelled: self?.close(nil)
            default: break
            }
        }
        connection.start(queue: queue)
    }

    func send(_ message: NetplayMessage) {
        sendLock.lock(); defer { sendLock.unlock() }
        var body = message.body()
        if sealer != nil {
            guard let sealed = try? sealer?.seal(body) else { return }
            body = sealed
        }
        connection.send(content: NetplayMessage.framed(body), completion: .contentProcessed { _ in })
    }

    /// Sends anything queued, then closes. Holds itself until then.
    func finish(_ message: NetplayMessage? = nil) {
        if let message { send(message) }
        connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            self.close(nil) // Completions run on `queue`.
        })
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, !closed else { return }
            if let data, !data.isEmpty {
                do {
                    try handle(data)
                } catch {
                    return close("The other phone sent something GagaEmu could not read, so the connection was closed.")
                }
            }
            if let error { return close(error.localizedDescription) }
            if isComplete { return close(nil) }
            receive()
        }
    }

    private func handle(_ data: Data) throws {
        framer.append(data)
        while !closed, var body = try framer.next() {
            if opener != nil { body = try opener!.open(body) } // A bad tag throws, and the link closes.
            let message = try NetplayMessage.decode(body, maxState: maxState)
            switch message {
            case .hello(let theirs):
                guard !peerHello, opener == nil else { throw NetplayWireError.malformed }
                peerHello = true
                // States may arrive from now on, up to this phone's own state size.
                maxState = ownStateSize
                framer.limit = max(NetplayWire.handshakeLimit, ownStateSize + 64)
                if theirs.version == NetplayWire.version { // Another version is refused by the session, unsealed.
                    if isHost {
                        peerCommitment = theirs.key
                    } else {
                        send(.reveal(privateKey.publicKey.rawRepresentation))
                        try pair(theirs.key)
                    }
                }
            case .reveal(let key):
                guard isHost, opener == nil, let commitment = peerCommitment, NetplayKeys.commitment(key) == commitment else {
                    throw NetplayWireError.malformed
                }
                try pair(key)
            case .reject, .bye: break
            default:
                guard opener != nil else { throw NetplayWireError.malformed }
            }
            heardLock.lock(); heard = Date(); heardLock.unlock()
            onMessage?(message)
        }
    }

    // Queue only. From here on every message both ways is sealed.
    private func pair(_ peerKey: Data) throws {
        let keys = try NetplayKeys(own: privateKey, peer: peerKey, isHost: isHost)
        opener = NetplayCipher(key: keys.receive)
        sendLock.lock(); sealer = NetplayCipher(key: keys.send); sendLock.unlock()
        heardLock.lock(); pairing = keys.code; heardLock.unlock()
    }

    // Queue only.
    func close(_ reason: String?) {
        guard !closed else { return }
        closed = true
        connection.cancel()
        let handler = onClose
        onClose = nil
        onMessage = nil
        onReady = nil
        handler?(reason)
    }
}
