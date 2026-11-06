# 03 — Core Matrix & Multi-Core Platform Catalog

Gaga-Emu adopts a multi-core architecture per platform. Users can assign a global default core for any system or override the core for individual titles by long-pressing a game cover in the library.

---

## 1. Master System & Core Taxonomy

```
   ┌──────────────────────────────────────────────────────────────────────────┐
   │                       GAGA-EMU MASTER CORE MATRIX                        │
   ├────────────────────┬──────────────────────┬──────────────────────────────┤
   │ System / Console   │ Primary Core         │ Alternative Cores & Purpose  │
   ├────────────────────┼──────────────────────┼──────────────────────────────┤
   │ Nintendo GBA       │ mGBA                 │ gpSP (speed), VBA-M (compat) │
   │ Nintendo GB / GBC  │ Gambatte             │ SameBoy (accuracy), Gearboy  │
   │ Nintendo SNES      │ Snes9x (fast)        │ bsnes (cycle-accuracy)       │
   │ Nintendo NES / FDS │ Nestopia UE          │ FCEUMM (broad mappers)       │
   │ Nintendo N64       │ Mupen64Plus-Next     │ Video: GLideN64 / ParaLLEl   │
   │ Nintendo DS        │ melonDS DS           │ DeSmuME (legacy hacks)       │
   │ Nintendo 3DS       │ Azahar               │ (PabloMK7 optimized interp)  │
   │ Sony PlayStation 1 │ PCSX-ReARMed (fast)  │ Beetle PSX HW, SwanStation   │
   │ Sony PSP           │ PPSSPP (IR Interp)   │ Native Metal Backend         │
   │ Sega Saturn        │ Beetle Saturn        │ Kronos (hardware rasterizer) │
   │ Sega Mega-CD       │ Genesis Plus GX      │ JGenesis, ClownMDEmu         │
   │ Sega Mega Drive    │ Genesis Plus GX      │ ClownMDEmu, Picodrive (32X)  │
   │ Sega Dreamcast     │ Flycast (JITLess)    │ Provenance SH-4 interpreter  │
   │ Arcade (CPS/NeoGeo)│ FBNeo                │ MAME (wide arcade catalog)   │
   │ MS-DOS / Win9x     │ DOSBox Pure          │ ZIP launch, controller maps  │
   ├────────────────────┴──────────────────────┴──────────────────────────────┤
   │ EXPERIMENTAL / SISTER ARCHITECTURE TARGETS                               │
   ├────────────────────┬──────────────────────┬──────────────────────────────┤
   │ Sony PlayStation 2 │ Balero-S2            │ Play! (pure C++ interpreter) │
   │ Nintendo GC / Wii  │ Dolphin iOS          │ Cached Interpreter           │
   └────────────────────┴──────────────────────┴──────────────────────────────┘
```

> **App Store Scope Isolation**: 7th and 8th-generation console architectures (`samba-s3` PS3, `bachata-s4` PS4) are strictly maintained in separate research repositories. They are not bundled in the Gaga-Emu App Store binary to guarantee compliance with App Store Rule 4.7 ("retro console emulators only") and prevent binary bloat.

---

## 2. In-Depth Multi-Core Analysis by System

### 2.1 Game Boy Advance (GBA)
- **`mGBA` (Primary)**:
  - *Strengths*: Highly accurate cycle timing, clean C99 architecture, native support for Game Boy Camera, solar sensor (Boktai), gyro sensors (WarioWare Twisted), and cartridge rumble.
  - *No-JIT Profile*: Fast direct interpreter; runs at full 60 FPS on all 64-bit iOS devices with negligible power draw.
- **`VBA-M` (Alternative — High Compatibility)**:
  - *Strengths*: Long-standing compatibility with thousands of older ROM hacks and translation patches that rely on imprecise emulator quirks.
- **`gpSP` (Alternative — Maximum Battery Savings)**:
  - *Strengths*: Originally built for low-power handhelds (PSP). Operates with the smallest CPU instruction footprint; ideal for maximum battery life on older iPhones.

### 2.2 Game Boy & Game Boy Color (GB / GBC)
- **`Gambatte` (Primary)**:
  - *Strengths*: State-of-the-art cycle-accurate video and audio emulation. Built-in color palettes for DMG games.
  - *No-JIT Profile*: Highly efficient C++ interpreter; negligible CPU usage.
- **`SameBoy` (Alternative — Audio & Boot Accuracy)**:
  - *Strengths*: Bit-perfect APU emulation, official boot ROM execution, real-time Game Boy Printer emulation, and built-in text-to-speech debugger.
- **`Gearboy` & `Mesen-S` (Alternative)**:
  - *Strengths*: Minimalist C++17 implementations, ideal for clean fallback.

