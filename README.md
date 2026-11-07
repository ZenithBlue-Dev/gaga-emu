# GagaEmu — All-in-One Multi-Model Emulator for iOS

Multi-system emulator for iOS and iPadOS, designed for App Store distribution with no JIT in any shipped core.

**Status: early. 35 real cores are merged and build, and 11 systems have run owner-supplied games on a device (iPhone 17) with benchmarks. Release builds ship no GPL core until the legal gate closes** (see [docs/07](./docs/07-roadmap-and-implementation-plan.md) and the device figures in [docs/04](./docs/04-no-jit-interpreter-architecture.md) section 7.1). The design uses no-JIT interpreter cores, Metal with MoltenVK for 3D cores, and an original, **landscape-only SwiftUI** interface. **Manic EMU** is a feature reference only; its UI is not copied and no feature parity is claimed.

---

## Core Pillars

1. **No-JIT Execution** (design):
   - iOS enforces W^X and offers no public JIT entitlement for App Store apps, so no shipped core uses JIT, RWX memory or a dynarec. Each core build gets a no-JIT gate. Guideline 4.7 covers "retro game console and PC emulator apps"; Apple defines no generations.
   - Third-party cores keep their upstream interpreters, built dynarec-free. No CPU-core rewrite is assumed.
   - `docs/04` also holds an in-house design: `[[clang::musttail]]` threaded dispatch, pre-decoded 16-byte ops, NEON lowering, and a cycle budget charged at block exit. It would be separately scheduled work, and none is scheduled.

2. **Metal Graphics Pipeline**:
   - App UI, frame presentation and the host post-process chain use native Metal. 3D cores use Vulkan on statically linked MoltenVK to `CAMetalLayer` (design), and a native Metal backend is allowed where upstream has one. GLES-only and desktop-GL-only renderers are not accepted.
   - GPU: A14 required for layer-path 3D cores; 2D cores have no such floor. Apple7 is the family, checked by `GPUFloor.supportsLayerPathCores`. iOS 17.0 also runs on A12 and A13, which can still run 2D cores.
   - 2D and software cores copy each frame into a triple-buffered shared `MTLBuffer` ring, with textures from `MTLBuffer.makeTexture(descriptor:offset:bytesPerRow:)`. The copy path is not zero copy; only the planned host-buffer path may be described that way.
   - Built-in MSL presets with live preview (Original, Cartoon, CRT v1, CRT v2, Geom CRT Border, Geom CRT, Film). They run on core frames in a game session.
   - Built: community Slang presets converted offline, runtime `.metal` import, `.slangp` import (translated to MSL at import), and saved filter presets (`.slangp` and saved presets are device pending).

3. **Multi-Core Flexibility per Platform** (design):
   - Defaults and alternates come from `docs/03`, for example GBA: mGBA (gpSP is a registry stub only); SNES: bsnes, with bsnes-jg and bsnes-mercury; PS1: PCSX-ReARMed, with Beetle PSX HW; 3DS: Azahar (experimental). Some platforms have no usable alternate yet.
   - Selected per game through a library long-press, with a per-platform default.
   - Compile-time core registry. Packaging is one dynamic, embedded framework per core, exporting only the bridge. Code is never loaded from user paths or downloaded.

4. **Original Landscape UI** (`docs/06` section 3): "Paper and ink", a quiet game shelf with a left rail, in landscape only on iPhone and iPad.

5. **Manic EMU as a Feature Reference** (no parity claim and no copied UI; `docs/02` tags each item by source and status):
   - Import tools: Files and iCloud, WiFi browser upload (PIN-protected, off by default), tap-only Read Clipboard, Multi-Disc M3U helper, and an in-memory ROM patcher (IPS, including RLE records, plus BPS and UPS).
   - Input: MFi, DualShock 4, DualSense, Xbox, Joy-Con, touch skins (`.deltaskin` and flex), and TriggerPro turbo, hold and combo. Built. Touch has driven games on a device in the UI walk; a real hardware controller or keyboard has not been run in a test.
   - Scope is an explicit platform list in `docs/03`. PS3 (`samba-s3`) and PS4 (`bachata-s4`) are external sister projects, never catalog rows or frame producers. PS2 (`balero-s2`) and GameCube/Wii are non-shipping research and are not promised.

---

## Building

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen). From a clean checkout:

```bash
git submodule update --init
scripts/build-core.sh          # writes build/cores/<Framework>.xcframework per core, runs the no-JIT gate
scripts/generate-project.sh    # runs xcodegen with the core set; GAGA_CORE_SET="mgba" links only mGBA
xcodebuild build -project GagaEmu.xcodeproj -scheme GagaEmu \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

Run `xcodebuild test` with the same arguments for the tests. For a device build without signing, use `-destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. A build fails if a core fails the no-JIT gate (`docs/04` section 8). Build outputs and the generated project are not committed. `docs/06` section 2.5 has the recipe for adding a core.

