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
| SNES / Super Famicom | bsnes | bsnes | Snes9x (sideload only), bsnes-jg, bsnes-mercury | [GPL-3.0-or-later](https://raw.githubusercontent.com/bsnes-emu/bsnes/master/LICENSE.txt), plus ISC, Expat, MIT and public-domain parts (section 5) | Software | Static gate passes on both slices, runtime check passes on the Simulator; device pending. Upstream libco's `mprotect` path is replaced (section 5). Built on branch `core/bsnes`, legal gate open | Active, last push 2026-11-06 ([libretro fork](https://github.com/libretro/bsnes-libretro), a GitHub fork of bsnes-emu/bsnes and the repository libretro-super builds). No release tag at that point; pinned to master commit `b51612a74c4ff4b91aa55eb094940d9d848e0e96` | 2 |
| Genesis / Mega-CD | JGenesis (self-maintained iOS port) | JGenesis (Mega-CD row) | Genesis Plus GX and PicoDrive (both sideload only), ClownMDEmu | [GPL-3.0](https://raw.githubusercontent.com/jsgroth/jgenesis/master/README.md), plus MIT, Apache-2.0, BSD-3-Clause, Zlib and Unlicense crates (section 5) | Software. GagaEmu's own Rust shim over upstream's emulation crates; no wgpu, SDL or egui is compiled. No 32X: upstream's embedded 32X boot ROMs are compiled as zeros (section 5) | Static gate passes on both slices; runtime check passes on the device. The resolved crate graph has no cranelift, dynasm or wasmtime crate. Merged from branch `core/jgenesis`, legal gate open | Active, last push 2026-11-06. Linux, Windows and web are official; iOS is not. Pinned to tag v0.14.1, `cbe7f129e3f5c805a2a2e4318981834192116e90` | 2 |
| 32X | PicoDrive. **Sideload builds only**, so App Store and TestFlight builds have no 32X platform | Not seen (Backlog listing) | None | [Non-commercial](https://raw.githubusercontent.com/notaz/picodrive/master/COPYING), with FAME and CZ80 terms (section 5) | Software | As its section 3 row. No 32X BIOS needed: `pico/32x/memory.c` builds small 68000 and SH-2 start-up stubs itself. JGenesis 32X is not used: it embeds Sega's SH-2 boot ROMs (section 6) | Active, last push 2026-09-26 | 2 |
| PS1 | PCSX-ReARMed (`DYNAREC=0`) | Beetle PSX HW | Beetle PSX HW (software, or Vulkan via MoltenVK), SwanStation (interpreter) | [GPL-2.0-or-later](https://github.com/libretro/pcsx_rearmed) (section 5) | Software (`BUILTIN_GPU = neon`, its C SIMD path) | Built at `7b0e8f8f` with `DRC_DISABLE` and no dynarec source; the no-JIT gate and the forbidden-source check pass on both slices. Upstream [`ios-arm64` sets `DYNAREC = 0`](https://raw.githubusercontent.com/libretro/pcsx_rearmed/master/Makefile.libretro) | Active, last push 2026-10-29 | 1 |
| DS | melonDS DS | melonDS DS | DeSmuME | [GPL-3.0-or-later](https://github.com/JesseTG/melonds-ds), plus MIT, BSD, LGPL-2.1, zlib, BSL-1.0, Unlicense and OFL parts (section 5) | Software only; the OpenGL renderer is not compiled | Static gate passes on both slices, on the binary and on its debug info; runtime check passes on the Simulator; device pending. Built on branch `core/melonds_ds`, legal gate open | Active, last push 2026-10-28. Pinned to tag v1.4.0, `f394adbacb5722ee97c1b37c8064da9a25818310` | 2 |
| Saturn | Beetle Saturn (interpreter, no `WANT_JIT`) | Beetle Saturn | None confirmed | [GPL-2.0-or-later](https://github.com/libretro/beetle-saturn-libretro) (section 5) | Software, threaded VDP2 renderer | Built at `30f4c120` (Mednafen SS 1.32.1) without `WANT_JIT`, so the SCU and SCSP DSP recompilers (arm64 `a64emit`, Linux only upstream) and the SH-2 recompiler (x86 only) are not compiled; the no-JIT gate and the forbidden-source check pass on both slices. Needs the player's own BIOS | Active, last push 2026-11-02 | 3 |
| N64 | Mupen64Plus-Next (ParaLLEl-RDP) | Not seen. Public repo: `mupen64plus.next` | parallel-n64 | [GPL-2.0](https://github.com/libretro/mupen64plus-libretro-nx) (file groups in section 5) | Vulkan via MoltenVK, layer path. [ParaLLEl-RDP](https://raw.githubusercontent.com/Themaister/parallel-rdp/master/README.md) needs 8-bit and 16-bit storage and `shaderInt8`/`shaderInt16`; MoltenVK v1.4.2 reports all four on Apple GPUs (`MVKDevice.mm`). Subgroup size control is absent, so ParaLLEl-RDP takes its non-subgroup paths | **Passes as GagaEmu builds it** (`Cores/mupen64plus_next`, `15bada85`): pure interpreter R4300, cxd4 interpreter RSP (`HAVE_LLE`), no `HAVE_PARALLEL_RSP`, no `WITH_DYNAREC`. Upstream's own `ios-arm64` sets `HAVE_PARALLEL_RSP = 1`, which [compiles `rsp_jit.cpp` and GNU Lightning](https://raw.githubusercontent.com/libretro/mupen64plus-libretro-nx/develop/Makefile.common) | Active, last push 2026-10-29 | 2 (unmeasured, see `docs/07` 5.2) |
| PSP | PPSSPP (`IR_INTERPRETER`) | Not seen. Public repo: `ppsspp.libretro` | None | [GPL-2.0-or-later](https://raw.githubusercontent.com/hrydgard/ppsspp/master/README.md), plus Apache-2.0 and GPL-3.0 parts, so the binary is GPL-3.0 as a whole (section 5) | Vulkan via MoltenVK on the layer path (upstream's libretro Vulkan context). No OpenGL is compiled | Static gate and the forbidden-source check pass on both slices: no CPU or vertex JIT back end, no code emitter, no `mprotect`, `dlopen` or `___clear_cache` import. Built on branch `core/ppsspp`, legal gate open; device pending. The [official post](https://www.ppsspp.org/news/live-on-app-store/) says the App Store build uses the IR interpreter | Active. Pinned to tag v1.20.4, `fa50bb1976065c4f8b1b47af227d367fe9771555` | 2 |
| Dreamcast | Flycast, upstream (no fork) | Not seen. Public repo: `flycast-jitless`; [App Store](https://apps.apple.com/us/app/manic-emu/id6743335790) 1.7.1 notes credit a Provenance developer | None | [GPL-2.0-or-later](https://github.com/flyinghead/flycast), with GPL-3.0 xBRZ (file groups in section 5) | Vulkan via MoltenVK v1.4.2, layer path. Flycast's own Vulkan renderer; no GL | **Passes as GagaEmu builds it** (`Cores/flycast`, tag `v2.7`, `5aa091fd`): upstream's `TARGET_NO_REC` gives the SH-4, ARM7 and AICA DSP interpreters; no recompiler, no virtual memory mapping, no fault handler is compiled. No fork needed | Upstream active. [Dropped iOS support](https://raw.githubusercontent.com/flyinghead/flycast/master/README.md), so GagaEmu keeps its own build (`core.env`, `FlycastSupport.cpp`) | 3 |
| 3DS | Azahar (experimental) | Azahar | None | [GPL-3.0](https://raw.githubusercontent.com/azahar-emu/azahar/master/LICENSE.txt) | Vulkan via MoltenVK ([README](https://raw.githubusercontent.com/azahar-emu/azahar/master/README.md): Vulkan 1.1 or GLES 3.2; GLES is not accepted), or software | Built at `2126.2` without Dynarmic or the shader JIT (dyncom and shader interpreters); gate passes, device pending (`docs/07` 6.3). [`use_cpu_jit` and `use_shader_jit`](https://raw.githubusercontent.com/azahar-emu/azahar/master/src/common/settings.h) default to true; GagaEmu turns them off and compiles both JITs out. Decrypted content only | Active, last push 2026-11-06. [CMake](https://raw.githubusercontent.com/azahar-emu/azahar/master/CMakeLists.txt) has an iOS path | 3 |
| Arcade | MAME (libretro fork, 28 machines) | Not seen. [Release notes](https://github.com/Manic-EMU/ManicEMU/releases): MAME in the App Store version | FinalBurn Neo (sideload only) | [GPL-2.0-or-later](https://www.mamedev.org/legal.html) as a whole, most files BSD-3-Clause, plus GPL-2.0+, LGPL-2.1+, CC0, MIT, zlib, IJG, BSL-1.0 and public-domain parts (section 5) | Software (libretro frame, `mame_alternate_renderer` off) | Static gate and the forbidden-source check pass on both slices: no DRC back end (not even `drcbe_c`), no asmjit, no `osdlib_retro.cpp`, no sockets, `dlopen` or `mprotect` imports. Merged from branch `core/mame` at bridge ABI 5, legal gate open | Active, last push 2026-11-07 ([libretro/mame](https://github.com/libretro/mame)). No tag for 0.289; pinned to master commit `5f5a07748ce5c239c4118463ce8e6473743d4859` | 2 |
| DOS / Win9x | DOSBox Pure (normal core) | Not seen. Public repo: `dosbox.pure` | DOSBox Staging, DOSBox-X | [GPL-2.0-or-later](https://codeberg.org/schelling/dosbox-pure), plus LGPL-2.1-or-later, BSD-3-Clause and MIT parts (section 5) | Software only; Voodoo runs in software and no OpenGL is linked | Built with `DISABLE_DYNAREC` and without `core_dyn_x86` or `core_dynrec`: the no-JIT gate and the forbidden-source check pass on both slices, and the dSYM lists the interpreter sources only. Merged from branch `core/dosbox_pure`, legal gate open | Active. Moved by its author from GitHub to Codeberg in October 2026 (section 5). Pinned to tag 1.0-preview7, `cdaea10ce8cac231bc341ca05d4c5e4e5fe0fbd5` | 2 |
| PC Engine / TurboGrafx-16 / PC Engine CD | Beetle PCE Fast | Beetle PCE (`mednafen.pce`, Backlog listing) | Beetle SuperGrafx | [GPL-2.0-or-later](https://github.com/libretro/beetle-pce-fast-libretro), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | Static gate passes on both slices; macOS host harness checks pass; device pending. Built on branch `core/group-mednafen`, legal gate open. CD needs the player's `syscard3.pce` | Active. No release tags; pinned to master commit `2de1ce1c3f237b161c126c54ba407990bb86d1e9` (2026-10-30) | 1 |
| SuperGrafx | Beetle SuperGrafx | Beetle PCE (`mednafen.pce`, Backlog listing) | None | [GPL-2.0-or-later](https://github.com/libretro/beetle-supergrafx-libretro), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | As PC Engine. Built on branch `core/group-mednafen`, legal gate open | Active. No release tags; pinned to master commit `9c11dcd213a79d57d2c86313971631af801f2cdc` (2026-10-06) | 1 |
| Virtual Boy | Beetle VB | `mednafen.vb` (Backlog listing) | None | [GPL-2.0-or-later](https://github.com/libretro/beetle-vb-libretro), plus LGPL-2.1-or-later, MIT and SoftFloat parts (section 5) | Software. One eye, red on black; anaglyph and side-by-side 3D are core options left off | As PC Engine. Built on branch `core/group-mednafen`, legal gate open | Active. No release tags; pinned to master commit `d5ae54c8e23b573a3b34e888b2d48a588027e92c` (2026-10-12) | 1 |
| Neo Geo Pocket / Color | Beetle NeoPop | `mednafen.ngp` (Backlog listing) | None | [GPL-2.0-or-later](https://github.com/libretro/beetle-ngp-libretro), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | As PC Engine. Built on branch `core/group-mednafen`, legal gate open. High-level BIOS, no SNK BIOS needed | Active. No release tags; pinned to master commit `a50d5ac288a81f2104ddf43195a4efdd15c72227` (2026-06-14) | 1 |
| WonderSwan / Color | Beetle Cygne | `mednafen.wswan` (Backlog listing) | None | [GPL-2.0-or-later](https://github.com/libretro/beetle-wswan-libretro), plus LGPL-2.1-or-later and MIT parts (section 5) | Software. Vertical games turn upright on Select, in software | As PC Engine. Built on branch `core/group-mednafen`, legal gate open. No boot ROM needed | Active. No release tags; pinned to master commit `4b01295838ea89e3f1355bbe4cb5cf98aa6108cd` (2026-07-31) | 1 |
| Pokémon Mini | PokeMini | `pokemini` (Backlog listing) | None | [GPL-3.0-or-later](https://github.com/libretro/PokeMini), plus MIT parts (section 5) | Software | As PC Engine. Built on branch `core/group-mednafen`, legal gate open. Free BIOS built in; the player's `bios.min` is optional | Active. No release tags; pinned to master commit `132111b76343559860532a1ccc094f93f1ed5650` (2026-07-31) | 1 |

**Backlog cores, group-retro** (`docs/07` section 8.x). Rows from section 6's backlog, built on branch `core/group-retro`. Same columns; Manic's core is from its public repo.

| Platform | GagaEmu default | Manic default (screenshot) | Alternates | Licence | Renderer path | No-JIT status | Upstream state | Load tier |
|---|---|---|---|---|---|---|---|---|
| Master System / Game Gear / SG-1000 | Gearsystem | `gearsystem` | None | [GPL-3.0-or-later](https://github.com/drhelius/Gearsystem) (file headers: "version 3 of the License, or any later version"), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | Z80 interpreter, no recompiler in the tree. Static gate passes on both slices; runtime check passes on a macOS host harness; device pending. Built on branch `core/group-retro`, legal gate open | Active, last push 2026-11-06 ([drhelius/Gearsystem](https://github.com/drhelius/Gearsystem), `platforms/libretro`). Pinned to tag 3.9.24, `40b8eebab53007c976eb29755b1ef7925140c37f` | 1 |
| Atari 2600 | Stella | `stella` | stella2014 (not built) | [GPL-2.0-or-later](https://github.com/stella-emu/stella) (`Copyright.txt`), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | 6502 interpreter; the ARM interpreter for DPC+, CDF and ELF carts (Thumbulator, CortexM0) does not recompile. Static gate passes on both slices; runtime check passes on a macOS host harness; device pending. Built on branch `core/group-retro`, legal gate open | Active, last push 2026-11-06 ([stella-emu/stella](https://github.com/stella-emu/stella), `src/os/libretro`). Pinned to release tag 7.0c, `c4016ea4891cb0f90979cb35182214af4c1cb4e7`. Chosen over [stella2014-libretro](https://github.com/libretro/stella2014-libretro), a 2014 snapshot (Stella 3.9.3) that libretro only keeps building: both are GPL-2, this one is maintained | 1 |
| Atari 7800 | ProSystem | `prosystem` | None | [GPL-2.0-or-later](https://github.com/libretro/prosystem-libretro) (`License.txt`), plus zlib and MIT parts (section 5) | Software | 6502 (Sally) interpreter. Static gate passes on both slices; runtime check passes on a macOS host harness; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/prosystem-libretro](https://github.com/libretro/prosystem-libretro)), last push 2026-08-22, no tags. Pinned to `8a88014287c7a01cd568067e5a557d0a2b2a051f` | 1 |
| Atari Lynx | Handy | `handy` | holani (not built) | [Zlib](https://github.com/libretro/libretro-handy) (`lynx/license.txt`), plus LGPL-2.1-or-later and MIT parts (section 5) | Software | 65C02 interpreter. Static gate passes on both slices; runtime check passes on a macOS host harness; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/libretro-handy](https://github.com/libretro/libretro-handy)), last push 2026-04-20, no tags. Pinned to `bc55d462f0b2d6b073ea93dc552ebd73cec60fd1`. Chosen over [holani-retro](https://github.com/LLeny/holani-retro): GPL-3.0 and Rust, which `scripts/build-core.sh` does not build | 1 |
| Atari 5200, Atari 8-bit | Atari800 | `atari800` | None | [GPL-2.0-or-later](https://github.com/libretro/libretro-atari800) (`atari800/COPYING`), plus all-permissive, Zlib and MIT parts (section 5) | Software | 6502 interpreter. Static gate passes on both slices; runtime check passes on a macOS host harness; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/libretro-atari800](https://github.com/libretro/libretro-atari800)), last push 2026-09-01, no tags. Pinned to `4e7fbc73765c1a9670c7506616046ad1d4ccda51` | 1 |
| Atari Jaguar | Virtual Jaguar | `virtualjaguar` | None (optional `jagboot.rom`) | [GPL-3.0-or-later](https://github.com/libretro/virtualjaguar-libretro) (`LICENSE`), plus BSD, MIT and public-domain parts (section 5) | Software | 68000, GPU and DSP interpreters. Heavy tier: a full-speed claim needs a device benchmark with real games. Static gate passes on both slices; runtime check passes on a macOS host harness; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/virtualjaguar-libretro](https://github.com/libretro/virtualjaguar-libretro)). Pinned to tag `v3.11.0`, `34696082dbc0448caf23aa4ecb5ed40817cb8da0` | 3 |
| Commodore 64 | VICE (x64sc) | `vice` | Player's `kernal-901227-03.bin`, `basic-901226-01.bin`, `chargen-901225-01.bin` | [GPL-2.0-or-later](https://github.com/libretro/vice-libretro) (`COPYING`), plus Zlib, MIT and public-domain parts (section 5) | Software | 6510, VIC-II and SID interpreters, cycle-exact. Static gate passes on both slices; runtime check passes on a macOS host harness with all-zero stand-in ROM files; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/vice-libretro](https://github.com/libretro/vice-libretro)), last push 2026-10-30, no tags. Pinned to `5ebe7d333ab15be57a9dde5f46c29a5bbd5f44f8` | 2 |
| Amiga | PUAE | `puae` | None: upstream's built-in AROS Kickstart replacement. Player's `kick34005.A500` and `kick40068.A1200` optional | [GPL-2.0-or-later](https://github.com/libretro/libretro-uae) (`COPYING`), plus AROS Public License 1.1 (the AROS ROM), SoftFloat-2a, BSD, Zlib, MIT and public-domain parts (section 5) | Software | 68000 interpreter (no JIT source compiled), OCS/ECS chipset. Static gate passes on both slices; runtime check passes on a macOS host harness on AROS; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/libretro-uae](https://github.com/libretro/libretro-uae)), last commit 2026-11-04, no tags (`VERSION` 5.3.1). Pinned to `c1d1d49d5c7cdad2005e86f1cbb279d39e041efc` | 2 |
| Doom (WAD) | PrBoom | `prboom` | None. The player's game WAD (an IWAD such as `doom2.wad` or `freedoom2.wad`, or a PWAD beside one); none bundled | [GPL-3.0-or-later](https://github.com/libretro/libretro-prboom) as a whole: mostly GPL-2.0-or-later (`COPYING`), `src/sc88.c` GPL-3.0-or-later, plus LGPL, BSD and MIT parts (section 5) | Software | Software renderer, no CPU to emulate. Static gate passes on both slices; runtime check passes on a macOS host harness with GagaEmu's generated IWAD; device pending. Built on branch `core/group-retro`, legal gate open | Maintained by libretro ([libretro/libretro-prboom](https://github.com/libretro/libretro-prboom)), last commit 2026-10-18, no tags (`v2.5.0` in `retro_get_system_info`). Pinned to `4849268e7342494193f2bbf2d0128a751cf58da7` | 1 |

### Renderer rules

- **App UI, frame presentation and post-processing:** native Metal.
- **Software-rendered cores:** a core that also has GL or Vulkan renderers (SwanStation) is set to its software renderer, and its GL and Vulkan loaders get a `dlopen` stub that returns NULL. The core frame goes through the host texture ring and Metal shader chain. libretro cores copy frames unless a host-buffer API exists, so zero copy is not claimed for them.
- **3D cores:** Vulkan on one embedded MoltenVK framework (docs/06 section 2.5) to `CAMetalLayer`, the pattern S3 and S4 use. MoltenVK counts as Metal for this project (owner decision, 2026-11-07). A native Metal backend is allowed where upstream has one.
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
| PS1 | SwanStation (built, `swanstation`) | [GPL-3.0](https://github.com/libretro/swanstation), with MIT OpenBIOS (section 5) | Software only (`swanstation_GPU_Renderer` = `Software`). The GL and Vulkan renderers are compiled but never start: their loaders' `dlopen` is a stub | **Passes as GagaEmu builds it** (`631f0fb3`): `WITH_RECOMPILER` and fastmem off, cached interpreter. Static gate and forbidden-source check pass on both slices; macOS harness checks pass; device pending | Active, last push 2026-10-24. No tags; pinned to master `631f0fb31b809e0f889d7c551fe695788e39c1d3` |
| SNES | Snes9x (built, `snes9x`). **Sideload builds only** | [Snes9x licence, non-commercial](https://raw.githubusercontent.com/snes9xgit/snes9x/master/LICENSE) (section 5) | Software | Passes: C++ interpreter only. Static gate passes on both slices; device pending | Active. No tags; pinned to master `fae2fea08f74180759ef540ee94259213f503480` (2026-09-19) |
| Genesis / Mega-CD / SMS / GG | Genesis Plus GX (built, `genesis_plus_gx`). **Sideload builds only** | [Non-commercial](https://raw.githubusercontent.com/ekeeke/Genesis-Plus-GX/master/LICENSE.txt) (section 5) | Software | Passes: 68000, Z80 and SSP1601 interpreters, no recompiler in the tree. Static gate passes on both slices; macOS harness checks pass; device pending. Mega-CD needs the player's `bios_CD_*.bin` | Active. No tags; pinned to master `f27655b592ef43f317272d79883bcaa10d3ac8ad` (2026-10-30) |
| Genesis / Mega-CD / 32X | PicoDrive (built, `picodrive`). **Sideload builds only**. Also the only 32X core | [Non-commercial](https://raw.githubusercontent.com/notaz/picodrive/master/COPYING), with FAME and CZ80 terms (section 5) | Software | Passes as built (`1890c293`): FAME/C, CZ80, MAME SH-2 and SSP1601 interpreters; the SH-2 and SVP recompilers are not compiled. Static gate passes on both slices; macOS harness checks pass on a Mega Drive ROM; 32X untested (no free 32X test ROM); device pending | Active. No tags; pinned to master `1890c2932234c9d30f4cd3851d02228baae8f09e` (2026-09-26) |
| Arcade | FinalBurn Neo (built, `fbneo`). **Sideload builds only** | [FB Neo licence, non-commercial, no donations](https://raw.githubusercontent.com/finalburnneo/FBNeo/master/src/license.txt) (section 5) | Software | Passes: every CPU an interpreter; no Cyclone (ARM32 asm) and no MIPS3 x64 recompiler. Static gate passes on both slices; macOS harness checks pass on Gridlee; device pending | Active. No tags; pinned to master `4cdb31f1729588fa42d4aa1c3d9ce2cdaed28618` (2026-11-07) |

Sideload-only rows are hidden from App Store and TestFlight builds (section 5, "Non-commercial cores"). Every alternate is picked per game, or as a platform default, through core switching (section 8); none is a default.

---

## 4. Platform Notes

Only sourced claims appear here. Expected performance is a target (unmeasured); `docs/04` owns tiers.

- **GBA (mGBA):** [README](https://raw.githubusercontent.com/mgba-emu/mgba/master/README.md) lists motion sensor and rumble cartridges, Boktai solar sensor, and Game Boy Camera and Printer.
- **GB (SameBoy):** ships open-source DMG and CGB boot ROMs, not official ones. [Printer emulation](https://sameboy.github.io/features/) is listed on its site.
- **SNES (bsnes):** [coprocessor firmware files are optional](https://docs.libretro.com/library/bsnes/). How each chip behaves without firmware is unverified. GagaEmu sets `bsnes_coprocessor_prefer_hle` and never asks for firmware, so Super Game Boy and BS-X games do not load. Only a homebrew LoROM test ROM has run.
- **N64:** ParaLLEl-RDP is [Vulkan compute](https://raw.githubusercontent.com/Themaister/parallel-rdp/master/README.md), not software rasterisation. GLideN64 is GLES on iOS and is not accepted. GagaEmu's build leaves `HAVE_PARALLEL_RSP` off and uses the cxd4 interpreter RSP, which upstream itself selects on iOS without JIT (`libretro.c`). It builds and passes the gate; whether it runs at usable speed is the open device benchmark in `docs/07` 5.2, and the tier 2 rating depends on it.
- **DS (melonDS DS):** DSi camera support is ["planned, but has not yet been integrated"](https://raw.githubusercontent.com/JesseTG/melonds-ds/main/README.md). Do not promise it. Delta's author [reported melonDS at 100% speed on most newer devices](https://rileytestut.com/blog/2021/04/21/delta-1-3-ds-for-everyone) in 2021.
- **Arcade (MAME):** a ROM set is one zip or 7z named after the machine, and MAME checks the file names inside, not the zip's name alone. Only the 28 machines in `Cores/mame/drivers.flt` are compiled; any other set is refused at load. Clones, BIOS sets and software lists are not offered. No commercial set has been run.
- **3DS (Azahar):** the PICA200 shader path differs by stage.
  - Fragment shaders have a direct SPIR-V generator, [`spv_fs_shader_gen.cpp`](https://github.com/azahar-emu/azahar/tree/master/src/video_core/shader/generator). That file listing supports the fragment wording used here.
  - No SPIR-V vertex generator is in that directory. The vertex path appears to go through `glsl_shader_gen` and `glsl_shader_decompiler`. This is inferred from file names, not traced in code.
  - MoltenVK then translates SPIR-V to MSL at runtime, which the project accepts for GPU shaders.
  - `shader_jit_a64_compiler` is in the tree and must not ship.
- **PS1 (Beetle PSX HW):** PGXP is documented as "Parallel/Precision Geometry Transform Pipeline". Upscaling runs on the GL or Vulkan renderer, not directly on Metal.
- **PSP (PPSSPP):** the [CPU modes](https://raw.githubusercontent.com/hrydgard/ppsspp/master/Core/ConfigValues.h) are `CPUCore` values, not a build flag. Use `IR_INTERPRETER`, not the plain `INTERPRETER`. The developer states iOS devices are ["generally fast enough to run nearly all PSP games at full speed"](https://www.ppsspp.org/news/live-on-app-store/) without JIT. A native Metal build means integrating outside libretro, so GagaEmu uses upstream's libretro frontend with Vulkan on MoltenVK. The libretro option `ppsspp_cpu_core` is set to `IR JIT`, which upstream maps to `IR_INTERPRETER`; the frontend also reports no JIT, which forces that mode. There is no FFmpeg (upstream ships it only as prebuilt binaries): ATRAC3 and MP3 audio use upstream's own `at3_standalone` and minimp3, and PSMF and MPEG video cutscenes do not decode. PPSSPP's assets (`compat.ini`, `ppge_atlas.zim`) are not bundled yet; upstream warns and runs without them.
- **Dreamcast:** tier 3 is deliberate. [Anecdotal reports](https://mjtsai.com/blog/?p=48998) describe struggling on iPhone 16 Pro and running well on M4 iPad. No benchmark was found. Provenance's JIT-free update was reported stuck in App Review in August 2025. GagaEmu's interpreter-only build of upstream Flycast is unmeasured (`docs/07` 6.2).
- **Java ME:** the 6.4 spike failed, so the row left the matrix (`docs/07` 6.4). The reasons:
  - **J2meJS has no corresponding source.** Manic's [v1.9.0 notes](https://github.com/Manic-EMU/ManicEMU/releases) name J2meJS, "based on Mozilla's PluotSorbet", and credit zixing131 and Rosabis. Its repo is [Rosabis/J2meJS](https://github.com/Rosabis/J2meJS) (GPL-2.0, last push 2026-10-31, checked at `5cad51de`).
    - The repo holds build output only: `bld/j2me.js`, `bld/main-all.js`, an Emscripten `bld/native.js` and a prebuilt `java/classes.jar`. There are no TypeScript or Java sources.
    - `classes.jar` has 1,778 entries and no `.java` file. Its phoneME MIDP classes are "GNU General Public License version 2 only". It also bundles FreeJ2ME classes (`org/recompile/*`, GPL-3.0) and ObjectWeb ASM.
    - GagaEmu could not meet the GPL source obligation for what it ships. A GPL-2.0-only part also sits next to a GPL-3.0 one. No other fork found holds the sources for the M3G and vendor-API additions: `zixing131/pluotsorbet-Reborn` is upstream unchanged, and `zixing131/pluotsorbet-Next` has no M3G.
    - The repo's `java/jar/` folder also carries commercial game JARs. They were not used.
  - **The JS runtime passes the no-JIT test.** A homebrew CLDC benchmark (`fib(24)`, a sieve, 30 per-pixel 176x208 frames, `StringBuffer` churn) ran on macOS in the system `jsc` with `--useJIT=false`. It used the J2meJS VM build and upstream's `shell/`.
    - Results, three runs each: total 3.09 to 3.16 s with no JIT, against 0.165 s with the JIT, about 19 times slower. `fib(24)` took 134 to 142 ms, and one per-pixel frame about 73 ms.
    - This is a Mac host, not a device measure.
    - The VM turns hot Java methods into JS source through `new Function`. JSC interprets that source, so no native code is made. In-process `JSContext` on iOS runs without a JIT.
    - The JS runtime path is not the blocker.
  - **Upstream PluotSorbet would be a port, not a core integration.** [mozilla/pluotsorbet](https://github.com/mozilla/pluotsorbet) has full source at `46ee3e78`. It is archived and was last pushed 2017-02-17. Its licences are GPL-2.0-only (phoneME Java), Apache-2.0 (the JS VM), MIT (`vm/` from node-jvm, Relooper) and Boehm GC.
    - Its MIDP layer needs a browser. It uses the DOM, canvas 2D for lcdui (`midp/gfx.js`), IndexedDB for RMS and files (`libs/fs.js`), HTML and Web Audio (`midp/media.js`) and DOM text input (`midp/text_editor.js`). `JSContext` has none of these, so a native canvas 2D, font, image-decode, storage and audio shim would be needed.
    - The build needs Emscripten (Boehm.js and Relooper to asm.js), TypeScript 1.8 `--out`, Closure, Soot and a SpiderMonkey shell. Only `javac` 21 and `node` are on this Mac, and `javac` 21 cannot target the `-source 1.3` the Makefile uses.
    - It has no M3G (JSR 184) or Mascot Capsule, and it was built for Firefox OS apps, not games.
    - A web view would provide the browser APIs. It would not fix the source or porting problems, and it does not fit the core texture path.
- **Symbian (EKA2L1):** out. The renderer spike failed at `62f0180e` (`docs/07` 6.6): only the OpenGL backend is built, the Vulkan backend is a stub with no swapchain or Metal surface, and no software renderer exists. The row left the master matrix and is listed under Excluded.

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

No file outside these groups is compiled, and the build fetches nothing. `NST_NO_ZLIB` is upstream's own define: states are never compressed and no zlib is linked. The FDS disk BIOS (`disksys.rom`) is not bundled. `.fds` is offered: the player puts their own `disksys.rom` in `GagaEmu/System` (listed on the BIOS Files screen), and a disk without it is refused with a message. Side A is inserted at power-on (`nestopia_fds_auto_insert`). `NstHomebrew.cpp` imports `exit` for an exit port that only the `Api::Homebrew` interface turns on, which `libretro.cpp` never calls. The test ROM is GagaEmu's own generated program (`Sources/Debug/NESTestROM.swift`).

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

No 32X. The 32X crates (`s32x-core`, `sh2-emu`) are linked only because `genesis-core` depends on them, and the shim never creates 32X hardware. Upstream's `s32x-core` embeds the 32X SH-2 master and slave boot ROMs with `include_bytes!` (`docs/07` section 14). `CORE_BLANK_FILES` in `Cores/jgenesis/core.env` makes `scripts/build-core.sh` compile those files, and `m68k_vectors.bin`, as zeros of the same size from a staged copy, so no ROM byte reaches `JgenesisCore.framework`; the submodule itself is unmodified. `scripts/bootrom-gate.py` fails the build if one ever does.

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

### Mupen64Plus-Next licence obligations

Source: [github.com/libretro/mupen64plus-libretro-nx](https://github.com/libretro/mupen64plus-libretro-nx), branch `develop`, commit `15bada85906593376e8fd697f1b0b3af3a20f512`, as the unmodified submodule `Cores/mupen64plus_next/upstream`. Its paraLLEl-RDP copy records commit `65f4f4da`. `Mupen64PlusNextCore.c`, `nogl.c` (stubs for the GLideN64 symbols upstream's glue references), `flags.h`, `volk_gaga.c`, `volk_rename.h` and `Cores/shared/LibretroAdapter.c` and `LibretroVulkan.c` are GagaEmu's own files. It is built on branch `core/n64`, kept out of release builds by `GAGA_CORE_SET`, and must not ship until the legal gate above closes. It also links MoltenVK, so the MoltenVK rows above apply.

| Part (as in `Cores/mupen64plus_next/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `mupen64plus-core` (R4300 interpreters, memory, PIF HLE boot, saves, cheats), `mupen64plus-rsp-hle`, `libretro/libretro.c`, `custom/` glue (`mupen64plus-core` config, audio backend, vidext, controller), `GLideN64/src/osal/osal_files_unix.c` | GPL-2.0-or-later (file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `mupen64plus-video-paraLLEl/parallel.cpp`, `rdp.cpp` | No header; the repository `LICENSE` (GPL-2.0) applies | As above. |
| `mupen64plus-rsp-cxd4` | CC0-1.0 | None. |
| `parallel-rdp` (renderer, Granite `vulkan/` and `util/`, shaders) | MIT (Themaister) | Reproduce the notice. |
| volk | MIT (Arseny Kapoulkine) | Reproduce the notice. |
| `libretro-common` | MIT; `libco` aarch64 public domain | Reproduce the MIT notice. |
| zlib, minizip | zlib licence | Do not misrepresent the origin; keep the notice in source. |
| `md5.c` | zlib-style (L. Peter Deutsch) | As zlib. |
| Vulkan headers in the tree | Apache-2.0 OR MIT (headers only) | Ship either licence text. |

Not compiled: `mupen64plus-rsp-paraLLEl` (`rsp_jit.cpp`, `jit_allocator`) and GNU Lightning (`HAVE_PARALLEL_RSP` off), `new_dynarec` (`WITH_DYNAREC` empty), GLideN64 except its osal file, `glsm` and `glsym`, Angrylion (`HAVE_THR_AL` off), libpng, `custom/ios/compat.c` (its `__clear_cache` exists for the dynarec) and every `.S` file (`NO_ASM`). `FORBIDDEN_SOURCES` refuses a framework that compiles any of them. volk's function pointers are renamed `gaga_volk_vk*` (`volk_rename.h`), so they cannot merge with MoltenVK's statically linked `vk*` functions, and volk's `dlopen` is a stub that returns NULL.

No PIF ROM, IPL3 or game is bundled. The PIF boot is upstream's HLE (`bootrom_hle.c`): it copies the cartridge's own boot block to RSP DMEM and jumps to it. The test cartridge `Sources/Debug/N64TestROM.swift` is GagaEmu's own MIPS program, booted that way.
### PPSSPP licence obligations

Source: [github.com/hrydgard/ppsspp](https://github.com/hrydgard/ppsspp), tag v1.20.4, commit `fa50bb1976065c4f8b1b47af227d367fe9771555`, as the unmodified submodule `Cores/ppsspp/upstream`. Upstream's own submodules that the build compiles are initialised at the commits upstream records, and `CORE_UPSTREAM_SUBMODULES` in `core.env` makes `scripts/build-core.sh` refuse any other: `libretro/libretro-common` `76a3d54f`, `ext/armips` `a8d71f0f` (with its `ext/filesystem` `3f1c185a`), `ext/glslang` `50e0708e`, `ext/SPIRV-Cross` `4212eef6`, `ext/rapidjson` `73063f50`, `ext/zstd` `f8745da6` (v1.5.7), `ext/cpu_features` `fd4ffc16`, `ext/rcheevos` `ebfe8ca1`, `ext/naett` `5f695cfa`, `ext/libchdr` `8bba7745`, `ext/lua` `7648485f`, `ext/freetype` `063ed27f`, `ext/nanosvg` `478dbb8f`, `ext/aemu_postoffice` `530fee54` and `ext/miniupnp` `27d13ca9` (headers only). FFmpeg is not one: upstream's `ffmpeg` submodule holds prebuilt libraries, not source, so `USE_FFMPEG=OFF`. Neither upstream build is run: `Cores/ppsspp/generate.py` runs upstream's CMake configure for iOS (`LIBRETRO=ON`, no FFmpeg, Discord or UPnP) and writes `sources.txt` (each file with its own library's flags), `cmake.env` and `generated/` (glslang's `build_info.h`), which are committed. `PpssppCore.c`, `PpssppSupport.cpp`, `JitCommonNoJit.cpp`, `MemoryUtil.cpp`, `LibretroVulkanContextGaga.cpp`, `LibretroGraphicsContextNoGL.cpp`, `flags.h`, `chdr_lzma.h` and `Cores/shared` are GagaEmu's own files; the three wrappers compile one upstream file each by `#include`. This is on branch `core/ppsspp` only and must not ship until the legal gate above closes.

**Licence of the whole.** PPSSPP is GPL-2.0-or-later. It is linked with Apache-2.0 parts (SPIRV-Cross, cpu_features, basis_universal, parts of glslang), which are compatible with GPL-3.0 only, and with GPL-3.0 parts (`aemu_postoffice`, xBRZ), so the binary can only be distributed under GPL-3.0. Upstream's own releases are in the same position. Counsel to confirm.

| Compiled part (844 upstream files in `sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `Core` (224), `Common` (122), `GPU` (63), `libretro` (13) | GPL-2.0-or-later | Complete corresponding source of the whole work, with the offer or the source alongside. This is the gate above. |
| `ext/aemu_postoffice` (6, the ad hoc relay client); `ext/xbrz` | GPL-3.0 (`gpl-3.0.txt`); GPL with a MAME linking exception, no version named | As above, under GPL-3.0. |
| `ext/libkirk` (6) | GPL-2.0 or GPL-3.0 (`bn.c`, `ec.c`), the rest public domain or BSD | As above. |
| `ext/at3_standalone` (9, ATRAC3 from FFmpeg) | LGPL-2.1-or-later | Satisfied by the GPL source release; counsel to confirm. |
| `ext/SPIRV-Cross` (9), `ext/cpu_features` (17), `ext/basis_universal` | Apache-2.0 | Reproduce the licence and any NOTICE text. |
| `ext/glslang` (52) | BSD-3-Clause, BSD-2-Clause, MIT and Apache-2.0 per file (`license-checker.cfg`) | Reproduce each notice. |
| `ext/libzip` (112), `ext/snappy` (4), `ext/sfmt19937`, `ext/libchdr` (16) | BSD-3-Clause | Reproduce the notices. |
| `ext/zstd` (30) | BSD-3-Clause or GPL-2.0 (take BSD) | Reproduce the notice. |
| `ext/udis86` (6), `ext/xxhash.c` | BSD-2-Clause | Reproduce the notices. |
| `ext/armips` (56), `ext/rcheevos` (23), `ext/lua` (32), `ext/gason`, `ext/pugixml`, `ext/vma`, `ext/cityhash`, `ext/riscv-disas.cpp`, `ext/loongarch-disasm.cpp`; `libretro-common`, `rapidjson` (headers) | MIT | Reproduce each notice. |
| `ext/disarm.cpp` | Permissive, keep the copyright notice | Reproduce the notice. |
| `ext/libpng17` (17) | libpng licence | None in a binary beyond keeping the notice in source. |
| `ext/lzma-sdk` (13), libchdr's `deps/lzma-24.05`, `ext/jpge` (2), `ext/minimp3` | Public domain; CC0 for minimp3 | None. |

**Not compiled.** Every CPU JIT back end (`Core/MIPS/ARM`, `ARM64`, `x86`, `RiscV`, `LoongArch64`), every code emitter (`Common/*Emitter.cpp`, `Thunk.cpp`, `ABI.cpp`), the vertex decoder JITs (`GPU/Common/VertexDecoder*.cpp` per architecture), the software renderer's x86 JIT and its code block (`RasterizerRegCache.cpp`), and upstream's `Common/MemoryUtil.cpp`, which `FORBIDDEN_SOURCES` refuses. `MemoryUtil.cpp` replaces it: it maps read-write memory only, `AllocateExecutableMemory` returns null and `ProtectMemoryPages` never calls `mprotect`. `JitCommonNoJit.cpp` builds upstream's `JitCommon.cpp` as for an architecture without a JIT, so `CreateNativeJit` can only make the `FakeJit`. OpenGL and OpenGL ES (`Common/GPU/OpenGL`, `GPU/GLES`, the libretro GL contexts) and OpenXR (`Common/VR`). `PpssppSupport.cpp` holds the few link stubs left: pointer accessors of the ARM64 emitter class that the vertex decoder's cache derives from, a vertex decoder `Compile` that returns null, an empty software renderer code block, and constant answers for OpenGL and VR. Discord, UPnP, FFmpeg and `git-version.cpp`.

**Imports.** `FORBIDDEN_IMPORTS` refuses `dlopen`, `mprotect`, `vm_protect`, `sys_icache_invalidate`, `sys_dcache_flush` and `pthread_jit*`; `flags.h` renames upstream's `dlopen` to a stub that loads nothing. BSD sockets are imported: the PSP network modules (`sceNet`, ad hoc) are HLE over sockets. `ppsspp_enable_wlan` is off, so a game sees no network. The required-reason APIs it imports (`stat`, `lstat`, `statvfs`, `mach_absolute_time`) are already declared in `Sources/App/PrivacyInfo.xcprivacy`.

No Sony firmware, BIOS, font or game is read or bundled: PPSSPP's kernel is HLE. The test program `Sources/Debug/PSPTestELF.swift` is GagaEmu's own hand-assembled Allegrex ELF, which imports kernel functions by NID.

### Flycast licence obligations

Source: [github.com/flyinghead/flycast](https://github.com/flyinghead/flycast), tag `v2.7`, commit `5aa091fde632fb332c8d8c34e280d62dc951954c`, as the unmodified submodule `Cores/flycast/upstream`. The dependencies upstream takes from its own submodules are submodules under `Cores/flycast/deps`, each at the commit `v2.7` records. `FlycastCore.c`, `FlycastSupport.cpp`, `flags.h`, `include/glslang/build_info.h` and `Cores/shared/LibretroAdapter.c` and `LibretroVulkan.c` are GagaEmu's own files. It is built on branch `core/flycast`, kept out of release builds by `GAGA_CORE_SET`, and must not ship until the legal gate above closes. It also links MoltenVK, so the MoltenVK rows above apply. `Licences/notices.json` lists every text below.

| Part (as in `Cores/flycast/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `upstream/core` (SH-4, ARM7 and DSP interpreters, PVR, AICA, maple, GD-ROM, reios, Vulkan renderer, network stubs), `upstream/shell/libretro` | GPL-2.0-or-later (file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `core/deps/xbrz` | GPL-3.0, with the author's linking exception | Makes the combined binary GPL-3.0. Same source obligation. |
| `core/deps/picotcp` (compiled, unreachable: no BBA or modem) | GPL-2.0 or GPL-3.0 | As above. |
| `core/deps/chdpsr` | No notice; distributed under Flycast's licence | As above. |
| `upstream/fonts/biosfont.bin.zip` (embedded BIOS font) | Built from Sony 12x24rk (Sony attribution licence), jiskan24 (public domain), neep (GPL-2.0-or-later) | Keep the attributions in `biosfont.cpp`. Sony's licence text is not in the tree; the notice names it. |
| `deps/glslang` | BSD-3-Clause, BSD-2-Clause, MIT, Apache-2.0 (its `LICENSE.txt`; no Bison GPL part in 15.3.0) | Reproduce `LICENSE.txt`. |
| `deps/VulkanMemoryAllocator` | MIT | Reproduce the notice. |
| `deps/Vulkan-Headers` | Apache-2.0 OR MIT (headers only) | Ship either licence text. |
| `deps/libchdr` | BSD-3-Clause | Reproduce the notice. |
| zlib 1.3.1, zstd 1.5.6 (decompression only), LZMA SDK 24.05 (in `deps/libchdr/deps`) | zlib, BSD-3-Clause, public domain | Keep the zlib notice; reproduce the zstd notice. |
| `deps/asio` (headers), `core/deps/nowide` | BSL-1.0 | Reproduce the licence with source; none required for object code. Listed anyway. |
| `core/deps/libelf` | BSD-2-Clause (UNSW); `exec_elf.h` BSD (OpenBSD) | Reproduce the notices. |
| `core/deps/libretro-common`, `xxHash`, `stb_image`, GLM | MIT, BSD-2-Clause, MIT or public domain, MIT | Reproduce the notices. |
| `core/deps/md5` | Public domain (Solar Designer's MD5) | None. |

Not compiled: every recompiler (`core/rec-*`, `core/hw/sh4/dyna`, `core/hw/arm7/arm7_rec*`, `core/hw/aica/dsp_arm32`, `dsp_arm64`, `dsp_x64`, `dsp_x86`, vixl, xbyak), `core/linux/posix_vmem.cpp`, `common.cpp` and `unwind_info.cpp`, the GL renderers, libzip, 7-Zip, tinygettext, CMakeRC resources, miniupnpc, the Adreno loader and every Naomi printer font. `FORBIDDEN_SOURCES` refuses a framework that compiles any of them. `FlycastSupport.cpp` replaces the memory mapping with heap memory and software VRAM write tracking, embeds only the BIOS font, and turns every socket call into a refusal.

No Dreamcast BIOS, flash image or game is bundled or fetched. Without a player BIOS, upstream's HLE BIOS (reios) boots the disc. A player may put their own `dc_boot.bin` and `dc_flash.bin` in `GagaEmu/System/dc`; Flycast uses them when found.

### Beetle (Mednafen) and PokeMini licence obligations

Sources: the libretro repositories and commits in section 2, as unmodified submodules `Cores/<id>/upstream` for `beetle_pce_fast`, `beetle_supergrafx`, `beetle_vb`, `beetle_ngp`, `beetle_wswan` and `pokemini`. Each `<Core>Core.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. All six are built on branch `core/group-mednafen`, kept out of release builds by `GAGA_CORE_SET`, and must not ship until the legal gate above closes.

| Part (as in each `sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| Mednafen and libretro glue (PCE, SuperGrafx, VB, NeoPop, Cygne), including files with no header, where the repository `COPYING` (GPL-2.0) applies | GPL-2.0-or-later (file headers) | The complete corresponding source, with the written offer or the source alongside. This is the gate above. |
| PokeMini emulator, libretro glue and FreeBIOS | GPL-3.0-or-later (`LICENSE`, file headers) | As above, under GPL-3.0, including its installation-information terms for a user product. The submodule has the notice but not the full GPL-3.0 text; the app's licence page must carry it. |
| Blip_Buffer, Stereo_Buffer, T6W28 | LGPL-2.1-or-later | The notice and source, or relinkable objects. Met by the GPL source offer above. |
| Fuse Z80 core (NeoPop) | GPL-2.0-or-later | As the first row. |
| SoftFloat (Virtual Boy FPU) | SoftFloat release 2 terms (keep the notice) | Reproduce the notice. |
| `libretro-common`, dr_flac and other single-file libraries in the trees | MIT or public domain | Reproduce the MIT notice. |

No BIOS, system card or boot ROM is bundled. PC Engine CD needs the player's own `syscard3.pce` in `GagaEmu/System` and is refused without it. NeoPop and Cygne need no BIOS; PokeMini runs its own free BIOS and uses the player's `bios.min` only if present. The test programs in `Sources/Debug` (`PCETestROM`, `VBTestROM`, `NGPTestROM`, `WSTestROM`, `PMTestROM`) are GagaEmu's own hand-assembled code with no licence string from any console maker.

### Non-commercial cores and the sideload profile

Snes9x, Genesis Plus GX, PicoDrive and FinalBurn Neo have licences that forbid commercial use. They are built and wired as alternates, for **free sideload builds only**. They never enter an App Store or TestFlight build:

- Each one's `core.env` sets `CORE_NONCOMMERCIAL=1`. `scripts/generate-project.sh` leaves such a core out unless `GAGA_CORE_SET=sideload` (`docs/06` section 2.5).
- `scripts/nojit-gate.sh` fails a release build that names `sideload`, `vktest` or a `CORE_NONCOMMERCIAL=1` core in `GAGA_CORE_SET`, or that embeds such a framework. `scripts/appstore_release.sh` runs the same check. `scripts/test-release-gate.sh` proves the gate on a throwaway tree and fails if a core in its list loses the flag.
- A left-out core keeps a refusing stub in the registry, and `CoreCatalog` hides it. The 32X platform has only PicoDrive, so it is hidden too, and import places no `.32x` file in a build without it.
- **The sideload build sells nothing.** `GAGA_CORE_SET=sideload` sets the `GAGA_SIDELOAD` compilation condition, which compiles out StoreKit, the product IDs, the Gaga Plus paywall, every purchase and restore path, the Gaga Plus settings pane and the App Store review row. Every premium feature is free (`StoreKitManager.entitlements` is premium and lifetime). A sideload build with `PAYWALL_ENABLED` does not compile. The app's build step (`scripts/nojit-gate.sh`, run by hand as `--sideload-app <App.app>`) fails a sideload app whose binary, debug dylib or test bundle links a StoreKit library or imports a StoreKit symbol (`otool -L` and `nm -u`). The App Store build is unchanged.
- Each is an alternate, never a default, and carries the note "Sideload" in the core sheet.

**Owner decision, needs counsel: the sideload build must be free of any commercial activity.** Genesis Plus GX and PicoDrive forbid use "in a commercial product or activity", Snes9x forbids "charging money for Snes9x or software derived from Snes9x", and FB Neo forbids seeking "monetary profit" and asking for donations "for any project that uses" it. The sideload build now has no paywall, no StoreKit and no purchase path (above). That does not settle FB Neo: its no-monetary-profit and no-donations terms cover "any project that uses" it, so the paid App Store build of the same project, Gaga Plus included, may still breach them even though FB Neo never ships in it. **Still open for the owner and counsel, not decided here:** whether a free sideload build that includes FB Neo is allowed at all while the App Store build is paid, and whether FB Neo must be dropped. The other three licences need the same answer for a free build of a paid app. Until then no sideload build is distributed to anyone.

The exact operative wording, from the pinned trees:

**Snes9x** (`Cores/snes9x/upstream/LICENSE`):

> Permission to use, copy, modify and/or distribute Snes9x in both binary and source form, for non-commercial purposes, is hereby granted without fee, providing that this license information and copyright notice appear with all copies and any derived work.
>
> Snes9x is freeware for PERSONAL USE only. Commercial users should seek permission of the copyright holders first. Commercial use includes, but is not limited to, charging money for Snes9x or software derived from Snes9x, including Snes9x or derivatives in commercial game bundles, and/or using Snes9x as a promotion for your commercial product.

Its header also states "(Under no circumstances will commercial rights be given)". A free build that ships the licence text and notices meets the grant.

**Genesis Plus GX** (`Cores/genesis_plus_gx/upstream/LICENSE.txt`) and **PicoDrive** (`Cores/picodrive/upstream/COPYING`) use the same terms:

> Redistribution and use of this code or any derivative works are permitted provided that the following conditions are met:
>
> \* Redistributions may not be sold, nor may they be used in a commercial product or activity.
>
> \* Redistributions that are modified from the original source must include the complete source code, including the source code for all components used by a binary built from the modified sources. However, as a special exception, the source code distributed need not include anything that is normally distributed (in either source or binary form) with the major components (compiler, kernel, and so on) of the operating system on which the executable runs, unless that component itself accompanies the executable.
>
> \* Redistributions must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

GagaEmu builds both unmodified, but links them with its own bridge into one framework. Counsel to say whether that is a modified redistribution; if so, the sideload build ships the complete source, which the GPL cores already require.

PicoDrive also compiles two parts with their own terms:

- **FAME/C** (`cpu/fame`, the 68000), `fame.html`: "FAME may be distributed freely in unmodified form, as long as this document file is included. Nothing may be charged for this library. If you want to use it in a shareware or commercial application, contact me." It also asks every program that uses FAME to credit it in its documentation or program. **Risk:** PicoDrive's copy is modified (the file's own change log says so), and the grant covers only unmodified copies. Counsel to decide; the licence text and credit ship in the notices.
- **CZ80** (`cpu/cz80`, the Z80), `readme.txt`: "The emulator can be freely distribued and used for any non commercial project as long you don't forget to credit me somewhere". The credit ships in the notices.
- The MAME SH-2 interpreter (`cpu/sh2/mame`) carries the old MAME non-commercial terms in its header comment, shipped in the notices.

**FinalBurn Neo** (`Cores/fbneo/upstream/src/license.txt`, Latin-1; shipped verbatim as the licence asks):

> You may freely use, modify, and distribute both the FB Neo source code and binary, however the following restrictions apply to the FB Neo original material (see below for a list of libraries with differing licenses, please consult their respective documentation for more information):
>
> \- You may not sell, lease, rent or otherwise seek to gain monetary profit from FB Neo;
> \- You must make public any changes you make to the source code;
> \- You must include, verbatim, the full text of this license;
> \- You may not distribute FB Neo with ROM images unless you have the legal right to distribute them;
> \- You may not ask for donations to support your work on any project that uses the FB Neo source code.

**Risk:** the donation clause covers "any project that uses" FB Neo, not only the build that links it. Gaga Plus in the App Store build may count. Counsel to decide before any sideload build exists; dropping FBNeo is the fallback. No ROM image is distributed: the test set `GridleeTestSet` is GagaEmu's own generated data in MAME's free `gridlee` layout.

None of the four is skipped: each licence allows a free, non-commercial build that ships its notices. Each is built from its official libretro repository, pinned, with no recompiler (section 3), and `Licences/notices.json` lists every compiled licence text.

**Source audit.** `scripts/build-core.sh` greps every compiled file for `PROT_EXEC`, `MAP_JIT`, `vm_protect`, `mach_vm_remap`, `__clear_cache`, `sys_icache_invalidate` and `pthread_jit`, and fails on a hit. A `core.env` may list reviewed hits by file and line in `SOURCE_AUDIT_REVIEWED`, each with a comment saying why it never runs. Snes9x and Genesis Plus GX have no hit: their CPUs are interpreters and their trees have no recompiler. PicoDrive's hits are all in `platform/libretro/libretro.c`, glue for the SH-2 and SVP recompilers that this build leaves out. SwanStation's are in `common/memory_arena.cpp` and libretro-common `memmap.c`, which add execute permission only when asked, and no caller asks. Where dead glue would still import a code-generation call, a `-include` header renames it to a stub in the core's own bridge file, so no upstream file is patched: `mprotect`, `sys_icache_invalidate` and `sys_dcache_flush` in PicoDrive; `sem_open` and `pthread_create` in FBNeo (its `thready.h` worker falls back to one thread); `dlopen`, `dlsym`, `dlclose`, `shm_open` and `shm_unlink` in SwanStation, whose `mprotect` stub refuses execute permission and passes read and write through.

### SwanStation licence obligations

Source: [github.com/libretro/swanstation](https://github.com/libretro/swanstation) at master commit `631f0fb31b809e0f889d7c551fe695788e39c1d3` (2026-10-24), as the unmodified submodule `Cores/swanstation/upstream`. It is the GPL-3.0 libretro fork of DuckStation from before DuckStation's CC-BY-NC-ND change. `SwanStationCore.c`, `no_exec.h`, `gen/config.h`, `gen/version.h` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. It is not non-commercial, so it is in the default core set; the GPL legal gate above still applies.

| Compiled part (131 upstream files in `sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `src/core`, `src/common`, `src/libretro` | GPL-3.0 (`LICENSE`) | Complete corresponding source, with the offer or the source alongside. This is the gate above. |
| `dep/openbios` (`openbios.bin.h`, a built OpenBIOS image from PCSX-Redux) | MIT | Reproduce the notice. It is a prebuilt binary inside the tree; its source is PCSX-Redux's `src/mips/openbios`. Counsel to confirm a prebuilt MIT image meets the GPL corresponding-source duty. |
| `dep/libchdr`, with LZMA SDK, miniz and Zstandard | BSD-3-Clause, public domain, MIT, BSD | Reproduce the notices. |
| `dep/xxhash` | BSD-2-Clause | Reproduce the notice. |
| `dep/stb` (`stb_image`, `stb_image_resize`) | MIT or public domain | Reproduce the notice. |
| `dep/glad`, `dep/vulkan-loader` (Khronos headers) | Generated loader; MIT-style Khronos header; Apache-2.0 Vulkan headers | Reproduce the notices and the Apache-2.0 text. |
| `dep/libretro-common` | MIT | Reproduce the notice. |

No Sony BIOS is bundled or fetched. With none in `GagaEmu/System`, the core boots the embedded OpenBIOS. It only takes a BIOS file whose hash it knows, so another system's 512 KiB BIOS (Saturn) is never used. Two limits found on the macOS harness: upstream starts a PS-EXE by patching a Sony BIOS at fixed offsets, so `.exe` files reach OpenBIOS's shell and do not run; and OpenBIOS did not boot the homebrew test disc, which has no licence sector. A player's own `scph5500.bin`, `scph5501.bin` or `scph5502.bin` (BIOS Files screen) runs both. Commercial discs on OpenBIOS are untested.

### Gearsystem licence obligations

Source: [github.com/drhelius/Gearsystem](https://github.com/drhelius/Gearsystem), the author's repository and the one libretro-super builds, tag 3.9.24, commit `40b8eebab53007c976eb29755b1ef7925140c37f`, as the unmodified submodule `Cores/gearsystem/upstream`. `Cores/gearsystem/GearsystemCore.c`, `nofm.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/gearsystem/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `src` (Z80, VDP, mappers, I/O, link cable, YM2413 wrapper) and `platforms/libretro` | GPL-3.0-or-later (file headers; `LICENSE` is the GPL-3.0 text) | The complete corresponding source of the whole work, with the written offer or the source alongside, and no added restrictions. This is the gate above. |
| `src/audio/Blip_Buffer.cpp`, `Sms_Apu.cpp`, `Stereo_Buffer.cpp` (Shay Green) | LGPL-2.1-or-later | Satisfied by the GPL source release; counsel to confirm. |
| `platforms/shared/dependencies/miniz/miniz.c` | MIT | Reproduce the notice. |

Not compiled: `src/audio/emu2413/emu2413.c`, the YM2413 FM emulation. It is Jarek Burczynski's MAME `ym2413.c` by way of Genesis Plus GX and its header states no licence, so `Cores/gearsystem/nofm.c` stands in with empty functions: FM music (Japanese Master System games only) is silent, the PSG plays. Also not compiled: the disassembler and VGM recorder (`GS_DISABLE_DISASSEMBLER`, `GS_DISABLE_VGMRECORDER`, as upstream's libretro makefile sets) and every desktop, iOS and imgui frontend. No socket, `dlopen` or thread is imported; the link cable runs two instances in one process.

No BIOS or game is bundled. The `gearsystem_bios_sms` and `gearsystem_bios_gg` options stay "Disabled", so no Sega boot ROM is read. The test ROM `Sources/Debug/SMSTestROM.swift` is GagaEmu's own hand-assembled Z80 program.

### Stella licence obligations

Source: [github.com/stella-emu/stella](https://github.com/stella-emu/stella), the Stella team's repository, whose `src/os/libretro` is the target libretro-super builds as `stella`, tag 7.0c, commit `c4016ea4891cb0f90979cb35182214af4c1cb4e7`, as the unmodified submodule `Cores/stella/upstream`. `Cores/stella/StellaCore.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/stella/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `src/emucore` (6507, TIA, RIOT, every cartridge scheme, Thumbulator, CortexM0, ELF), `src/common`, `src/os/libretro` | GPL-2.0-or-later (`Copyright.txt`; `License.txt` is the GPL-2.0 text) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `src/common/tv_filters/AtariNTSC.cxx` (Blargg's NTSC filter, updated) | LGPL-2.1-or-later (`AtariNTSC.hxx`) | Satisfied by the GPL source release; counsel to confirm. |
| `src/lib/json` (nlohmann JSON, headers) | MIT | Reproduce the notice. |

Not compiled or not reachable: `HTTP_LIB_SUPPORT` is not defined, so PlusROM carts get no network and `lib/httplib` is never included; no GUI, debugger, image or SQLite support is defined, so `lib/sqlite` is not compiled. `FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym` and `mprotect`. `pthread_create` is imported by `EmulationWorker`, which the libretro target does not start.

No BIOS or game is bundled; the 2600 has no BIOS. The test cartridge `Sources/Debug/Atari2600TestROM.swift` is GagaEmu's own hand-assembled 6502 program.

### ProSystem licence obligations

Source: [github.com/libretro/prosystem-libretro](https://github.com/libretro/prosystem-libretro), libretro's port of Greg Stanton's ProSystem, commit `8a88014287c7a01cd568067e5a557d0a2b2a051f` (upstream has no tags), as the unmodified submodule `Cores/prosystem/upstream`. `Cores/prosystem/ProSystemCore.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/prosystem/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `core/` (Sally 6502, MARIA, TIA, POKEY, RIOT, cartridge, database, libretro glue) | GPL-2.0-or-later (file headers; `License.txt` is the GPL-2.0 text) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `bupboop/coretone` (BupChip audio) | zlib (`bupboop/License.txt`) | Keep the notice; mark altered sources (none are altered). |
| `libretro-common` (compat, file, streams, string, time, vfs) | MIT | Reproduce the notice. |

Not compiled or not reachable: `.cdf` loading reads loose files named by the descriptor, but the app only offers `.a78`. `FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym`, `mprotect` and `pthread_create`.

No BIOS or game is bundled. The 7800 BIOS is optional: upstream opens `7800 BIOS (U).rom` (or `(E)` for a PAL cart) from the system folder if the player put one there, and boots the cart directly otherwise. The test cartridge `Sources/Debug/Atari7800TestROM.swift` is GagaEmu's own hand-assembled 6502 program.

### Handy licence obligations

Source: [github.com/libretro/libretro-handy](https://github.com/libretro/libretro-handy), libretro's port of K. Wilkins' Handy, commit `bc55d462f0b2d6b073ea93dc552ebd73cec60fd1` (upstream has no tags), as the unmodified submodule `Cores/handy/upstream`. `Cores/handy/HandyCore.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/handy/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `lynx/` (65C02, Mikey, Suzy, cart, EEPROM, loader decryption), `libretro/` | Zlib (`lynx/license.txt`) | Keep the notice; mark altered sources (none are altered). |
| `blip/` (Blip_Buffer, Stereo_Buffer) | LGPL-2.1-or-later (file headers) | Statically linked, so the player must be able to relink: satisfied by the source release the GPL cores already need; counsel to confirm. |
| `libretro-common` (compat, file, streams, string, time, vfs) | MIT | Reproduce the notice. |

`FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym`, `mprotect` and `pthread_create`. `stat` is imported (libretro-common's `path_is_valid`, for the boot ROM); it is covered by the app's File Timestamp reason C617.1.

No boot ROM or game is bundled. `lynxboot.img` is the player's: upstream opens it from the system folder and otherwise emulates the boot ROM's loader (HLE), which still needs the cart's own signed loader. The BIOS Files screen lists it as optional. The test program `Sources/Debug/LynxTestROM.swift` is GagaEmu's own hand-assembled 65C02 in the BS93 homebrew format; it uses no Atari key.

### Atari800 licence obligations

Source: [github.com/libretro/libretro-atari800](https://github.com/libretro/libretro-atari800), libretro's port of Atari800, commit `4e7fbc73765c1a9670c7506616046ad1d4ccda51` (upstream has no tags), as the unmodified submodule `Cores/atari800/upstream`. `Cores/atari800/Atari800Core.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/atari800/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `atari800/src` (6502, ANTIC, GTIA, POKEY, PIA, SIO, cartridges, disks, tape), `libretro/` | GPL-2.0-or-later (`atari800/COPYING`, file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `atari800/src/roms/altirra*.c` (AltirraOS XL/XE, 400/800 and 5200 kernels, Altirra BASIC, 5200 charset) | All-permissive (FSF), Avery Lee | Keep the copyright notice and the permission notice. |
| `deps/zlib` | Zlib | Keep the notice. |
| `libretro/libretro-common` (compat, file, streams, string, time, vfs) | MIT | Reproduce the notice. |

`FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym`, `mprotect` and `pthread_create`; the R: device stays off. The P: printer device is turned off by the bridge, so no print file is written, and `atari800_cfg` stays disabled, so no `atari800.cfg` is written. `stat`, `opendir` and `readdir` are imported (the system-folder ROM scan); `stat` is covered by the app's File Timestamp reason C617.1.

No Atari ROM or game is bundled; the AltirraOS replacements are free software. Atari's own `5200.rom`, XL/XE OS (`atarixl.rom`), 400/800 OS and BASIC are the player's: upstream scans the system folder for them by checksum, under any name, and uses AltirraOS otherwise. The BIOS Files screen lists `5200.rom` and `atarixl.rom` as optional. The test programs `Sources/Debug/Atari800TestROM.swift` are GagaEmu's own hand-assembled 6502.

### Virtual Jaguar licence obligations

Source: [github.com/libretro/virtualjaguar-libretro](https://github.com/libretro/virtualjaguar-libretro), libretro's Virtual Jaguar, tag `v3.11.0`, commit `34696082dbc0448caf23aa4ecb5ed40817cb8da0`, as the unmodified submodule `Cores/virtualjaguar/upstream`. `Cores/virtualjaguar/VirtualJaguarCore.c`, `bios_stub.c`, `nonet_*.c`, `version.h` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/virtualjaguar/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `src` (68000, TOM, JERRY, blitter, Object Processor, CD, EEPROM), `libretro.c` | GPL-3.0-or-later (`LICENSE`, file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `deps/libchdr` (`unity.c`) | BSD-3-Clause | Keep the notice. |
| libchdr's zstd | BSD-3-Clause (dual GPL-2.0) | Keep the notice. |
| libchdr's miniz | MIT | Keep the notice. |
| libchdr's LZMA SDK | Public domain | None. |
| `libretro-common` | MIT | Reproduce the notice. |

Upstream's `src/bios/jag*.c` embed Atari's boot ROMs and are never compiled: `bios_stub.c` gives zeroed arrays of the same names, and `FORBIDDEN_SOURCES` in `core.env` fails the build if any of those files reaches the binary. JagLink TCP/UDP and the GDB stub are built from their socketless branches through `nonet_*.c`, and `FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym`, `mprotect` and `pthread_create`. The bridge keeps netlink, voice chat, the GDB stub, texture dump and replace, and JGD off. `stat`, `lstat`, `opendir`, `readdir` and `localtime` are imported (libretro-common and the CD path); `stat` and `lstat` are covered by the app's File Timestamp reason C617.1.

No boot ROM or game is bundled. Carts start by HLE; `jagboot.rom` is the player's and optional on the BIOS Files screen (the bridge leaves the BIOS option off). The test program `Sources/Debug/JaguarTestROM.swift` is GagaEmu's own hand-assembled 68000.

### VICE licence obligations

Source: [github.com/libretro/vice-libretro](https://github.com/libretro/vice-libretro), libretro's port of VICE 3.10, commit `5ebe7d333ab15be57a9dde5f46c29a5bbd5f44f8` (upstream has no tags), as the unmodified submodule `Cores/vice/upstream`, built as x64sc. `Cores/vice/ViceCore.c`, `vice_embedded.c`, `vice_sysfile.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/vice/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `vice/src` (6510, VIC-II, CIA, SID with reSID and reSID-fp, drives, cartridges, tape), `libretro/`, `retrodep/` | GPL-2.0-or-later (`COPYING`, file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `vice/src/lib/p64` | Zlib (Benjamin Rosseaux) | Keep the notice. |
| `libretro/libretro-dc.c` | MIT | Reproduce the notice. |
| `deps/libz` | Zlib | Keep the notice. |
| `deps/7zip` | Public domain | None. |
| `libretro-common` | MIT | Reproduce the notice. |

Upstream compiles Commodore's KERNAL, BASIC, character and drive ROMs into the core (`include/embedded/*.h`, through `retrodep/embedded.c` and `retrodep/embedded/c64embedded.c`). GagaEmu builds neither file: `vice_embedded.c` answers "not embedded", `include/embedded` is not on the include path, and `FORBIDDEN_SOURCES` fails the build if any of them reaches the binary. A byte check of the built framework finds no KERNAL bytes. `vice_sysfile.c` builds upstream's `sysfile.c` so the player's ROM files are also found at the top of the system folder, where the BIOS Files screen lists them. `config.h` undefines `HAVE_NETWORK`, and `FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym`, `mprotect` and `pthread_create`. `stat`, `access`, `opendir`, `readdir` and `localtime` are imported; `stat` is covered by the app's File Timestamp reason C617.1.

No Commodore ROM or game is bundled. The player adds `kernal-901227-03.bin`, `basic-901226-01.bin` and `chargen-901225-01.bin` on the BIOS Files screen; without them the bridge refuses the game with a message, because upstream crashes. Upstream makes `<system>/vice` and writes its defaults there once (`vicerc-dump-C64SC`). Disk images are write-protected, so the player's files are never changed. The test cartridge `Sources/Debug/C64TestROM.swift` is GagaEmu's own hand-assembled 6502; the tests' stand-in ROM files are all zeros and never run.

### PUAE licence obligations

Source: [github.com/libretro/libretro-uae](https://github.com/libretro/libretro-uae), libretro's port of WinUAE/E-UAE (`VERSION` 5.3.1), commit `c1d1d49d5c7cdad2005e86f1cbb279d39e041efc` (upstream has no tags), as the unmodified submodule `Cores/puae/upstream`. `Cores/puae/PuaeCore.c`, `puae_stubs.c`, `puae_fpp_native.c`, `puae_cpuboard.c`, `puae_dlopen.c`, `retrodep/WHDLoad_*.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/puae/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `sources/src` (68000 interpreter, chipset, floppy, hard file, CD), `libretro/`, `retrodep/`, `deps/libmpeg2` | GPL-2.0-or-later (`COPYING`, file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `sources/src/aros.rom.c` (AROS Kickstart replacement, a ROM image built from AROS) | AROS Public License 1.1 (MPL-1.1 based) | Keep the notice and say where the AROS source is ([aros-development-team/AROS](https://github.com/aros-development-team/AROS)). Gate item: confirm the APL's source and notice terms for a binary-only image. |
| `sources/src/softfloat`, `fpp_softfloat.c` | SoftFloat-2a, BSD-3-Clause (Fabrice Bellard), GPL-2.0-or-later | Reproduce the SoftFloat and BSD notices. |
| `sources/src/archivers/mp2` (kjmp2) | Zlib | Keep the notice. |
| `sources/src/archivers/lha` (LHa for UNIX) | Not stated in the tree (authors named in headers) | Gate item: the LHa for UNIX licence text is not in the upstream tree; confirm its terms or drop LHA archive support. |
| `sources/src/archivers/dms` (xDMS), `deps/7zip` | Public domain | None. |
| `sources/src/dsp3210`, other `archivers` | GPL-2.0-or-later (no header; the whole is GPL) | As the first row. |
| `libretro/libretro-dc.c` | MIT | Reproduce the notice. |
| `deps/libz` | Zlib | Keep the notice. |
| `deps/libchdr`, `deps/zstd` | BSD-3-Clause | Reproduce the notice. |
| `libretro-common` | MIT | Reproduce the notice. |

Upstream also compiles WHDLoad's Amiga-side files (`retrodep/WHDLoad_files.zip.c`, `WHDLoad_prefs.gz.c`) and the HRTmon cartridge ROM (`sources/src/hrtmon.rom.c`), whose licences are unclear. GagaEmu builds empty stand-ins instead (`Cores/puae/retrodep/`, `puae_stubs.c`), and `FORBIDDEN_SOURCES` fails the build if the upstream files reach the binary. So `.lha` WHDLoad games are not offered. Three upstream files are wrapped after the source audit: `fpp_native.c` (its x87 code is never compiled on arm64), `cpuboard.c` (it switches a map-ROM area between read-only and read-write only for the JIT cache) and `caps/uae_dlopen.c` (built with `HAVE_DLOPEN` cleared, so the capsimg plug-in for IPF images is never loaded and IPF images do not load). `retrodep/mman.c`, which reserves memory for the JIT, is not built; `puae_stubs.c` keeps its one shared variable at 0. `FORBIDDEN_IMPORTS` refuses sockets, `getaddrinfo`, `dlopen`, `dlsym` and `mprotect`; `pthread_create` and named semaphores (`sem_open`) are used by the hard-file, CD and serial threads. `stat`, `opendir`, `readdir`, `localtime`, `mkdir`, `rename` and `unlink` are imported; `stat` is covered by the app's File Timestamp reason C617.1.

No Kickstart ROM or game is bundled. The core boots on AROS when no Kickstart is in the system folder; `kick34005.A500` and `kick40068.A1200` are the player's and optional on the BIOS Files screen. Floppies are write-protected and shared NVRAM is off, so the player's files are never changed; a host harness run left the system and save folders empty. The test floppy `Sources/Debug/AmigaTestROM.swift` is GagaEmu's own hand-assembled 68000 bootblock.

### PrBoom licence obligations

Source: [github.com/libretro/libretro-prboom](https://github.com/libretro/libretro-prboom), libretro's PrBoom (`v2.5.0`, with Heretic and Hexen support), commit `4849268e7342494193f2bbf2d0128a751cf58da7` (upstream has no tags), as the unmodified submodule `Cores/prboom/upstream`. `Cores/prboom/PrboomCore.c`, `prboom_memmap.c` and `Cores/shared/LibretroAdapter.c` are GagaEmu's own files. Built on branch `core/group-retro`, kept out of release builds by `GAGA_CORE_SET`; it must not ship until the legal gate above closes.

| Part (as in `Cores/prboom/sources.txt`) | Licence | What it asks of a binary release |
|---|---|---|
| `src` (Doom engine, `heretic/`, `hexen/`, `udmf.c`, DOSBox OPL `dbopl.c`, `opl.c`, Nuked-SC55 `sc55.c`), `libretro/libretro.c`, and `prboom.wad` compiled in as `src/prboom_wad_data.h` | GPL-2.0-or-later (`COPYING`, file headers) | The complete corresponding source of the whole work, with the written offer or the source alongside. This is the gate above. |
| `src/sc88.c` (Roland SC-88 emulation, from gearmulator) | GPL-3.0-or-later | Makes the combined core GPL-3.0-or-later: the GPL-3.0 text, and the gate above under version 3. |
| `src/u_mapinfo.c` | LGPL, version 2 or later | Keep the notice and the LGPL text; the source is offered with the rest. |
| `src/scanner.c`, `src/u_scanner.c` | BSD-3-Clause (Braden Obrzut) | Reproduce the notice. |
| `libretro-common/formats/mod/rmodtracker.c` (micromod) | BSD-3-Clause (Martin Cameron) | Reproduce the notice. |
| `libretro-common/formats/vorbis/rvorbis.c`, `mp3/rmp3.c` | Derived from stb_vorbis (public domain or MIT) and minimp3 (CC0); the files carry no header | None beyond libretro-common's MIT notice. |
| `libretro-common` (rest) | MIT | Reproduce the notice. |

libretro-common's `memmap/memmap.c` is not built: it also holds helpers that map executable memory (`memprotect`, `memjit_alloc`). `prboom_memmap.c` gives its six address-reservation functions upstream's own answers for a platform without reservation, so `data_transfer.c` reads whole files, and `FORBIDDEN_SOURCES` fails the build if memmap.c reaches the binary. Built without `HAVE_THREADS`, so `rthreads` is not compiled, the threaded renderer and the SC-55/SC-88 workers run inline, and `FORBIDDEN_IMPORTS` refuses `pthread_create` with sockets, `dlopen`, `dlsym` and `mprotect`. FluidSynth (`WANT_FLUIDSYNTH`) is off, as upstream's default. `stat`, `opendir`, `readdir`, `mmap` (read-only, for WAD mapping, off by default), `mkdir`, `rename`, `remove`, `unlink` and `utimes` are imported; `stat` is covered by the app's File Timestamp reason C617.1.

No game WAD is bundled: neither id Software's nor Freedoom's. The SC-55 and SC-88 synthesisers run only from Roland ROM files the player supplies (`sc55player.c` looks for them by name); none are bundled. Upstream writes `prboom.cfg` and savegames under `<save>/<game name>/`. The test IWAD `Sources/Debug/DoomTestWAD.swift` is GagaEmu's own: a one-room map, a palette, stripes and a square-wave sound, with no id Software or Freedoom lump.

### Azahar licence obligations

Source: [github.com/azahar-emu/azahar](https://github.com/azahar-emu/azahar), tag `2126.2`, commit `219d743a1e698101fe1ab8bef43e6563126c3c27`, as the unmodified submodule `Cores/azahar/upstream`, with the 22 nested submodules that tag records checked out at their recorded commits. Dynarmic is not checked out; the `tsl::robin_map` headers it would supply come from the submodule `Cores/azahar/deps/robin-map` ([Tessil/robin-map](https://github.com/Tessil/robin-map), `054ec5ad`, v1.3.0-6, MIT). `AzaharCore.c`, `AzaharSupport.cpp`, `flags.h`, `generate.py`, `cmake/tsl-robin-mapConfig.cmake` and the shared adapter files are GagaEmu's own. Built on branch `core/azahar`, kept out of release builds by `GAGA_CORE_SET`, and must not ship until the legal gate above closes. It links MoltenVK, so the MoltenVK rows above apply. `Licences/notices.json` lists every text below.

| Part (as in `Cores/azahar/sources.txt`) | Pin | Licence | What it asks of a binary release |
|---|---|---|---|
| `upstream/src` (dyncom ARM11 interpreter, HLE services, audio, PICA200 shader interpreter, Vulkan and software renderers, `citra_libretro`) | `219d743` | GPL-2.0-or-later file headers, with `core.cpp` and `perf_stats.cpp` GPL-3.0-or-later; `license.txt` at this tag is GPL-2.0, upstream master is GPL-3.0 | The combined binary is GPL-3.0-or-later. Complete corresponding source; this is the gate above. |
| `nfc/amiibo_crypto.cpp` (part from amiitool) | in tree | MIT | Reproduce the notice. |
| `externals/boost` (azahar-emu/ext-boost; serialization, iostreams, date_time parts compiled) | `6a85c310` | BSL-1.0 | None for object code. Listed anyway. |
| `externals/cryptopp` (cryptopp-modern) | `8d92d788` | BSL-1.0 for the compilation, files public domain | Reproduce `LICENSE`. |
| `externals/fmt` | `e424e3f2` | MIT | Reproduce the notice. |
| `externals/faad2` | `216f00e8` | GPL-2.0-or-later, with Ahead Software's no non-GPL use clause | Same source obligation; compatible with the GPL-3.0 whole. |
| `externals/soundtouch` | `9ef8458d` | LGPL-2.1 | Statically linked: relinkable object files or the source, which the GPL source offer covers. |
| `externals/teakra` | `3d697a18` | MIT | Reproduce the notice. |
| `externals/zstd` | `f8745da6` | BSD-3-Clause (dual GPL-2.0) | Reproduce the notice. |
| `externals/enet` (compiled, unreachable: sockets refused) | `2662c0de` | MIT | Reproduce the notice. |
| `externals/libressl` (ext-libressl-portable; crypto and ssl for httplib and `RAND_bytes`) | `88b8e41b` | OpenSSL, SSLeay and ISC (`COPYING`) | Reproduce `COPYING`, with its advertising clause wording. |
| `externals/lodepng` | `0b1d9ccf` | zlib | Keep the notice. |
| `externals/glslang` (GLSL to SPIR-V for the vertex and geometry paths; no optimizer, `ENABLE_OPT=OFF`) | `fc9889c8` | BSD-3-Clause, BSD-2-Clause, MIT, Apache-2.0 | Reproduce `LICENSE.txt`. |
| `externals/sirit` (SPIR-V emitter for fragment shaders) | `37d49d2a` | BSD-3-Clause | Reproduce the notice. |
| `externals/spirv-headers`, `vulkan-headers`, `vma` (headers) | `aa6cef19`, `409c16be`, `c788c521` | MIT-style Khronos, Apache-2.0 OR MIT, MIT | Reproduce the notices. |
| `externals/xxHash`, `dds-ktx`, `nihstro` | `e626a72b`, `c3ca8feb`, `f4d8659d` | BSD-2-Clause | Reproduce the notices. |
| `externals/libretro-common` | `7fc7feed` | MIT | Reproduce the notice. |
| `externals/library-headers` (FFmpeg 6.0 headers; the decoder loader finds no library on iOS) | `3b3e28db` | LGPL-2.1-or-later | Ship the LGPL text. |
| `externals/httplib`, `json` (headers in tree) | in tree | MIT | Reproduce the notice. |
| `externals/microprofile` (header, profiler off) | in tree | Unlicense (public domain) | None. |
| `externals/open_source_archives` (free shared font, Mii data, word and country lists) | in tree | Distributed with Azahar under its licence; generated by B3n30/citra_system_archives `0baa5f5` | As above. |

Not compiled: Dynarmic, oaknut, xbyak, every `shader_jit*` file, `src/core/arm/dynarmic`, the OpenGL renderer and glad, SPIRV-Tools, inih, cubeb, OpenAL, SDL, libusb, Discord RPC, cpp-jwt and the web service. `FORBIDDEN_SOURCES` refuses a framework that compiles any of the JIT or GL files.

No keys, firmware, system archives (other than the free ones above), shared font dump or game is bundled or fetched. `ENABLE_BUILTIN_KEYBLOB` is off. Only decrypted content runs: `.3ds`, `.cci`, `.cxi`, `.app` decrypted dumps, and `.3dsx`, `.elf` and `.axf` homebrew. `.cia` is not accepted: installing a title needs the player's keys and NAND, which GagaEmu does not handle. Network, online features, camera and microphone are off: socket and name lookup calls go to refusing stubs (`AzaharSupport.cpp`).

### App archive reader (LZMA SDK) and RAR

Import reads `.7z` with Igor Pavlov's [LZMA SDK](https://www.7-zip.org/sdk.html) 25.01 (2025-08-03), compiled into the app itself, not a core. The C decoder files in `Sources/Archive/LZMA` are copied unmodified from the FBNeo submodule, `Cores/fbneo/upstream/src/dep/libs/lib7z` at FBNeo commit `4cdb31f1729588fa42d4aa1c3d9ce2cdaed28618`; `7zVersion.h` records the version. To move the pin, copy the same file list from a newer official SDK and update this paragraph and `Licences/notices.json`. `Sources/Archive/GagaSevenZip.c` is GagaEmu's own bridge.

| Part | Licence | What it asks of a binary release |
|---|---|---|
| `Sources/Archive/LZMA` (`7zArcIn`, `7zDec`, `LzmaDec`, `Lzma2Dec`, `Bcj2`, `Bra`, `Bra86`, `BraIA64`, `Delta`, `7zCrc`, `7zCrcOpt`, `7zStream`, `7zBuf`, `7zAlloc`, `CpuArch` and headers) | Public domain, as each file header says | Nothing. `Licences/notices.json` lists it anyway. |

PPMd, AES and the encoders are not copied. RAR is not read: unrar's licence forbids using its code to recreate the RAR compression algorithm, which conflicts with the GPL cores, so import refuses a `.rar` with "RAR archives are not supported. Extract it or repack it as .zip or .7z."

### No-JIT gate

No JIT, no RWX and no dynarec in any shipped core. Each core build gets a gate, audited per core and not only at the end. iOS itself denies JIT; the gate catches a core that would depend on it. `docs/04` section 8 describes both parts:

- `scripts/nojit-gate.sh`, an `nm` and `strings` check as in `S3/scripts/ios/build-core.sh:45-54`, which refuses `_pthread_jit_write_protect_np`, `_sys_icache_invalidate`, `___clear_cache`, `_mach_vm_protect`, `_vm_protect` and each core's own string list in `Cores/<id>/core.env` (for example GNU Lightning, Dynarmic, Oaknut).
- `CodeGenCheck`, a check for code generation at runtime, which a symbol scan can miss.
- `FORBIDDEN_SOURCES` in `core.env`, for a core that ships its dynarec in the same tree. `scripts/build-core.sh` refuses the framework if any compiled source path in its dSYM matches. PCSX-ReARMed uses it for `new_dynarec`, `lightrec` and `lightning`, because its option help text names "lightrec" and "dynarec", so those words cannot be in `FORBIDDEN_STRINGS`. DOSBox Pure uses it for `core_dyn_x86`, `core_dynrec` and `dyn_cache.h`, for the same reason. Mupen64Plus-Next uses it for `new_dynarec`, `mupen64plus-rsp-paraLLEl`, `lightning`, GLideN64 and `glsm`. PPSSPP uses it for every JIT back end, code emitter and upstream `MemoryUtil.cpp`: its binary still names the type `ARM64XEmitter`, which upstream's vertex decoder cache derives from, so that name cannot be in `FORBIDDEN_STRINGS`.

---

## 6. Excluded, Research, Candidates and Backlog

### Excluded

Re-verified 2026-11-07 against each upstream. Snes9x, Genesis Plus GX, PicoDrive and FBNeo left this table: they are sideload-only alternates (section 3 and section 5). SwanStation left it too: it is a PS1 alternate.

| Core | Reason |
|---|---|
| Play! | [Requires JIT](https://raw.githubusercontent.com/jpd002/Play-/master/README.md): its iOS section says it "uses JIT code generation" and points to ways to enable JIT. Last push 2026-10-26 |
| FreeJ2ME | [Needs a Java runtime](https://raw.githubusercontent.com/hex007/freej2me/master/README.md) with AWT: its `PlatformGraphics` draws through `java.awt.Graphics2D` and `BufferedImage`. GPL-3.0, plus ObjectWeb ASM. No embeddable interpreter-only JRE with AWT was found for iOS. [miniJVM](https://github.com/digitalgust/miniJVM) runs on iOS as an interpreter, with an optional SLJIT JIT, but has only "a minimal bootstrap class library" and no `java.awt`. HotSpot `-Xint` still generates its template interpreter at startup. The libretro FreeJ2ME core needs the same JRE. Manic's FreeJ2ME uses CheerpJ, a proprietary runtime that needs a network connection |
| J2meJS ([Rosabis/J2meJS](https://github.com/Rosabis/J2meJS)) | Ships build output with no corresponding source, and mixes GPL-2.0-only phoneME classes with GPL-3.0 FreeJ2ME classes (section 4, Java ME). Its JS runtime passes the no-JIT test |
| Kronos | [Requires OpenGL 4.3 compute](https://docs.libretro.com/library/kronos/): the libretro page still says "It uses compute shaders and as such requires OpenGL 4.3". No Vulkan or software path. [FCare/Kronos](https://github.com/FCare/Kronos) last push 2026-11-06 |
| Citra | [Shut down in March 2024](https://pcgamer.com/software/nintendo-3ds-emulator-citra-taken-offline-as-collateral-damage-in-yuzu-settlement/). Azahar replaces it |
| Panda3DS | Fails the no-JIT rule. Its [CMake](https://raw.githubusercontent.com/wheremyfoodat/Panda3DS/master/CMakeLists.txt) builds Dynarmic (a recompiler) on x64 and arm64 and stops with "Currently unsupported CPU architecture" otherwise; there is no CPU interpreter. Last push 2026-10-04 |
| Mesen-S, Mesen2 | Both [archived](https://github.com/SourMesen/Mesen2) on GitHub; the Mesen2 README calls the repository "an archive of Mesen as it was around version 2.1.1 in mid-2025". GPL-3.0. Mesen2 is skipped: archived, no libretro target in the tree, and its SNES, NES and GB cores are already covered |
| DuckStation | [CC-BY-NC-ND](https://raw.githubusercontent.com/stenzek/duckstation/master/README.md): its README still forbids publishing modified versions. SwanStation is its GPL-3.0 fork |
| GLideN64 | GLES on iOS; not an accepted renderer path. ParaLLEl-RDP is the N64 renderer |
| EKA2L1 (Symbian) | [GPL-3.0](https://github.com/EKA2L1/EKA2L1). Renderer spike failed at `62f0180e` (`docs/07` 6.6): GLES on iOS is the only working backend, the Vulkan backend is a stub, and there is no software renderer. The dyncom interpreter was not the blocker |
| Yabause | Not selected. [yabause/yabause](https://github.com/yabause/yabause) last push 2024-03-09. Beetle Saturn is the Saturn core |
| Angrylion RDP | Not selected. CPU-side RDP (angrylion-rdp-plus last push 2025-01-05); ParaLLEl-RDP is the chosen path |
| JGenesis 32X | Not used for 32X. `backend/s32x-core/src/bootrom.rs` in JGenesis v0.14.1 embeds Sega's 32X SH-2 boot ROMs (`include_bytes!` of `sh2_master_boot_rom.bin` and `sh2_slave_boot_rom.bin`). `genesis-core` depends on `s32x-core`, so both files, 2,048 and 1,024 bytes, were found byte for byte in the built `JgenesisCore` (ios-arm64, checked 2026-11-07). Shipping Sega boot code breaks the no-BIOS rule. Fixed the same day: `build-core.sh` compiles them as zeros and `scripts/bootrom-gate.py` refuses any binary that holds them (section 5, `docs/07` section 14). The app's no-JIT build step also runs it on every embedded framework, so a stale core framework in DerivedData cannot ship. PicoDrive covers 32X in sideload builds |

### Non-shipping research

Not in the App Store binary and not promised.

| Platform | Project | Facts |
|---|---|---|
| GameCube / Wii | Dolphin (GPL-2.0-or-later) | Has a [native Metal backend](https://raw.githubusercontent.com/dolphin-emu/dolphin/master/Source/Core/VideoBackends/CMakeLists.txt) and a No JIT mode, but the Cached Interpreter [cannot reach full speed at default settings](https://oatmealdome.me/?p=1695): Mario Kart Wii runs about 30 fps (50% speed) on iPhone 16 Pro Max. The DolphiniOS team says an App Store release is "simply not a good idea at the moment" |
| PS2 | Balero-S2 (sister project, `balero-s2`) | Its README describes a cached IR interpreter with `musttail` and NEON lowering. Not part of the GagaEmu binary; no performance data here |

### Candidates, not in the plan

These repos exist. **Licence and no-JIT status are unchecked for all of them, except where the Java ME row says otherwise.** None is adopted until both are checked and it passes section 5.

| Platform | Candidate |
|---|---|
| GBA | [NanoBoyAdvance](https://github.com/nba-emu/NanoBoyAdvance) |
| SNES | [bsnes-hd](https://github.com/DerKoun/bsnes-hd) |
| NES | [libretro Mesen](https://github.com/libretro/mesen) |
| Saturn | [Ymir](https://github.com/StrikerX3/Ymir) (URL redirects) |
| DOS | [dosbox-core](https://github.com/libretro/dosbox-core) |
| Arcade | [mame2003-plus](https://github.com/libretro/mame2003-plus-libretro). Older MAME licensing is a known concern; check before any use |
| PS2 (research only) | [ARMSX2](https://github.com/ARMSX2/ARMSX2) (GitHub reports GPL-3.0; no-JIT unchecked) |
| Java ME | Two candidates, checked by the 6.4 spike; neither is adopted.<br>[PluotSorbet](https://github.com/mozilla/pluotsorbet): licence and no-JIT checked. Adopting it means a port: a native browser-API shim for `JSContext` and a revived 2017 build (section 4).<br>[SquirrelJME](https://github.com/SquirrelJME/SquirrelJME) (MPL-2.0, NanoCoat C runtime, libretro target listing iOS): its own `route.mkd` still has the libretro frontend, GC and reference correctness, software `float`/`double`/`long` and save states open, and the last release is 0.2.0 (2018). Revisit when 0.4.0 ships |

### Backlog: seen in Manic listing, not planned for v1

Source: [App Store listing](https://apps.apple.com/us/app/manic-emu/id6743335790), with core names from the [public repo](https://github.com/Manic-EMU/ManicEMU/tree/main/Cores) where they could be matched by name. Core names are Manic's and are not GagaEmu picks.

- **Nintendo:** Famicom Disk System
- **Sega:** Master System, Game Gear (`gearsystem`), SG-1000, 32X
- **Atari:** 2600 (`stella`), 5200 (`atari800`), 7800 (`prosystem`), Jaguar (`virtualjaguar`), Lynx (`holani`)
- **Commodore:** C64 (`vice.x64sc`), Amiga (`puae`)
- **Other:** DOOM (`prboom`), Flash (core not identified), NAOMI / Atomiswave / System SP ([release notes](https://github.com/Manic-EMU/ManicEMU/releases))

**Taken up by group-retro** (branch `core/group-retro`, `docs/07` section 8.x; rows in section 2): Master System, Game Gear and SG-1000 (Gearsystem); Atari 2600 (Stella); Atari 7800 (ProSystem); Atari Lynx (Handy); Atari 5200 and Atari 8-bit (Atari800); Atari Jaguar (Virtual Jaguar); Commodore 64 (VICE x64sc); Amiga (PUAE); Doom WADs (PrBoom).

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

**Alternates added on branch `core/group-excluded`:** Snes9x (SNES), Genesis Plus GX (Mega Drive, Mega-CD; also `.sms`, `.gg` and `.sg` files, which open on the Mega Drive platform), PicoDrive (Mega Drive, Mega-CD, and the 32X platform), FinalBurn Neo (Arcade) and SwanStation (PS1). Each is last in its platform's list and never the default. FBNeo and MAME name some sets differently and want different set versions, so FBNeo is picked per game: a set that MAME refuses may load in FBNeo, and the player switches that game's core rather than the platform default. FBNeo takes `.zip` and `.7z` only; its Neo Geo CD formats stay out, because they need a CD BIOS.

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

Lookup is by `core_id` through `GagaCoreRegistry_FindByID`. mGBA comes from `MgbaCore.xcframework`, Gambatte from `GambatteCore.xcframework`, Nestopia from `NestopiaCore.xcframework`, PCSX-ReARMed from `PcsxReArmedCore.xcframework`, bsnes from `BsnesCore.xcframework`, melonDS DS (`melonds_ds`, `.nds`) from `MelonDSCore.xcframework`, JGenesis (`jgenesis`, `.md`, `.gen`, `.smd`, and Mega-CD `.cue` and `.bin`) from `JgenesisCore.xcframework`, DOSBox Pure (`dosbox_pure`) from `DosboxPureCore.xcframework`, MAME (`mame`, `.zip` and `.7z`) from `MameCore.xcframework`, Beetle Saturn (`beetle_saturn`, `.cue`, `.ccd`, `.chd`, `.toc`, `.m3u`) from `BeetleSaturnCore.xcframework`, PPSSPP (`ppsspp`, `.iso`, `.cso`, `.pbp` and `.elf`) from `PpssppCore.xcframework` and Flycast (`flycast`, `.gdi`, `.cdi`, `.chd` and `.cue`) from `FlycastCore.xcframework`. Each keeps a stub inside `#ifndef GAGA_HAS_<ID>`, used only by a build whose `GAGA_CORE_SET` leaves the core out, and the catalog then hides it (`docs/06` section 2.5). Everything else except the mock core is a stub whose `self_test` fails, so the app refuses to start it and says the core is not part of this build. This mGBA build is GBA only: it takes `.gba`, Gambatte takes `.gb` and `.gbc`, and Nestopia takes `.nes` (iNES and NES 2.0) only. PCSX-ReARMed takes `.cue`, `.bin`, `.img`, `.chd`, `.pbp`, `.iso`, `.m3u` and a bare PS-EXE `.exe`. Earlier rows also list two of them, the mock core `.bin` and JGenesis `.bin` and `.cue`, so `GagaCoreRegistry_FindByExtension` alone does not find PCSX-ReARMed for those. Only tests call that lookup; the Library picks the core through the platform, which is `ps1` for all of them. DOSBox Pure takes upstream's list less folders (`.zip`, `.dosz`, `.exe`, `.com`, `.bat`, `.iso`, `.chd`, `.cue`, `.ins`, `.img`, `.ima`, `.vhd`, `.jrc`, `.m3u`, `.m3u8`, `.conf`) and comes last in `s_core_getters`, so the shared ones find PCSX-ReARMed there and `.zip` finds MAME. `CoreCatalog.platformID(forFile:)` decides by content: an `.exe` is `ps1` only when it starts with `PS-X EXE`, otherwise `dos`; a `.zip` is placed by `CoreCatalog.zipPlatformID` from its central directory, nothing extracted: `dos` when it names an `.exe`, `.com`, `.bat` or `.conf`, otherwise `arcade` when the zip is named after a machine in `CoreCatalog.mameMachines` (`Sources/App/MameMachines.swift`, written by `Cores/mame/generate.py` from `drivers.flt`) or every entry has a ROM-like name (no extension, `.bin`, `.rom`, or an extension with a digit). A `.7z` is `arcade`. An `.elf` and a `.cso` are `psp`; a `.pbp` is `ps1` when its `DATA.PSAR` starts `PSISOIMG` or `PSTITLEIMG` (a PS1 disc), or when it is not a PBP at all, and otherwise `psp` (`CoreCatalog.pbpPlatformID`). A disc image (`.iso`, `.bin`, `.cue`, `.chd`, `.img`, `.m3u`) is placed by `CoreCatalog.discPlatformID` from its first 64 KiB: `psp` for `PSP GAME` as the sector 16 system ID of a 2048-byte image, `ps1` for `PLAYSTATION` as the sector 16 system ID or `SYSTEM.CNF` in the root, `saturn` for `SEGA SEGASATURN` opening the first sector, `dreamcast` for `SEGA SEGAKATANA` (the IP.BIN hardware ID) at byte 0 or 16, `megacd` for `SEGADISCSYSTEM` or any other `SEGA` there, otherwise `dos` for an ISO 9660 disc or any `.iso` or `.img`. A `.cue` is read through its first `FILE`, an `.m3u` through its first entry. A `.chd` is compressed; only its header and metadata are read, and a `CHGD` or `CHGT` (GD-ROM track) entry makes it `dreamcast`. A `.gdi` or `.cdi` is always `dreamcast`. When the contents do not say, Add Games asks the player which system the disc (PS1, Saturn, Mega-CD, DOS, Dreamcast) or `.zip` (Arcade, DOS) is for. The Multi-Disc Helper passes its own platform. `CoreCatalog` uses the same short lowercase `core_id` (`mgba`, `pcsx_rearmed`), the only ID scheme. `StateMigration` in `Sources/App/AppState.swift` upgrades older saved values.

### Storage (current code)

State persists as JSON at `Application Support/GagaEmu/state.json`, through `AppState.Snapshot`. It does not use SQLite or Core Data.

- **Per game:** `GameItem.coreOverride: String?`.
- **Per platform:** `AppState.defaultCores: [String: String]`, keyed by platform ID.
- **Resolution order:** `coreOverride`, then `defaultCores[platformID]`, then `CoreCatalog.defaultCore(for:)`, in `GameItem.resolvedCoreID(defaults:)`.