### 2.3 Super Nintendo Entertainment System (SNES / SFC)
- **`bsnes` (Primary)**:
  - *Strengths*: Cycle-exact PPU/APU accuracy. Flawlessly supports special enhancement chips (SuperFX, SA-1, DSP-1/2/3/4, Cx4, ST010, SPC7110) without external HLE hacks.
  - *No-JIT Profile*: Deterministic instruction interpreter; runs at full speed on A13 Bionic and newer.
- **`Snes9x` (Alternative — Fast / Low-Power)**:
  - *Strengths*: Excellent balance of accuracy and raw speed. Runs at 60 FPS on any iOS device with virtually zero heat output.
- **`Mesen-S` (Alternative — Precision)**:
  - *Strengths*: Audio DSP cycle precision; supports HD-SNES widescreen mods.

### 2.4 Nintendo 64 (N64)
- **`Mupen64Plus-Next` (Master Core)**:
  - Supports dynamic switching between two distinct graphics RDP paths:
    1. **`GLideN64` (HLE)**: High-level graphics emulation translated into Metal via custom shader pipeline. Upscales to native Retina resolutions (2x to 4x).
    2. **`ParaLLEl RDP / Angrylion` (LLE)**: Bit-exact, pixel-perfect software rasterization of the SGI Reality Coprocessor. Eliminates every graphical glitch found in HLE plugins.
  - *No-JIT Strategy*: Uses Mupen64Plus Pure Interpreter with cached opcode decoding.

### 2.5 Nintendo DS (NDS)
- **`melonDS DS` (Primary)**:
  - *Strengths*: Modern C++ architecture, accurate 3D rasterizer, DSi NAND emulation, camera injection, local WiFi multiplayer, and microphone input via iOS `AVAudioEngine`.
  - *No-JIT Profile*: ARM946E-S and ARM7TDMI pure interpreter with fast memory mapping.
- **`DeSmuME` (Alternative — Legacy Hacks)**:
  - *Strengths*: Mature core with deep support for obscure homebrew and custom touchscreen layout profiles.

### 2.6 Nintendo 3DS
- **`Azahar` (Primary — PabloMK7 Citra Fork)**:
  - *Strengths*: Purpose-built optimizations for ARM64 and low-memory devices. Supports real-time microphone input, camera capture, amiibo `.bin` scanning via NFC, and built-in Action Replay cheat engine.
  - *No-JIT Profile*: Dual-core ARM11 interpreter with fast SIMD math routines and SPIR-V to Metal PICA200 fragment shader translation.
- **`Citra` (Alternative)**:
  - *Strengths*: Upstream baseline reference.

### 2.7 Sony PlayStation 1 (PS1 / PSX)
- **`Beetle PSX HW` (Primary)**:
  - *Strengths*: Mednafen-derived accuracy. Includes **PGXP (Precision Geometry Transform Pipeline)** which fixes the infamous PS1 3D polygon jittering and affine texture warping. Internal resolution upscaled up to 4K via Metal.
  - *No-JIT Profile*: R3000A MIPS interpreter.
- **`PCSX-ReARMed` (Alternative — Speed)**:
  - *Strengths*: Optimized specifically for ARM; lowest memory footprint and lowest battery impact.
- **`SwanStation` (Alternative — Modern DuckStation Core)**:
  - *Strengths*: Comprehensive rewind support, automatic widescreen patches, and adaptive texture filtering.

### 2.8 Sony PlayStation 2 (PS2)
- **`Balero-S2` (Primary — Sister Project Integration)**:
  - *Architecture*: 100% pure interpreter. Pre-decoded Intermediate Representation (IR) blocks stored in static memory arenas. Direct-threaded dispatch with `[[clang::musttail]]`.
  - *Vector Emulation*: EE MMI and VU0/VU1 128-bit SIMD lowered directly to ARM64 NEON intrinsics (`vld1q_u32`, `vaddq_s32`, `vfmaq_f32`).
  - *Graphics*: Native Metal 3/4 Graphics Synthesizer engine with compute swizzling of the 4 MB eDRAM.
- **`Play!` (Alternative — Pure C++ Interpreter)**:
  - *Strengths*: Clean, modular, standalone C++ codebase requiring zero JIT. Highly stable fallback.

### 2.9 Sony PlayStation 3 & 4 (PS3 & PS4)
- **`Samba-S3` (PS3)**: Modular RPCS3 interpreter mode with PPU/SPU execution mapped to Apple Silicon P/E cluster scheduling.
- **`Bachata-S4` (PS4)**: shadPS4 interpreter mode with Liverpool GPU GCN instruction packets translated directly into Metal Compute Command Encoders.

### 2.10 Sony PlayStation Portable (PSP)
- **`PPSSPP`**:
  - *No-JIT Configuration*: Compiled with `CPU_INTERPRETER`. Emulates the Allegrex MIPS R4000 CPU via direct-threaded execution.
  - *Graphics*: Direct Apple Metal backend (`GPU_BACKEND_METAL`) rendering the GE (Graphics Engine) pipeline natively on Apple Silicon.

