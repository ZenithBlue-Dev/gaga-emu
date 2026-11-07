# 06 — iOS App Architecture, C-Bridge & Subsystem Specification

This document is canonical for the bridge API and the premium and in-app purchase spec. `docs/03` is canonical for the core list, `docs/04` for interpreter design and tiers, `docs/05` for graphics, and `docs/07` for phases and status.

Manic EMU is a feature reference only, tracked in `docs/02`. Nothing in this document copies its UI.

---

## Status

The app runs a full game session on mGBA, the first real core, and on the mock core. The 10 other non-mock registry cores are stubs: their `self_test` fails, so `GagaCoreWrapper` refuses them and the player sees that the core is not part of this build.

Status terms used in this document:

- **built:** the code exists and does its job in the shell.
- **stub:** the row, toggle or symbol exists, but nothing acts on it. A stub toggle persists its value and no code reads it.
- **planned:** no code exists.

Status comes from reading the code and running the iOS Simulator, not from a device test.

---

## 1. System Decomposition

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │ SwiftUI app (built)                                                 │
 │ Library, Add, Settings, GameView, GameSession, ControllerManager    │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │ EmulatorCoreProtocol, GagaCoreWrapper
                                 │ (built)
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ C bridge: GagaBridge.h, GagaCoreRegistry (built)                    │
 │ GagaCoreInterface: one function-pointer table per core              │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ Mock core, MgbaCore.xcframework (built). 10 weak stubs (stub).      │
 └───────────────────────────────┬─────────────────────────────────────┘
                                 │ video and audio callbacks
 ┌───────────────────────────────┴─────────────────────────────────────┐
 │ Video: Metal paths in docs/05. Audio: AudioEngineManager.           │
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

// Bump on any change to GagaCoreInterface. The host refuses a core built for another version.
#define GAGA_BRIDGE_ABI_VERSION 1u

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

typedef enum {
    GAGA_EVENT_INFO    = 0,
    GAGA_EVENT_WARNING = 1,
    GAGA_EVENT_FATAL   = 2, // The host ends the session and shows the message.
} GagaEventSeverity;

// Threading contract. The host makes every instance call on one serial queue, never concurrently.
// Video, audio and event callbacks must fire on that queue, inside a host call to the core. A core
// with worker threads marshals to step_frame. Descriptor pointers and event messages are valid only
// during the callback. No callback may fire after destroy returns.

// Core Lifecycle Interface
typedef struct GagaCoreInterface {
    // Stays the first member, so the host can read it before trusting the rest of the table.
    uint32_t    abi_version;          // GAGA_BRIDGE_ABI_VERSION
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

    // Layer attachment for 3D cores (Beetle PSX HW, PPSSPP, Azahar). No core implements it yet.
    bool (*attach_metal_layer)(GagaInstance* inst, void* ca_metal_layer);

    // Audio & Video callbacks
    void (*set_video_callback)(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor* frame, void* userdata), void* userdata);
    void (*set_audio_callback)(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor* audio, void* userdata), void* userdata);

    // Save States (File-path based to support dynamic NAND/Card sizes)
    bool (*save_state_file)(GagaInstance* inst, const char* file_path);
    bool (*load_state_file)(GagaInstance* inst, const char* file_path);

    // Cheats
    void (*apply_cheat)(GagaInstance* inst, uint32_t index, bool enabled, const char* code);

    // Runs with no instance or game. Returns false and fills error on failure.
    bool (*self_test)(char* error, size_t error_capacity);

    // The host pauses before the app leaves the foreground. No step_frame runs between the two.
    void (*pause)(GagaInstance* inst);
    void (*resume)(GagaInstance* inst);

    // Errors and events. A FATAL event during load_rom supplies the message the player sees.
    void (*set_event_callback)(GagaInstance* inst,
        void (*cb)(GagaEventSeverity severity, int32_t code, const char* message, void* userdata), void* userdata);
} GagaCoreInterface;

