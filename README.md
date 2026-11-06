# Gaga-Emu — All-in-One Multi-Model Emulator for iOS

High-performance, App Store-compliant multi-system console emulator designed natively for iOS and iPadOS.

Built with strict **No-JIT Interpreter Execution**, native **Apple Metal 3 Graphics**, and an idiomatic **SwiftUI** interface achieving complete feature parity with the gold standard **Manic EMU**.

---

## Core Pillars

1. **Strict No-JIT Execution Engine**:
   - Compliant with Apple App Store Review Guidelines 4.7 and 2.5.2 (no `mprotect(PROT_EXEC)`, no writable-executable pages, zero dynamic code generation).
   - High-throughput direct-threaded dispatch using `[[clang::musttail]]` and pre-decoded 16-byte Intermediate Representation (IR) block caches.
   - Vector instructions lowered directly to 128-bit ARM64 NEON intrinsics.
   - Runloop yield safety via slice cycle budgets and static `BlockExit` handlers.

2. **Native Apple Metal 3 Graphics Pipeline**:
   - True zero-copy Unified Memory Architecture (UMA) streaming via triple-buffered shared memory `MTLBuffer` wrapped with `makeTexture(descriptor:offset:bytesPerRow:)`.
   - Built-in MSL shader engine featuring real-time preview (Original, Cartoon, CRT v1, CRT v2, Geom CRT Border, Geom CRT, Film).
   - Offline precompiled community Slang shaders updated via dynamic parameter uniform buffers.

3. **Multi-Core Flexibility per Platform**:
   - Every system supports multiple selectable cores with sensible defaults (e.g. GBA: mGBA / gpSP; SNES: Snes9x / bsnes; PS1: PCSX-ReARMed / Beetle PSX HW / SwanStation; 3DS: Azahar).
   - Hot-swappable per game via library long-press; global system default fallbacks.
   - Statically registered core registry ensuring zero unsigned `dlopen()` App Store hazards.

4. **Complete Manic EMU Reference Parity**:
   - Adventurer Profile Card with cumulative playtime tracking and custom retro avatars.
   - Integrated Ingestion Hub: Local Files/iCloud, LAN browser WiFi upload (PIN-protected), tap-only clipboard paste extraction, MultiDisc M3U helper, and in-memory RomPatcher (IPS/BPS/UPS).
   - Input engine: MFi, DualShock 4, DualSense, Xbox, Joy-Con, touch skins (`.deltaskin` and dynamic SVG), and TriggerPro macro/turbo controls.
   - Clear architectural boundary: Sister 7th/8th-gen projects (`samba-s3` PS3, `bachata-s4` PS4) kept as decoupled research repositories outside the App Store binary to guarantee Rule 4.7 compliance.

---

## Technical Documentation Index

Detailed engineering specifications located in [`docs/`](./docs/):

- [**01 — Problem Statement & Executive Summary**](./docs/01-problem-statement-and-executive-summary.md): App Store Rule 4.7 & 2.5.2 constraints, market landscape, reference analysis of Manic EMU, and sister project lineage (`balero-s2`, `samba-s3`, `bachata-s4`).
- [**02 — Feature Set & Manic EMU Reference Parity**](./docs/02-feature-set-and-manic-emu-parity.md): 1:1 functional mapping against the 14 reference screenshots across Adventurer Card, Controller Engine, Shaders, Import Hub, Library, and StoreKit 2 paywall.
- [**03 — Core Matrix & Multi-Core Platform Catalog**](./docs/03-core-matrix-and-platform-catalog.md): Complete taxonomy of all supported systems and multi-core alternatives with trade-offs between cycle accuracy and interpreter speed.
- [**04 — No-JIT Interpreter Architecture**](./docs/04-no-jit-interpreter-architecture.md): W^X compliance, `[[clang::musttail]]` direct threading, pre-decoded IR block caches, ARM64 NEON vector lowering, and core performance audit.
- [**05 — Metal Graphics Pipeline & Shaders**](./docs/05-metal-graphics-pipeline-and-shaders.md): UMA zero-copy texture ring, 2D/3D render paths, MSL shader equations, live interactive preview canvas, and Slang-to-Metal compilation.
- [**06 — iOS App Architecture & C-Bridge Specification**](./docs/06-ios-app-bridge-and-subsystem-spec.md): `GagaBridge.h` C-ABI, SwiftUI view hierarchy, WiFi file server, MultiDisc helper, RomPatcher, and XcodeGen project manifest.
- [**07 — Roadmap & Implementation Plan**](./docs/07-roadmap-and-implementation-plan.md): 7-phase engineering execution plan from scaffolding to App Store submission.
