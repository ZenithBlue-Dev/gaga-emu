# 02 — Feature Set & Manic EMU Reference Parity

Gaga-Emu reconstructs and expands the complete feature matrix established by Manic EMU (v2.0.1) as validated against the 14 attached reference screenshots (`maniac-emu-reference-images/`).

---

## 1. Feature Breakdown by Reference Screenshot

```
   ┌────────────────────────────────────────────────────────────────────────┐
   │                       MANIC EMU REFERENCE MATRIX                       │
   ├──────────────────────────┬───────────────────────┬─────────────────────┤
   │ Screenshot Asset         │ UI Module / Screen    │ Primary Feature Set │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 026FA2CF-BF58-483F-96FD  │ Controllers Modal     │ Slot selection,     │
   │                          │                       │ Touch vs Gamepad    │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 0596EA12-2CD5-4A4E-A8DC  │ Premium Paywall (IAP) │ Unlimited states,   │
   │                          │                       │ cheats, 5x speed    │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 0BF2D032-B3DB-43DC-B6B2  │ Shaders / Filters     │ Real-time preview,  │
   │                          │                       │ CRT/Geom/RetroArch  │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 3D38E22D & DE9D26E2      │ Emulator Core List    │ Platform-to-core,   │
   │                          │                       │ per-game override   │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 443B8BE2-45D4-4380-886B  │ Recents / Cloud Drive │ Archive browser,    │
   │                          │                       │ Turnip/ROM lists    │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 44F4AEE0 & C4E3779B      │ Settings (General &   │ Dark mode, BIOS,    │
   │                          │ Advanced)             │ Silent mode, Rumble │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ 8A17681E & 9EFF77AC      │ Settings (Support &   │ Discord/QQ links,   │
   │                          │ Utilities)            │ Cache clear, Tips   │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ A59F001A-4A5D-4C8E-9521  │ Import Tab Hub        │ WiFi, Clipboard,    │
   │                          │                       │ MultiDisc, RomPatch │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ E2946B38-0948-4625-BFED  │ Play History          │ Activity timeline,  │
   │                          │                       │ quick resume        │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ F7ADD189-AE09-4C81-8624  │ Adventurer Card       │ Playtime, join date,│
   │                          │                       │ avatar, banner      │
   ├──────────────────────────┼───────────────────────┼─────────────────────┤
   │ FC11608F-934C-4BDB-8444  │ Main Library (Empty)  │ 3-tab layout,       │
   │                          │                       │ legal disclaimer    │
   └──────────────────────────┴───────────────────────┴─────────────────────┘
```

---

## 2. Detailed Subsystem Specifications

### 2.1 Adventurer Card & Social Profile (Ref: `F7ADD189`, `8A17681E`)
- **Profile Header**: Top of Settings page features the custom gamer identity card:
  - **Nickname**: User-customizable alias (defaults to "Adventurer"), used as display handle in Netplay rooms and RetroAchievements.
  - **Play Time**: Cumulative active gameplay counter tracked across all emulator cores.
  - **Joined Date**: Timestamp of first app initialization.
  - **Avatar**: Customizable avatar icon with unlocked retro mascots.
- **Support & Community Links**: Direct deep-linking to Discord, QQ Community, online FAQ, and issue reporting.
- **Cache Management**: One-tap cache eviction (clearing decompressed temp ROMs, scraped covers, and shader compilation caches).

### 2.2 Controller Engine & Input Subsystem (Ref: `026FA2CF`, `C4E3779B`)
- **Controller Slot Assignment**:
  - Modal overlay accessible via top-left controller icon.
  - Assigns connected inputs to Player 1 through Player 4.
  - Automatic fallback to on-screen Touch Control when no physical gamepad is bound to Player 1.
- **Hardware Controller Support**:
  - Native `GameController.framework` integration: DualShock 4, DualSense (PS5), Xbox Wireless Controller, Switch Joy-Cons (paired or split single Joy-Con mode), MFi gamepads.
  - Bluetooth keyboards and Mac input routing for computer cores (DOSBox, EKA2L1, J2meJS).
- **Haptic & Audio Polish**:
  - CoreHaptics rumble emulation translated from core vibration events.
  - "Skin Sound Effects" toggle: Plays authentic mechanical tactile clicks on touch skin button presses.
  - "Respect Silent Mode": Follows the physical iOS hardware mute switch.
- **TriggerPro Macro Engine**:
  - User can bind compound virtual triggers:
    - **Turbo Mode**: Sustained pulsing at configurable frequencies (5 Hz to 30 Hz).
    - **Hold Toggle**: Latches buttons (e.g. holding accelerator or run).
    - **Combo Macros**: Executes multi-frame sequences (e.g., Street Fighter quarter-circle motions).
- **Skin Engine**:
  - Dual compatibility: Delta skins (`.deltaskin` format with JSON layout + PNG assets) and Manic Flex dynamic SVG/JSON skins.
  - Interactive skin customizer: Modify button positions, scale, opacity, and landscape aspect ratio.

