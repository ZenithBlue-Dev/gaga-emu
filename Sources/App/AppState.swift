import SwiftUI
import Foundation

/// One imported game. `coreOverride` wins over the platform default.
struct GameItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var platformID: String
    var romPath: String
    var coverPath: String?
    var coreOverride: String?
    var playTime: TimeInterval
    var lastPlayed: Date?
    var isFavorite: Bool
    var shaderID: String
    /// A touch layout for this game only. Nil follows the platform's choice.
    var skinID: String? = nil

    /// Resolution order: game override, platform default, catalog recommendation.
    func resolvedCoreID(defaults: [String: String]) -> String {
        coreOverride ?? defaults[platformID] ?? CoreCatalog.defaultCore(for: platformID)
    }

    /// The saved absolute path goes stale when iOS moves the app container, so also look in the ROM folder.
    func resolvedROMPath(romDirectory: URL) -> String? {
        let name = URL(fileURLWithPath: romPath).lastPathComponent
        return [romPath, romDirectory.appendingPathComponent(name).path]
            .first(where: FileManager.default.fileExists(atPath:))
    }
}

struct PlaySession: Identifiable, Codable, Equatable {
    var id: UUID
    var gameID: UUID
    var started: Date
    var duration: TimeInterval
}

struct PlatformInfo: Identifiable, Equatable {
    var id: String
    var name: String
    var manufacturer: String
    var cores: [CoreInfo]
}

struct CoreInfo: Identifiable, Equatable {
    var id: String
    var name: String
    var note: String
    var recommended: Bool
}

/// Static registry. Defaults match docs/03 section 2; alternates are a subset of section 3.
/// IDs are the C registry's short lowercase `core_id`, the only ID scheme. No dlopen.
enum CoreCatalog {
    /// Without the cores this build left out (`GAGA_CORE_SET`), or any platform with none left.
    static let platforms: [PlatformInfo] = allPlatforms.compactMap { platform in
        let cores = platform.cores.filter { !GagaCoreRegistry_IsExcluded($0.id) }
        return cores.isEmpty ? nil : PlatformInfo(id: platform.id, name: platform.name,
                                                  manufacturer: platform.manufacturer, cores: cores)
    }

