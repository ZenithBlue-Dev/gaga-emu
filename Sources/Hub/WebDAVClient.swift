import Foundation
import Security

/// The sign-in for the user's one WebDAV server, kept only in the Keychain and only on this device.
struct WebDAVCredentials: Codable, Equatable {
    var username: String
    var password: String

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.zenithblue.gagaemu.webdav",
         kSecAttrAccount as String: "server"]
    }

    static func load() -> WebDAVCredentials? {
        var result: AnyObject?
        var search = query
        search[kSecReturnData as String] = true
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WebDAVCredentials.self, from: data)
    }

    @discardableResult func save() -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        Self.delete()
        var item = Self.query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() { SecItemDelete(query as CFDictionary) }
}

/// Browses a WebDAV server the user names and copies the games they pick into the ROM folder. There is no server
/// list and nothing is fetched unless the user taps it. HTTPS unless the user allows plain HTTP, and App Transport
/// Security still limits plain HTTP to local names and addresses.
final class WebDAVClient: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    struct Entry: Identifiable, Equatable {
        let name: String
        let isFolder: Bool
        let size: Int64?
        var id: String { name }
    }

    enum Failure: LocalizedError, Equatable {
        case badAddress, plainHTTP, signIn, status(Int), badReply, unsafeName
        var errorDescription: String? {
            switch self {
            case .badAddress: return "Enter a full server address, such as https://nas.local/games."
            case .plainHTTP: return "This address is not encrypted. Turn on Allow Unencrypted HTTP to use it."
            case .signIn: return "The server refused this username or password."
            case .status(let code): return "The server answered with status \(code)."
            case .badReply: return "The server sent a reply GagaEmu cannot read."
            case .unsafeName: return "The server sent a file name GagaEmu refuses."
            }
        }
    }

    let base: URL
    private let credentials: WebDAVCredentials?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    /// A listing bigger than this is not a folder of games.
    private static let replyLimit = 8 << 20

    init(address: String, allowPlainHTTP: Bool, credentials: WebDAVCredentials?) throws {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: text.contains("://") ? text : "https://" + text),
              let scheme = parts.scheme?.lowercased(), parts.host?.isEmpty == false else { throw Failure.badAddress }
        guard scheme == "https" || scheme == "http" else { throw Failure.badAddress }
        guard scheme == "https" || allowPlainHTTP else { throw Failure.plainHTTP }
        // A password belongs in its own field, where it reaches the Keychain, and not in an address.
        parts.user = nil
        parts.password = nil
        parts.query = nil
        parts.fragment = nil
        if !parts.percentEncodedPath.hasSuffix("/") { parts.percentEncodedPath += "/" }
        guard let url = parts.url else { throw Failure.badAddress }
        base = url
        self.credentials = credentials
    }

    /// Ends the session, which otherwise keeps this client alive.
    func close() { session.invalidateAndCancel() }

    // MARK: Requests

    func list(_ folder: [String]) async throws -> [Entry] {
        var request = URLRequest(url: try url(folder, isFolder: true))
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"<?xml version="1.0"?><propfind xmlns="DAV:"><prop><resourcetype/><getcontentlength/></prop></propfind>"#.utf8)
        let (bytes, response) = try await session.bytes(for: request)
        try check(response, expected: 207)
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            guard data.count <= Self.replyLimit else { throw Failure.badReply }
        }
        return try Self.parse(data, directory: request.url?.path ?? "/")
    }

    /// Copies one file into `directory` through the same placement as every other import.
    func download(_ path: [String], into directory: URL) async throws -> URL {
        guard let name = path.last else { throw Failure.unsafeName }
        let (temporary, response) = try await session.download(for: URLRequest(url: try url(path, isFolder: false)))
        defer { try? FileManager.default.removeItem(at: temporary) }
        try check(response, expected: 200)
        let part = try ClipboardImporter.partFile(in: directory)
        defer { try? FileManager.default.removeItem(at: part) }
        try FileManager.default.moveItem(at: temporary, to: part)
        return try ClipboardImporter.placeROM(part, named: name, in: directory)
    }

    private func check(_ response: URLResponse, expected: Int) throws {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw Failure.badReply }
        if status == 401 || status == 403 { throw Failure.signIn }
        guard status == expected else { throw Failure.status(status) }
    }

    /// Built only from names that passed `isSafeName`, under `base`, so a server's reply cannot point anywhere else.
    func url(_ path: [String], isFolder: Bool) throws -> URL {
        guard path.allSatisfy(Self.isSafeName) else { throw Failure.unsafeName }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/;?#%")
        let encoded = path.compactMap { $0.addingPercentEncoding(withAllowedCharacters: allowed) }.joined(separator: "/")
        let tail = encoded + (isFolder && !path.isEmpty ? "/" : "")
        guard let url = URL(string: base.absoluteString + tail) else { throw Failure.badAddress }
        return url
    }

    private func isOurServer(host: String?, port: Int?) -> Bool {
        host?.lowercased() == base.host?.lowercased() && (port ?? 0) == (base.port ?? 0)
    }

    // MARK: Delegate

    /// The password goes only to the server the user named, and is tried once.
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let space = challenge.protectionSpace
        guard [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest].contains(space.authenticationMethod) else {
            return (.performDefaultHandling, nil)
        }
        let port = base.port ?? (base.scheme == "https" ? 443 : 80)
        guard let credentials, challenge.previousFailureCount == 0, space.host.lowercased() == base.host?.lowercased(),
              space.port == port || space.port == 0 else {
            return (.rejectProtectionSpace, nil)
        }
        return (.useCredential, URLCredential(user: credentials.username, password: credentials.password, persistence: .none))
    }

    /// A redirect may stay on this server and scheme only: it must not carry the session to another host or to HTTP.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        guard let url = request.url, url.scheme?.lowercased() == base.scheme?.lowercased(),
              isOurServer(host: url.host, port: url.port) else { return nil }
        return request
    }

    // MARK: Reading a listing

    /// False for anything that could leave the import folder or hide there.
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\")
            && WiFiTransferServer.sanitize(name) == name
    }

    /// The folders and importable files directly inside `directory`, a decoded path. An entry anywhere else, or
    /// with an unsafe name, is dropped.
    static func parse(_ data: Data, directory: String) throws -> [Entry] {
        let delegate = ListingParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() || delegate.full else { throw Failure.badReply }
        let parent = directory.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let entries = delegate.responses.compactMap { item -> Entry? in
            // `path` gives decoded text, so "%2F" and "%2e%2e" fail the checks below.
            guard let path = URL(string: item.href.trimmingCharacters(in: .whitespacesAndNewlines))?.path else { return nil }
            let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard parts.count == parent.count + 1, Array(parts.dropLast()) == parent, let name = parts.last, isSafeName(name) else { return nil }
            guard item.isFolder || ClipboardImporter.romExtensions.contains((name as NSString).pathExtension.lowercased()) else { return nil }
            return Entry(name: name, isFolder: item.isFolder, size: item.isFolder ? nil : item.size)
        }
        return entries.sorted {
            $0.isFolder != $1.isFolder ? $0.isFolder : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

private final class ListingParser: NSObject, XMLParserDelegate {
    struct Item { var href = ""; var isFolder = false; var size: Int64? }
    private static let responseLimit = 5000

    private(set) var responses: [Item] = []
    private(set) var full = false
    private var current: Item?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if name == "response" { current = Item() }
        if name == "collection" { current?.isFolder = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "href": current?.href = text
        case "getcontentlength": current?.size = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines))
        case "response":
            if let current { responses.append(current) }
            current = nil
            if responses.count >= Self.responseLimit {
                full = true
                parser.abortParsing()
            }
        default: break
        }
    }
}
