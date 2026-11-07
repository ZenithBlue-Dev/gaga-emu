# 06 — iOS App Architecture, C-Bridge & Subsystem Specification

This document is canonical for the bridge API and the premium and in-app purchase spec. `docs/03` is canonical for the core list, `docs/04` for interpreter design and tiers, `docs/05` for graphics, and `docs/07` for phases and status.

Manic EMU is a feature reference only, tracked in `docs/02`. Nothing in this document copies its UI.

---

## Status

The app runs a full game session on mGBA, on Gambatte (the first core through the shared libretro adapter, merged from the `core/gambatte` branch, with its GPL gate still open), on Nestopia UE, PCSX-ReARMed, bsnes and melonDS DS (through the same adapter, merged from branches `core/nestopia`, `core/pcsx_rearmed`, `core/bsnes` and `core/melonds_ds`, GPL gate open) and on the mock core. The 6 other non-mock registry cores are stubs: their `self_test` fails, so `GagaCoreWrapper` refuses them and the player sees that the core is not part of this build.

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
 │ Mock core; Mgba, Gambatte, Nestopia, PcsxReArmed, Bsnes and MelonDS │
 │ xcframeworks (built). 6 weak stubs (stub).                          │
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

// Bump on any change to GagaCoreInterface or the structs it passes. The host refuses a core built for another version.
#define GAGA_BRIDGE_ABI_VERSION 5u

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
    // One finger on the game picture, in libretro's pointer scale over the whole frame the core last
    // sent: -32767 is the left or top edge, 32767 the right or bottom edge. Player 1 only.
    int16_t  pointer_x;
    int16_t  pointer_y;
    bool     pointer_down;
    // Keys held on a hardware keyboard, by USB HID usage (page 7, as GCKeyCode): usage u is bit (u & 7) of
    // keys[u >> 3]. Player 1 only, and only for a core that types (DOS); others get it zeroed.
    uint8_t  keys[32];
} GagaInputState;

// Pixel formats emitted by core
typedef enum {
    GAGA_PIXEL_FORMAT_RGB565   = 0,
    GAGA_PIXEL_FORMAT_XRGB8888 = 1,
    GAGA_PIXEL_FORMAT_RGBA8888 = 2,
} GagaPixelFormat;

// Video frame descriptor emitted to Metal
typedef struct {
    const void* pixel_data;   // NULL from a layer-path core, which sends the size of each frame it presents
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

// Bits 0 and 2 are kept for the host-buffer and output-texture paths (docs/06 section 2.4).
typedef enum {
    GAGA_CORE_CAP_METAL_LAYER = 1u << 1, // Presents to an attached CAMetalLayer. Host shaders do not run.
} GagaCoreCapability;

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
    uint32_t    capabilities;         // GagaCoreCapability bits

    // Instance lifecycle
    GagaInstance* (*create)(const char* system_dir, const char* save_dir);
    void          (*destroy)(GagaInstance* inst);

    // Media ingestion
    bool (*load_rom)(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size);
    void (*reset)(GagaInstance* inst);

    // Execution slice (supports up to 4 local controller inputs)
    void (*step_frame)(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count);

    // Layer path, for a core with GAGA_CORE_CAP_METAL_LAYER. The host attaches its CAMetalLayer with the
    // drawable size in pixels, and again whenever that size changes. Frames stepped while no layer is
    // attached render but are not shown. Detach returns with no GPU work using the layer.
    bool (*attach_metal_layer)(GagaInstance* inst, void* ca_metal_layer,
                               uint32_t width_px, uint32_t height_px, float content_scale);
    void (*detach_metal_layer)(GagaInstance* inst);
    // Copies the frame last presented, at the size the core rendered it, as BGRA8 rows of width * 4
    // bytes, and sets width and height. False if there is none or capacity is short. For thumbnails and tests.
    bool (*read_layer_pixels)(GagaInstance* inst, void* pixels, size_t capacity, uint32_t* width, uint32_t* height);

    // Audio & Video callbacks
    void (*set_video_callback)(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor* frame, void* userdata), void* userdata);
    void (*set_audio_callback)(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor* audio, void* userdata), void* userdata);

    // Save states. A core only fills and reads bytes: the host owns files, headers, checksums and atomic
    // writes. state_size is the exact byte count save_state writes now. NULL state_size means no states.
    // state_version changes when old state bytes stop meaning the same thing. The host refuses any other.
    uint32_t state_version;
    size_t (*state_size)(GagaInstance* inst);
    bool   (*save_state)(GagaInstance* inst, void* buffer, size_t size);
    // False fills error, which may be NULL. The running game must be unchanged afterwards.
    bool   (*load_state)(GagaInstance* inst, const void* buffer, size_t size, char* error, size_t error_capacity);

    // Forces battery save data to storage. Called on pause and before destroy. NULL if a core has none.
    void (*flush_battery_save)(GagaInstance* inst);

    // Cheats, by a host-chosen ID. code holds one or more newline-separated lines in any format the core
    // recognises. False fills error, which may be NULL, and adds nothing. NULL cheat_add means no cheats.
    bool (*cheat_add)(GagaInstance* inst, uint32_t id, const char* code, bool enabled, char* error, size_t error_capacity);
    void (*cheat_remove)(GagaInstance* inst, uint32_t id);
    void (*cheat_set_enabled)(GagaInstance* inst, uint32_t id, bool enabled);

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
// True for a core with a framework in Cores/ that GAGA_CORE_SET left out of this build.
bool GagaCoreRegistry_IsExcluded(const char* core_id);
```

The table is compile-time; `docs/03` section 8 shows it and lists where the code disagrees with the catalog. The short lowercase `core_id` is the planned single ID scheme.

Each remaining stub is a weak definition in the app binary. A linked framework's symbol must not meet its stub, or the app's own definition wins. So a core with a framework keeps its stub inside `#ifndef GAGA_HAS_<ID>`, with core version `"excluded"`: a build whose core set leaves the core out gets the stub, and `CoreCatalog.platforms` hides that core, and any platform left with no core. mGBA and Gambatte stubs are guarded this way.

