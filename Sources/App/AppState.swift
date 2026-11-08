import SwiftUI
import Foundation
import Compression
import UniformTypeIdentifiers

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
            // Interpreter and Vulkan on MoltenVK (layer path). Boots its embedded OpenBIOS when no BIOS is present.
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
        ]),
        // group-retro backlog platforms (docs/07 section 8.x). Genesis Plus GX and PicoDrive also run Master System,
        // Game Gear and SG-1000 games in sideload builds.
        .init(id: "mastersystem", name: "Master System", manufacturer: "Sega", cores: [
            .init(id: "gearsystem", name: "Gearsystem", note: "Default", recommended: true),
            .init(id: "genesis_plus_gx", name: "Genesis Plus GX", note: "Sideload", recommended: false),
            .init(id: "picodrive", name: "PicoDrive", note: "Sideload", recommended: false)
        ]),
        .init(id: "gamegear", name: "Game Gear", manufacturer: "Sega", cores: [
            .init(id: "gearsystem", name: "Gearsystem", note: "Default", recommended: true),
            .init(id: "genesis_plus_gx", name: "Genesis Plus GX", note: "Sideload", recommended: false),
            .init(id: "picodrive", name: "PicoDrive", note: "Sideload", recommended: false)
        ]),
        .init(id: "sg1000", name: "SG-1000", manufacturer: "Sega", cores: [
            .init(id: "gearsystem", name: "Gearsystem", note: "Default", recommended: true),
            .init(id: "genesis_plus_gx", name: "Genesis Plus GX", note: "Sideload", recommended: false),
            .init(id: "picodrive", name: "PicoDrive", note: "Sideload", recommended: false)
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
                       "arcade": "ARC", "unknown": "ETC",
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
        // Azahar's loaders: NCSD (.3ds, .cci), NCCH (.cxi, .app), 3DSX homebrew, and ARM ELF (.axf; an .elf is
        // placed by platformID(forFile:)). A .cia must be installed to a console's NAND first, so it is not offered.
        case "3ds", "cci", "cxi", "app", "3dsx", "axf": return "n3ds"
        // Disc images serve PS1, PSP, Mega-CD and DOS alike: platformID(forFile:) looks inside, and asks when unsure.
        // An EBOOT.PBP holds a PSP program or a PS1 disc: platformID(forFile:) looks inside.
        case "pbp": return "ps1"
        // A PS-EXE also ends in .exe. platformID(forFile:) tells the two apart by the file's first bytes.
        // The rest are the DOSBox Pure extensions no other core takes.
        case "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf": return "dos"
        case "cso", "elf": return "psp"
        case "gdi", "cdi": return "dreamcast"
        case "md", "gen", "smd": return "megadrive"
        case "sms": return "mastersystem"
        case "gg": return "gamegear"
        case "sg", "mv": return "sg1000"
        // A CloneCD .ccd serves PS1, Saturn and PC Engine, so it is a disc placed by content, like a .cue.
        case "pce": return "pce"
        case "sgx": return "sgx"
        case "vb", "vboy": return "vb"
        case "ngp", "ngc", "ngpc", "npc": return "ngp"
        case "ws", "wsc", "pc2": return "ws"
        case "min": return "pokemini"
        // PicoDrive is the only 32X core and sideload only, so an App Store set has no 32X platform and no .32x.
        case "32x": return platform("sega32x") == nil ? nil : "sega32x"
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
    static let discExtensions: Set<String> = ["iso", "bin", "cue", "chd", "img", "m3u", "ccd", "toc"]
    /// The platforms import offers for a disc it could not place, in that order, where a core is listed.
    static var discPlatforms: [PlatformInfo] { ["ps1", "saturn", "megacd", "dos", "pce", "dreamcast"].compactMap(platform) }

    /// The platforms import offers for a file it could not place, or nil when it does not ask for that extension.
    static func unplacedPlatforms(forExtension ext: String) -> [PlatformInfo]? {
        if discExtensions.contains(ext.lowercased()) { return discPlatforms }
        if ext.lowercased() == "7z" { return ["arcade"].compactMap(platform) }
        return ext.lowercased() == "zip" ? ["arcade", "dos"].compactMap(platform) : nil
    }

    /// As `unplacedPlatforms(forExtension:)`, but a .zip or .7z first offers the platforms its entries'
    /// extensions name. DOSBox Pure reads zips only, so a 7z (whatever its name) never offers DOS.
    static func unplacedPlatforms(forFile url: URL) -> [PlatformInfo]? {
        guard ["zip", "7z"].contains(url.pathExtension.lowercased()) else { return unplacedPlatforms(forExtension: url.pathExtension) }
        let named = archiveEntries(url).compactMap { platformID(forExtension: ($0.name as NSString).pathExtension.lowercased()) }
        var seen = Set<String>()
        let fallback = isSevenZip(url) || url.pathExtension.lowercased() == "7z" ? ["arcade"] : ["arcade", "dos"]
        return (named + fallback).filter { seen.insert($0).inserted }.compactMap(platform)
    }

    /// The extension's platform, corrected by the file's contents where one extension serves two platforms:
    /// an .exe that starts with "PS-X EXE" is a PlayStation program, a .pbp is placed by `pbpPlatformID(_:)`,
    /// a .zip is placed by `zipPlatformID(_:)`, and a disc image is placed by `discPlatformID(_:)`.
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
        case "zip", "7z":
            return zipPlatformID(url)
        case "pbp":
            return pbpPlatformID(url)
        case "elf":
            return elfPlatformID(url)
        default:
            return platformID(forExtension: url.pathExtension)
        }
    }

    /// An .elf's platform from its e_machine field (bytes 18 and 19, little endian): ARM (40) is 3DS homebrew,
    /// anything else stays PSP (MIPS), as before.
    static func elfPlatformID(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "psp" }
        defer { try? handle.close() }
        let header = [UInt8]((try? handle.read(upToCount: 20)) ?? Data())
        guard header.count == 20, header[0..<4].elementsEqual([0x7F, 0x45, 0x4C, 0x46]) else { return "psp" }
        return header[18] == 40 && header[19] == 0 ? "n3ds" : "psp"
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
    /// .bin, .rom, or one with a digit, as in "pacman.6e"). Otherwise nil, and import asks. A .7z (or a 7z named
    /// .zip) follows the same rules, except DOS: DOSBox Pure reads zips only.
    static func zipPlatformID(_ url: URL) -> String? {
        let sevenZip = isSevenZip(url)
        let entries = sevenZip ? sevenZipEntries(url) : zipEntries(url)
        if let rom = zipConsoleROM(entries) { return rom.platformID == "disc" ? nil : rom.platformID }
        let names = entries.map(\.name)
        let exts = names.map { ($0 as NSString).pathExtension.lowercased() }
        if !sevenZip, exts.contains(where: { ["exe", "com", "bat", "conf"].contains($0) }) { return "dos" }
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
        // A Sega disc opens with "SEGA" (after 16 bytes of sync when raw) and has "SEGA" at 0x100 too; a cartridge opens with vectors.
        if [0, 16].contains(where: { head.dropFirst($0).starts(with: "SEGA".utf8) }) { return nil }
        if head.suffix(4).elementsEqual("SEGA".utf8) { return "megadrive" }
        guard (2048...32768).contains(size), size % 2048 == 0, (try? handle.seek(toOffset: size - 4)) != nil,
              let vector = try? handle.read(upToCount: 2), vector.count == 2 else { return nil }
        return vector[vector.startIndex + 1] & 0x10 != 0 ? "atari2600" : nil
    }

    /// A disc image's platform from its first 64 KiB, or nil when that does not say. PS1: "PLAYSTATION" as
    /// the system ID in sector 16, or SYSTEM.CNF in the root directory. PSP: "PSP GAME" as that system ID.
    /// Saturn: "SEGA SEGASATURN" opening the first sector. Dreamcast: "SEGA SEGAKATANA" opening it (IP.BIN).
    /// Mega-CD: "SEGADISCSYSTEM" or any other "SEGA" opening it. Any other ISO 9660 disc, and any .iso or
    /// .img, is DOS. A .cue is read through its first FILE, an .m3u through its first entry, a .toc through
    /// its first FILE or DATAFILE that names a console, and a CloneCD .ccd through the .img beside it (a PC Engine CD when that says
    /// nothing). A .cue whose first FILE names no console and whose first track is audio is a PC Engine CD: those
    /// open with a warning track, and PS1, Mega-CD and DOS discs with data. A .chd
    /// is placed by `chdPlatformID(_:)`.
    static func discPlatformID(_ url: URL, depth: Int = 0) -> String? {
        let ext = url.pathExtension.lowercased()
        if ext == "chd" { return chdPlatformID(url) }
        if ext == "ccd" {
            // The .img holds raw sectors, which the ISO 9660 rule would call DOS; DOSBox Pure cannot open a .ccd.
            // PS1, Saturn and Dreamcast discs name themselves in the .img's sector 16 or IP.BIN, so those are read
            // first; anything else, a missing .img included, is a PC Engine CD. The extension may be upper case.
            let sibling = ["img", "IMG", "Img"].map { url.deletingPathExtension().appendingPathExtension($0) }
                .first { FileManager.default.fileExists(atPath: $0.path) }
            let id = depth < 2 ? sibling.flatMap { discPlatformID($0, depth: 1) } : nil
            return id == nil || id == "dos" ? "pce" : id
        }
        if ext == "toc" {
            guard depth < 2, let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            // FILE "name" 0 or DATAFILE "name", in cdrdao's format. The first file that names a console wins, so
            // an audio track ahead of the data track does not hide it.
            let names = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.uppercased().hasPrefix("FILE ") || $0.uppercased().hasPrefix("DATAFILE ") }
                .compactMap { $0.split(separator: "\"").dropFirst().first.map(String.init) }
            for name in names {
                if let id = discPlatformID(url.deletingLastPathComponent().appendingPathComponent(name), depth: 1), id != "dos" {
                    return id
                }
            }
            return nil
        }
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
            let id = name.flatMap { discPlatformID(url.deletingLastPathComponent().appendingPathComponent($0), depth: 1) }
            // The first FILE's own header wins (SEGA SEGAKATANA, SEGA SEGASATURN, PLAYSTATION). Only a disc it does
            // not name and whose first track is audio is a PC Engine CD, which opens with a warning track.
            if ext == "cue", id == nil || id == "dos",
               lines.first(where: { $0.uppercased().hasPrefix("TRACK ") })?.uppercased().hasSuffix(" AUDIO") == true {
                return "pce"
            }
            return id
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
        /// Set for a 7z file: its index in the archive, which `extractZipEntry` decodes instead.
        var sevenZipIndex: Int? = nil
    }

    /// Files a .zip may carry beside the ROM, ignored when placing it.
    static let zipSidecarExtensions: Set<String> = ["txt", "nfo", "diz", "htm", "html", "url", "sfv", "pdf", "jpg", "jpeg", "png"]

    /// The most a console ROM in a .zip may inflate to, so a zip bomb stops there. Each is above the largest
    /// real image for the platform; any other platform gets 2 GiB. A 3DS card image is up to 4 GiB (device run 9:
    /// a zip64 entry of exactly 4 GiB was refused as too large).
    static func zipROMLimit(_ platformID: String) -> Int {
        let mib = 1 << 20
        let limits = ["gb": 8 * mib, "gbc": 8 * mib, "gba": 32 * mib, "nes": 8 * mib, "snes": 16 * mib,
                      "megadrive": 16 * mib, "n64": 64 * mib, "nds": 512 * mib, "n3ds": 4096 * mib]
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
        // A .pbp serves PS1 and PSP alike and is placed by its contents, which a zip hides. A lone .iso (PSP, PS1, a
        // DOS CD and more) is "disc": the import unpacks it and places it by its sector 16, as a bare .iso.
        let id: String
        if ext == "iso" {
            id = "disc"
        } else {
            guard ext != "pbp", let known = platformID(forExtension: ext), known != "arcade", known != "dos", platform(known) != nil
            else { return nil }
            id = known
        }
        let parts = entry.name.split(whereSeparator: { $0 == "/" || $0 == "\\" })
        guard !entry.name.hasPrefix("/"), !entry.name.hasPrefix("\\"), parts.first?.hasSuffix(":") != true,
              !parts.contains("..") else { return .failure(.unsafeName) }
        guard entry.size <= zipROMLimit(id) else { return .failure(.tooLarge) }
        return .success((entry, id))
    }

    enum ZipError: LocalizedError {
        case unsupported, corrupt, truncated, tooLarge, unsafeName
        var errorDescription: String? {
            switch self {
            case .unsupported: return "The archive uses encryption or a compression GagaEmu cannot read."
            case .corrupt: return "The archive is damaged."
            case .truncated: return "The archive is incomplete: its end is missing. Copy or download it again."
            case .tooLarge: return "The file in the archive is too large."
            case .unsafeName: return "The file in the archive has a path GagaEmu refuses, such as one that leaves its folder."
            }
        }
    }

    /// Writes one stored or deflated entry to `destination`, or under a new name when a different file has that
    /// name, and returns where it went. Stops past `limit` bytes, whatever the entry claims, and checks the size
    /// and CRC-32 before the file appears. Stops with `CancellationError` once `progress` is cancelled, which also
    /// counts the bytes written.
    @discardableResult
    static func extractZipEntry(_ entry: ZipEntry, from zip: URL, to destination: URL, limit: Int,
                                progress: Progress? = nil) throws -> URL {
        if entry.sevenZipIndex != nil {
            return try extractSevenZipEntries([(entry, destination)], from: zip, limit: limit, progress: progress)[0]
        }
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
            if progress?.isCancelled == true { throw CancellationError() }
            progress?.completedUnitCount += Int64(bytes.count)
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
    /// The set is built in a hidden staging folder and renamed into place whole, so a set folder is never partial;
    /// a 7z's solid block is decoded once for every file in it.
    static func extractZipDiscSet(_ entries: [ZipEntry], from zip: URL, into romDirectory: URL,
                                  progress: Progress? = nil) throws -> URL? {
        let files = entries.filter { !$0.name.hasSuffix("/") && !zipSidecarExtensions.contains(($0.name as NSString).pathExtension.lowercased()) }
        let names = files.map { WiFiTransferServer.sanitize(String($0.name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last ?? "")) }
        guard files.count >= 2, let sheet = names.first(where: DiscSet.isDescriptor), !names.contains(""),
              Set(names.map { $0.lowercased() }).count == names.count else { return nil }
        guard files.allSatisfy({ !$0.name.hasPrefix("/") && !$0.name.hasPrefix("\\") && !$0.name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).contains("..") })
        else { throw ZipError.unsafeName }
        let fileManager = FileManager.default
        let staging = romDirectory.appendingPathComponent("\(stagingPrefix)\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        progress?.totalUnitCount = Int64(files.reduce(0) { $0 + $1.size })
        let wanted = Swift.zip(files, names.map { staging.appendingPathComponent($0) }).map { (entry: $0, destination: $1) }
        if files.allSatisfy({ $0.sevenZipIndex != nil }) {
            try extractSevenZipEntries(wanted, from: zip, limit: zipROMLimit("disc"), progress: progress)
        } else {
            for item in wanted {
                try extractZipEntry(item.entry, from: zip, to: item.destination, limit: zipROMLimit("disc"), progress: progress)
            }
        }
        guard DiscSet.primary(in: staging) != nil, DiscSet.missing(in: staging).isEmpty,
              Set(DiscSet.wanted(in: staging).map { $0.lowercased() }) == Set(names.map { $0.lowercased() }) else {
            return nil
        }
        // newFolder claims a free name; the staged set then takes that name in one rename.
        let folder = try DiscSet.newFolder(for: sheet, in: romDirectory)
        try fileManager.removeItem(at: folder)
        try fileManager.moveItem(at: staging, to: folder)
        return folder
    }

    /// The hidden folder in the ROM folder a disc set is built in before it moves into place.
    static let stagingPrefix = ".import-"

    /// What an archive import made: its one console ROM, its one disc set, or nothing, so the archive itself is
    /// the game (an arcade set or a DOS zip).
    enum Unpacked: Equatable {
        case rom(URL), discSet(URL), kept
    }

    /// The archive part of an import, run off the main thread. Writes only .part files and a staging folder
    /// until a finished file or set moves into place, and never touches the archive itself.
    static func unpackArchive(_ url: URL, into romDirectory: URL, progress: Progress) throws -> Unpacked {
        let entries = archiveEntries(url)
        guard !entries.isEmpty else { throw startsAsZip(url) ? ZipError.truncated : ZipError.corrupt }
        if let rom = try zipConsoleCheck(entries)?.get() {
            let name = WiFiTransferServer.sanitize(String(rom.entry.name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last ?? ""))
            guard !name.isEmpty else { throw ZipError.unsafeName }
            progress.totalUnitCount = Int64(rom.entry.size)
            return .rom(try extractZipEntry(rom.entry, from: url, to: romDirectory.appendingPathComponent(name),
                                            limit: zipROMLimit(rom.platformID), progress: progress))
        }
        if let folder = try extractZipDiscSet(entries, from: url, into: romDirectory, progress: progress) {
            return .discSet(folder)
        }
        return .kept
    }

    /// A zip's first local header with no readable directory: the end of the file is missing (device run 9).
    static func startsAsZip(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)) == Data([0x50, 0x4B, 3, 4])
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
        func u64(_ b: [UInt8], _ i: Int) -> Int { u32(b, i) | u32(b, i + 4) << 32 }
        guard let end = stride(from: bytes.count - 22, through: 0, by: -1).first(where: {
            bytes[$0] == 0x50 && bytes[$0 + 1] == 0x4B && bytes[$0 + 2] == 5 && bytes[$0 + 3] == 6
        }) else { return [] }
        var directorySize = u32(bytes, end + 12), directoryOffset = u32(bytes, end + 16)
        // Zip64 (APPNOTE 4.3.14): a locator 20 bytes before the end record points at the zip64 end record, which
        // holds the directory's real size and offset when either overflows 32 bits.
        if end >= 20, u32(bytes, end - 20) == 0x0706_4B50 {
            let record = u64(bytes, end - 12)
            guard record >= 0, record + 56 <= size, (try? handle.seek(toOffset: UInt64(record))) != nil,
                  let data = try? handle.read(upToCount: 56), data.count == 56 else { return [] }
            let zip64 = [UInt8](data)
            guard u32(zip64, 0) == 0x0606_4B50 else { return [] }
            directorySize = u64(zip64, 40)
            directoryOffset = u64(zip64, 48)
        }
        guard directorySize >= 0, directoryOffset >= 0, directoryOffset + directorySize <= size,
              (try? handle.seek(toOffset: UInt64(directoryOffset))) != nil,
              let directory = try? handle.read(upToCount: directorySize) else { return [] }
        let records = [UInt8](directory)
        var entries: [ZipEntry] = []
        var i = 0
        while i + 46 <= records.count, u32(records, i) == 0x0201_4B50 {
            let nameLength = u16(records, i + 28), extraLength = u16(records, i + 30)
            let next = i + 46 + nameLength + extraLength + u16(records, i + 32)
            guard i + 46 + nameLength + extraLength <= records.count else { break }
            var size = u32(records, i + 24), compressedSize = u32(records, i + 20), offset = u32(records, i + 42)
            // A field of all ones moved to the zip64 extra (ID 1), which holds only those, in this order.
            var extra = i + 46 + nameLength
            let extraEnd = extra + extraLength
            while extra + 4 <= extraEnd {
                let id = u16(records, extra), length = u16(records, extra + 2)
                guard extra + 4 + length <= extraEnd else { break }
                if id == 1 {
                    var field = extra + 4
                    let fieldEnd = field + length
                    func take(_ value: inout Int) {
                        guard value == 0xFFFF_FFFF, field + 8 <= fieldEnd else { return }
                        value = u64(records, field)
                        field += 8
                    }
                    take(&size)
                    take(&compressedSize)
                    take(&offset)
                }
                extra += 4 + length
            }
            guard size >= 0, compressedSize >= 0, offset >= 0 else { break }
            entries.append(ZipEntry(name: String(decoding: records[(i + 46)..<(i + 46 + nameLength)], as: UTF8.self),
                                    flags: u16(records, i + 8), method: u16(records, i + 10),
                                    crc: UInt32(u32(records, i + 16)), compressedSize: compressedSize,
                                    size: size, localHeaderOffset: offset))
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
    static let site = "\(host)/"
    /// What Share GagaEmu sends.
    /// shortcut: the app has no App Store ID until its first submission, so this is the site; replace with
    /// https://apps.apple.com/app/id<ID> once App Store Connect assigns one.
    static let appStore = site
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
    /// Disc images and archives whose contents did not name a platform, asked one at a time (`unplacedQuestion`).
    @Published var unplaced: [GameItem] = []
    /// Waits for the game view to finish dismissing, because an alert cannot present during that.
    private var pendingFailure: LaunchFailure?

    struct LaunchFailure: Identifiable, Equatable {
        /// The title of a failure that came from an import, not a game.
        static let importTitle = "Import"
        let id = UUID()
        let title: String
        let message: String

        var heading: String {
            #if DEBUG
            // A finished benchmark ends its session the same way a failure does.
            if message.hasPrefix("Benchmark saved") { return "Benchmark finished" }
            #endif
            if title == Self.importTitle { return "Could not import" }
            return "Could not play \(title)"
        }
    }

    @Published var nickname: String { didSet { save() } }
    @Published var joined: Date
    @Published var avatarIndex: Int { didSet { save() } }
    @Published var appearance: AppearanceMode { didSet { save() } }
    @Published var quickStart: Bool { didSet { save() } }
    @Published var autoSaveStates: Bool { didSet { save() } }
    /// Off by default: it keeps up to `RewindPolicy.budgetBytes` of snapshots while a game runs.
    @Published var rewind: Bool { didSet { save() } }
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
    /// 0 to 1. Scales a game's rumble on controllers and the device.
    @Published var rumbleStrength: Double { didSet { save() } }
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
    /// Saved filter presets, in Documents (in the test root under a test).
    let presets: ShaderPresetStore
    var coverFetcher = CoverArtFetcher()
    private var coverTask: Task<Void, Never>?

    var romDirectory: URL
    /// Custom touch layouts from the skin editor, one flex skin per platform ID.
    let skinDirectory: URL
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
        var rewind: Bool?
        var platformSkins: [String: String]?
        var airPlayFullscreen: Bool
        var iCloudSync: Bool
        var autoFullScreen: Bool
        var respectSilentMode: Bool
        var rumble: Bool
        var rumbleStrength: Double?
        var skinSoundEffects: Bool
        var language: String
        var shaderID: String
        var defaultCores: [String: String]
    }

    /// Test only: the folder that holds the Library (state.json), ROMs, System and the rest, in place of the app's
    /// own. `GagaTestCase` sets a new one for every test, so no test reads or writes the device's Library.
    nonisolated(unsafe) static var rootOverride: URL?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = Self.rootOverride ?? base.appendingPathComponent("GagaEmu", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        romDirectory = root.appendingPathComponent("ROMs", isDirectory: true)
        storeURL = root.appendingPathComponent("state.json")
        skinDirectory = root.appendingPathComponent("Skins", isDirectory: true)
        wifi = WiFiTransferServer(romDirectory: romDirectory)
        filters = ImportedFilterStore(directory: root.appendingPathComponent("Filters", isDirectory: true))
        let documents = Self.rootOverride.map { $0.appendingPathComponent("Documents", isDirectory: true) }
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? root
        presets = ShaderPresetStore(directory: documents)
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
        rewind = snapshot?.rewind ?? false
        coverArt = snapshot?.coverArt ?? false
        shaderParameters = snapshot?.shaderParameters ?? [:]
        platformSkins = snapshot?.platformSkins ?? [:]
        airPlayFullscreen = snapshot?.airPlayFullscreen ?? false
        iCloudSync = snapshot?.iCloudSync ?? false
        autoFullScreen = snapshot?.autoFullScreen ?? true
        respectSilentMode = snapshot?.respectSilentMode ?? false
        rumble = snapshot?.rumble ?? false
        rumbleStrength = snapshot?.rumbleStrength ?? 1
        skinSoundEffects = snapshot?.skinSoundEffects ?? true
        language = snapshot?.language ?? "English"
        shaderID = snapshot?.shaderID ?? "original"
        defaultCores = snapshot?.defaultCores ?? [:]
        skins.loadDefault()
        if Self.rootOverride != nil { systemDirectory = root.appendingPathComponent("System", isDirectory: true) }
        if migrated != nil { save() }
        wifi.onUploaded = { [weak self] names in
            Task { @MainActor in await self?.addUploads(names) }
        }
    }

    /// A file uploaded again with the same bytes keeps its name, so it must not become a second shelf entry.
    /// A name is a path under the ROM folder, as "Game/Game.cue" for a disc set.
    func addUploads(_ names: [String]) async {
        for name in names { await importArrived(romDirectory.appendingPathComponent(name)) }
    }

    /// `importArrived` for a file the player chose or dropped: queues the platform question when a disc image
    /// or archive did not say. Returns the note, when there is one.
    @discardableResult
    func importChosen(_ dest: URL) async -> String? {
        let (game, note) = await importArrived(dest)
        if let game, game.platformID == "unknown", CoreCatalog.unplacedPlatforms(forFile: URL(fileURLWithPath: game.romPath)) != nil {
            unplaced.append(game)
        }
        return note
    }

    /// Drop import, for every screen that takes drops: copies each dropped file into the ROM folder off the
    /// main thread, then `importChosen`. `done` gets each file's notice, and true when it is a problem (a note
    /// or an error) rather than "Imported". False when nothing is a file.
    func importDropped(_ providers: [NSItemProvider], done: @escaping @MainActor (String, Bool) -> Void) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            // @Sendable: the provider calls back on its own queue, never the main actor.
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { @Sendable item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    do {
                        let romDirectory = self.romDirectory
                        let dest = try await Task.detached { try ClipboardImporter.persist(.file(url), into: romDirectory) }.value
                        let note = await self.importChosen(dest)
                        done(note ?? "Imported \(dest.lastPathComponent)", note != nil)
                    } catch {
                        done(error.localizedDescription, true)
                    }
                }
            }
        }
        return accepted
    }

    // MARK: Touch skins

    func customSkinURL(_ platformID: String) -> URL {
        skinDirectory.appendingPathComponent("\(platformID).json")
    }

    func hasCustomSkin(_ platformID: String) -> Bool {
        FileManager.default.fileExists(atPath: customSkinURL(platformID).path)
    }

    /// The game's choice, then the platform's. Custom loads the saved layout; a missing or unreadable one falls
    /// back to the platform's own built-in layout.
    func applySkin(for game: GameItem) {
        let platform = platformSkins[game.platformID]
        if (game.skinID ?? platform) == TouchSkinEngine.customID {
            do { return try skins.loadFlex(from: customSkinURL(game.platformID)) } catch {}
        }
        skins.loadBuiltIn(TouchSkinEngine.layoutID(game: game.skinID, platform: platform, platformID: game.platformID),
                          platformID: game.platformID)
    }

    /// Saves the skin editor's layout as the platform's custom skin and chooses it. Throws, saving nothing,
    /// when the layout fails `TouchSkinEngine.problems`.
    func saveCustomSkin(_ buttons: [TouchSkinEngine.Button], opacity: Double, platformID: String) throws {
        if let problem = TouchSkinEngine.problems(in: buttons).first { throw CustomSkinError(message: problem) }
        let data = try TouchSkinEngine.encodeFlex(name: "Custom", buttons: buttons, opacity: opacity)
        try FileManager.default.createDirectory(at: skinDirectory, withIntermediateDirectories: true)
        try data.write(to: customSkinURL(platformID), options: .atomic)
        platformSkins[platformID] = TouchSkinEngine.customID
    }

    /// Deletes the platform's custom skin and returns it to its default layout.
    func resetCustomSkin(_ platformID: String) {
        try? FileManager.default.removeItem(at: customSkinURL(platformID))
        if platformSkins[platformID] == TouchSkinEngine.customID { platformSkins[platformID] = nil }
    }

    struct CustomSkinError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Every import ends here: Files, drop, clipboard, download, WiFi Transfer and the Debug launch arguments.
    /// `url` is a file already placed in the ROM folder (`ClipboardImporter.persist` or `download`, or the WiFi
    /// server). A file a game already uses is that game, not a second entry. The note says why no game was
    /// stored or an older file was kept, as `lastImportNote`. A .zip or .7z unpacks off the main thread, as an
    /// `importJobs` row.
    @discardableResult
    func importArrived(_ url: URL) async -> (game: GameItem?, note: String?) {
        let name = ClipboardImporter.relativePath(url, in: romDirectory)
        if let existing = games.first(where: { ClipboardImporter.relativePath(URL(fileURLWithPath: $0.romPath), in: romDirectory) == name
                                               || (!name.contains("/") && URL(fileURLWithPath: $0.romPath).lastPathComponent == name) }) {
            return (existing, nil)
        }
        if ["zip", "7z"].contains(url.pathExtension.lowercased()), isInROMFolder(url), biosName(url) == nil,
           DiscSet.folder(of: url, romDirectory: romDirectory) == nil, !CoreCatalog.isRAR(url) {
            return await unpackArrived(url)
        }
        let game = importROM(at: url)
        return (game, lastImportNote)
    }

    /// An archive unpacking off the main thread, shown with its progress and a Cancel button.
    struct ImportJob: Identifiable {
        let id = UUID()
        let name: String
        let progress: Progress
    }

    @Published private(set) var importJobs: [ImportJob] = []

    /// The archive stays in the ROM folder and nothing half written is left.
    func cancelImport(_ job: ImportJob) { job.progress.cancel() }

    /// One empty file per archive whose unpacking began and has not ended, named as the archive in the ROM folder.
    var pendingImportDirectory: URL {
        romDirectory.deletingLastPathComponent().appendingPathComponent("PendingImports", isDirectory: true)
    }

    /// The copied archive goes only once its game is saved in the Library. A refused or cancelled one stays.
    private func unpackArrived(_ url: URL) async -> (game: GameItem?, note: String?) {
        let fileManager = FileManager.default
        let marker = pendingImportDirectory.appendingPathComponent(url.lastPathComponent)
        try? fileManager.createDirectory(at: pendingImportDirectory, withIntermediateDirectories: true)
        fileManager.createFile(atPath: marker.path, contents: nil)
        let job = ImportJob(name: url.lastPathComponent, progress: Progress(totalUnitCount: 0))
        importJobs.append(job)
        defer { importJobs.removeAll { $0.id == job.id } }
        let romDirectory = romDirectory, progress = job.progress
        let result = await Task.detached(priority: .userInitiated) {
            Result { try CoreCatalog.unpackArchive(url, into: romDirectory, progress: progress) }
        }.value
        lastImportNote = nil
        let game: GameItem?
        switch result {
        case .failure(let error):
            try? fileManager.removeItem(at: marker)
            lastImportNote = "\(url.lastPathComponent): " + (error is CancellationError ? "Import cancelled." : error.localizedDescription)
            return (nil, lastImportNote)
        case .success(.kept):
            game = addGame(url, title: nil, platform: CoreCatalog.platformID(forFile: url) ?? "unknown")
        case .success(.rom(let placed)):
            game = addGame(placed, title: nil, platform: CoreCatalog.platformID(forFile: placed) ?? "unknown")
        case .success(.discSet(let folder)):
            game = importDiscSet(folder, arrived: folder, title: nil, platformID: nil)
        }
        if game != nil, (try? result.get()) != .kept { try? fileManager.removeItem(at: url) }
        try? fileManager.removeItem(at: marker)
        return (game, lastImportNote)
    }

    /// At launch: drops what a quit mid-import left half written (.part files and staging folders), then runs
    /// each import a marker names again. Its archive is still in the ROM folder, as it goes only after the game is
    /// saved; a finished file already in place is matched, not written twice.
    func finishInterruptedImports() async {
        let fileManager = FileManager.default
        let folders = [romDirectory] + DiscSet.folders(in: romDirectory)
        for folder in folders {
            for name in (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
            where name.hasPrefix(".") && (name.hasSuffix(".part") || name.hasPrefix(CoreCatalog.stagingPrefix)) {
                try? fileManager.removeItem(at: folder.appendingPathComponent(name))
            }
        }
        for name in (try? fileManager.contentsOfDirectory(atPath: pendingImportDirectory.path)) ?? [] {
            let archive = romDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: archive.path) {
                await importArrived(archive)
            }
            try? fileManager.removeItem(at: pendingImportDirectory.appendingPathComponent(name))
        }
    }

    private func isInROMFolder(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL == romDirectory.standardizedFileURL
    }

    /// The System name of a BIOS file the BIOS Files screen names, at a size its core reads; nil otherwise.
    /// Matched in any letter case, as the exact name the core opens (bios_CD_U.bin, kick34005.A500).
    private func biosName(_ url: URL) -> String? {
        let fileName = BIOSManagerView.canonicalName(url.lastPathComponent) ?? url.lastPathComponent.lowercased()
        // Not url.resourceValues: a URL caches them, so a file rewritten at the same URL kept its old size.
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int,
              BIOSManagerView.sizes[fileName]?.contains(size) == true else { return nil }
        return fileName
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
    func runBenchmark(rom: URL? = nil, core coreID: String = "mgba", seconds: TimeInterval = BenchmarkRun.defaultSeconds,
                      input: String? = nil) {
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
                let run = BenchmarkRun(session: next, interface: interface, romURL: romURL, seconds: seconds, input: input)
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
        let input = defaults.string(forKey: "GagaBenchmarkInput")
        if let input, BenchmarkRun.parseInput(input) == nil {
            launchFailure = LaunchFailure(title: "Benchmark", message: "-GagaBenchmarkInput takes button@seconds entries, such as start@8,cross@12.")
            return
        }
        runBenchmark(rom: defaults.string(forKey: "GagaBenchmarkROM").map { romDirectory.appendingPathComponent($0) },
                     core: defaults.string(forKey: "GagaBenchmarkCore") ?? "mgba",
                     seconds: seconds > 0 ? seconds : BenchmarkRun.defaultSeconds, input: input)
    }

    /// `-GagaImportROM <path>`: copies the file in as Files import does, so core work can add a game
    /// without the UI. A file already in the Library is replaced on disk, not added twice. A relative path is
    /// in Documents, where `devicectl device copy to` puts a file without knowing the container's path.
    func importROMIfRequested() async {
        guard let path = UserDefaults.standard.string(forKey: "GagaImportROM") else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            // "~" is the app's container, whose path changes with each device install; a relative path is under Documents.
            let expanded = (path as NSString).expandingTildeInPath
            try await importDebugROM(at: expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : documents.appendingPathComponent(expanded))
        } catch {
            launchFailure = LaunchFailure(title: "Import", message: error.localizedDescription)
        }
    }

    /// As Files import: copied in, then `importArrived`. A note is shown as an Import failure, and the game is
    /// filtered onto the screen, since the Library builds only the shelves in view and a walk looks for it there.
    /// Logs `[gaga-import] done <name> -> <platform>` (`-> system (BIOS)` for a BIOS file, else `-> none`) when it
    /// ends, for device runners.
    @discardableResult
    func importDebugROM(at url: URL) async throws -> GameItem? {
        let romDirectory = romDirectory
        // Off the main thread: the copy can be gigabytes.
        let copied = try await Task.detached { try ClipboardImporter.persist(.file(url), into: romDirectory) }.value
        let (game, note) = await importArrived(copied)
        print("[gaga-import] done \(url.lastPathComponent) -> \(game?.platformID ?? (biosName(url) == nil ? "none" : "system (BIOS)"))"
              + (note.map { " (\($0))" } ?? ""))
        if let note { launchFailure = LaunchFailure(title: "Import", message: note) }
        if let game {
            platformFilter = game.platformID
            search = game.title
        }
        return game
    }

    /// `-GagaImportTestROM <core-id>`: adds that core's generated test ROM (the benchmark's) to the Library,
    /// set to play on that core, so a device walk (UITests) has a game with a touch layout and no file to copy.
    func importTestROMIfRequested() async {
        guard let coreID = UserDefaults.standard.string(forKey: "GagaImportTestROM") else { return }
        do {
            guard let platformID = CoreCatalog.platforms.first(where: { $0.cores.contains { $0.id == coreID } })?.id else {
                throw GameLaunchError.coreNotBuilt(CoreCatalog.coreName(coreID))
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GagaTestROM", isDirectory: true)
            if let game = try await importDebugROM(at: BenchmarkRun.writeTestROM(platformID: platformID, to: folder)) {
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
        applySkin(for: game)
        skins.hapticsEnabled = rumble
        skins.soundEnabled = skinSoundEffects
        let shader = store.canUseShader(game.shaderID) ? game.shaderID : "original"
        let session = try GameSession(game: game, interface: interface, romPath: romPath, controllers: controllers,
                                      skins: skins, bindings: triggerPro.bindings, shaderID: shader,
                                      respectSilentMode: respectSilentMode,
                                      rumble: RumbleManager(scale: Float(rumbleStrength), targets: HapticRumbleTargets(controllers: controllers, device: rumble).targets),
                                      entitlements: { [store] in store.entitlements })
        session.autoSaveEnabled = { [weak self] in self?.autoSaveEnabled ?? false }
        session.rewindEnabled = rewind
        session.renderer.apply(shaderParameters[shader] ?? ShaderParameterValues())
        return session
    }

    /// A filter that no longer builds is not a failed launch: Original runs, and the player is told.
    private func applyImportedFilter(to session: GameSession) async {
        let id = session.game.shaderID
        guard ImportedFilter.isImported(id) || ImportedFilter.isSlang(id) else { return }
        let renderer = session.renderer
        do {
            if ImportedFilter.isSlang(id) {
                renderer.setSlang(try await filters.slangChain(for: id, device: renderer.device))
            } else {
                renderer.setImported(try await filters.pipeline(for: id, device: renderer.device))
            }
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
        // A BIOS file the BIOS Files screen names, at a size its core reads, moves to the cores' system folder.
        // Another size under that name (a game called firmware.bin) is placed as a game. A different file already
        // in System is never replaced. A .rom (such as an FDS folder's disksys.rom) is never a game.
        if platformID == nil, isInROMFolder(url), let fileName = biosName(url) {
            try? FileManager.default.createDirectory(at: systemDirectory, withIntermediateDirectories: true)
            let dest = systemDirectory.appendingPathComponent(fileName)
            // A copy at a size no core reads (an emptied file: device run 6's disksys.rom) is damaged, not kept.
            let keptSize = (try? FileManager.default.attributesOfItem(atPath: dest.path))?[.size] as? Int
            if let keptSize, BIOSManagerView.sizes[fileName]?.contains(keptSize) != true {
                try? FileManager.default.removeItem(at: dest)
            }
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
        // unrar's licence conflicts with the GPL cores, so a RAR is refused with a way forward and stays put.
        if platformID == nil, CoreCatalog.isRAR(url) {
            lastImportNote = "\(url.lastPathComponent): \(CoreCatalog.rarMessage)"
            return nil
        }
        // No console core reads a .zip or .7z, so `importArrived` unpacks one in the ROM folder off the main thread
        // (`unpackArrived`). One reaching here is kept as it is. A damaged or refused one is reported there and
        // stays where it is, with no shelf entry and no platform question.
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
                                shaderParameters: shaderParameters, rewind: rewind, platformSkins: platformSkins,
                                airPlayFullscreen: airPlayFullscreen, iCloudSync: iCloudSync,
                                autoFullScreen: autoFullScreen, respectSilentMode: respectSilentMode,
                                rumble: rumble, rumbleStrength: rumbleStrength, skinSoundEffects: skinSoundEffects, language: language,
                                shaderID: shaderID, defaultCores: defaultCores)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