**Source for bundled code.** mGBA is MPL-2.0: [github.com/mgba-emu/mgba](https://github.com/mgba-emu/mgba), tag 0.10.5, commit `26b7884bc25a5933960f3cdcd98bac1ae14d42e2`, unmodified, at `Cores/mgba/upstream`. `docs/03` section 5 lists the licences it brings. Gambatte is GPL-2.0: [github.com/libretro/gambatte-libretro](https://github.com/libretro/gambatte-libretro), commit `77f2567d718b8973d02caa2daa8dce4953faf811`, unmodified, at `Cores/gambatte/upstream`. Nestopia UE is GPL-2.0-or-later: [github.com/libretro/nestopia](https://github.com/libretro/nestopia), commit `f1e02d12664834536edbf7352995a3d0cd1caef4`, unmodified, at `Cores/nestopia/upstream`. PCSX-ReARMed is GPL-2.0-or-later: [github.com/libretro/pcsx_rearmed](https://github.com/libretro/pcsx_rearmed), commit `7b0e8f8fadfbce3d170d195b9d9eecaabfa08c8e`, unmodified, at `Cores/pcsx_rearmed/upstream`. bsnes is GPL-3.0-or-later: [github.com/libretro/bsnes-libretro](https://github.com/libretro/bsnes-libretro), commit `b51612a74c4ff4b91aa55eb094940d9d848e0e96`, unmodified, at `Cores/bsnes/upstream`. melonDS DS is GPL-3.0-or-later: [github.com/JesseTG/melonds-ds](https://github.com/JesseTG/melonds-ds), tag v1.4.0, commit `f394adbacb5722ee97c1b37c8064da9a25818310`, unmodified, at `Cores/melonds_ds/upstream`, with its dependencies as pinned submodules in `Cores/melonds_ds/deps`. No GPL core is in release builds until the legal gate in `docs/07` milestone 4.0 closes.

**Test ROM.** No commercial game, Nintendo or Sony material is involved. `scripts/make-test-rom.sh <out.gba|out.gb|out.gbc|out.nes|out.sfc|out.nds|out.exe|out.cue>` writes a small homebrew ROM or PS1 program from `Sources/Debug/GBATestROM.swift`, `GBTestROM.swift`, `NESTestROM.swift`, `SNESTestROM.swift`, `NDSTestROM.swift` or `PS1TestEXE.swift`; the tests generate their own.

**Benchmark.** In a Debug build, use Settings > About > Run Benchmark, or launch with `-GagaBenchmark` (add `-GagaBenchmarkCore gambatte` for another core). The record lands in Documents/Benchmarks, which the Files app shows. `docs/04` section 7.2 has the procedure. A Debug build launched with `-GagaImportROM <path>` adds that file to the Library as Files import does, once.

---

## Technical Documentation Index

Detailed engineering specifications located in [`docs/`](./docs/):

- [**01 — Problem Statement & Executive Summary**](./docs/01-problem-statement-and-executive-summary.md): OS and App Review constraints, existing iOS options, reference analysis of Manic EMU, and sister projects (`balero-s2`, `samba-s3`, `bachata-s4`).
- [**02 — Feature Set & Manic EMU Reference**](./docs/02-feature-set-and-manic-emu-parity.md): Feature inventory checked against the 14 reference screenshots, tagged by source and status, with no parity claim.
- [**03 — Core Matrix & Platform Catalog**](./docs/03-core-matrix-and-platform-catalog.md): Canonical core list, alternates, licences, renderer paths, and the legal and no-JIT gates.
- [**04 — No-JIT Interpreter Architecture & Execution Engine**](./docs/04-no-jit-interpreter-architecture.md): iOS execution constraints, sister-project evidence, ranked optimisations, in-house interpreter design, performance tiers (target, unmeasured), benchmark method, and the per-core gate.
- [**05 — Metal Graphics Pipeline & Shader Subsystem**](./docs/05-metal-graphics-pipeline-and-shaders.md): Graphics rules, GPU floor, frame paths, shader picker, presets and multi-pass chain, runtime shader policy and `.metal` import, and shader licences.
- [**06 — iOS App Architecture, C-Bridge & Subsystem Specification**](./docs/06-ios-app-bridge-and-subsystem-spec.md): `GagaBridge.h` interface and planned additions, the UI design and screen specifications, the canonical premium and in-app purchase spec, and the XcodeGen project manifest.
- [**07 — Roadmap & Implementation Plan**](./docs/07-roadmap-and-implementation-plan.md): Phases 0 to 8, status, milestones, and the definition of done for a core.
