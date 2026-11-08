# 01 — Problem Statement & Executive Summary

Gaga-Emu is a multi-system emulator for iOS and iPadOS, with iOS 17.0 as the minimum OS. No shipped core uses JIT, RWX memory or a dynarec. App UI, frame presentation and the host post-process chain use native Metal. 3D cores render through Vulkan on statically linked MoltenVK to `CAMetalLayer`, the same pattern as the S3 and S4 sister projects. MoltenVK counts as Metal for this project (owner decision, 2026-11-07).

**Status:** `Sources/Bridge/GagaCoreRegistry.c` has 38 entries: 35 real cores, the mock core, the Debug-only `vktest` layer-path test core, and one stub (`gpsp`). Games run on a device, and the cores are merged but gated: release builds leave out every GPL core until the legal gate (`docs/07` 4.0) closes. Device results are in `docs/04` section 7.1. Sections below that describe design are marked as design. `docs/07` is canonical for phases and status.

**Doc ownership:** `docs/03` core list, licences and renderers. `docs/04` interpreter design and performance tiers. `docs/06` bridge API and premium/IAP spec. `docs/07` phases and status.

**Source tags for Manic EMU facts:** **[S]** seen in screenshot, **[L]** App Store listing or public repo, **[G]** GagaEmu design. The full legend is in `docs/02`.

---

## 1. Problem Statement

### 1.1 The iOS Emulation Landscape & App Store Constraints
Two separate constraints apply. They have different sources.

**OS enforcement (JIT):** iOS enforces W^X memory protection and offers no public JIT entitlement for App Store apps. `com.apple.security.cs.allow-jit` is macOS only. This is OS behaviour, not an App Review rule, so this doc does not attribute it to Guideline 2.5.2. Sideloading tools can enable JIT for enthusiasts. Gaga-Emu does not rely on them.

