# 06 — iOS App Architecture, C-Bridge & Subsystem Specification

This document is canonical for the bridge API and the premium and in-app purchase spec. `docs/03` is canonical for the core list, `docs/04` for interpreter design and tiers, `docs/05` for graphics, and `docs/07` for phases and status.

Manic EMU is a feature reference only, tracked in `docs/02`. Nothing in this document copies its UI.

---

## Status

The app today is a shell plus a mock core. The 12 non-mock registry cores are stubs: `load_rom` returns true and `step_frame` does nothing (`Sources/Bridge/GagaCoreRegistry.c:241-247,279-290`). No game session exists, because `AppState.launch` only records state and `GagaCoreWrapper` is instantiated only in tests.

Status terms used in this document:

- **built:** the code exists and does its job in the shell.
- **stub:** the row, toggle or symbol exists, but nothing acts on it. A stub toggle persists its value and no code reads it.
- **planned:** no code exists.

Status comes from reading the code, not from a device test.

---

## 1. System Decomposition

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │ SwiftUI app (built)                                                 │
 │ Library, Add, Settings, ControllerManager, StoreKitManager          │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │ EmulatorCoreProtocol, GagaCoreWrapper
                                 │ (built, used only by tests)
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ C bridge: GagaBridge.h, GagaCoreRegistry (built)                    │
 │ GagaCoreInterface: one function-pointer table per core              │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ Mock core (built). 11 weak stubs (stub). Real cores (planned, docs/03)│
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │ video and audio callbacks
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ Video: Metal paths in docs/05. Audio: AudioEngineManager (unused).  │
 │ Haptics: CoreHaptics in TouchSkinEngine.                            │
 └─────────────────────────────────────────────────────────────────────┘
```

---

## 2. C Bridge

### 2.1 Current header (built)

There are no free `gaga_core_*` functions. Each core exposes a `GagaCoreInterface` table of function pointers, and the host calls through it. This listing matches `Sources/Bridge/GagaBridge.h`.

```c
#ifndef GAGA_BRIDGE_H
#define GAGA_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque instance handle for core isolation
typedef struct GagaInstance GagaInstance;

// Universal controller button masks (cross-mapped for Nintendo, PlayStation, Xbox)
typedef enum {
    GAGA_BTN_UP       = 1 << 0,
    GAGA_BTN_DOWN     = 1 << 1,
    GAGA_BTN_LEFT     = 1 << 2,
    GAGA_BTN_RIGHT    = 1 << 3,
    GAGA_BTN_SOUTH    = 1 << 4, // B (Nintendo) / Cross (Sony) / A (Xbox)
    GAGA_BTN_EAST     = 1 << 5, // A (Nintendo) / Circle (Sony) / B (Xbox)
    GAGA_BTN_WEST     = 1 << 6, // Y (Nintendo) / Square (Sony) / X (Xbox)
    GAGA_BTN_NORTH    = 1 << 7, // X (Nintendo) / Triangle (Sony) / Y (Xbox)
    GAGA_BTN_L1       = 1 << 8, // L / L1
    GAGA_BTN_R1       = 1 << 9, // R / R1
    GAGA_BTN_L2       = 1 << 10,// ZL / L2 (Digital click)
    GAGA_BTN_R2       = 1 << 11,// ZR / R2 (Digital click)
    GAGA_BTN_START    = 1 << 12,
    GAGA_BTN_SELECT   = 1 << 13,
    GAGA_BTN_L3       = 1 << 14,
    GAGA_BTN_R3       = 1 << 15,
} GagaButtonMask;

// Input state packet per player slot
typedef struct {
    uint32_t buttons;     // Digital button bitmask
    int16_t  left_x;      // Analog stick X (-32768 to 32767)
    int16_t  left_y;      // Analog stick Y (-32768 to 32767)
    int16_t  right_x;     // Right stick X
    int16_t  right_y;     // Right stick Y
    float    trigger_l;   // Analog trigger depth (0.0 to 1.0)
    float    trigger_r;   // Analog trigger depth (0.0 to 1.0)
    float    accel_x, accel_y, accel_z; // Motion gyro / accelerometer
} GagaInputState;

