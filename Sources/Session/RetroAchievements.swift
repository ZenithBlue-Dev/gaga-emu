import Foundation

enum RetroAchievementsError: LocalizedError {
    case hardcoreBlocks(String)
    var errorDescription: String? {
        switch self { case .hardcoreBlocks(let thing): return "\(thing) is off in hardcore mode." }
    }
}

struct AchievementInfo: Identifiable, Equatable {
    let id: UInt32
    let title: String
    let detail: String
    let points: UInt32
    let unlocked: Bool
    /// Empty when the achievement has no measured progress.
    let progress: String
    let percent: Float
}

/// RetroAchievements through rcheevos `rc_client`, for the player's own account. The class exists on one queue:
/// every rc_client call runs on `queue`, and `doFrame` waits for it only while a game is active. A player who has
/// not signed in has no client, and a session gets no frame hook, so nothing here runs.
///
/// The password reaches this class only as a call argument, goes to rc_client as HTTPS POST data and is not
/// kept. The token is what is stored, in the Keychain.
final class RetroAchievements: ObservableObject, @unchecked Sendable {
    enum Event {
        case unlocked(title: String, points: UInt32)
        case offline
        case reconnected
        case reset
        case serverError(String)
    }

    /// One response from the server. Status is HTTP, or `RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR` for no response.
    typealias Transport = (_ url: String, _ post: String?, _ contentType: String?, _ agent: String, _ reply: @escaping (Int, Data) -> Void) -> Void

    static let shared = RetroAchievements()

    /// The signed-in player. Set as soon as a token is found, before the server has confirmed it. Main queue.
    @Published private(set) var username: String?
    /// The game has achievements and `doFrame` is running them. Main queue.
    @Published private(set) var gameLoaded = false
    @Published private(set) var hardcore = UserDefaults.standard.bool(forKey: hardcoreKey)

    /// Delivered on the main queue.
    var onEvent: ((Event) -> Void)?

    private static let hardcoreKey = "retroAchievements.hardcore"
    private let queue = DispatchQueue(label: "com.zenithblue.gagaemu.achievements", qos: .userInitiated)
    private let transport: Transport
    private let keychainAccount: String
    private var client: OpaquePointer?
    private var idleTimer: DispatchSourceTimer?
    private let activeLock = NSLock()
    private var active = false // Guarded by activeLock.

    init(transport: Transport? = nil, keychainAccount: String = "retroachievements") {
        self.transport = transport ?? Self.urlSessionTransport
        self.keychainAccount = keychainAccount
    }

    // MARK: Transport

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()

    private static let retryableStatus = Int(RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR)

    private static let urlSessionTransport: Transport = { url, post, contentType, agent, reply in
        // rc_client only ever builds https URLs for retroachievements.org; this keeps a bad host from getting the POST body.
        guard let target = URL(string: url), target.scheme == "https" else { return reply(Int(RC_API_SERVER_RESPONSE_CLIENT_ERROR), Data()) }
        var request = URLRequest(url: target)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        if let post {
            request.httpMethod = "POST"
            request.httpBody = Data(post.utf8)
            request.setValue(contentType ?? "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        session.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse {
                reply(http.statusCode, data ?? Data())
            } else {
                reply(retryableStatus, Data()) // No response: rc_client keeps an unlock queued and retries it.
            }
        }.resume()
    }

    private var userAgent: String {
        var clause = [CChar](repeating: 0, count: 64)
        if let client { rc_client_get_user_agent_clause(client, &clause, clause.count) }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let system = ProcessInfo.processInfo.operatingSystemVersion
        return "GagaEmu/\(version) (iOS \(system.majorVersion).\(system.minorVersion)) \(String(cString: clause))"
    }

    private static func owner(_ client: OpaquePointer?) -> RetroAchievements {
        Unmanaged<RetroAchievements>.fromOpaque(rc_client_get_userdata(client)!).takeUnretainedValue()
    }

    private func ensureClient() -> OpaquePointer? {
        if let client { return client }
        let serverCall: rc_client_server_call_t = { request, callback, data, client in
            let owner = RetroAchievements.owner(client)
            guard let request = request?.pointee else { return }
            let post = request.post_data.map { String(cString: $0) }
            let type = request.content_type.map { String(cString: $0) }
            owner.transport(String(cString: request.url), post, type, owner.userAgent) { status, body in
                owner.queue.async {
                    body.withUnsafeBytes { raw in
                        var response = rc_api_server_response_t()
                        response.body = raw.bindMemory(to: CChar.self).baseAddress
                        response.body_length = raw.count
                        response.http_status_code = Int32(status)
                        callback?(&response, data)
                    }
                }
            }
        }
        guard let created = rc_client_create(gaga_cheevos_read_memory, serverCall) else { return nil }
        rc_client_set_userdata(created, Unmanaged.passUnretained(self).toOpaque())
        rc_client_set_event_handler(created) { event, client in
            guard let event = event?.pointee else { return }
            RetroAchievements.owner(client).handle(event)
        }
        rc_client_set_hardcore_enabled(created, hardcore ? 1 : 0)
        client = created
        return created
    }

