# 07 — Roadmap & Implementation Plan

This roadmap outlines the 7-phase engineering execution plan for Gaga-Emu, progressing from initial scaffolding to App Store submission.

---

## 1. Phase Breakdown & Milestones

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                       GAGA-EMU ENGINEERING ROADMAP                         │
 ├─────────┬───────────────────────────────┬───────────────────────────────────┤
 │ Phase   │ Title                         │ Primary Deliverables              │
 ├─────────┼───────────────────────────────┼───────────────────────────────────┤
 │ Phase 1 │ Foundation & Scaffolding      │ XcodeGen, SwiftUI shell, C-bridge │
 │ Phase 2 │ Tier-1 2D Cores & Metal UMA   │ mGBA, bsnes, Gambatte, shared ring│
 │ Phase 3 │ Metal Shader Engine & Preview │ MSL shaders, live preview canvas  │
 │ Phase 4 │ Tier-2 3D Cores (No-JIT)      │ Beetle PSX, Mupen64Plus, melonDS  │
 │ Phase 5 │ Import Hub & Utility Suite    │ WiFi server, RomPatcher, MultiDisc│
 │ Phase 6 │ Tier-3 Cores & Sister Bridges │ Azahar 3DS, PPSSPP, Balero-S2     │
 │ Phase 7 │ App Store Polish & StoreKit 2 │ Guideline 4.7 audit, IAP paywall  │
 └─────────┴───────────────────────────────┴───────────────────────────────────┘
```

---

## 2. Detailed Phase Specifications

### Phase 1: Foundation, App Shell & C-Bridge Scaffolding
- **Milestone 1.1**: Setup declarative XcodeGen environment (`project.yml`). Establish modular workspace separating core logic from UI.
- **Milestone 1.2**: Implement base SwiftUI 5.9+ application shell with custom bottom glass tab bar:
  - `[Games]` tab with hero branding and legal disclaimer.
  - `[Import]` tab with utility cards.
  - `[Settings]` tab with Adventurer profile header.
- **Milestone 1.3**: Create pure C99 bridge interface (`GagaBridge.h`) with input bitmasks, audio/video callbacks, and state serialization signatures.
- **Milestone 1.4**: Configure CoreAudio / `AVAudioEngine` low-latency stereo PCM ring buffer.

### Phase 2: Tier-1 2D Cores & Zero-Copy Metal Renderer
- **Milestone 2.1**: Compile and package first batch of 8-bit/16-bit pure interpreter cores into static frameworks:
  - `mGBA` (Game Boy Advance)
  - `Gambatte` (Game Boy & Game Boy Color)
  - `Snes9x` & `bsnes` (Super Nintendo)
  - `Genesis Plus GX` (Genesis / Mega-CD / Master System)
- **Milestone 2.2**: Build triple-buffered `MTLBuffer` ring (`.storageModeShared`) with `makeTexture(descriptor:offset:bytesPerRow:)` for zero-copy CPU-to-GPU pixel delivery and completion-handler semaphore signaling.
- **Milestone 2.3**: Implement touch skin rendering engine supporting `.deltaskin` and dynamic SVG formats.
- **Milestone 2.4**: Connect `GameController.framework` for MFi, DualShock, Xbox, and Joy-Con gamepads.

### Phase 3: Metal Shaders & Interactive Live Preview
- **Milestone 3.1**: Author native Metal Shading Language (MSL) post-processing kernels:
  - `Original` (pass-through nearest/bilinear)
  - `Cartoon` (edge detection + palette quantization)
  - `CRT v1` (lightweight scanlines)
  - `CRT v2` (aperture grille + phosphors)
  - `Geom CRT` (tube barrel curvature + blooming)
  - `Geom CRT Border` (vintage TV bezel composite)
  - `Film` (animated grain + warm color drift)
- **Milestone 3.2**: Implement interactive real-time preview card inside the Shaders sheet (`MTKView` rendering live 16-bit pixel art).
- **Milestone 3.3**: Precompile community Slang shaders offline into cached `.metallib` archives, with real-time UI sliders updating parameters via an `MTLBuffer` uniform struct without pipeline recompilation.

### Phase 4: Tier-2 3D Cores & No-JIT Optimization
- **Milestone 4.1**: Integrate 32-bit and 64-bit 3D cores running in pure interpreter mode:
  - `PCSX-ReARMed` (primary fast PS1 core) and `Beetle PSX HW` with PGXP.
  - `Mupen64Plus-Next` with GLideN64 (Metal HLE) and ParaLLEl RDP (software compute LLE).
  - `melonDS DS` with DSi NAND, camera, and microphone input.
  - `Flycast` with Provenance JITLess interpreter and PowerVR2 Metal backend.
- **Milestone 4.2**: Implement core selector sheet with per-game override via library long-press.

### Phase 5: Ingestion Hub & Utility Suite
- **Milestone 5.1**: Build embedded LAN HTTP file server for desktop browser drag-and-drop uploads, guarded by explicit user toggle, PIN authentication, and `NSLocalNetworkUsageDescription`.
- **Milestone 5.2**: Implement clipboard inspector for auto-detecting copied ROM archives, triggered strictly on explicit user button tap.
- **Milestone 5.3**: Build MultiDisc Helper for automated `.m3u` playlist generation.
- **Milestone 5.4**: Implement in-memory ROM patcher supporting IPS, BPS, and UPS patches.
- **Milestone 5.5**: Add automated boxart scraping via OpenVGDB and Libretro Thumbnails.

### Phase 6: Tier-3 High-Performance Cores & Sister Projects
- **Milestone 6.1**: Integrate `Azahar` (PabloMK7 Citra fork) for Nintendo 3DS in pure interpreter mode with SPIR-V to Metal PICA200 vertex shader compilation.
- **Milestone 6.2**: Integrate `PPSSPP` in pure IR interpreter mode with native Metal backend.
- **Milestone 6.3**: Bridge sister projects:
  - `balero-s2`: PS2 Emotion Engine cached IR interpreter and GS Metal eDRAM engine (experimental target).
  - Maintain `samba-s3` (PS3) and `bachata-s4` (PS4) as decoupled external research repositories outside the App Store binary to guarantee compliance with Guideline 4.7.
- **Milestone 6.4**: Implement TriggerPro macro engine (turbo fire, button hold latch, combo macros).

### Phase 7: App Store Qualification, StoreKit 2 & Polish
- **Milestone 7.1**: Strict compliance audit for Apple Review Guidelines 4.7 and 2.5.2 (verify zero executable page allocations).
- **Milestone 7.2**: Implement StoreKit 2 membership paywall:
  - Monthly Subscription
  - Annual Membership (50% Off)
  - Lifetime Pass (Non-consumable)
  - Entitlement gatekeeper for unlimited save states, unlimited cheats, and premium shaders.
- **Milestone 7.3**: RetroAchievements integration (login, badge display, Hardcore Mode).
- **Milestone 7.4**: AirPlay 2 low-latency full-screen mirroring with external display auto-detection.
