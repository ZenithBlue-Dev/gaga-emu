# GagaEmu

A multi-system emulator for iPhone and iPad, built for the App Store with no JIT in any core.

GagaEmu puts your own games on a quiet shelf and plays them with well-known open source emulator cores, rendered through Metal. It runs upright or in landscape on iPhone and iPad (iOS 17 or later).

Copyright (C) 2026 zenithblue. GagaEmu is free software under the [GNU Affero General Public License 3.0](./LICENSE).

> **No games or BIOS are included.** GagaEmu ships no games, ROMs, BIOS, firmware or keys, and does not link to or help you obtain them. Bring your own legally dumped files.

---

## Features

- **31 cores** in App Store builds (see the systems below), each built as an interpreter with no JIT, RWX memory or dynarec. Every core build passes a no-JIT gate (`scripts/nojit-gate.sh`).
- **Metal throughout.** 2D cores present through a Metal frame path; 3D cores (N64, PS1 HW, PSP, Dreamcast, 3DS) render with Vulkan on MoltenVK to a `CAMetalLayer`. Layer-path 3D cores need an A14 or newer.
- **Picture filters.** Built-in Metal presets (CRT, LCD, cartoon, film and more), Anime4K upscaling, `.slangp` and `.metal` filter import, and saved presets.
- **Touch skins.** Original built-in layouts, a skin editor, and imported `.deltaskin` button layouts. MFi, DualShock 4, DualSense, Xbox and Joy-Con controllers and hardware keyboards are supported.
- **Saves.** Battery saves, save states, rewind where the system supports it, and iCloud sync (Pro).
- **Play Nearby.** Multiplayer between nearby devices, with encrypted pairing, on supported cores.
- **RetroAchievements.** Sign in to earn achievements (rcheevos).
- **Import tools.** Files and iCloud Drive, a PIN-protected WiFi Transfer page (off by default), zip unpacking, a multi-disc playlist helper, and IPS, BPS and UPS patching in memory.
- **Cheats** from the libretro cheat database, plus TriggerPro turbo, hold and combo buttons.
- **Private by design.** No accounts, analytics, advertising or tracking.

### Systems in App Store builds

| System | Core |
|---|---|
| Game Boy / Game Boy Color | Gambatte |
| Game Boy Advance | mGBA |
| NES | Nestopia UE |
| SNES / Super Famicom | bsnes (with a clean-room SPC700 boot program) |
| Genesis / Mega Drive / Mega-CD | JGenesis |
| PlayStation | PCSX-ReARMed, Beetle PSX HW, SwanStation |
| Nintendo DS | melonDS DS |
| Saturn | Beetle Saturn |
| Nintendo 64 | Mupen64Plus-Next |
| PSP | PPSSPP |
| Dreamcast | Flycast |
| Nintendo 3DS (experimental) | Azahar |
| Arcade | MAME |
| DOS / Windows 9x | DOSBox Pure |
| PC Engine / TurboGrafx-16 / CD | Beetle PCE Fast |
| SuperGrafx | Beetle SuperGrafx |
| Virtual Boy | Beetle VB |
| Neo Geo Pocket / Color | Beetle NeoPop |
| WonderSwan / Color | Beetle Cygne |
| Pokémon Mini | PokeMini |
| Master System / Game Gear / SG-1000 | Gearsystem |
| Atari 2600 | Stella |
| Atari 7800 | ProSystem |
| Atari Lynx | Handy |
| Atari 5200 / 8-bit | Atari800 |
| Atari Jaguar | Virtual Jaguar |
| Commodore 64 | VICE |
| Amiga | PUAE |
| Doom (WAD) | PrBoom |

Snes9x, Genesis Plus GX, PicoDrive (32X) and FinalBurn Neo have non-commercial licences, so they are only in personal sideload builds (`GAGA_CORE_SET=sideload`), never in App Store builds. [`docs/03`](./docs/03-core-matrix-and-platform-catalog.md) is the full core matrix, with pins, licences and renderer paths.