    private func handle(_ event: rc_client_event_t) {
        let delivered: Event?
        switch Int(event.type) {
        case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED:
            delivered = event.achievement.map { .unlocked(title: String(cString: $0.pointee.title), points: $0.pointee.points) }
        case RC_CLIENT_EVENT_DISCONNECTED: delivered = .offline
        case RC_CLIENT_EVENT_RECONNECTED: delivered = .reconnected
        case RC_CLIENT_EVENT_RESET: delivered = .reset
        case RC_CLIENT_EVENT_SERVER_ERROR:
            delivered = event.server_error.map { .serverError(String(cString: $0.pointee.error_message)) }
        default: delivered = nil
        }
        guard let delivered else { return }
        DispatchQueue.main.async { [self] in onEvent?(delivered) }
    }

    /// Boxes a Swift closure through rc_client's C callback.
    private final class Done {
        let run: (Int32, String?) -> Void
        init(_ run: @escaping (Int32, String?) -> Void) { self.run = run }
        static let callback: rc_client_callback_t = { result, message, _, userdata in
            guard let userdata else { return }
            Unmanaged<Done>.fromOpaque(userdata).takeRetainedValue().run(result, message.map { String(cString: $0) })
        }
        func retained() -> UnsafeMutableRawPointer { Unmanaged.passRetained(self).toOpaque() }
    }

    // MARK: Account

    /// Reads the Keychain. Makes no network call and no client when there is no token.
    func restoreSession() {
        guard let saved = WebDAVCredentials.load(account: keychainAccount) else { return }
        username = saved.username
        queue.async { [self] in
            guard let client = ensureClient() else { return }
            let done = Done { [self] result, _ in
                guard Int(result) == RC_INVALID_CREDENTIALS || Int(result) == RC_EXPIRED_TOKEN else { return }
                WebDAVCredentials.delete(account: keychainAccount)
                DispatchQueue.main.async { self.username = nil }
            }
            rc_client_begin_login_with_token(client, saved.username, saved.password, Done.callback, done.retained())
        }
    }

    /// Completion runs on the main queue with nil on success, otherwise a message for the player.
    func signIn(username name: String, password: String, completion: @escaping (String?) -> Void) {
        queue.async { [self] in
            guard let client = ensureClient() else { return DispatchQueue.main.async { completion("Could not start RetroAchievements.") } }
            let done = Done { [self] result, message in
                guard result == RC_OK, let user = rc_client_get_user_info(client)?.pointee else {
                    let text = message ?? "Could not sign in."
                    return DispatchQueue.main.async { completion(text) }
                }
                let login = String(cString: user.username)
                // shortcut: the shared Keychain record names its secret `password`; here it holds the token. Rename if a third kind of account appears.
                let saved = WebDAVCredentials(username: login, password: String(cString: user.token)).save(account: keychainAccount)
                DispatchQueue.main.async {
                    self.username = login
                    completion(saved ? nil : "Could not save the sign-in to the Keychain.")
                }
            }
            rc_client_begin_login_with_password(client, name, password, Done.callback, done.retained())
        }
    }

    func signOut() {
        WebDAVCredentials.delete(account: keychainAccount)
        username = nil
        queue.async { [self] in if let client { rc_client_logout(client) } }
    }

    func setHardcore(_ on: Bool) {
        hardcore = on
        UserDefaults.standard.set(on, forKey: Self.hardcoreKey)
        queue.async { [self] in if let client { rc_client_set_hardcore_enabled(client, on ? 1 : 0) } }
    }

    // MARK: Game