// Pixel formats emitted by core
typedef enum {
    GAGA_PIXEL_FORMAT_RGB565   = 0,
    GAGA_PIXEL_FORMAT_XRGB8888 = 1,
    GAGA_PIXEL_FORMAT_RGBA8888 = 2,
} GagaPixelFormat;

// Video frame descriptor emitted to Metal
typedef struct {
    const void* pixel_data;   // Valid for 2D software cores; NULL for 3D hardware cores
    uint32_t    width;
    uint32_t    height;
    size_t      pitch;
    uint32_t    pixel_format; // 0 = RGB565, 1 = XRGB8888, 2 = RGBA8888
} GagaFrameDescriptor;

// Audio descriptor emitted to host
typedef struct {
    const int16_t* pcm_samples;
    size_t         frames;
    uint32_t       sample_rate; // e.g. 32040, 32768, 44100, 48000
    uint8_t        channels;    // 1 = mono, 2 = stereo
} GagaAudioDescriptor;

// Core Lifecycle Interface
typedef struct GagaCoreInterface {
    const char* core_id;
    const char* core_name;
    const char* core_version;
    const char* supported_extensions; // e.g. "gba|bin|zip"
    double      target_fps;           // e.g. 59.7275 (GBA), 60.0, 50.0 (PAL)
    uint32_t    native_sample_rate;   // Core master audio rate

    // Instance lifecycle
    GagaInstance* (*create)(const char* system_dir, const char* save_dir);
    void          (*destroy)(GagaInstance* inst);

    // Media ingestion
    bool (*load_rom)(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size);
    void (*reset)(GagaInstance* inst);

    // Execution slice (supports up to 4 local controller inputs)
    void (*step_frame)(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count);

    // Hardware Metal Attachment (for 3D cores: Beetle PSX HW, PPSSPP, Azahar, Balero-S2)
    bool (*attach_metal_layer)(GagaInstance* inst, void* ca_metal_layer);

    // Audio & Video callbacks
    void (*set_video_callback)(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor* frame, void* userdata), void* userdata);
    void (*set_audio_callback)(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor* audio, void* userdata), void* userdata);

    // Save States (File-path based to support dynamic NAND/Card sizes)
    bool (*save_state_file)(GagaInstance* inst, const char* file_path);
    bool (*load_state_file)(GagaInstance* inst, const char* file_path);

    // Cheats
    void (*apply_cheat)(GagaInstance* inst, uint32_t index, bool enabled, const char* code);
} GagaCoreInterface;

#ifdef __cplusplus
}
#endif

#endif // GAGA_BRIDGE_H
```

The Balero-S2 mention in the `attach_metal_layer` comment is stale, because S2 is not part of the binary. `docs/07` tracks the cleanup.

### 2.2 Registry (built)

`Sources/Bridge/GagaCoreRegistry.h` declares one getter per core (`Mgba_GetInterface` and so on), the working `MockCore_GetInterface`, and four lookups:

```c
size_t GagaCoreRegistry_GetCount(void);
const GagaCoreInterface* GagaCoreRegistry_GetAtIndex(size_t index);
const GagaCoreInterface* GagaCoreRegistry_FindByID(const char* core_id);
const GagaCoreInterface* GagaCoreRegistry_FindByExtension(const char* extension);
```

The table is compile-time; `docs/03` section 8 shows it and lists where the code disagrees with the catalog. The short lowercase `core_id` is the planned single ID scheme.

Each stub is a weak definition in the app binary. A core's stub must be deleted when its framework is linked, or the app's own definition will win over the framework's symbol.

### 2.3 Swift layer (built, test use only)

`Sources/Bridge/EmulatorCoreProtocol.swift` defines `EmulatorCoreError`, `VideoFrame`, `AudioPacket`, `EmulatorCoreProtocol` and `GagaCoreWrapper`. The wrapper runs on a `.userInteractive` execution queue.

### 2.4 Planned additions

Nothing in this section is in the header yet. The bridge has no stable ABI today, so these can change the existing table directly. All are `Status: planned`.

```c
#define GAGA_BRIDGE_ABI_VERSION 1u

