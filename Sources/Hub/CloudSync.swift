import CryptoKit
import Foundation
import UIKit

/// One two-way pass between local folders and folders in the iCloud container. It never deletes a file on either
/// side, so a deletion does not travel: a file removed on one device comes back from the other.
///
/// shortcut: deletions do not propagate, add tombstones if players ask for it.
///
/// A plain folder stands in for the container in tests. Only a real container has placeholders and file versions.
final class CloudSyncEngine: @unchecked Sendable {
    struct Area {
        let name: String
        let local: URL
        let remote: URL
    }

    struct Report: Equatable {
        var uploaded: [String] = []
        var downloaded: [String] = []
        var conflicts = 0
        /// In iCloud but not on this device yet. Asked for, and left for a later pass.
        var pending = 0
        var failed = 0
    }

    /// What both sides held after the last pass. Without it two different files are a conflict, never a guess.
    struct Entry: Codable, Equatable {
        var hash: String
        var localSize: Int64
        var localDate: Date
        var remoteSize: Int64
        var remoteDate: Date
    }

    private struct Stat {
        let size: Int64
        let date: Date
        var pending = false
        var versions = false
    }

    private let manifestURL: URL
    private let progress: Progress
    private let fm = FileManager.default
    private var manifest: [String: Entry]
    private var report = Report()

    /// `progress` cancelled stops the pass between files, each of which is placed whole.
    init(manifest: URL, progress: Progress = Progress()) {
        manifestURL = manifest
        self.progress = progress
        self.manifest = (try? Data(contentsOf: manifest)).flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
    }

    func run(areas: [Area], now: Date = Date()) -> Report {
        // A conflict leaves its older copy on one side, and a second pass carries it to the other.
        for _ in 0..<2 {
            let conflicts = report.conflicts
            areas.forEach { pass($0, now: now) }
            if report.conflicts == conflicts || progress.isCancelled { break }
        }
        if let data = try? JSONEncoder().encode(manifest) { try? AtomicFile.write(data, to: manifestURL) }
        return report
    }

    private func pass(_ area: Area, now: Date) {
        let local = list(area.local), remote = list(area.remote)
        for relative in Set(local.keys).union(remote.keys).sorted() {
            if progress.isCancelled { return }
            do {
                try sync(relative, area, local: local[relative], remote: remote[relative], now: now)
            } catch {
                report.failed += 1
            }
        }
    }

