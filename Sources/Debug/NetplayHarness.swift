#if DEBUG
import Combine
import Foundation

/// Drives Play Nearby between two devices with no taps, for a device run. Debug builds only.
///
/// `-GagaNetplay host` or `-GagaNetplay join`. Options: `-GagaNetplayCore nestopia` (default),
/// `-GagaNetplayROM <path, relative to Documents>` (default: the core's generated test ROM), `-GagaNetplayFrames 3600`,
/// `-GagaNetplayMismatch YES` (one byte added to the test ROM, so the content hash differs and pairing must be refused).
///
/// The host accepts the code by itself; the joiner connects to the first host it finds. Port 1 holds A on a
/// script from the host, port 2 holds B from the joiner. Logs `[gaga-netplay]` lines: both codes, `frame=<n>
/// hash=<h>` every 60 frames (the state at the start of that frame), the buttons each port ran, ping and stalls
/// each second, and how it ended. The host leaves after the frames; each side exits a few seconds after it ends.
@MainActor
final class NetplayHarness {
    private static var running: NetplayHarness?
    private let net: NetplaySession
    private let frames: Int
    private let probe = Probe()
    private var watches: Set<AnyCancellable> = []
    private var ticker: Timer?
    private var hooked = false

    /// Core-queue counters, read on the main actor for the summary.
    private final class Probe: @unchecked Sendable {
        let lock = NSLock()
        var hashed = -1, stalls = 0, frame = 0, hostOnPort1 = 0, joinerOnPort2 = 0, crossed = 0
    }

    static let hostButton = UInt32(GAGA_BTN_EAST.rawValue)
    static let joinerButton = UInt32(GAGA_BTN_SOUTH.rawValue)

    /// Held for a stretch, released for a stretch, at different rates on each phone.
    nonisolated static func script(frame: Int, isHost: Bool) -> UInt32 {
        isHost ? (frame / 30 % 2 == 0 ? hostButton : 0) : (frame / 45 % 2 == 1 ? joinerButton : 0)
    }

    private init(net: NetplaySession, frames: Int) {
        self.net = net
        self.frames = frames
    }

    /// Flushed, since stdout to a file (a Mac run) is fully buffered.
    nonisolated static func log(_ text: String) {
        print("[gaga-netplay] \(text)")
        fflush(stdout)
    }

    static func runIfRequested(_ state: AppState) {
        let defaults = UserDefaults.standard
        guard let role = defaults.string(forKey: "GagaNetplay"), role == "host" || role == "join" else { return }
        let coreID = defaults.string(forKey: "GagaNetplayCore") ?? "nestopia"
        let frames = defaults.integer(forKey: "GagaNetplayFrames") > 0 ? defaults.integer(forKey: "GagaNetplayFrames") : 3600
        Task {
            do {
                guard let platformID = CoreCatalog.platforms.first(where: { $0.cores.contains { $0.id == coreID } })?.id else {
                    throw GameLaunchError.coreNotBuilt(CoreCatalog.coreName(coreID))
                }
                var rom: URL
                if let name = defaults.string(forKey: "GagaNetplayROM") {
                    // As -GagaImportROM: a relative path is in Documents, where `devicectl device copy to` puts a file.
                    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    rom = name.hasPrefix("/") ? URL(fileURLWithPath: name) : documents.appendingPathComponent(name)
                } else {
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GagaNetplayROM", isDirectory: true)
                    rom = try BenchmarkRun.writeTestROM(platformID: platformID, to: folder)
                    if defaults.bool(forKey: "GagaNetplayMismatch") {
                        var data = try Data(contentsOf: rom)
                        data.append(0xA5)
                        let changed = folder.appendingPathComponent("mismatch-" + rom.lastPathComponent)
                        try data.write(to: changed)
                        rom = changed
                    }
                }
                log("role=\(role) core=\(coreID) frames=\(frames) mismatch=\(defaults.bool(forKey: "GagaNetplayMismatch")) rom=\(rom.lastPathComponent)")
                let game = GameItem(id: UUID(), title: "Netplay", platformID: platformID, romPath: rom.path,
                                    coverPath: nil, coreOverride: coreID, playTime: 0, lastPlayed: nil,
                                    isFavorite: false, shaderID: "original")
                state.start(game)
                for _ in 0..<600 {
                    try await Task.sleep(for: .milliseconds(100))
                    if let session = state.session, session.game.id == game.id, session.phase == .running {
                        let net = NetplaySession.session(for: session, romPath: rom.path)
                        let harness = NetplayHarness(net: net, frames: frames)
                        running = harness
                        harness.watch()
                        role == "host" ? net.host() : net.join()
                        return
                    }
                }
                log("error: the game did not start")
            } catch {
                log("error: \(error.localizedDescription)")
            }
        }
    }

