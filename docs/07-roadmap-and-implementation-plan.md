# 07 — Roadmap & Implementation Plan

This document is canonical for phases and status. `docs/03` is canonical for the core list, licences and renderers, `docs/04` for interpreter design and load tiers, `docs/05` for graphics, and `docs/06` for the bridge API and premium spec. Other docs do not fork this plan.

**Where the project stands:** Phase 1 is closed: the code matches the docs, and the UI redesign (1.19 to 1.21) resolved 1.13. Milestones 2.1 to 2.10 are built: mGBA 0.10.5 runs a homebrew test ROM in a full game session on the iOS Simulator, with saves, fast-forward and cheats. No commercial game has been run, and nothing has run on a device: the device build compiles and passes the gate, but it has not been installed. Milestone 4.1, Gambatte, is built through the shared libretro adapter (merged from branch `core/gambatte`); its GPL legal gate (4.0) is open, so release builds leave it out. Milestones 4.2, Nestopia UE, 4.3, bsnes, 4.5, PCSX-ReARMed, and 4.6, melonDS DS, are built the same way (merged from branches `core/nestopia`, `core/bsnes`, `core/pcsx_rearmed` and `core/melonds_ds`), with the same gate. The 6 other non-mock registry cores are stubs that refuse to start. Status below comes from reading the code and from unit tests and screens on the iOS Simulator on 2026-11-07, not from a device test. Phase 3 is built except three items: `.slangp` import waits for MoltenVK, and RetroAchievements and iCloud Sync need owner action. AirPlay Fullscreen is built but unverified, because no second screen could be attached, so its row stays hidden.

**Status terms:**

- **built:** the code exists and does its job in the shell.
- **stub:** a row, toggle or symbol exists, but nothing acts on it.
- **planned:** no code exists.
- **blocked:** cannot start until the named owner action happens.

**Tier and phase are different things.** A load tier is a core's expected CPU load (`docs/04`). A phase is delivery order. They do not map onto each other: a Tier 1 core can arrive after a Tier 2 core, and Java ME is rated Tier 2 yet sits in Phase 6 because it depends on a spike. No performance claim in this plan is a measurement.

**No in-house rewrites are implied.** Each milestone adopts or ports an upstream core. Writing a new interpreter, or rewriting one inside a core, would be separately scheduled work with its own milestone. None is scheduled. `docs/04` section 4.2 lists the candidates, Dreamcast first, and the condition for starting one.

---

## 1. Phases

| Phase | Goal | Status | Exit condition |
|---|---|---|---|
| 0 | Shell, bridge skeleton and import tools | built | Done |
| 1 | Bring the code in line with the docs, and redesign the UI | built | Every milestone in section 4 closed |
| 2 | First game session with one real core | 2.1 to 2.8a and 2.10 built; 2.9 built, device benchmark pending | mGBA runs a game end to end on a device, and the paywall release gate can open |
| 3 | Shader chain and library features | built except 3.6 (deferred), 3.10 and the iCloud half of 3.11 (blocked); AirPlay built, unverified | Listed features work in a game session |
| 4 | Software-rendered cores | 4.1, 4.2, 4.3, 4.5 and 4.6 built, legal gate open; the rest planned | Each core meets section 2. Starts behind the legal gate. |
| 5 | Vulkan on MoltenVK | planned | Layer path works, and each core meets section 2 |
| 6 | High-load cores and spikes | planned | Each core meets section 2, or its row leaves `docs/03` |
| 7 | App Store submission qualification | planned | Checklist passes on the submitted binary |

Phase 7 repeats for each submission. A first submission needs only Phases 1, 2 and 7. Phases 3 to 6 can follow in later updates; whether to submit that early is an owner decision.

---

## 2. Definition of Done for a Core

A core milestone closes only when all of these hold:

1. **No-JIT gate passes for this core's build.** It runs per core and on every build, not only at the end (milestone 2.7, `docs/03` section 5, `docs/04` section 8). No JIT, no RWX and no dynarec ship in any core.
2. **Licence recorded.** The core's licence is in `docs/03`. For a GPL core, the legal gate (milestone 4.0) must already be closed.
3. **Renderer path accepted.** The core uses a path in `docs/05` section 2. GLES-only and desktop-GL-only renderers are not accepted.
4. **Runs in a game session.** Video, audio, input, battery saves and save states work on a device.
5. **Benchmark recorded.** A measured result on a named device is recorded, using the method in `docs/04` section 7.2 (milestone 2.8a). Until then, any speed figure stays labelled "target (unmeasured)".
6. **Registry and catalog updated.** The core's weak stub is deleted and its `core_id` is in the registry and in `CoreCatalog`.