#ifdef __cplusplus
}
#endif

#endif // GAGA_BRIDGE_H
```

### 2.2 Registry (built)

`Sources/Bridge/GagaCoreRegistry.h` declares one getter per core (`Mgba_GetInterface` and so on), the working `MockCore_GetInterface`, and four lookups:

```c
size_t GagaCoreRegistry_GetCount(void);
const GagaCoreInterface* GagaCoreRegistry_GetAtIndex(size_t index);
const GagaCoreInterface* GagaCoreRegistry_FindByID(const char* core_id);
const GagaCoreInterface* GagaCoreRegistry_FindByExtension(const char* extension);
```

The table is compile-time; `docs/03` section 8 shows it and lists where the code disagrees with the catalog. The short lowercase `core_id` is the planned single ID scheme.

Each remaining stub is a weak definition in the app binary. A core's stub must be deleted when its framework is linked, or the app's own definition will win over the framework's symbol. The mGBA stub is deleted.

### 2.3 Swift layer (built)

`Sources/Bridge/EmulatorCoreProtocol.swift` defines `EmulatorCoreError`, `VideoFrame`, `AudioPacket`, `EmulatorCoreProtocol` and `GagaCoreWrapper`. The wrapper's initializer throws: it checks `abi_version`, runs `self_test` and creates the instance, so a core that fails either check never gets an instance. A `.userInteractive` serial queue owns every instance call, and a strict timer at `target_fps` drives `step_frame`. `pause` and `stop` are synchronous barriers on that queue, so no callback runs after they return. `Sources/Session/GameSession.swift` is the only caller in the app. `create` gets a per-game save directory, `Saves/<rom file name>/`, from `GagaCoreWrapper.saveDirectory(forROM:)`, and `load_rom` gets a path only.

### 2.4 Bridge additions

**Built** (2.5, listed in section 2.1): `GAGA_BRIDGE_ABI_VERSION` with `abi_version`, `self_test`, `pause`, `resume`, `set_event_callback` and `GagaEventSeverity`. A fatal event during `load_rom` supplies the message the player sees. A fatal event while playing ends the session and shows its message on the Library.

**Planned.** These arrive with the frame paths that need them. Each changes `GagaCoreInterface`, so each bumps the ABI version.

```c
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

// Added to GagaCoreInterface.
uint32_t capabilities; // GagaCoreCapability bits

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

Per `docs/03` section 5: each core is a dynamic, embedded xcframework that exports only the bridge entry point. Several libretro cores in one image would collide on `retro_*` symbols, and an export list keeps each core's internals private. S3 and S4 follow this shape (`S3/ios/SambaS3/project-core.yml:11-12`, `S4/ios/BachataS4/project-core.yml:16-17`, `S4/src/platform/ios/BachataCore.exports`).

Frameworks are signed and shipped inside the app bundle. Code is never loaded from user paths or downloaded. Dynamic linking does not change the GPL analysis in `docs/03` section 5.

Status: built for mGBA. `scripts/build-core.sh` writes `build/cores/MgbaCore.xcframework`, arm64 only, for simulator and device. The app's `project.yml` embeds it. There is no separate core project as in S3, because `xcodebuild -create-xcframework` from a script is simpler when the core has no Xcode targets of its own. Build outputs are not committed, so `scripts/build-core.sh` must run before `xcodegen generate` and a build (README).

**Adding the next core.** Follow these in order. `<id>` is the `core_id` in `CoreCatalog`, `<Name>` is the prefix of its stub in `GagaCoreRegistry.c`.

1. **Read the gates.** For a GPL core, milestone 4.0 must be closed. Read `docs/07` section 2 and the core's row in `docs/03`. Read any upstream script before running it; `build-core.sh` runs none.
2. **Vendor and pin.** Confirm the URL is the project's official repository, then run these. The final `git add` is what records the pin: without it, a clean checkout gets whatever the branch tip was.
   ```bash
   git submodule add <official-url> Cores/<id>/upstream
   git -C Cores/<id>/upstream checkout <tag-or-commit>
   git add .gitmodules Cores/<id>/upstream
   ```