    /// Files under `root` by relative path. Temp files, hidden folders and each game's cheat list stay out. A
    /// `.name.icloud` placeholder counts as `name`, not yet here.
    private func list(_ root: URL) -> [String: Stat] {
        var files: [String: Stat] = [:]
        guard let walker = fm.enumerator(atPath: root.path) else { return files }
        for case let relative as String in walker {
            let parts = relative.split(separator: "/").map(String.init)
            guard let name = parts.last, !parts.dropLast().contains(where: { $0.hasPrefix(".") }) else { continue }
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = (parts.dropLast() + [String(name.dropFirst().dropLast(7))]).joined(separator: "/")
                files[real] = Stat(size: 0, date: .distantPast, pending: true)
                continue
            }
            guard !name.hasPrefix("."), !name.contains(".tmp-"), name != "cheats.json" else { continue }
            let url = root.appendingPathComponent(relative)
            guard let attributes = try? fm.attributesOfItem(atPath: url.path), attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? Int64, let date = attributes[.modificationDate] as? Date else { continue }
            let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemHasUnresolvedConflictsKey])
            let status = values?.ubiquitousItemDownloadingStatus
            files[relative] = Stat(size: size, date: date, pending: status != nil && status != .current,
                                   versions: values?.ubiquitousItemHasUnresolvedConflicts == true)
        }
        return files
    }

    private func sync(_ relative: String, _ area: Area, local: Stat?, remote: Stat?, now: Date) throws {
        let key = "\(area.name)/\(relative)"
        let localURL = area.local.appendingPathComponent(relative), remoteURL = area.remote.appendingPathComponent(relative)
        if remote?.pending == true {
            try? fm.startDownloadingUbiquitousItem(at: remoteURL)
            report.pending += 1
            return
        }
        // Two devices wrote before iCloud could tell them apart. The next pass sees the settled file.
        if remote?.versions == true {
            try settleVersions(remoteURL, root: area, relative: relative, now: now)
            return
        }

        let entry = manifest[key]
        if let local, let remote, let entry, Self.matches(local, entry.localSize, entry.localDate),
           Self.matches(remote, entry.remoteSize, entry.remoteDate) { return }
        let localHash = try local.map { stat -> String in
            if let entry, Self.matches(stat, entry.localSize, entry.localDate) { return entry.hash }
            return try Self.hash(localURL)
        }
        let remoteHash = try remote.map { stat -> String in
            if let entry, Self.matches(stat, entry.remoteSize, entry.remoteDate) { return entry.hash }
            return try reading(remoteURL, Self.hash)
        }

        switch (localHash, remoteHash, local, remote) {
        case let (l?, r?, _, _) where l == r:
            break
        case (_?, nil, _, _):
            try upload(localURL, to: remoteURL, key)
        case (nil, _?, _, _):
            try download(remoteURL, to: localURL, key)
        case let (l?, _?, _, _) where l == entry?.hash:
            try download(remoteURL, to: localURL, key)
        case let (_?, r?, _, _) where r == entry?.hash:
            try upload(localURL, to: remoteURL, key)
        case let (_, _, l?, r?):
            // Copy the older first: a failure after this line costs an extra copy, never a save.
            let name = copyName(relative, area, now: now)
            if l.date >= r.date {
                try writing(area.remote.appendingPathComponent(name)) { try self.place(remoteURL, at: $0) }
                try upload(localURL, to: remoteURL, key)
            } else {
                try place(localURL, at: area.local.appendingPathComponent(name))
                try download(remoteURL, to: localURL, key)
            }
            report.conflicts += 1
        default:
            return
        }
        try record(key, localURL, remoteURL)
    }

    private func upload(_ local: URL, to remote: URL, _ key: String) throws {
        try writing(remote) { try self.place(local, at: $0) }
        report.uploaded.append(key)
    }

    private func download(_ remote: URL, to local: URL, _ key: String) throws {
        try reading(remote) { try self.place($0, at: local) }
        report.downloaded.append(key)
    }

    private func record(_ key: String, _ local: URL, _ remote: URL) throws {
        let l = try fm.attributesOfItem(atPath: local.path), r = try fm.attributesOfItem(atPath: remote.path)
        guard let localSize = l[.size] as? Int64, let localDate = l[.modificationDate] as? Date,
              let remoteSize = r[.size] as? Int64, let remoteDate = r[.modificationDate] as? Date else { return }
        manifest[key] = Entry(hash: try Self.hash(local), localSize: localSize, localDate: localDate,
                              remoteSize: remoteSize, remoteDate: remoteDate)
    }

    /// The newest version becomes the file, and every other version stays as a named copy.
    private func settleVersions(_ url: URL, root: Area, relative: String, now: Date) throws {
        try writing(url) { url in
            guard let current = NSFileVersion.currentVersionOfItem(at: url),
                  let others = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !others.isEmpty else { return }
            let all = ([current] + others).sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
            for older in all.dropFirst() {
                let name = self.copyName(relative, root, now: now)
                try self.place(older.url, at: root.remote.appendingPathComponent(name))
                self.report.conflicts += 1
            }
            if all[0] !== current { try all[0].replaceItem(at: url, options: []) }
            others.forEach { $0.isResolved = true }
            try NSFileVersion.removeOtherVersionsOfItem(at: url)
        }
    }

    /// One date for the whole pass, so a state and its thumbnail get the same stem and stay a pair.
    private func copyName(_ relative: String, _ area: Area, now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        let url = URL(fileURLWithPath: "/" + relative), ext = url.pathExtension
        let folder = (relative as NSString).deletingLastPathComponent, stem = url.deletingPathExtension().lastPathComponent
        var number = 1
        while true {
            let suffix = number == 1 ? "" : " \(number)"
            let file = "\(stem) (conflict \(formatter.string(from: now))\(suffix))" + (ext.isEmpty ? "" : ".\(ext)")
            let name = folder.isEmpty ? file : "\(folder)/\(file)"
            if !fm.fileExists(atPath: area.local.appendingPathComponent(name).path),
               !fm.fileExists(atPath: area.remote.appendingPathComponent(name).path) { return name }
            number += 1
        }
    }

    /// Copy beside the destination, then rename: a failure or a kill leaves the old file whole. The copy keeps the
    /// source's date, which conflict handling and the save slot list depend on.
    private func place(_ source: URL, at destination: URL) throws {
        let folder = destination.deletingLastPathComponent()
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let temp = folder.appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        try fm.copyItem(at: source, to: temp)
        guard rename(temp.path, destination.path) == 0 else {
            let code = errno
            try? fm.removeItem(at: temp)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
    }

    private func reading<T>(_ url: URL, _ body: (URL) throws -> T) throws -> T {
        var failure: NSError?, result: Result<T, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &failure) { url in result = Result { try body(url) } }
        if let failure { throw failure }
        guard let result else { throw POSIXError(.EIO) }
        return try result.get()
    }

    private func writing(_ url: URL, _ body: (URL) throws -> Void) throws {
        var failure: NSError?, result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &failure) { url in result = Result { try body(url) } }
        if let failure { throw failure }
        guard let result else { throw POSIXError(.EIO) }
        try result.get()
    }

    private static func matches(_ stat: Stat, _ size: Int64, _ date: Date) -> Bool { stat.size == size && stat.date == date }

    private static func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { digest.update(data: chunk) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// The iCloud Sync switch in Settings: one pass at a time, off the main thread, and never while a game holds its
/// files. `AppState.syncCloud` decides when a pass may start.
@MainActor
final class CloudSync: ObservableObject {
    nonisolated static let containerID = "iCloud.com.zenithblue.gagaemu"

    enum Status: Equatable {
        case off, signedOut, unavailable, syncing, upToDate, waiting(Int), failed(Int)

        var text: String {
            switch self {
            case .off: return String(localized: "Off")
            case .signedOut: return String(localized: "Sign in to iCloud in the Settings app")
            case .unavailable: return String(localized: "iCloud is not available")
            case .syncing: return String(localized: "Syncing")
            case .upToDate: return String(localized: "Up to date")
            case .waiting(let count): return String(localized: "Waiting for \(count) from iCloud")
            case .failed(let count): return String(localized: "\(count) could not sync, will retry")
            }
        }
    }

    @Published private(set) var status = Status.off
    /// Called when something changed in iCloud or a request arrived during a pass.
    var rerun: (() -> Void)?

    private var pass: Task<Void, Never>?
    private var progress: Progress?
    private var again = false
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var debounce: Task<Void, Never>?
    private var includesROMs = false

    func sync(saves: URL, roms: URL, includingROMs: Bool, manifest: URL, downloadedROMs: @escaping ([String]) -> Void) {
        if pass != nil {
            again = true
            return
        }
        // No identity is signed out or iCloud Drive off. The call needs no entitlement and cannot crash.
        guard FileManager.default.ubiquityIdentityToken != nil else {
            status = .signedOut
            return
        }
        status = .syncing
        includesROMs = includingROMs
        let progress = Progress()
        self.progress = progress
        // Leaving the app gives a pass only seconds. Whatever is unfinished waits for the next one.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "iCloud Sync") { progress.cancel() }
        pass = Task {
            let report = await Task.detached(priority: .utility) { () -> CloudSyncEngine.Report? in
                guard let container = FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID) else { return nil }
                let documents = container.appendingPathComponent("Documents", isDirectory: true)
                var areas = [CloudSyncEngine.Area(name: "Saves", local: saves, remote: documents.appendingPathComponent("Saves", isDirectory: true))]
                if includingROMs { areas.append(.init(name: "ROMs", local: roms, remote: documents.appendingPathComponent("ROMs", isDirectory: true))) }
                return CloudSyncEngine(manifest: manifest, progress: progress).run(areas: areas)
            }.value
            pass = nil
            self.progress = nil
            UIApplication.shared.endBackgroundTask(backgroundTask)
            guard let report else {
                status = .unavailable
                return
            }
            status = report.failed > 0 ? .failed(report.failed) : report.pending > 0 ? .waiting(report.pending) : .upToDate
            startWatching()
            downloadedROMs(report.downloaded.filter { $0.hasPrefix("ROMs/") }.map { String($0.dropFirst(5)) })
            if again {
                again = false
                rerun?()
            }
        }
    }

    /// Cancels the running pass and waits for it, at most one file. Called before a game opens its files.
    func finish() async {
        again = false
        progress?.cancel()
        await pass?.value
    }

    func turnOff() {
        again = false
        progress?.cancel()
        stopWatching()
        status = .off
    }

    /// Learns of changes from other devices, and asks for files iCloud has listed but not fetched.
    private func startWatching() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.queryChanged() }
            })
        }
        self.query = query
        query.start()
    }

    private func stopWatching() {
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        debounce?.cancel()
    }

    private func queryChanged() {
        guard let query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        for case let item as NSMetadataItem in query.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  includesROMs || !url.path.contains("/Documents/ROMs/"),
                  item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String != NSMetadataUbiquitousItemDownloadingStatusCurrent
            else { continue }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self?.rerun?() }
        }
    }
}