typedef enum {
    GAGA_CORE_CAP_HOST_BUFFER    = 1u << 0, // accepts set_host_framebuffer
    GAGA_CORE_CAP_METAL_LAYER    = 1u << 1, // presents to an attached layer; host shaders skipped
    GAGA_CORE_CAP_OUTPUT_TEXTURE = 1u << 2, // hands back an MTLTexture
} GagaCoreCapability;

typedef struct {
    void*           base;          // MTLBuffer.contents() of the current ring slot
    size_t          bytes_per_row; // from minimumLinearTextureAlignment(for:)
    uint32_t        width;
    uint32_t        height;
    GagaPixelFormat format;
} GagaHostFramebuffer;

typedef enum {
    GAGA_EVENT_INFO    = 0,
    GAGA_EVENT_WARNING = 1,
    GAGA_EVENT_FATAL   = 2,
} GagaEventSeverity;

// Added to GagaCoreInterface. abi_version becomes the first member, so the host
// can read it before trusting the rest of the table, and refuses a mismatch.
uint32_t abi_version;
uint32_t capabilities; // GagaCoreCapability bits

// Runs with no game loaded. Returns false and fills error on failure.
bool (*self_test)(char* error, size_t error_capacity);

// Replaces the current attach_metal_layer. Called again when the drawable size changes.
bool (*attach_metal_layer)(GagaInstance* inst, void* ca_metal_layer,
                           uint32_t width_px, uint32_t height_px, float content_scale);
void (*detach_metal_layer)(GagaInstance* inst);

// Host-buffer path (docs/05 section 2.2). Called before each step_frame with the slot to fill.
bool (*set_host_framebuffer)(GagaInstance* inst, const GagaHostFramebuffer* buffer);

// Core-output texture path (docs/05 section 2.4). The id<MTLTexture> is borrowed and valid
// until the next step_frame. It must come from the host's MTLDevice.
void (*set_output_texture_callback)(GagaInstance* inst,
    void (*cb)(void* mtl_texture, uint32_t width, uint32_t height, void* userdata), void* userdata);

// Lifecycle. The host pauses before the app leaves the foreground.
void (*pause)(GagaInstance* inst);
void (*resume)(GagaInstance* inst);

// Errors and events. Today load_rom and state calls return only a bool.
void (*set_event_callback)(GagaInstance* inst,
    void (*cb)(GagaEventSeverity severity, int32_t code, const char* message, void* userdata), void* userdata);
```

Precedent in the sister projects:

| Addition | S3 `SambaBridge.h` | S4 `BachataBridge.h` |
|---|---|---|
| API version | `samba_api_version` (`:43`) | `bachata_bridge_api_version` (`:200`) |
| Self-test | `samba_core_self_test` (`:46`) | `bachata_core_self_test` (`:242`) |
| Layer with size, and detach | `:53-54` | `:271-274` |
| Pause and resume | `:55-56` | `:261-262` |
| Event callback | none | `BachataEventCallback` (`:195`) |

Which core uses which video path is in `docs/05` section 2.5.

### 2.5 Linking and embedding

Target design, per `docs/03` section 5: each core is a dynamic, embedded xcframework that exports only the bridge entry point. Several libretro cores in one image would collide on `retro_*` symbols, and an export list keeps each core's internals private. S3 and S4 follow this shape (`S3/ios/SambaS3/project-core.yml:11-12`, `S4/ios/BachataS4/project-core.yml:16-17`, `S4/src/platform/ios/BachataCore.exports`).

Frameworks are signed and shipped inside the app bundle. Code is never loaded from user paths or downloaded. Dynamic linking does not change the GPL analysis in `docs/03` section 5.

Status: planned. Today everything compiles into the app target, and no framework exists.

---

## 3. Screen Specifications

The UI is an original design named "Paper and ink": a quiet game shelf, flat and print-like. No other app is a visual reference. There is no glass, blur, gradient, mascot, RPG flavour or floating tab bar. System controls such as context menus and confirmation dialogs keep the look iOS gives them.

The app is **landscape only** on iPhone and iPad, left and right. Status: built, unless a row says otherwise.

### Design system

Tokens live in `Sources/App/AppTheme.swift` (`Palette`, `AppTheme`) and follow the system appearance. There is no appearance or theme setting. `state.appearance` is kept only so old `state.json` files decode.

| Token | Light | Dark | Use |
|---|---|---|---|
| paper | `#F4EFE6` | `#16140F` | Screen background |
| surface | `#FBF8F2` | `#211E18` | Rail, cover placeholders |
| ink | `#1C1A17` | `#EDE6D8` | Text |
| muted | `#6B655B` | `#A79F90` | Secondary text and glyphs |
| rule | `#D9D1C2` | `#3A352C` | Hairlines |
| accent | `#BF3D18` | `#F0683F` | Accent text and glyphs. Vermilion adjusted so it meets AA on paper and surface. |
| accentFill | `#E4572E` | `#E4572E` | Vermilion fill for primary buttons and selected chips |
| onAccent | `#1C1A17` | `#1C1A17` | Text on accentFill |

