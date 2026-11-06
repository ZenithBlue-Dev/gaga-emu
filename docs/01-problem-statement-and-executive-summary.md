# 01 — Problem Statement & Executive Summary

Gaga-Emu is an all-in-one, multi-system retro console emulator engineered natively for iOS and iPadOS. Designed for strict compliance with Apple's App Store Review Guidelines (Rules 4.7 and 2.5.2), Gaga-Emu operates entirely in **pure interpreter mode (zero JIT)** and executes all visual output through a native **Apple Metal 3 graphics pipeline**.

---

## 1. Problem Statement

### 1.1 The iOS Emulation Landscape & App Store Constraints
In April 2024, Apple updated App Store Review Guideline 4.7 to explicitly permit retro video game console emulator applications. However, Apple strictly enforces hardware-level **W^X (Write XOR Execute)** memory page protection (Guideline 2.5.2):
- Any call to `mprotect(PROT_READ | PROT_WRITE | PROT_EXEC)` or runtime machine code allocation without the `com.apple.security.cs.allow-jit` entitlement fails immediately with `EACCES` (Permission Denied).
- Standard App Store builds cannot attach debuggers (`ptrace`, `task_for_pid`, or `CS_DEBUGGED`), completely blocking runtime JIT compilation engines used by default Dolphin, Citra, and PPSSPP builds.
- Sideloading tools (AltStore/AltJIT, SideStore, StikDebug, TrollStore) provide workarounds for enthusiasts, but App Store mass distribution requires deterministic, high-efficiency **pure interpreter execution**.
- **Scope & Store Policy (Rule 4.7 Boundaries)**: App Store Guideline 4.7 applies strictly to *retro console emulators*. Non-retro desktop architectures or modern complex operating systems risk immediate rejection under Guideline 4.7.2. Consequently, Gaga-Emu focuses its App Store binary strictly on retro generations (8-bit through 6th-gen handhelds/consoles up to PS1, N64, Saturn, Dreamcast, PSP, and NDS), while treating sister 7th/8th-gen experimental interpreters (`samba-s3` and `bachata-s4`) as independent, external projects.

### 1.2 Fragmentation & Legacy Friction
Existing iOS emulation solutions suffer from deep architectural fragmentation:
1. **Delta / Ignited**: Limited primarily to Nintendo legacy systems (NES, SNES, N64, GBC, GBA, DS). Lacks PlayStation, Sega, and PSP systems, and lacks switchable alternative cores.
2. **RetroArch iOS**: Comprehensive core catalog but burdened by a 20-year-old C codebase, desktop-oriented UI paradigms, clunky file navigation, and non-idiomatic iOS touch interactions.
3. **Folium**: Specialized 3DS/NDS/GBA player, but suffers severe frame drops and thermal throttling under pure interpreter execution due to naive fetch-decode loops and MoltenVK translation overhead.
4. **Manic EMU (Benchmark Reference)**: Demonstrated that an all-in-one emulator with a gorgeous, dark-themed, controller-first SwiftUI/UIKit frontend, rich import options (WiFi, clipboard, ROM patcher, multi-disc assistant), and hot-swappable emulator cores per system is the exact user experience iOS players demand. However, its core bindings and JITLess interpreter optimizations remain fragmented.

### 1.3 Sister Project Synergy: Decoupled Architectural Boundaries
Gaga-Emu adopts the modular interpreter and Metal engineering patterns established across the local repository ecosystem, while enforcing clean architectural separation:
- **`balero-s2` (PlayStation 2)**: 128-bit Emotion Engine (EE) MMI and Vector Unit (VU0/VU1) SIMD lowered directly to 128-bit ARM64 NEON intrinsics via direct-threaded, cached-IR interpreters; native Metal 3 GS 4 MB eDRAM emulation (experimental target).
- **`samba-s3` (PlayStation 3) & `bachata-s4` (PlayStation 4)**: Maintained strictly as external, decoupled research siblings. Because PS3/PS4 require massive compute budgets and do not qualify as "retro consoles" under Apple Guideline 4.7, they are excluded from the Gaga-Emu App Store binary to guarantee regulatory compliance and zero bloat.
- **`gaga-emu`**: Serves as the master multi-core platform for retro systems (NES, SNES, GB, GBC, GBA, NDS, PS1, N64, Saturn, Genesis, Mega-CD, Dreamcast, PSP), utilizing a statically compiled, unified C-ABI bridge.

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         Gaga-Emu Unified Host (iOS)                         │
 │   SwiftUI 5.9+ / Combine / StoreKit 2 / GameController / CoreAudio / Metal  │
 └──────────────────────────────────────┬──────────────────────────────────────┘
                                        │ Unified C-ABI Bridge (`GagaBridge.h`)
 ┌──────────────────────────────────────┴──────────────────────────────────────┐
 │                      Multi-Core Orchestration Layer                         │
 ├───────────────────┬───────────────────┬───────────────────┬─────────────────┤
 │ 8/16-Bit Cores    │ 32/64-Bit Cores   │ Handheld & 3D     │ Decoupled S-Tree│
 │ • Gambatte / Same │ • PCSX-ReARMed /  │ • Azahar (3DS)    │ (External S2/S3)│
 │ • Snes9x / bsnes  │   Beetle PSX HW   │ • melonDS DS      │ • Balero-S2     │
 │ • mGBA / gpSP     │ • Flycast JITLess │ • PPSSPP No-JIT   │   (Experimental)│
 │ • Genesis Plus GX │ • Mupen64Plus-Next│                   │                 │
 └───────────────────┴───────────────────┴───────────────────┴─────────────────┘
                                        │ Unified Memory Zero-Copy (MTLBuffer)
 ┌──────────────────────────────────────┴──────────────────────────────────────┐
 │                       Native Apple Metal 3 Pipeline                         │
 │  • CAMetalLayer / MTKView     • Precompiled MSL Pipelines   • CRT Shaders   │
 └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Pillars & Design Constraints

