# 06 — iOS App Architecture, C-Bridge & Subsystem Specification

This document is canonical for the bridge API and the premium and in-app purchase spec. `docs/03` is canonical for the core list, `docs/04` for interpreter design and tiers, `docs/05` for graphics, and `docs/07` for phases and status.

Manic EMU facts are marked by source. "Seen in screenshot" names the image in `maniac-emu-reference-images/`, and "GagaEmu design" means the choice is ours. This document does not claim parity with Manic EMU.

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
 │ Games, Import, Settings, ControllerManager, StoreKitManager         │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │ EmulatorCoreProtocol, GagaCoreWrapper
                                 │ (built, used only by tests)
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ C bridge: GagaBridge.h, GagaCoreRegistry (built)                    │
 │ GagaCoreInterface: one function-pointer table per core              │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ Mock core (built). 12 weak stubs (stub). Real cores (planned, docs/03)│
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

### 3.1 Games tab

**Header** (seen in screenshot `FC11608F`): controller button on the left, logo in the centre, Play History button on the right. Status: built.

**Empty state** (seen in screenshot `FC11608F`): "Welcome to MANIC EMU's World", then "Tap the [import icon] button to import", a star divider, a "Join Discord for assistance" pill and an "Ensure game ROMs are legally obtained" pill. There is no hero illustration and no import button on this screen; the "Your adventure begins here!" hero belongs to the Import tab. GagaEmu uses its own name in the welcome line. Status: built, with a placeholder Discord link (`https://discord.com`).

**Controllers panel** (seen in screenshot `026FA2CF`): a side panel that slides in from the left while the main view stays visible at the right edge. It has help and more buttons, a "Touch Control" row with a "Player 1" picker, and a controller illustration. Status: content built, but presented as a `.sheet` in `MainTabView`. Side-panel presentation is planned.

**Play History panel** (seen in screenshot `E2946B38`): slides in from the opposite side, with the main view visible at the left edge. The empty state shows crossed swords, "No Play History" and an "Import Games" button. Status: content built, also presented as a `.sheet`. Side-panel presentation is planned.

**Populated library** (GagaEmu design; no populated library appears in the reference images): a "Recently Played" carousel, platform filter chips and a game grid. Tap launches and long-press opens the menu below. Status: built, but launch only records state.

**Long-press menu.** This is the single definition of the menu; other docs point here. The only source fact is the caption "switch cores by long-pressing a game in the library" (seen in screenshot `DE9D26E2`). Everything else is GagaEmu design.

| Action | Behaviour | Status |
|---|---|---|
| Launch | Starts a game session | stub: records state only (`AppState.launch`) |
| Switch Core | Opens the core sheet, with an option to set the platform default (`docs/03` section 8) | built |
| Select Shader | Opens the Shaders sheet | built |
| Manage Saves | Save state slots with thumbnails | planned |
| Edit Metadata | Title and cover art | built for the title, as a "Rename" action; cover art planned |
| Toggle Favorite | Marks the game as a favourite | built |
| Export Save | Shares the battery save and states | planned |
| Delete | Removes the game from the library | built |

### 3.2 Import tab

Seen in screenshots `A59F001A` and `443B8BE2`. The header has a plus button on the left and a group of cloud-download, help and more buttons on the right, over the "Your adventure begins here!" hero. Screenshots do not show what those buttons do. Status: hero built; header buttons planned, scope to be decided.

| Tool | Behaviour | Status |
|---|---|---|
| Files | System document picker, including iCloud Drive (screenshot `443B8BE2` shows Recents, Shared and Browse). | built |
| WiFi | LAN upload server, **off by default**, started only by the user's toggle. Each start creates a fresh 4-digit PIN. Port 8080. The PIN is required for every write, and uploads are capped at 2 GiB with sanitized file names (`Sources/Hub/WiFiTransferServer.swift`). | built |
| Read Clipboard | **Tap only**: `ClipboardImporter.scan` is called from the button and never automatically. Supports files copied from macOS or the Files app. | built |
| MultiDisc Helper | Groups disc files into one `.m3u` entry. | built |
| RomPatcher | IPS, BPS and UPS patches, in memory, on a copy of the source. IPS RLE records are not supported and throw an error (`Sources/Hub/RomPatcher.swift:91`). | built |
| Drag & Drop | Drop target on the Import tab (`onDrop`). The screenshot's wording says any interface; app-wide coverage is planned. | built |
| Join Discord pill | Same link as Support. | built, placeholder link |

