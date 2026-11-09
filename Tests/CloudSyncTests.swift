import XCTest
@testable import GagaEmu

/// A temporary folder stands in for the iCloud container.
final class CloudSyncTests: XCTestCase {
    private var root: URL!
    private var local: URL { root.appendingPathComponent("local", isDirectory: true) }
    private var remote: URL { root.appendingPathComponent("remote", isDirectory: true) }
    private var manifest: URL { root.appendingPathComponent("CloudSync.json") }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let stamp = "2027-01-15 080000"

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-\(UUID().uuidString)", isDirectory: true)
        for folder in [local, remote] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    @discardableResult
    private func syncOnce(cancelled: Bool = false) -> CloudSyncEngine.Report {
        let progress = Progress()
        if cancelled { progress.cancel() }
        return CloudSyncEngine(manifest: manifest, progress: progress)
            .run(areas: [.init(name: "Saves", local: local, remote: remote)], now: now)
    }

    private func write(_ text: String, _ folder: URL, _ name: String, age: TimeInterval = 100) throws {
        let url = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-age)], ofItemAtPath: url.path)
    }

    private func read(_ folder: URL, _ name: String) -> String? {
        (try? Data(contentsOf: folder.appendingPathComponent(name))).map { String(decoding: $0, as: UTF8.self) }
    }

    func testNewFilesTravelBothWays() throws {
        try write("mine", local, "Game.gba/Game.srm")
        try write("theirs", remote, "Other.gba/States/quick-1.gagastate")
        let report = syncOnce()
        XCTAssertEqual(read(remote, "Game.gba/Game.srm"), "mine")
        XCTAssertEqual(read(local, "Other.gba/States/quick-1.gagastate"), "theirs")
        XCTAssertEqual(report.uploaded, ["Saves/Game.gba/Game.srm"])
        XCTAssertEqual(report.downloaded, ["Saves/Other.gba/States/quick-1.gagastate"])
        XCTAssertEqual(report.conflicts, 0)
    }

    func testOneSidedChangeIsNotAConflict() throws {
        try write("one", local, "a.srm")
        syncOnce()
        try write("two", local, "a.srm", age: 50)
        XCTAssertEqual(syncOnce().conflicts, 0)
        XCTAssertEqual(read(remote, "a.srm"), "two")
        try write("three", remote, "a.srm", age: 40)
        XCTAssertEqual(syncOnce().conflicts, 0)
        XCTAssertEqual(read(local, "a.srm"), "three")
    }

    func testConflictKeepsBothNewestActiveWhenLocalIsNewer() throws {
        try write("old remote", remote, "a.srm", age: 200)
        try write("new local", local, "a.srm", age: 100)
        XCTAssertEqual(syncOnce().conflicts, 1)
        let copy = "a (conflict \(stamp)).srm"
        for side in [local, remote] {
            XCTAssertEqual(read(side, "a.srm"), "new local")
            XCTAssertEqual(read(side, copy), "old remote")
        }
    }

    func testConflictKeepsBothNewestActiveWhenRemoteIsNewer() throws {
        try write("old local", local, "b/States/s.gagastate", age: 200)
        try write("new remote", remote, "b/States/s.gagastate", age: 100)
        XCTAssertEqual(syncOnce().conflicts, 1)
        let copy = "b/States/s (conflict \(stamp)).gagastate"
        for side in [local, remote] {
            XCTAssertEqual(read(side, "b/States/s.gagastate"), "new remote")
            XCTAssertEqual(read(side, copy), "old local")
        }
    }

    func testBothChangedAfterASyncIsAConflict() throws {
        try write("base", local, "a.srm")
        syncOnce()
        try write("device one", local, "a.srm", age: 30)
        try write("device two", remote, "a.srm", age: 20)
        XCTAssertEqual(syncOnce().conflicts, 1)
        XCTAssertEqual(read(local, "a.srm"), "device two")
        XCTAssertEqual(read(remote, "a (conflict \(stamp)).srm"), "device one")
    }

    func testAConflictSettlesAndARepeatChangesNothing() throws {
        try write("x", local, "a.srm", age: 200)
        try write("y", remote, "a.srm", age: 100)
        syncOnce()
        XCTAssertEqual(syncOnce(), CloudSyncEngine.Report())
    }

    func testAnExistingCopyIsNeverReplaced() throws {
        try write("earlier copy", local, "a (conflict \(stamp)).srm")
        try write("earlier copy", remote, "a (conflict \(stamp)).srm")
        try write("x", local, "a.srm", age: 200)
        try write("y", remote, "a.srm", age: 100)
        syncOnce()
        XCTAssertEqual(read(local, "a (conflict \(stamp)).srm"), "earlier copy")
        XCTAssertEqual(read(remote, "a (conflict \(stamp) 2).srm"), "x")
    }

    func testADeletionDoesNotTravel() throws {
        try write("keep", local, "a.srm")
        syncOnce()
        try FileManager.default.removeItem(at: local.appendingPathComponent("a.srm"))
        syncOnce()
        XCTAssertEqual(read(remote, "a.srm"), "keep")
        XCTAssertEqual(read(local, "a.srm"), "keep")
    }

    func testAFileStillInICloudIsNotOverwritten() throws {
        try write("mine", local, "a.srm")
        try write("", remote, ".a.srm.icloud")
        let report = syncOnce()
        XCTAssertEqual(report.pending, 1)
        XCTAssertEqual(report.uploaded, [])
        XCTAssertEqual(read(local, "a.srm"), "mine")
        XCTAssertNil(read(remote, "a.srm"))
    }

    func testTempAndCheatFilesStayHome() throws {
        try write("t", local, ".a.srm.tmp-1")
        try write("c", local, "g/cheats.json")
        XCTAssertEqual(syncOnce(), CloudSyncEngine.Report())
        XCTAssertNil(read(remote, "g/cheats.json"))
    }

    func testACancelledPassTouchesNothing() throws {
        try write("mine", local, "a.srm")
        XCTAssertEqual(syncOnce(cancelled: true), CloudSyncEngine.Report())
        XCTAssertNil(read(remote, "a.srm"))
    }

    func testCopiedFileKeepsItsDate() throws {
        try write("mine", local, "a.srm", age: 500)
        syncOnce()
        let date = try FileManager.default.attributesOfItem(atPath: remote.appendingPathComponent("a.srm").path)[.modificationDate] as? Date
        XCTAssertEqual(date, now.addingTimeInterval(-500))
    }
}