    private static let allPlatforms: [PlatformInfo] = [
        .init(id: "ps1", name: "PlayStation", manufacturer: "Sony", cores: [
            .init(id: "beetle_psx", name: "Beetle PSX HW", note: "PGXP, Vulkan", recommended: false),
            .init(id: "pcsx_rearmed", name: "PCSX-ReARMed", note: "Fast", recommended: true)
        ]),
        .init(id: "saturn", name: "Sega Saturn", manufacturer: "Sega", cores: [
            .init(id: "beetle_saturn", name: "Beetle Saturn", note: "Cycle accuracy", recommended: true)
        ]),
        .init(id: "megacd", name: "Mega-CD", manufacturer: "Sega", cores: [
            .init(id: "jgenesis", name: "JGenesis", note: "Mega-CD accuracy", recommended: true)
        ]),
        .init(id: "megadrive", name: "Mega Drive", manufacturer: "Sega", cores: [
            .init(id: "jgenesis", name: "JGenesis", note: "Default", recommended: true)
        ]),
        .init(id: "dreamcast", name: "Dreamcast", manufacturer: "Sega", cores: [
            .init(id: "flycast", name: "Flycast", note: "JITLess", recommended: true)
        ]),
        .init(id: "n3ds", name: "Nintendo 3DS", manufacturer: "Nintendo", cores: [
            .init(id: "azahar", name: "Azahar", note: "Interpreter", recommended: true)
        ]),
        .init(id: "nds", name: "Nintendo DS", manufacturer: "Nintendo", cores: [
            .init(id: "melonds_ds", name: "melonDS DS", note: "Software renderer", recommended: true),
            .init(id: "desmume", name: "DeSmuME", note: "Legacy hacks", recommended: false)
        ]),
        .init(id: "gba", name: "Game Boy Advance", manufacturer: "Nintendo", cores: [
            .init(id: "mgba", name: "mGBA", note: "Accuracy", recommended: true),
            .init(id: "gpsp", name: "gpSP", note: "Interpreter", recommended: false),
            .init(id: "vba_m", name: "VBA-M", note: "ROM hacks", recommended: false)
        ]),
        .init(id: "gbc", name: "Game Boy Color", manufacturer: "Nintendo", cores: [
            .init(id: "gambatte", name: "Gambatte", note: "Cycle accuracy", recommended: true),
            .init(id: "sameboy", name: "SameBoy", note: "Audio accuracy", recommended: false)
        ]),
        .init(id: "gb", name: "Game Boy", manufacturer: "Nintendo", cores: [
            .init(id: "gambatte", name: "Gambatte", note: "Default", recommended: true)
        ]),
        .init(id: "snes", name: "Super Famicom", manufacturer: "Nintendo", cores: [
            .init(id: "bsnes", name: "bsnes", note: "Cycle accuracy", recommended: true)
        ]),
        .init(id: "nes", name: "NES", manufacturer: "Nintendo", cores: [
            .init(id: "nestopia", name: "Nestopia UE", note: "Default", recommended: true),
            .init(id: "fceumm", name: "FCEUmm", note: "Broad mappers", recommended: false)
        ]),
        .init(id: "n64", name: "Nintendo 64", manufacturer: "Nintendo", cores: [
            .init(id: "mupen64plus_next", name: "Mupen64Plus-Next", note: "ParaLLEl-RDP", recommended: true)
        ]),
        .init(id: "psp", name: "PSP", manufacturer: "Sony", cores: [
            .init(id: "ppsspp", name: "PPSSPP", note: "IR interpreter", recommended: true)
        ]),
        .init(id: "arcade", name: "Arcade", manufacturer: "Arcade", cores: [
            .init(id: "mame", name: "MAME", note: "Wide catalog", recommended: true)
        ]),
        .init(id: "dos", name: "MS-DOS", manufacturer: "Vintage", cores: [
            .init(id: "dosbox_pure", name: "DOSBox Pure", note: "ZIP launch", recommended: true)
        ]),
        // group-retro backlog platforms (docs/07 section 8.x).
        .init(id: "mastersystem", name: "Master System", manufacturer: "Sega", cores: [
            .init(id: "gearsystem", name: "Gearsystem", note: "Default", recommended: true)
        ]),
        .init(id: "gamegear", name: "Game Gear", manufacturer: "Sega", cores: [
            .init(id: "gearsystem", name: "Gearsystem", note: "Default", recommended: true)
        ]),
        .init(id: "sg1000", name: "SG-1000", manufacturer: "Sega", cores: [
            .init(id: "gearsystem", name: "Gearsystem", note: "Default", recommended: true)
        ]),
        .init(id: "atari2600", name: "Atari 2600", manufacturer: "Atari", cores: [
            .init(id: "stella", name: "Stella", note: "Default", recommended: true)
        ]),
        .init(id: "atari7800", name: "Atari 7800", manufacturer: "Atari", cores: [
            .init(id: "prosystem", name: "ProSystem", note: "Default", recommended: true)
        ]),
        .init(id: "lynx", name: "Atari Lynx", manufacturer: "Atari", cores: [
            .init(id: "handy", name: "Handy", note: "Default", recommended: true)
        ]),
        .init(id: "atari5200", name: "Atari 5200", manufacturer: "Atari", cores: [
            .init(id: "atari800", name: "Atari800", note: "Default", recommended: true)
        ]),
        .init(id: "atari8bit", name: "Atari 8-bit", manufacturer: "Atari", cores: [
            .init(id: "atari800", name: "Atari800", note: "800XL", recommended: true)
        ]),
        .init(id: "jaguar", name: "Atari Jaguar", manufacturer: "Atari", cores: [
            .init(id: "virtualjaguar", name: "Virtual Jaguar", note: "Heavy", recommended: true)
        ]),
        .init(id: "c64", name: "Commodore 64", manufacturer: "Commodore", cores: [
            .init(id: "vice", name: "VICE", note: "x64sc", recommended: true)
        ]),
        .init(id: "amiga", name: "Amiga", manufacturer: "Commodore", cores: [
            .init(id: "puae", name: "PUAE", note: "A500", recommended: true)
        ]),
        .init(id: "doom", name: "Doom", manufacturer: "id Software", cores: [
            .init(id: "prboom", name: "PrBoom", note: "WAD", recommended: true)
        ]),
        .init(id: "javame", name: "Java ME", manufacturer: "Vintage", cores: [
            .init(id: "j2mejs", name: "J2meJS", note: "MIDP", recommended: true)
        ]),
        .init(id: "symbian", name: "Symbian", manufacturer: "Vintage", cores: [
            .init(id: "eka2l1", name: "EKA2L1", note: "Interpreter", recommended: true)
        ])
    ] + debugPlatforms

    #if DEBUG
    /// The layer-path test core (Cores/vktest), for proving the Vulkan path in the app.
    private static let debugPlatforms: [PlatformInfo] = [
        .init(id: "vktest", name: "Vulkan Test", manufacturer: "GagaEmu", cores: [
            .init(id: "vktest", name: "Vulkan Test", note: "Layer path", recommended: true)
        ])
    ]
    #else
    private static let debugPlatforms: [PlatformInfo] = []
    #endif

    /// A layer-path core presents its own picture, so host shaders and filters do not run on it.
    static func drawsOwnPicture(_ coreID: String) -> Bool {
        guard let core = GagaCoreRegistry_FindByID(coreID), !GagaCoreRegistry_IsExcluded(coreID) else { return false }
        return core.pointee.capabilities & GAGA_CORE_CAP_METAL_LAYER.rawValue != 0
    }

    /// Names of this build's layer-path cores, for the Gaga Plus filter statement.
    static var layerPathCoreNames: [String] {
        platforms.flatMap(\.cores).filter { drawsOwnPicture($0.id) }.map(\.name)
            .reduce(into: []) { names, name in if !names.contains(name) { names.append(name) } }
    }

    static func platform(_ id: String) -> PlatformInfo? { platforms.first { $0.id == id } }

    static func platformName(_ id: String) -> String { platform(id)?.name ?? "Other" }

    /// Short label for chips and metadata.
    static func platformCode(_ id: String) -> String {
        let special = ["saturn": "SAT", "megacd": "MCD", "megadrive": "MD", "dreamcast": "DC", "n3ds": "3DS",
                       "arcade": "ARC", "javame": "JME", "symbian": "SYM", "unknown": "ETC",
                       "mastersystem": "SMS", "gamegear": "GG", "sg1000": "SG", "atari2600": "2600",
                       "atari7800": "7800", "atari5200": "5200", "atari8bit": "A8", "jaguar": "JAG", "c64": "C64", "amiga": "AMI",
                       "doom": "WAD"]
        return special[id] ?? id.uppercased()
    }