3. **Write `Cores/<id>/core.env`.** Copy `Cores/mgba/core.env` and set all of these:
   - `CORE_FRAMEWORK`, for example `GambatteCore`.
   - `CORE_EXPORT`, exactly `_<Name>_GetInterface`.
   - `CORE_VERSION`, `UPSTREAM_TAG`, and the full 40-character `UPSTREAM_COMMIT`. The build stops if the submodule is at any other commit.
   - `CORE_CFLAGS` and `CORE_CXXFLAGS`. Paths are relative to `Cores/<id>/`. `Sources/Bridge` is already on the include path, and `GAGA_CORE_VERSION` is already defined.
   - `FORBIDDEN_STRINGS`, the core's JIT runtime names from its audit. Never bare `jit` (`docs/04` section 8).
   - `FORBIDDEN_IMPORTS`, a regex of APIs from features you disabled, such as `_socket$`.
4. **Write `Cores/<id>/<Framework>.exports`.** One line: `_<Name>_GetInterface`.
5. **Write `Cores/<id>/flags.h` if the core needs build defines.** Force it with `-include flags.h` in `CORE_CFLAGS`. Disable debuggers, frontends, scripting, networking, updaters and any dynarec.
6. **Write `Cores/<id>/sources.txt`.** One path per line, relative to `Cores/<id>/`, listing the bridge and exactly the upstream files needed. `.c` uses `CORE_CFLAGS`, `.cpp` and `.cc` use `CORE_CXXFLAGS`. Upstream's own build system is not run. Check each third-party file's licence and add it to `docs/03`.
7. **Write the bridge, `Cores/<id>/<Framework>.c`,** implementing `GagaCoreInterface` from `GagaBridge.h`:
   - Set `abi_version` first. Implement `self_test`, which runs with no instance and before `create`, `pause`, `resume` and `set_event_callback`.
   - Every instance call runs on one serial queue. Callbacks fire on it, inside a host call. Marshal any worker thread to `step_frame`. Descriptor and message pointers are valid only during the callback. No callback after `destroy` returns.
   - `load_rom` gets a path only, and returns false after a FATAL event whose message the player can read. FATAL during play ends the session with its message.
   - The host timer calls `step_frame` at `target_fps` with 4 inputs. Do not self-pace. Each audio packet carries `sample_rate`.
   - Write battery saves into the `save_dir` you are given. `Cores/mgba/MgbaCore.c` is the pattern.
8. **Delete the core's `DEFINE_CORE_INTERFACE(<Name>_GetInterface, ...)` line** in `Sources/Bridge/GagaCoreRegistry.c`. Keep its entry in `s_core_getters`. Check that `CoreCatalog` has the `core_id` and the file extensions the core really accepts.
9. **Add to `project.yml`,** under the `GagaEmu` target's `dependencies`, then run `xcodegen generate`:
   ```yaml
      - framework: build/cores/<Framework>.xcframework
        embed: true
   ```