---

## 3. Phase 0: Built

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 0.1 | XcodeGen project | built | `project.yml`. See 1.11. |
| 0.2 | SwiftUI shell | built, UI replaced by 1.21 | The first shell, with tabs and an Adventurer Card |
| 0.3 | Bridge, registry, mock core | built | Mock core produces a pattern and a 440 Hz sine. The 12 other cores are stubs. |
| 0.4 | ROM import | built | Files, WiFi, Read Clipboard, MultiDisc Helper, RomPatcher and drag and drop. 2.9 proved WiFi to Library to mGBA on the Simulator, and found that uploads never reached the Library; that is fixed. Files, clipboard and drag and drop have not loaded a real ROM into a core. |
| 0.5 | Metal ring, renderer, seven presets, preview | built | Core frames reach it since 2.2; Phase 3 extends it (`docs/05`). |
| 0.6 | Controllers, touch skins, TriggerPro logic | built | Feed the game session since 2.4 |
| 0.7 | Audio engine class | built | Rewritten and wired by 2.3 |
| 0.8 | StoreKit manager and paywall | built | See 1.5 and 1.6. |

ROM import sits here because cores depend on it and it already exists. The previous plan delivered it after the cores that need it.

---

## 4. Phase 1: Corrections

These are the code changes the docs expected. Items 1.1 to 1.4 were the mismatches in `docs/03` section 8. Verified on the iOS Simulator, not on a device.