    static func playTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    static func defaultCore(for platformID: String) -> String {
        platform(platformID)?.cores.first { $0.recommended }?.id ?? platform(platformID)?.cores.first?.id ?? ""
    }

    static func coreName(_ id: String) -> String {
        platforms.flatMap(\.cores).first { $0.id == id }?.name ?? id
    }

    /// Extension to platform. Used by import.
    static func platformID(forExtension ext: String) -> String? {
        switch ext.lowercased() {
        case "gba": return "gba"
        case "gbc": return "gbc"
        case "gb": return "gb"
        case "nes", "fds": return "nes"
        case "sfc", "smc": return "snes"
        case "n64", "z64", "v64": return "n64"
        case "nds": return "nds"
        case "3ds", "cia": return "n3ds"
        // Disc images serve PS1, Mega-CD and DOS alike: platformID(forFile:) looks inside, and asks when unsure.
        case "pbp": return "ps1"
        // A PS-EXE also ends in .exe. platformID(forFile:) tells the two apart by the file's first bytes.
        // The rest are the DOSBox Pure extensions no other core takes.
        case "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf": return "dos"
        case "cso": return "psp"
        case "gdi", "cdi": return "dreamcast"
        case "md", "gen", "smd": return "megadrive"
        case "sms": return "mastersystem"
        case "gg": return "gamegear"
        case "sg", "mv": return "sg1000"
        // A 2600 image is often a .bin: platformID(forFile:) tells it from a Mega Drive ROM or a disc by content.
        case "a26": return "atari2600"
        case "a78": return "atari7800"
        case "lnx": return "lynx"
        case "a52": return "atari5200"
        case "xex", "atr", "xfd", "dcm", "atx": return "atari8bit"
        case "j64", "jag": return "jaguar"
        case "d64", "t64", "prg", "crt", "tap": return "c64"
        case "adf", "hdf": return "amiga"
        case "wad": return "doom"
        #if DEBUG
        case "gagavk": return "vktest"
        #endif
        // A MAME ROM set, kept zipped as MAME reads it. A .zip serves Arcade and DOS: platformID(forFile:) looks inside.
        case "7z": return "arcade"
        default: return nil
        }
    }

    /// Extensions a disc image can have. Without a platform from `platformID(forFile:)`, import asks the player.
    static let discExtensions: Set<String> = ["iso", "bin", "cue", "chd", "img", "m3u"]
    /// The platforms import offers for a disc it could not place, in that order, where a core is listed.
    static var discPlatforms: [PlatformInfo] { ["ps1", "megacd", "dos"].compactMap(platform) }

    /// The platforms import offers for a file it could not place, or nil when it does not ask for that extension.
    static func unplacedPlatforms(forExtension ext: String) -> [PlatformInfo]? {
        if discExtensions.contains(ext.lowercased()) { return discPlatforms }
        return ext.lowercased() == "zip" ? ["arcade", "dos"].compactMap(platform) : nil
    }

    /// The extension's platform, corrected by the file's contents where one extension serves two platforms:
    /// an .exe that starts with "PS-X EXE" is a PlayStation program, a .zip is placed by `zipPlatformID(_:)`,
    /// and a disc image is placed by `discPlatformID(_:)`.
    static func platformID(forFile url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        if ext == "bin", let cartridge = binCartridgePlatformID(url) { return cartridge }
        if discExtensions.contains(ext) { return discPlatformID(url) }
        switch ext {
        case "exe":
            let handle = try? FileHandle(forReadingFrom: url)
            defer { try? handle?.close() }
            let magic = (try? handle?.read(upToCount: 8)) ?? nil
            return magic == Data("PS-X EXE".utf8) ? "ps1" : "dos"
        case "zip":
            return zipPlatformID(url)
        default:
            return platformID(forExtension: url.pathExtension)
        }
    }

    /// A .zip's platform from its central directory, nothing extracted. DOS: it holds an .exe, .com, .bat or
    /// DOSBox .conf. Arcade: its name is a machine in `mameMachines`, or every entry is ROM-like (no extension,
    /// .bin, .rom, or one with a digit, as in "pacman.6e"). Otherwise nil, and import asks.
    static func zipPlatformID(_ url: URL) -> String? {
        let names = zipEntryNames(url)
        let exts = names.map { ($0 as NSString).pathExtension.lowercased() }
        if exts.contains(where: { ["exe", "com", "bat", "conf"].contains($0) }) { return "dos" }
        if mameMachines.contains(url.deletingPathExtension().lastPathComponent.lowercased()) { return "arcade" }
        let romLike = Swift.zip(names, exts).allSatisfy { name, ext in
            !name.contains("/") && (ext.isEmpty || ext == "bin" || ext == "rom" || ext.contains(where: \.isNumber))
        }
        return !names.isEmpty && romLike ? "arcade" : nil
    }

    /// A cartridge dumped as .bin, or nil to try it as a disc. Mega Drive: "SEGA" at 0x100, its header. Atari 2600:
    /// 2 to 32 KB in whole 2 KB banks, with no Sega header, and a reset vector (the image's last 4 bytes) that
    /// has address line 12 set, as every 6507 cartridge's must.
    static func binCartridgePlatformID(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size >= 0x104, (try? handle.seek(toOffset: 0)) != nil,
              let head = try? handle.read(upToCount: 0x104) else { return nil }
        if head.suffix(4).elementsEqual("SEGA".utf8) { return "megadrive" }
        guard (2048...32768).contains(size), size % 2048 == 0, (try? handle.seek(toOffset: size - 4)) != nil,
              let vector = try? handle.read(upToCount: 2), vector.count == 2 else { return nil }
        return vector[vector.startIndex + 1] & 0x10 != 0 ? "atari2600" : nil
    }

