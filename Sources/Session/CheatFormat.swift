import Foundation

/// What the cheat sheet tells the player each core reads. The core still judges every code (`docs/06`).
enum CheatFormat {
    /// The line under the code field, by core ID.
    static func hint(coreID: String) -> String {
        switch coreID {
        case "mgba": "GameShark, Action Replay, CodeBreaker or VBA format."
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
        default: "Codes in a format this core reads."
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