**Security note on WiFi transfer.** Traffic is plain HTTP, so the PIN and files cross the local network unencrypted. The code has no limit on PIN attempts, a 4-digit PIN has only 10,000 values, and the PIN is also accepted in the query string, where it can end up in browser history. The server stays off by default and should stay on only while the user is transferring. `docs/07` tracks an attempt limit and removal of the query-string PIN. `NSLocalNetworkUsageDescription` is present in `Info.plist`.

### 3.3 Settings tab

**Top of screen** (seen in screenshot `F7ADD189`): a membership banner reading "Unlock MANIC EMU membership" with "You are the protagonist of this story" and a "50% Off" pill, followed by the "Adventurer Card" with Nickname, Play Time, Joined and an avatar. Status: both built, with GagaEmu's name in the banner. Banner behaviour follows section 4.

The tables below use the labels seen in the screenshots. A row marked stub must be implemented or hidden before submission (`docs/07`).

**General** (seen in `F7ADD189`, `44F4AEE0`)

| Row | GagaEmu behaviour | Status |
|---|---|---|
| Appearance | Dark, Light and System | built |
| Theme | App icons, theme colours, boxart settings, console ordering | stub |
| Quick Start | Skip preparation page | stub |
| Auto Save States | Automatic save states. Premium item, section 4. | stub: a free toggle today |
| Assign Skin | Choose a touch skin. `TouchSkinEngine` loads `.deltaskin` and flex (JSON and SVG) skins. | stub: row empty, engine built |
| Cover Scraping | OpenVGDB and Libretro Thumbnails, with SteamGridDB under consideration | stub |

**Advanced** (seen in `44F4AEE0`, `C4E3779B`, `8A17681E`)

| Row | GagaEmu behaviour | Status |
|---|---|---|
| AirPlay Fullscreen | Full-screen mirroring | stub |
| iCloud Sync | Save sync | stub: flips a stored flag |
| Auto Full Screen | Enters full screen when a controller connects | stub |
| BIOS | Lists BIOS files and shows SHA-1 once imported | built |
| Respect Silent Mode | Plays audio only when not in silent mode | stub |
| Online Play Settings | Not promised. Netplay is not gated or promised until built. | stub: row empty |
| Rumble | Device vibration during certain events | stub |
| Skin Sound Effects | Sound on touch skin presses | stub |
| RetroAchievements | Sign-in and achievements | stub: row empty |
| TriggerPro | "Create and manage advanced custom buttons." | built: editor and logic, no session to apply it |
| JIT | **Deliberately dropped.** Manic shows this row (`C4E3779B`). GagaEmu ships no JIT, so there is nothing to configure, and the row must not be added. | not applicable |
| Shaders | `docs/05` section 3 | built |
| Emulator Core | Lists platforms with their current core (seen in `3D38E22D`, `DE9D26E2`). GagaEmu's defaults come from `docs/03`, not from Manic's list. | built, using the old catalog |

**Support** (seen in `8A17681E`). Scope is a GagaEmu decision.

| Row | Scope decision | Status |
|---|---|---|
| FAQ | Keep | built: link to `https://gagaemu.app/faq`, reachability unverified |
| Feedback | Keep | built: `mailto:support@gagaemu.app` |
| Join QQ Channel | Out of v1 unless the owner runs a channel. Remove the row until then. | stub: link to `https://gagaemu.app/qq`, unverified |
| Join Discord | Keep only with a real invite. Without a server, remove this row and both Discord pills. | stub: placeholder link |

**Others** (seen in `8A17681E`, `9EFF77AC`). Scope is a GagaEmu decision.

| Row | Scope decision | Status |
|---|---|---|
| About Us | Keep | stub |
| Share Gaga-Emu | Keep, using the system share sheet | stub |
| Clear Cache | Keep. Asks for confirmation, then removes the Caches directory. | built |
| Reset Tips | Keep once the app has dismissible tips; hide until then | stub |
| Language | Keep once a second localisation exists; English only until then | stub: display only |
| Terms of Service | Keep; required | built: link |
| Privacy Policy | Keep; required | built: link |
| Featured Items | Dropped. GagaEmu has no catalogue to feature. Remove the empty row. | stub |
| More from Manic | Dropped. This is Manic's cross-promotion; GagaEmu has no equivalent. | not built |
| Rate Us | Keep, using the system review prompt, after a real core runs. Reword the "5-star" copy. | stub: card only |

The Terms, Privacy, FAQ and QQ links use `gagaemu.app`, while the App Store metadata uses `zenithblue-oss.github.io/gaga-emu-site`. One host must be chosen (`docs/07`).

---

## 4. Premium and In-App Purchases

This section is canonical. Code changes it requires are roadmap items in `docs/07`.

### 4.1 Products

Three products with existing IDs, from `Sources/Store/StoreKitManager.swift`:

