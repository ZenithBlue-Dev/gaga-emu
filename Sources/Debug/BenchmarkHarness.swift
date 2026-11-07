#if DEBUG
import CryptoKit
import Foundation
import UIKit
import os

/// The run record and metrics of docs/04 section 7.2, as code. Debug builds only.
///
/// Start it from Settings > About > Run Benchmark, or with the launch argument `-GagaBenchmark`. Options:
/// `-GagaBenchmarkCore <core_id>` (default `mgba`), `-GagaBenchmarkSeconds 60` and
/// `-GagaBenchmarkROM <file name in the ROM folder>`. With no ROM it generates the homebrew test ROM for
/// GBA, GB, GBC, NES, SNES, NDS, PS1, DOS, PC Engine or the Vulkan test core, and any other core needs a ROM. The record lands in the app's Documents/Benchmarks, which the Files
/// app shows on a device. The procedure is in docs/04 section 7.2.
@MainActor
final class BenchmarkRun {
    static let defaultSeconds: TimeInterval = 60
    static let warmupSeconds: TimeInterval = 5

    struct Percentiles: Encodable, Equatable {
        let mean, p50, p95, p99, max: Double

        /// Nearest rank. `samples` need not be sorted.
        init(_ samples: [Double]) {
            let sorted = samples.sorted()
            func rank(_ fraction: Double) -> Double {
                sorted.isEmpty ? 0 : sorted[Swift.min(sorted.count - 1, Int((Double(sorted.count) * fraction).rounded(.up)) - 1)]
            }
            mean = sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count)
            p50 = rank(0.50)
            p95 = rank(0.95)
            p99 = rank(0.99)
            max = sorted.last ?? 0
        }
    }

    struct Record: Encodable {
        struct Core: Encodable { let id, name, version, settings: String }
        struct ROM: Encodable { let file, sha256: String; let bytes: Int }
        struct Memory: Encodable { let peakFootprintBytes, footprintBytes, availableBytes: UInt64 }
        struct Thermal: Encodable { let start, end, highest: String }
        struct Audio: Encodable { let underruns, framesWritten, framesRendered: Int }
        struct Video: Encodable { let framesWritten, framesDropped: Int }

        /// "measured" on a device. A simulator record says plainly that it measures nothing.
        let label: String
        let device: String
        let os: String
        let appBuild: String
        let buildCommit: String
        /// The core is always a Release build. The Swift host around it is Debug, so its callback cost reads high.
        let hostConfiguration: String
        let core: Core
        let rom: ROM
        let inputScript: String
        let interrupted: Bool
        let warmupSeconds: Double
        let measuredSeconds: Double
        let frames: Int
        let fps: Double
        let fps1PercentLow: Double
        let frameIntervalMs: Percentiles
        /// Primary metric: CPU time on the core thread per guest frame, including the host callbacks.
        let coreCPUMsPerFrame: Percentiles
        let coreWallMsPerFrame: Percentiles
        let threadCPUPercentOfOneCore: [String: Double]
        let memory: Memory
        let thermal: Thermal
        let audio: Audio
        let video: Video
        let codeGenViolations: [String]
    }

    /// Filled on the core's queue, read on the main actor after `core.pause`, which is a barrier.
    private final class Samples: @unchecked Sendable {
        var starts: [UInt64] = []
        var walls: [UInt64] = []
        var cpus: [UInt64] = []

        init(capacity: Int) {
            starts.reserveCapacity(capacity)
            walls.reserveCapacity(capacity)
            cpus.reserveCapacity(capacity)
        }
    }

    private static let inputScript = "A for 10 of every 60 frames; D-pad cycling each 120 frames"

    private let session: GameSession
    private let romURL: URL
    private let seconds: TimeInterval
    private let warmup: TimeInterval
    private let samples: Samples
    private let interface: GagaCoreInterface
    private var thermalHigh = ProcessInfo.processInfo.thermalState
    private var threadTotals: [String: Double] = [:]
    private var threadSampleCount = 0

    /// Called with the record's location, after it is written and before the session ends.
    var onWritten: ((URL) -> Void)?

    init(session: GameSession, interface: GagaCoreInterface, romURL: URL, seconds: TimeInterval, warmup: TimeInterval = BenchmarkRun.warmupSeconds) {
        self.session = session
        self.interface = interface
        self.romURL = romURL
        self.seconds = seconds
        self.warmup = warmup
        samples = Samples(capacity: Int((seconds + warmup + 5) * 62))
    }

    struct NoTestROM: LocalizedError {
        let platformID: String
        var errorDescription: String? { "No test ROM is generated for \(platformID). Pass -GagaBenchmarkROM." }
    }

    static func writeTestROM(platformID: String, to directory: URL) throws -> URL {
        let data: Data
        var ext = platformID, name = "GagaBenchmark"
        switch platformID {
        case "gba": data = GBATestROM.build()
        case "gb": data = GBTestROM.build()
        case "gbc": data = GBTestROM.build(color: true)
        case "nes": data = NESTestROM.build()
        case "ps1": (data, ext) = (PS1TestEXE.build(), "exe") // PCSX-ReARMed boots a PS-EXE by its name.
        case "snes": data = SNESTestROM.build()
        case "nds": data = NDSTestROM.build()
        case "megadrive": (data, ext) = (MDTestROM.build(), "md")
        case "vktest": (data, ext) = (VkTestROM.build(), "gagavk")
        case "dos": (data, ext) = (DOSTestCOM.build(), "com")
        case "arcade": (data, name, ext) = (GridleeTestSet.build(), GridleeTestSet.machine, "zip") // MAME finds the machine by name.
        case "n64": (data, ext) = (N64TestROM.build(), "z64")
        case "pce": data = PCETestROM.build()
        case "sgx": data = PCETestROM.build(superGrafx: true)
        case "vb": data = VBTestROM.build()
        case "ngp": (data, ext) = (NGPTestROM.build(), "ngc")
        default: throw NoTestROM(platformID: platformID)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).\(ext)")
        try data.write(to: url)
        return url
    }

    /// Call after `prepare` and before `run`.
    func attach() {
        let samples = self.samples
        session.attachBenchmark(script: Self.scriptedButtons) { start, wall, cpu in
            if samples.starts.isEmpty { pthread_setname_np("gaga.core") }
            samples.starts.append(start)
            samples.walls.append(wall)
            samples.cpus.append(cpu)
        }
    }

    /// Same input on every run, driven by frame number only.
    nonisolated static func scriptedButtons(frame: Int) -> UInt32 {
        var buttons: UInt32 = frame % 60 < 10 ? UInt32(GAGA_BTN_EAST.rawValue) : 0
        let pad = [GAGA_BTN_UP, GAGA_BTN_RIGHT, GAGA_BTN_DOWN, GAGA_BTN_LEFT]
        buttons |= UInt32(pad[(frame / 120) % pad.count].rawValue)
        return buttons
    }

    /// Waits for the game view to start the session, measures, writes the record, then ends the session.
    func drive() async {
        let thermalStart = ProcessInfo.processInfo.thermalState
        while session.phase != .running {
            if session.phase == .stopped { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        try? await Task.sleep(for: .seconds(warmup))
        let measureFrom = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        var interrupted = false
        for _ in 0..<Int(seconds) {
            try? await Task.sleep(for: .seconds(1))
            guard session.phase == .running else {
                interrupted = true
                break
            }
            sampleThreads()
            noteThermal()
        }
        guard session.phase != .stopped else { return }
        session.pause(.menu)

        let record = makeRecord(thermalStart: thermalStart, measureFrom: measureFrom, interrupted: interrupted)
        do {
            let url = try write(record)
            Logger(subsystem: "com.zenithblue.gagaemu", category: "benchmark").notice("record \(url.path, privacy: .public)")
            onWritten?(url)
            session.stop(message: "Benchmark saved to Documents/Benchmarks/\(url.lastPathComponent).")
        } catch {
            session.stop(message: "The benchmark record could not be written: \(error.localizedDescription)")
        }
    }

    private func noteThermal() {
        let now = ProcessInfo.processInfo.thermalState
        if now.rawValue > thermalHigh.rawValue { thermalHigh = now }
    }

    private func sampleThreads() {
        var threads: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threads, &count) == KERN_SUCCESS, let threads else { return }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads),
                          vm_size_t(count) * vm_size_t(MemoryLayout<thread_act_t>.stride))
        }
        threadSampleCount += 1
        for index in 0..<Int(count) {
            var info = thread_extended_info_data_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_extended_info_data_t>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[index], thread_flavor_t(THREAD_EXTENDED_INFO), $0, &infoCount)
                }
            }
            mach_port_deallocate(mach_task_self_, threads[index])
            guard result == KERN_SUCCESS else { continue }
            let name = withUnsafeBytes(of: info.pth_name) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            threadTotals[name.isEmpty ? "unnamed" : name, default: 0] += Double(info.pth_cpu_usage) / Double(TH_USAGE_SCALE) * 100
        }
    }

    private func makeRecord(thermalStart: ProcessInfo.ThermalState, measureFrom: UInt64, interrupted: Bool) -> Record {
        noteThermal()
        let first = samples.starts.firstIndex { $0 >= measureFrom } ?? samples.starts.count
        let starts = samples.starts[first...]
        let intervals = zip(starts.dropFirst(), starts).map { Double($0 - $1) / 1_000_000 }
        let slowest = Array(intervals.sorted().suffix(Swift.max(1, intervals.count / 100)))
        let slowestMean = slowest.reduce(0, +) / Double(Swift.max(1, slowest.count))
        let measured = starts.count > 1 ? Double(starts.last! - starts.first!) / 1_000_000_000 : 0

        let stats = session.stats
        let romData = (try? Data(contentsOf: romURL)) ?? Data()
        let info = Bundle.main.infoDictionary
        let divisor = Double(Swift.max(1, threadSampleCount))
        return Record(
            label: Self.label,
            device: Self.deviceModel,
            os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appBuild: "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))",
            buildCommit: (Bundle.main.url(forResource: "build-commit", withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "unknown")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            hostConfiguration: "Debug host, Release core",
            core: .init(id: String(cString: interface.core_id), name: String(cString: interface.core_name),
                        version: String(cString: interface.core_version),
                        settings: String(cString: interface.core_id) == "mgba" ? "defaults, HLE BIOS, skip BIOS boot" : "defaults"),
            rom: .init(file: romURL.lastPathComponent,
                       sha256: SHA256.hash(data: romData).map { String(format: "%02x", $0) }.joined(), bytes: romData.count),
            inputScript: Self.inputScript,
            interrupted: interrupted,
            warmupSeconds: warmup,
            measuredSeconds: measured,
            frames: starts.count,
            fps: measured > 0 ? Double(starts.count - 1) / measured : 0,
            fps1PercentLow: slowestMean > 0 ? 1000 / slowestMean : 0,
            frameIntervalMs: Percentiles(intervals),
            coreCPUMsPerFrame: Percentiles(samples.cpus[first...].map { Double($0) / 1_000_000 }),
            coreWallMsPerFrame: Percentiles(samples.walls[first...].map { Double($0) / 1_000_000 }),
            threadCPUPercentOfOneCore: threadTotals.mapValues { ($0 / divisor * 10).rounded() / 10 },
            memory: Self.memory(),
            thermal: .init(start: Self.name(thermalStart), end: Self.name(ProcessInfo.processInfo.thermalState), highest: Self.name(thermalHigh)),
            audio: .init(underruns: stats.audioUnderruns, framesWritten: stats.audioWritten, framesRendered: stats.audioRendered),
            video: .init(framesWritten: stats.videoWritten, framesDropped: stats.videoDropped),
            codeGenViolations: CodeGenCheck.violations().map(\.description))
    }

    private func write(_ record: Record) throws -> URL {
        let folder = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Benchmarks", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("\(record.core.id)-\(record.device)-\(stamp).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: url, options: .atomic)
        return url
    }

    private static var label: String {
        #if targetEnvironment(simulator)
        return "simulator, not a performance measure"
        #else
        return "measured"
        #endif
    }

    private static var deviceModel: String {
        #if targetEnvironment(simulator)
        return "Simulator-" + (ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown")
        #else
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
        #endif
    }

    private static func memory() -> Record.Memory {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        _ = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return .init(peakFootprintBytes: UInt64(info.ledger_phys_footprint_peak), footprintBytes: info.phys_footprint,
                     availableBytes: UInt64(os_proc_available_memory()))
    }

    private static func name(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
#endif