- **Contrast:** text and accent colours meet WCAG AA in both modes. `testPaletteTextMeetsAA` checks every pair.
- **Type:** New York (`.serif`) for screen titles and large game titles, SF Pro for body text, monospaced for metadata such as platform code, play time and file size. All text uses Dynamic Type text styles. Columns scroll, so larger sizes do not clip. Only the rail caps its text size, at `xxLarge`, and offers the large content viewer instead.
- **Shape:** 6pt corners at most, and hairline rules instead of shadows and cards. Covers have a 3pt colour spine on the left, keyed by platform, and always carry the platform code as text.
- **Motion:** a 0.15s fade between screens, removed under Reduce Motion.
- **Accessibility:** icon-only and cover controls have VoiceOver labels, targets are at least 44pt, and selected states also change weight, shape or glyph, so colour is never the only cue.

### Landscape and safe areas

`UISupportedInterfaceOrientations` and its `~ipad` variant list landscape left and right. iPad apps must support all orientations unless they require full screen, so `UIRequiresFullScreen` is set. Apple has deprecated that key and says the compatibility mode will go in a future release. When it does, the app needs a landscape-shaped minimum window size or another migration (TN3192). `docs/07` 7.6 tracks the check.

Backgrounds extend under the notch, Dynamic Island and home indicator. Content stays inside the safe area on whichever side the hardware sits. iPhone height is about 375 to 440pt, so persistent chrome stays small.

### Navigation

A left rail about 72pt wide holds Library, Add and Settings as icon plus small label. The selected item uses the accent colour, bold text and a 3pt bar. There is no tab bar.

### 3.1 Library

**Left column** (about 240pt on iPhone): the Continue panel. It shows the most recently played game, or the newest import when nothing has been played: cover, title, last played and a large Play button pinned to the bottom of the panel.

**Right side:** platform filter chips and search on one compact row, then horizontally scrolling shelves per platform. Chips are All, Recent (once something has been played) and each platform present in the library. A filter with no matches shows a line and Show All Games.

**Play history** is the Continue panel plus the Recent filter. It is not a separate panel. `AppState.history` still records sessions, and Settings > Play counts them.

**Empty state:** one typographic line, "The shelf is empty.", and an Add Games button.

Tapping a cover plays, as does the Play button. Status: stub, because `AppState.launch` only records state until Phase 2.

**Long-press menu.** This is the single definition of the menu; other docs point here.

| Action | Behaviour | Status |
|---|---|---|
| Play | Starts a game session | stub: records state only (`AppState.launch`) |
| Change Core | Opens the core picker, with an option to set the platform default (`docs/03` section 8) | built |
| Choose Filter | Opens the filter picker for this game | built: stored on the game; no session reads it yet |
| Manage Saves | Save state slots with thumbnails | planned: the sheet states that no saves exist yet. 2.6 fills it. |
| Edit Details | Title and favorite, plus platform, core, file size and play time as read-only metadata | built; cover art planned |
| Delete | Asks for confirmation, then removes the game and its play history from the library. The file stays in the ROM folder. | built |