Manic EMU is a feature reference only (owner decision, 2026-11-07). GagaEmu does not copy Manic's screens, labels or layouts. The redesign (1.19 to 1.21) closes this phase.

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 1.1 | Align `CoreCatalog` with `docs/03` | built | `CoreCatalog` now has the docs/03 defaults and removed cores, plus a Symbian row, so every platform in the master matrix appears. |
| 1.2 | Align the C registry | built | `Snes9x_GetInterface` and `GenesisPlusGx_GetInterface` deleted, and a JGenesis stub added. The registry has 12 entries: the mock core and 11 stubs. Remaining rows arrive as each core integrates. |
| 1.3 | Single core ID scheme | built | The short lowercase `core_id` (`mgba`, `pcsx_rearmed`) is the only ID. `StateMigration` upgrades saved `coreOverride` and `defaultCores` values in `state.json` on load. A saved choice of a removed core falls back to the platform default. |
| 1.4 | Fix `resolvedCoreID` | built | `GameItem.resolvedCoreID(defaults:)` honours `defaultCores`, and launch, `coreName` and `CorePickerSheet` share it. |
| 1.5 | Premium spec (`docs/06` section 4) | built | `anime4k` and `crt-royale` were taken off `premiumShaderIDs`. 3.4 returned `anime4k` once built and put `crt-deluxe` in place of `crt-royale`, whose saved selections reset to Original. `canUseAutoSaveState` is the gate on the row 2.6 restored. Redeem Offer is wired, and lifetime owners get no subscribe prompts. Offer badges and trial text follow the product's intro offer and eligibility. The paywall states the host shader chain limit. |
| 1.6 | Paywall release gate | built | One switch: the `PAYWALL_ENABLED` compilation condition (`PaywallGate`, `project.yml`). It is absent, so the Gaga Plus category and premium labels are hidden and limits are lifted. 7.2 opens it. |
| 1.7 | `PrivacyInfo.xcprivacy` and app icon | built | `Sources/App/PrivacyInfo.xcprivacy` declares no tracking, and no collected data until 3.8. Its one required-reason category is file timestamps, reason `C617.1`, for mGBA's `fstat`, GambatteCore's `stat` and the dates on save states, all inside the app container. Add each new one when code needs it. Since 3.8 it also declares Other Data Types (game titles sent for box art when Cover Art is on), for App Functionality, not linked and not tracking. The asset catalog holds the original Steps icon the owner chose, with dark and tinted entries (`docs/BRAND.md`). |
| 1.8 | Files app visibility | built | `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are set, so the app's Documents folder is visible in Files. The app does not yet import from Documents (ROMs live in Application Support). |
| 1.9 | GameKit | built | GameKit is linked, and `GameCenter.authenticate` runs in the background with no failure UI. The entitlement stays. No leaderboards or achievements. |
| 1.10 | Support links and metadata mismatch | built | The single host is `zenithblue-oss.github.io/gaga-emu-site`, in `SiteLinks`. Discord and QQ rows and pills are removed. FAQ and Feedback go to `support.html`, since the metadata has no support email. The site has no terms page, so Terms links to Apple's standard EULA until it does. |
| 1.11 | Stop tracking the generated project | built | `GagaEmu.xcodeproj/` is ignored and untracked. `scripts/appstore_release.sh` runs `scripts/generate-project.sh` first; run it yourself after a fresh clone. |
| 1.12 | Ring corrections | built | Row pitch comes from `minimumLinearTextureAlignment(for:)`. `attachCompletion` pairs each acquire with one completion signal (`docs/05` section 2.1). |
| 1.13 | Screen corrections | resolved by 1.19 to 1.21 | Side panels are not built. Controllers live in Settings > Controls, and play history is the Continue panel plus the Recent filter. Featured Items is removed under 1.14, and no JIT row exists. |
| 1.14 | Empty rows | built | Each stub row and the empty Featured Items row are hidden or removed; saved values stay in `state.json`. Theme was dropped by 1.19, because the palette is fixed. Still hidden: AirPlay Fullscreen, iCloud Sync, Online Play Settings, RetroAchievements, About Us, Share GagaEmu, Reset Tips, Language. `docs/06` section 3.3 lists the settings category and milestone that restores each. Quick Start, Auto Full Screen, Respect Silent Mode, Rumble and Skin Sound Effects came back with 2.1 to 2.4, Rate Us with 2.9, Auto Save State with 2.6, and Assign Skin and Cover Art (which replaced Cover Scraping) with 3.9 and 3.8. |
| 1.15 | WiFi transfer hardening | built | `PINAttemptLimiter`: every 5th wrong PIN locks the server for a minute, and the 15th stops it until the user restarts it with a new PIN. The PIN is header only, and comparison stays timing-safe. Plain HTTP remains; the Add screen and upload page say so, and that it is off by default. |
| 1.16 | GPU check | built | A14 required for layer-path 3D cores; 2D cores have no such floor. `GPUFloor.supportsLayerPathCores` wraps `device.supportsFamily(.apple7)`, and `GPUFloor.layerPathMessage` is the text. Nothing is refused today, because no code uses a Metal 3 API. 5.1 is the first caller. |
| 1.17 | IPS RLE support | built | `RomPatcher.applyIPS` already decoded RLE; only a stale comment and the docs said otherwise. Hand-built test vectors now cover it. |
| 1.18 | Stale comments | built | Comments corrected in `MetalTextureRing.swift`, `GagaBridge.h` and the shader picker, now `FilterPickerView.swift`. |
| 1.19 | Design system | built | "Paper and ink" tokens and shared styles in `AppTheme.swift` (`docs/06` section 3). The app follows the system appearance, so the Appearance row is gone. A unit test checks AA contrast for every text colour. The icon is covered in 1.7. |
| 1.20 | Landscape only | built | Landscape left and right on iPhone and iPad, with `UIRequiresFullScreen`. Device rotation and the portrait refusal were checked on the Simulator (iOS 27.0), not on a device. App Store validation was not run. The key is deprecated, so 7.6 rechecks it. `NSLocalNetworkUsageDescription` now names WiFi transfer only. |
| 1.21 | Screens redesign | built | Left rail, Library with Continue panel and shelves, Add, two-pane Settings, split filter picker, core picker sheet, and the Gaga Plus paywall (`docs/06` section 3). Paywall logic, import, security and migration behaviour are unchanged. Checked with screenshots on the Simulator, in light and dark, with empty and seeded libraries, on iPhone 18 Pro Max, iPhone 17e and iPad Pro 11-inch. |

---

## 5. Phase 2: First Game Session

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 2.1 | Game view and session controller | built, on the mock core | `GameSession` creates the core and loads the ROM off the main thread, steps it on the core's queue at `target_fps`, pauses for the menu, backgrounding and audio interruptions, and tears down. `GameView` and the pause menu are in `docs/06` section 3.7. A failed load shows the real message on the Library. `GameItem.resolvedROMPath` finds a game by file name in the ROM folder when the container path has moved. Play time and last played are saved on pause and stop. Restored Quick Start and Auto Full Screen (`docs/06` section 3.3). |
| 2.2 | Video | built, on the mock core | Video callback to ring to renderer, the copy path in `docs/05` section 2.1, with aspect fit, the ink letterbox, the game's shader, and pixel format or size changes between frames. The 16-bit path is expanded on the Simulator, so `.b5g6r5Unorm` has not run on a device. |
| 2.3 | Audio | built, on the mock core | `AudioEngineManager` rewritten around a source node, with `LinearResampler` converting to 48 kHz. No rate control yet, so clock drift would show as a rare dropped or re-primed moment. Restored Respect Silent Mode: on uses `.ambient`, off uses `.playback`. The switch itself has not been tested on a device. |
| 2.4 | Input | built, on the mock core | Controllers, touch and TriggerPro feed `GagaInputState`, sampled once per display frame. TriggerPro applies to player 1 only. 3.9 added built-in layouts per platform or game. The session reads keyboard mapping for Player 1 since 2.6; a real keyboard has not driven it in a test. A controller hides touch only once it has sent input, and Unassign persists by device name, because the Simulator reports a controller named Gamepad that never sends anything. Menu and Options together open the pause menu. Restored Rumble, which means a haptic on each touch press because the bridge has no rumble event, and Skin Sound Effects. |
| 2.5 | Bridge additions | built | `abi_version`, `self_test`, `pause`, `resume` and `set_event_callback` (`docs/06` sections 2.1 and 2.4). A core with the wrong ABI, or a failing self-test, is refused with a clear error. Capabilities, layer size and detach, host framebuffer and output texture stay planned for the paths that need them. |
| 2.6 | Saves | built, on the Simulator | Bridge ABI 2: buffer save states and `flush_battery_save`. `SaveStateFile` validates magic, core ID, state version, length and SHA-256 before a core sees the bytes, `AtomicFile` writes by temp file, `fsync` and rename, and the wrapper restores a snapshot if the core refuses, so a bad state leaves the game running. Battery saves flush on pause and before destroy. Manage Saves, from the Library or Load State, has slots with time and thumbnail, Load, Delete with confirmation, and Export Save for the battery save. `canAddSaveState` enforced. Auto Save State row restored; a saved on value needs `canUseAutoSaveState` too (1.14, 1.5). Saves on quit and background, and resume is offered on the next launch of that game. The Delete confirmation says saves stay. Run on the iPhone 18 Pro Simulator with the test ROM: save, load, background, kill, resume, quit, delete. Not on a device, and no commercial game. Export Save's share sheet has not been driven in the Simulator. |
| 2.7 | Per-core no-JIT gate | built | `scripts/nojit-gate.sh`, modelled on `S3/scripts/ios/build-core.sh:45-54`, runs on each core slice and as an app post-build step that fails the build. Per-core string list in `Cores/<id>/core.env`. Refuses JIT entitlement keys. `CodeGenCheck` walks executable regions at startup, in debug and test builds, and again when a session stops (`docs/04` section 8). Proved by a harness outside the repo; a build with an `allow-jit` plist failed. The runtime check has run on the Simulator only. |
| 2.8 | Core packaging | built | `scripts/build-core.sh` builds a dynamic xcframework, arm64 for simulator and device, and refuses any export except the bridge getter. One `project.yml`: no separate core project, because the core is built by script and the app always links it (`docs/06` section 2.5). `-std=c99` moved from `OTHER_CFLAGS` to `GCC_C_LANGUAGE_STANDARD`, so a C++ file in the app target compiles. |
| 2.8a | Benchmark method | built | `BenchmarkRun`, debug builds only, writes the `docs/04` section 7.2 run record to `Documents/Benchmarks`. Settings > About > Run Benchmark or `-GagaBenchmark` starts it. It has run once on the Simulator, labelled "simulator, not a performance measure". The host app is a Debug build and the core is optimised, so core ms per frame is meaningful, while host thread percentages are not a Release figure. |
| 2.9 | mGBA | built, device benchmark pending | mGBA 0.10.5 (`26b7884b`), GBA only, embedded API, HLE BIOS with the BIOS boot skipped. Battery saves are written to `Saves/<rom file name>/<rom stem>.sav` by mGBA, and survive quit and relaunch on the Simulator. 2.6 replaced blip_buf (LGPL-2.1) with `Cores/mgba/blip.c`, GagaEmu's own resampler (`docs/03` section 5). Section 2 status: item 1 yes; item 2 yes; item 3 yes; item 4 Simulator and homebrew ROM only, now including save states; item 5 no: this is what keeps the milestone open; item 6 yes. Rate GagaEmu restored in About, using the system review prompt, without the "5-star" copy. |
| 2.10 | Fast-forward and cheats | built, on the Simulator | Fast-forward: pause menu speeds and an on-screen toggle, capped by `maxFastForward`. N whole frames per tick, the last one drawn, and audio dropped while it runs, with sound back when it stops. Cheats: bridge add, remove and enable; mGBA's cheat API with GameShark, Action Replay, CodeBreaker and VBA formats, each proved by a test; a list per game in `cheats.json`, reapplied at launch; a pause menu sheet; `canAddCheat` enforced; invalid codes refused with a message. With the gate closed, the limits lift (1.6). Run on the Simulator with the test ROM, not on a device or a commercial game's real codes. |

---

## 6. Phase 3: Shader Chain and Library Features

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 3.1 | Built-in presets in a session | built, on the Simulator | Every preset was selected in an mGBA session with the homebrew test ROM and drew core frames, with screenshots. Fixes: colour temperature was not neutral at 0.5, presets now write alpha 1, and pixel-sized effects use the source size (`docs/05` section 3.1). The embedded MSL fallback is removed. |
| 3.2 | Parameter sliders | built, on the Simulator | Curvature, Scanlines, Glow and Colour, shown per preset, saved per filter in `state.json` when a drag ends, with Reset. A value set to 100 survived closing and reopening the picker (`docs/05` section 3.2). |
| 3.3 | Multi-pass chain | built, on the Simulator | Chain of passes with cached intermediates. Upscalers: Nearest, Bilinear, Bicubic (Catmull-Rom) and Edge Smooth. xBRZ is GPL-3.0, so Edge Smooth is GagaEmu's own edge-aware upscaler in its place (`docs/05` sections 3.4 and 5). GPU cost not measured on a device. |
| 3.4 | `anime4k`, CRT Deluxe | built, on the Simulator | `anime4k` is a Metal port of MIT-licensed Anime4K CNN x2 S. `crt-royale` is GPL and does not ship; CRT Deluxe, an original three-pass CRT, takes its premium slot. Premium list: `geom-crt`, `geom-crt-border`, `crt-deluxe`, `anime4k` (`docs/06` section 4.3). |
| 3.5 | Filter import, `.metal` | built, on the Simulator | Size, text, include, entry point, compile, link and binding checks, with the reason in plain text and Original selected on any failure, and a GPU failure falling back to Original (`docs/05` section 4.1). A file that does not compile and one without `gaga_fragment` were refused with their messages, and a working filter ran in a session. |
| 3.6 | Filter import, `.slangp` | planned, deferred to after 5.1 | Needs a Slang to MSL path, which waits for MoltenVK. No tab or button is shown. |
| 3.7 | Community filter presets | built | Replaces the old RetroArch tab. Three public-domain shaders from libretro/slang-shaders converted offline: Lottes CRT, LCD3x, Sharp Bilinear. That repository has no overall licence, so only files whose own header allows shipping are used (`docs/05` section 5). |
| 3.8 | Cover art | built, on the Simulator | Libretro Thumbnails only, by exact title. Off by default, with a toggle in Settings > Library that names the site; HTTPS, timeouts, size and image checks, cache in Caches, placeholder on failure (`docs/06` section 5). OpenVGDB and SteamGridDB are dropped. Tested with a stub URL protocol, never the live server. The privacy manifest declares the titles; the site privacy policy and App Store Connect privacy answers must change before a release that ships it (owner). |
| 3.9 | Assign Skin | built, on the Simulator | Three original built-in layouts, chosen per platform in Settings > Controls or per game from the long-press menu (`docs/06` section 3.7). Theme is gone by design. |
| 3.10 | RetroAchievements | blocked: owner account and approval | Needs an owner RetroAchievements account, sign-in testing and RA client approval. No account is created by the project. The row stays hidden. |
| 3.11 | AirPlay Fullscreen, iCloud Sync | AirPlay built, not verified; iCloud blocked: App ID capability | AirPlay: `ExternalDisplay` puts the picture on an external screen through a `windowExternalDisplayNonInteractive` scene and keeps the controls on the device (`docs/06` section 3.7). The installed Xcode has no Simulator app, so no external display could be attached; the row stays hidden until it is checked on a device with a second screen. iCloud Sync needs the iCloud capability on the App ID, an owner change; its row stays hidden. |

Online play is not scheduled. It is not promised or gated until built, and its Settings row stays hidden until then (1.14).

---

## 7. Phase 4: Software-Rendered Cores

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 4.0 | **Legal gate** | planned, open owner decision | Required before the first GPL core ships, and nearly every core is GPL. The likely posture is publishing app source under a compatible licence (`docs/03` section 5). Counsel is needed, including on any self-disclosure. Two further owner decisions for counsel (`docs/03` section 5): bsnes compiles upstream's 64-byte SPC700 IPL boot ROM, Nintendo code in `resources.hpp`, with no free replacement; and GPL-2.0-only Gambatte with GPL-3.0-or-later bsnes and melonDS DS in one binary. This is engineering guidance, not legal advice. |
| 4.1 | Game Boy / GBC: Gambatte | built, legal gate open, device benchmark pending | Merged from branch `core/gambatte`, pinned to `77f2567d` (GPL-2.0, `docs/03` section 5). The first core through the shared libretro adapter, `Cores/shared/LibretroAdapter.c` (`docs/06` section 2.5). Runs a generated homebrew GB and GBC ROM on the Simulator with battery saves, save states and cheats (GameShark type 01 and Game Genie). Uses the core's built-in post-boot state; no boot ROM. Kept out of release builds by `GAGA_CORE_SET` until 4.0 closes. |
| 4.2 | NES: Nestopia | built, legal gate open, device benchmark pending | Merged from branch `core/nestopia`, pinned to `f1e02d12` of libretro/nestopia (GPL-2.0-or-later, `docs/03` section 5), through the shared libretro adapter. Runs a generated homebrew iNES ROM (mapper 0, with and without battery RAM) on the Simulator with battery saves, save states and cheats (Game Genie and raw RAM codes; Pro Action Rocky is refused). Cartridges only: no FDS BIOS, so `.fds` is not offered. Simulator benchmark only, not a performance measure: 0.82 ms per frame mean. Kept out of release builds by `GAGA_CORE_SET` until 4.0 closes. |
| 4.3 | SNES: bsnes | built, legal gate open, device benchmark pending | Merged from branch `core/bsnes`, the libretro fork `libretro/bsnes-libretro` pinned to `b51612a7` (GPL-3.0-or-later, `docs/03` section 5), libretro target only, through the shared adapter. Upstream libco is replaced by GagaEmu's own arm64 `libco.c`, because upstream's makes memory executable. Runs a generated homebrew LoROM (`Sources/Debug/SNESTestROM.swift`: valid header and checksum, 8 KB battery SRAM, BG pattern, joypad cells, an uploaded SPC700 program playing a 500 Hz tone) on the Simulator: import, play from the Library, input, pause, save and load state, quit, and the battery boot counter surviving three launches. Cheats: Pro Action Replay and Game Genie. Simulator benchmark only, not a performance measure: 60.1 fps, core CPU 3.9 ms per frame mean. The SPC700 IPL boot ROM is compiled in from upstream; that is an open owner question (`docs/03` section 5). No coprocessor firmware, so Super Game Boy and BS-X games do not load. PAL games run at the NTSC frame rate. Kept out of release builds by `GAGA_CORE_SET` until 4.0 closes. |
| 4.4 | Genesis / Mega-CD: JGenesis | planned | Self-maintained iOS port. Upstream's frontend uses wgpu and iOS is not an official target. |
| 4.5 | PS1: PCSX-ReARMed | built, legal gate open, device benchmark pending | Merged from branch `core/pcsx_rearmed`, pinned to `7b0e8f8f` (GPL-2.0-or-later, `docs/03` section 5). Interpreter only: `DRC_DISABLE`, no new_dynarec, lightrec or lightning source, proved by the forbidden-source check on both slices. Software `gpu_neon` on its C SIMD path; HLE BIOS, no Sony BIOS. Runs a generated PS-EXE (`Sources/Debug/PS1TestEXE.swift`) that draws through GP0, reads the pad, plays an SPU tone and counts boots on the memory card, which persists as the battery save. Save states and GameShark cheats (types 30 and 80, among others) work. A generated cue and bin disc and a Multi-Disc Helper `.m3u` boot. Kept out of release builds by `GAGA_CORE_SET` until 4.0 closes. |
| 4.6 | DS: melonDS DS | built, legal gate open, device benchmark pending | Merged from branch `core/melonds_ds`, pinned to v1.4.0 `f394adba` (GPL-3.0-or-later), with each fetched dependency a pinned submodule (`docs/03` section 5). No JIT, no OpenGL, no networking compiled. melonDS's free BIOS and built-in firmware, direct boot; no Nintendo file. The two screens sit side by side, top screen left, and a finger on the lower screen in the picture reaches the core as the libretro pointer (bridge ABI 3). Runs a generated homebrew DS ROM (`Sources/Debug/NDSTestROM.swift`) on the Simulator: both screens, buttons including X and Y, touch, sound, EEPROM saves, save states and Action Replay cheats. A retail dump with an encrypted secure area needs Nintendo's BIOS, so the core shows its own error screen for one. DSi mode and DSi camera are not offered. Kept out of release builds by `GAGA_CORE_SET` until 4.0 closes. |
| 4.7 | Arcade: MAME | planned | Audit for dynamic-recompiler paths. Libretro output path is unverified. |
| 4.8 | DOS / Win9x: DOSBox Pure | planned | Normal core. The dynamic core must be compiled out, not only left unselected. |
| 4.9 | Alternates | planned | Each one individually, once its gaps in `docs/03` section 3 are closed. |

---

## 8. Phase 5: Vulkan on MoltenVK

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 5.1 | MoltenVK and layer path | stub | Statically link MoltenVK. Size-aware attach and detach (`docs/06` section 2.4). The libretro Vulkan adapter (`docs/05` section 2.3). First caller of `GPUFloor.supportsLayerPathCores`: a layer-path core on a device below A14 shows `GPUFloor.layerPathMessage` (1.16). |
| 5.2 | **N64 RSP spike** | planned | `ios-arm64` sets `HAVE_PARALLEL_RSP = 1`, which compiles `rsp_jit.cpp` and GNU Lightning, so Mupen64Plus-Next fails the no-JIT gate as configured. Prove an interpreter RSP can drive ParaLLEl-RDP at usable speed. Also confirm ParaLLEl-RDP's Vulkan 1.1 and 8-bit and 16-bit storage needs on MoltenVK. |
| 5.3 | N64: Mupen64Plus-Next | planned | Only if 5.2 passes. The core's Tier 2 rating depends on the spike. |
| 5.4 | PS1 alternate: Beetle PSX HW, Vulkan mode | planned | The iOS Vulkan build config is unverified. Keep "CPU Dynarec" disabled. |
| 5.5 | PSP: PPSSPP | planned | `IR_INTERPRETER`, not plain `INTERPRETER`. Choose native Metal outside libretro or Vulkan on MoltenVK. |
| 5.6 | Core-output texture path | planned | Optional. Lets layer-path cores use host shaders (`docs/05` section 2.4). |

---

## 9. Phase 6: High-Load Cores and Spikes

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 6.0 | Memory entitlements | planned | Add `com.apple.developer.kernel.extended-virtual-addressing` (address space) and `com.apple.developer.kernel.increased-memory-limit` (RAM limit) to the entitlements file and App ID before any Tier 3 core. |
| 6.1 | Saturn: Beetle Saturn | planned | |
| 6.2 | Dreamcast: Flycast JIT-less fork | planned | Name and maintain the fork first. Upstream dropped iOS support, and the fork source was not located. |
| 6.3 | 3DS: Azahar (experimental) | planned | `use_cpu_jit` and `use_shader_jit` must be off and compiled out, and `shader_jit_a64_compiler` must not ship. Vulkan on MoltenVK, or the software renderer. PICA200 path per `docs/03` section 4: fragment shaders use `spv_fs_shader_gen.cpp`. No SPIR-V vertex generator was found; the vertex path appears to go through GLSL, which is inferred from file names and not traced. |
| 6.4 | **J2meJS spike** | planned | Establish the source, licence and JS runtime path, and whether that path uses any JIT that counts against the no-JIT rule. No upstream repo has been identified. |
| 6.5 | Java ME: J2meJS | planned | Only if 6.4 passes. |
| 6.6 | **EKA2L1 renderer spike** | planned | The iOS path links OpenGLES.framework, which is not an accepted path. Prove a Vulkan or software renderer works, and that the dyncom interpreter runs games. |
| 6.7 | Symbian: EKA2L1 | planned | Only if 6.6 passes. |

A failed spike removes the platform's row from `docs/03`.

---

## 10. Phase 7: Submission Qualification

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 7.1 | Correct App Store metadata | planned | `AppStore/metadata` and its review notes describe gameplay that does not exist. Correct them before any submission, and match them to what the binary does. |
| 7.2 | Paywall gate decision | planned | Open only if 2.9 is closed and products exist in App Store Connect (`docs/06` section 4.5). Opening it means adding the `PAYWALL_ENABLED` compilation condition (1.6). |
| 7.3 | No-JIT audit of the final binary | planned | Rerun the gate on every embedded framework. Attribute JIT denial to OS enforcement (W^X, no public iOS entitlement), not to a guideline. |
| 7.4 | Guideline 4.7 review | planned | 4.7 covers "retro game console and PC emulator apps". Apple defines no generations. Confirm the catalog against the current text. |
| 7.5 | Licence notices | planned | Every shipped core's licence and any source offer appear in the app (`docs/03` section 5), with Anime4K's MIT notice and the public-domain credits in `docs/05` section 5. Restores the About Us row to show them (1.14). |
| 7.6 | Screens and rows | planned | No empty rows (1.14). Restores the Share GagaEmu row, using the system share sheet. Screenshots show real gameplay in this app's own landscape UI; `AppStore/screenshots` must be replaced, because `scripts/make_screenshots.py` builds them from the Manic reference images. Privacy manifest present (1.7), and the icon chosen by the owner (Steps, 1.7). Recheck `UIRequiresFullScreen` against the current iPadOS SDK (`docs/06` section 3). |

---

## 11. Platform Lookup

`docs/03` is canonical for each core's details; `docs/04` for tiers.

| Platform | Milestone |
|---|---|
| GBA | 2.9 |
| Game Boy / GBC | 4.1 |
| NES | 4.2 |
| SNES / Super Famicom | 4.3 |
| Genesis / Mega-CD | 4.4 |
| PS1 | 4.5, alternate at 5.4 |
| DS | 4.6 |
| Arcade | 4.7 |
| DOS / Win9x | 4.8 |
| N64 | 5.2 then 5.3 |
| PSP | 5.5 |
| Saturn | 6.1 |
| Dreamcast | 6.2 |
| 3DS | 6.3 |
| Java ME | 6.4 then 6.5 |
| Symbian | 6.6 then 6.7 |

---

## 12. Outside the Plan

- **Non-shipping research, not promised:** Dolphin (GameCube and Wii) and PS2 (Balero-S2). Neither is in the App Store binary. No milestone delivers them.
- **External sister projects:** S3 (PS3) and S4 (PS4) stay in their own repositories. They are never catalog rows or frame producers. GagaEmu reuses their build patterns only.
- **Backlog:** WonderSwan and the other systems in `docs/03` section 6 are "seen in Manic listing, not planned for v1".
- **Excluded:** the cores in `docs/03` section 6 are not scheduled.
- **Hidden rows with no phase (1.14):** Reset Tips returns once the app has dismissible tips, and Language once a second localisation exists.
