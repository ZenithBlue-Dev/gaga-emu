import Foundation

/// Browses a RomM server the user runs and names. It has WebDAV's rules: no server list, HTTPS unless the user allows
/// plain HTTP, redirects on this server only, and paths built from checked names. Nothing is fetched until tapped.
final class RomMClient: WebDAVClient, @unchecked Sendable {
    static let keychainAccount = "romm"

    struct Platform: Identifiable, Equatable, Decodable {
        let id: Int
        let name: String
    }

    struct Rom: Identifiable, Equatable {
        let id: Int
        let title: String
        let fileName: String
        let size: Int64?
        var path: [String] { ["api", "roms", String(id), "content", fileName] }
    }

    private struct RawRom: Decodable {
        let id: Int
        let platformId: Int?
        let name: String?
        let fsName: String
        let fsSizeBytes: Int64?
        let hasMultipleFiles: Bool?
    }

    private struct Page: Decodable { let items: [RawRom]; let total: Int? }

    private static let pageSize = 200
    /// Same ceiling as a WebDAV listing.
    private static let romLimit = 5000

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// RomM takes HTTP Basic on every request and may not send a challenge first.
    override func makeRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let credentials {
            let token = Data("\(credentials.username):\(credentials.password)".utf8).base64EncodedString()
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func get(_ path: [String], query: [URLQueryItem] = []) async throws -> Data {
        guard var parts = URLComponents(url: try url(path, isFolder: false), resolvingAgainstBaseURL: false) else { throw Failure.badAddress }
        if !query.isEmpty { parts.queryItems = query }
        guard let target = parts.url else { throw Failure.badAddress }
        return try await fetch(makeRequest(target), expected: 200)
    }

    func platforms() async throws -> [Platform] {
        try Self.parsePlatforms(try await get(["api", "platforms"]))
    }

    /// Every page of one platform's games, up to `romLimit`.
    func roms(platform: Int) async throws -> [Rom] {
        var found: [Rom] = []
        var offset = 0
        while offset < Self.romLimit {
            // Newer servers read platform_ids, older ones platform_id; each ignores the other.
            let data = try await get(["api", "roms"], query: [
                .init(name: "platform_ids", value: String(platform)), .init(name: "platform_id", value: String(platform)),
                .init(name: "limit", value: String(Self.pageSize)), .init(name: "offset", value: String(offset))
            ])
            let page = try Self.parseRoms(data, platform: platform)
            found += page.roms
            offset += page.received
            if page.received == 0 || page.received < Self.pageSize || (page.total.map { offset >= $0 } ?? false) { break }
        }
        return found.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    static func parsePlatforms(_ data: Data) throws -> [Platform] {
        guard let list = try? decoder.decode([Platform].self, from: data) else { throw Failure.badReply }
        return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A server's list is untrusted: an entry for another platform, with an unsafe name, or that is not one game
    /// file GagaEmu reads is dropped. `received` counts everything on the page, for paging.
    static func parseRoms(_ data: Data, platform: Int) throws -> (roms: [Rom], received: Int, total: Int?) {
        // Paged on current servers, a bare list on old ones.
        let items: [RawRom], total: Int?
        if let page = try? decoder.decode(Page.self, from: data) {
            (items, total) = (page.items, page.total)
        } else if let list = try? decoder.decode([RawRom].self, from: data) {
            (items, total) = (list, nil)
        } else {
            throw Failure.badReply
        }
        let roms = items.compactMap { item -> Rom? in
            guard item.platformId == nil || item.platformId == platform, item.hasMultipleFiles != true, isSafeName(item.fsName),
                  ClipboardImporter.romExtensions.contains((item.fsName as NSString).pathExtension.lowercased()) else { return nil }
            return Rom(id: item.id, title: item.name?.isEmpty == false ? item.name! : item.fsName, fileName: item.fsName, size: item.fsSizeBytes)
        }
        return (roms, items.count, total)
    }
}
