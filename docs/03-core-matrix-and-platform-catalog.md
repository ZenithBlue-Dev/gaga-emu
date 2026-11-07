# 03 — Core Matrix & Platform Catalog

This document is canonical for the GagaEmu core list, licences and renderer paths. Other docs reference it and do not fork the table. `docs/04` owns interpreter design and performance tiers, `docs/06` owns the bridge API, and `docs/07` owns phases and status.

**Status: planned.** The app today is a shell plus a mock core. The 11 non-mock cores in `Sources/Bridge/GagaCoreRegistry.c` are stubs, and no emulator core in this document is integrated. The tables below are design, not current state.

**Sources.** Upstream state and licences were checked on 2026-11-07. Manic EMU facts are marked by source: "seen in screenshot", "App Store listing", "public repo", or "release notes". Licensing text is engineering guidance, not legal advice.

---

## 1. Scope

The App Store binary contains exactly the platforms in the master matrix. There is no rule based on console generation.

- Guideline 4.7 covers "retro game console and PC emulator apps". Apple defines no generations and does not define "retro". [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Guideline 4.7.2 is about exposing native platform APIs. It is not a rule about which systems may be emulated.
- JIT denial comes from OS enforcement (W^X, no public iOS entitlement), not from a guideline. See `docs/04`.
- PS3 and PS4 are never catalog rows or frame producers (section 7).
- GameCube, Wii and PS2 are non-shipping research and are not promised (section 6).

**GPU support:** A14 required for layer-path 3D cores; 2D cores have no such floor. A14 (Apple7) is the first chip listed with Metal 3. Metal 4 is optional and never the baseline. [Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf) The deployment target stays iOS 17.0 (`project.yml:5`). `GPUFloor.supportsLayerPathCores` in `Sources/Metal/MetalRenderer.swift` is the check layer-path cores gate on (milestone 5.1).

---

## 2. Master Matrix

One row per platform. Licence, renderer, no-JIT status and upstream state describe the GagaEmu default; section 3 covers alternates. Load tier is expected CPU load, not delivery order. Tier meanings are in `docs/04`, and phases in `docs/07` may schedule differently.

"Unverified" means no source was found that settles the question. Every core must still pass the no-JIT gate (section 5), including those marked confirmed.

| Platform | GagaEmu default | Manic default (screenshot) | Alternates | Licence | Renderer path | No-JIT status | Upstream state | Load tier |
|---|---|---|---|---|---|---|---|---|
| Game Boy / GBC | Gambatte | Gambatte | SameBoy, Gearboy | [GPL-2.0](https://github.com/libretro/gambatte-libretro) (source headers say version 2, with no "or later"), plus MIT parts (section 5) | Software | Static gate passes on both slices, runtime check passes on the Simulator; device pending. Built on branch `core/gambatte`, legal gate open | Active, last push 2026-10-30. No release tags; pinned to master commit `77f2567d718b8973d02caa2daa8dce4953faf811` | 1 |
| GBA | mGBA | mGBA | VBA-M, gpSP (interpreter) | [MPL-2.0](https://github.com/mgba-emu/mgba), plus a BSD-3-Clause part (section 5) | Software | Static gate passes on both slices, runtime check passes on the Simulator; device pending | Active, last push 2026-11-06. Pinned to tag 0.10.5, `26b7884bc25a5933960f3cdcd98bac1ae14d42e2` | 1 |
| NES | Nestopia UE | Not seen | FCEUMM, QuickNES | [GPL-2.0-or-later](https://github.com/libretro/nestopia) (source headers say "version 2 of the License, or (at your option) any later version"), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | Static gate passes on both slices, runtime check passes on the Simulator; device pending. Built on branch `core/nestopia`, legal gate open | Active, last push 2026-10-31 ([libretro/nestopia](https://github.com/libretro/nestopia), the libretro port of [0ldsk00l/nestopia](https://github.com/0ldsk00l/nestopia)). No release tags; pinned to master commit `f1e02d12664834536edbf7352995a3d0cd1caef4` | 1 |
| SNES / Super Famicom | bsnes | bsnes | bsnes-jg, bsnes-mercury | [GPL-3.0-or-later](https://raw.githubusercontent.com/bsnes-emu/bsnes/master/LICENSE.txt), plus ISC, Expat, MIT and public-domain parts (section 5) | Software | Static gate passes on both slices, runtime check passes on the Simulator; device pending. Upstream libco's `mprotect` path is replaced (section 5). Built on branch `core/bsnes`, legal gate open | Active, last push 2026-11-06 ([libretro fork](https://github.com/libretro/bsnes-libretro), a GitHub fork of bsnes-emu/bsnes and the repository libretro-super builds). No release tag at that point; pinned to master commit `b51612a74c4ff4b91aa55eb094940d9d848e0e96` | 2 |
| Genesis / Mega-CD | JGenesis (self-maintained iOS port) | JGenesis (Mega-CD row) | ClownMDEmu | [GPL-3.0](https://raw.githubusercontent.com/jsgroth/jgenesis/master/README.md), plus MIT, Apache-2.0, BSD-3-Clause, Zlib and Unlicense crates (section 5) | Software. GagaEmu's own Rust shim over upstream's emulation crates; no wgpu, SDL or egui is compiled | Static gate passes on both slices; runtime check passes on the device. The resolved crate graph has no cranelift, dynasm or wasmtime crate. Merged from branch `core/jgenesis`, legal gate open | Active, last push 2026-11-06. Linux, Windows and web are official; iOS is not. Pinned to tag v0.14.1, `cbe7f129e3f5c805a2a2e4318981834192116e90` | 2 |
| PS1 | PCSX-ReARMed (`DYNAREC=0`) | Beetle PSX HW | Beetle PSX HW (software, or Vulkan via MoltenVK) | [GPL-2.0-or-later](https://github.com/libretro/pcsx_rearmed) (section 5) | Software (`BUILTIN_GPU = neon`, its C SIMD path) | Built at `7b0e8f8f` with `DRC_DISABLE` and no dynarec source; the no-JIT gate and the forbidden-source check pass on both slices. Upstream [`ios-arm64` sets `DYNAREC = 0`](https://raw.githubusercontent.com/libretro/pcsx_rearmed/master/Makefile.libretro) | Active, last push 2026-10-29 | 1 |
| DS | melonDS DS | melonDS DS | DeSmuME | [GPL-3.0-or-later](https://github.com/JesseTG/melonds-ds), plus MIT, BSD, LGPL-2.1, zlib, BSL-1.0, Unlicense and OFL parts (section 5) | Software only; the OpenGL renderer is not compiled | Static gate passes on both slices, on the binary and on its debug info; runtime check passes on the Simulator; device pending. Built on branch `core/melonds_ds`, legal gate open | Active, last push 2026-10-28. Pinned to tag v1.4.0, `f394adbacb5722ee97c1b37c8064da9a25818310` | 2 |
| Saturn | Beetle Saturn (interpreter, no `WANT_JIT`) | Beetle Saturn | None confirmed | [GPL-2.0-or-later](https://github.com/libretro/beetle-saturn-libretro) (section 5) | Software, threaded VDP2 renderer | Built at `30f4c120` (Mednafen SS 1.32.1) without `WANT_JIT`, so the SCU and SCSP DSP recompilers (arm64 `a64emit`, Linux only upstream) and the SH-2 recompiler (x86 only) are not compiled; the no-JIT gate and the forbidden-source check pass on both slices. Needs the player's own BIOS | Active, last push 2026-11-02 | 3 |
| N64 | Mupen64Plus-Next (ParaLLEl-RDP) | Not seen. Public repo: `mupen64plus.next` | parallel-n64 | [GPL-2.0](https://github.com/libretro/mupen64plus-libretro-nx) | Vulkan via MoltenVK. [ParaLLEl-RDP](https://raw.githubusercontent.com/Themaister/parallel-rdp/master/README.md) needs Vulkan 1.1 plus 8-bit and 16-bit storage; MoltenVK behaviour unverified | **Fails as configured upstream.** The CPU side is clean ([`WITH_DYNAREC=` empty on `ios-arm64`](https://raw.githubusercontent.com/libretro/mupen64plus-libretro-nx/develop/Makefile)), but `HAVE_PARALLEL_RSP = 1` [compiles `rsp_jit.cpp` and GNU Lightning](https://raw.githubusercontent.com/libretro/mupen64plus-libretro-nx/develop/Makefile.common). A non-JIT RSP is required (section 4) | Active, last push 2026-10-29 | 2 |
| PSP | PPSSPP (`IR_INTERPRETER`) | Not seen. Public repo: `ppsspp.libretro` | None | [GPL-2.0-or-later](https://raw.githubusercontent.com/hrydgard/ppsspp/master/README.md) | Native Metal on non-libretro builds ([`Common/GPU/Metal`](https://github.com/hrydgard/ppsspp/tree/master/Common/GPU/Metal); which release ships it is unverified), otherwise Vulkan via MoltenVK | Confirmed: [official post](https://www.ppsspp.org/news/live-on-app-store/) says the App Store build has no JIT and uses the IR interpreter | Active, last push 2026-11-06 | 2 |
| Dreamcast | Flycast JIT-less fork (fork to be named and maintained) | Not seen. Public repo: `flycast-jitless`; [App Store](https://apps.apple.com/us/app/manic-emu/id6743335790) 1.7.1 notes credit a Provenance developer | None | [GPL-2.0](https://github.com/flyinghead/flycast) | Vulkan via MoltenVK expected. Upstream lists Vulkan and OpenGL; the fork's renderer is unverified | Unverified for any fork we would adopt. [Reported](https://retrododo.com/ifly-testflight-spots-are-available-for-iphone-dreamcast-emulator/) as Flycast with the dynarec removed; fork source not located | Upstream active, but [dropped iOS support](https://raw.githubusercontent.com/flyinghead/flycast/master/README.md). GagaEmu would maintain the fork | 3 |
| 3DS | Azahar (experimental) | Azahar | None | [GPL-3.0](https://raw.githubusercontent.com/azahar-emu/azahar/master/LICENSE.txt) | Vulkan via MoltenVK ([README](https://raw.githubusercontent.com/azahar-emu/azahar/master/README.md): Vulkan 1.1 or GLES 3.2; GLES is not accepted), or software | Unverified end to end. Interpreter present (`arm/dyncom`). [`use_cpu_jit` and `use_shader_jit`](https://raw.githubusercontent.com/azahar-emu/azahar/master/src/common/settings.h) default to true and must be off and compiled out | Active, last push 2026-11-06. [CMake](https://raw.githubusercontent.com/azahar-emu/azahar/master/CMakeLists.txt) has an iOS path | 3 |
| Arcade | MAME (libretro fork, 28 machines) | Not seen. [Release notes](https://github.com/Manic-EMU/ManicEMU/releases): MAME in the App Store version | None | [GPL-2.0-or-later](https://www.mamedev.org/legal.html) as a whole, most files BSD-3-Clause, plus GPL-2.0+, LGPL-2.1+, CC0, MIT, zlib, IJG, BSL-1.0 and public-domain parts (section 5) | Software (libretro frame, `mame_alternate_renderer` off) | Static gate and the forbidden-source check pass on both slices: no DRC back end (not even `drcbe_c`), no asmjit, no `osdlib_retro.cpp`, no sockets, `dlopen` or `mprotect` imports. Merged from branch `core/mame` at bridge ABI 5, legal gate open | Active, last push 2026-11-07 ([libretro/mame](https://github.com/libretro/mame)). No tag for 0.289; pinned to master commit `5f5a07748ce5c239c4118463ce8e6473743d4859` | 2 |
| DOS / Win9x | DOSBox Pure (normal core) | Not seen. Public repo: `dosbox.pure` | DOSBox Staging, DOSBox-X | [GPL-2.0-or-later](https://codeberg.org/schelling/dosbox-pure), plus LGPL-2.1-or-later, BSD-3-Clause and MIT parts (section 5) | Software only; Voodoo runs in software and no OpenGL is linked | Built with `DISABLE_DYNAREC` and without `core_dyn_x86` or `core_dynrec`: the no-JIT gate and the forbidden-source check pass on both slices, and the dSYM lists the interpreter sources only. Merged from branch `core/dosbox_pure`, legal gate open | Active. Moved by its author from GitHub to Codeberg in October 2026 (section 5). Pinned to tag 1.0-preview7, `cdaea10ce8cac231bc341ca05d4c5e4e5fe0fbd5` | 2 |
| Java ME | J2meJS | J2meJS | None | Unknown; upstream not identified | Unverified | **Unverified: spike required.** JS runtime path unknown (section 4) | Unknown | 2 |
| Symbian | EKA2L1 | Not seen. [Release notes](https://github.com/Manic-EMU/ManicEMU/releases) list JIT modes for it | None | [GPL-3.0](https://github.com/EKA2L1/EKA2L1) | **Port needed.** [iOS path links OpenGLES.framework](https://raw.githubusercontent.com/EKA2L1/EKA2L1/master/src/emu/drivers/CMakeLists.txt), which is not an accepted path. A Vulkan backend file exists; completeness unverified | **Unverified: spike required.** [dyncom interpreter is in the tree](https://raw.githubusercontent.com/EKA2L1/EKA2L1/master/src/emu/cpu/CMakeLists.txt); a full no-JIT run is unproven | Active, last push 2026-11-06. README calls development a part-time hobby | 3 |

### Renderer rules

- **App UI, frame presentation and post-processing:** native Metal.
- **Software-rendered cores:** the core frame goes through the host texture ring and Metal shader chain. libretro cores copy frames unless a host-buffer API exists, so zero copy is not claimed for them.
- **3D cores:** Vulkan on statically linked MoltenVK to `CAMetalLayer`, the pattern S3 and S4 use. MoltenVK counts as Metal for this project (owner decision, 2026-11-07). A native Metal backend is allowed where upstream has one.
- **GLES-only and desktop-GL-only renderers are not accepted.** Such a core needs a Vulkan, Metal or software renderer, or it is out.
- **libretro has no Metal context type.** [`retro_hw_context_type`](https://raw.githubusercontent.com/libretro/libretro-common/master/include/libretro.h) has OpenGL variants, Vulkan, Direct3D and RSX values, and no Metal value. PPSSPP's [native Metal backend is excluded from its libretro build](https://raw.githubusercontent.com/hrydgard/ppsspp/master/CMakeLists.txt).

---

## 3. Alternates

Alternates are GagaEmu design choices. Manic's alternates are outside the reference images: the screenshots show one core per platform. Where Manic ships a core, the source is its public repo or release notes.

| Platform | Alternate | Licence | Renderer path | No-JIT status | Upstream state |
|---|---|---|---|---|---|
| GB / GBC | SameBoy | [Expat](https://raw.githubusercontent.com/LIJI32/SameBoy/master/LICENSE). The upstream `iOS` directory needs written permission for App Store use; use the core only | Software | Unverified | Active, last push 2026-11-02 |
| GB / GBC | Gearboy | [GPL-3.0](https://github.com/drhelius/Gearboy) | Software | Unverified | Active, last push 2026-11-06 |
| GBA | VBA-M | [GPL-2.0](https://github.com/visualboyadvance-m/visualboyadvance-m) | Software | Unverified | Active, last push 2026-11-01 |
| GBA | gpSP (interpreter) | [GPL-2.0](https://github.com/libretro/gpsp) | Software | Unverified. [README](https://raw.githubusercontent.com/libretro/gpsp/master/README.md): dynarec is the fast path and the interpreter is "albeit slower". Its speed reputation does not apply here | Active, last push 2026-09-19 |
| NES | FCEUMM | [GPL-2.0](https://github.com/libretro/libretro-fceumm) | Software | Unverified | Active, last push 2026-11-02 |
| NES | QuickNES | [GPL-2.0](https://raw.githubusercontent.com/libretro/QuickNES_Core/master/LICENSE) | Software | Unverified | Unchecked |
| SNES | bsnes-jg | [GPL-3.0](https://raw.githubusercontent.com/libretro/bsnes-jg/master/COPYING) | Software | Unverified | Unchecked |
| SNES | bsnes-mercury | [GPL-3.0](https://raw.githubusercontent.com/libretro/bsnes-mercury/master/LICENSE) | Software | Unverified | Unchecked |
| Genesis / Mega-CD | ClownMDEmu | [AGPLv3](https://raw.githubusercontent.com/Clownacy/clownmdemu/master/README.md) | Software | Unverified | README states some standard features are unemulated. Last push unchecked |
| PS1 | Beetle PSX HW | [GPLv2](https://docs.libretro.com/library/beetle_psx_hw/) | Software, or Vulkan via MoltenVK. Docs list GL and Vulkan, up to 16x, and no Metal. The iOS Vulkan build config is unverified | Confirmed for the build config: [iOS stanza sets `HAVE_LIGHTREC = 0`](https://raw.githubusercontent.com/libretro/beetle-psx-libretro/master/Makefile). The "CPU Dynarec" option must stay disabled | Active, last push 2026-11-01 |
| DS | DeSmuME | [GPL-2.0](https://github.com/TASEmulators/desmume) | Software (its OpenGL renderer is not accepted) | Confirmed for the build config: [AArch64 builds the interpreter core](https://raw.githubusercontent.com/libretro/desmume/master/desmume/src/frontend/libretro/Makefile.libretro) | Active, last push 2026-11-06 |
| N64 | parallel-n64 | Unchecked | Vulkan via MoltenVK (ParaLLEl plugin, `HAVE_PARALLEL` off by default) | Unverified. [Makefile](https://raw.githubusercontent.com/libretro/parallel-n64/master/Makefile) has dynarec targets, and the same RSP question applies | Unchecked |
| DOS | DOSBox Staging | [GPL-2.0-or-later](https://raw.githubusercontent.com/dosbox-staging/dosbox-staging/main/LICENSE) | Port needed: standalone app, not a core | Unverified | Unchecked |
| DOS | DOSBox-X | [GPL-2.0](https://raw.githubusercontent.com/joncampbell123/dosbox-x/master/COPYING) | Port needed: standalone app, not a core | Unverified | Unchecked |

---

## 4. Platform Notes

Only sourced claims appear here. Expected performance is a target (unmeasured); `docs/04` owns tiers.

- **GBA (mGBA):** [README](https://raw.githubusercontent.com/mgba-emu/mgba/master/README.md) lists motion sensor and rumble cartridges, Boktai solar sensor, and Game Boy Camera and Printer.
- **GB (SameBoy):** ships open-source DMG and CGB boot ROMs, not official ones. [Printer emulation](https://sameboy.github.io/features/) is listed on its site.
- **SNES (bsnes):** [coprocessor firmware files are optional](https://docs.libretro.com/library/bsnes/). How each chip behaves without firmware is unverified. GagaEmu sets `bsnes_coprocessor_prefer_hle` and never asks for firmware, so Super Game Boy and BS-X games do not load. Only a homebrew LoROM test ROM has run.
- **N64:** ParaLLEl-RDP is [Vulkan compute](https://raw.githubusercontent.com/Themaister/parallel-rdp/master/README.md), not software rasterisation. GLideN64 is GLES on iOS and is not accepted. `HAVE_PARALLEL_RSP` must be off or its JIT removed. Whether an interpreter RSP can drive ParaLLEl-RDP at usable speed on iOS is an open spike, and the tier 2 rating depends on it.
- **DS (melonDS DS):** DSi camera support is ["planned, but has not yet been integrated"](https://raw.githubusercontent.com/JesseTG/melonds-ds/main/README.md). Do not promise it. Delta's author [reported melonDS at 100% speed on most newer devices](https://rileytestut.com/blog/2021/04/21/delta-1-3-ds-for-everyone) in 2021.
- **Arcade (MAME):** a ROM set is one zip or 7z named after the machine, and MAME checks the file names inside, not the zip's name alone. Only the 28 machines in `Cores/mame/drivers.flt` are compiled; any other set is refused at load. Clones, BIOS sets and software lists are not offered. No commercial set has been run.
- **3DS (Azahar):** the PICA200 shader path differs by stage.
  - Fragment shaders have a direct SPIR-V generator, [`spv_fs_shader_gen.cpp`](https://github.com/azahar-emu/azahar/tree/master/src/video_core/shader/generator). That file listing supports the fragment wording used here.
  - No SPIR-V vertex generator is in that directory. The vertex path appears to go through `glsl_shader_gen` and `glsl_shader_decompiler`. This is inferred from file names, not traced in code.
  - MoltenVK then translates SPIR-V to MSL at runtime, which the project accepts for GPU shaders.
  - `shader_jit_a64_compiler` is in the tree and must not ship.
- **PS1 (Beetle PSX HW):** PGXP is documented as "Parallel/Precision Geometry Transform Pipeline". Upscaling runs on the GL or Vulkan renderer, not directly on Metal.
- **PSP (PPSSPP):** the [CPU modes](https://raw.githubusercontent.com/hrydgard/ppsspp/master/Core/ConfigValues.h) are `CPUCore` values, not a build flag. Use `IR_INTERPRETER`, not the plain `INTERPRETER`. The developer states iOS devices are ["generally fast enough to run nearly all PSP games at full speed"](https://www.ppsspp.org/news/live-on-app-store/) without JIT. A native Metal build means integrating outside libretro.
- **Dreamcast:** tier 3 is deliberate. [Anecdotal reports](https://mjtsai.com/blog/?p=48998) describe struggling on iPhone 16 Pro and running well on M4 iPad. No benchmark was found. Provenance's JIT-free update was reported stuck in App Review in August 2025.
- **Java ME (J2meJS):** the name is seen in the screenshot, and release notes mention J2meJS. No upstream repo was identified. [mozilla/pluotsorbet](https://github.com/mozilla/pluotsorbet) (GPL-2.0, archived) is a possible origin only. The spike must establish the source, licence, JS runtime path (for example whether it runs in a web view), and whether that path uses any JIT that counts against the no-JIT rule.
- **Symbian (EKA2L1):** the spike must prove the dyncom interpreter runs games and that a Vulkan or software renderer exists. If either fails, the row is out under the renderer rules.

---

## 5. Licensing and Build Gates

### Legal gate (open owner decision)

GPL cores in an App Store binary carry legal risk. The FSF had [GNU Go removed](https://lwn.net/Articles/391423), and [VLC was pulled](https://www.macrumors.com/2010/10/31/last-chance-to-get-vlc-for-iphone-ipad-likely-to-be-pulled-from-app-store/) over the same conflict. Nearly every row above is GPL.

- Legal review is a required gate before the first GPL core ships.
- The likely posture is publishing the app source under a compatible licence. [Manic](https://github.com/Manic-EMU/ManicEMU) and [Delta](https://github.com/rileytestut/Delta) publish app source under AGPL-3.0.
- The mix of GPL-2.0 (Gambatte's headers say version 2, with no "or later"), GPL-3.0 and AGPLv3 needs a compatibility check. This review could not read the FSF compatibility matrix. A GPL-2.0-only part is commonly read as not combinable with GPL-3.0 code, which matters for an app that would carry both Gambatte and a GPL-3.0 core. bsnes and melonDS DS (both GPL-3.0-or-later) are such cores: `core/bsnes` and `core/melonds_ds` build them into the same app as Gambatte. Neither has a GPL-2.0-only part inside its own framework. Nestopia is GPL-2.0-or-later, and PCSX-ReARMed's headers say "version 2 or later", so neither adds to that conflict. MAME is GPL-2.0-or-later as a whole (mamedev.org), but its repository's `COPYING` is the GPL-2.0 text with no "or later" line: counsel to confirm which governs (MAME licence obligations below).
- Until this gate closes, release builds use `GAGA_CORE_SET=mgba` (`docs/06` section 2.5), so no GPL code ships.
- Owner decision, needs counsel: bsnes compiles upstream's 64-byte SPC700 IPL boot ROM (Nintendo code, in `bsnes/target-libretro/resources.hpp`). bsnes has no HLE for it and no free replacement was found (bsnes licence obligations below).
- Owner decision, needs counsel: GPL-2.0-only Gambatte and the GPL-3.0-or-later cores bsnes and melonDS DS (`melonds_ds`) are built into one app binary. If they cannot be combined, Gambatte or those cores must leave the release core set or be replaced.
- The same question covers JGenesis (`jgenesis`), whose README grants GPL-3.0 with no "or later" wording, so it is read as GPL-3.0-only. It also links one Apache-2.0-only crate (`claxon`), which GPL-3.0 accepts and GPL-2.0 does not.
- This is an open owner decision. Counsel is needed.

### Linking

**Recommendation: build each core as a dynamic, embedded framework that exports only the bridge.** S3 does this:

- `S3/ios/SambaS3/project-core.yml:11-12` embeds `SambaCore.xcframework` with `embed: true`.
- `rpcsx/ios/CMakeLists.txt:75` declares `add_library(SambaCore SHARED ...)`, and `:82` restricts exports with `-exported_symbols_list`.
- S4 follows the same shape (`S4/CMakeLists.txt:1684-1689`).

Reasons: several libretro cores in one image would collide on `retro_*` symbols, and an export list keeps each core's internals private. Frameworks are signed and shipped inside the app bundle. Code is never loaded from user paths or downloaded. `docs/06` section 2.5 owns the bridge details and matches this.

Dynamic linking does not change the GPL analysis above.

### mGBA licence obligations

Source: [github.com/mgba-emu/mgba](https://github.com/mgba-emu/mgba), tag 0.10.5, commit `26b7884bc25a5933960f3cdcd98bac1ae14d42e2`, as the unmodified submodule `Cores/mgba/upstream`. `Cores/mgba/MgbaCore.c` is GagaEmu's own file, combined with mGBA as a Larger Work (MPL-2.0 section 3.3).

The build compiles two licences, and each needs a place in the 7.5 notices:

| Part | Licence | What it asks of a binary release |
|---|---|---|
| mGBA, including its own HLE BIOS `src/gba/hle-bios.c` | MPL-2.0 | Tell recipients the source is available and where (section 3.2): the URL and commit above. Any change to an MPL file must be published under MPL-2.0. None is changed today. |
| `src/third-party/inih` | BSD-3-Clause | Reproduce its copyright notice and licence. |

`src/third-party/blip_buf` (LGPL-2.1) is no longer compiled. `Cores/mgba/blip.c`, GagaEmu's own 116-line band-limited resampler, implements the same functions, written from the contracts in the header and not from the library's source. The header, `include/mgba/core/blip_buf.h`, is still read at compile time, because mGBA's own files include it. It contributes declarations only, and `Cores/mgba/sources.txt` compiles no file from `third-party/blip_buf`. This engineering step removes the relinking question, but it is not legal advice: counsel should confirm the header's status when they look at the gate above.

Settings > About > Licences shows these notices for every linked core (milestone 7.5, `Licences/notices.json`). A new core or a changed pin needs its rows there, then `scripts/generate-licences.py`. No Nintendo BIOS or game is bundled.

### Gambatte licence obligations

Source: [github.com/libretro/gambatte-libretro](https://github.com/libretro/gambatte-libretro), the repository libretro-super builds from, at master commit `77f2567d718b8973d02caa2daa8dce4953faf811` (it has no release tags), as the unmodified submodule `Cores/gambatte/upstream`. `Cores/gambatte/GambatteCore.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files, linked with Gambatte into `GambatteCore.framework`. This is on branch `core/gambatte` only and must not ship until the legal gate above closes.

| Part | Licence | What it asks of a binary release |
|---|---|---|
| `libgambatte/src` (26 compiled files have a GPL header) | GPL-2.0, no "or later" | The complete corresponding source of the whole work, under GPL-2.0, with the written offer or the source alongside. This is the gate above. |
| `libgambatte/libretro-common` (14 files), `libgambatte/libretro/blipper.c` | MIT | Reproduce each copyright notice and the permission notice. |
| `libretro.cpp`, `gambatte_log.c`, `bootloader.cpp`, `cartridge_libretro.cpp`, `next_m0_time.cpp` | No header; the repository's `COPYING` is GPL-2.0 | Treat as GPL-2.0. |

`libgambatte/libretro/cc_resampler.c` says GPLv3 and is not compiled: `GambatteCore.c` defines `CC_init` and `CC_renderaudio` as empty functions. Upstream calls them only when `gambatte_audio_resampler` is `cc`, which GagaEmu never sets, or when allocating its default resampler fails, and then the game runs silent. Its header `cc_resampler.h` is still read at compile time, as `libretro.cpp` includes it. It contributes declarations only. Counsel should confirm this, as with mGBA's `blip_buf.h`.

`HAVE_NETWORK` is off, so the link-cable socket code is not compiled. The core's own Game Boy and Game Boy Color boot ROMs are not bundled: the `gambatte_gb_bootloader` option is off, so the core starts the game with its built-in post-boot register state and never reads a Nintendo file. The test ROM carries no Nintendo logo bytes; the core does not check them.

### Nestopia licence obligations

Source: [github.com/libretro/nestopia](https://github.com/libretro/nestopia), the repository libretro-super builds from, at master commit `f1e02d12664834536edbf7352995a3d0cd1caef4` (it has no release tags), as the unmodified submodule `Cores/nestopia/upstream`. `Cores/nestopia/NestopiaCore.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files, linked with Nestopia into `NestopiaCore.framework`. This is on branch `core/nestopia` only and must not ship until the legal gate above closes.

| Part | Licence | What it asks of a binary release |
|---|---|---|
| `source/core` (292 compiled files, each with a GPL header) | GPL-2.0-or-later | The complete corresponding source of the whole work, under GPL-2.0 or later, with the written offer or the source alongside. This is the gate above. |
| `source/nes_ntsc` (headers and `nes_ntsc.inl`, included by `NstVideoFilterNtsc*.cpp`) | LGPL-2.1-or-later | Reproduce the notice and give the source. Compatible with the GPL whole. The NTSC filter is compiled but off (`nestopia_blargg_ntsc_filter` is `disabled`). |
| `libretro/libretro-common` (11 compiled files) | MIT | Reproduce each copyright notice and the permission notice. |
| `libretro/libretro.cpp` and the headers it includes, `nesfont.h`, `nstdatabase.hpp` (the cartridge database, compiled in) and `palettes.hpp` | No header; the repository's `COPYING` is GPL-2.0 | Treat as GPL-2.0. |

No file outside these groups is compiled, and the build fetches nothing. `NST_NO_ZLIB` is upstream's own define: states are never compressed and no zlib is linked. The FDS disk BIOS (`disksys.rom`) is not bundled and `.fds` is not offered, so only cartridges run. `NstHomebrew.cpp` imports `exit` for an exit port that only the `Api::Homebrew` interface turns on, which `libretro.cpp` never calls. The test ROM is GagaEmu's own generated program (`Sources/Debug/NESTestROM.swift`).

### PCSX-ReARMed licence obligations

Source: [github.com/libretro/pcsx_rearmed](https://github.com/libretro/pcsx_rearmed), the repository libretro-super builds from, at master commit `7b0e8f8fadfbce3d170d195b9d9eecaabfa08c8e` (`git describe`: `r26l-137-g7b0e8f8f`), as the unmodified submodule `Cores/pcsx_rearmed/upstream`. `Cores/pcsx_rearmed/PcsxReArmedCore.c`, `nodrc.c`, `revision.h` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files, linked with it into `PcsxReArmedCore.framework`. This is on branch `core/pcsx_rearmed` only and must not ship until the legal gate above closes.

| Part (as in `Cores/pcsx_rearmed/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `libpcsxcore` (22 files), `plugins/dfsound` (4 files), `plugins/gpu_neon/psx_gpu/psx_gpu_simd.c`, and `psx_gpu.c`, `psx_gpu_parse.c` and `psx_gpu_4x.c`, which `psx_gpu_if.c` includes | GPL-2.0-or-later | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `frontend/libretro.c`, `main.c`, `plugin.c`, `cspace.c`, `plugins/gpulib/gpu.c`, `vout_pl.c`, `plugins/gpu_neon/psx_gpu_if.c` | GPLv2 or later (notaz's short header) | As above. |
| `libpcsxcore/database.c`, `psxevents.c`, `gte_nf.c`, `plugins/dfsound/out.c`, `nullsnd.c`, `plugins/gpulib/prim.c` | No header; the repository's `COPYING` is the GPL-2.0 text | Treat as GPL-2.0. |
| `libpcsxcore/gte_divider.c` (from MAME) | BSD-3-Clause | Reproduce its copyright notice and licence. |
| `deps/libchdr` (13 files) | BSD-3-Clause | Reproduce its copyright notice and licence. |
| `dr_flac.h`, compiled inside `libchdr_flac.c` | Public domain or MIT-0, at the user's choice | None. |
| `deps/libchdr/deps/lzma-26.02` (`LzmaDec.c`) | Public domain | None. |
| `deps/libchdr/deps/zstd-1.5.7` (`zstddeclib.c`) | BSD-3-Clause or GPL-2.0, at the user's choice | Take BSD: reproduce its notice. |
| `deps/libchdr/deps/miniz-3.1.2` (`miniz.c`) | MIT | Reproduce its notice. |
| `deps/libretro-common/include` (headers only, `libretro.h` and the file stream headers) | MIT | Reproduce its notice. |

No dynarec file is compiled: not `libpcsxcore/new_dynarec` (ari64), not `deps/lightrec`, not `deps/lightning`. `nodrc.c` defines the three symbols the interpreter path still names (`ndrc_g`, `ndrc_freeze`, `ndrc_clear_full`) as empty, so no upstream file is patched. The built-in HLE BIOS (`psxbios.c`) runs every game; `pcsx_rearmed_bios` is set to `HLE`, so the core never looks for a Sony BIOS, and none is bundled. The test program `Sources/Debug/PS1TestEXE.swift` is GagaEmu's own hand-assembled MIPS code with no Sony bytes.

### Beetle Saturn licence obligations

Source: [github.com/libretro/beetle-saturn-libretro](https://github.com/libretro/beetle-saturn-libretro) at master commit `30f4c12072d265c9e553dcb29386059114945dea` (Mednafen SS 1.32.1), as the unmodified submodule `Cores/beetle_saturn/upstream`. `Cores/beetle_saturn/BeetleSaturnCore.c`, `nojit.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files, linked with it into `BeetleSaturnCore.framework`. This is on branch `core/saturn` only and must not ship until the legal gate above closes.

| Part (as in `Cores/beetle_saturn/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `mednafen/ss`, `mednafen/cdrom` (with dvdisaster code by Carsten Gnoerlich), `mednafen/hw_cpu/m68k`, `mednafen/hash`, `mednafen/video`, state and glue files | GPL-2.0-or-later (repository `COPYING` is GPL-2.0) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `libretro.c`, `disc.c`, `input.c`, `libretro_settings.c`, `mednafen/vfs_hybrid.c` | No header; the repository licence applies | Treat as GPL-2.0-or-later. |
| `mednafen/hash/md5.c` (Christophe Devine) | GPL | As above. |
| `mednafen/tremor` | Xiph BSD-style (`mednafen/tremor/COPYING`) | Reproduce its notice. |
| `libretro-common` | MIT (RetroArch team) | Reproduce its notice. |
| `libretro-common/formats/flac/rflac.c` (dr_flac) | Public domain or MIT-0 | None; notice kept anyway. |
| `rmp3` (minimp3-derived) | No statement in the file; minimp3 upstream is CC0 | None known. Recheck before release. |
| `r7z_lzma.c` | MIT header, derived from the public-domain LZMA SDK | Reproduce its notice. |

No recompiler file is compiled: `sources.txt` drops every `*jit*` and `*emit*` file, and `nojit.c` copies upstream's own non-x86 SH-2 stubs (`SH2JIT_*`) so no upstream file is patched. No Sega BIOS is bundled or fetched. `BeetleSaturnCore.c` refuses a game with a message when neither `mpr-17933.bin` nor `sega_101.bin` (512 KiB) is in `GagaEmu/System`. The test ROM `Sources/Debug/SaturnTestBIOS.swift` is GagaEmu's own hand-assembled SH-2 code with no Sega bytes.

### bsnes licence obligations

Source: [github.com/libretro/bsnes-libretro](https://github.com/libretro/bsnes-libretro), the libretro fork that libretro-super builds (`recipes/apple/cores-ios-arm64-generic`, `target=libretro`), at master commit `b51612a74c4ff4b91aa55eb094940d9d848e0e96`, as the unmodified submodule `Cores/bsnes/upstream`. Only the libretro target is compiled: no GUI, Qt, hiro or ruby. `Cores/bsnes/BsnesCore.c`, `BsnesSupport.cpp`, `libco.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files, linked with bsnes into `BsnesCore.framework`. This is on branch `core/bsnes` only and must not ship until the legal gate above closes.

| Part | Licence | What it asks of a binary release |
|---|---|---|
| `bsnes/sfc`, `bsnes/processor`, `bsnes/emulator`, `bsnes/target-libretro/libretro.cpp` and `program.cpp`, and `bsnes/filter/none.cpp` (through `BsnesSupport.cpp`) | GPL-3.0-or-later (`LICENSE.txt`) | The complete corresponding source of the whole work, under GPL-3.0, with the written offer or the source alongside, and the installation information GPL-3.0 section 6 asks for. This is the gate above. |
| `nall` (headers, compiled into every unit) | ISC (`LICENSE.txt`, second part) | Reproduce the copyright notice and permission notice. |
| `bsnes/gb/Core` (15 files: SameBoy, needed because the Super Game Boy code references it) | Expat (`bsnes/gb/LICENSE`) | Reproduce the copyright notice and permission notice. |
| `bsnes/lzma` (Igor Pavlov's LZMA SDK files, included by `lzma.cpp`) | Public domain, as each file header says | Nothing. |
| `bsnes/target-libretro/libretro.h` | MIT | Reproduce the notice. |

Not compiled:

- `bsnes/filter/filter.cpp` bundles third-party scalers, among them blargg's `snes_ntsc` (LGPL-2.1). `BsnesSupport.cpp` draws the four NTSC options unfiltered, and `bsnes_video_filter` stays at None.
- Upstream `libco`: its `libco.c` forces the `mprotect` path under clang, which makes a data array executable. `Cores/bsnes/libco.c` is GagaEmu's own arm64 context switch with the same API, and the gate refuses `_mprotect`.

**The SPC700 IPL boot ROM is compiled in.** `bsnes/target-libretro/resources.hpp` holds the 64-byte IPL ROM of the console's sound chip, and the libretro target serves it as `ipl.rom`. bsnes has no HLE for it and no free replacement was found. It is Nintendo code inside a GPL file. This is an owner and counsel question before any release: it is the one piece of console firmware in the build. No coprocessor firmware, BIOS or game is bundled.

### melonDS DS licence obligations

Source: [github.com/JesseTG/melonds-ds](https://github.com/JesseTG/melonds-ds), the URL libretro-super's core rules build `melondsds` from, at tag v1.4.0, commit `f394adbacb5722ee97c1b37c8064da9a25818310`, as the unmodified submodule `Cores/melonds_ds/upstream`. Upstream's CMake fetches its dependencies at configure time. GagaEmu does not run that CMake: each dependency is an unmodified submodule in `Cores/melonds_ds/deps`, pinned to the ref upstream's `cmake/FetchDependencies.cmake` names at that tag, so a build after `git submodule update --init` needs no network. `scripts/build-core.sh` refuses to build if a submodule is not at its recorded commit. `Cores/melonds_ds/MelonDSCore.c`, `MelonDSAssets.c`, `MelonDSNet.cpp`, `include/` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. This is on branch `core/melonds_ds` only and must not ship until the legal gate above closes.

| Submodule | Commit | Compiled part | Licence | What it asks of a binary release |
|---|---|---|---|---|
| `upstream` (melonDS DS) | `f394adba` (v1.4.0) | `src/libretro` (49 files), `src/pntr/pntr.c`, the error-screen images and `wfc.cfg` | GPL-3.0-or-later (file headers and `LICENSE`) | Complete corresponding source of the whole work under GPL-3.0, with the offer or the source alongside. This is the gate above. |
| `upstream` assets | as above | `OpenSans-ExtraBold.ttf`, `OpenSans_Condensed-SemiBold.ttf`, embedded for the error screen | SIL OFL 1.1 (the fonts' own name table) | Ship the copyright notice and the OFL text; the fonts may not be sold alone. |
| `deps/melonDS` (JesseTG fork, branch `jtg/fix-uninitialized-opengl`) | `16f127db` | 46 top-level files of `src`, `net/Net.cpp`, `net/PacketDispatcher.cpp`, `NDSCart/` (8), `DSP_HLE/` (4) | GPL-3.0-or-later. `GPU3D_Texcache.cpp` has no header; the repository `LICENSE` is GPL-3.0 | As above. |
| `deps/melonDS` | as above | `FreeBIOS.cpp`, the built-in ARM7 and ARM9 BIOS replacement by Gilead Kutnick | BSD-style, two clauses (its header) | Reproduce the copyright notice, conditions and disclaimer. |
| `deps/melonDS` | as above | `src/teakra/src` (11 files) | MIT (`teakra/LICENSE`) | Reproduce the notice. |
| `deps/melonDS` | as above | `src/fatfs` | FatFs licence, BSD-style one clause (ChaN), and MIT for melonDS's glue | Reproduce the notice. |
| `deps/melonDS` | as above | `src/blip-buf/blip_buf.c` | LGPL-2.1-or-later | Within a GPL-3.0 work this is satisfied by the GPL source release; counsel to confirm. |
| `deps/melonDS` | as above | `src/xxhash`, `src/sha1`, `src/tiny-AES-c` | BSD-2-Clause, public domain, Unlicense | Reproduce the xxHash notice. |
| `deps/libretro-common` | `fa8a1b57` | 60 files from upstream's `libretro-common.cmake` list, without the network, zlib and dylib files and `memmap/memmap.c` (it calls `mprotect` with `PROT_EXEC`, and nothing uses it) | MIT; `encodings/encoding_crc32.c` zlib | Reproduce the notices. |
| `deps/fmt` | `1be298e1` (12.2.0) | `src/format.cc` | MIT | Reproduce the notice. |
| `deps/glm` | `6f14f479` | headers | MIT (or the Happy Bunny licence) | Reproduce the notice. |
| `deps/pntr` | `a47fe167` | headers, through `upstream/src/pntr/pntr.c` | zlib | No notice required in a binary; keep it in the source. |
| `deps/yamc` | `4e015a7e` | headers | MIT | Reproduce the notice. |
| `deps/span-lite` | `f63fe297` | headers | BSL-1.0 | None for a binary. |
| `deps/date` | `179a6b92` (v3.0.5) | headers | MIT | Reproduce the notice. |

Not fetched and not compiled: libslirp and the pcap driver (networking is off; `MelonDSNet.cpp` replaces upstream's `net/net.cpp`, which always links slirp), zlib (`ENABLE_ZLIB` off), tracy, and embed-binaries (`MelonDSAssets.c` embeds the five assets with `.incbin`). Not compiled from the fetched trees: melonDS's `ARMJIT*`, `ARMJIT_A64/`, `ARMJIT_x64/`, `dolphin/`, `GPU_OpenGL*`, `GPU3D_OpenGL*`, `GPU3D_Compute*`, `OpenGLSupport`, `GDBStub`, `Net_Slirp` and `Net_PCap`, and melonDS DS's `render/opengl.cpp` and `tracy/`.

No GPL-2.0-only file is compiled into this framework, so there is no GPL-2.0-only against GPL-3.0 conflict inside it. The conflict with Gambatte in the same app is the gate above.

No Nintendo BIOS or firmware is read or bundled: `melonds_sysfile_mode` is `builtin`, so melonDS uses FreeBIOS and its generated firmware and boots the game directly. That mode cannot boot an encrypted retail dump, which needs Nintendo's BIOS: melonDS DS shows its own error screen for one. The test ROM carries no Nintendo logo bytes.

### JGenesis licence obligations

Source: [github.com/jsgroth/jgenesis](https://github.com/jsgroth/jgenesis), the author's own repository, at tag v0.14.1, commit `cbe7f129e3f5c805a2a2e4318981834192116e90`, as the unmodified submodule `Cores/jgenesis/upstream`. Upstream is Rust and has no libretro core, so `Cores/jgenesis/shim` is GagaEmu's own crate (`jgenesis-gaga`, GPL-3.0-only) over upstream's emulation crates, and `Cores/jgenesis/JgenesisCore.c` is GagaEmu's own interface table. `scripts/build-core.sh` builds the shim with `cargo build --release --locked` into a static library; `shim/Cargo.lock` pins every crate. Upstream's frontends, wgpu, SDL, egui and its own build scripts are never compiled or run. It is merged from branch `core/jgenesis`, kept out of release builds by `GAGA_CORE_SET`, and must not ship until the legal gate above closes.

The list below is every crate `cargo metadata --locked --filter-platform aarch64-apple-ios` resolves into the library at this pin (77 crates), from each crate's own `license` field. The upstream crates have no `license` field; the repository `LICENSE` is GPL-3.0 and the README says all code is GPL-3.0 unless a file says otherwise. No compiled upstream file says otherwise.

| Crates linked into `JgenesisCore.framework` | Licence | What it asks of a binary release |
|---|---|---|
| Upstream: `genesis-core`, `genesis-components`, `genesis-config`, `segacd-core`, `s32x-core`, `m68000-emu`, `z80-emu`, `sh2-emu`, `ti-sn76489`, `cdrom`, `dsp`, `jgenesis-common` (all 0.14.1); GagaEmu's `jgenesis-gaga` | GPL-3.0 (no "or later" grant found) | Complete corresponding source of the whole work under GPL-3.0, with the offer or the source alongside, and the installation information of section 6. This is the gate above. |
| `chd` 0.3.4 | BSD-3-Clause | Reproduce the copyright notice, conditions and disclaimer. |
| `zstd-sys` 2.0.16 (MIT or Apache-2.0), which compiles the bundled zstd 1.5.7 C library | zstd C code: BSD-3-Clause, or GPL-2.0 at the user's choice (its `LICENSE` and `COPYING`); BSD is the choice here | Reproduce the zstd BSD notice. |
| `claxon` 0.4.3 | Apache-2.0 | Ship the Apache-2.0 text and any `NOTICE`. Compatible with GPL-3.0, not with GPL-2.0. |
| `zlib-rs` 0.6.3 | Zlib | No notice required in a binary. |
| `bincode` 2.0.1, `lzma-rs-perf-exp` 0.2.1, `macro_rules_attribute` 0.1.3, `ruzstd` 0.8.3, `twox-hash` 2.1.2, `winnow` 1.0.3 | MIT | Reproduce the notice. |
| `aho-corasick` 1.1.4, `byteorder` 1.5.0, `memchr` 2.8.2 | Unlicense or MIT | None under Unlicense. |
| `bytemuck` 1.25.0, `ext-trait` 1.0.1, `extension-traits` 1.0.1, `lending-iterator` 0.1.7, `never-say-never` 6.6.666, `nougat` 0.2.4, `polonius-the-crab` 0.2.1 | Zlib or Apache-2.0 or MIT | None under Zlib. |
| `arrayvec` 0.7.6, `bitreader` 0.3.11, `cfg-if` 1.0.4, `chacha20` 0.10.0, `crc` 3.4.0, `crc-catalog` 2.5.0, `deranged` 0.5.8, `equivalent` 1.0.2, `flate2` 1.1.9, `getrandom` 0.4.3, `hashbrown` 0.17.1, `indexmap` 2.14.0, `libc` 0.2.186, `log` 0.4.33, `multiversion` 0.8.0, `num` 0.4.3, `num-bigint` 0.4.6, `num-complex` 0.4.6, `num-conv` 0.2.2, `num-integer` 0.1.46, `num-iter` 0.1.45, `num-rational` 0.4.2, `num-traits` 0.2.19, `powerfmt` 0.2.0, `rand` 0.10.1, `rand_core` 0.10.1, `regex` 1.13.1, `regex-automata` 0.4.16, `regex-syntax` 0.8.11, `rustc-hash` 2.1.2, `serde` 1.0.228, `serde_core` 1.0.228, `serde_spanned` 1.1.1, `target-features` 0.1.6, `text_io` 0.1.13, `thiserror` 2.0.18, `time` 0.3.49, `time-core` 0.1.9, `toml` 1.1.2, `toml_datetime` 1.1.1, `toml_parser` 1.1.2, `toml_writer` 1.1.1, `unty` 0.0.4, `zstd-safe` 7.2.4 | MIT or Apache-2.0 | Reproduce the MIT notice. |
| Rust standard library (rustc 1.99.1, `std`, `core`, `alloc`, `panic_unwind`) | MIT or Apache-2.0 | Reproduce the MIT notice. |

Run at build time only, never linked (proc macros and build scripts, 24 crates): `autocfg`, `bincode_derive`, `bytemuck_derive`, `cc`, `ext-trait-proc_macros`, `find-msvc-tools`, `jgenesis-proc-macros`, `jobserver`, `lending-iterator-proc_macros`, `macro_rules_attribute-proc_macro`, `multiversion-macros`, `nougat-proc_macros`, `num-derive`, `paste`, `pkg-config`, `proc-macro2`, `quote`, `serde_derive`, `shlex`, `syn` 1 and 2, `thiserror-impl`, `unicode-ident` and `virtue`. Each is MIT, Apache-2.0 or Zlib under its own field; `unicode-ident` adds Unicode-3.0. They are not in the binary, so they ask nothing of a release. Cargo fetches the crates once from crates.io; later builds are offline.

The 32X crates (`s32x-core`, `sh2-emu`) are linked because `genesis-core` depends on them; GagaEmu does not offer 32X games.

No Sega BIOS or TMSS ROM is bundled. A Genesis cartridge needs none. A Mega-CD disc needs the player's own BIOS: the shim looks in the core's `system_dir` (`Application Support/GagaEmu/System`) for `bios_CD_U.bin`, `bios_CD_E.bin` or `bios_CD_J.bin`, the disc's region first, and without one refuses the disc with "This Mega-CD game needs a Mega-CD BIOS file (bios_CD_U.bin, bios_CD_E.bin or bios_CD_J.bin). GagaEmu does not include one." The test ROM (`Sources/Debug/MDTestROM.swift`) is GagaEmu's own 68000 code with no Sega bytes.

### MoltenVK and layer-path licence obligations

Source: [github.com/KhronosGroup/MoltenVK](https://github.com/KhronosGroup/MoltenVK), tag v1.4.2, commit `db66022459ffb663aa2b50f6b018bc2e124f5edf`. `scripts/build-moltenvk.sh` clones it into `build/moltenvk-src`, runs MoltenVK's own `fetchDependencies --ios --iossim`, which checks out each dependency at the commit the tag records in `ExternalRevisions/`, and builds the static `MoltenVK.xcframework` (`ios-arm64` and `ios-arm64_x86_64-simulator`). SPIRV-Tools uses MoltenVK's pregenerated headers, so no CMake configure runs. Nothing built is committed. Every layer-path core links `libMoltenVK.a` into its own framework (`CORE_USES_MOLTENVK=1`), so each such framework carries all of the rows below. The script copies each licence to `build/moltenvk/licenses`.

| Part | Commit | Compiled part | Licence | What it asks of a binary release |
|---|---|---|---|---|
| MoltenVK | `db660224` (v1.4.2) | `MoltenVK/`, `MoltenVKShaderConverter/`, `Common/` | Apache-2.0 | Ship the licence text and any NOTICE; state changes (none). |
| SPIRV-Cross | `6c09849f` | MSL, GLSL and reflection back ends | Apache-2.0 (some files Apache-2.0 OR MIT) | Ship the licence text. |
| SPIRV-Tools | `0d6fd73c` | optimiser and validator, built in MoltenVK's `ExternalDependencies` project | Apache-2.0 | Ship the licence text. |
| cereal | `a56bad8b` | headers (pipeline cache serialisation) | BSD-3-Clause | Reproduce the notice. |
| Vulkan-Headers | `e3b1eec0` | headers | Apache-2.0 OR MIT | Ship either licence text. |
| SPIRV-Headers | `29981f65` | headers | MIT (KhronosFreeUse) | Reproduce the notice. |

Fetched and not compiled: Vulkan-Tools (`8c66b352`) and volk (`77689330`), which only MoltenVK's Cube demo uses. None of these licences conflicts with the GPL cores, and the Vulkan test core `vktest` (`Cores/vktest`, written in this repository, debug and test builds only) has no upstream. MoltenVK translates SPIR-V to MSL and Metal compiles it into an `MTLLibrary` for the GPU at run time; no CPU code is generated, and the no-JIT gate passes on both slices. compiler-rt's `@available` support, linked with MoltenVK, imports `_dlsym` to read the OS version from CoreFoundation; it loads no code.

### DOSBox Pure licence obligations

Source: [codeberg.org/schelling/dosbox-pure](https://codeberg.org/schelling/dosbox-pure), tag 1.0-preview7, commit `cdaea10ce8cac231bc341ca05d4c5e4e5fe0fbd5`, as the unmodified submodule `Cores/dosbox_pure/upstream`. Why Codeberg: the author's GitHub repository [schellingb/dosbox-pure](https://github.com/schellingb/dosbox-pure) ends with a commit by `schellingb` titled "project moved" (2026-10-03, tag `moved`), whose README says the project moved to that Codeberg URL; GitHub has no tag after 1.0-preview6. The Codeberg repository is owned by `schelling` (Bernhard Schelling), was migrated from the GitHub URL, and is not marked as a mirror. `Cores/dosbox_pure/DosboxPureCore.c`, `GagaDosboxPure.cpp`, `GagaPic.cpp` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files; the two `.cpp` files compile upstream files by `#include` so upstream stays unmodified. It is merged from branch `core/dosbox_pure`, kept out of release builds by `GAGA_CORE_SET`, and must not ship until the legal gate above closes.

| Part (as in `Cores/dosbox_pure/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `dosbox_pure_libretro.cpp` and its `dosbox_pure_*.h`, and 106 files of `src` (cpu interpreters, dos, fpu, gui, hardware, ints, misc, shell, `dbp_network.cpp`, `dbp_serialize.cpp`) | GPL-2.0-or-later (file headers; `LICENSE` is the GPL-2.0 text) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `src/hardware/nukedopl3.cpp`, and `src/gui/mt32emu.h` (Munt, included by `midi.cpp`) | LGPL-2.1-or-later | Within a GPL work this is satisfied by the GPL source release; counsel to confirm. |
| `src/hardware/mame/saa1099.cpp`, `sn76496.cpp` | BSD-3-Clause | Reproduce the copyright notice and licence. |
| `src/gui/tsf.h` (TinySoundFont, included by `midi.cpp`), `libretro-common/include` (headers) | MIT | Reproduce the notice. |
| `keyb2joypad.cpp` (key-to-pad table) | Used by upstream "with permission" of its authors, no licence text | Counsel to confirm; it ships in every libretro build of DOSBox Pure. |

Not compiled: `src/cpu/core_dyn_x86*` and `src/cpu/core_dynrec*` (the recompilers; `DISABLE_DYNAREC` leaves `C_DYNAMIC_X86` and `C_DYNREC` undefined), upstream's `Makefile` and every platform MIDI driver (CoreMIDI and CoreAudio need `C_SUPPORTS_*`, never defined). No socket or OpenGL symbol is imported: network play only runs through libretro's netpacket interface and the Voodoo OpenGL path only through `SET_HW_RENDER`, and the adapter refuses both; `core.env` forbids `_socket`, `_connect`, `_bind`, `_getaddrinfo`, `_dlopen`, `_dlsym`, `_mprotect` and `_gl*` imports.

No BIOS, DOS or game is bundled: DOSBox emulates the PC BIOS and DOS itself. MT-32 and SC-55 ROMs and SoundFonts are optional user files in the system folder and are not shipped. The test program `Sources/Debug/DOSTestCOM.swift` is GagaEmu's own hand-assembled 8086 code.

### MAME licence obligations

Source: [github.com/libretro/mame](https://github.com/libretro/mame), the libretro fork of mamedev/mame and the repository libretro-super builds, at master commit `5f5a07748ce5c239c4118463ce8e6473743d4859` (MAME 0.289, 2026-10-09; the fork has no tag for it), as the unmodified submodule `Cores/mame/upstream`. Neither upstream makefile is run: `Cores/mame/generate.py` ran upstream's GENie for the iOS libretro target once and wrote `sources.txt` and `generated/` (7.3 MB: driver list, layouts, version, and C-as-C++ wrappers), which are committed, so a build needs no Python, GENie or network. `Cores/mame/MameCore.c`, `MameSupport.cpp`, `MameOsdLib.cpp`, `generated/` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. This is on branch `core/mame` only and must not ship until the legal gate above closes.

**Licence of the whole.** [mamedev.org/legal](https://www.mamedev.org/legal.html) states MAME is GPL-2.0-or-later as a whole since 0.172, with most files BSD-3-Clause. The fork's `COPYING` is the plain GPL-2.0 text and says nothing of "or later". Counsel to confirm; either way no GPL-3.0-only file is compiled.

| Compiled part (1,108 files in `sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `src/emu`, `src/devices`, `src/lib`, `src/frontend`, `src/mame` (561 files with a header) | BSD-3-Clause | Reproduce the notice. The whole is still GPL, so this is the gate above. |
| `src/mame/videogames/supertnk.cpp` | GPL-2.0-or-later | Complete corresponding source of the whole work, with the offer or the source alongside. This is the gate above. |
| `src/lib/formats/rpk.cpp` | LGPL-2.1-or-later | Satisfied by the GPL source release; counsel to confirm. |
| `src/lib/netlist/macro` and `generated/nlm_modules_lib.cpp` (8 files) | CC0-1.0 | None. |
| `src/lib/util/path_to_regex.cpp`; `md5.cpp` | MIT; public domain | Reproduce the MIT notice. |
| `src/lib/util/nanosvg.cpp` (includes `3rdparty/nanosvg`) | zlib | None in a binary. |
| `src/osd/libretro` and its `modules` (10 files), the m68000 generated files, `disasmintf.cpp`, `static_solvers.cpp` (27 files with no tag) | None in the file; MAME's whole-work licence | Treat as GPL-2.0-or-later. |
| `3rdparty/zlib` (11), `3rdparty/zstd` (25), `3rdparty/flac` (27) | zlib; BSD-3-Clause or GPL-2.0 (take BSD); Xiph BSD-3-Clause | Reproduce the zstd and FLAC notices. |
| `3rdparty/libjpeg` (46) | IJG | State that the software is based in part on the work of the Independent JPEG Group. |
| `3rdparty/lzma` (30), `3rdparty/sqlite3` | Public domain; SQLite blessing | None. |
| `3rdparty/expat` (3), `3rdparty/utf8proc`, `3rdparty/lua` (32), `luafilesystem`, `lua-zlib`, `lsqlite3`, `lua-linenoise` | MIT | Reproduce each notice. |
| `3rdparty/softfloat3` (309, through `generated/cxx`), `3rdparty/ymfm` (9) | BSD-3-Clause | Reproduce the notices. |
| `3rdparty/linenoise` (3) | BSD-2-Clause | Reproduce the notice. |
| Headers only: `sol2`, `pugixml`, `rapidjson`, `glm`; `asio` | MIT; BSL-1.0 | Reproduce the MIT notices; none for BSL-1.0. |

**Driver subset.** `Cores/mame/drivers.flt` lists 28 machines, all parents, taken from MAME's own [free ROM list](https://www.mamedev.org/roms/) (sets the rights holders allow for non-commercial use): gridlee, robby, carpolo, circus, robotbwl, crash, ripcord, sidetrac, targ, spectar, teetert, hardhat, fax, starfire, fireone, topgunnr, victory, falcnwld, witchcrd, witchgme, wstrike, witchjol, wtchjack, wupndown, wldwitch, looping, supertnk and alienar. Reason: the full driver list has tens of thousands of machines and a framework many times this size; this subset is the only one whose sets a player can obtain lawfully, and no machine in it has a recompiling CPU. Framework binary: 84,030,024 bytes (iphoneos arm64), 84,659,192 bytes (simulator). Each dSYM is about 636 MB and is not shipped. `scripts/build-core.sh mame` takes 323 to 353 s for both slices on a 12-core Mac.

**Not compiled.** Any DRC back end, including `drcbe_c` (no machine needs one), `drcbex64.cpp`, `drcbearm64.cpp` and `3rdparty/asmjit`, which `FORBIDDEN_SOURCES` refuses. `osdlib_retro.cpp`, which allocates executable memory and calls `dlopen`: `MameOsdLib.cpp` replaces it without either. The web server, the network output module and the socket file types: `MameSupport.cpp` replaces them with stubs that open nothing, and `FORBIDDEN_IMPORTS` refuses `socket`, `connect`, `bind`, `listen`, `accept`, `getaddrinfo`, `dlopen`, `dlsym` and `mprotect`. Qt, SDL, BGFX, OpenGL, PortAudio, PortMidi and the Qt or Windows debugger front ends.

**Compiled, not used.** MAME's frontend needs Lua 5.4, sol2 and the debugger core (`src/emu/debug`, 18 files) unconditionally; upstream has no switch to leave them out. At runtime no Lua plugin or autoboot script runs (the plugin path is GagaEmu's empty `system/mame/plugins`), Lua's `loadlib` has no `dlopen`, SQLite has no extension loading, and the debugger front end is `osd/modules/debugger/none.cpp`.

No commercial ROM or BIOS is read or bundled. The test set `Sources/Debug/GridleeTestSet.swift` is GagaEmu's own hand-assembled 6809 program, packed in upstream's 13 file names and sizes for the gridlee machine; MAME warns about the wrong checksums, and the libretro OSD hides that warning.

### No-JIT gate

No JIT, no RWX and no dynarec in any shipped core. Each core build gets a gate, audited per core and not only at the end. iOS itself denies JIT; the gate catches a core that would depend on it. `docs/04` section 8 describes both parts:

- `scripts/nojit-gate.sh`, an `nm` and `strings` check as in `S3/scripts/ios/build-core.sh:45-54`, which refuses `_pthread_jit_write_protect_np`, `_sys_icache_invalidate`, `___clear_cache`, `_mach_vm_protect`, `_vm_protect` and each core's own string list in `Cores/<id>/core.env` (for example GNU Lightning, Dynarmic, Oaknut).
- `CodeGenCheck`, a check for code generation at runtime, which a symbol scan can miss.
- `FORBIDDEN_SOURCES` in `core.env`, for a core that ships its dynarec in the same tree. `scripts/build-core.sh` refuses the framework if any compiled source path in its dSYM matches. PCSX-ReARMed uses it for `new_dynarec`, `lightrec` and `lightning`, because its option help text names "lightrec" and "dynarec", so those words cannot be in `FORBIDDEN_STRINGS`. DOSBox Pure uses it for `core_dyn_x86`, `core_dynrec` and `dyn_cache.h`, for the same reason.

---

## 6. Excluded, Research, Candidates and Backlog

### Excluded

| Core | Reason |
|---|---|
| snes9x | [Non-commercial licence](https://raw.githubusercontent.com/snes9xgit/snes9x/master/LICENSE). Not in a paid app. Manic lists it as [sideload only](https://github.com/Manic-EMU/ManicEMU/releases) |
| Genesis Plus GX | [Non-commercial licence](https://raw.githubusercontent.com/ekeeke/Genesis-Plus-GX/master/LICENSE.txt) |
| FBNeo | [Non-commercial licence](https://raw.githubusercontent.com/finalburnneo/FBNeo/master/src/license.txt). Manic lists it as [sideload only](https://github.com/Manic-EMU/ManicEMU/releases) |
| PicoDrive | [Non-commercial licence](https://raw.githubusercontent.com/notaz/picodrive/master/COPYING) |
| Play! | [Requires JIT](https://raw.githubusercontent.com/jpd002/Play-/master/README.md): crashes on game launch without it |
| FreeJ2ME | [Needs a Java runtime](https://raw.githubusercontent.com/hex007/freej2me/master/README.md) |
| Kronos | [Requires OpenGL 4.3 compute](https://docs.libretro.com/library/kronos/) |
| Citra | [Shut down in March 2024](https://pcgamer.com/software/nintendo-3ds-emulator-citra-taken-offline-as-collateral-damage-in-yuzu-settlement/). Azahar replaces it |
| Panda3DS | Fails the no-JIT rule today. CPU is Dynarmic (a recompiler) in the [CMake path checked](https://raw.githubusercontent.com/wheremyfoodat/Panda3DS/master/CMakeLists.txt); no interpreter was found |
| Mesen-S, Mesen2 | [Archived](https://github.com/SourMesen/Mesen2); not active picks |
| DuckStation | [CC-BY-NC-ND](https://raw.githubusercontent.com/stenzek/duckstation/master/README.md) |
| GLideN64 | GLES on iOS; not an accepted renderer path |
| SwanStation | Not selected. [GPL-3.0 hard fork](https://raw.githubusercontent.com/libretro/swanstation/main/README.md) of DuckStation; removed from the plan with no accepted role |
| Yabause | Not selected. Last push 2024-03 |
| Angrylion RDP | Not selected. CPU-side RDP; ParaLLEl-RDP is the chosen path |

### Non-shipping research

Not in the App Store binary and not promised.

| Platform | Project | Facts |
|---|---|---|
| GameCube / Wii | Dolphin (GPL-2.0-or-later) | Has a [native Metal backend](https://raw.githubusercontent.com/dolphin-emu/dolphin/master/Source/Core/VideoBackends/CMakeLists.txt) and a No JIT mode, but the Cached Interpreter [cannot reach full speed at default settings](https://oatmealdome.me/?p=1695): Mario Kart Wii runs about 30 fps (50% speed) on iPhone 16 Pro Max. The DolphiniOS team says an App Store release is "simply not a good idea at the moment" |
| PS2 | Balero-S2 (sister project, `balero-s2`) | Its README describes a cached IR interpreter with `musttail` and NEON lowering. Not part of the GagaEmu binary; no performance data here |

### Candidates, not in the plan

These repos exist. **Licence and no-JIT status are unchecked for all of them.** None is adopted until both are checked and it passes section 5.

| Platform | Candidate |
|---|---|
| GBA | [NanoBoyAdvance](https://github.com/nba-emu/NanoBoyAdvance) |
| SNES | [bsnes-hd](https://github.com/DerKoun/bsnes-hd) |
| NES | [libretro Mesen](https://github.com/libretro/mesen) |
| Saturn | [Ymir](https://github.com/StrikerX3/Ymir) (URL redirects) |
| DOS | [dosbox-core](https://github.com/libretro/dosbox-core) |
| Arcade | [mame2003-plus](https://github.com/libretro/mame2003-plus-libretro). Older MAME licensing is a known concern; check before any use |
| PS2 (research only) | [ARMSX2](https://github.com/ARMSX2/ARMSX2) (GitHub reports GPL-3.0; no-JIT unchecked) |

### Backlog: seen in Manic listing, not planned for v1

Source: [App Store listing](https://apps.apple.com/us/app/manic-emu/id6743335790), with core names from the [public repo](https://github.com/Manic-EMU/ManicEMU/tree/main/Cores) where they could be matched by name. Core names are Manic's and are not GagaEmu picks.

- **Nintendo:** Virtual Boy (`mednafen.vb`), Pokémon Mini (`pokemini`), Famicom Disk System
- **Sega:** Master System, Game Gear (`gearsystem`), SG-1000, 32X
- **NEC:** PC Engine, TurboGrafx-16, TurboGrafx-CD, SuperGrafx (`mednafen.pce`)
- **SNK:** Neo Geo Pocket, Neo Geo Pocket Color (`mednafen.ngp`)
- **Atari:** 2600 (`stella`), 5200 (`atari800`), 7800 (`prosystem`), Jaguar (`virtualjaguar`), Lynx (`holani`)
- **Commodore:** C64 (`vice.x64sc`), Amiga (`puae`)
- **Other:** WonderSwan (`mednafen.wswan`), DOOM (`prboom`), Flash (core not identified), NAOMI / Atomiswave / System SP ([release notes](https://github.com/Manic-EMU/ManicEMU/releases))

---

## 7. PS3 and PS4: External Sister Projects

S3 (`samba-s3-ui`) and S4 (`Bachata-S4-Dev`) are external sister projects. They are not catalog rows, frame producers, or part of the GagaEmu binary. GagaEmu reuses their build patterns only.

- **S3 thread placement:** the iOS path is a QoS hint (`rpcsx/rpcs3/util/Thread.cpp:2249-2253`). big.LITTLE placement is `#ifdef ANDROID` code, not an iOS scheduling scheme.
- **S4 graphics:** GCN shaders go to SPIR-V, then Vulkan on static MoltenVK, presenting to `CAMetalLayer` (`S4/CMakeLists.txt:1667-1686`). There are no direct Metal compute encoders.

---

## 8. Core Selection and Registry

### Core switching

**Manic (seen in screenshot):** the Emulator Core list shows one core per platform, with the caption "switch cores by long-pressing a game in the library." Long-press is the only switching visible in the reference images. The alternates Manic offers are outside the images.

**GagaEmu (design; shell code exists in `Sources/UI/Games/CorePickerSheet.swift`):** long-press a game to open the core sheet, with an option to set the choice as the platform default.

```
┌────────────────────────────────────────────────────────┐
│ Core Selection                                         │
│                                                        │
│  ● PCSX-ReARMed                           [Selected]   │
│  ○ Beetle PSX HW                                       │
│                                                        │
│  [ Set as Default for PlayStation ]                    │
└────────────────────────────────────────────────────────┘
```

### C registry (current code)

`Sources/Bridge/GagaCoreRegistry.c` is a compile-time table of getter functions, each returning a pointer to a `GagaCoreInterface`:

```c
typedef const GagaCoreInterface* (*CoreGetterFunc)(void);

static const CoreGetterFunc s_core_getters[] = {
    MockCore_GetInterface,
    Mgba_GetInterface,
    Gambatte_GetInterface,
    Nestopia_GetInterface,
    Bsnes_GetInterface,
    Jgenesis_GetInterface,
    PcsxReArmed_GetInterface,
    BeetlePsx_GetInterface,
    Gpsp_GetInterface,
    MelonDS_GetInterface,
    Azahar_GetInterface,
    Flycast_GetInterface,
    Ppsspp_GetInterface,
};
```

Lookup is by `core_id` through `GagaCoreRegistry_FindByID`. mGBA comes from `MgbaCore.xcframework`, Gambatte from `GambatteCore.xcframework`, Nestopia from `NestopiaCore.xcframework`, PCSX-ReARMed from `PcsxReArmedCore.xcframework`, bsnes from `BsnesCore.xcframework`, melonDS DS (`melonds_ds`, `.nds`) from `MelonDSCore.xcframework`, JGenesis (`jgenesis`, `.md`, `.gen`, `.smd`, and Mega-CD `.cue` and `.bin`) from `JgenesisCore.xcframework`, DOSBox Pure (`dosbox_pure`) from `DosboxPureCore.xcframework` MAME (`mame`, `.zip` and `.7z`) from `MameCore.xcframework` and Beetle Saturn (`beetle_saturn`, `.cue`, `.ccd`, `.chd`, `.toc`, `.m3u`) from `BeetleSaturnCore.xcframework`. Each keeps a stub inside `#ifndef GAGA_HAS_<ID>`, used only by a build whose `GAGA_CORE_SET` leaves the core out, and the catalog then hides it (`docs/06` section 2.5). Everything else except the mock core is a stub whose `self_test` fails, so the app refuses to start it and says the core is not part of this build. This mGBA build is GBA only: it takes `.gba`, Gambatte takes `.gb` and `.gbc`, and Nestopia takes `.nes` (iNES and NES 2.0) only. PCSX-ReARMed takes `.cue`, `.bin`, `.img`, `.chd`, `.pbp`, `.iso`, `.m3u` and a bare PS-EXE `.exe`. Earlier rows also list two of them, the mock core `.bin` and JGenesis `.bin` and `.cue`, so `GagaCoreRegistry_FindByExtension` alone does not find PCSX-ReARMed for those. Only tests call that lookup; the Library picks the core through the platform, which is `ps1` for all of them. DOSBox Pure takes upstream's list less folders (`.zip`, `.dosz`, `.exe`, `.com`, `.bat`, `.iso`, `.chd`, `.cue`, `.ins`, `.img`, `.ima`, `.vhd`, `.jrc`, `.m3u`, `.m3u8`, `.conf`) and comes last in `s_core_getters`, so the shared ones find PCSX-ReARMed there and `.zip` finds MAME. `CoreCatalog.platformID(forFile:)` decides by content: an `.exe` is `ps1` only when it starts with `PS-X EXE`, otherwise `dos`; a `.zip` is placed by `CoreCatalog.zipPlatformID` from its central directory, nothing extracted: `dos` when it names an `.exe`, `.com`, `.bat` or `.conf`, otherwise `arcade` when the zip is named after a machine in `CoreCatalog.mameMachines` (`Sources/App/MameMachines.swift`, written by `Cores/mame/generate.py` from `drivers.flt`) or every entry has a ROM-like name (no extension, `.bin`, `.rom`, or an extension with a digit). A `.7z` is `arcade`. A disc image (`.iso`, `.bin`, `.cue`, `.chd`, `.img`, `.m3u`) is placed by `CoreCatalog.discPlatformID` from its first 64 KiB: `ps1` for `PLAYSTATION` as the sector 16 system ID or `SYSTEM.CNF` in the root, `saturn` for `SEGA SEGASATURN` opening the first sector, `megacd` for `SEGADISCSYSTEM` or any other `SEGA` there, otherwise `dos` for an ISO 9660 disc or any `.iso` or `.img`. A `.cue` is read through its first `FILE`, an `.m3u` through its first entry. A `.chd` is compressed and is not read. When the contents do not say, Add Games asks the player which system the disc (PS1, Saturn, Mega-CD, DOS) or `.zip` (Arcade, DOS) is for. The Multi-Disc Helper passes its own platform. `CoreCatalog` uses the same short lowercase `core_id` (`mgba`, `pcsx_rearmed`), the only ID scheme. `StateMigration` in `Sources/App/AppState.swift` upgrades older saved values.

### Storage (current code)

State persists as JSON at `Application Support/GagaEmu/state.json`, through `AppState.Snapshot`. It does not use SQLite or Core Data.

- **Per game:** `GameItem.coreOverride: String?`.
- **Per platform:** `AppState.defaultCores: [String: String]`, keyed by platform ID.
- **Resolution order:** `coreOverride`, then `defaultCores[platformID]`, then `CoreCatalog.defaultCore(for:)`, in `GameItem.resolvedCoreID(defaults:)`.