### 2.3 Shaders & Visual Processing Pipeline (Ref: `0BF2D032`)
- **Interactive Live Preview Canvas**:
  - Real-time preview card rendering a live 16-bit pixel art scene through the active shader pipeline before applying it to the active game.
- **Four Shader Source Tiers**:
  1. **Default**: Factory tuned Metal Shading Language (MSL) filters.
  2. **RetroArch**: Slang/GLSL shaders ported from the Libretro shader repository.
  3. **Import**: Custom `.slangp` or `.metal` filter archives ingested from Files.
  4. **Custom**: In-app parameter tweaking (scanline intensity, curvature, bloom, color temperature).
- **Core Preset Catalog**:
  - `Original`: Zero-filtering point/bilinear sampler.
  - `Cartoon`: Cel-shaded edge detection and posterization.
  - `CRT v1`: Lightweight horizontal scanlines with subtle phosphors (ideal for low-power A-series chips).
  - `CRT v2`: High-fidelity aperture grille simulation with shadow mask.
  - `Geom CRT Border`: Authentic retro CRT television bezel housing with screen curvature.
  - `Geom CRT`: Mathematical CRT beam curvature and blooming.
  - `Film`: 35mm film grain and color drift.
  - `Anime4K / xBRZ`: Smart AI/pixel scaling for handheld 2D sprites.

### 2.4 Ingestion & Import Hub (Ref: `A59F001A`, `443B8BE2`)
- **Files & iCloud**: `UIDocumentPickerViewController` supporting single ROMs and archives (`.zip`, `.7z`, `.rar`, `.bin`, `.iso`, `.chd`, `.pbp`, `.cso`).
- **Local WiFi Web Server**:
  - Built-in embedded HTTP server running on a local LAN port (e.g. `http://iphone.local:8080`).
  - *Privacy & Security Safeguards*: Disabled by default. Toggled on explicitly by the user, generating an ephemeral 4-digit PIN for session authorization. Includes `NSLocalNetworkUsageDescription` in `Info.plist` to prevent App Store rejection under Guideline 1.4 / 5.1.1.
- **Read Clipboard**:
  - *Strict Tap-to-Read*: In compliance with Apple's clipboard privacy notification banner, clipboard inspection executes **only** when the user explicitly taps "Read Clipboard".
  - Scans system clipboard for copied file URLs, binary file blobs, or direct download links copied from Safari or Files.
- **MultiDisc Helper**:
  - Automated detection of multi-disc games (e.g. `Game (Disc 1).bin`, `Game (Disc 2).bin`).
  - Generates valid `.m3u` playlist files automatically so games switch discs seamlessly without losing save continuity.
- **RomPatcher**:
  - Built-in checksum validator (CRC32, MD5, SHA-1).
  - On-the-fly patching for IPS, UPS, and BPS translation/enhancement patches without destroying original clean dumps.
- **Drag & Drop**: Full iOS/iPadOS pointer drag-and-drop ingestion directly into the game grid.

### 2.5 Library & Gameplay Architecture (Ref: `FC11608F`, `E2946B38`, `44F4AEE0`)
- **Navigation Paradigm**:
  - Minimalist bottom glass tab bar: `[Games (Rocket)]`, `[Import (Folder)]`, `[Settings (Gear)]`.
  - Top navigation bar: Left controller manager, right Play History and Search.
- **Library Features**:
  - Automatic boxart scraping via OpenVGDB, Libretro Thumbnails, and SteamGridDB.
  - Platform filtering, manufacturer sorting (Nintendo, Sony, Sega, Arcade, Vintage), search, and favorite pinning.
  - Long-press contextual action sheet: Launch, Core Selection, Shader Assignment, Edit Metadata, Export Save, Delete.
- **Save State Subsystem**:
  - Manual save slots with embedded screenshot thumbnails.
  - 50 rolling auto-save slots managed by FIFO queue.
  - iCloud sync for state persistence across iPhone, iPad, and Mac.
- **Emulation Enhancements**:
  - 5x Fast-Forward speed control with audio pitch preservation.
  - Rewind buffer for qualifying 8-bit/16-bit cores.
  - Full RetroAchievements integration supporting Softcore and Hardcore modes.
  - AirPlay 2 low-latency full-screen mirroring with external controller navigation.

### 2.6 Monetization & StoreKit 2 Tiers (Ref: `0596EA12`)
- **Free Core Tier**:
  - Complete emulation of all supported systems in interpreter mode.
  - Standard bilinear/nearest filtering.
  - Up to 3 manual save states per game.
  - Up to 3 active cheat codes per game.
  - 2x Fast-Forward.
  - 1 Controller connection.
- **Premium Membership Tier (StoreKit 2)**:
  - **Unlimited Save States & Rolling 50 Auto-Saves**.
  - **Unlimited Cheat Codes** with online cheat database search.
  - **Premium Metal Shaders** (Geom CRT, Anime4K, CRT-Royale).
  - **5x Fast-Forward & Custom Speeds**.
  - **Multi-Controller Local Multiplayer & Netplay Hosting**.
  - Flexible purchase options:
    - Monthly Subscription
    - Annual Membership (50% Off)
    - Lifetime Pass (Single In-App Purchase)
