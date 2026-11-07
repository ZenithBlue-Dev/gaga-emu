# 07 — Roadmap & Implementation Plan

This document is canonical for phases and status. `docs/03` is canonical for the core list, licences and renderers, `docs/04` for interpreter design and load tiers, `docs/05` for graphics, and `docs/06` for the bridge API and premium spec. Other docs do not fork this plan.

**Where the project stands:** the app is a shell plus a mock core. The 12 non-mock registry cores are stubs, and no game session exists. Status below comes from reading the code on 2026-11-07, not from a device test.

**Status terms:**

- **built:** the code exists and does its job in the shell.
- **stub:** a row, toggle or symbol exists, but nothing acts on it.
- **planned:** no code exists.

**Tier and phase are different things.** A load tier is a core's expected CPU load (`docs/04`). A phase is delivery order. They do not map onto each other: a Tier 1 core can arrive after a Tier 2 core, and Java ME is rated Tier 2 yet sits in Phase 6 because it depends on a spike. No performance claim in this plan is a measurement.

**No in-house rewrites are implied.** Each milestone adopts or ports an upstream core. Writing a new interpreter, or rewriting one inside a core, would be separately scheduled work with its own milestone. None is scheduled. `docs/04` section 4.2 lists the candidates, Dreamcast first, and the condition for starting one.

---

## 1. Phases

| Phase | Goal | Status | Exit condition |
|---|---|---|---|
| 0 | Shell, bridge skeleton and import tools | built | Done |
| 1 | Bring the code in line with the docs | planned | Every milestone in section 4 closed |
| 2 | First game session with one real core | planned | mGBA runs a game end to end on a device, and the paywall release gate can open |
| 3 | Shader chain and library features | planned, with parts built in Phase 0 | Listed features work in a game session |
| 4 | Software-rendered cores | planned | Each core meets section 2. Starts behind the legal gate. |
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
| 0.2 | SwiftUI shell | built | Games, Import and Settings tabs, glass tab bar, Adventurer Card |
| 0.3 | Bridge, registry, mock core | built | Mock core produces a pattern and a 440 Hz sine. The 12 other cores are stubs. |
| 0.4 | ROM import | built | Files, WiFi, Read Clipboard, MultiDisc Helper, RomPatcher and drag and drop. No real core has loaded an imported ROM yet; 2.9 proves that path. |
| 0.5 | Metal ring, renderer, seven presets, preview | built | No core frame reaches it (`docs/05`). |
| 0.6 | Controllers, touch skins, TriggerPro logic | built | No session to feed |
| 0.7 | Audio engine class | built | Unused, no resampler. See 2.3. |
| 0.8 | StoreKit manager and paywall | built | See 1.5 and 1.6. |

ROM import sits here because cores depend on it and it already exists. The previous plan delivered it after the cores that need it.

---

## 4. Phase 1: Corrections

These are the code changes the docs now expect. All are `Status: planned`. Items 1.1 to 1.4 are the mismatches in `docs/03` section 8.