10. **Build.** `scripts/build-core.sh <id>` must print `exports (iphonesimulator): _<Name>_GetInterface`, the same for `iphoneos`, and `no-JIT gate: pass <Framework>` twice. The app's post-build gate must print `pass` for the framework. It fails the build if the framework is not embedded.
11. **Check the privacy manifest.** Run `nm -u` on the framework. Any required-reason API, such as `fstat`, needs an entry in `Sources/App/PrivacyInfo.xcprivacy`.
12. **Test.** Add `Tests/<Name>CoreTests.swift`, reaching the core through `GagaCoreRegistry_FindByID("<id>")`, because the test bundle cannot link the framework's symbol. Use a homebrew or generated ROM, never a commercial one, and no vendor BIOS. Assert that it loads, frames match, input changes the frame, audio is non-silent, a FATAL message arrives, and `CodeGenCheck.violations()` is empty after a run. `Tests/MgbaCoreTests.swift` and `Sources/Debug/GBATestROM.swift` are the pattern. Update any test that uses this core's ID as its example of a stub.
13. **Verify in the app on the Simulator.** Import through a real importer, launch from the Library, press a touch control, pause, resume, quit, relaunch ten times, and check the `.sav`. Run the tests with `-enableThreadSanitizer YES`. Build `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO`, both Debug and Release.
14. **Record.** Update the core's rows in `docs/03` (pin, licence, no-JIT) and `docs/04` section 7.1, and its milestone in `docs/07`. Its status stays "built, device benchmark pending" until a device run per `docs/04` section 7.2 exists.

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

Tapping a cover plays, as does the Play button. The game view opens only once the core has loaded the game (section 3.7).

**Long-press menu.** This is the single definition of the menu; other docs point here.

| Action | Behaviour | Status |
|---|---|---|
| Play | Starts a game session | built: only the mock core can run a game until 2.9 |
| Change Core | Opens the core picker, with an option to set the platform default (`docs/03` section 8) | built |
| Choose Filter | Opens the filter picker for this game | built: the game session applies it |
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
| Play | Total play time and session count, read-only. Quick Start opens the most recent game when the app starts, because GagaEmu has no preparation page to skip. Auto Full Screen removes the touch bands when a controller owns Player 1. Respect Silent Mode makes game audio obey the silent switch. | built |
| Library | Game count, BIOS Files, default core per platform | built |
| Graphics | Default Filter, which opens the filter picker | built |
| Controls | Touch Control, connected controllers with their player slot, TriggerPro. Rumble is a haptic on each touch press, because the bridge has no rumble event yet. Skin Sound Effects is a click on each touch press. | built |
| Storage | Game files size, Clear Cache with confirmation. Clear Cache removes the Caches directory. | built |
| Gaga Plus | Status and See Plans. Absent while the paywall gate is closed (section 4.5). Lifetime owners get no See Plans row. | built, gated |
| About | Version, Support and FAQ, Feedback, Rate Gaga-Emu, Terms of Service, Privacy Policy. Debug builds add Run Benchmark. | built: Rate Gaga-Emu uses the system review prompt. Support and Feedback link to `support.html`, because the App Store metadata has no support email. Terms is Apple's standard EULA, because the site has no terms page. |

All site links use `zenithblue-oss.github.io/gaga-emu-site` (`SiteLinks`), the host the App Store metadata uses.

There is no profile card, nickname, avatar or membership banner. `nickname`, `joined` and `avatarIndex` stay in `state.json` so saved data still loads.

**Rows not shown yet.** Each has no working behaviour today. Saved values stay in `state.json`.

| Row | Home when it returns | Returns with |
|---|---|---|
| Auto Save States | Play | 2.6, gated by `canUseAutoSaveState` |
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

### 3.7 Game view and pause menu

`GameView` covers the whole screen, with the status bar and home indicator hidden. The picture is aspect fit on the ink letterbox, which stays dark in both appearances. Touch controls sit in a band on each side of the picture, inside the safe area, with hit areas of at least 44pt. The left band holds L, the D-pad and Select. The right band holds R, the face buttons and Start. A pause button sits top left. When a controller owns Player 1, the controls hide; with Auto Full Screen on, the bands go too and the picture takes the width. Every control has a VoiceOver label, and activating one presses that button briefly.

The pause menu is a compact paper side sheet over the dimmed game: Paused, the game title, Resume and Quit to Library. Later entries, such as save states, appear only when they work. Opening it pauses the core and audio. Quit ends the session and returns to the Library, where Continue shows the game.

**Pausing.** The menu, backgrounding and audio interruptions are separate reasons, and play resumes only when all have cleared. An interruption that ends without the system's resume hint leaves the menu open, so the player chooses.