### 2.3 Swift layer (built)

`Sources/Bridge/EmulatorCoreProtocol.swift` defines `EmulatorCoreError`, `VideoFrame`, `AudioPacket`, `EmulatorCoreProtocol` and `GagaCoreWrapper`. The wrapper's initializer throws: it checks `abi_version`, runs `self_test` and creates the instance, so a core that fails either check never gets an instance. A `.userInteractive` serial queue owns every instance call, and a strict timer at `target_fps` drives `step_frame`. `pause` and `stop` are synchronous barriers on that queue, so no callback runs after they return. `Sources/Session/GameSession.swift` is the only caller in the app. `create` gets a per-game save directory, `Saves/<rom file name>/`, from `GagaCoreWrapper.saveDirectory(forROM:)`, and `load_rom` gets a path only.

`Sources/Session/SaveStore.swift` owns everything on disk for a game. State files go in `States/` and `cheats.json` beside them, in the same save directory, so both outlive the game's place in the Library. `SaveStateFile` wraps the core's bytes in a header: `GAGASTAT`, format version, 32-byte core ID, `state_version`, payload length and SHA-256. It checks all of these before a core sees a byte. Every file goes through `AtomicFile`: temp file, `fsync`, `rename`. The wrapper takes a snapshot of the running game before `load_state`, and loads it back if the core refuses, so a bad state leaves the game running.

Fast-forward runs whole frames: at N times speed, each timer tick steps the core N times, presents only the last frame and drops the audio of all N, so nothing plays pitched up or out of step.

### 2.4 Bridge additions

**Built** (2.5 and 2.10, listed in section 2.1): `GAGA_BRIDGE_ABI_VERSION` with `abi_version`, `self_test`, `pause`, `resume`, `set_event_callback` and `GagaEventSeverity`. A fatal event during `load_rom` supplies the message the player sees. A fatal event while playing ends the session and shows its message on the Library. ABI 2 replaced the file-path save state calls and `apply_cheat`, which no core used, with `state_version`, `state_size`, `save_state`, `load_state`, `flush_battery_save`, `cheat_add`, `cheat_remove` and `cheat_set_enabled`.

**Built in ABI 5** (milestones 5.1 and 4.8, listed in section 2.1). Branches `core/moltenvk` and `core/dosbox_pure` each made a different ABI 4; the merge combines both as ABI 5, so a core built on either branch is refused, not mistaken for the merged layout. From milestone 5.1: `GagaCoreCapability` with `GAGA_CORE_CAP_METAL_LAYER`, `capabilities`, the size-aware `attach_metal_layer`, `detach_metal_layer` and `read_layer_pixels`. A layer-path core sends a size-only frame descriptor (`pixel_data` NULL) for each frame it presents. `read_layer_pixels` serves save-state thumbnails and tests. `GameSession` attaches its `CAMetalLayer` from the game view on every drawable size change and detaches only the layer attached last, so a picture moving to the external screen keeps going. The libretro side is `Cores/shared/LibretroVulkan.c` (`docs/05` section 2.3). From milestone 4.8: `GagaInputState.keys`, the hardware keyboard (section 2.5).

**Planned.** These arrive with the frame paths that need them. Each changes `GagaCoreInterface`, so each bumps the ABI version.

