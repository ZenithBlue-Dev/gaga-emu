import Foundation

/// What the cheat sheet tells the player each core reads. The core still judges every code (`docs/06`).
enum CheatFormat {
    /// The line under the code field, by core ID.
    static func hint(coreID: String) -> String {
        switch coreID {
        case "mgba": "GameShark, Action Replay, CodeBreaker or VBA format. Game Boy: GameShark or Game Genie."
        case "gambatte": "GameShark 01VVLLHH, or Game Genie VVA-AAA or VVA-AAA-CCC."
        case "nestopia": "Game Genie, or raw RAM AAAA:VV or AAAA?CC:VV."
        case "bsnes": "Pro Action Replay AAAAAADD or Game Genie XXXX-XXXX."
        case "snes9x": "Pro Action Replay AAAAAADD, Game Genie XXXX-XXXX or raw AAAAAA:DD."
        case "jgenesis", "genesis_plus_gx", "picodrive": "Game Genie or Pro Action Replay format, one code per line."
        case "gearsystem": "Pro Action Replay 00AAAA:VV or Game Genie XXX-XXX."
        case "pcsx_rearmed", "swanstation", "beetle_psx": "GameShark TTAAAAAA VVVV, one stand-alone code per line."
        case "melonds_ds": "Action Replay DS, XXXXXXXX YYYYYYYY per line."
        case "mupen64plus_next": "GameShark XXXXXXXX YYYY, one per line."
        case "beetle_saturn": "Pro Action Replay TTAAAAAA VVVV, or raw AAAAAAAA VVVV."
        case "beetle_pce_fast", "beetle_supergrafx": "Raw RAM AAAAAA:VV, one per line."
        case "beetle_wswan": "Raw RAM AAAAA:VV, one per line."
        case "ppsspp": "CWCheat _L 0xAAAAAAAA 0xVVVVVVVV lines. A pasted _C block from a cheat .ini adds each cheat in it."
        case "mame": "A cheat's name from your System/mame/cheat/<set>.xml or cheat.7z, or Name = Setting."
        case "fbneo": "A cheat's name from your System/fbneo/cheats/<set>.ini or .dat, or Name = Option."
        case "azahar": "Gateway XXXXXXXX YYYYYYYY, one code line per line."
        case "prboom": "A Doom cheat word such as iddqd. Once on, it stays on until the game is reloaded."
        default: PokeEngine.base(coreID: coreID) == nil ? "Codes in a format this core reads." : PokeEngine.hint
        }
    }

    /// The pause menu's note for a core without cheats.
    static func unsupported(coreName: String) -> String {
        "Cheats: \(coreName) has no cheat support in GagaEmu."
    }

    /// One cheat from a CWCheat file (PPSSPP).
    struct Block: Equatable {
        var name: String
        var code: String
        var enabled: Bool
    }

    /// Largest .cht accepted. The biggest in the libretro collection is about 3 MB.
    static let maxChtBytes = 4 * 1024 * 1024
    private static let maxChtEntries = 20_000
    private static let maxChtCodeLength = 8 * 1024
    private static let maxChtNameLength = 200

    /// Cores whose cheat lines are "ADDRESS VALUE", which a .cht writes as "ADDRESS+VALUE".
    private static let pairedCores: Set<String> = ["mgba", "melonds_ds", "pcsx_rearmed", "swanstation", "beetle_psx", "beetle_saturn"]

    /// The usable cheats in a RetroArch .cht file, in file order and all off. Bad lines are skipped. Entries with
    /// no code (RetroArch's memory-search cheats) are dropped, because `retro_cheat_set` cannot run them.
    static func chtBlocks(_ text: String, coreID: String) -> [Block] {
        var names: [Int: String] = [:]
        var codes: [Int: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            guard raw.hasPrefix("cheat"), let equals = raw.firstIndex(of: "=") else { continue }
            let key = raw[raw.index(raw.startIndex, offsetBy: 5)..<equals].trimmingCharacters(in: .whitespaces)
            let digits = key.prefix(while: \.isNumber)
            guard digits.count <= 6, let index = Int(digits), index < maxChtEntries else { continue }
            let value = raw[raw.index(after: equals)...].trimmingCharacters(in: CharacterSet.whitespaces.union(["\""]))
            switch key.dropFirst(digits.count) {
            case "_desc": names[index] = String(value.prefix(maxChtNameLength))
            case "_code": if value.count <= maxChtCodeLength { codes[index] = chtCode(value, coreID: coreID) }
            default: break
            }
        }
        return codes.keys.sorted().compactMap { index in
            guard let code = codes[index], !code.isEmpty else { return nil }
            let name = names[index].flatMap { $0.isEmpty ? nil : $0 } ?? "Cheat \(index + 1)"
            return Block(name: name, code: code, enabled: false)
        }
    }

    /// A .cht code as this app's lines: `+` separates lines, or the two halves of one line on `pairedCores`.
    static func chtCode(_ code: String, coreID: String) -> String {
        var parts = code.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if pairedCores.contains(coreID) {
            parts = parts.map { isHex($0) && $0.count == 12 ? "\($0.prefix(8)) \($0.suffix(4))" : $0 }
            let pairs = parts.count.isMultiple(of: 2) && stride(from: 0, to: parts.count, by: 2).allSatisfy {
                isHex(parts[$0]) && parts[$0].count == 8 && isHex(parts[$0 + 1]) && [4, 8].contains(parts[$0 + 1].count)
            }
            if pairs { parts = stride(from: 0, to: parts.count, by: 2).map { parts[$0] + " " + parts[$0 + 1] } }
        }
        return parts.joined(separator: "\n")
    }

    private static func isHex(_ text: String) -> Bool { text.allSatisfy(\.isHexDigit) }

    /// Reads a player's .cht. Untrusted: the size is checked before the bytes are read.
    static func readCht(_ url: URL, coreID: String) throws -> [Block] {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maxChtBytes else { throw EmulatorCoreError.cheatRejected("This file is too large to be a cheat file.") }
        let data = try Data(contentsOf: url)
        return chtBlocks(String(decoding: data, as: UTF8.self), coreID: coreID)
    }

    /// The cheats in a pasted CWCheat .ini block: each `_C0 Name` (off) or `_C1 Name` (on) line starts one, and
    /// the `_L` lines under it are its code. `_S` and `_G` lines and anything before the first `_C` are skipped.
    /// Empty when the text has no `_C` line, so a plain code goes through as one cheat.
    static func cwCheatBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let upper = line.uppercased()
            if upper.hasPrefix("_C"), let state = line.dropFirst(2).first, state == "0" || state == "1" {
                let name = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                blocks.append(Block(name: name.isEmpty ? "Cheat \(blocks.count + 1)" : name, code: "", enabled: state == "1"))
            } else if upper.hasPrefix("_L"), !blocks.isEmpty {
                blocks[blocks.count - 1].code += (blocks[blocks.count - 1].code.isEmpty ? "" : "\n") + line
            }
        }
        return blocks.filter { !$0.code.isEmpty }
    }
}