    /// A disc image's platform from its first 64 KiB, or nil when that does not say. PS1: "PLAYSTATION" as
    /// the system ID in sector 16, or SYSTEM.CNF in the root directory. Mega-CD: "SEGADISCSYSTEM" or "SEGA"
    /// opening the first sector (Saturn's "SEGA SEGASATURN" is left out). Any other ISO 9660 disc, and any
    /// .iso or .img, is DOS. A .cue is read through its first FILE, an .m3u through its first entry.
    /// shortcut: a .chd is compressed, so it always asks; read its first hunk if players import many.
    static func discPlatformID(_ url: URL, depth: Int = 0) -> String? {
        let ext = url.pathExtension.lowercased()
        if ext == "cue" || ext == "m3u" {
            guard depth < 2, let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            let name: String?
            if ext == "cue" {
                // FILE "name" BINARY, or FILE name BINARY when the name has no spaces.
                name = lines.first { $0.uppercased().hasPrefix("FILE ") }.flatMap { line -> String? in
                    let rest = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if rest.hasPrefix("\"") { return rest.dropFirst().split(separator: "\"").first.map(String.init) }
                    return rest.split(separator: " ").first.map(String.init)
                }
            } else {
                name = lines.first { !$0.isEmpty && !$0.hasPrefix("#") }
            }
            guard let name else { return nil }
            return discPlatformID(url.deletingLastPathComponent().appendingPathComponent(name), depth: 1)
        }
        guard ext != "chd", let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let bytes = [UInt8]((try? handle.read(upToCount: 0x10000)) ?? Data())
        func has(_ text: String, in range: Range<Int>) -> Bool {
            let needle = [UInt8](text.utf8), range = range.clamped(to: 0..<bytes.count)
            guard range.count >= needle.count else { return false }
            return (range.lowerBound...(range.upperBound - needle.count)).contains {
                bytes[$0..<($0 + needle.count)].elementsEqual(needle)
            }
        }
        // Sector 16 starts at 32768 in a 2048-byte image, and its data at 16 * 2352 + 16 (Mode 1) or + 24 (Mode 2) in a raw one.
        let pvdStarts = [32768, 16 * 2352 + 16, 16 * 2352 + 24]
        if pvdStarts.contains(where: { has("PLAYSTATION", in: ($0 + 8)..<($0 + 40)) }) || has("SYSTEM.CNF;1", in: 0..<bytes.count) {
            return "ps1"
        }
        // A raw image's first sector has 16 bytes of sync and header before the data.
        for start in [0, 16] where has("SEGA", in: start..<(start + 4)) {
            return has("SEGASATURN", in: start..<(start + 16)) ? nil : "megacd"
        }
        if ext == "iso" || ext == "img" || pvdStarts.contains(where: { has("CD001", in: ($0 + 1)..<($0 + 6)) }) {
            return "dos"
        }
        return nil
    }

    /// The file names in a ZIP's central directory, or none when the file is not a readable ZIP.
    static func zipEntryNames(_ url: URL) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size >= 22 else { return [] }
        // The end record is the last 22 bytes plus a comment of up to 65535 bytes.
        let tailStart = size - min(size, 22 + 65535)
        guard (try? handle.seek(toOffset: tailStart)) != nil, let tail = try? handle.readToEnd() else { return [] }
        let bytes = [UInt8](tail)
        func u16(_ b: [UInt8], _ i: Int) -> Int { Int(b[i]) | Int(b[i + 1]) << 8 }
        func u32(_ b: [UInt8], _ i: Int) -> Int { u16(b, i) | u16(b, i + 2) << 16 }
        guard let end = stride(from: bytes.count - 22, through: 0, by: -1).first(where: {
            bytes[$0] == 0x50 && bytes[$0 + 1] == 0x4B && bytes[$0 + 2] == 5 && bytes[$0 + 3] == 6
        }) else { return [] }
        let directorySize = u32(bytes, end + 12), directoryOffset = u32(bytes, end + 16)
        guard directoryOffset + directorySize <= size, (try? handle.seek(toOffset: UInt64(directoryOffset))) != nil,
              let directory = try? handle.read(upToCount: directorySize) else { return [] }
        let entries = [UInt8](directory)
        var names: [String] = []
        var i = 0
        while i + 46 <= entries.count, u32(entries, i) == 0x0201_4B50 {
            let nameLength = u16(entries, i + 28)
            let next = i + 46 + nameLength + u16(entries, i + 30) + u16(entries, i + 32)
            guard i + 46 + nameLength <= entries.count else { break }
            names.append(String(decoding: entries[(i + 46)..<(i + 46 + nameLength)], as: UTF8.self))
            i = next
        }
        return names
    }
}

