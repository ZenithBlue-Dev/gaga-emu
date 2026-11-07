import Foundation
import Network

/// LAN HTTP upload server. Off until the user toggles it. A fresh 4-digit PIN gates every
/// session, sent only as a header, with guesses limited by `PINAttemptLimiter`. Uploads land
/// straight in the ROM directory. Traffic is plain HTTP, so the PIN and files are unencrypted.
///
/// `NSLocalNetworkUsageDescription` must be set in Info.plist or iOS will
/// silently refuse the listener (Guideline 1.4 / 5.1.1).
public final class WiFiTransferServer: ObservableObject, @unchecked Sendable {

    public enum State: Equatable {
        case stopped
        case running(host: String, port: UInt16, pin: String)
        case failed(String)
    }

    @Published public private(set) var state: State = .stopped

    public let romDirectory: URL
    public let port: UInt16
    /// File names just written to `romDirectory`. Called on the main queue.
    public var onUploaded: (([String]) -> Void)?

    private var listener: NWListener?
    private var pin: String = ""
    private var limiter = PINAttemptLimiter()
    private let queue = DispatchQueue(label: "com.zenithblue.gagaemu.wifi", qos: .userInitiated)
    private let lock = NSLock()

    public init(romDirectory: URL, port: UInt16 = 8080) {
        self.romDirectory = romDirectory
        self.port = port
        try? FileManager.default.createDirectory(at: romDirectory, withIntermediateDirectories: true)
    }

    /// Starts the listener and mints a new PIN. No-op if already running.
    public func start() {
        guard listener == nil else { return }
        pin = String(format: "%04d", Int.random(in: 0...9999))
        limiter = PINAttemptLimiter()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            publish(.failed("Bad port \(port)"))
            return
        }
        do {
            let listener = try NWListener(using: params, on: nwPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] nwState in
                guard let self else { return }
                switch nwState {
                case .ready:
                    let host = Self.lanAddress() ?? "iphone.local"
                    self.publish(.running(host: host, port: self.port, pin: self.pin))
                case .failed(let error):
                    self.publish(.failed(error.localizedDescription))
                    self.stop()
                default:
                    break
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            publish(.failed(error.localizedDescription))
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        pin = ""
        publish(.stopped)
    }

    // MARK: - Connection

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        readRequest(connection, buffer: Data())
    }

