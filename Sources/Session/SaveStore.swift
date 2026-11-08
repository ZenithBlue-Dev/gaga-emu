import CryptoKit
import Foundation

/// Temp file, flush, rename. A failure or a kill at any point leaves the old file whole.
enum AtomicFile {
    static func write(_ data: Data, to url: URL) throws {
        let temp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        let fd = open(temp.path, O_CREAT | O_EXCL | O_WRONLY, 0o644)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        do {
            defer { close(fd) }
            try data.withUnsafeBytes { bytes in
                var written = 0
                while written < bytes.count {
                    let count = Darwin.write(fd, bytes.baseAddress! + written, bytes.count - written)
                    guard count > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                    written += count
                }
            }
            guard fsync(fd) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard rename(temp.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        } catch {
            unlink(temp.path)
            throw error
        }
    }
}

enum SaveStateError: LocalizedError, Equatable {
    case notAState
    case incomplete
    case damaged
    case otherCore(String)
    case otherVersion
    case limitReached(Int)

    var errorDescription: String? {
        switch self {
        case .notAState: return "This file is not a save state."
        case .incomplete: return "This save state is incomplete. It may not have finished saving."
        case .damaged: return "This save state is damaged and cannot be loaded."
        case .otherCore(let core): return "This save state was made by \(CoreCatalog.coreName(core)), so this core cannot load it."
        case .otherVersion: return "This save state was made by a different version of this core."
        case .limitReached(let limit): return "You have \(limit) save states, the most without Gaga Plus. Delete one to save another."
        }
    }
}

/// A core's state bytes on disk. Everything here is checked before a core sees any of it.
///
/// Header, little-endian: "GAGASTAT", format version (u32), core ID (32 bytes, zero padded),
/// state version (u32), payload length (u64), SHA-256 of the payload (32 bytes). Then the payload.
enum SaveStateFile {
    private static let magic = Array("GAGASTAT".utf8)
    private static let formatVersion: UInt32 = 1
    private static let coreIDLength = 32
    static let headerSize = 8 + 4 + coreIDLength + 4 + 8 + 32

    static func encode(payload: Data, coreID: String, stateVersion: UInt32) -> Data {
        var file = Data(capacity: headerSize + payload.count)
        file.append(contentsOf: magic)
        withUnsafeBytes(of: formatVersion.littleEndian) { file.append(contentsOf: $0) }
        var id = Array(coreID.utf8.prefix(coreIDLength))
        id += [UInt8](repeating: 0, count: coreIDLength - id.count)
        file.append(contentsOf: id)
        withUnsafeBytes(of: stateVersion.littleEndian) { file.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt64(payload.count).littleEndian) { file.append(contentsOf: $0) }
        file.append(contentsOf: SHA256.hash(data: payload))
        file.append(payload)
        return file
    }

    /// The payload, or the reason the player should not load it.
    static func decode(_ file: Data, coreID: String, stateVersion: UInt32) throws -> Data {
        let bytes = [UInt8](file.prefix(headerSize))
        guard bytes.count >= magic.count, Array(bytes[0..<magic.count]) == magic else { throw SaveStateError.notAState }
        guard bytes.count == headerSize else { throw SaveStateError.incomplete }
        func u32(_ at: Int) -> UInt32 { bytes[at..<at + 4].reversed().reduce(0) { $0 << 8 | UInt32($1) } }
        guard u32(8) == formatVersion else { throw SaveStateError.otherVersion }
        let id = String(decoding: bytes[12..<12 + coreIDLength].prefix { $0 != 0 }, as: UTF8.self)
        guard id == coreID else { throw SaveStateError.otherCore(id) }
        guard u32(44) == stateVersion else { throw SaveStateError.otherVersion }
        let length = bytes[48..<56].reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        guard UInt64(file.count - headerSize) == length else { throw SaveStateError.incomplete }
        let payload = file.subdata(in: file.startIndex + headerSize..<file.endIndex)
        guard Array(SHA256.hash(data: payload)) == Array(bytes[56..<88]) else { throw SaveStateError.damaged }
        return payload
    }
}

struct SaveSlot: Identifiable, Equatable {
    let url: URL
    let date: Date
    var id: String { url.lastPathComponent }
    var isAuto: Bool { url.deletingPathExtension().lastPathComponent == SaveStore.autoName }
    var thumbnailURL: URL { url.deletingPathExtension().appendingPathExtension("png") }
}

struct CheatEntry: Identifiable, Codable, Equatable {
    let id: UInt32
    var name: String
    var code: String
    var enabled: Bool
}

/// One game's folder: battery saves written by the core, `States/` and `cheats.json`. It is named after
/// the ROM file (`GagaCoreWrapper.saveDirectory`), so it outlives the game's place in the Library.
struct SaveStore {
    static let autoName = "auto"
    private static let stateExtension = "gagastate"
    private static let cheatsFile = "cheats.json"
    private static let statesFolder = "States"