| ID | Milestone | Detail |
|---|---|---|
| 1.1 | Align `CoreCatalog` with `docs/03` | Remove Snes9x, Genesis Plus GX, PicoDrive and FBNeo, which are excluded by licence, plus Kronos and SwanStation. Fix recommended defaults (`AppState.swift:60,87,100`). Fix the comment at `:43`. |
| 1.2 | Align the C registry | Delete `Snes9x_GetInterface` and `GenesisPlusGx_GetInterface`. Add a JGenesis entry. Update `Tests/GagaEmuTests.swift:22,24`. Remaining rows arrive as each core integrates. |
| 1.3 | Single core ID scheme | The registry's short lowercase `core_id` (`mgba`, `pcsx_rearmed`) becomes the only ID. `CoreCatalog` adopts it, and saved `coreOverride` and `defaultCores` values in `state.json` are migrated. |
| 1.4 | Fix `resolvedCoreID` | `GameItem.resolvedCoreID` (`AppState.swift:17-19`) ignores `defaultCores`. The launch path, `coreName` and `CoreSelectionSheet` already honour it, so the bug affects only this property, whose one use is the assertion at `GagaEmuApp.swift:30`. Update that assertion together with 1.3. |
| 1.5 | Premium spec (`docs/06` section 4) | Take `anime4k` and `crt-royale` off `premiumShaderIDs`, and remove `anime4k` from `ShaderCatalog` until implemented. Gate Auto Save State. Wire Redeem Offer. Hide subscribe prompts from lifetime owners. Show offer badges and trial text only when the product has that offer. State on the paywall that Premium Filters apply only to cores that use the host shader chain. |
| 1.6 | Paywall release gate | Off in submitted builds until 2.9 closes. While off, the banner is hidden and limits are lifted. |
| 1.7 | `PrivacyInfo.xcprivacy` and app icon | Neither exists, and there is no asset catalog. S3 and S4 carry a privacy manifest. |
| 1.8 | Files app visibility | Decide on and add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` (`S3` `Info.plist:81-83`). |
| 1.9 | GameKit | The `com.apple.developer.game-center` entitlement is present, but GameKit is neither linked nor used. Link and use it, or remove the entitlement and App ID capability. |
| 1.10 | Support links and metadata mismatch | Choose one host: the app uses `gagaemu.app`, the App Store metadata uses `zenithblue-oss.github.io/gaga-emu-site`. Replace the Discord placeholder or remove the rows and pills. Remove Join QQ Channel unless a channel exists. |
| 1.11 | Stop tracking the generated project | Remove `GagaEmu.xcodeproj/project.pbxproj` from git and ignore it, after confirming the release scripts run XcodeGen first. |
| 1.12 | Ring corrections | Replace the hard-coded 256 with `minimumLinearTextureAlignment(for:)`. Pair each acquire with one completion signal (`docs/05` section 2.1). |
| 1.13 | Screen corrections (`docs/06` section 3) | Present Controllers and Play History as side panels from opposite sides. Remove Featured Items. Keep the JIT row out. |
| 1.14 | Empty rows | Implement or hide each stub row in `docs/06` section 3.3 before submission. |
| 1.15 | WiFi transfer hardening | Add a PIN attempt limit and stop accepting the PIN in the query string. Plain HTTP remains; the UI should say so. |
| 1.16 | GPU floor check | Runtime check with `device.supportsFamily(.apple7)`. iOS 17.0 also runs on A12 and A13, so the floor must be enforced or the docs changed. |
| 1.17 | IPS RLE support | `RomPatcher.swift:91` throws on RLE records, which are a standard part of IPS. |
| 1.18 | Stale comments | "Zero-copy" and "256-byte" in `MetalTextureRing.swift`, Balero-S2 at `GagaBridge.h:91`, and the stand-in preview in `ShadersSettingsView.swift`. |

---

## 5. Phase 2: First Game Session

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 2.1 | Game view and session controller | planned | `launch` creates the core, loads the ROM, runs `step_frame` and tears down. Prove it with the mock core first. |
| 2.2 | Video | planned | Video callback to ring to renderer, the copy path in `docs/05` section 2.1. |
| 2.3 | Audio | planned | Wire `AudioEngineManager` to the audio callback and add the missing resampler. Core rates differ from the output rate. |
| 2.4 | Input | planned | Controllers, touch skins and TriggerPro feed `GagaInputState`. |
| 2.5 | Bridge additions | planned | ABI version, self-test, pause and resume, event callback (`docs/06` section 2.4). |
| 2.6 | Saves | planned | Battery saves, save states, Manage Saves, Export Save. Enforce `canAddSaveState`. |
| 2.7 | Per-core no-JIT gate | planned | A build script in this repo, modelled on `S3/scripts/ios/build-core.sh:45-54`, with a per-core string list. Add a runtime check for code generation at startup, which a symbol scan can miss (`S3/docs/ios/research/00-README.md`). |
| 2.8 | Core packaging | planned | Dynamic embedded xcframework exporting only the bridge (`docs/06` section 2.5). |
| 2.8a | Benchmark method | planned | Set up the run record, metrics and procedure in `docs/04` section 7.2 before the first core milestone. Section 2 item 5 depends on it. |
| 2.9 | mGBA | planned | First real core, meets section 2. Chosen first because it is MPL-2.0 (`docs/03`), so it does not wait on the GPL gate. Its MPL obligations still need recording. |
| 2.10 | Fast-forward and cheats | planned | Enforce `maxFastForward` and `canAddCheat`. Add the cheat UI. |

---

## 6. Phase 3: Shader Chain and Library Features

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 3.1 | Built-in presets in a session | planned | The seven presets exist (0.5). This applies them to core frames. |
| 3.2 | Parameter sliders | planned | Properties exist; no UI does. |
| 3.3 | Multi-pass chain | planned | Bicubic and xBRZ upscalers (`docs/05` section 3.4). |
| 3.4 | `anime4k`, `crt-royale` | planned | They may return to the premium list only once implemented. |
| 3.5 | Import tab, `.metal` | planned | Runtime `makeLibrary(source:)` (`docs/05` section 4). |
| 3.6 | Import tab, `.slangp` | planned | Decide the translation path first. |
| 3.7 | RetroArch tab | planned | Offline-converted presets with licences recorded. |
| 3.8 | Cover scraping | stub | OpenVGDB and Libretro Thumbnails, with SteamGridDB under consideration. |
| 3.9 | Theme, Assign Skin | stub | Rows exist, with empty actions. |
| 3.10 | RetroAchievements | stub | Sign-in and achievements. |
| 3.11 | AirPlay Fullscreen, iCloud Sync | stub | Toggles exist. |

Online play is not scheduled. It is not promised or gated until built.

---

## 7. Phase 4: Software-Rendered Cores

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 4.0 | **Legal gate** | planned, open owner decision | Required before the first GPL core ships, and nearly every core is GPL. The likely posture is publishing app source under a compatible licence (`docs/03` section 5). Counsel is needed, including on any self-disclosure. This is engineering guidance, not legal advice. |
| 4.1 | Game Boy / GBC: Gambatte | planned | |
| 4.2 | NES: Nestopia | planned | |
| 4.3 | SNES: bsnes | planned | |
| 4.4 | Genesis / Mega-CD: JGenesis | planned | Self-maintained iOS port. Upstream's frontend uses wgpu and iOS is not an official target. |
| 4.5 | PS1: PCSX-ReARMed | planned | `DYNAREC=0`. |
| 4.6 | DS: melonDS DS | planned | Software renderer. DSi camera is not promised. |
| 4.7 | Arcade: MAME | planned | Audit for dynamic-recompiler paths. Libretro output path is unverified. |
| 4.8 | DOS / Win9x: DOSBox Pure | planned | Normal core. The dynamic core must be compiled out, not only left unselected. |
| 4.9 | Alternates | planned | Each one individually, once its gaps in `docs/03` section 3 are closed. |

---

## 8. Phase 5: Vulkan on MoltenVK

| ID | Milestone | Status | Detail |
|---|---|---|---|
| 5.1 | MoltenVK and layer path | stub | Statically link MoltenVK. Size-aware attach and detach (`docs/06` section 2.4). The libretro Vulkan adapter (`docs/05` section 2.3). |
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
| 7.2 | Paywall gate decision | planned | Open only if 2.9 is closed and products exist in App Store Connect (`docs/06` section 4.5). |
| 7.3 | No-JIT audit of the final binary | planned | Rerun the gate on every embedded framework. Attribute JIT denial to OS enforcement (W^X, no public iOS entitlement), not to a guideline. |
| 7.4 | Guideline 4.7 review | planned | 4.7 covers "retro game console and PC emulator apps". Apple defines no generations. Confirm the catalog against the current text. |
| 7.5 | Licence notices | planned | Every shipped core's licence and any source offer appear in the app (`docs/03` section 5). |
| 7.6 | Screens and rows | planned | No empty rows (1.14). Screenshots show real gameplay. Privacy manifest and icon present (1.7). |

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
