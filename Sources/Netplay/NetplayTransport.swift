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

/// One connection to the other phone, framed. Messages and the close arrive on `queue`.
final class NetplayLink {
    let queue: DispatchQueue
    private let connection: NWConnection
    private let ownStateSize: Int
    // Queue only.
    private var framer = NetplayFramer()
    private var maxState = 0
    private var closed = false
    private let heardLock = NSLock()
    private var heard = Date()

    var onReady: (() -> Void)?
    var onMessage: ((NetplayMessage) -> Void)?
    /// Once. Nil for a clean close.
    var onClose: ((String?) -> Void)?

    /// `ownStateSize` caps every state the other phone sends.
    init(_ connection: NWConnection, ownStateSize: Int, queue: DispatchQueue) {
        self.connection = connection
        self.ownStateSize = ownStateSize
        self.queue = queue
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
        connection.send(content: message.encoded(), completion: .contentProcessed { _ in })
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
        while !closed, let body = try framer.next() {
            let message = try NetplayMessage.decode(body, maxState: maxState)
            if case .hello = message {
                // States may arrive from now on, up to this phone's own state size.
                maxState = ownStateSize
                framer.limit = max(NetplayWire.handshakeLimit, ownStateSize + 16)
            }
            heardLock.lock(); heard = Date(); heardLock.unlock()
            onMessage?(message)
        }
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