**Failures.** A load runs before the game view opens. If it fails, the Library shows an alert with the core's own message and no game view opens. A fatal core event while playing closes the game view and shows the same alert.

`shortcut:` the pause button is the only way to open the menu, so a player with a controller still reaches for the screen. A controller combination is the upgrade.

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
| Audio | `AudioEngineManager`: `AVAudioEngine` source node pulling from a ring buffer, with `LinearResampler` converting core audio to 48 kHz. | built |
| Controllers | `ControllerManager`: MFi, DualShock 4, DualSense, Xbox, Joy-Con and keyboards | built. Keyboard mapping exists, but the session does not read it yet. |
| Touch skins | `TouchSkinEngine`: `.deltaskin` and flex skins, CoreHaptics. One default layout for all platforms; 3.9 adds skin assignment. | built |
| TriggerPro | `TriggerProManager`: turbo, hold and combo, on player 1 | built |
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
  # Paywall release gate: stays out until milestone 7.2 opens it (docs/06 section 4.5).
  # To open it, add here: SWIFT_ACTIVE_COMPILATION_CONDITIONS: $(inherited) PAYWALL_ENABLED
  SWIFT_VERSION: "5.9"
  ENABLE_BITCODE: NO
  CLANG_ENABLE_MODULES: YES
  IPHONEOS_DEPLOYMENT_TARGET: "17.0"
  TARGETED_DEVICE_FAMILY: "1,2"
  DEVELOPMENT_TEAM: "9227VF8RW4"
  CODE_SIGN_STYLE: Automatic
  CODE_SIGN_IDENTITY: "Apple Development"
  # Cores are built for arm64 only (scripts/build-core.sh).
  "EXCLUDED_ARCHS[sdk=iphonesimulator*]": x86_64

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
      ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      CODE_SIGN_ENTITLEMENTS: Sources/App/GagaEmu.entitlements
      SWIFT_OBJC_BRIDGING_HEADER: Sources/Bridge/GagaBridge-Bridging-Header.h
      HEADER_SEARCH_PATHS:
        - $(SRCROOT)/Sources/Bridge
      # Not OTHER_CFLAGS: C++ inherits those, and -std=c99 is an error in a C++ compile.
      GCC_C_LANGUAGE_STANDARD: c99
      # The no-JIT gate reads the built app, outside what a sandboxed script may read.
      ENABLE_USER_SCRIPT_SANDBOXING: NO
    dependencies:
      # Built by scripts/build-core.sh, which must run first. See README.
      - framework: build/cores/MgbaCore.xcframework
        embed: true
    frameworks:
      - Metal
      - MetalKit
      - GameController
      - CoreHaptics
      - AVFoundation
      - StoreKit
      - AudioToolbox
      - GameKit
    postBuildScripts:
      - name: No-JIT gate
        script: '"$SRCROOT/scripts/nojit-gate.sh" --app "$TARGET_BUILD_DIR/$WRAPPER_NAME" "$SRCROOT/$CODE_SIGN_ENTITLEMENTS"'
        basedOnDependencyAnalysis: false
      - name: Record build commit
        script: 'git -C "$SRCROOT" describe --always --dirty --exclude "*" > "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/build-commit.txt"'
        basedOnDependencyAnalysis: false

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
      GENERATE_INFOPLIST_FILE: YES
      SWIFT_OBJC_BRIDGING_HEADER: Sources/Bridge/GagaBridge-Bridging-Header.h
      HEADER_SEARCH_PATHS:
        - $(SRCROOT)/Sources/Bridge
```

Each integrated core adds one embedded dependency to the app target, per section 2.5 above.

`GagaEmu.xcodeproj/` is generated and ignored by git, as in S3 and S4 (`S3/ios/.gitignore:2`, `S4/ios/BachataS4/project.yml:4-5`). After a fresh clone, run the build command in the README; `scripts/appstore_release.sh` runs the same steps first.