    /// Console for a library system ID, nil where RetroAchievements has none.
    static func consoleID(platform: String) -> UInt32? {
        let consoles: [String: Int] = [
            "nes": RC_CONSOLE_NINTENDO, "snes": RC_CONSOLE_SUPER_NINTENDO, "gb": RC_CONSOLE_GAMEBOY, "gbc": RC_CONSOLE_GAMEBOY_COLOR,
            "gba": RC_CONSOLE_GAMEBOY_ADVANCE, "n64": RC_CONSOLE_NINTENDO_64, "nds": RC_CONSOLE_NINTENDO_DS, "n3ds": RC_CONSOLE_NINTENDO_3DS,
            "vb": RC_CONSOLE_VIRTUAL_BOY, "pokemini": RC_CONSOLE_POKEMON_MINI, "ps1": RC_CONSOLE_PLAYSTATION, "psp": RC_CONSOLE_PSP,
            "megadrive": RC_CONSOLE_MEGA_DRIVE, "megacd": RC_CONSOLE_SEGA_CD, "sega32x": RC_CONSOLE_SEGA_32X, "saturn": RC_CONSOLE_SATURN,
            "dreamcast": RC_CONSOLE_DREAMCAST, "mastersystem": RC_CONSOLE_MASTER_SYSTEM, "gamegear": RC_CONSOLE_GAME_GEAR,
            "sg1000": RC_CONSOLE_SG1000, "pce": RC_CONSOLE_PC_ENGINE, "ngp": RC_CONSOLE_NEOGEO_POCKET, "ws": RC_CONSOLE_WONDERSWAN,
            "arcade": RC_CONSOLE_ARCADE, "dos": RC_CONSOLE_MS_DOS,
        ]
        return consoles[platform].map(UInt32.init)
    }

    private func setActive(_ on: Bool) {
        activeLock.lock()
        active = on
        activeLock.unlock()
    }

    /// Hashes the file on `queue`, off the emulation thread. `loaded` runs on the main queue.
    func startGame(path: String, console: UInt32, loaded: @escaping (Bool) -> Void) {
        queue.async { [self] in
            guard let client = ensureClient() else { return DispatchQueue.main.async { loaded(false) } }
            let done = Done { [self] result, _ in
                let ok = result == RC_OK && rc_client_has_achievements(client) != 0
                setActive(ok)
                if ok { startIdleTimer() }
                DispatchQueue.main.async {
                    self.gameLoaded = ok
                    loaded(ok)
                }
            }
            rc_client_begin_identify_and_load_game(client, console, path, nil, 0, Done.callback, done.retained())
        }
    }

    /// Keeps pings and queued unlocks moving while the game is paused, and while no frame is running.
    private func startIdleTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [self] in if let client { rc_client_idle(client) } }
        timer.resume()
        idleTimer = timer
    }

    /// Call before the core's instance is destroyed.
    func endGame() {
        activeLock.lock()
        let wasActive = active
        active = false
        activeLock.unlock()
        queue.sync {
            idleTimer?.cancel()
            idleTimer = nil
            if let client {
                // rc_client_unload_game clears client->game before raising a pending mastery event, a crash at v12.5.0
                // if the last award's reply arrived since the last frame. A frame here raises it first.
                if wasActive { rc_client_do_frame(client) }
                rc_client_unload_game(client)
            }
            gaga_cheevos_memory_destroy()
        }
        DispatchQueue.main.async { self.gameLoaded = false }
    }

    /// One emulated frame, on the core's queue. rc_client does no I/O here: server calls leave through URLSession
    /// and a failed one only re-queues, so a dead network cannot hold the frame.
    func doFrame() {
        activeLock.lock()
        let on = active
        activeLock.unlock()
        guard on else { return }
        queue.sync { if let client { rc_client_do_frame(client) } }
    }

    /// After a core reset, or to finish enabling hardcore.
    func reset() { queue.async { [self] in if let client { rc_client_reset(client) } } }

    /// shortcut: progress is not stored in save states, so hit counters restart after a load or rewind. Store `rc_client_serialize_progress` in the state file to keep them.
    func stateChanged() { queue.async { [self] in if let client { _ = rc_client_deserialize_progress(client, nil) } } }

    /// False while hardcore's pause limit applies.
    func canPause() -> Bool {
        queue.sync {
            guard let client else { return true }
            var remaining: UInt32 = 0
            return rc_client_can_pause(client, &remaining) != 0
        }
    }

    func achievements() -> [AchievementInfo] {
        queue.sync {
            guard let client, let list = rc_client_create_achievement_list(client, Int32(RC_CLIENT_ACHIEVEMENT_CATEGORY_CORE),
                                                                         Int32(RC_CLIENT_ACHIEVEMENT_LIST_GROUPING_PROGRESS)) else { return [] }
            defer { rc_client_destroy_achievement_list(list) }
            var result: [AchievementInfo] = []
            for b in 0..<Int(list.pointee.num_buckets) {
                let bucket = list.pointee.buckets[b]
                for a in 0..<Int(bucket.num_achievements) {
                    guard let item = bucket.achievements[a]?.pointee else { continue }
                    result.append(AchievementInfo(
                        id: item.id, title: String(cString: item.title), detail: String(cString: item.description),
                        points: item.points, unlocked: item.unlocked != 0,
                        progress: withUnsafeBytes(of: item.measured_progress) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) },
                        percent: item.measured_percent))
                }
            }
            return result
        }
    }
}
