# Cheat sources and per-core cheat plan

Research date: 2026-11-09. Web research only, nothing downloaded. Not legal advice. Each claim names its URL. A claim marked "unverified" comes from memory or a search snippet, not a page I read; check it before building on it.

## Decision

The owner decided on 2026-11-09: **bundle all cheats**. GagaEmu ships the libretro `cht` collection inside the app, with credit on the licences screen (`Sources/UI/Settings/LicencesView.swift`). User import stays as the route for sources whose terms do not allow bundling.

**Bundled 2026-11-09:** commit `c4e17d41ec1bb744fb064f7cefeb61b878fc5d64`. The repository's `LICENSE` is the full text of CC BY-SA 4.0. It has no `COPYING` file, so the third-party MIT listing is wrong. Its README still says the codes come from any source on the web, so the licence does not prove each contributor held the rights. The owner accepted that. The adapted pack carries the same licence and is credited in `Licences/notices.json`.

`scripts/build-cheat-pack.py` writes `Resources/cheats.pack` (9,995,554 bytes). It covers 18 platforms: gb 16,849 cheats, gbc 9,274, gba 7,018, nes 44,347, snes 68,152, n64 178,650, nds 548,889, ps1 22,647, psp 81,099, saturn 1,698, megadrive 37,571, megacd 164, mastersystem 4,679, gamegear 7,274, sg1000 69, pce 1,437, sgx 14, ws 32. That is 1,029,863 cheats in 13,127 titles. The 4 MiB and 20,000-entry limits drop 144,401 more: those are the last files of titles whose region and device files together pass a limit. Six titles among DS, N64 and PSP pass it.

Left out: systems whose release core cannot apply a `.cht` today (Dreamcast, Lynx, Neo Geo Pocket, Virtual Boy, Atari, DOS, Doom), the 3DS (no upstream folder and no cheat hook), arcade and the 32X (its only core is not in the release set). Add a system to `SYSTEMS` in the script when its core can use it.

## Sources

| Source | Systems | Format | Size | Licence or terms | Bundle in an App Store app | Freshness |
|---|---|---|---|---|---|---|
| libretro-database `cht/` | One folder per system, many cartridge and disc systems. Folder list not checked. | RetroArch `.cht` text, `cheatN_desc` / `cheatN_code` / `cheatN_enable` | Not measured. Measure and compress at build time. | Owner brief: CC BY-SA 4.0 blanket, not re-confirmed. README says codes are "collected from any available source on the web including by manual contributions from users". Third-party index lists repo as MIT. | Owner decided yes. Risks: ShareAlike on adapted text, attribution, and no proof every contributor held rights to their codes. | Active repo, per-file dates not checked |
| PPSSPP in-app "Download cheat database" | PSP | CWCheat `cheat.db` (`_S`, `_G`, `_C0`, `_L` lines) | Not measured | No licence stated on the docs page. | No. Terms unknown. PPSSPP itself fetches it at the user's request, which is the on-demand model. | Not checked |
| CWCheat-Database-Plus (Saramagrean, GitHub) | PSP | CWCheat `cheat.db` | Not measured | Not found. | No, until a licence is found. | Not checked |
| CTRPF-AR-CHEAT-CODES (JourneyOver, forks exist) | 3DS | Per-game `.txt`, Action Replay / Gateway style | Not measured | No licence file found. GameBrew lists "Mixed". Repo archived 2019-05-08. | No. | Stale, archived |
| `usrcheat.dat` (DeadSkullzJr pack on GBAtemp) | DS | R4 binary database | Not measured | No licence found. | No. | Not checked |
| GameHacking.org | Many | Website; no bulk export (a scraper project exists) | n/a | Terms not read: site returned HTTP 403 to my fetch. | No. Scraping is not permission. | Not checked |
| MAME `cheat.7z` | Arcade | MAME cheat XML | Not measured | Not read. Unverified. | Unknown. | Not checked |
| FBNeo `cheat.dat` | Arcade | FBNeo ini/dat | Not measured | Not read. Unverified: FBNeo's own licence is non-commercial, so check before bundling. | Unknown. | Not checked |
| Dolphin `GameSettings` | GC, Wii | ini with `[ActionReplay]`, `[Gecko]` | Not measured | Dolphin repo is GPL-2.0-or-later (unverified). GagaEmu has no Dolphin core today. | Only if a Dolphin core is added. | n/a |

URLs behind the table:
- libretro-database README text: https://raw.githubusercontent.com/libretro/libretro-database/master/README.md (fetched; "Cheat codes are collected from any available source on the web...", files "used as-is by RetroArch if manually selected by the user").
- Repository listed as MIT: https://awesome.ecosyste.ms/projects/github.com%2Flibretro%2Flibretro-database (secondary).
- PPSSPP database behaviour: https://www.ppsspp.org/docs/reference/cwcheats (fetched; saves to `PSP/Cheats/cheat.db`, names follow CWCheat-Database-Plus; no licence or source stated).
- CTRPF-AR-CHEAT-CODES: https://github.com/jvhellraiser/CTRPF-AR-CHEAT-CODES (fork), https://www.gamebrew.org/wiki/CTRPF_AR_Cheat_Collections_3DS ("Mixed" licence), search results for the archive date.
- R4 `usrcheat.dat`: https://emulation.gametechwiki.com/index.php/Cheats_and_patches and https://wiki.ds-homebrew.com/ds-index/retail-roms (search snippets only; GBAtemp thread not read).
- GameHacking scraper: https://awesome.ecosyste.ms/projects/github.com%2Fmaxwlang%2Fgamehacking-scraper (secondary; says the site has no bulk export).
- Azahar cheat usage: https://www.joeysretrohandhelds.com/?p=6353 and https://manual.emudeck.com/tricks/azahar (search snippets). Gateway/Action Replay `.txt` named by title ID, from https://www.gamebrew.org/wiki/Raika_Azahar_Switch (a Switch fork, so only indicative).

