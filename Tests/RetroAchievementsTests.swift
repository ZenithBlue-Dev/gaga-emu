import XCTest
@testable import GagaEmu

/// A fake retroachievements.org and a synthetic set on the mock core's work RAM (NES map, 0xH0010).
@MainActor
final class RetroAchievementsTests: GagaTestCase {
    private let password = "swordfish-not-stored"
    private let token = "FAKETOKEN123"
    private let account = "retroachievements-test-\(UUID().uuidString)"
    private var directory: URL!
    private var skins: TouchSkinEngine!
    private var controllers: ControllerManager!
    private var requests: [String] = []
    private var awards = 0
    private var failAwards = false

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("ra-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        skins = TouchSkinEngine()
        skins.loadDefault()
        controllers = ControllerManager()
        controllers.devices = []
        MockCore_SetMemory(0x10, 0)
    }

    override func tearDown() async throws {
        WebDAVCredentials.delete(account: account)
        try? FileManager.default.removeItem(at: directory)
    }

    private func patch(memory: String = "0xH0010=1") -> String {
        """
        {"Success":true,"GameId":1,"Title":"Fake","ConsoleId":7,"ImageIconUrl":"https://x/i.png","RichPresenceGameId":1,"RichPresencePatch":"",\
        "Sets":[{"AchievementSetId":9,"GameId":1,"Title":null,"Type":"core","ImageIconUrl":"https://x/i.png","Achievements":[\
        {"ID":100,"Title":"First","Description":"Set the byte","Flags":3,"Points":5,"MemAddr":"\(memory)","Author":"t","BadgeName":"1","Created":1,"Modified":1}\
        ],"Leaderboards":[]}]}
        """
    }

    private func makeClient() -> RetroAchievements {
        RetroAchievements(transport: { [weak self] _, post, _, _, reply in
            guard let self else { return }
            let body = post ?? ""
            Task { @MainActor in
                self.requests.append(body)
                let answer: (Int, String)
                if body.contains("r=login2") {
                    answer = (200, #"{"Success":true,"User":"tester","Token":"\#(self.token)","Score":1,"SoftcoreScore":2,"Messages":0}"#)
                } else if body.contains("r=achievementsets") {
                    answer = (200, self.patch())
                } else if body.contains("r=awardachievement") {
                    self.awards += 1
                    answer = self.failAwards ? (-2, "") : (200, #"{"Success":true,"Score":10,"AchievementID":100,"AchievementsRemaining":0}"#)
                } else {
                    answer = (200, #"{"Success":true}"#)
                }
                reply(answer.0, Data(answer.1.utf8))
            }
        }, keychainAccount: account)
    }

    private func signIn(_ client: RetroAchievements) async throws {
        let error: String? = await withCheckedContinuation { go in
            client.signIn(username: "tester", password: password) { go.resume(returning: $0) }
        }
        XCTAssertNil(error)
    }

    private func wait(_ what: String, _ condition: @escaping () -> Bool) async throws {
        for _ in 0..<600 where !condition() { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertTrue(condition(), what)
    }

    private func session(_ client: RetroAchievements?) async throws -> GameSession {
        let rom = directory.appendingPathComponent("game.nes")
        try Data(repeating: 7, count: 32_768).write(to: rom)
        let game = GameItem(id: UUID(), title: "Fake", platformID: "nes", romPath: rom.path, coverPath: nil,
                            coreOverride: "mock", playTime: 0, lastPlayed: nil, isFavorite: false, shaderID: "crt-v1")
        let session = try GameSession(game: game, interface: MockCore_GetInterface()!.pointee, romPath: rom.path,
                                      audio: AudioEngineManager(), controllers: controllers, skins: skins,
                                      bindings: [], shaderID: "crt-v1", respectSilentMode: false)
        session.achievements = client
        try await session.prepare()
        return session
    }

    private func step(_ session: GameSession, frames: Int = 3) {
        for _ in 0..<frames { session.netplayCore?.step(inputs: []) }
    }

    func testTokenNotPasswordPersisted() async throws {
        let client = makeClient()
        try await signIn(client)
        XCTAssertEqual(client.username, "tester")
        let stored = try XCTUnwrap(WebDAVCredentials.load(account: account))
        XCTAssertEqual(stored.password, token)
        XCTAssertNotEqual(stored.password, password)
        let defaults = UserDefaults.standard.dictionaryRepresentation().description
        XCTAssertFalse(defaults.contains(password), "password reached UserDefaults")
        client.signOut()
        XCTAssertNil(WebDAVCredentials.load(account: account))
        XCTAssertNil(client.username)
    }

    func testTransportStaysHTTPSOnly() {
        let security = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any] ?? [:]
        XCTAssertNil(security["NSAllowsArbitraryLoads"], "App Transport Security must stay strict")
    }

    func testSignedOutHasNoFrameHook() async throws {
        let session = try await session(nil)
        XCTAssertNil(session.netplayCore?.onFrameStepped)
        XCTAssertFalse(session.achievementsLoaded)
        session.stop()
    }

    func testUnlockFires() async throws {
        let client = makeClient()
        try await signIn(client)
        let session = try await session(client)
        try await wait("set loaded") { session.achievementsLoaded }
        var unlocked: String?
        client.onEvent = { if case .unlocked(let title, _) = $0 { unlocked = title } }
        step(session)
        XCTAssertNil(unlocked)
        MockCore_SetMemory(0x10, 1)
        step(session)
        try await wait("unlock event") { unlocked != nil }
        XCTAssertEqual(unlocked, "First")
        try await wait("award sent") { self.awards == 1 }
        XCTAssertEqual(client.achievements().first?.unlocked, true)
        session.stop()
    }

    func testFailedAwardRetriesWithoutStallingFrames() async throws {
        failAwards = true
        let client = makeClient()
        try await signIn(client)
        let session = try await session(client)
        try await wait("set loaded") { session.achievementsLoaded }
        step(session) // An achievement must see its condition false before it can fire.
        MockCore_SetMemory(0x10, 1)
        step(session)
        try await wait("first attempt") { self.awards >= 1 }
        let clock = ContinuousClock()
        let spent = clock.measure { step(session, frames: 60) }
        XCTAssertLessThan(spent, .seconds(1), "frames stalled on a dead network")
        failAwards = false
        // rc_client's retry backs off; the idle timer delivers it.
        try await wait("retry reached the server") { self.awards >= 2 }
        session.stop()
    }

    func testHardcoreBlocksStateLoadAndCheats() async throws {
        let client = makeClient()
        try await signIn(client)
        client.setHardcore(true)
        addTeardownBlock { UserDefaults.standard.removeObject(forKey: "retroAchievements.hardcore") }
        let session = try await session(client)
        try await wait("set loaded") { session.achievementsLoaded }
        XCTAssertTrue(session.hardcoreActive)
        let slot = try session.saveState()
        XCTAssertThrowsError(try session.loadState(slot))
        XCTAssertThrowsError(try session.addCheat(name: "x", code: "00000000 0000"))
        session.setRewindHeld(true)
        XCTAssertFalse(session.rewinding)
        client.setHardcore(false)
        session.setHardcore(false)
        XCTAssertFalse(session.hardcoreActive)
        XCTAssertNoThrow(try session.loadState(slot))
        session.stop()
    }
}