### 2.11 Sega Saturn & Dreamcast
- **Sega Saturn — `Beetle Saturn`**:
  - Emulates dual SH-2 RISC CPUs and complex VDP1/VDP2 sprite and plane processors with cycle fidelity.
  - *Alternatives*: `Kronos` (hardware-accelerated rasterization), `Yabause` (lightweight).
- **Sega Dreamcast — `Flycast (JITLess)`**:
  - Incorporates the Provenance JITLess interpreter developed specifically for App Store compliance.
  - Translates PowerVR2 graphics to Metal and executes SH-4 instructions via optimized NEON dispatch.

### 2.12 Sega Mega-CD & 16-Bit Ecosystem
- **`JGenesis` (Primary for Mega-CD)**:
  - Modern Rust-based core providing cycle accuracy for the dual Motorola 68000 + Ricoh PCM sound chip setup in the Mega-CD.
- **`Genesis Plus GX`**:
  - Gold standard for Genesis / Mega Drive, Sega CD, Master System, and Game Gear.
- **`ClownMDEmu` & `Picodrive`**:
  - `ClownMDEmu`: High accuracy cycle-based Genesis core.
  - `Picodrive`: Best-in-class support for the complex Sega 32X dual SH-2 architecture on mobile devices.

### 2.13 Arcade Systems
- **`FBNeo` (FinalBurn Neo)**:
  - The premier arcade core for Neo Geo, Capcom CPS-1, CPS-2, CPS-3, Cave, and Sega System 16/18. Full support for RetroAchievements.
- **`MAME`**:
  - Universal arcade emulation library supporting tens of thousands of historical arcade titles.

### 2.14 Vintage & Mobile Platforms
- **Symbian OS (`EKA2L1`)**:
  - Emulates Nokia N-Gage and Symbian S60v1 through Symbian^3 mobile devices.
- **Java ME (`J2meJS` & `FreeJ2ME`)**:
  - Emulates MIDP 1.0/2.0 J2ME retro mobile phone games (e.g. Gameloft, EA Mobile titles).
- **MS-DOS & Windows 9x (`DOSBox Pure`)**:
  - Supports direct execution from `.zip` files, virtual gamepad mapping, and Windows 95/98 VHD booting.

---

## 3. Core Switching Mechanism & Static Linking Model

```
   ┌────────────────────────────────────────────────────────┐
   │                  Game Library Grid                     │
   └──────────────────────────┬─────────────────────────────┘
                              │ Long-Press Gesture
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │             Context Menu: "Switch Core"                │
   └──────────────────────────┬─────────────────────────────┘
                              │ Presents Bottom Sheet
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │             Core Selection Sheet (Modal)               │
   │                                                        │
   │  ● PCSX-ReARMed (Fast / Recommended)      [Selected]   │
   │  ○ Beetle PSX HW (PGXP, Metal Hardware)                │
   │  ○ SwanStation (DuckStation, Rewind)                   │
   │                                                        │
   │  [ Set as Global Default for PlayStation ]             │
   └────────────────────────────────────────────────────────┘
```

1. **Static Table Registration (App Store 2.5.2 Compliance)**:
   - To strictly comply with Guideline 2.5.2, all cores are **statically compiled into the application binary** or shipped as pre-signed embedded frameworks.
   - Arbitrary dynamic code loading via `dlopen()` on user paths is strictly prohibited. Cores register into a compile-time static registry:

```c
typedef struct {
    const char* core_id;
    const char* display_name;
    const char* platform_id;
    bool        is_recommended;
    GagaCoreInterface (*get_interface)(void);
} GagaCoreRegistryEntry;

static const GagaCoreRegistryEntry g_core_registry[] = {
    { "org.libretro.pcsx-rearmed", "PCSX-ReARMed", "ps1", true,  PcsxReArmed_GetInterface },
    { "org.libretro.beetle-psx",   "Beetle PSX HW", "ps1", false, BeetlePsx_GetInterface   },
    { "org.libretro.mgba",         "mGBA",          "gba", true,  Mgba_GetInterface        },
    { "org.libretro.gpsp",         "gpSP",          "gba", false, Gpsp_GetInterface        },
    { "org.libretro.snes9x",       "Snes9x",        "snes", true, Snes9x_GetInterface      },
    { "org.libretro.bsnes",        "bsnes",         "snes", false, Bsnes_GetInterface       },
    { NULL, NULL, NULL, false, NULL }
};
```

2. **Storage Schema**:
   - Stored in local SQLite / CoreData schema:
     `GameEntity.coreOverride: String?` (e.g., `"org.libretro.pcsx-rearmed"`).
   - If `coreOverride == nil`, system resolves to `UserPreferences.defaultCoreForPlatform[platformID]`.