    private func watch() {
        net.$phase.sink { [weak self] phase in self?.changed(phase) }.store(in: &watches)
        net.$peers.sink { [weak self] peers in
            guard let self, let first = peers.first else { return }
            Self.log("found \(peers.count) host(s)")
            net.connect(to: first)
        }.store(in: &watches)
        net.$note.sink { note in
            guard let note else { return }
            Self.log("host note: \(note)")
            Self.exitSoon()
        }.store(in: &watches)
    }

    private func changed(_ phase: NetplaySession.Phase) {
        switch phase {
        case .confirm(_, let code):
            Self.log("sas=\(code) (host)")
            // After this change lands: @Published calls the sink before it stores the new phase.
            DispatchQueue.main.async { [net] in net.accept() }
        case .waiting(_, let code):
            Self.log("sas=\(code) (joiner)")
        case .connected:
            Self.log("connected ports host=\(net.ports?.host ?? 0) joiner=\(net.ports?.joiner ?? 0)")
            hook()
            net.game.resume(.menu)
        case .ended(let message):
            Self.log("ended: \(message)")
            summary()
            Self.exitSoon()
        case .idle where hooked:
            Self.log("left")
            summary()
            Self.exitSoon()
        default:
            Self.log("phase \(phase)")
        }
    }

    /// Wraps the session's lockstep hook: scripted input in, a state hash and the ports' buttons out.
    private func hook() {
        guard !hooked, let driver = net.debugDriver, let core = net.game.netplayCore else { return }
        hooked = true
        let probe = probe, isHost = net.isHost
        core.betweenFrames {
            driver.onFrame = { frame, all in
                let port1 = all.first?.buttons ?? 0, port2 = all.count > 1 ? all[1].buttons : 0
                probe.lock.lock()
                if port1 & Self.hostButton != 0 { probe.hostOnPort1 += 1 }
                if port2 & Self.joinerButton != 0 { probe.joinerOnPort2 += 1 }
                if port1 & Self.joinerButton != 0 || port2 & Self.hostButton != 0 { probe.crossed += 1 }
                probe.lock.unlock()
                if frame % 60 == 0 { Self.log("ports frame=\(frame) p1=\(port1) p2=\(port2)") }
            }
            guard let inner = core.lockstep else { return }
            core.lockstep = { local in
                let frame = driver.status.frame
                probe.lock.lock()
                let due = frame % 60 == 0 && probe.hashed != frame
                if due { probe.hashed = frame }
                probe.lock.unlock()
                if due, let state = try? core.captureState() {
                    Self.log("frame=\(frame) hash=\(String(LockstepDriver.hash(state), radix: 16))")
                }
                var mine = local
                if !mine.isEmpty { mine[0].buttons = Self.script(frame: frame, isHost: isHost) }
                let out = inner(mine)
                probe.lock.lock()
                if out == nil { probe.stalls += 1 }
                probe.frame = frame
                probe.lock.unlock()
                return out
            }
        }
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    private func tick() {
        probe.lock.lock()
        let frame = probe.frame, stalls = probe.stalls
        probe.lock.unlock()
        let status = net.debugDriver?.status
        Self.log("rtt=\(net.pingMs.map(String.init) ?? "-")ms delay=\(status?.delay ?? 0) frame=\(frame) stalls=\(stalls) desyncs=\(status?.desyncs ?? 0)")
        if net.isHost, frame >= frames, case .connected = net.phase {
            Self.log("reached \(frames) frames, leaving")
            net.leave()
        }
    }

    private func summary() {
        ticker?.invalidate()
        probe.lock.lock()
        defer { probe.lock.unlock() }
        Self.log("summary frame=\(probe.frame) stalls=\(probe.stalls) p1host=\(probe.hostOnPort1) p2joiner=\(probe.joinerOnPort2) crossed=\(probe.crossed)")
    }

    private static func exitSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            log("exit")
            fflush(stdout)
            exit(0)
        }
    }
}
#endif
