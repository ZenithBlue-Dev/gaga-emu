import XCTest
@testable import GagaEmu

/// WebDAV source and skin package import. The WebDAV server here is a socket on this device's loopback, so the
/// real client, TLS rules aside, runs without the Local Network prompt.
final class Manic2Tests: GagaTestCase {
    /// Answers each request from `reply`, one request per connection.
    final class LoopbackServer: @unchecked Sendable {
        let port: UInt16
        private let socketFD: Int32

        init(reply: @escaping @Sendable (String) -> (status: String, headers: String, body: Data)) throws {
            let listener = socket(AF_INET, SOCK_STREAM, 0)
            socketFD = listener
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            var size = socklen_t(MemoryLayout<sockaddr_in>.size)
            let bound = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, size) == 0 && getsockname(listener, $0, &size) == 0 }
            }
            guard bound, listen(listener, 8) == 0 else { throw CocoaError(.fileWriteUnknown) }
            port = UInt16(bigEndian: address.sin_port)
            DispatchQueue.global().async {
                while true {
                    let client = accept(listener, nil, nil)
                    guard client >= 0 else { return }
                    var request = Data(), buffer = [UInt8](repeating: 0, count: 4096)
                    while !request.contains(Data("\r\n\r\n".utf8)) {
                        let count = read(client, &buffer, buffer.count)
                        guard count > 0 else { break }
                        request.append(contentsOf: buffer[0..<count])
                    }
                    let answer = reply(String(decoding: request, as: UTF8.self))
                    let head = "HTTP/1.1 \(answer.status)\r\nConnection: close\r\nContent-Length: \(answer.body.count)\r\n\(answer.headers)\r\n"
                    let bytes = [UInt8](Data(head.utf8) + answer.body)
                    _ = write(client, bytes, bytes.count)
                    close(client)
                }
            }
        }

        deinit { close(socketFD) }
    }

    private func listing(_ hrefs: [(String, Bool)]) -> Data {
        let body = hrefs.map { href, folder in
            "<D:response><D:href>\(href)</D:href><D:propstat><D:prop><D:resourcetype>\(folder ? "<D:collection/>" : "")</D:resourcetype><D:getcontentlength>4</D:getcontentlength></D:prop></D:propstat></D:response>"
        }.joined()
        return Data("<?xml version=\"1.0\"?><D:multistatus xmlns:D=\"DAV:\">\(body)</D:multistatus>".utf8)
    }

    /// Read by the device run before the long walks start.
    func testReportFreeSpace() throws {
        let free = try FileManager.default.temporaryDirectory
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        print("GAGA_FREE_BYTES=\(free)")
    }

    func testAddressNeedsTLSUnlessAllowed() throws {
        XCTAssertEqual(try WebDAVClient(address: "nas.local/games", allowPlainHTTP: false, credentials: nil).base.absoluteString, "https://nas.local/games/")
        XCTAssertThrowsError(try WebDAVClient(address: "http://nas.local", allowPlainHTTP: false, credentials: nil)) {
            XCTAssertEqual($0 as? WebDAVClient.Failure, .plainHTTP)
        }
        XCTAssertNoThrow(try WebDAVClient(address: "http://nas.local", allowPlainHTTP: true, credentials: nil))
        XCTAssertThrowsError(try WebDAVClient(address: "ftp://nas.local", allowPlainHTTP: true, credentials: nil))
        XCTAssertEqual(try WebDAVClient(address: "https://me:secret@nas.local", allowPlainHTTP: false, credentials: nil).base.absoluteString, "https://nas.local/")
    }

    func testListingCannotEscapeTheFolder() throws {
        let data = listing([("/dav/", true), ("/dav/Game.gba", false), ("/dav/Sub%20Dir/", true), ("/dav/notes.txt", false),
                            ("/dav/../evil.gba", false), ("/other/Game.gba", false), ("/dav/.hidden.gba", false),
                            ("/dav/a%2Fb.gba", false), ("/dav/%2e%2e/evil.gba", false), ("https://elsewhere.example/dav/Far.gba", false)])
        let entries = try WebDAVClient.parse(data, directory: "/dav/")
        XCTAssertEqual(entries.map(\.name), ["Sub Dir", "Far.gba", "Game.gba"], "A host in an href is ignored: only the path and name are used")
        XCTAssertThrowsError(try WebDAVClient(address: "https://a.b", allowPlainHTTP: false, credentials: nil).url(["..", "x"], isFolder: false))
        let url = try WebDAVClient(address: "https://a.b/dav", allowPlainHTTP: false, credentials: nil).url(["Sub Dir", "G#1.gba"], isFolder: false)
        XCTAssertEqual(url.absoluteString, "https://a.b/dav/Sub%20Dir/G%231.gba")
    }

    func testKeychainRoundTrip() {
        WebDAVCredentials.delete()
        defer { WebDAVCredentials.delete() }
        XCTAssertNil(WebDAVCredentials.load())
        let saved = WebDAVCredentials(username: "gaga", password: "test-only")
        XCTAssertTrue(saved.save())
        XCTAssertEqual(WebDAVCredentials.load(), saved)
    }

    func testBrowseAndDownloadOverLoopback() async throws {
        let rom = Data((0..<4096).map { UInt8($0 & 0xFF) })
        let list = listing([("/dav/", true), ("/dav/Game.gba", false)])
        let server = try LoopbackServer { request in
            guard request.contains("Authorization: Basic Z2FnYTp0ZXN0") else {
                return ("401 Unauthorized", "WWW-Authenticate: Basic realm=\"t\"\r\n", Data())
            }
            if request.hasPrefix("PROPFIND /dav/ ") { return ("207 Multi-Status", "Content-Type: application/xml\r\n", list) }
            if request.hasPrefix("GET /dav/Game.gba ") { return ("200 OK", "", rom) }
            return ("404 Not Found", "", Data())
        }
        let address = "http://127.0.0.1:\(server.port)/dav"
        let client = try WebDAVClient(address: address, allowPlainHTTP: true, credentials: WebDAVCredentials(username: "gaga", password: "test"))
        defer { client.close() }
        let entries = try await client.list([])
        XCTAssertEqual(entries.map(\.name), ["Game.gba"])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("webdav-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let dest = try await client.download(["Game.gba"], into: folder)
        XCTAssertEqual(dest.lastPathComponent, "Game.gba")
        XCTAssertEqual(try Data(contentsOf: dest), rom)

        let denied = try WebDAVClient(address: address, allowPlainHTTP: true, credentials: WebDAVCredentials(username: "x", password: "y"))
        defer { denied.close() }
        do {
            _ = try await denied.list([])
            XCTFail("A wrong password was accepted")
        } catch { XCTAssertEqual(error as? WebDAVClient.Failure, .signIn) }
    }

    func testRedirectToAnotherHostIsRefused() async throws {
        let server = try LoopbackServer { _ in ("302 Found", "Location: http://localhost:1/stolen\r\n", Data()) }
        let client = try WebDAVClient(address: "http://127.0.0.1:\(server.port)/dav", allowPlainHTTP: true, credentials: nil)
        defer { client.close() }
        do {
            _ = try await client.list([])
            XCTFail("The redirect was followed")
        } catch { XCTAssertEqual(error as? WebDAVClient.Failure, .status(302)) }
    }

    // MARK: Skin packages

    private let info = #"""
    {"name":"T","identifier":"a.b","gameTypeIdentifier":"public.aoshuang.game.gba","representations":{"iphone":{"edgeToEdge":{
      "landscape":{"mappingSize":{"width":800,"height":400},"items":[
        {"inputs":{"up":"up","down":"down","left":"left","right":"right"},"frame":{"x":0,"y":100,"width":300,"height":300}},
        {"inputs":["a"],"frame":{"x":700,"y":200,"width":100,"height":100},"extendedEdges":{"top":5}},
        {"inputs":["a","b"],"frame":{"x":600,"y":300,"width":100,"height":100}},
        {"inputs":["menu"],"frame":{"x":400,"y":0,"width":50,"height":50}},
        {"inputs":["restart"],"frame":{"x":0,"y":0,"width":50,"height":50}},
        {"inputs":["start"],"frame":{"x":"bad","y":0,"width":50,"height":50}}]},
      "portrait":{"mappingSize":{"width":400,"height":800},"items":[{"inputs":["start"],"frame":{"x":100,"y":600,"width":100,"height":100}}]}}}}}
    """#

    func testSkinLayoutMapsInputsAndFrames() throws {
        let layout = try TouchSkinEngine.skinPackageLayout(info: Data(info.utf8))
        let land = try XCTUnwrap(layout.landscape)
        XCTAssertEqual(land.map(\.id), ["up", "down", "left", "right", "east", "east+south", "menu"], "Unknown functions and bad frames are dropped")
        XCTAssertEqual(land[4].mask, ControllerManager.Button.east)
        XCTAssertEqual(land[4].frame.minX, 0.875, accuracy: 0.0001)
        XCTAssertEqual(land[6].action, .app(.pauseMenu))
        XCTAssertEqual(layout.portrait?.first?.mask, ControllerManager.Button.start)
    }

    func testSkinFileIsUntrusted() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("skin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        func zip(_ entries: [(name: String, data: Data, size: Int?)]) throws -> URL {
            let url = folder.appendingPathComponent("\(UUID().uuidString).manicskin")
            try ZipImportTests.deflatedZip(entries).write(to: url)
            return url
        }
        XCTAssertNotNil(try TouchSkinEngine.skinPackageLayout(at: zip([("info.json", Data(info.utf8), nil)])).landscape)
        XCTAssertThrowsError(try TouchSkinEngine.skinPackageLayout(at: zip([("../info.json", Data(info.utf8), nil)])), "An entry outside the root is not info.json")
        XCTAssertThrowsError(try TouchSkinEngine.skinPackageLayout(at: zip([("info.json", Data(count: 2 << 20), nil)])), "Over the size limit")
        XCTAssertThrowsError(try TouchSkinEngine.skinPackageLayout(at: zip([("info.json", Data("{}".utf8), nil)])))
        XCTAssertThrowsError(try TouchSkinEngine.skinPackageLayout(info: Data("not json".utf8)))
    }

    func testDiscFilesSkipsTracksBesideSheets() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("discs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["Odd One.cue", "Odd One.bin", "Other.chd", "Note.gba"] {
            FileManager.default.createFile(atPath: folder.appendingPathComponent(name).path, contents: Data())
        }
        XCTAssertEqual(MultiDiscHelper.discFiles(in: folder).map(\.lastPathComponent), ["Odd One.cue", "Other.chd"])
    }
}
