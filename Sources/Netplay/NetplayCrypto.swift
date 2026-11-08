import CryptoKit
import Foundation

/// Play Nearby's pairing keys (docs/06 section 5). Each phone makes a fresh X25519 key for each pairing. The
/// joiner's hello carries only a SHA-256 commitment to its public key; the host's hello carries the host's public
/// key; then the joiner reveals its own. Neither side can pick its key after seeing the other's, so a phone in the
/// middle matches the six-digit code on both screens with a chance of one in a million. HKDF-SHA256 over the
/// shared secret, salted with both public keys (host first), gives the code and one ChaCha20-Poly1305 key for
/// each direction.
struct NetplayKeys {
    static let keyBytes = 32
    let send: SymmetricKey
    let receive: SymmetricKey
    /// Six digits both players compare before the host accepts.
    let code: String

    static func commitment(_ publicKey: Data) -> Data { Data(SHA256.hash(data: publicKey)) }

    /// Throws for a peer key that is not a valid X25519 public key.
    init(own: Curve25519.KeyAgreement.PrivateKey, peer: Data, isHost: Bool) throws {
        let secret = try own.sharedSecretFromKeyAgreement(with: Curve25519.KeyAgreement.PublicKey(rawRepresentation: peer))
        let mine = own.publicKey.rawRepresentation
        let salt = isHost ? mine + peer : peer + mine
        func derive(_ label: String) -> SymmetricKey {
            secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                           sharedInfo: Data("GagaEmu Play Nearby 2 \(label)".utf8), outputByteCount: 32)
        }
        let hostToJoiner = derive("host to joiner"), joinerToHost = derive("joiner to host")
        send = isHost ? hostToJoiner : joinerToHost
        receive = isHost ? joinerToHost : hostToJoiner
        let value = derive("code").withUnsafeBytes { $0.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
        code = String(format: "%06u", value % 1_000_000)
    }
}

/// One direction of the link. The nonce is a message counter, never sent: a message dropped, repeated, reordered
/// or changed fails its tag, and the link closes.
struct NetplayCipher {
    static let tagBytes = 16
    private let key: SymmetricKey
    private var counter: UInt64 = 0

    init(key: SymmetricKey) { self.key = key }

    mutating func seal(_ body: Data) throws -> Data {
        let box = try ChaChaPoly.seal(body, using: key, nonce: try nonce())
        counter += 1
        return Data(box.ciphertext + box.tag) // From 0: the box's ciphertext is a slice of its combined bytes.
    }

    mutating func open(_ sealed: Data) throws -> Data {
        guard sealed.count > Self.tagBytes else { throw NetplayWireError.malformed }
        let box = try ChaChaPoly.SealedBox(nonce: try nonce(), ciphertext: sealed.dropLast(Self.tagBytes),
                                           tag: sealed.suffix(Self.tagBytes))
        let body = try ChaChaPoly.open(box, using: key)
        counter += 1
        return body
    }

    private func nonce() throws -> ChaChaPoly.Nonce {
        var bytes = Data(count: 4)
        withUnsafeBytes(of: counter.bigEndian) { bytes.append(contentsOf: $0) }
        return try ChaChaPoly.Nonce(data: bytes)
    }
}

/// What both phones compare to know they have the same game. A single file is the SHA-256 of its bytes. A .cue or
/// .m3u is only a list of names, so a disc set is every track or disc file it names (an .m3u's .cue followed
/// once more), each streamed through SHA-256, then one SHA-256 over each file's path relative to the descriptor's
/// folder and its digest, sorted by that path. The descriptors' own text is left out, so line endings do not
/// matter. Nil when any file cannot be read.
enum NetplayContentHash {
    // shortcut: .ccd and .toc sets hash only the descriptor file; follow their tracks too if a disc core that takes them joins the allow list.
    static func of(_ path: String) -> Data? {
        let url = URL(fileURLWithPath: path)
        guard isDescriptor(url) else { return fileHash(url) }
        var leaves: [String: URL] = [:]
        guard collect(url, relativeDir: "", depth: 0, into: &leaves), !leaves.isEmpty else { return nil }
        var outer = SHA256()
        for (name, file) in leaves.sorted(by: { $0.key < $1.key }) {
            guard let digest = fileHash(file) else { return nil }
            outer.update(data: Data(name.utf8) + [0])
            outer.update(data: digest)
        }
        return Data(outer.finalize())
    }

    private static func isDescriptor(_ url: URL) -> Bool { ["cue", "m3u"].contains(url.pathExtension.lowercased()) }

    private static func collect(_ url: URL, relativeDir: String, depth: Int, into leaves: inout [String: URL]) -> Bool {
        guard depth < 2, let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        for name in referencedNames(text, cue: url.pathExtension.lowercased() == "cue") {
            let child = url.deletingLastPathComponent().appendingPathComponent(name)
            let relative = relativeDir.isEmpty ? name : relativeDir + "/" + name
            if isDescriptor(child) {
                let dir = (relative as NSString).deletingLastPathComponent
                guard collect(child, relativeDir: dir, depth: depth + 1, into: &leaves) else { return false }
            } else {
                leaves[relative] = child
            }
        }
        return true
    }

    /// A .cue's FILE names, quoted or not; an .m3u's lines that are not comments.
    static func referencedNames(_ text: String, cue: Bool) -> [String] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard cue else { return lines.filter { !$0.isEmpty && !$0.hasPrefix("#") } }
        return lines.filter { $0.uppercased().hasPrefix("FILE ") }.compactMap { line in
            let rest = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("\"") { return rest.dropFirst().split(separator: "\"").first.map(String.init) }
            return rest.split(separator: " ").first.map(String.init)
        }
    }

    /// SHA-256 of the file, read in 1 MB pieces.
    static func fileHash(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            // Nil or empty at the end of the file.
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        } catch {
            return nil
        }
        return Data(hasher.finalize())
    }
}