Exporting a battery save and states is planned with 2.6 and has no menu item yet.

### 3.2 Add

Two columns.

**Left:** a large Choose from Files action and a drag-and-drop target. The drop handler covers the whole screen, and other screens do not accept drops.

**Right:** the other sources, then the ROM legal notice as plain small text.

| Source | Behaviour |
|---|---|
| Choose from Files | System document picker, including iCloud Drive. |
| WiFi Transfer | LAN upload server, **off by default**, started only by the user's toggle. Each start creates a fresh 4-digit PIN. Port 8080. The PIN is required for every write, and uploads are capped at 2 GiB with sanitized file names (`Sources/Hub/WiFiTransferServer.swift`). |
| Read Clipboard | **Tap only**: `ClipboardImporter.scan` is called from the row and never automatically. |
| Multi-Disc Helper | Groups disc files into one `.m3u` entry. |
| Patch a ROM | IPS, BPS and UPS patches, in memory, on a copy of the source. IPS RLE records are supported. |

**Security note on WiFi transfer.** Traffic is plain HTTP, so the PIN and files cross the local network unencrypted, and the Add screen and upload page say so. A 4-digit PIN has only 10,000 values, so `PINAttemptLimiter` bounds guessing: every 5th wrong PIN locks the server for a minute, and the 15th stops it until the user restarts it with a new PIN. The PIN is accepted only in the `X-Gaga-Pin` header, never the query string. The server stays off by default and should stay on only while the user is transferring. `NSLocalNetworkUsageDescription` is present in `Info.plist` and names WiFi transfer only.

### 3.3 Settings

Two panes: categories on the left, the selected category on the right. Only rows that work appear.

| Category | Rows | Status |
|---|---|---|
| Play | Total play time and session count, read-only | built |
| Library | Game count, BIOS Files, default core per platform | built |
| Graphics | Default Filter, which opens the filter picker | built |
| Controls | Touch Control, connected controllers with their player slot, TriggerPro | built: no session to feed |
| Storage | Game files size, Clear Cache with confirmation. Clear Cache removes the Caches directory. | built |
| Gaga Plus | Status and See Plans. Absent while the paywall gate is closed (section 4.5). Lifetime owners get no See Plans row. | built, gated |
| About | Version, Support and FAQ, Feedback, Terms of Service, Privacy Policy | built: Support and Feedback link to `support.html`, because the App Store metadata has no support email. Terms is Apple's standard EULA, because the site has no terms page. |

All site links use `zenithblue-oss.github.io/gaga-emu-site` (`SiteLinks`), the host the App Store metadata uses.

There is no profile card, nickname, avatar or membership banner. `nickname`, `joined` and `avatarIndex` stay in `state.json` so saved data still loads.

**Rows not shown yet.** Each has no working behaviour today. Saved values stay in `state.json`.

| Row | Home when it returns | Returns with |
|---|---|---|
| Quick Start, Auto Full Screen | Play | 2.1 |
| Respect Silent Mode | Play | 2.3 |
| Rumble, Skin Sound Effects | Controls | 2.4 |
| Auto Save States | Play | 2.6, gated by `canUseAutoSaveState` |
| Rate Us | About | 2.9 |
| Cover Scraping | Library | 3.8 |
| Assign Skin | Controls | 3.9 |
| RetroAchievements | Play | 3.10 |
| AirPlay Fullscreen | Graphics | 3.11 |
| iCloud Sync | Storage | 3.11 |
| About Us (licence notices) | About | 7.5 |
| Share Gaga-Emu | About | 7.6 |
| Reset Tips | About | When the app has dismissible tips |
| Language | About | When a second localisation exists |
| Online Play | Play | Not scheduled. Netplay is not promised or gated until built. |