    let directory: URL
    private var states: URL { directory.appendingPathComponent(Self.statesFolder, isDirectory: true) }

    init(directory: URL) { self.directory = directory }

    init(romPath: String) { directory = URL(fileURLWithPath: GagaCoreWrapper.saveDirectory(forROM: romPath)) }

    /// Newest first. Temp files from a killed write are not slots.
    func slots() -> [SaveSlot] {
        let key = URLResourceKey.contentModificationDateKey
        let files = (try? FileManager.default.contentsOfDirectory(at: states, includingPropertiesForKeys: [key])) ?? []
        return files.filter { $0.pathExtension == Self.stateExtension }
            .map { SaveSlot(url: $0, date: (try? $0.resourceValues(forKeys: [key]).contentModificationDate) ?? .distantPast) }
            .sorted { $0.date > $1.date }
    }

    var autoSlot: SaveSlot? { slots().first(where: \.isAuto) }

    /// The auto save does not count against a player's limit: it has one fixed slot.
    var manualCount: Int { slots().filter { !$0.isAuto }.count }

    /// The file goes in last, so no slot appears without a whole file behind it. A lost thumbnail costs only a picture.
    /// A quick slot's file name. Writing to it again replaces it.
    static func quickName(_ slot: Int) -> String { "quick-\(slot)" }

    func quickSlot(_ slot: Int) -> SaveSlot? {
        slots().first { $0.url.deletingPathExtension().lastPathComponent == Self.quickName(slot) }
    }

    @discardableResult
    func writeState(_ file: Data, thumbnail: Data?, auto: Bool = false, quick: Int? = nil) throws -> SaveSlot {
        try FileManager.default.createDirectory(at: states, withIntermediateDirectories: true)
        for leftover in (try? FileManager.default.contentsOfDirectory(at: states, includingPropertiesForKeys: nil)) ?? []
        where leftover.lastPathComponent.contains(".tmp-") {
            try? FileManager.default.removeItem(at: leftover)
        }
        let name = auto ? Self.autoName : quick.map(Self.quickName) ?? "state-\(UUID().uuidString)"
        let url = states.appendingPathComponent(name).appendingPathExtension(Self.stateExtension)
        let slot = SaveSlot(url: url, date: Date())
        if let thumbnail { try? AtomicFile.write(thumbnail, to: slot.thumbnailURL) }
        try AtomicFile.write(file, to: url)
        return slot
    }

    func delete(_ slot: SaveSlot) throws {
        try FileManager.default.removeItem(at: slot.url)
        try? FileManager.default.removeItem(at: slot.thumbnailURL)
    }

    /// What the core wrote into its save folder, for Export Save.
    func batterySaves() -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return files.filter { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.isRegularFile == true && (values?.fileSize ?? 0) > 0 && url.lastPathComponent != Self.cheatsFile
        }
    }

    func cheats() -> [CheatEntry] {
        let url = directory.appendingPathComponent(Self.cheatsFile)
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([CheatEntry].self, from: $0) } ?? []
    }

    func saveCheats(_ cheats: [CheatEntry]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try AtomicFile.write(JSONEncoder().encode(cheats), to: directory.appendingPathComponent(Self.cheatsFile))
    }
}
