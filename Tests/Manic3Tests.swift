import XCTest
@testable import GagaEmu

/// RomM parsing and signing, the download queue, the UPS creator and the alternate icons.
final class Manic3Tests: GagaTestCase {
    func testUPSCreatorRoundTrips() throws {
        let source = Data((0..<4096).map { UInt8($0 & 0xFF) })
        var longer = source
        longer[10] ^= 0x5A
        longer[11] ^= 0x01
        longer[3000] = longer[3000] &+ 1
        longer.append(contentsOf: [1, 0, 2, 0, 0, 3])
        for (from, to) in [(source, longer), (longer, source), (source, source), (Data(), source)] {
            let patch = try RomPatcher.createUPS(from: from, to: to)
            XCTAssertEqual(RomPatcher.format(of: patch), .ups)
            XCTAssertEqual(try RomPatcher.apply(patch, to: from), to)
        }
    }

    func testRomMListDropsUnsafeEntries() throws {
        let json = Data("""
        {"items":[
          {"id":1,"platform_id":7,"name":"Good","fs_name":"Good.gba","fs_size_bytes":12},
          {"id":2,"platform_id":7,"name":"Escape","fs_name":"../../evil.gba"},
          {"id":3,"platform_id":7,"name":"Slash","fs_name":"a/b.gba"},
          {"id":4,"platform_id":8,"name":"Other system","fs_name":"Other.gba"},
          {"id":5,"platform_id":7,"name":"Folder","fs_name":"Set","has_multiple_files":true},
          {"id":6,"platform_id":7,"name":"Note","fs_name":"Readme.txt"}
        ],"total":6}
        """.utf8)
        let page = try RomMClient.parseRoms(json, platform: 7)
        XCTAssertEqual(page.roms.map(\.id), [1])
        XCTAssertEqual(page.received, 6)
        XCTAssertEqual(page.total, 6)
        XCTAssertThrowsError(try RomMClient.parseRoms(Data("<html>".utf8), platform: 7))
        XCTAssertEqual(try RomMClient.parseRoms(Data(#"[{"id":9,"fs_name":"Old.gba"}]"#.utf8), platform: 7).roms.map(\.fileName), ["Old.gba"])
    }

    func testRomMKeepsWebDAVRules() throws {
        XCTAssertThrowsError(try RomMClient(address: "http://example.test", allowPlainHTTP: false, credentials: nil))
        let client = try RomMClient(address: "https://romm.test", allowPlainHTTP: false,
                                    credentials: WebDAVCredentials(username: "a", password: "b"))
        defer { client.close() }
        let rom = RomMClient.Rom(id: 3, title: "T", fileName: "My Game.gba", size: nil)
        let url = try client.url(rom.path, isFolder: false)
        XCTAssertEqual(url.absoluteString, "https://romm.test/api/roms/3/content/My%20Game.gba")
        XCTAssertEqual(client.makeRequest(url).value(forHTTPHeaderField: "Authorization"), "Basic YTpi")
        XCTAssertThrowsError(try client.url(["api", "..", "x"], isFolder: false))
        let webdav = try WebDAVClient(address: "https://nas.test", allowPlainHTTP: false, credentials: WebDAVCredentials(username: "a", password: "b"))
        defer { webdav.close() }
        XCTAssertNil(webdav.makeRequest(url).value(forHTTPHeaderField: "Authorization"))
    }

    /// The whole path over this device's loopback: sign-in, platforms, a paged list, then a queued download.
    @MainActor func testRomMBrowseAndQueuedDownloadOverLoopback() async throws {
        let rom = Data((0..<4096).map { UInt8($0 & 0xFF) })
        let platforms = Data(#"[{"id":7,"name":"GBA"}]"#.utf8)
        let games = Data(#"{"items":[{"id":3,"platform_id":7,"name":"Game","fs_name":"Game.gba","fs_size_bytes":4096}],"total":1}"#.utf8)
        let server = try Manic2Tests.LoopbackServer { request in
            guard request.contains("Authorization: Basic Z2FnYTp0ZXN0") else { return ("401 Unauthorized", "", Data()) }
            if request.hasPrefix("GET /api/platforms ") { return ("200 OK", "", platforms) }
            if request.hasPrefix("GET /api/roms?") { return ("200 OK", "", games) }
            if request.hasPrefix("GET /api/roms/3/content/Game.gba ") { return ("200 OK", "", rom) }
            return ("404 Not Found", "", Data())
        }
        let address = "http://127.0.0.1:\(server.port)"
        let client = try RomMClient(address: address, allowPlainHTTP: true, credentials: WebDAVCredentials(username: "gaga", password: "test"))
        let systems = try await client.platforms()
        XCTAssertEqual(systems.map(\.name), ["GBA"])
        let found = try await client.roms(platform: 7)
        XCTAssertEqual(found.map(\.fileName), ["Game.gba"])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("romm-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let queue = DownloadQueue()
        let done = expectation(description: "download finished")
        let path = found[0].path
        queue.add(key: "one", name: "Game.gba", client: client, run: { try await client.download(path, into: folder) }, finish: { file in
            XCTAssertEqual(try? Data(contentsOf: file), rom)
            done.fulfill()
            return nil
        })
        queue.release(client) // As the sheet does on closing: the download must still finish.
        await fulfillment(of: [done], timeout: 20)
        let denied = try RomMClient(address: address, allowPlainHTTP: true, credentials: WebDAVCredentials(username: "x", password: "y"))
        defer { denied.close() }
        do {
            _ = try await denied.platforms()
            XCTFail("A wrong password was accepted")
        } catch { XCTAssertEqual(error as? WebDAVClient.Failure, .signIn) }
    }

    func testRomMSignInIsKeptApartFromWebDAV() {
        defer { WebDAVCredentials.delete(account: RomMClient.keychainAccount) }
        let saved = WebDAVCredentials.load()
        XCTAssertTrue(WebDAVCredentials(username: "r", password: "p").save(account: RomMClient.keychainAccount))
        XCTAssertEqual(WebDAVCredentials.load(), saved)
        XCTAssertEqual(WebDAVCredentials.load(account: RomMClient.keychainAccount)?.username, "r")
    }

    @MainActor func testQueueRunsOneAtATimeAndCancels() async throws {
        let queue = DownloadQueue()
        let gate = AsyncStream<Void>.makeStream()
        let finished = expectation(description: "second finished")
        queue.add(key: "a", name: "a", client: nil, run: {
            for await _ in gate.stream { break }
            return URL(fileURLWithPath: "/a")
        }, finish: { _ in "a done" })
        queue.add(key: "a", name: "duplicate", client: nil, run: { throw CancellationError() }, finish: { _ in nil })
        queue.add(key: "b", name: "b", client: nil, run: { URL(fileURLWithPath: "/b") }, finish: { _ in
            finished.fulfill()
            return "b done"
        })
        queue.add(key: "c", name: "c", client: nil, run: { XCTFail("cancelled job ran"); return URL(fileURLWithPath: "/c") }, finish: { _ in nil })
        XCTAssertEqual(queue.jobs.map(\.name), ["a", "b", "c"])
        XCTAssertEqual(queue.status(of: "a"), .active)
        XCTAssertEqual(queue.status(of: "b"), .waiting)
        queue.cancel(queue.jobs[2].id)
        gate.continuation.yield()
        await fulfillment(of: [finished], timeout: 5)
        for _ in 0..<100 where !queue.jobs.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(queue.jobs.isEmpty)
        XCTAssertEqual(queue.note, "b done")
    }

    @MainActor func testQueueKeepsAFailureAndCancelsTheActiveJob() async throws {
        let queue = DownloadQueue()
        queue.add(key: "bad", name: "bad", client: nil, run: { throw WebDAVClient.Failure.signIn }, finish: { _ in nil })
        for _ in 0..<100 where queue.status(of: "bad") == .active { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(queue.status(of: "bad"), .failed(WebDAVClient.Failure.signIn.localizedDescription))
        queue.add(key: "slow", name: "slow", client: nil, run: {
            try await Task.sleep(for: .seconds(60))
            return URL(fileURLWithPath: "/s")
        }, finish: { _ in nil })
        for _ in 0..<100 where queue.status(of: "slow") != .active { try await Task.sleep(for: .milliseconds(10)) }
        queue.cancel(queue.jobs[1].id)
        for _ in 0..<200 where queue.status(of: "slow") != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(queue.status(of: "slow"))
    }

    @MainActor func testEveryAlternateIconIsInTheBundle() throws {
        XCTAssertTrue(UIApplication.shared.supportsAlternateIcons)
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let alternates = try XCTUnwrap(icons?["CFBundleAlternateIcons"] as? [String: Any])
        for choice in AppIconPicker.choices {
            XCTAssertNotNil(UIImage(named: choice.preview), choice.preview)
            if let icon = choice.icon { XCTAssertNotNil(alternates[icon], icon) }
        }
    }

    func testPreviewImageTakesAPictureAndGoesBack() {
        let manager = ShaderManager.shared
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 100)).image { _ in }
        XCTAssertTrue(manager.setPreviewImage(image))
        XCTAssertTrue(manager.setPreviewImage(nil))
    }
}