| Product ID | Label | Type |
|---|---|---|
| `monthly.sub` | Monthly Membership | Auto-renewing subscription |
| `annual.sub` | Annual Membership | Auto-renewing subscription |
| `lifetime.pass` | Lifetime Pass | Non-consumable, one-time payment |

The labels match screenshot `0596EA12`. Prices always come from `Product.displayPrice` and are never hard-coded. Prices in the screenshot are Manic's and do not apply here.

### 4.2 What stays free

Emulation stays free: every core, ROM import, saves, baseline shaders and local multi-controller play. No core or platform is ever gated.

### 4.3 What premium adds

Premium is the five items on Manic's paywall (seen in screenshot `0596EA12`). Free-tier numbers are GagaEmu policy and are not Manic facts.

| Paywall item | Free | Premium | Enforced in code today |
|---|---|---|---|
| Higher fast-forward speed | 2x | 5x | No: `maxFastForward` has no caller and no fast-forward exists. The screenshot's card is partly hidden, so Manic's multiplier is unconfirmed, and "5x Speed" is GagaEmu's value. |
| Unlimited Save States | 3 | Unlimited | No: `canAddSaveState` has no caller and no save state UI exists. |
| Unlimited Cheat Codes | 3 | Unlimited | No: `canAddCheat` has no caller and no cheat UI exists. |
| Premium Filters | Original, Cartoon, CRT v1, CRT v2, Film | Geom CRT, Geom CRT Border | Yes: `canUseShader` in `ShadersSettingsView.swift:65`. |
| Auto Save State | Off | Available | No: `Entitlements` has no such member, and `AppState.autoSaveStates` is a free toggle. |

**Sell only what works.** `anime4k` and `crt-royale` are not premium items until implemented. Both are in `premiumShaderIDs` today, and `anime4k` is in `ShaderCatalog` and falls back to Original. The Premium Filters entitlement covers only cores whose frames pass through the host shader chain. Layer-path cores (N64, PSP, Dreamcast, 3DS, and Beetle PSX HW in Vulkan mode; `docs/05` section 2.5) skip host shaders until the output-texture path exists. Netplay is not gated or promised until built.

### 4.4 Paywall requirements

| Requirement | Status in `MembershipPaywallView.swift` |
|---|---|
| Restore Purchases | built: `AppStore.sync` |
| Redeem Offer | stub: the button action is empty (`:63`). Planned: system offer-code redemption. |
| Terms and Privacy links | built, on the unsettled host above |
| Trial and cancel disclosure | built as fixed text (`:24`). It must match what the selected product actually offers. |
| Five paywall items | built |
| Premium Filters item states that filters apply only to cores using the host shader chain, so it does not imply they work on layer-path cores | planned |
| Prices from `Product.displayPrice` | built |
| Entitlement from StoreKit 2 `Transaction.currentEntitlements` | built (`StoreKitManager.swift:128-135`) |
| Lifetime owners never see subscribe prompts | planned: `hasPremium` does not distinguish lifetime, and the banner opens the paywall for every user |

The "50% Off" and "Introductory Offer" badges are hard-coded (`StoreKitManager.swift:144,148`). A badge may show only when App Store Connect has that offer configured.

### 4.5 Release gate

The paywall stays off in submitted builds until a real core runs end to end. While it is off, the banner is hidden and premium limits are lifted, so no shipped feature sits behind a purchase the user cannot make. App Store metadata must be corrected before submission, because it currently describes gameplay that does not exist. The code has no such gate yet (`docs/07`).

---

## 5. Other Subsystems

| Subsystem | Current state | Status |
|---|---|---|
| Persistence | JSON at `Application Support/GagaEmu/state.json`; no SQLite or Core Data (`AppState.swift:221-248`, `docs/03` section 8) | built |
| Audio | `AudioEngineManager`: `AVAudioEngine` ring buffer, default 44.1 kHz. No resampler, and no caller in `Sources`. | built, unused |
| Controllers | `ControllerManager`: MFi, DualShock 4, DualSense, Xbox, Joy-Con and keyboards | built, no session to feed |
| Touch skins | `TouchSkinEngine`: `.deltaskin` and flex skins, CoreHaptics | built, no session to feed |
| TriggerPro | `TriggerProManager`: turbo, hold and combo | built, no session to feed |
| Game Center | `com.apple.developer.game-center` entitlement present; GameKit is not linked or used | stub |

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

`GagaEmu.xcodeproj/project.pbxproj` is tracked in git, which works against generating the project from `project.yml`. S3 and S4 do not commit their generated project (`S3/ios/.gitignore:2`, `S4/ios/BachataS4/project.yml:4-5`). `docs/07` tracks removing it.