## Screenshots

App Store screenshots are produced in `design/store` and exported to `AppStore/screenshots/` when available.

---

## Building

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen). From a clean checkout:

```bash
git submodule update --init
scripts/build-core.sh          # writes build/cores/<Framework>.xcframework per core, runs the no-JIT gate
scripts/build-moltenvk.sh      # MoltenVK, for the 3D cores
scripts/generate-project.sh    # runs xcodegen with the core set; GAGA_CORE_SET="mgba" links only mGBA
xcodebuild build -project GagaEmu.xcodeproj -scheme GagaEmu \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

`scripts/generate-project.sh` with no `GAGA_CORE_SET` links the App Store core set (every core except the non-commercial ones and the `vktest` debug core). `GAGA_CORE_SET=sideload` links every core and compiles out StoreKit, for a free personal build only. Name `vktest` in `GAGA_CORE_SET` to run its Vulkan layer-path tests.

Run `xcodebuild test` with the same arguments for the tests. For a device build without signing, use `-destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. A build fails if a core fails the no-JIT gate (`docs/04` section 8). Build outputs and the generated project are not committed. `docs/06` section 2.5 has the recipe for adding a core.

**Test ROMs.** No commercial game, Nintendo or Sony material is involved. `scripts/make-test-rom.sh <out.gba|out.gb|out.gbc|out.nes|out.sfc|out.nds|out.exe|out.cue>` writes a small homebrew ROM or PS1 program from the generators in `Sources/Debug`; the tests generate their own.

**Benchmark.** In a Debug build, use Settings > About > Run Benchmark, or launch with `-GagaBenchmark` (add `-GagaBenchmarkCore gambatte` for another core). The record lands in Documents/Benchmarks, which the Files app shows. `docs/04` section 7.2 has the procedure. A Debug build launched with `-GagaImportROM <path>` adds that file to the Library as Files import does, once.

---

## GagaEmu Pro

Every system and core is free to play, with no ads and no sign-in. GagaEmu Pro is an optional subscription or one-time purchase in the App Store build. It adds fast forward above 2x, more than 4 save states and 5 cheats per game, players 3 and 4, the full filter catalogue, iCloud sync, and extra app icons and colours. Pro funds development. Its code is part of this repository and available under the AGPL like the rest of the app.

## Licence

GagaEmu's own code is licensed under the [GNU Affero General Public License 3.0](./LICENSE). Copyright (C) 2026 zenithblue.

The App Store binary is distributed under the AGPL-3.0, and this repository is its corresponding source.

Bundled emulator cores and libraries keep their own licences, including GPL-2.0, GPL-2.0-or-later, GPL-3.0, MPL-2.0 (mGBA), Zlib (Handy), Apache-2.0 (MoltenVK) and MIT. Each component's licence text is in Settings > About > Licences in the app, generated from [`Licences/notices.json`](./Licences/notices.json) by `scripts/generate-licences.py`. [`docs/03`](./docs/03-core-matrix-and-platform-catalog.md) section 5 records the licence review.

GagaEmu is an independent project. It is not affiliated with, endorsed by or sponsored by any console maker. All trademarks belong to their owners.

## Contributing

Issues and pull requests are welcome. Keep changes small and focused, and run the tests before you open a pull request. New cores must build without JIT and pass the no-JIT gate; read [`docs/06`](./docs/06-ios-app-bridge-and-subsystem-spec.md) section 2.5 first. By contributing you agree that your contribution is licensed under the AGPL-3.0. Never commit games, BIOS, firmware or keys.

## Credits

GagaEmu stands on the work of these projects:

[mGBA](https://github.com/mgba-emu/mgba) ·
[Gambatte](https://github.com/libretro/gambatte-libretro) ·
[Nestopia UE](https://github.com/libretro/nestopia) ·
[bsnes](https://github.com/libretro/bsnes-libretro) ·
[JGenesis](https://github.com/jsgroth/jgenesis) ·
[PCSX-ReARMed](https://github.com/libretro/pcsx_rearmed) ·
[Beetle PSX HW](https://github.com/libretro/beetle-psx-libretro) ·
[SwanStation](https://github.com/libretro/swanstation) ·
[melonDS DS](https://github.com/JesseTG/melonds-ds) ·
[Beetle Saturn](https://github.com/libretro/beetle-saturn-libretro) ·
[Mupen64Plus-Next](https://github.com/libretro/mupen64plus-libretro-nx) ·
[PPSSPP](https://github.com/hrydgard/ppsspp) ·
[Flycast](https://github.com/flyinghead/flycast) ·
[Azahar](https://github.com/azahar-emu/azahar) ·
[MAME](https://github.com/libretro/mame) ·
[DOSBox Pure](https://codeberg.org/schelling/dosbox-pure) ·
[Beetle PCE Fast](https://github.com/libretro/beetle-pce-fast-libretro) ·
[Beetle SuperGrafx](https://github.com/libretro/beetle-supergrafx-libretro) ·
[Beetle VB](https://github.com/libretro/beetle-vb-libretro) ·
[Beetle NeoPop](https://github.com/libretro/beetle-ngp-libretro) ·
[Beetle Cygne](https://github.com/libretro/beetle-wswan-libretro) ·
[PokeMini](https://github.com/libretro/PokeMini) ·
[Gearsystem](https://github.com/drhelius/Gearsystem) ·
[Stella](https://github.com/stella-emu/stella) ·
[ProSystem](https://github.com/libretro/prosystem-libretro) ·
[Handy](https://github.com/libretro/libretro-handy) ·
[Atari800](https://github.com/libretro/libretro-atari800) ·
[Virtual Jaguar](https://github.com/libretro/virtualjaguar-libretro) ·
[VICE](https://github.com/libretro/vice-libretro) ·
[PUAE](https://github.com/libretro/libretro-uae) ·
[PrBoom](https://github.com/libretro/libretro-prboom) ·
[MoltenVK](https://github.com/KhronosGroup/MoltenVK) ·
[rcheevos](https://github.com/RetroAchievements/rcheevos) ·
[Anime4K](https://github.com/bloc97/Anime4K) ·
[libretro slang-shaders](https://github.com/libretro/slang-shaders) ·
[libretro-database](https://github.com/libretro/libretro-database) ·
[glslang](https://github.com/KhronosGroup/glslang) and SPIRV-Cross

Sideload builds also use [Snes9x](https://github.com/libretro/snes9x), [Genesis Plus GX](https://github.com/libretro/Genesis-Plus-GX), [PicoDrive](https://github.com/libretro/picodrive) and [FinalBurn Neo](https://github.com/libretro/FBNeo).

---

## Technical documentation

Engineering specifications are in [`docs/`](./docs/):

- [01 — Problem statement and executive summary](./docs/01-problem-statement-and-executive-summary.md)
- [02 — Feature set](./docs/02-feature-set-and-manic-emu-parity.md)
- [03 — Core matrix and platform catalog](./docs/03-core-matrix-and-platform-catalog.md): core list, alternates, licences, renderer paths, and the legal and no-JIT gates.
- [04 — No-JIT interpreter architecture](./docs/04-no-jit-interpreter-architecture.md): iOS execution constraints, performance tiers, benchmark method and the per-core gate.
- [05 — Metal graphics pipeline and shaders](./docs/05-metal-graphics-pipeline-and-shaders.md)
- [06 — iOS app architecture, C bridge and subsystems](./docs/06-ios-app-bridge-and-subsystem-spec.md): the bridge interface, UI specification, premium spec and project manifest.
- [07 — Roadmap and implementation plan](./docs/07-roadmap-and-implementation-plan.md)