    private func readRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            if error != nil || (isComplete && (data == nil || data?.isEmpty == true) && buffer.isEmpty) {
                connection.cancel()
                return
            }
            var acc = buffer
            if let data { acc.append(data) }
            if let headerEnd = acc.range(of: Data("\r\n\r\n".utf8)) {
                self.dispatch(connection, raw: acc, headerEnd: headerEnd.upperBound)
            } else if acc.count > 64 * 1024 {
                self.respond(connection, status: 431, body: "headers too large")
            } else {
                self.readRequest(connection, buffer: acc)
            }
        }
    }

    private func dispatch(_ connection: NWConnection, raw: Data, headerEnd: Int) {
        let headerBytes = raw.prefix(headerEnd)
        guard let headerText = String(data: headerBytes, encoding: .utf8) else {
            respond(connection, status: 400, body: "bad request")
            return
        }
        let lines = headerText.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else {
            respond(connection, status: 400, body: "bad request")
            return
        }
        let method = String(requestLine[0])
        let target = String(requestLine[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() where line.contains(":") {
            let parts = line.split(separator: ":", maxSplits: 1)
            headers[parts[0].lowercased().trimmingCharacters(in: .whitespaces)] =
                parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        }

        if method == "GET" && (target == "/" || target.hasPrefix("/?")) {
            respond(connection, status: 200, contentType: "text/html; charset=utf-8", body: Self.page)
            return
        }

        // PIN is required for anything that writes. Header only: a query string lands in browser history.
        switch limiter.check(supplied: headers["x-gaga-pin"] ?? "", pin: pin) {
        case .allow:
            break
        case .reject:
            respond(connection, status: 401, body: "bad pin")
            return
        case .locked:
            respond(connection, status: 429, body: "too many wrong PINs, try again in a minute")
            return
        case .exhausted:
            respond(connection, status: 429, body: "too many wrong PINs, transfer stopped")
            stop()
            publish(.failed("Too many wrong PINs, so transfer stopped. Turn it on again for a new PIN."))
            return
        }

        if method == "POST" && target.hasPrefix("/upload") {
            let contentLength = Int(headers["content-length"] ?? "") ?? 0
            let contentType = headers["content-type"] ?? ""
            guard contentLength > 0, contentLength <= 2 * 1024 * 1024 * 1024 else {
                respond(connection, status: 413, body: "empty or oversized")
                return
            }
            let body = Data(raw.dropFirst(headerEnd))
            receiveBody(connection, soFar: body, expected: contentLength, contentType: contentType)
            return
        }

        respond(connection, status: 404, body: "not found")
    }

    private func receiveBody(_ connection: NWConnection, soFar: Data, expected: Int, contentType: String) {
        if soFar.count >= expected {
            finishUpload(connection, body: soFar.prefix(expected), contentType: contentType)
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            if let error {
                self.respond(connection, status: 400, body: error.localizedDescription)
                return
            }
            var next = soFar
            if let data { next.append(data) }
            if next.count >= expected || isComplete {
                self.finishUpload(connection, body: next.prefix(expected), contentType: contentType)
            } else {
                self.receiveBody(connection, soFar: next, expected: expected, contentType: contentType)
            }
        }
    }

    private func finishUpload(_ connection: NWConnection, body: Data.SubSequence, contentType: String) {
        do {
            let saved = try Self.writeMultipart(Data(body), contentType: contentType, into: romDirectory)
            DispatchQueue.main.async { self.onUploaded?(saved) }
            respond(connection, status: 200, contentType: "application/json",
                    body: "{\"ok\":true,\"files\":\(saved.count)}")
        } catch {
            respond(connection, status: 400, body: error.localizedDescription)
        }
    }

    private func respond(_ connection: NWConnection, status: Int, contentType: String = "text/plain; charset=utf-8", body: String) {
        let payload = Data(body.utf8)
        let reason = [200: "OK", 400: "Bad Request", 401: "Unauthorized", 404: "Not Found", 413: "Payload Too Large", 429: "Too Many Requests", 431: "Headers Too Large"][status] ?? "Error"
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(payload.count)\r\n"
        head += "Connection: close\r\n"
        head += "Cache-Control: no-store\r\n\r\n"
        var packet = Data(head.utf8)
        packet.append(payload)
        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func publish(_ next: State) {
        DispatchQueue.main.async { self.state = next }
    }

    // MARK: - Multipart

    enum UploadError: LocalizedError {
        case noBoundary, noFile, badName
        var errorDescription: String? {
            switch self {
            case .noBoundary: return "missing multipart boundary"
            case .noFile: return "no file part"
            case .badName: return "rejected filename"
            }
        }
    }

    /// Writes every file part of a multipart body into `directory`. Returns saved names.
    static func writeMultipart(_ body: Data, contentType: String, into directory: URL) throws -> [String] {
        guard let boundary = boundary(from: contentType) else { throw UploadError.noBoundary }
        let delimiter = Data(("--" + boundary).utf8)
        var saved: [String] = []
        var search = body.startIndex
        while let range = body.range(of: delimiter, in: search..<body.endIndex) {
            let partStart = range.upperBound
            guard let next = body.range(of: delimiter, in: partStart..<body.endIndex) else { break }
            var part = body[partStart..<next.lowerBound]
            // Strip the leading CRLF that follows a boundary and the trailing CRLF before the next.
            if part.starts(with: Data("\r\n".utf8)) { part = part.dropFirst(2) }
            if part.suffix(2) == Data("\r\n".utf8) { part = part.dropLast(2) }
            if let (name, bytes) = filePart(part) {
                let safe = sanitize(name)
                guard !safe.isEmpty else { throw UploadError.badName }
                let part = try ClipboardImporter.partFile(in: directory)
                defer { try? FileManager.default.removeItem(at: part) }
                try bytes.write(to: part, options: .atomic)
                saved.append(try ClipboardImporter.place(part, named: safe, in: directory).lastPathComponent)
            }
            search = next.lowerBound
        }
        guard !saved.isEmpty else { throw UploadError.noFile }
        return saved
    }

    private static func filePart(_ part: Data) -> (String, Data)? {
        guard let split = part.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: part[part.startIndex..<split.lowerBound], encoding: .utf8) else { return nil }
        guard head.lowercased().contains("filename=") else { return nil }
        guard let name = filename(in: head) else { return nil }
        return (name, Data(part[split.upperBound...]))
    }

    private static func filename(in disposition: String) -> String? {
        guard let key = disposition.range(of: "filename=", options: .caseInsensitive) else { return nil }
        var rest = disposition[key.upperBound...]
        if rest.hasPrefix("\"") {
            rest = rest.dropFirst()
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            return String(rest[..<end])
        }
        let end = rest.firstIndex(where: { $0 == ";" || $0 == "\r" }) ?? rest.endIndex
        return String(rest[..<end])
    }

    private static func boundary(from contentType: String) -> String? {
        guard let range = contentType.range(of: "boundary=", options: .caseInsensitive) else { return nil }
        var value = contentType[range.upperBound...]
        if value.hasPrefix("\"") {
            value = value.dropFirst()
            if let end = value.firstIndex(of: "\"") { return String(value[..<end]) }
        }
        let end = value.firstIndex(where: { $0 == ";" || $0 == " " }) ?? value.endIndex
        let found = String(value[..<end])
        return found.isEmpty ? nil : found
    }

    /// Basename only. Rejects traversal and control characters.
    static func sanitize(_ raw: String) -> String {
        let base = (raw as NSString).lastPathComponent
        let cleaned = base.unicodeScalars.filter { scalar in
            scalar.value > 31 && "\\/:*?\"<>|".unicodeScalars.contains(scalar) == false
        }
        let name = String(String.UnicodeScalarView(cleaned))
        if name == "." || name == ".." || name.isEmpty { return "" }
        return name
    }

    /// Equal length required, so a wrong-length PIN fails fast. Byte compare does not early-return.
    static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let da = Array(a.utf8), db = Array(b.utf8)
        guard da.count == db.count, !da.isEmpty else { return false }
        var diff: UInt8 = 0
        for i in 0..<da.count { diff |= da[i] ^ db[i] }
        return diff == 0
    }

    static func lanAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                address = String(cString: host)
                break
            }
        }
        return address
    }

    // Drag-and-drop page. PIN is typed once; every upload sends it as a header.
    static let page = """
    <!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
    <title>GagaEmu</title>
    <style>
    body{margin:0;background:#0b0c10;color:#fff;font:16px -apple-system,sans-serif;display:flex;min-height:100vh;align-items:center;justify-content:center}
    main{width:min(520px,92vw)}h1{font-weight:700;letter-spacing:.04em}
    #drop{border:1.5px dashed #3a3a44;border-radius:18px;padding:48px 20px;text-align:center;background:#14151b}
    #drop.over{border-color:#ff4d6a;background:#1c1220}button,input{font:inherit;border-radius:12px;border:0;padding:12px 16px}
    input{background:#1c1d24;color:#fff;width:8ch}button{background:linear-gradient(90deg,#ff4d6a,#7a5cff);color:#fff;font-weight:700}
    #log{white-space:pre-wrap;color:#9aa;font-size:13px}
    </style>
    <main>
    <h1>GagaEmu</h1><p>Drop ROMs, saves, or BIOS files. This local connection is not encrypted.</p>
    <p><input id=pin inputmode=numeric maxlength=4 placeholder=PIN> <button id=go>Upload</button></p>
    <div id=drop>Drop files here or tap to choose<input id=file type=file multiple hidden></div>
    <p id=log></p>
    </main>
    <script>
    const drop=document.getElementById('drop'),file=document.getElementById('file'),log=document.getElementById('log');
    drop.onclick=()=>file.click();
    drop.ondragover=e=>{e.preventDefault();drop.classList.add('over')};
    drop.ondragleave=()=>drop.classList.remove('over');
    drop.ondrop=e=>{e.preventDefault();drop.classList.remove('over');send(e.dataTransfer.files)};
    file.onchange=()=>send(file.files);document.getElementById('go').onclick=()=>file.click();
    async function send(list){
      const pin=document.getElementById('pin').value;
      for(const f of list){
        const body=new FormData();body.append('file',f,f.name);
        const res=await fetch('/upload',{method:'POST',headers:{'X-Gaga-Pin':pin},body});
        log.textContent+=f.name+' '+(res.ok?'saved':'rejected '+res.status)+'\\n';
      }
    }
    </script>
    """
}