```c
// GagaCoreCapability bits 0 and 2.
GAGA_CORE_CAP_HOST_BUFFER    = 1u << 0, // accepts set_host_framebuffer
GAGA_CORE_CAP_OUTPUT_TEXTURE = 1u << 2, // hands back an MTLTexture

typedef struct {
    void*           base;          // MTLBuffer.contents() of the current ring slot
    size_t          bytes_per_row; // from minimumLinearTextureAlignment(for:)
    uint32_t        width;
    uint32_t        height;
    GagaPixelFormat format;
} GagaHostFramebuffer;

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

Status: built for mGBA, Gambatte, Nestopia, PCSX-ReARMed, bsnes, melonDS DS, JGenesis and DOSBox Pure, Mupen64Plus-Next on branch `core/n64`, Flycast on branch `core/flycast`, and the Vulkan test core `vktest`, which is listed in Debug builds only and is not in the release core set. `scripts/build-core.sh <id>` writes `build/cores/<Framework>.xcframework`, arm64 only, for simulator and device. There is no separate core project as in S3, because `xcodebuild -create-xcframework` from a script is simpler when the core has no Xcode targets of its own. Build outputs are not committed, so `scripts/build-core.sh` must run before `scripts/generate-project.sh` and a build (README).

**Core set.** `GAGA_CORE_SET` picks which cores a build links, for example an MPL-only TestFlight build with no GPL code. `GAGA_CORE_SET="mgba" scripts/generate-project.sh` links only mGBA. Unset, it links every `Cores/*/core.env`. The script refuses an unknown ID or a missing xcframework. It writes `build/core-set.yml`, which embeds each framework, sets the `GAGA_CORE_SET` build setting and defines `GAGA_HAS_<ID>=1`. The post-build no-JIT gate fails if a framework in the set is missing from the app, or a framework outside it is embedded, which happens when a build folder from a wider set is reused. `scripts/appstore_release.sh` defaults to `GAGA_CORE_SET=mgba` until the GPL gate in `docs/07` milestone 4.0 closes. A core left out keeps its guarded stub (section 2.2) and is hidden from the catalog, and its tests skip.

**Libretro cores.** `Cores/shared/LibretroAdapter.c` hosts one statically linked libretro core behind `GagaCoreInterface`. Each libretro core's framework compiles the adapter with its own copy of the core, so `retro_*` symbols never meet. Its bridge file is a table and a getter; `Cores/gambatte/GambatteCore.c` is the pattern. What the adapter does:

- **Environment.** It answers the system and save directories (the `system_dir` and `save_dir` given to `create`), the pixel format (XRGB8888 or RGB565 only), `GET_VARIABLE` from the core's table, `SET_VARIABLES` (accepted and ignored, because melonDS DS reads no option until it succeeds), `INPUT_BITMASKS`, `CAN_DUPE`, `LOG` (dropped), `SET_SYSTEM_AV_INFO`, `SHUTDOWN` (a FATAL event) and `SET_KEYBOARD_CALLBACK`. Every other call, including frontend extras, cores that load content themselves and options UI, returns false. Hardware rendering is refused too, unless the core's build adds `Cores/shared/LibretroVulkan.c` (the layer-path step below).
- **Instance.** libretro is a set of globals with no userdata, so a framework has one live instance. `create` returns NULL while another is alive. Callbacks with no live instance do nothing. Every call runs on the host's serial queue, and the frame and audio pointers handed on are valid only during the callback.
- **Video and audio.** Frames are copied; XRGB8888 alpha is forced opaque. A NULL frame (a duplicate) is skipped. Audio arrives through the batch callback.
- **Input.** Host bits map to the RetroPad, with bitmask queries and analog sticks. `RETRO_DEVICE_POINTER` on port 0 answers `pointer_x`, `pointer_y` and `pointer_down` from `GagaInputState`. ABI 5 has `keys`, the hardware keyboard by USB HID usage: `RETRO_DEVICE_KEYBOARD` on port 0 answers from it, and a core that sets `RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK` hears each key change, as a `RETROK_` code with modifiers, before `retro_run`. `GameSession` fills `keys` only for `typingPlatforms` (`dos`), and there the keyboard does not also press pad buttons. `GameSession` maps the first finger on the picture to that scale over the frame's fitted viewport, and sends no touch from the letterbox.
- **Battery.** `RETRO_MEMORY_SAVE_RAM` goes to `<rom stem>.sav` and `RETRO_MEMORY_RTC` to `<rom stem>.rtc` in `save_dir`, by temp file, `fsync` and `rename`. The adapter writes only changed bytes, every 300 frames, on `flush_battery_save` and on `destroy`. A crash loses at most about 5 seconds of saves. A write failure raises one FATAL; later flushes still retry. An existing file of the wrong size refuses the load, so it is never overwritten. A core that writes its own battery files and returns no `RETRO_MEMORY_SAVE_RAM` (bsnes) sets `save_battery`, which the adapter calls after load, where a failure refuses the load, and at every flush, where a failure raises the same FATAL.
- **Loading.** A `need_fullpath` core gets the path only. If it sets `is_rom`, the adapter still reads the file once for that check and for the ROM hash.
- **States.** The adapter asks `retro_serialize_size` once right after `retro_load_game`, before any frame, because a core may fix its size on the first call: Nestopia does, and its state is 9 bytes longer in the first frames after power on, so a later first call gave states the next session refused. The adapter puts a 16-byte header in front of the core's bytes: `GLR1`, payload size and a hash of the ROM. `load_state` refuses a wrong size or another ROM, then takes its own snapshot and restores it if `retro_unserialize` fails, so the game keeps running.
- **Cheats.** Optional. The adapter keeps the list by host ID and, on every change, resets and re-applies it, one code per index. The core's `is_cheat` refuses codes it cannot parse. A core that cannot add a code to ones already applied sets `unapply_cheats`, called before each `retro_cheat_set` (bsnes, `Cores/bsnes/BsnesSupport.cpp`). A core that reads one multi-line code per index, such as melonDS DS, sets `cheat_lines_are_one_code`, and the adapter joins the lines with `+`.
- **Teardown.** `self_test` runs `retro_init` and `retro_deinit` before every `create`, so a framework sees several init and deinit pairs in one process. A core whose `retro_deinit` leaves a global that the next pair trips on sets `after_deinit`, called after every `retro_deinit`. MAME sets it to clear `retro_load_ok`, which upstream never clears, so the second game no longer tears the first one down again (`Cores/mame/MameSupport.cpp`).

**Rust cores.** A core with no C entry point, such as JGenesis, keeps its own crate under `Cores/<id>/shim` that depends on upstream's crates by path and exports `extern "C"` functions matching `GagaBridge.h`. `core.env` sets `CORE_CARGO_MANIFEST` (relative to `Cores/<id>/`) and `CORE_CARGO_LIB` (the static library's file name). `scripts/build-core.sh` then runs `cargo build --release --locked` for `aarch64-apple-ios` and `aarch64-apple-ios-sim` into `build/cores/<id>/cargo`, with `IPHONEOS_DEPLOYMENT_TARGET` set, and links that library with the files in `sources.txt`. The bridge `.c` file holds only the interface table, so the C compiler checks it against the header. Commit the crate's `Cargo.lock`: `--locked` builds exactly it, and the first build fetches from crates.io, later ones need no network. List every linked crate's licence from `cargo metadata --locked --filter-platform aarch64-apple-ios` in `docs/03`. Build with `panic = "unwind"` and catch panics at each exported function, so an upstream panic becomes a FATAL event instead of a crash. The toolchain needs `rustup target add aarch64-apple-ios aarch64-apple-ios-sim`; JGenesis was built with Rust 1.99.1.

For a libretro core, steps 3 to 7 below become:

- `core.env` also adds `-I../shared` to both flag sets, and `sources.txt` lists `../shared/LibretroAdapter.c`.
- The bridge file defines `const GagaLibretroCore gaga_libretro_core` (name, game kind, the variable table with this app's defaults, and optional `is_rom`, `is_cheat`, `save_battery`, `unapply_cheats` and `after_deinit`), then the getter: `GAGA_LIBRETRO_ENTRY_POINTS` (which also sets `abi_version`) plus `GAGA_LIBRETRO_CHEATS` if cheats work, then ID, name, version, extensions, `target_fps`, `audio_sample_rate` and `state_version`.
- Put in the variable table every core option whose upstream default is wrong for this app, such as a boot ROM option. The adapter answers false for a key not in the table, which the core reads as its own default.
- Leave out any upstream file whose licence is not the core's licence, and stub what it provided. Gambatte's `cc_resampler.c` is GPLv3 and is replaced by two empty functions (`docs/03` section 5).
- Read the core's `retro_get_memory_*` and options before writing tests: battery saves need `RETRO_MEMORY_SAVE_RAM` or `save_battery`, and a boot ROM option must stay off unless the core has its own free boot ROM.
- A layer-path core (Vulkan, `docs/05` section 2.3): set `CORE_USES_MOLTENVK=1` in `core.env`, which makes `build-core.sh` run `scripts/build-moltenvk.sh` and link `libMoltenVK.a` with clang++ and Metal, QuartzCore, IOSurface, UIKit and CoreGraphics. Add `-DGAGA_LIBRETRO_VULKAN -I../../build/moltenvk/include` to both flag sets, list `../shared/LibretroVulkan.c` after the adapter in `sources.txt`, and add `GAGA_LIBRETRO_VULKAN_LAYER` to the getter. `Cores/vktest` is the pattern. compiler-rt's `@available` support imports `_dlsym` for CoreFoundation lookups, so leave `_dlsym` out of `FORBIDDEN_IMPORTS`; keep `_dlopen`.
- A core whose upstream makefile cannot run here (MAME's GENie): run its project generator once in a GagaEmu script, commit `sources.txt` and the generated files, and record the generator's options in `core.env` (`Cores/mame/generate.py`).
- A layer-path core that bundles volk (Mupen64Plus-Next's paraLLEl-RDP): volk's global `PFN_vkX vkX` tentative definitions merge with MoltenVK's static `vkX` functions at link time, so volk would write over code. Rename them for every C++ file and for volk itself, as `Cores/mupen64plus_next/volk_rename.h` (`#define vkX gaga_volk_vkX`, included from `flags.h` and `volk_gaga.c`) does, and map volk's `dlopen` to a stub that returns NULL. The link must then print no "tentative definition" warning.
- A core that needs extra system frameworks sets `CORE_LDFLAGS` in `core.env`, for example `'-framework AudioToolbox'` for Mupen64Plus-Next's AudioConverter resampler.
- A C++ core whose libretro glue defines `retro_run` but needs work before each frame (Flycast): rename upstream's function in C++ only from `flags.h` (`#define retro_run gaga_flycast_upstream_retro_run` under `__cplusplus`) and define the real `retro_run` in the bridge's C file, which does the work and then calls the renamed one. Upstream stays unmodified.
- A core with network code the app must not use (Flycast's BBA, modem and UPnP): turn the options off in the variable table, and rename `socket`, `connect`, `bind`, `listen`, `accept`, `getaddrinfo` and `gethostbyname` to refusing stubs from `flags.h`. List the real names in `FORBIDDEN_IMPORTS`, so the gate fails if one is linked.
- A core that uses `mprotect` to catch guest writes (Flycast's VRAM texture cache): leave out its memory-mapping file and fault handler, and replace the page locks with a software copy that is compared before each frame (`Cores/flycast/FlycastSupport.cpp`, `gaga_flycast_check_vram`). Put `_mprotect`, `_mmap` and `_sigaction` in `FORBIDDEN_IMPORTS`.
- A layer-path core links MoltenVK through `CORE_USES_MOLTENVK=1` only, never a copy of its own, so moving MoltenVK into one shared embedded framework changes `build-core.sh` and not the core. Statically linked into more than one core, MoltenVK's Objective-C classes load twice (`MVKBlockObserver` duplicate warning) and crash on device.
- A core whose interpreter still names a few dynarec symbols: compile the dynarec out with the core's own define and define those symbols as empty in a GagaEmu file, as `Cores/pcsx_rearmed/nodrc.c` does with `DRC_DISABLE`, instead of patching upstream.
- A core that mounts a loose file's folder as a writable drive (DOSBox Pure) must get a private copy, not the ROM folder: `Cores/dosbox_pure/DosboxPureCore.c` copies it to `<save dir>/DOS/<file name>/` first.
- A disc core loads by path (`need_fullpath`). Its battery file is named after what was opened, so a `.m3u` gives every disc one memory card. The Multi-Disc Helper imports each playlist with its discs' platform, because an `.m3u` alone names none.

**Adding the next core.** Follow these in order. `<id>` is the `core_id` in `CoreCatalog`, `<Name>` is the prefix of its stub in `GagaCoreRegistry.c`.

1. **Read the gates.** For a GPL core, milestone 4.0 must be closed. Read `docs/07` section 2 and the core's row in `docs/03`. Read any upstream script before running it; `build-core.sh` runs none.
2. **Vendor and pin.** Confirm the URL is the project's official repository, then run these. The final `git add` is what records the pin: without it, a clean checkout gets whatever the branch tip was.
   ```bash
   git submodule add <official-url> Cores/<id>/upstream
   git -C Cores/<id>/upstream checkout <tag-or-commit>
   git add .gitmodules Cores/<id>/upstream
   ```
   Pin each dependency the core does not vendor as its own submodule under `Cores/<id>/deps/<name>` the same way, so the build works offline after the first fetch. `build-core.sh` stops if any submodule under `Cores/<id>` is not at its recorded commit.
3. **Write `Cores/<id>/core.env`.** Copy `Cores/mgba/core.env` and set all of these:
   - `CORE_FRAMEWORK`, for example `GambatteCore`.
   - `CORE_EXPORT`, exactly `_<Name>_GetInterface`.
   - `CORE_VERSION`, `UPSTREAM_TAG`, and the full 40-character `UPSTREAM_COMMIT`. The build stops if the submodule is at any other commit.
   - `CORE_CFLAGS` and `CORE_CXXFLAGS`. Paths are relative to `Cores/<id>/`. `Sources/Bridge` is already on the include path, and `GAGA_CORE_VERSION` is already defined.
   - `FORBIDDEN_STRINGS`, the core's JIT runtime names from its audit. Never bare `jit` (`docs/04` section 8).
   - `FORBIDDEN_IMPORTS`, a regex of APIs from features you disabled, such as `_socket$`. Every core lists `_mprotect$`, so a change of page protection never slips in.
   - `FORBIDDEN_SOURCES`, optional: a regex of source paths that must not be compiled, such as a dynarec directory in the same tree. The build checks it against the source paths in the dSYM and prints `forbidden sources (<sdk>): none`. Use it when the core's own text names its dynarec, so the word cannot be in `FORBIDDEN_STRINGS`.
   - The framework's bundle identifier is `com.zenithblue.gagaemu.<id>` with `_` written as `-`, and its short version is `CORE_VERSION` with everything but digits and dots removed.
4. **Write `Cores/<id>/<Framework>.exports`.** One line: `_<Name>_GetInterface`.
5. **Write `Cores/<id>/flags.h` if the core needs build defines.** Force it with `-include flags.h` in `CORE_CFLAGS`. Disable debuggers, frontends, scripting, networking, updaters and any dynarec.
6. **Write `Cores/<id>/sources.txt`.** One path per line, relative to `Cores/<id>/`, listing the bridge and exactly the upstream files needed. `.c` uses `CORE_CFLAGS`, `.cpp` and `.cc` use `CORE_CXXFLAGS`. Upstream's own build system is not run. Check each third-party file's licence and add it to `docs/03`.
7. **Write the bridge, `Cores/<id>/<Framework>.c`,** implementing `GagaCoreInterface` from `GagaBridge.h`:
   - Set `abi_version` first. Implement `self_test`, which runs with no instance and before `create`, `pause`, `resume` and `set_event_callback`.
   - Every instance call runs on one serial queue. Callbacks fire on it, inside a host call. Marshal any worker thread to `step_frame`. Descriptor and message pointers are valid only during the callback. No callback after `destroy` returns.
   - `load_rom` gets a path only, and returns false after a FATAL event whose message the player can read. FATAL during play ends the session with its message.
   - The host timer calls `step_frame` at `target_fps` with 4 inputs. Do not self-pace. Each audio packet carries `sample_rate`.
   - Write battery saves into the `save_dir` you are given, and implement `flush_battery_save` so they are on disk when it returns. The host calls it on pause and before `destroy`. `Cores/mgba/MgbaCore.c` is the pattern.
   - Save states are required by `docs/07` section 2. Implement `state_size`, `save_state` and `load_state` over plain buffers. The host owns the file, header, checksum and atomic write, so the core never opens a state file.
   - Set `state_version` from the core's own state format, and change it when old bytes stop meaning the same thing. The host refuses a file with any other value.
   - `load_state` validates what it can, such as the size and the ROM the state came from, and returns false with an error for the player. The running game must be unchanged afterwards. The host also takes a snapshot first and loads it back after a refusal, as a second line of defence, not as a reason to skip validation.
   - `state_size` returns the exact byte count `save_state` writes now. The host asks before each save, so it may change between saves.
   - `step_frame` must be safe to call several times in one timer tick, because fast-forward does. The host drops the audio and shows the last frame, so a core does not need a fast-forward mode.
   - Cheats are optional: a NULL `cheat_add` hides the menu row. If you implement it, also implement `cheat_remove` and `cheat_set_enabled`. `id` is the host's and stays stable across sessions. A code the core cannot parse returns false with an error and adds nothing. The host re-adds stored cheats after `load_rom` on every launch.
8. **Guard the core's stub** in `Sources/Bridge/GagaCoreRegistry.c`: wrap its `DEFINE_CORE_INTERFACE(<Name>_GetInterface, ...)` line in `#ifndef GAGA_HAS_<ID>` and set its version to `GAGA_CORE_EXCLUDED`, as mGBA's is. `<ID>` is the core ID in capitals. Keep its entry in `s_core_getters`. Check that `CoreCatalog` has the `core_id` and the file extensions the core really accepts.
9. **Run `scripts/generate-project.sh`.** It finds the new `core.env` and embeds the framework. `project.yml` does not change.
10. **Build.** `scripts/build-core.sh <id>` must print `exports (iphonesimulator): _<Name>_GetInterface`, the same for `iphoneos`, and `no-JIT gate: pass <Framework>` twice. If `core.env` sets `FORBIDDEN_DEBUG_STRINGS` (JIT source file names), the gate also reads both dSYMs, which proves no JIT file was compiled in. The bundle ID is `com.zenithblue.gagaemu.<id>` with `_` replaced by `-`. The app's post-build gate must print `pass` for the framework. It fails the build if the framework is not embedded.
11. **Check the privacy manifest.** Run `nm -u` on the framework. Any required-reason API, such as `fstat`, needs an entry in `Sources/App/PrivacyInfo.xcprivacy`.
12. **Test.** Add `Tests/<Name>CoreTests.swift`, reaching the core through `GagaCoreRegistry_FindByID("<id>")`, because the test bundle cannot link the framework's symbol. Use a homebrew or generated ROM, never a commercial one, and no vendor BIOS. Assert that it loads, frames match, input changes the frame, audio is non-silent, a FATAL message arrives, `CodeGenCheck.violations()` is empty after a run, a state round trip restores the game, a refused state leaves the game running, and any cheat format has an effect. `Tests/MgbaCoreTests.swift` and `Sources/Debug/GBATestROM.swift` are the pattern; `Tests/GambatteCoreTests.swift` and `Sources/Debug/GBTestROM.swift` for a libretro core. Skip the tests when `GagaCoreRegistry_IsExcluded("<id>")`. Update any test that uses this core's ID as its example of a stub.
13. **Verify in the app on the Simulator.** Import through a real importer, launch from the Library, press a touch control, pause, resume, quit, relaunch ten times, and check the `.sav`. Run the tests with `-enableThreadSanitizer YES`. Build `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO`, both Debug and Release.
14. **Record.** Update the core's rows in `docs/03` (pin, licence, no-JIT) and `docs/04` section 7.1, and its milestone in `docs/07`. Its status stays "built, device benchmark pending" until a device run per `docs/04` section 7.2 exists. A GPL core whose gate is still open is "built, legal gate open, device benchmark pending", and stays out of `scripts/appstore_release.sh`'s core set.

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
| Assign Skin | Chooses this game's touch layout, or Platform Default to follow Settings > Controls > Assign Skin (section 3.7) | built |
| Manage Saves | Save state slots with time and thumbnail, Load, Delete with confirmation, and Export Save for the game's battery save, through the share sheet. Loading from here starts the game on that state. | built |
| Edit Details | Title and favorite, plus platform, core, file size and play time as read-only metadata | built. Box art comes from the Cover Art setting, not from this sheet. |
| Delete | Asks for confirmation, then removes the game and its play history from the library. The file stays in the ROM folder. The confirmation says that saves and save states stay on the device and return if the same file is added again. | built |

Export Save covers the battery save. Save state files are not exported: they belong to one core version, and nothing in the app can import them.

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
| Play | Total play time and session count, read-only. Quick Start opens the most recent game when the app starts, because GagaEmu has no preparation page to skip. Auto Save State saves on quit and when the app goes to the background, and offers to resume when that game next starts; it follows `canUseAutoSaveState`, so a saved value of on does not bypass the gate. Auto Full Screen removes the touch bands when a controller owns Player 1. Respect Silent Mode makes game audio obey the silent switch. | built |
| Library | Game count, Cover Art, BIOS Files (it lists `Application Support/GagaEmu/System`, the `system_dir` every core gets, after moving files from the old `GagaEmu/BIOS` without overwriting), default core per platform. Cover Art is off by default and its note names `thumbnails.libretro.com` as the site that receives game titles (section 5). | built |
| Graphics | Default Filter, which opens the filter picker | built |
| Controls | Touch Control, connected controllers with their player slot, TriggerPro. A controller that has sent no input in a game says that touch stays on until it does. Unassign is remembered by device name across launches. Rumble is a haptic on each touch press, because the bridge has no rumble event yet. Skin Sound Effects is a click on each touch press. Assign Skin opens a sheet with a drawing of each built-in layout and a layout per platform. | built |
| Storage | Game files size, Clear Cache with confirmation. Clear Cache removes the Caches directory. | built |
| Gaga Plus | Status and See Plans. Absent while the paywall gate is closed (section 4.5). Lifetime owners get no See Plans row. | built, gated |
| About | Version, Support and FAQ, Feedback, Rate GagaEmu, Terms of Service, Privacy Policy, Licences. Debug builds add Run Benchmark. Licences (`LicencesView`) is a two-pane paper sheet: components on the left, the chosen one's source and full licence texts on the right. It reads `licences.json`, which `scripts/generate-licences.py` writes with the texts into `Sources/App/Licences` from the committed list `Licences/notices.json`, and shows a component only when a core that brings it in is linked (`GAGA_CORE_SET`); Anime4K and the community filters are in every build. | built: Rate GagaEmu uses the system review prompt. Support and Feedback link to `support.html`, because the App Store metadata has no support email. Terms is Apple's standard EULA, because the site has no terms page. |

All site links use `zenithblue-oss.github.io/gaga-emu-site` (`SiteLinks`), the host the App Store metadata uses.

There is no profile card, nickname, avatar or membership banner. `nickname`, `joined` and `avatarIndex` stay in `state.json` so saved data still loads.

**Rows not shown yet.** Each has no working behaviour today. Saved values stay in `state.json`.

| Row | Home when it returns | Returns with |
|---|---|---|
| RetroAchievements | Play | Blocked: needs an owner account, sign-in testing and RetroAchievements client approval (`docs/07` 3.10) |
| AirPlay Fullscreen | Graphics | Built (`ExternalDisplay.swift`) but not checked on a second screen, so the row stays hidden (`docs/07` 3.11) |
| iCloud Sync | Storage | Blocked: needs the iCloud capability on the App ID, an owner change (`docs/07` 3.11) |
| Share GagaEmu | About | 7.6 |
| Reset Tips | About | When the app has dismissible tips |
| Language | About | When a second localisation exists |
| Online Play | Play | Not scheduled. Netplay is not promised or gated until built. |

There is no JIT row, because GagaEmu ships no JIT and there is nothing to configure. Theme and Appearance are gone, because the palette is fixed and follows the system. Skins are touch layouts only and carry no theme.

Cover Art replaces the old Cover Scraping row. The old `coverScraping` value, which defaulted to on, is ignored, so no install starts sending titles without a new choice.

### 3.4 Filter and core pickers

**Filter picker** (`FilterPickerView`): a split view with the list on the left and a large live preview on the right. Opened from a game it sets that game's filter; opened from Graphics it sets the default for new games. Premium filters show a Plus label and open Gaga Plus when locked, only while the gate is open.

The list has the built-in presets, a Community section whose rows name the author and licence, and an Imported section with a delete button per filter and an `Import .metal File` button (`docs/05` section 4.1). A failed import shows the reason in plain text in a "Filter Not Imported" sheet and selects Original. Beside the preview, the controls show Upscale (Nearest, Bilinear, Bicubic, Edge Smooth) for filters that take one, a slider for each parameter the filter reads, and Reset. The values are saved per filter. `.slangp` import and custom presets have no UI until they exist.

**Core picker** (`CorePickerSheet`): a simple list sheet for one game, with an action that also makes the choice the platform default. A file of unknown type says no cores are available.

### 3.5 Gaga Plus

The paywall is named Gaga Plus (`GagaPlusView`). Two columns: benefits on the left in plain language, plans on the right as Monthly, Annual and Lifetime. Requirements and logic are in section 4.

### 3.6 App icon

Steps, chosen by the owner: ink pixel stairs and one vermilion pixel in the air, on a paper tile. `AppIcon.appiconset` holds a single-size 1024 PNG with dark and tinted entries, rendered by `design/icons/render_all.sh`. Original artwork with no third-party imagery. Options and rules are in `docs/BRAND.md`.

### 3.7 Game view and pause menu

`GameView` covers the whole screen, with the status bar and home indicator hidden. The picture is aspect fit on the ink letterbox, which stays dark in both appearances. Touch controls sit in a band on each side of the picture, inside the safe area, with hit areas of at least 44pt. The left band holds L, the D-pad and Select. The right band holds R, the face buttons and Start. A pause button sits top left and a fast-forward toggle top right. The toggle switches between normal speed and the last speed chosen, which starts at 2x. When a controller assigned to Player 1 has sent input in this launch, the controls hide; with Auto Full Screen on, the bands go too and the picture takes the width. iOS can report a controller that never sends anything, as the Simulator does on every launch, so a connected controller alone never hides touch. Keyboard mapping feeds Player 1. Every control has a VoiceOver label, and activating one presses that button briefly.

The pause menu is a compact paper side sheet over the dimmed game: Paused, the game title, Resume, Save State, Load State, Fast Forward (Off, then each allowed speed), Cheats and Quit to Library. Save State, Load State and Cheats appear only for a core that implements them. See Gaga Plus appears only while the gate is open, and never for a lifetime owner. Opening the menu pauses the core and audio. Quit ends the session and returns to the Library, where Continue shows the game.

**From a controller.** Pressing Menu and Options together, or Home where the system passes it through, opens and closes the menu. The game does not receive that Start and Select. Either button alone still reaches the game.

**Saves.** Save State writes a new slot and shows the time. Load State opens the Manage Saves sheet. A state that cannot load shows why, and the game keeps running. Reaching the free limit explains it and suggests deleting one. The auto save has one fixed slot and does not count against the limit.

**Cheats.** The sheet has a name field and a code field on the left, and this game's cheats with a switch and a delete button on the right. The Add Cheat button sits above the fields, because the landscape keyboard covers what is below them. The core decides whether a code is valid, and its reason is shown beside that button. mGBA accepts GameShark, Action Replay, CodeBreaker and VBA formats.

**Pausing.** The menu, backgrounding and audio interruptions are separate reasons, and play resumes only when all have cleared. An interruption that ends without the system's resume hint leaves the menu open, so the player chooses.

**Touch layouts.** `TouchSkinEngine.Layout.builtIn` has three original layouts: Standard (pad and face buttons at mid height, Select and Start below), Low Reach (pad and buttons at the bottom edge, Select and Start above them) and Two Button (A and B alone, larger and on a slant, offered for Game Boy, GBC, GBA and NES). A game's own choice wins over its platform's, which wins over Standard (`TouchSkinEngine.layoutID`). On a platform that types (`GameSession.typingPlatforms`, DOS today) every layout adds a Keyboard key under L that presses L3, which opens DOSBox Pure's on-screen keyboard (`Layout.buttons(for:)`).

**Layer path.** A core that draws its own picture (`GAGA_CORE_CAP_METAL_LAYER`) gets the same touch controls. A finger on its picture becomes the pointer the same way: the session takes the frame size from the core's size-only frames and maps the finger over the same aspect fit the Vulkan adapter blits. Both paths hand the screen BGRA8 UNORM tagged sRGB (`MetalRenderer.configureOutput`), which MoltenVK's `B8G8R8A8_UNORM` / `SRGB_NONLINEAR` swapchain matches, so neither applies gamma twice.

**Second screen.** `ExternalDisplay` puts the picture in a window on a connected external screen and leaves the controls on the device, while a game runs with AirPlay Fullscreen on. Without that window iOS mirrors the device as usual. The scene is configured by `AppDelegate` for the `windowExternalDisplayNonInteractive` role. The setting defaults to off and its row is hidden until the feature is checked on a real second screen.

**Failures.** A load runs before the game view opens. If it fails, the Library shows an alert with the core's own message and no game view opens. A fatal core event while playing closes the game view and shows the same alert.

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
| Higher fast-forward speed | 2x | 5x | Yes: `GameSession.fastForwardSpeeds` filters by `maxFastForward`, and `setFastForward` clamps to it. |
| Unlimited Save States | 3 | Unlimited | Yes: `GameSession.saveState` checks `canAddSaveState`. The auto save slot does not count. |
| Unlimited Cheat Codes | 3 | Unlimited | Yes: `GameSession.addCheat` checks `canAddCheat`. |
| Premium Filters | Original, Cartoon, CRT v1, CRT v2, Film, the Community filters and imported filters | Geom CRT, Geom CRT Border, CRT Deluxe, Anime4K | Yes: `canUseShader` in `FilterPickerView.swift`, and `AppState.makeSession` falls back to Original without it. |
| Auto Save State | Off | Available | Yes: `AppState.autoSaveEnabled` needs `canUseAutoSaveState`, and the Settings row becomes a locked row without it. |

**Sell only what works.** `premiumShaderIDs` is `geom-crt`, `geom-crt-border`, `crt-deluxe` and `anime4k`, each drawn on real core frames (`docs/05` section 3.1). `crt-royale` is GPL and is not shipped; CRT Deluxe is the original multi-pass CRT sold in its place, and a saved `crt-royale` selection resets to Original. The Premium Filters entitlement covers only cores whose frames pass through the host shader chain. Layer-path cores (N64, PSP, Dreamcast, 3DS, and Beetle PSX HW in Vulkan mode; `docs/05` section 2.5) skip host shaders until the output-texture path exists. Netplay is not gated or promised until built.

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
| Controllers | `ControllerManager`: MFi, DualShock 4, DualSense, Xbox, Joy-Con and keyboards | built. The session reads keyboard mapping for Player 1. |
| Touch skins | `TouchSkinEngine`: `.deltaskin` and flex skins, CoreHaptics. Three built-in layouts, assigned per platform or per game (section 3.7). | built |
| Cover art | `CoverArtFetcher`: box art from [Libretro Thumbnails](https://thumbnails.libretro.com) (`Named_Boxarts`), matched by exact title, with libretro's rule that ampersand, asterisk, slash, colon, backtick, angle brackets, question mark, backslash, vertical bar and double quote become an underscore (`LibretroThumbnails.fileName`). Only while Cover Art is on, which is off by default; the setting is checked before each request. HTTPS only, ephemeral session with no cookies, 10 s request and 30 s resource timeouts, one request at a time. A response over 5 MiB, not PNG or JPEG, or over 4096 px a side is dropped. The image is decoded and re-encoded at 600 px into `Caches/Covers`, and a failure keeps the placeholder. OpenVGDB and SteamGridDB are not used. The game title leaves the device, so `PrivacyInfo.xcprivacy` declares it (Other Data Types, App Functionality, not linked, no tracking). Box art is third-party artwork and is never used in marketing (`docs/BRAND.md`). | built |
| TriggerPro | `TriggerProManager`: turbo, hold and combo, on player 1 | built |
| Game Center | Entitlement present, GameKit linked. `GameCenter.authenticate` signs in the local player in the background, with no failure UI. No leaderboards or achievements. | built |

---

## 6. Project Generation

`project.yml` is authoritative. This listing matches it today:

```yaml
name: GagaEmu
# The core frameworks and GAGA_HAS_<ID> defines. Run scripts/generate-project.sh, not xcodegen directly.
include:
  - path: build/core-set.yml
    relativePaths: false
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

`project.yml` names no core. `scripts/generate-project.sh` writes `build/core-set.yml` with one embedded dependency per core in the core set, the `GAGA_CORE_SET` build setting and a `GAGA_HAS_<ID>=1` define for each, then runs `xcodegen generate`. Plain `xcodegen generate` fails, because the include file is missing. Section 2.5 has the core set.

`GagaEmu.xcodeproj/` is generated and ignored by git, as in S3 and S4 (`S3/ios/.gitignore:2`, `S4/ios/BachataS4/project.yml:4-5`). After a fresh clone, run the build command in the README; `scripts/appstore_release.sh` runs the same steps first.
