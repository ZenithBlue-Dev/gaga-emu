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
| SNES / Super Famicom | bsnes | bsnes | bsnes-jg, bsnes-mercury | [GPL-3.0-or-later](https://raw.githubusercontent.com/bsnes-emu/bsnes/master/LICENSE.txt) | Software | Unverified | Active, last push 2026-11-06 ([libretro fork](https://github.com/libretro/bsnes-libretro)) | 2 |
| Genesis / Mega-CD | JGenesis (self-maintained iOS port) | JGenesis (Mega-CD row) | ClownMDEmu | [GPL-3.0](https://raw.githubusercontent.com/jsgroth/jgenesis/master/README.md) | Software frames expected; port needed, since upstream's frontend uses wgpu | Unverified. [`Cargo.lock`](https://raw.githubusercontent.com/jsgroth/jgenesis/master/Cargo.lock) lists no cranelift, dynasm or wasmtime crate | Active, last push 2026-11-06. Linux, Windows and web are official; iOS is not | 2 |
| PS1 | PCSX-ReARMed (`DYNAREC=0`) | Beetle PSX HW | Beetle PSX HW (software, or Vulkan via MoltenVK) | [GPL-2.0-or-later](https://github.com/libretro/pcsx_rearmed) (section 5) | Software (`BUILTIN_GPU = neon`, its C SIMD path) | Built at `7b0e8f8f` with `DRC_DISABLE` and no dynarec source; the no-JIT gate and the forbidden-source check pass on both slices. Upstream [`ios-arm64` sets `DYNAREC = 0`](https://raw.githubusercontent.com/libretro/pcsx_rearmed/master/Makefile.libretro) | Active, last push 2026-10-29 | 1 |
| DS | melonDS DS | melonDS DS | DeSmuME | [GPL-3.0](https://github.com/JesseTG/melonds-ds) | Software (its OpenGL modes are not an accepted path) | Confirmed for the build config: ["JIT is disabled by default in iOS builds"](https://raw.githubusercontent.com/JesseTG/melonds-ds/main/CMakeLists.txt) | Active, last push 2026-10-28. README lists iOS arm64 | 2 |
| Saturn | Beetle Saturn | Beetle Saturn | None confirmed | [GPL-2.0](https://github.com/libretro/beetle-saturn-libretro) | Software | Unverified. A [forum thread](https://forums.libretro.com/t/what-would-it-take-to-get-a-dynarec-into-beetle-saturn/47739?page=3) discusses adding a dynarec, which suggests none exists | Active, last push 2026-11-02 | 3 |
| N64 | Mupen64Plus-Next (ParaLLEl-RDP) | Not seen. Public repo: `mupen64plus.next` | parallel-n64 | [GPL-2.0](https://github.com/libretro/mupen64plus-libretro-nx) | Vulkan via MoltenVK. [ParaLLEl-RDP](https://raw.githubusercontent.com/Themaister/parallel-rdp/master/README.md) needs Vulkan 1.1 plus 8-bit and 16-bit storage; MoltenVK behaviour unverified | **Fails as configured upstream.** The CPU side is clean ([`WITH_DYNAREC=` empty on `ios-arm64`](https://raw.githubusercontent.com/libretro/mupen64plus-libretro-nx/develop/Makefile)), but `HAVE_PARALLEL_RSP = 1` [compiles `rsp_jit.cpp` and GNU Lightning](https://raw.githubusercontent.com/libretro/mupen64plus-libretro-nx/develop/Makefile.common). A non-JIT RSP is required (section 4) | Active, last push 2026-10-29 | 2 |
| PSP | PPSSPP (`IR_INTERPRETER`) | Not seen. Public repo: `ppsspp.libretro` | None | [GPL-2.0-or-later](https://raw.githubusercontent.com/hrydgard/ppsspp/master/README.md) | Native Metal on non-libretro builds ([`Common/GPU/Metal`](https://github.com/hrydgard/ppsspp/tree/master/Common/GPU/Metal); which release ships it is unverified), otherwise Vulkan via MoltenVK | Confirmed: [official post](https://www.ppsspp.org/news/live-on-app-store/) says the App Store build has no JIT and uses the IR interpreter | Active, last push 2026-11-06 | 2 |
| Dreamcast | Flycast JIT-less fork (fork to be named and maintained) | Not seen. Public repo: `flycast-jitless`; [App Store](https://apps.apple.com/us/app/manic-emu/id6743335790) 1.7.1 notes credit a Provenance developer | None | [GPL-2.0](https://github.com/flyinghead/flycast) | Vulkan via MoltenVK expected. Upstream lists Vulkan and OpenGL; the fork's renderer is unverified | Unverified for any fork we would adopt. [Reported](https://retrododo.com/ifly-testflight-spots-are-available-for-iphone-dreamcast-emulator/) as Flycast with the dynarec removed; fork source not located | Upstream active, but [dropped iOS support](https://raw.githubusercontent.com/flyinghead/flycast/master/README.md). GagaEmu would maintain the fork | 3 |
| 3DS | Azahar (experimental) | Azahar | None | [GPL-3.0](https://raw.githubusercontent.com/azahar-emu/azahar/master/LICENSE.txt) | Vulkan via MoltenVK ([README](https://raw.githubusercontent.com/azahar-emu/azahar/master/README.md): Vulkan 1.1 or GLES 3.2; GLES is not accepted), or software | Unverified end to end. Interpreter present (`arm/dyncom`). [`use_cpu_jit` and `use_shader_jit`](https://raw.githubusercontent.com/azahar-emu/azahar/master/src/common/settings.h) default to true and must be off and compiled out | Active, last push 2026-11-06. [CMake](https://raw.githubusercontent.com/azahar-emu/azahar/master/CMakeLists.txt) has an iOS path | 3 |
| Arcade | MAME (GPL) | Not seen. [Release notes](https://github.com/Manic-EMU/ManicEMU/releases): MAME in the App Store version | None | [GPL](https://raw.githubusercontent.com/mamedev/mame/master/COPYING) | Software expected; libretro output path unverified | Unverified. Needs an audit for dynamic-recompiler paths | Active, last push 2026-11-07 | 2 |
| DOS / Win9x | DOSBox Pure (normal core) | Not seen. Public repo: `dosbox.pure` | DOSBox Staging, DOSBox-X | [GPL-2.0-or-later](https://github.com/schellingb/dosbox-pure) | Software | Unverified. The dynamic core must be compiled out, not only left unselected | Active, last push 2026-10-06 | 2 |
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
- **SNES (bsnes):** [coprocessor firmware files are optional](https://docs.libretro.com/library/bsnes/). How each chip behaves without firmware is unverified.
- **N64:** ParaLLEl-RDP is [Vulkan compute](https://raw.githubusercontent.com/Themaister/parallel-rdp/master/README.md), not software rasterisation. GLideN64 is GLES on iOS and is not accepted. `HAVE_PARALLEL_RSP` must be off or its JIT removed. Whether an interpreter RSP can drive ParaLLEl-RDP at usable speed on iOS is an open spike, and the tier 2 rating depends on it.
- **DS (melonDS DS):** DSi camera support is ["planned, but has not yet been integrated"](https://raw.githubusercontent.com/JesseTG/melonds-ds/main/README.md). Do not promise it. Delta's author [reported melonDS at 100% speed on most newer devices](https://rileytestut.com/blog/2021/04/21/delta-1-3-ds-for-everyone) in 2021.
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
- The mix of GPL-2.0 (Gambatte's headers say version 2, with no "or later"), GPL-3.0 and AGPLv3 needs a compatibility check. This review could not read the FSF compatibility matrix. A GPL-2.0-only part is commonly read as not combinable with GPL-3.0 code, which matters for an app that would carry both Gambatte and a GPL-3.0 core. Nestopia is GPL-2.0-or-later, and PCSX-ReARMed's headers say "version 2 or later", so neither adds to that conflict.
- Until this gate closes, release builds use `GAGA_CORE_SET=mgba` (`docs/06` section 2.5), so no GPL code ships.
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

The app has no licence screen yet. In-app notices are tracked at milestone 7.5, which must close before any App Store release containing this core. No Nintendo BIOS or game is bundled.

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

### No-JIT gate

No JIT, no RWX and no dynarec in any shipped core. Each core build gets a gate, audited per core and not only at the end. iOS itself denies JIT; the gate catches a core that would depend on it. `docs/04` section 8 describes both parts:

- `scripts/nojit-gate.sh`, an `nm` and `strings` check as in `S3/scripts/ios/build-core.sh:45-54`, which refuses `_pthread_jit_write_protect_np`, `_sys_icache_invalidate`, `___clear_cache`, `_mach_vm_protect`, `_vm_protect` and each core's own string list in `Cores/<id>/core.env` (for example GNU Lightning, Dynarmic, Oaknut).
- `CodeGenCheck`, a check for code generation at runtime, which a symbol scan can miss.
- `FORBIDDEN_SOURCES` in `core.env`, for a core that ships its dynarec in the same tree. `scripts/build-core.sh` refuses the framework if any compiled source path in its dSYM matches. PCSX-ReARMed uses it for `new_dynarec`, `lightrec` and `lightning`, because its option help text names "lightrec" and "dynarec", so those words cannot be in `FORBIDDEN_STRINGS`.

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

Lookup is by `core_id` through `GagaCoreRegistry_FindByID`. mGBA comes from `MgbaCore.xcframework`, Gambatte from `GambatteCore.xcframework`, Nestopia from `NestopiaCore.xcframework` and PCSX-ReARMed from `PcsxReArmedCore.xcframework`. Each keeps a stub inside `#ifndef GAGA_HAS_<ID>`, used only by a build whose `GAGA_CORE_SET` leaves the core out, and the catalog then hides it (`docs/06` section 2.5). Everything else except the mock core is a stub whose `self_test` fails, so the app refuses to start it and says the core is not part of this build. This mGBA build is GBA only: it takes `.gba`, Gambatte takes `.gb` and `.gbc`, and Nestopia takes `.nes` (iNES and NES 2.0) only. PCSX-ReARMed takes `.cue`, `.bin`, `.img`, `.chd`, `.pbp`, `.iso`, `.m3u` and a bare PS-EXE `.exe`. JGenesis's stub comes first in the registry and also lists `.bin` and `.cue`, so a lookup by those extensions alone finds it; the Library picks the core through the platform, which is `ps1` for all of them. `CoreCatalog` uses the same short lowercase `core_id` (`mgba`, `pcsx_rearmed`), the only ID scheme. `StateMigration` in `Sources/App/AppState.swift` upgrades older saved values.

### Storage (current code)

State persists as JSON at `Application Support/GagaEmu/state.json`, through `AppState.Snapshot`. It does not use SQLite or Core Data.

- **Per game:** `GameItem.coreOverride: String?`.
- **Per platform:** `AppState.defaultCores: [String: String]`, keyed by platform ID.
- **Resolution order:** `coreOverride`, then `defaultCores[platformID]`, then `CoreCatalog.defaultCore(for:)`, in `GameItem.resolvedCoreID(defaults:)`.