There is no JIT row, because GagaEmu ships no JIT and there is nothing to configure. Theme and Appearance are gone, because the palette is fixed and follows the system.

### 3.4 Filter and core pickers

**Filter picker** (`FilterPickerView`): a split view with the list on the left and a large live preview on the right. Opened from a game it sets that game's filter; opened from Graphics it sets the default for new games. Premium filters show a Plus label and open Gaga Plus when locked, only while the gate is open. The planned sources in `docs/05` section 4 have no UI until they exist.

**Core picker** (`CorePickerSheet`): a simple list sheet for one game, with an action that also makes the choice the platform default. A file of unknown type says no cores are available.

### 3.5 Gaga Plus

The paywall is named Gaga Plus (`GagaPlusView`). Two columns: benefits on the left in plain language, plans on the right as Monthly, Annual and Lifetime. Requirements and logic are in section 4.

### 3.6 App icon

An ink game cover with a vermilion spine on paper, drawn by `scripts/make_app_icon.py`. Original artwork with no third-party imagery. It needs owner sign-off before submission.

---

## 4. Premium and In-App Purchases

This section is canonical. Code changes it requires are roadmap items in `docs/07`.

### 4.1 Products

Three products with existing IDs, from `Sources/Store/StoreKitManager.swift`:

| Product ID | Label | Type |
|---|---|---|
| `monthly.sub` | Monthly | Auto-renewing subscription |
| `annual.sub` | Annual | Auto-renewing subscription |
| `lifetime.pass` | Lifetime | Non-consumable, one-time payment |

Prices always come from `Product.displayPrice` and are never hard-coded.

### 4.2 What stays free

Emulation stays free: every core, ROM import, saves, baseline shaders and local multi-controller play. No core or platform is ever gated.

### 4.3 What premium adds

Premium is five items. Free-tier numbers are GagaEmu policy.

| Paywall item | Free | Premium | Enforced in code today |
|---|---|---|---|
| Higher fast-forward speed | 2x | 5x | No: `maxFastForward` has no caller and no fast-forward exists. |
| Unlimited Save States | 3 | Unlimited | No: `canAddSaveState` has no caller and no save state UI exists. |
| Unlimited Cheat Codes | 3 | Unlimited | No: `canAddCheat` has no caller and no cheat UI exists. |
| Premium Filters | Original, Cartoon, CRT v1, CRT v2, Film | Geom CRT, Geom CRT Border | Yes: `canUseShader` in `FilterPickerView.swift`. |
| Auto Save State | Off | Available | Gate exists: `canUseAutoSaveState`. Its row is hidden until 2.6. |

**Sell only what works.** `anime4k` and `crt-royale` are not premium items until implemented (milestone 3.4): neither is in `premiumShaderIDs` or `ShaderCatalog`. The Premium Filters entitlement covers only cores whose frames pass through the host shader chain. Layer-path cores (N64, PSP, Dreamcast, 3DS, and Beetle PSX HW in Vulkan mode; `docs/05` section 2.5) skip host shaders until the output-texture path exists. Netplay is not gated or promised until built.

### 4.4 Paywall requirements

| Requirement | Status in `GagaPlusView.swift` |
|---|---|
| Restore Purchases | built: `AppStore.sync` |
| Redeem Offer | built: system offer-code redemption (`offerCodeRedemption`) |
| Terms and Privacy links | built, using `SiteLinks` |
| Trial and cancel disclosure | built: `StoreKitManager.disclosure` follows the selected product |
| Five paywall items | built |
| Premium Filters item states that filters apply only to cores using the host shader chain, so it does not imply they work on layer-path cores | built, as a line on the paywall |
| Prices from `Product.displayPrice` | built |
| Entitlement from StoreKit 2 `Transaction.currentEntitlements` | built (`StoreKitManager.currentEntitlements`) |
| Lifetime owners never see subscribe prompts | built: `Entitlements.showsSubscribePrompts` |

Offer badges come from `StoreKitManager.badge`, which needs an intro offer configured in App Store Connect that the user is eligible for. Lifetime always shows its own "One payment" label.