/// Upgrades values saved by older builds in state.json. Safe to run on every launch.
enum StateMigration {
    /// Reverse-DNS catalog IDs from before milestone 1.3.
    static let legacyCoreIDs: [String: String] = [
        "org.libretro.beetle-psx": "beetle_psx",
        "org.libretro.pcsx-rearmed": "pcsx_rearmed",
        "org.libretro.beetle-saturn": "beetle_saturn",
        "org.libretro.jgenesis": "jgenesis",
        "org.libretro.flycast": "flycast",
        "org.azahar.azahar": "azahar",
        "org.libretro.melonds": "melonds_ds",
        "melonds": "melonds_ds", // The catalog ID before milestone 4.6.
        "org.libretro.desmume": "desmume",
        "org.libretro.mgba": "mgba",
        "org.libretro.gpsp": "gpsp",
        "org.libretro.vba-m": "vba_m",
        "org.libretro.gambatte": "gambatte",
        "org.libretro.sameboy": "sameboy",
        "org.libretro.bsnes": "bsnes",
        "org.libretro.nestopia": "nestopia",
        "org.libretro.fceumm": "fceumm",
        "org.libretro.mupen64plus-next": "mupen64plus_next",
        "org.ppsspp.ppsspp": "ppsspp",
        "org.libretro.mame": "mame",
        "org.libretro.dosbox-pure": "dosbox_pure",
        "org.j2mejs": "j2mejs"
    ]

    /// Cores removed by docs/03 section 6. A choice of one falls back to the platform default.
    static let removedCoreIDs: Set<String> = [
        "org.libretro.swanstation", "org.libretro.kronos", "org.libretro.genesis-plus-gx",
        "org.libretro.picodrive", "org.libretro.snes9x", "org.libretro.fbneo"
    ]

    /// crt-royale is GPL and never shipped (docs/05 section 5). A saved choice falls back to Original.
    static let removedShaderIDs: Set<String> = ["crt-royale"]

    /// nil means "no saved choice". Current and unknown IDs pass through untouched.
    static func coreID(_ saved: String) -> String? {
        removedCoreIDs.contains(saved) ? nil : legacyCoreIDs[saved] ?? saved
    }

    /// Returns the upgraded snapshot, or nil when nothing needed changing. Other fields are kept.
    static func migrated(_ snapshot: AppState.Snapshot) -> AppState.Snapshot? {
        var next = snapshot
        var changed = false
        for index in next.games.indices {
            guard let saved = next.games[index].coreOverride, coreID(saved) != saved else { continue }
            next.games[index].coreOverride = coreID(saved)
            changed = true
        }
        for index in next.games.indices where removedShaderIDs.contains(next.games[index].shaderID) {
            next.games[index].shaderID = "original"
            changed = true
        }
        if removedShaderIDs.contains(next.shaderID) {
            next.shaderID = "original"
            changed = true
        }
        let cores = next.defaultCores.compactMapValues(coreID)
        if cores != next.defaultCores {
            next.defaultCores = cores
            changed = true
        }
        return changed ? next : nil
    }
}

/// The app's one web host, the same one the App Store metadata uses.
enum SiteLinks {
    private static let host = "https://zenithblue-oss.github.io/gaga-emu-site"
    /// The site's page is "Support & FAQ", and it is also the feedback route.
    static let support = "\(host)/support.html"
    static let privacy = "\(host)/privacy.html"
    /// shortcut: the site has no terms.html (404), so this is Apple's standard EULA; replace when the site has one.
    static let terms = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
}

enum ShaderCatalog {
    struct Shader: Identifiable, Equatable {
        let id: String
        let name: String
        let premium: Bool
        var credit: String? = nil
    }
    static let builtIn: [Shader] = [
        .init(id: "original", name: "Original", premium: false),
        .init(id: "cartoon", name: "Cartoon", premium: false),
        .init(id: "crt-v1", name: "CRT v1", premium: false),
        .init(id: "crt-v2", name: "CRT v2", premium: false),
        .init(id: "geom-crt-border", name: "Geom CRT Border", premium: true),
        .init(id: "geom-crt", name: "Geom CRT", premium: true),
        .init(id: "film", name: "Film", premium: false),
        .init(id: "crt-deluxe", name: "CRT Deluxe", premium: true),
        .init(id: "anime4k", name: "Anime4K", premium: true)
    ]
    /// Offline conversions that may ship because each source file says so (docs/05 section 5).
    static let community: [Shader] = [
        .init(id: "lottes-crt", name: "Lottes CRT", premium: false, credit: "Timothy Lottes, public domain"),
        .init(id: "lcd3x", name: "LCD3x", premium: false, credit: "Gigaherz, public domain"),
        .init(id: "sharp-bilinear", name: "Sharp Bilinear", premium: false, credit: "Themaister, public domain")
    ]
    static var all: [Shader] { builtIn + community }
}

/// Saved value only. The app follows the system appearance; this keeps old state.json files decoding.
enum AppearanceMode: String, Codable {
    case dark, light, system
}

/// Single source of truth for the shell. Persists to Application Support as JSON.
@MainActor
final class AppState: ObservableObject {
    @Published var games: [GameItem] = []
    @Published var history: [PlaySession] = []
    @Published var activeGameID: UUID?
    @Published var loadedCoreID: String = ""
    /// Non-nil while a game is on screen.
    @Published var session: GameSession?
    /// A launch is preparing the core, before any game view is on screen.
    @Published private(set) var launching = false
    @Published var launchFailure: LaunchFailure?
    /// A game waiting on the player's answer: resume its auto save, or start from the battery save.
    @Published var resumeOffer: GameItem?
    /// Waits for the game view to finish dismissing, because an alert cannot present during that.
    private var pendingFailure: LaunchFailure?