| Pillar | Technical Implementation | Constraint & Compliance Target |
| :--- | :--- | :--- |
| **Strict No-JIT Engine** | Direct-threaded dispatch with `[[clang::musttail]]`, pre-decoded IR opcode blocks, ARM64 NEON SIMD intrinsics. | Zero executable allocations (`PROT_EXEC` banned). App Store Guidelines 2.5.2 & 4.7 compliant. |
| **Native Metal 3/4 Backend** | Direct MSL (Metal Shading Language) render pipelines, UMA zero-copy texture streaming (`MTLStorageModeShared`). | Zero MoltenVK/OpenGL overhead on 2D cores; native Metal render passes on 3D cores. |
| **Multi-Core Flexibility** | Dynamic C-ABI bridge (`GagaBridge`) supporting multiple switchable cores per platform (e.g. mGBA vs gpSP, bsnes vs snes9x, Beetle PSX vs PCSX-ReARMed). | Hot-swappable per title via library long-press; global system default fallbacks. |
| **Manic EMU Feature Parity** | Adventurer profile card, live shader preview, RomPatcher (IPS/BPS/UPS), MultiDisc helper, LAN WiFi server, TriggerPro macros. | 1:1 feature parity with Manic EMU v2.0.1 reference captures. |
| **Modern Apple Architecture** | 100% Swift 5.9+ / SwiftUI, XcodeGen declarative project generation, StoreKit 2 monetization, CoreAudio low-latency ring buffers. | Clean separation of concerns: UI knows nothing of core C++ internals; bridged via pure C struct headers. |

---

## 3. Reference Analysis: Manic EMU Benchmark

From the 14 reference captures of Manic EMU (App Store ID: `6743335790`, v2.0.1), the application establishes five primary pillars that define consumer expectations for an iOS multi-system emulator:
1. **Seamless Core Selection Modal**: Ability to select and swap cores per platform (e.g., J2meJS for Java ME, Beetle PSX HW for PS1, Beetle Saturn for Saturn, JGenesis for Mega-CD, Azahar for 3DS, melonDS for DS, mGBA for GBA, Gambatte for GB/GBC, bsnes for SNES) with long-press per-game override.
2. **Comprehensive Shader Suite**: Real-time interactive shader selection across Default, RetroArch, Import, and Custom tabs with live thumbnail previewing (Original, Cartoon, CRT v1, CRT v2, Geom CRT Border, Geom CRT, Film).
3. **Integrated Import Utilities**: Standalone file ingestion including local Files/iCloud, LAN browser WiFi upload, clipboard paste extraction, MultiDisc M3U playlist creation, and an in-memory ROM patcher.
4. **Input Customization & TriggerPro**: First-class support for MFi/PlayStation/Xbox/Joy-Con controllers, per-player slot mapping, custom on-screen skin assignment (`.deltaskin` and Flex formats), and TriggerPro macro/turbo controls.
5. **Adventurer Identity & StoreKit 2**: Gamer card displaying total playtime, join date, nickname, and custom avatar, paired with non-intrusive premium tier upgrades for unlimited save states, unlimited cheats, and premium filters.

Gaga-Emu adopts this exact feature taxonomy while re-architecting the backend for 100% pure interpreter execution and native Metal pipelines.
