import SwiftUI
import Foundation
import Compression

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
        let url = URL(fileURLWithPath: romPath), folder = url.deletingLastPathComponent()
        // A disc set's descriptor keeps its set folder, and never falls back to a flat file of the same name.
        let moved = folder.deletingLastPathComponent().lastPathComponent == romDirectory.lastPathComponent
            ? romDirectory.appendingPathComponent(folder.lastPathComponent).appendingPathComponent(url.lastPathComponent)
            : romDirectory.appendingPathComponent(url.lastPathComponent)
        return [romPath, moved.path].first(where: FileManager.default.fileExists(atPath:))
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
            .init(id: "pcsx_rearmed", name: "PCSX-ReARMed", note: "Fast", recommended: true),
            // Cached interpreter and software renderer only. Boots its embedded OpenBIOS when no BIOS is present.
            .init(id: "swanstation", name: "SwanStation", note: "Interpreter", recommended: false)
        ]),
        .init(id: "saturn", name: "Sega Saturn", manufacturer: "Sega", cores: [
            .init(id: "beetle_saturn", name: "Beetle Saturn", note: "Cycle accuracy", recommended: true)
        ]),
        .init(id: "megacd", name: "Mega-CD", manufacturer: "Sega", cores: [
            .init(id: "jgenesis", name: "JGenesis", note: "Mega-CD accuracy", recommended: true),
            .init(id: "genesis_plus_gx", name: "Genesis Plus GX", note: "Sideload", recommended: false),
            .init(id: "picodrive", name: "PicoDrive", note: "Sideload", recommended: false)
        ]),
        // Genesis Plus GX and PicoDrive also run the .sms and .gg files this platform takes; JGenesis runs Mega Drive only.
        .init(id: "megadrive", name: "Mega Drive", manufacturer: "Sega", cores: [
            .init(id: "jgenesis", name: "JGenesis", note: "Default", recommended: true),
            .init(id: "genesis_plus_gx", name: "Genesis Plus GX", note: "Sideload", recommended: false),
            .init(id: "picodrive", name: "PicoDrive", note: "Sideload", recommended: false)
        ]),
        // Sideload builds only, so App Store builds have no 32X platform (docs/03 section 5).
        .init(id: "sega32x", name: "32X", manufacturer: "Sega", cores: [
            .init(id: "picodrive", name: "PicoDrive", note: "Default", recommended: true)
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
            .init(id: "bsnes", name: "bsnes", note: "Cycle accuracy", recommended: true),
            // Sideload builds only: a non-commercial licence (docs/03 section 5). Hidden when excluded.
            .init(id: "snes9x", name: "Snes9x", note: "Speed", recommended: false)
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
        .init(id: "pce", name: "PC Engine", manufacturer: "NEC", cores: [
            .init(id: "beetle_pce_fast", name: "Beetle PCE Fast", note: "HuCard and CD", recommended: true)
        ]),
        .init(id: "sgx", name: "SuperGrafx", manufacturer: "NEC", cores: [
            .init(id: "beetle_supergrafx", name: "Beetle SuperGrafx", note: "Dual VDC", recommended: true)
        ]),
        .init(id: "vb", name: "Virtual Boy", manufacturer: "Nintendo", cores: [
            .init(id: "beetle_vb", name: "Beetle VB", note: "Red on black", recommended: true)
        ]),
        .init(id: "ngp", name: "Neo Geo Pocket", manufacturer: "SNK", cores: [
            .init(id: "beetle_ngp", name: "Beetle NeoPop", note: "Pocket and Color", recommended: true)
        ]),
        .init(id: "ws", name: "WonderSwan", manufacturer: "Bandai", cores: [
            .init(id: "beetle_wswan", name: "Beetle WonderSwan", note: "Mono and Color", recommended: true)
        ]),
        .init(id: "pokemini", name: "Pokémon Mini", manufacturer: "Nintendo", cores: [
            .init(id: "pokemini", name: "PokeMini", note: "Free BIOS built in", recommended: true)
        ]),
        .init(id: "arcade", name: "Arcade", manufacturer: "Arcade", cores: [
            .init(id: "mame", name: "MAME", note: "Wide catalog", recommended: true),
            // Sideload builds only. FBNeo names some sets differently, so the player picks it per game (docs/03 section 8).
            .init(id: "fbneo", name: "FinalBurn Neo", note: "Sideload", recommended: false)
        ]),
        .init(id: "dos", name: "MS-DOS", manufacturer: "Vintage", cores: [
            .init(id: "dosbox_pure", name: "DOSBox Pure", note: "ZIP launch", recommended: true)
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
        let special = ["saturn": "SAT", "megacd": "MCD", "megadrive": "MD", "sega32x": "32X", "dreamcast": "DC", "n3ds": "3DS",
                       "arcade": "ARC", "unknown": "ETC"]
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
        // Disc images serve PS1, PSP, Mega-CD and DOS alike: platformID(forFile:) looks inside, and asks when unsure.
        // An EBOOT.PBP holds a PSP program or a PS1 disc: platformID(forFile:) looks inside.
        case "pbp": return "ps1"
        // A PS-EXE also ends in .exe. platformID(forFile:) tells the two apart by the file's first bytes.
        // The rest are the DOSBox Pure extensions no other core takes.
        case "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf": return "dos"
        case "cso", "elf": return "psp"
        case "gdi", "cdi": return "dreamcast"
        case "md", "gen", "smd", "sms", "gg": return "megadrive"
        // A .ccd is a CloneCD disc, which only the PC Engine core opens. A PC Engine .cue is placed by its contents.
        case "pce", "ccd": return "pce"
        case "sgx": return "sgx"
        case "vb", "vboy": return "vb"
        case "ngp", "ngc", "ngpc", "npc": return "ngp"
        case "ws", "wsc", "pc2": return "ws"
        case "min": return "pokemini"
        // PicoDrive is the only 32X core and sideload only, so an App Store set has no 32X platform and no .32x.
        case "32x": return platform("sega32x") == nil ? nil : "sega32x"
        #if DEBUG
        case "gagavk": return "vktest"
        #endif
        // A MAME ROM set, kept zipped as MAME reads it. A .zip serves Arcade and DOS: platformID(forFile:) looks inside.
        case "7z": return "arcade"
        default: return nil
        }
    }

    /// Extensions a disc image can have. Without a platform from `platformID(forFile:)`, import asks the player.
    static let discExtensions: Set<String> = ["iso", "bin", "cue", "chd", "img", "m3u", "ccd", "toc"]
    /// The platforms import offers for a disc it could not place, in that order, where a core is listed.
    static var discPlatforms: [PlatformInfo] { ["ps1", "saturn", "megacd", "dos", "dreamcast", "pce"].compactMap(platform) }

    /// The platforms import offers for a file it could not place, or nil when it does not ask for that extension.
    static func unplacedPlatforms(forExtension ext: String) -> [PlatformInfo]? {
        if discExtensions.contains(ext.lowercased()) { return discPlatforms }
        return ext.lowercased() == "zip" ? ["arcade", "dos"].compactMap(platform) : nil
    }

    /// As `unplacedPlatforms(forExtension:)`, but a .zip first offers the platforms its entries' extensions name.
    static func unplacedPlatforms(forFile url: URL) -> [PlatformInfo]? {
        guard url.pathExtension.lowercased() == "zip" else { return unplacedPlatforms(forExtension: url.pathExtension) }
        let named = zipEntryNames(url).compactMap { platformID(forExtension: ($0 as NSString).pathExtension.lowercased()) }
        var seen = Set<String>()
        return (named + ["arcade", "dos"]).filter { seen.insert($0).inserted }.compactMap(platform)
    }

    /// The extension's platform, corrected by the file's contents where one extension serves two platforms:
    /// an .exe that starts with "PS-X EXE" is a PlayStation program, a .pbp is placed by `pbpPlatformID(_:)`,
    /// a .zip is placed by `zipPlatformID(_:)`, and a disc image is placed by `discPlatformID(_:)`.
    static func platformID(forFile url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        if discExtensions.contains(ext) { return discPlatformID(url) }
        switch ext {
        case "exe":
            let handle = try? FileHandle(forReadingFrom: url)
            defer { try? handle?.close() }
            let magic = (try? handle?.read(upToCount: 8)) ?? nil
            return magic == Data("PS-X EXE".utf8) ? "ps1" : "dos"
        case "zip":
            return zipPlatformID(url)
        case "pbp":
            return pbpPlatformID(url)
        default:
            return platformID(forExtension: url.pathExtension)
        }
    }

    /// A .pbp's platform: "psp" unless its DATA.PSAR is a PS1 disc (PSISOIMG or PSTITLEIMG) or it is not a PBP
    /// at all, which stays "ps1" as before. The
    /// header is "\0PBP", a version, then eight offsets, of which the eighth is DATA.PSAR's.
    static func pbpPlatformID(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "ps1" }
        defer { try? handle.close() }
        let header = [UInt8]((try? handle.read(upToCount: 40)) ?? Data())
        guard header.count == 40, header[0..<4].elementsEqual([0, 0x50, 0x42, 0x50]) else { return "ps1" }
        let psar = UInt64(header[36]) | UInt64(header[37]) << 8 | UInt64(header[38]) << 16 | UInt64(header[39]) << 24
        guard (try? handle.seek(toOffset: psar)) != nil, let magic = try? handle.read(upToCount: 10) else { return "psp" }
        return magic.starts(with: Data("PSISOIMG".utf8)) || magic.starts(with: Data("PSTITLEIMG".utf8)) ? "ps1" : "psp"
    }

    /// A .zip's platform from its central directory, nothing extracted. First a console: the zip holds one ROM
    /// for one, as `zipConsoleROM(_:)` finds. DOS: it holds an .exe, .com, .bat or
    /// DOSBox .conf. Arcade: its name is a machine in `mameMachines`, or every entry is ROM-like (no extension,
    /// .bin, .rom, or one with a digit, as in "pacman.6e"). Otherwise nil, and import asks.
    static func zipPlatformID(_ url: URL) -> String? {
        let entries = zipEntries(url)
        if let rom = zipConsoleROM(entries) { return rom.platformID }
        let names = entries.map(\.name)
        let exts = names.map { ($0 as NSString).pathExtension.lowercased() }
        if exts.contains(where: { ["exe", "com", "bat", "conf"].contains($0) }) { return "dos" }
        if mameMachines.contains(url.deletingPathExtension().lastPathComponent.lowercased()) { return "arcade" }
        let romLike = Swift.zip(names, exts).allSatisfy { name, ext in
            !name.contains("/") && (ext.isEmpty || ext == "bin" || ext == "rom" || ext.contains(where: \.isNumber))
        }
        return !names.isEmpty && romLike ? "arcade" : nil
    }

    /// A disc image's platform from its first 64 KiB, or nil when that does not say. PS1: "PLAYSTATION" as
    /// the system ID in sector 16, or SYSTEM.CNF in the root directory. PSP: "PSP GAME" as that system ID.
    /// Saturn: "SEGA SEGASATURN" opening the first sector. Dreamcast: "SEGA SEGAKATANA" opening it (IP.BIN).
    /// Mega-CD: "SEGADISCSYSTEM" or any other "SEGA" opening it. Any other ISO 9660 disc, and any .iso or
    /// .img, is DOS. A .cue is read through its first FILE, an .m3u through its first entry, a .toc through
    /// its first FILE or DATAFILE, and a CloneCD .ccd through the .img beside it. A .cue whose first track is
    /// audio is a PC Engine CD: those open with a warning track, and PS1, Mega-CD and DOS discs with data. A .chd
    /// is placed by `chdPlatformID(_:)`.
    static func discPlatformID(_ url: URL, depth: Int = 0) -> String? {
        let ext = url.pathExtension.lowercased()
        if ext == "chd" { return chdPlatformID(url) }
        if ext == "ccd" {
            // The .img holds raw sectors, which the ISO 9660 rule would call DOS; DOSBox Pure cannot open a .ccd.
            let id = depth < 2 ? discPlatformID(url.deletingPathExtension().appendingPathExtension("img"), depth: 1) : nil
            return id == "dos" ? nil : id
        }
        if ext == "toc" {
            guard depth < 2, let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            // FILE "name" 0 or DATAFILE "name", in cdrdao's format.
            let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
                .first { $0.uppercased().hasPrefix("FILE ") || $0.uppercased().hasPrefix("DATAFILE ") }
            guard let name = line?.split(separator: "\"").dropFirst().first.map(String.init) else { return nil }
            let id = discPlatformID(url.deletingLastPathComponent().appendingPathComponent(name), depth: 1)
            return id == "dos" ? nil : id
        }
        if ext == "cue" || ext == "m3u" {
            guard depth < 2, let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            let name: String?
            if ext == "cue", let track = lines.first(where: { $0.uppercased().hasPrefix("TRACK ") }),
               track.uppercased().hasSuffix(" AUDIO") {
                return "pce"
            }
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
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
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
        if has("PSP GAME", in: 32776..<32808) { return "psp" }
        if pvdStarts.contains(where: { has("PLAYSTATION", in: ($0 + 8)..<($0 + 40)) }) || has("SYSTEM.CNF;1", in: 0..<bytes.count) {
            return "ps1"
        }
        // A raw image's first sector has 16 bytes of sync and header before the data.
        if [0, 16].contains(where: { has("SEGA SEGAKATANA", in: $0..<($0 + 15)) }) { return "dreamcast" }
        for start in [0, 16] where has("SEGA", in: start..<(start + 4)) {
            return has("SEGA SEGASATURN", in: start..<(start + 15)) ? "saturn" : "megacd"
        }
        if ext == "iso" || ext == "img" || pvdStarts.contains(where: { has("CD001", in: ($0 + 1)..<($0 + 6)) }) {
            return "dos"
        }
        return nil
    }

    /// A .chd's platform from its metadata, which is stored uncompressed: Dreamcast when a track is a GD-ROM
    /// track ("CHGD", or "CHGT" from older chdman). Otherwise nil, and import asks.
    /// shortcut: a CD-ROM .chd's sectors are compressed, so a PS1, Mega-CD or Dreamcast CD-R .chd still asks.
    static func chdPlatformID(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        func read(_ offset: UInt64, _ count: Int) -> [UInt8] {
            guard (try? handle.seek(toOffset: offset)) != nil else { return [] }
            return [UInt8]((try? handle.read(upToCount: count)) ?? Data())
        }
        func be(_ bytes: [UInt8], _ at: Int, _ count: Int) -> UInt64 {
            bytes[at..<(at + count)].reduce(0) { $0 << 8 | UInt64($1) }
        }
        let header = read(0, 124)
        guard header.count >= 56, header.starts(with: Array("MComprHD".utf8)) else { return nil }
        // The first metadata entry's offset: header version 5 keeps it at byte 48, versions 3 and 4 at 36.
        var next = be(header, 12, 4) >= 5 ? be(header, 48, 8) : be(header, 36, 8)
        // Each entry: a 4-byte tag, flags and a 3-byte length, then the next entry's offset. A bound stops a loop.
        for _ in 0..<256 where next != 0 {
            let entry = read(next, 16)
            guard entry.count == 16 else { return nil }
            if ["CHGD", "CHGT"].contains(String(decoding: entry[0..<4], as: UTF8.self)) { return "dreamcast" }
            next = be(entry, 8, 8)
        }
        return nil
    }

    /// The file names in a ZIP's central directory, or none when the file is not a readable ZIP.
    static func zipEntryNames(_ url: URL) -> [String] { zipEntries(url).map(\.name) }

    /// One central directory record. Zip64 sizes read as 0xFFFFFFFF, which every ROM limit refuses.
    struct ZipEntry: Equatable {
        var name: String
        var flags: Int
        var method: Int
        var crc: UInt32
        var compressedSize: Int
        var size: Int
        var localHeaderOffset: Int
    }

    /// Files a .zip may carry beside the ROM, ignored when placing it.
    static let zipSidecarExtensions: Set<String> = ["txt", "nfo", "diz", "htm", "html", "url", "sfv", "pdf", "jpg", "jpeg", "png"]

    /// The most a console ROM in a .zip may inflate to, so a zip bomb stops there. Each is above the largest
    /// real image for the platform; any other platform gets 2 GiB.
    static func zipROMLimit(_ platformID: String) -> Int {
        let mib = 1 << 20
        let limits = ["gb": 8 * mib, "gbc": 8 * mib, "gba": 32 * mib, "nes": 8 * mib, "snes": 16 * mib,
                      "megadrive": 16 * mib, "n64": 64 * mib, "nds": 512 * mib]
        return limits[platformID] ?? 2048 * mib
    }

    /// The one ROM a .zip holds for a console platform (not Arcade or DOS), or nil. Folders and sidecar files
    /// are ignored. A name with a ".." part, an absolute or drive path, or a size over the platform's limit is refused.
    static func zipConsoleROM(_ entries: [ZipEntry]) -> (entry: ZipEntry, platformID: String)? {
        try? zipConsoleCheck(entries)?.get()
    }

    /// As `zipConsoleROM(_:)`, but a refused ROM is a failure that says why, and nil means no one console ROM.
    static func zipConsoleCheck(_ entries: [ZipEntry]) -> Result<(entry: ZipEntry, platformID: String), ZipError>? {
        let files = entries.filter {
            !$0.name.hasSuffix("/") && !zipSidecarExtensions.contains(($0.name as NSString).pathExtension.lowercased())
        }
        guard files.count == 1, let entry = files.first else { return nil }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        // A .pbp serves PS1 and PSP alike and is placed by its contents, which a zip hides.
        guard ext != "pbp", let id = platformID(forExtension: ext), id != "arcade", id != "dos", platform(id) != nil
        else { return nil }
        let parts = entry.name.split(whereSeparator: { $0 == "/" || $0 == "\\" })
        guard !entry.name.hasPrefix("/"), !entry.name.hasPrefix("\\"), parts.first?.hasSuffix(":") != true,
              !parts.contains("..") else { return .failure(.unsafeName) }
        guard entry.size <= zipROMLimit(id) else { return .failure(.tooLarge) }
        return .success((entry, id))
    }

    enum ZipError: LocalizedError {
        case unsupported, corrupt, tooLarge, unsafeName
        var errorDescription: String? {
            switch self {
            case .unsupported: return "The zip uses encryption or a compression GagaEmu cannot read."
            case .corrupt: return "The zip is damaged."
            case .tooLarge: return "The file in the zip is too large."
            case .unsafeName: return "The file in the zip has a path GagaEmu refuses, such as one that leaves its folder."
            }
        }
    }

    /// Writes one stored or deflated entry to `destination`, or under a new name when a different file has that
    /// name, and returns where it went. Stops past `limit` bytes, whatever the entry claims, and checks the size
    /// and CRC-32 before the file appears.
    @discardableResult
    static func extractZipEntry(_ entry: ZipEntry, from zip: URL, to destination: URL, limit: Int) throws -> URL {
        guard entry.flags & 1 == 0, entry.method == 0 || entry.method == 8 else { throw ZipError.unsupported }
        guard entry.size <= limit else { throw ZipError.tooLarge }
        let input = try FileHandle(forReadingFrom: zip)
        defer { try? input.close() }
        try input.seek(toOffset: UInt64(entry.localHeaderOffset))
        let header = [UInt8](try input.read(upToCount: 30) ?? Data())
        guard header.count == 30, header[0..<4].elementsEqual([0x50, 0x4B, 3, 4]) else { throw ZipError.corrupt }
        let skip = (Int(header[26]) | Int(header[27]) << 8) + (Int(header[28]) | Int(header[29]) << 8)
        try input.seek(toOffset: UInt64(entry.localHeaderOffset + 30 + skip))

        let part = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).part")
        guard FileManager.default.createFile(atPath: part.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        defer { try? FileManager.default.removeItem(at: part) }
        let output = try FileHandle(forWritingTo: part)
        var written = 0
        var crc: UInt32 = 0xFFFF_FFFF
        func emit(_ bytes: UnsafeBufferPointer<UInt8>) throws {
            written += bytes.count
            guard written <= limit else { throw ZipError.tooLarge }
            for byte in bytes { crc = RomPatcher.table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
            try output.write(contentsOf: bytes)
        }
        let chunk = 1 << 20
        var remaining = entry.compressedSize
        do {
            defer { try? output.close() }
            if entry.method == 0 {
                while remaining > 0 {
                    let data = try input.read(upToCount: min(remaining, chunk)) ?? Data()
                    guard !data.isEmpty else { throw ZipError.corrupt }
                    remaining -= data.count
                    try data.withUnsafeBytes { try emit($0.bindMemory(to: UInt8.self)) }
                }
            } else {
                // COMPRESSION_ZLIB is raw DEFLATE (RFC 1951), the zip method 8 stream.
                let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
                defer { stream.deallocate() }
                guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK
                else { throw ZipError.corrupt }
                defer { compression_stream_destroy(stream) }
                let source = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
                let target = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
                defer { source.deallocate(); target.deallocate() }
                stream.pointee.src_size = 0
                while true {
                    if stream.pointee.src_size == 0, remaining > 0 {
                        let data = try input.read(upToCount: min(remaining, chunk)) ?? Data()
                        guard !data.isEmpty else { throw ZipError.corrupt }
                        data.copyBytes(to: source, count: data.count)
                        stream.pointee.src_ptr = UnsafePointer(source)
                        stream.pointee.src_size = data.count
                        remaining -= data.count
                    }
                    stream.pointee.dst_ptr = target
                    stream.pointee.dst_size = chunk
                    let flags = remaining == 0 ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                    let status = compression_stream_process(stream, flags)
                    guard status != COMPRESSION_STATUS_ERROR else { throw ZipError.corrupt }
                    let produced = chunk - stream.pointee.dst_size
                    try emit(UnsafeBufferPointer(start: target, count: produced))
                    if status == COMPRESSION_STATUS_END { break }
                    // Input spent and nothing came out: the stream ended early.
                    if produced == 0, stream.pointee.src_size == 0, remaining == 0 { throw ZipError.corrupt }
                }
            }
        }
        guard written == entry.size, crc ^ 0xFFFF_FFFF == entry.crc else { throw ZipError.corrupt }
        return try ClipboardImporter.place(part, named: destination.lastPathComponent, in: destination.deletingLastPathComponent())
    }

    /// Unpacks a zip that holds one disc set (a descriptor and the files it names, at most 2 GiB each) into a new
    /// set folder, and returns it. Nil, with nothing left behind, when the zip is not exactly one complete set.
    static func extractZipDiscSet(_ entries: [ZipEntry], from zip: URL, into romDirectory: URL) throws -> URL? {
        let files = entries.filter { !$0.name.hasSuffix("/") && !zipSidecarExtensions.contains(($0.name as NSString).pathExtension.lowercased()) }
        let names = files.map { WiFiTransferServer.sanitize(String($0.name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last ?? "")) }
        guard files.count >= 2, let sheet = names.first(where: DiscSet.isDescriptor), !names.contains(""),
              Set(names.map { $0.lowercased() }).count == names.count else { return nil }
        guard files.allSatisfy({ !$0.name.hasPrefix("/") && !$0.name.hasPrefix("\\") && !$0.name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).contains("..") })
        else { throw ZipError.unsafeName }
        let folder = try DiscSet.newFolder(for: sheet, in: romDirectory)
        do {
            for (entry, name) in Swift.zip(files, names) {
                try extractZipEntry(entry, from: zip, to: folder.appendingPathComponent(name), limit: zipROMLimit("disc"))
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        guard DiscSet.primary(in: folder) != nil, DiscSet.missing(in: folder).isEmpty,
              Set(DiscSet.wanted(in: folder).map { $0.lowercased() }) == Set(names.map { $0.lowercased() }) else {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
        return folder
    }

    /// The records in a ZIP's central directory, or none when the file is not a readable ZIP.
    static func zipEntries(_ url: URL) -> [ZipEntry] {
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
        let records = [UInt8](directory)
        var entries: [ZipEntry] = []
        var i = 0
        while i + 46 <= records.count, u32(records, i) == 0x0201_4B50 {
            let nameLength = u16(records, i + 28)
            let next = i + 46 + nameLength + u16(records, i + 30) + u16(records, i + 32)
            guard i + 46 + nameLength <= records.count else { break }
            entries.append(ZipEntry(name: String(decoding: records[(i + 46)..<(i + 46 + nameLength)], as: UTF8.self),
                                    flags: u16(records, i + 8), method: u16(records, i + 10),
                                    crc: UInt32(u32(records, i + 16)), compressedSize: u32(records, i + 20),
                                    size: u32(records, i + 24), localHeaderOffset: u32(records, i + 42)))
            i = next
        }
        return entries
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
        "org.libretro.dosbox-pure": "dosbox_pure"
    ]

    /// Cores removed by docs/03 section 6. A choice of one falls back to the platform default.
    /// J2meJS and EKA2L1 failed their spikes (docs/07 6.4 and 6.6).
    static let removedCoreIDs: Set<String> = [
        "org.libretro.swanstation", "org.libretro.kronos", "org.libretro.genesis-plus-gx",
        "org.libretro.picodrive", "org.libretro.snes9x", "org.libretro.fbneo",
        "org.j2mejs", "j2mejs", "eka2l1"
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

    /// A file uploaded again with the same bytes keeps its name, so it must not become a second shelf entry.
    /// A name is a path under the ROM folder, as "Game/Game.cue" for a disc set.
    func addUploads(_ names: [String]) {
        for name in names where !games.contains(where: { ClipboardImporter.relativePath(URL(fileURLWithPath: $0.romPath), in: romDirectory) == name
                                                          || (!name.contains("/") && URL(fileURLWithPath: $0.romPath).lastPathComponent == name) }) {
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
        addUploads([ClipboardImporter.relativePath(dest, in: romDirectory)])
    }

    /// `-GagaImportTestROM <core-id>`: adds that core's generated test ROM (the benchmark's) to the Library,
    /// set to play on that core, so a device walk (UITests) has a game with a touch layout and no file to copy.
    func importTestROMIfRequested() {
        guard let coreID = UserDefaults.standard.string(forKey: "GagaImportTestROM") else { return }
        do {
            guard let platformID = CoreCatalog.platforms.first(where: { $0.cores.contains { $0.id == coreID } })?.id else {
                throw GameLaunchError.coreNotBuilt(CoreCatalog.coreName(coreID))
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GagaTestROM", isDirectory: true)
            let name = try BenchmarkRun.writeTestROM(platformID: platformID, to: folder).lastPathComponent
            try importDebugROM(at: folder.appendingPathComponent(name))
            if let game = games.first(where: { URL(fileURLWithPath: $0.romPath).lastPathComponent == name }) {
                update(game.id) { $0.coreOverride = coreID }
            }
        } catch {
            launchFailure = LaunchFailure(title: "Import", message: error.localizedDescription)
        }
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

    /// Why the last `importROM(at:)` stored no game or kept an older file, for the import screen; nil otherwise.
    private(set) var lastImportNote: String?

    /// The cores' system folder BIOS files move to. A test points it at a temporary folder.
    lazy var systemDirectory: URL = GagaCoreWrapper.systemDirectory

    @discardableResult
    func importROM(at url: URL, title: String? = nil, platformID: String? = nil) -> GameItem? {
        lastImportNote = nil
        let inROMFolder = url.deletingLastPathComponent().standardizedFileURL == romDirectory.standardizedFileURL
        // A BIOS file the BIOS Files screen names, at a size its core reads, moves to the cores' system folder.
        // Another size under that name (a game called firmware.bin) is placed as a game. A different file already
        // in System is never replaced. A .rom (such as an FDS folder's disksys.rom) is never a game.
        let fileName = url.lastPathComponent.lowercased()
        // Not url.resourceValues: a URL caches them, so a file rewritten at the same URL kept its old size.
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
        if platformID == nil, inROMFolder, let size, BIOSManagerView.sizes[fileName]?.contains(size) == true {
            try? FileManager.default.createDirectory(at: systemDirectory, withIntermediateDirectories: true)
            let dest = systemDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.moveItem(at: url, to: dest)
            } else if ClipboardImporter.sameContents(url, dest) {
                try? FileManager.default.removeItem(at: url)
            } else {
                lastImportNote = "\(url.lastPathComponent) differs from the \(fileName) already in System, so that one was kept. The new file stays in ROMs."
            }
            return nil
        }
        if platformID == nil, url.pathExtension.lowercased() == "rom" { return nil }
        if let folder = DiscSet.folder(of: url, romDirectory: romDirectory) {
            return importDiscSet(folder, arrived: url, title: title, platformID: platformID)
        }
        var url = url
        // No console core reads a .zip, so its one ROM is stored as a plain file and the copied zip goes.
        // Only a zip already in the ROM folder is unpacked, so a file elsewhere is never removed. A damaged or
        // refused zip is reported and stays where it is, with no shelf entry and no platform question.
        if platformID == nil, url.pathExtension.lowercased() == "zip", inROMFolder {
            let entries = CoreCatalog.zipEntries(url)
            do {
                guard !entries.isEmpty else { throw CoreCatalog.ZipError.corrupt }
                if let rom = try CoreCatalog.zipConsoleCheck(entries)?.get() {
                    let name = WiFiTransferServer.sanitize(String(rom.entry.name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last ?? ""))
                    guard !name.isEmpty else { throw CoreCatalog.ZipError.unsafeName }
                    let placed = try CoreCatalog.extractZipEntry(rom.entry, from: url, to: romDirectory.appendingPathComponent(name),
                                                                 limit: CoreCatalog.zipROMLimit(rom.platformID))
                    try? FileManager.default.removeItem(at: url)
                    url = placed
                } else if let folder = try CoreCatalog.extractZipDiscSet(entries, from: url, into: romDirectory) {
                    try? FileManager.default.removeItem(at: url)
                    return importDiscSet(folder, arrived: folder, title: title, platformID: nil)
                }
            } catch {
                lastImportNote = "\(url.lastPathComponent): \(error.localizedDescription)"
                return nil
            }
        }
        return addGame(url, title: title, platform: platformID ?? CoreCatalog.platformID(forFile: url) ?? "unknown")
    }

    /// Game entries this run added and nobody has played, by ROM path. Only their files may join a disc set
    /// that arrives later, so an older game is never taken.
    private var freshImports: Set<String> = []

    /// A disc set's file arrived in `folder`: take earlier arrivals in, reuse an identical older set, and keep one
    /// entry on the set's descriptor. Nil while the folder has no descriptor or the file has already moved on.
    private func importDiscSet(_ folder: URL, arrived url: URL, title: String?, platformID: String?) -> GameItem? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let taken = DiscSet.gather(into: folder, romDirectory: romDirectory) { file in
            let entries = games.filter { $0.resolvedROMPath(romDirectory: romDirectory) == file.path }
            return entries.allSatisfy { freshImports.contains($0.romPath) && $0.playTime == 0 && $0.lastPlayed == nil }
        }
        let gone = Set(taken.map(\.standardizedFileURL.path))
        dropFresh { game in
            guard let path = game.resolvedROMPath(romDirectory: romDirectory) ?? Optional(game.romPath) else { return false }
            return gone.contains(path) || gone.contains(URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL.path)
        }
        guard var sheet = DiscSet.primary(in: folder) else { return nil }
        if let twin = DiscSet.twin(of: folder, in: romDirectory), let twinSheet = DiscSet.primary(in: twin) {
            // The same set again: the older folder stays and this copy goes.
            dropFresh { $0.romPath == sheet.path }
            if !games.contains(where: { $0.resolvedROMPath(romDirectory: romDirectory) == sheet.path }) {
                try? fileManager.removeItem(at: folder)
                sheet = twinSheet
            }
        }
        let platform = platformID ?? CoreCatalog.platformID(forFile: sheet) ?? "unknown"
        // A sheet that came before its tracks could not be placed then.
        if let index = games.firstIndex(where: { $0.romPath == sheet.path }), games[index].platformID == "unknown", platform != "unknown" {
            update(games[index].id) { $0.platformID = platform }
        }
        return addGame(sheet, title: title, platform: platform)
    }

    /// Removes fresh entries that match, after their files joined a disc set.
    private func dropFresh(_ match: (GameItem) -> Bool) {
        let dropped = games.filter { freshImports.contains($0.romPath) && $0.playTime == 0 && $0.lastPlayed == nil && match($0) }
        guard !dropped.isEmpty else { return }
        let ids = Set(dropped.map(\.id))
        games.removeAll { ids.contains($0.id) }
        history.removeAll { ids.contains($0.gameID) }
        save()
    }

    private func addGame(_ url: URL, title: String?, platform: String) -> GameItem {
        // Import reuses a file with the same contents, so the same file in the ROM folder is the same game.
        if url.deletingLastPathComponent().standardizedFileURL == romDirectory.standardizedFileURL,
           let existing = games.first(where: { URL(fileURLWithPath: $0.romPath).lastPathComponent == url.lastPathComponent }) {
            return existing
        }
        if DiscSet.folder(of: url, romDirectory: romDirectory) != nil,
           let existing = games.first(where: { $0.resolvedROMPath(romDirectory: romDirectory) == url.path }) {
            return existing
        }
        let name = title ?? url.deletingPathExtension().lastPathComponent
        let item = GameItem(id: UUID(), title: name, platformID: platform, romPath: url.path,
                            coverPath: nil, coreOverride: nil, playTime: 0, lastPlayed: nil,
                            isFavorite: false, shaderID: shaderID)
        games.append(item)
        freshImports.insert(item.romPath)
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

    /// The disc set folder deleting `game` removes: nil for a flat game, or while another entry still points into it.
    func folderDeleted(with game: GameItem) -> URL? {
        guard let path = game.resolvedROMPath(romDirectory: romDirectory),
              let folder = DiscSet.folder(of: URL(fileURLWithPath: path), romDirectory: romDirectory),
              !games.contains(where: { $0.id != game.id && $0.resolvedROMPath(romDirectory: romDirectory).map { URL(fileURLWithPath: $0).deletingLastPathComponent() } == folder })
        else { return nil }
        return folder
    }

    /// Library games whose .m3u (a Multi-Disc Helper playlist in the ROM folder) names a file in `folder`.
    func playlists(into folder: URL) -> [GameItem] {
        games.filter { game in
            guard let path = game.resolvedROMPath(romDirectory: romDirectory), path.lowercased().hasSuffix(".m3u"),
                  DiscSet.folder(of: URL(fileURLWithPath: path), romDirectory: romDirectory) == nil
            else { return false }
            return DiscSet.playlistEntries(of: URL(fileURLWithPath: path))
                .contains { $0.contains("/") && $0.split(separator: "/").first?.lowercased() == folder.lastPathComponent.lowercased() }
        }
    }

    /// A disc set's folder goes with its game, unless another entry still points into it. Saves stay. A folder
    /// a playlist game plays from is never deleted: the Library asks for that game to go first.
    func delete(_ game: GameItem) {
        let folder = folderDeleted(with: game)
        if let folder, !playlists(into: folder).isEmpty { return }
        games.removeAll { $0.id == game.id }
        history.removeAll { $0.gameID == game.id }
        save()
        if let folder { try? FileManager.default.removeItem(at: folder) }
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