    struct LaunchFailure: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String

        var heading: String {
            #if DEBUG
            // A finished benchmark ends its session the same way a failure does.
            if message.hasPrefix("Benchmark saved") { return "Benchmark finished" }
            #endif
            return "Could not play \(title)"
        }
    }

    @Published var nickname: String { didSet { save() } }
    @Published var joined: Date
    @Published var avatarIndex: Int { didSet { save() } }
    @Published var appearance: AppearanceMode { didSet { save() } }
    @Published var quickStart: Bool { didSet { save() } }
    @Published var autoSaveStates: Bool { didSet { save() } }
    /// Off until the player turns it on. Sends game titles to `LibretroThumbnails.host`, and nothing else does.
    @Published var coverArt: Bool {
        didSet {
            save()
            refreshCovers()
        }
    }
    /// Bumped when a cover lands, so covers on screen redraw.
    @Published private(set) var coverRevision = 0
    /// Saved per preset ID or imported filter ID. A preset with no entry uses the defaults.
    @Published var shaderParameters: [String: ShaderParameterValues] { didSet { save() } }
    /// Touch layout per platform ID. A platform with no entry uses the standard layout.
    @Published var platformSkins: [String: String] { didSet { save() } }
    @Published var airPlayFullscreen: Bool { didSet { save() } }
    @Published var iCloudSync: Bool { didSet { save() } }
    @Published var autoFullScreen: Bool { didSet { save() } }
    @Published var respectSilentMode: Bool { didSet { save() } }
    @Published var rumble: Bool { didSet { save() } }
    @Published var skinSoundEffects: Bool { didSet { save() } }
    @Published var language: String { didSet { save() } }
    @Published var shaderID: String { didSet { save() } }
    @Published var defaultCores: [String: String] { didSet { save() } }
    @Published var platformFilter: String = "all"
    @Published var search: String = ""

    let controllers = ControllerManager()
    let triggerPro = TriggerProManager()
    let skins = TouchSkinEngine()
    let store = StoreKitManager()
    let wifi: WiFiTransferServer
    let filters: ImportedFilterStore
    var coverFetcher = CoverArtFetcher()
    private var coverTask: Task<Void, Never>?

    var romDirectory: URL
    private let storeURL: URL

    struct Snapshot: Codable {
        var games: [GameItem]
        var history: [PlaySession]
        var nickname: String
        var joined: Date
        var avatarIndex: Int
        var appearance: AppearanceMode
        var quickStart: Bool
        var autoSaveStates: Bool
        /// Optional, like the two below, so an older state.json still decodes. Older files carry
        /// `coverScraping` instead, which is ignored on purpose: it defaulted to on, and this must not.
        var coverArt: Bool?
        var shaderParameters: [String: ShaderParameterValues]?
        var platformSkins: [String: String]?
        var airPlayFullscreen: Bool
        var iCloudSync: Bool
        var autoFullScreen: Bool
        var respectSilentMode: Bool
        var rumble: Bool
        var skinSoundEffects: Bool
        var language: String
        var shaderID: String
        var defaultCores: [String: String]
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("GagaEmu", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        romDirectory = root.appendingPathComponent("ROMs", isDirectory: true)
        storeURL = root.appendingPathComponent("state.json")
        wifi = WiFiTransferServer(romDirectory: romDirectory)
        filters = ImportedFilterStore(directory: root.appendingPathComponent("Filters", isDirectory: true))
        let stored = (try? Data(contentsOf: storeURL)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        let migrated = stored.flatMap(StateMigration.migrated)
        let snapshot = migrated ?? stored
        games = snapshot?.games ?? []
        history = snapshot?.history ?? []
        nickname = snapshot?.nickname ?? "Adventurer"
        joined = snapshot?.joined ?? Date()
        avatarIndex = snapshot?.avatarIndex ?? 0
        appearance = snapshot?.appearance ?? .dark
        quickStart = snapshot?.quickStart ?? false
        autoSaveStates = snapshot?.autoSaveStates ?? false
        coverArt = snapshot?.coverArt ?? false
        shaderParameters = snapshot?.shaderParameters ?? [:]
        platformSkins = snapshot?.platformSkins ?? [:]
        airPlayFullscreen = snapshot?.airPlayFullscreen ?? false
        iCloudSync = snapshot?.iCloudSync ?? false
        autoFullScreen = snapshot?.autoFullScreen ?? true
        respectSilentMode = snapshot?.respectSilentMode ?? false
        rumble = snapshot?.rumble ?? false
        skinSoundEffects = snapshot?.skinSoundEffects ?? true
        language = snapshot?.language ?? "English"
        shaderID = snapshot?.shaderID ?? "original"
        defaultCores = snapshot?.defaultCores ?? [:]
        skins.loadDefault()
        if migrated != nil { save() }
        wifi.onUploaded = { [weak self] names in
            MainActor.assumeIsolated { self?.addUploads(names) }
        }
    }

    /// A file uploaded again replaces its bytes on disk, so it must not become a second shelf entry.
    func addUploads(_ names: [String]) {
        for name in names where !games.contains(where: { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }) {
            importROM(at: romDirectory.appendingPathComponent(name))
        }
    }

    var totalPlayTime: TimeInterval { games.reduce(0) { $0 + $1.playTime } }

    var activeGame: GameItem? { games.first { $0.id == activeGameID } }

    /// `platformFilter` is "all", "recent" or a platform ID.
    var filteredGames: [GameItem] {
        (platformFilter == "recent" ? recentGames : games).filter { game in
            (platformFilter == "all" || platformFilter == "recent" || game.platformID == platformFilter)
                && (search.isEmpty || game.title.localizedCaseInsensitiveContains(search))
        }
    }

    var recentGames: [GameItem] {
        games.filter { $0.lastPlayed != nil }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    func coreName(for game: GameItem) -> String {
        CoreCatalog.coreName(game.resolvedCoreID(defaults: defaultCores))
    }

    func setCore(_ coreID: String, for gameID: UUID, global: Bool) {
        guard let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index].coreOverride = coreID
        if global { defaultCores[games[index].platformID] = coreID }
        save()
    }

    /// A saved value from the old free toggle must not get past the gate (docs/07 2.6).
    var autoSaveEnabled: Bool { autoSaveStates && store.canUseAutoSaveState }

    /// Offers to resume first when there is an auto save to resume.
    func launch(_ game: GameItem) {
        if autoSaveEnabled, saveStore(for: game).autoSlot != nil {
            resumeOffer = game
        } else {
            start(game)
        }
    }

    func saveStore(for game: GameItem) -> SaveStore {
        SaveStore(romPath: game.resolvedROMPath(romDirectory: romDirectory) ?? game.romPath)
    }

    /// Loads the core off screen first, so a failure stays on the Library with a message. A state that
    /// will not load is not a failed launch: the game still starts, and says why.
    func start(_ game: GameItem, loading slot: SaveSlot? = nil) {
        guard session == nil, !launching else { return }
        launching = true
        Task {
            defer { launching = false }
            do {
                let next = try makeSession(for: game)
                try await next.prepare()
                await applyImportedFilter(to: next)
                if let slot {
                    do {
                        try next.loadState(slot)
                    } catch {
                        next.notice = error.localizedDescription
                    }
                }
                next.onStarted = { [weak self] in self?.recordStart(of: game) }
                next.onPlayTime = { [weak self] in self?.recordPlay(gameID: game.id, seconds: $0) }
                next.onFinish = { [weak self] message in self?.endSession(game: game, message: message) }
                session = next
            } catch {
                launchFailure = LaunchFailure(title: game.title, message: error.localizedDescription)
            }
        }
    }

    #if DEBUG
    /// Runs the benchmark on `core` with `rom`, or with a generated test ROM. It stays out of the Library and
    /// play history.
    func runBenchmark(rom: URL? = nil, core coreID: String = "mgba", seconds: TimeInterval = BenchmarkRun.defaultSeconds) {
        guard session == nil, !launching else { return }
        launching = true
        Task {
            defer { launching = false }
            do {
                // CoreCatalog has no row for a core this build left out, so that is "not part of this build".
                guard let platformID = CoreCatalog.platforms.first(where: { $0.cores.contains { $0.id == coreID } })?.id,
                      let interface = GagaCoreRegistry_FindByID(coreID)?.pointee else {
                    throw GameLaunchError.coreNotBuilt(CoreCatalog.coreName(coreID))
                }
                let romURL = try rom ?? BenchmarkRun.writeTestROM(platformID: platformID, to: romDirectory)
                let game = GameItem(id: UUID(), title: "Benchmark", platformID: platformID, romPath: romURL.path,
                                    coverPath: nil, coreOverride: coreID, playTime: 0, lastPlayed: nil,
                                    isFavorite: false, shaderID: "original")
                let next = try makeSession(for: game)
                next.autoSaveEnabled = { false }
                try await next.prepare()
                let run = BenchmarkRun(session: next, interface: interface, romURL: romURL, seconds: seconds)
                run.attach()
                next.onFinish = { [weak self] message in self?.endSession(game: game, message: message) }
                session = next
                Task { await run.drive() }
            } catch {
                launchFailure = LaunchFailure(title: "Benchmark", message: error.localizedDescription)
            }
        }
    }

    func runBenchmarkIfRequested() {
        let defaults = UserDefaults.standard
        guard ProcessInfo.processInfo.arguments.contains("-GagaBenchmark") else { return }
        let seconds = defaults.double(forKey: "GagaBenchmarkSeconds")
        runBenchmark(rom: defaults.string(forKey: "GagaBenchmarkROM").map { romDirectory.appendingPathComponent($0) },
                     core: defaults.string(forKey: "GagaBenchmarkCore") ?? "mgba",
                     seconds: seconds > 0 ? seconds : BenchmarkRun.defaultSeconds)
    }

    /// `-GagaImportROM <path>`: copies the file in as Files import does, so core work can add a game
    /// without the UI. A file already in the Library is replaced on disk, not added twice. A relative path is
    /// in Documents, where `devicectl device copy to` puts a file without knowing the container's path.
    func importROMIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "GagaImportROM") else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            // "~" is the app's container, whose path changes with each device install; a relative path is under Documents.
            let expanded = (path as NSString).expandingTildeInPath
            try importDebugROM(at: expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : documents.appendingPathComponent(expanded))
        } catch {
            launchFailure = LaunchFailure(title: "Import", message: error.localizedDescription)
        }
    }

    func importDebugROM(at url: URL) throws {
        let dest = try ClipboardImporter.persist(.file(url), into: romDirectory)
        addUploads([dest.lastPathComponent])
    }
    #endif

    func makeSession(for game: GameItem) throws -> GameSession {
        let coreID = game.resolvedCoreID(defaults: defaultCores)
        guard !coreID.isEmpty else { throw GameLaunchError.noCore }
        guard let interface = GagaCoreRegistry_FindByID(coreID)?.pointee else {
            throw GameLaunchError.coreNotBuilt(CoreCatalog.coreName(coreID))
        }
        guard let romPath = game.resolvedROMPath(romDirectory: romDirectory) else {
            throw GameLaunchError.romMissing(URL(fileURLWithPath: game.romPath).lastPathComponent)
        }
        skins.loadBuiltIn(TouchSkinEngine.layoutID(game: game.skinID, platform: platformSkins[game.platformID],
                                                   platformID: game.platformID),
                          platformID: game.platformID)
        skins.hapticsEnabled = rumble
        skins.soundEnabled = skinSoundEffects
        let shader = store.canUseShader(game.shaderID) ? game.shaderID : "original"
        let session = try GameSession(game: game, interface: interface, romPath: romPath, controllers: controllers,
                                      skins: skins, bindings: triggerPro.bindings, shaderID: shader,
                                      respectSilentMode: respectSilentMode,
                                      entitlements: { [store] in store.entitlements })
        session.autoSaveEnabled = { [weak self] in self?.autoSaveEnabled ?? false }
        session.renderer.apply(shaderParameters[shader] ?? ShaderParameterValues())
        return session
    }

    /// A filter that no longer builds is not a failed launch: Original runs, and the player is told.
    private func applyImportedFilter(to session: GameSession) async {
        let id = session.game.shaderID
        guard ImportedFilter.isImported(id) else { return }
        let renderer = session.renderer
        do {
            renderer.setImported(try await filters.pipeline(for: id, device: renderer.device))
            renderer.onImportedFailure = { [weak session] in
                session?.notice = "The imported filter failed on the GPU. Original is on."
            }
        } catch {
            session.notice = "The imported filter did not load, so Original is on.\n\n\(error.localizedDescription)"
        }
    }

    // MARK: - Cover art

    /// The only way covers are fetched, so the toggle alone decides whether a title leaves the device.
    func refreshCovers() {
        coverTask?.cancel()
        guard coverArt else { return }
        let games = self.games
        let fetcher = coverFetcher
        coverTask = Task { [weak self] in
            await fetcher.fetchMissing(games: games, isEnabled: { [weak self] in self?.coverArt ?? false }) {
                self?.coverRevision += 1
            }
        }
    }

    /// Nil while the toggle is off, or until a cover has landed.
    func coverURL(for game: GameItem) -> URL? {
        coverArt ? coverFetcher.cachedCover(for: game) : nil
    }

    private func recordStart(of game: GameItem) {
        activeGameID = game.id
        loadedCoreID = game.resolvedCoreID(defaults: defaultCores)
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index].lastPlayed = Date()
        }
        history.insert(PlaySession(id: UUID(), gameID: game.id, started: Date(), duration: 0), at: 0)
        save()
    }

    private func endSession(game: GameItem, message: String?) {
        pendingFailure = message.map { LaunchFailure(title: game.title, message: $0) }
        activeGameID = nil
        session = nil
    }

    func showPendingFailure() {
        launchFailure = pendingFailure
        pendingFailure = nil
    }

    /// Adds play time to the game and to its newest history entry. A session calls this several times.
    func recordPlay(gameID: UUID, seconds: TimeInterval) {
        guard seconds > 0, let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index].playTime += seconds
        games[index].lastPlayed = Date()
        if let session = history.firstIndex(where: { $0.gameID == gameID }) {
            history[session].duration += seconds
        }
        save()
    }

    @discardableResult
    func importROM(at url: URL, title: String? = nil, platformID: String? = nil) -> GameItem? {
        let platform = platformID ?? CoreCatalog.platformID(forFile: url) ?? "unknown"
        let name = title ?? url.deletingPathExtension().lastPathComponent
        let item = GameItem(id: UUID(), title: name, platformID: platform, romPath: url.path,
                            coverPath: nil, coreOverride: nil, playTime: 0, lastPlayed: nil,
                            isFavorite: false, shaderID: shaderID)
        games.append(item)
        save()
        refreshCovers()
        return item
    }

    /// Element writes on `games` do not trigger persistence. All edits go through here.
    func update(_ id: UUID, _ change: (inout GameItem) -> Void) {
        guard let index = games.firstIndex(where: { $0.id == id }) else { return }
        change(&games[index])
        save()
        objectWillChange.send()
    }

    func delete(_ game: GameItem) {
        games.removeAll { $0.id == game.id }
        history.removeAll { $0.gameID == game.id }
        save()
    }

    func clearCache() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let caches { try? FileManager.default.removeItem(at: caches) }
    }

    /// Internal, not private, so a test that swaps `games` or `history` can write the originals back.
    func save() {
        let snapshot = Snapshot(games: games, history: history, nickname: nickname, joined: joined,
                                avatarIndex: avatarIndex, appearance: appearance, quickStart: quickStart,
                                autoSaveStates: autoSaveStates, coverArt: coverArt,
                                shaderParameters: shaderParameters, platformSkins: platformSkins,
                                airPlayFullscreen: airPlayFullscreen, iCloudSync: iCloudSync,
                                autoFullScreen: autoFullScreen, respectSilentMode: respectSilentMode,
                                rumble: rumble, skinSoundEffects: skinSoundEffects, language: language,
                                shaderID: shaderID, defaultCores: defaultCores)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