**App Review policy:**
- Guideline 4.7 says "retro game console and PC emulator apps can offer to download games" ([Apple guidelines](https://developer.apple.com/app-store/review/guidelines/)). The PC wording was added on 1 August 2024 ([MacRumors](https://www.macrumors.com/2024/08/01/app-store-review-guidelines-pc-emulator-apps/)).
- Apple defines no console generations and does not define "retro". Whether a given platform passes review is therefore a judgment by App Review, not a rule this project can compute.
- Guideline 4.7.2 is about exposing native platform APIs to the software an app offers. It is not a limit on which systems may be emulated.
- Guideline 2.5.2 covers apps downloading or executing code that adds or changes features. It is not a ban on GPU shader compilation. MoltenVK and SPIRV-Cross translate GPU shaders at runtime in S3 and S4, and that is accepted for this project.

**Scope:** an explicit platform list replaces any generation rule. In-binary v1 and v1.x platforms are exactly:

Game Boy / Game Boy Color, Game Boy Advance, NES, SNES / Super Famicom, Genesis / Mega-CD, PlayStation 1, Nintendo DS, Saturn, Nintendo 64, PSP, Dreamcast, Nintendo 3DS (experimental), Arcade, DOS / Win9x. Java ME and Symbian are not in the binary: their spikes failed (`docs/07` 6.4 and 6.6).

- `docs/03` is canonical for the core behind each platform.
- PS3 and PS4 are external sister projects by owner scope. They are never catalog rows or frame producers.
- PS2 and GameCube/Wii (Dolphin) are non-shipping research and are not promised.
- Other systems on Manic's listing are backlog, not planned for v1. See `docs/02` section 3.

### 1.2 Existing iOS Options
1. **Delta**: supports NES, SNES, N64, GB/GBC, GBA and DS, plus Sega Genesis in beta ([README](https://raw.githubusercontent.com/rileytestut/Delta/main/README.md)). No PlayStation or PSP. **Ignited** was not reviewed for this doc.
2. **RetroArch iOS**: a large core catalog through libretro, with a desktop-oriented UI. libretro has no Metal context type, which limits renderer choices (see `docs/03`).
3. **Folium**: a 3DS/DS/GBA-focused player. Its performance was not measured for this doc (unverified). Using MoltenVK is not a flaw; GagaEmu uses it too.
4. **Manic EMU (reference app)**: an all-in-one emulator. Its dark UI, import hub and per-platform core list are seen in screenshots [S]. Its listing covers more systems than GagaEmu plans [L]. It also exposes a `JIT` settings row [S], which GagaEmu deliberately drops.

### 1.3 Sister Projects
Gaga-Emu reuses interpreter patterns and the MoltenVK-on-`CAMetalLayer` pattern from local sibling repositories. They are not part of the Gaga-Emu binary.
- **`balero-s2` (PlayStation 2)**: non-shipping research. Not promised in Gaga-Emu.
- **`samba-s3` (PlayStation 3) and `bachata-s4` (PlayStation 4)**: external by owner scope. S3 and S4 carry their own App Store pipelines.
- **`gaga-emu`**: the multi-core app for the platforms listed in section 1.1, using a unified C-ABI bridge.

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         Gaga-Emu Unified Host (iOS)                         │
 │ SwiftUI 5.9+ / Combine / StoreKit 2 / GameController / AVFoundation / Metal │
 └──────────────────────────────────────┬──────────────────────────────────────┘
                                        │ Unified C-ABI Bridge (`GagaBridge.h`)
 ┌──────────────────────────────────────┴──────────────────────────────────────┐
 │                      Multi-Core Orchestration Layer                         │
 ├─────────────────────────┬─────────────────────────┬─────────────────────────┤
 │ Load tier 1             │ Load tier 2             │ Load tier 3             │
 │ • Gambatte              │ • bsnes / JGenesis      │ • Beetle Saturn         │
 │ • mGBA                  │ • melonDS DS            │ • Flycast JIT-less fork │
 │ • Nestopia              │ • Mupen64Plus-Next      │ • Azahar (experimental) │
 │ • PCSX-ReARMed          │ • PPSSPP / MAME         │                         │
 │                         │ • DOSBox Pure           │                         │
 └─────────────────────────┴────────────┬────────────┴─────────────────────────┘
                                        │ Core frames
 ┌──────────────────────────────────────┴──────────────────────────────────────┐
 │                      Metal Presentation and Rendering                       │
 │  App UI, frame presentation, post-process chain: native Metal               │
 │  2D and software cores: host texture ring, then Metal shader chain          │
 │  3D cores: Vulkan on statically linked MoltenVK to CAMetalLayer             │
 └─────────────────────────────────────────────────────────────────────────────┘
```

The diagram shows default cores by design; each is merged and builds (`docs/07`), and in release builds except the non-commercial cores (`docs/03` section 5). Tier is expected CPU load, not delivery order. `docs/03` is canonical for cores and alternates, and `docs/07` for scheduling. Java ME (J2meJS) and Symbian (EKA2L1) are excluded: J2meJS ships no corresponding source and EKA2L1 has no accepted renderer on iOS (`docs/07` 6.4 and 6.6).

---

## 2. Core Pillars & Design Constraints

All rows are design. Status is in `docs/07`.

| Pillar | Technical Implementation | Constraint |
| :--- | :--- | :--- |
| **No JIT** | Interpreter cores only, with no RWX and no dynarec. Interpreter design is in `docs/04`. | Each core build gets a no-JIT gate: an nm/strings check as in `S3/scripts/ios/build-core.sh:45-54`, plus a check for startup code generation. Audit per core, not only at the end. |
| **Metal Graphics** | Native Metal for UI, presentation and the post-process chain. 2D and software cores pass through the host texture ring. 3D cores use Vulkan on statically linked MoltenVK. A native Metal backend is allowed where upstream has one. | libretro cores memcpy unless a host-buffer API exists, so no zero-copy claim for them. GLES-only and desktop-GL-only renderers are not accepted. A14 required for layer-path 3D cores; 2D cores have no such floor (Apple7). Metal 4 is optional, never baseline. |
| **Multi-Core Flexibility** | C-ABI bridge (`GagaBridge`) with several selectable cores per platform where alternates exist, for example PCSX-ReARMed, Beetle PSX HW or SwanStation. | Selected per title through a library long-press, with a per-platform default. Each core is a dynamic, embedded framework that exports only the bridge (`docs/03` section 5). |
| **Manic EMU as Feature Reference** | Filter preview, ROM patching, multi-disc playlists, WiFi transfer and TriggerPro are features also seen in Manic's screenshots. Behaviour behind them is largely GagaEmu design. | Features only: the UI is not copied. Not 1:1 parity. Manic's `JIT` row is dropped, and many listed systems are not planned. `docs/02` tags each item by source. |
| **Original Landscape UI** | "Paper and ink", a quiet, print-like game shelf with a left rail. Spec in `docs/06` section 3. | Upright and landscape on iPhone and iPad. No other app's look is recreated. |
| **Apple Architecture** | Swift and SwiftUI for the app layer, C bridge headers, core code in its upstream languages, XcodeGen, StoreKit 2, an `AVAudioEngine` ring buffer. | UI knows nothing of core internals; it reaches them through C struct headers. |

**GPU support:** A14 required for layer-path 3D cores; 2D cores have no such floor. An iOS 17.0 minimum also admits devices older than A14, and `Sources/App/Info.plist` requires only `arm64` and `metal`. No code uses a Metal 3 API, so the app does not refuse those devices. `GPUFloor.supportsLayerPathCores` is the check future layer-path cores gate on (milestone 5.1).

**Memory entitlements:** `extended-virtual-addressing` is address space and `increased-memory-limit` is the RAM limit. Both must be added to entitlements and the App ID before Tier 3 cores.

**Licensing (engineering guidance, not legal advice):** snes9x, Genesis Plus GX, FBNeo and PicoDrive have non-commercial licences and are excluded from the App Store build. GPL cores in an App Store binary carry legal risk. Legal review is a required gate before the first GPL core ships, and the likely posture is publishing app source under a compatible licence. This is an open owner decision; counsel is needed. Details are in `docs/03`.

---

## 3. Reference Analysis: Manic EMU

Evidence is 14 screenshots in `maniac-emu-reference-images/` plus the [App Store listing](https://apps.apple.com/us/app/manic-emu/id6743335790) (ID `6743335790`). No screenshot shows a version number. The listing showed version 2.0.2 when checked on 2026-11-07.

1. **Core selection** [S]: the Emulator Core sheet maps each platform to its current core: J2meJS for Java ME (Manic only; GagaEmu has no Java ME core, `docs/07` 6.4), Beetle PSX HW for PlayStation, Beetle Saturn for Sega Saturn, JGenesis for Mega-CD, Azahar for Nintendo 3DS, melonDS DS for Nintendo DS, mGBA for Game Boy Advance, Gambatte for Game Boy and Game Boy Color, bsnes for Super Famicom. A caption says cores switch by long-pressing a game. No screenshot shows an alternate core. Version notes on the listing name more cores [L].
2. **Shaders** [S]: four tabs (Default, RetroArch, Import, Custom), one preview card with a per-row eye icon, and the presets Original, Cartoon, CRT v1, CRT v2, Geom CRT Border, Geom CRT and Film. Only the Default tab is shown.
3. **Import** [S]: Files, WiFi, Read Clipboard, MultiDisc Helper, RomPatcher and Drag & Drop. Files covers games, skins and game saves. M3U output and patch formats are not shown; those details are GagaEmu design [G].
4. **Input** [S]: a Controllers panel with a `Touch Control` row and a `Player 1` picker, plus `Assign Skin`, `Skin Sound Effects` and `TriggerPro` rows. The TriggerPro subtitle says only that it creates and manages advanced custom buttons. Controller brands, skin formats and macro or turbo behaviour are not shown; they are GagaEmu design [G].
5. **Adventurer card and membership** [S]: nickname, play time, joined date and a mascot image, with a membership banner. The paywall shows five items: a speed item (card clipped), `Unlimited Save States`, `Unlimited Cheat Codes`, `Premium Filters` and `Auto Save State`.

Gaga-Emu uses this as a feature reference only. Its UI is an original design (`docs/06` section 3), and it does not claim parity. The backend differs by design: no JIT in any shipped core, and Metal as described above.