### 4.5 Release gate

The paywall stays off in submitted builds until a real core runs end to end. While it is off, the Gaga Plus category and premium labels are hidden and premium limits are lifted, so no shipped feature sits behind a purchase the user cannot make. The one switch is the `PAYWALL_ENABLED` compilation condition (`PaywallGate`, `project.yml`), absent today; `docs/07` 7.2 opens it. App Store metadata must be corrected before submission, because it currently describes gameplay that does not exist.

---

## 5. Other Subsystems

| Subsystem | Current state | Status |
|---|---|---|
| Persistence | JSON at `Application Support/GagaEmu/state.json`; no SQLite or Core Data (`AppState.swift:221-248`, `docs/03` section 8) | built |
| Audio | `AudioEngineManager`: `AVAudioEngine` ring buffer, default 44.1 kHz. No resampler, and no caller in `Sources`. | built, unused |
| Controllers | `ControllerManager`: MFi, DualShock 4, DualSense, Xbox, Joy-Con and keyboards | built, no session to feed |
| Touch skins | `TouchSkinEngine`: `.deltaskin` and flex skins, CoreHaptics | built, no session to feed |
| TriggerPro | `TriggerProManager`: turbo, hold and combo | built, no session to feed |
| Game Center | Entitlement present, GameKit linked. `GameCenter.authenticate` signs in the local player in the background, with no failure UI. No leaderboards or achievements. | built |

---

## 6. Project Generation

`project.yml` is authoritative. This listing matches it today:

```yaml
name: GagaEmu
options:
  bundleIdPrefix: com.zenithblue
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  groupSortPosition: top

configs:
  Debug:
    type: debug
    settings:
      SWIFT_OPTIMIZATION_LEVEL: "-Onone"
      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
      GCC_OPTIMIZATION_LEVEL: "0"
  Release:
    type: release
    settings:
      SWIFT_OPTIMIZATION_LEVEL: "-O"
      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
      GCC_OPTIMIZATION_LEVEL: "s"

settings:
  SWIFT_VERSION: "5.9"
  ENABLE_BITCODE: NO
  CLANG_ENABLE_MODULES: YES
  IPHONEOS_DEPLOYMENT_TARGET: "17.0"
  TARGETED_DEVICE_FAMILY: "1,2"
  DEVELOPMENT_TEAM: "9227VF8RW4"
  CODE_SIGN_STYLE: Automatic
  CODE_SIGN_IDENTITY: "Apple Development"

targets:
  GagaEmu:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Sources
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.zenithblue.gagaemu
      INFOPLIST_FILE: Sources/App/Info.plist
      CODE_SIGN_ENTITLEMENTS: Sources/App/GagaEmu.entitlements
      SWIFT_OBJC_BRIDGING_HEADER: Sources/Bridge/GagaBridge-Bridging-Header.h
      HEADER_SEARCH_PATHS:
        - $(SRCROOT)/Sources/Bridge
      OTHER_CFLAGS:
        - -std=c99
    frameworks:
      - Metal
      - MetalKit
      - GameController
      - CoreHaptics
      - AVFoundation
      - StoreKit
      - AudioToolbox

  GagaEmuTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Tests
    dependencies:
      - target: GagaEmu
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.zenithblue.GagaEmuTests
      SWIFT_OBJC_BRIDGING_HEADER: Sources/Bridge/GagaBridge-Bridging-Header.h
      HEADER_SEARCH_PATHS:
        - $(SRCROOT)/Sources/Bridge
```

Future addition, not in `project.yml` today. Each integrated core adds one embedded dependency to the app target, following `docs/03` section 5 and section 2.5 above:

```yaml
    dependencies:
      - framework: Frameworks/MgbaCore.xcframework
        embed: true
```

`GagaEmu.xcodeproj/` is generated and ignored by git, as in S3 and S4 (`S3/ios/.gitignore:2`, `S4/ios/BachataS4/project.yml:4-5`). Run `xcodegen generate` after a fresh clone; `scripts/appstore_release.sh` runs it first.