## Recommended source per system

| System group | Source | Why |
|---|---|---|
| Cores that already apply cheats (GB, GBC, GBA, NES, SNES, Genesis, SMS, PS1 and so on) | libretro `cht`, bundled | One clean source, owner decision, formats match what the core reads. Check that the folder exists for each system. |
| PSP (PPSSPP) | libretro `cht` if it has a PSP folder; otherwise user import of a CWCheat `.ini` (already supported) | PPSSPP's database has no stated licence. |
| Arcade (MAME, FBNeo) | User import (already supported) | Pack terms unread, FBNeo licence concern. |
| 3DS (Azahar) | User import of Gateway `.txt`, after a core change | No source with a clear licence. |
| DS | libretro `cht` if present; `usrcheat.dat` by user import only if a reader is written | Pack has no stated licence. |
| Dreamcast, Lynx, NGP, Virtual Boy, Pokemon Mini, Atari 2600/5200/7800/800, Jaguar, C64, Amiga, DOS | libretro `cht` where a folder exists, applied through the poke engine below | Only after the core change. |

Further sources safe to add: none confirmed. The candidates above all need a licence read first. Until then they stay user-import only.

## Per-core plan

Verified upstream facts, read from the libretro core source on raw.githubusercontent.com:
- Azahar: `retro_cheat_set` is an empty stub; memory is given through `RETRO_ENVIRONMENT_SET_MEMORY_MAPS` (heap, linear heap, VRAM; virtual addresses), and `retro_get_memory_data` returns NULL. https://raw.githubusercontent.com/azahar-emu/azahar/master/src/citra_libretro/citra_libretro.cpp
- Flycast: `retro_cheat_set` and `retro_cheat_reset` are empty ("Nothing to do here"). The core has an internal `cheatManager` (used for the widescreen cheat) and a `core/cheats.cpp`, so wiring is plausible. https://raw.githubusercontent.com/flyinghead/flycast/master/shell/libretro/libretro.cpp, https://raw.githubusercontent.com/flyinghead/flycast/master/core/cheats.cpp
- beetle_vb, handy, puae, stella: `retro_cheat_set` is an empty stub. pokemini: stub with the comment "no cheats on this core". Handy returns a RAM pointer from `retro_get_memory_data`.
- prboom: `retro_cheat_set` works already (Doom cheat strings; cannot be switched off once active). The core is listed as lacking cheats in GagaEmu, so the gap is the host side, not the core.
- atari800, beetle_ngp, prosystem, vice, virtualjaguar, dosbox_pure: my guessed source URLs returned 404, so unverified. Assume stubs until read.

Generic route, "poke engine": the host parses a plain `address value` code (libretro `.cht` raw codes), then writes the bytes into the core's RAM every frame after `retro_run`. It uses `retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM)` or the memory map. Limits: RAM only, no ROM patches, no Game Genie style codes, and a code with a different address base than the core's RAM needs a per-system offset.

| Core | Feasible | How | Effort |
|---|---|---|---|
| azahar | Yes | Best: port the Gateway cheat engine from the Azahar tree into the libretro frontend's `retro_cheat_set` (engine location in the tree unverified). Fallback: host-side Gateway parser writing through the memory map each frame. | L |
| flycast | Likely | Wire `retro_cheat_set` to `cheatManager`; check what code format it reads. | M |
| prboom | Yes | Host passes Doom cheat strings through the working call. Remember the no-disable limit. | S |
| handy | Yes | Poke engine over the RAM pointer it already returns. | S |
| stella | Yes, 128-byte RAM | Poke engine; check the RAM pointer is exposed. | S to M |
| prosystem, atari800, pokemini, beetle_ngp, beetle_vb, virtualjaguar | Probably | Poke engine, after reading each core for a RAM pointer or map. | S to M each |
| vice | Probably | C64 `POKE address,value` lists fit the poke engine; 64 KB RAM. Code source: none found. | M |
| puae | Weak | Amiga has no common code format; needs a per-game trainer list. | L, low value |
| dosbox_pure | No | No stable memory address across DOS programs. Not planned. | n/a |

## Options the owner must decide

1. Bundle: done, for systems whose core can apply the codes.
2. Other sources (PPSSPP database, usrcheat, CTRPF AR): bundle (needs a licence read first), user import (works now for PSP, MAME, FBNeo), or on-demand fetch.
3. On-demand fetch of cheat text is not a ROM download, but check App Review Guideline 4.7 (software that downloads or runs code) with the reviewer, and each source's terms. Recommend: do not add a fetch path until a source offers terms that allow it.
4. ShareAlike: confirm with a lawyer that bundling CC BY-SA text, and any converted copies, fits the App Store licence terms. Give the credit text for the licences screen.
5. Whether to build the poke engine (one engine for about eight cores) or patch each core.