/// Bounds PIN guessing for one server session, since a 4-digit PIN has only 10,000 values.
/// Every 5th wrong PIN locks the server for a minute. The 15th ends the session, for 15 guesses in all.
/// A correct PIN does not clear the count, so uploads cannot refresh an attacker's budget.
struct PINAttemptLimiter {
    enum Decision: Equatable { case allow, reject, locked, exhausted }

    static let failuresPerLockout = 5
    static let lockoutSeconds: TimeInterval = 60
    static let maxFailures = 15

    private var failures = 0
    private var lockedUntil = Date.distantPast

    /// A request with no PIN, such as a browser's favicon fetch, is not a guess and is not counted.
    mutating func check(supplied: String, pin: String, now: Date = Date()) -> Decision {
        if failures >= Self.maxFailures { return .exhausted }
        if now < lockedUntil { return .locked }
        guard !supplied.isEmpty, !pin.isEmpty else { return .reject }
        if WiFiTransferServer.constantTimeEqual(supplied, pin) { return .allow }
        failures += 1
        if failures >= Self.maxFailures { return .exhausted }
        if failures % Self.failuresPerLockout == 0 {
            lockedUntil = now.addingTimeInterval(Self.lockoutSeconds)
            return .locked
        }
        return .reject
    }
}

#if DEBUG
enum WiFiTransferServerChecks {
    static func run() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gaga-wifi-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let boundary = "gagaBoundary"
        let body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"game.gba\"\r\nContent-Type: application/octet-stream\r\n\r\nROMDATA\r\n--\(boundary)--\r\n".utf8)
        let saved = try? WiFiTransferServer.writeMultipart(body, contentType: "multipart/form-data; boundary=\(boundary)", into: dir)
        assert(saved == ["game.gba"])
        assert(WiFiTransferServer.sanitize("../../etc/passwd") == "passwd")
        assert(WiFiTransferServer.sanitize("..") == "")
        assert(WiFiTransferServer.constantTimeEqual("1234", "1234"))
        assert(!WiFiTransferServer.constantTimeEqual("1234", "1235"))
        assert(!WiFiTransferServer.constantTimeEqual("1234", "12345"))
    }
}
#endif
