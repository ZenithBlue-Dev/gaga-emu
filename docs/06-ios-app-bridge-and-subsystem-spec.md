# 06 — iOS App Architecture, C-Bridge & Subsystem Specification

Gaga-Emu is constructed with a clean, decoupled architecture: a 100% native **Swift 5.9+ / SwiftUI** frontend communicating with heterogeneous emulator cores via a unified, zero-overhead **C-ABI Bridge (`GagaBridge.h`)**.

---

## 1. System Decomposition & Data Flow

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                       SwiftUI 5.9+ Native iOS Frontend                      │
 │  • Games Library   • Import Hub (WiFi/ROM)   • Settings (Adventurer Card)   │
 │  • Controller Engine (GameController)        • StoreKit 2 In-App Purchases  │
 └──────────────────────────────────────┬──────────────────────────────────────┘
                                        │ Swift Protocol: `EmulatorCoreProtocol`
 ┌──────────────────────────────────────┴──────────────────────────────────────┐
 │                      C-ABI Bridge Layer (`GagaBridge.h`)                     │
 │  • gaga_core_init()       • gaga_core_load_rom()   • gaga_core_step_frame() │
 │  • gaga_core_set_input()  • gaga_core_save_state() • gaga_core_load_state() │
 └───────────────────┬──────────────────────────────────┬──────────────────────┘
                     │                                  │
                     ▼                                  ▼
 ┌──────────────────────────────────────┐   ┌──────────────────────────────────┐
 │ Standard Libretro Dynamic Frameworks │   │ Specialized Standalone Engines   │
 │ (mGBA, bsnes, Gambatte, Beetle PSX)  │   │ (Azahar 3DS, PPSSPP, Balero-S2)  │
 └───────────────────┬──────────────────┘   └──────────────────┬───────────────┘
                     │                                         │
                     ▼                                         ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         Shared Apple Audio/Video Sinks                      │
 │  • Video: MTKView / CAMetalLayer Zero-Copy Texture Ingestion                │
 │  • Audio: AVAudioEngine Low-Latency PCM Ring Buffer (44.1 / 48 kHz Stereo)   │
 │  • Haptics: CoreHaptics Engine (DualSense / Taptic Vibration)               │
 └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Unified C-ABI Bridge (`GagaBridge.h`)

To ensure that changes to individual C++ cores never cause compilation friction in the Swift frontend, all core interactions pass through strict C99 function signatures:

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

---

## 3. Screen Specifications & Reference Parity

### 3.1 Games Tab (Ref: `FC11608F`, `E2946B38`)
- **Visual Design**: Dark OLED background (`#0B0C10`), floating glass navigation bars, dynamic accent glow.
- **Header Elements**:
  - Top-Left: Controllers Manager modal launcher.
  - Center: App branding ("GAGA-EMU").
  - Top-Right: Play History / Search toggle.
- **Empty State**: Displays hero illustration, "Welcome to GAGA-EMU's World", quick import button, and mandatory legal disclaimer banner: *"Ensure game ROMs are legally obtained"*.
- **Populated State**:
  - Horizontal carousel for "Recently Played" titles.
  - Multi-column grid organized by platform categories.
  - Long-press contextual sheet:
    - *Switch Core*: Displays available cores for that console with instantaneous assignment.
    - *Select Shader*: Direct shortcut to the shader selector.
    - *Manage Saves*: Visual save state slot picker with image thumbnails.
    - *Edit Metadata / Boxart*: Manual cover scraper search.

### 3.2 Import Tab (Ref: `A59F001A`, `443B8BE2`)
The import screen provides an all-in-one suite of game ingestion tools:
1. **Files**: System document picker supporting local storage, external USB-C drives, and iCloud Drive.
2. **WiFi Transfer**:
   - Built-in embedded HTTP file server running on local LAN port (e.g. `http://192.168.1.15:8080`).
   - Web browser interface allows drag-and-drop uploading of ROMs, saves, and BIOS files from Mac/PC.
3. **Read Clipboard**:
   - Inspects iOS system clipboard. If a ROM file or valid direct URL was copied in Safari or Files, Gaga-Emu automatically ingests and moves it to the appropriate platform directory.
4. **MultiDisc Helper**:
   - Automatically detects multi-disc file naming schemes (e.g., `Final Fantasy VII (Disc 1).chd`, `Final Fantasy VII (Disc 2).chd`).
   - Generates unified `.m3u` playlist manifests, grouping discs into a single clean library entry.
5. **RomPatcher**:
   - In-memory patching engine supporting **IPS**, **BPS**, and **UPS** file formats.
   - Allows applying fan translations, balance patches, and retro hacks on-the-fly without corrupting the pristine source dump.
6. **Drag & Drop**: Native iPadOS split-view and iOS pointer drop target across the entire app window.

### 3.3 Settings Tab & Adventurer Profile (Ref: `F7ADD189`, `44F4AEE0`, `C4E3779B`, `8A17681E`, `9EFF77AC`)
- **Adventurer Identity Card**:
  - Displays user nickname, total cumulative play time, join date, and custom retro avatar.
- **StoreKit 2 Membership Banner**:
  - "Unlock GAGA-EMU Membership" (50% Off promotion banner).
  - Monthly subscription, Annual membership, and Lifetime Pass.
- **General Options**:
  - *Appearance*: Dark Mode, Light Mode, System Auto.
  - *Theme*: Dynamic app icon switcher (alternate app icons), theme colors, boxart display aspect ratios, and console category ordering.
  - *Quick Start*: Bypasses the preparation/loading splash screen.
  - *Auto Save States*: Rolling save state automation.
  - *Assign Skin*: Touch controller skin selector (`.deltaskin` and dynamic SVG).
  - *Cover Scraping*: Automated boxart scraping from Libretro Thumbnails, OpenVGDB, and SteamGridDB.
- **Advanced Options**:
  - *AirPlay Fullscreen*: Low-latency TV mirroring.
  - *iCloud Sync*: Cross-device save state and battery save synchronizer.
  - *Auto Full Screen*: Automatically expands to full screen when an external Bluetooth or MFi controller connects.
  - *BIOS Manager*: Displays required BIOS files, SHA-1 checksum statuses, and direct folder import.
  - *Respect Silent Mode*: Follows physical hardware mute switch.
  - *Online Play / Netplay*: LAN discovery, room creation, public lobbies, and password protection.
  - *Rumble / Haptics*: Device vibration via CoreHaptics.
  - *Skin Sound Effects*: Tactile mechanical sound feedback on touch skin button presses.
  - *RetroAchievements*: Account login, achievement popup banners, and Hardcore Mode enforcement.
  - *TriggerPro*: Virtual button macro and turbo configuration engine.
  - *Shaders*: Live preview shader selection.
  - *Emulator Core*: Master platform-to-core mapping directory.

---

## 4. Declarative Project Generation (XcodeGen)

To maintain clean Git hygiene and avoid merge conflicts in `.xcodeproj` files, Gaga-Emu uses declarative `project.yml` definitions:

```yaml
name: GagaEmu
options:
  bundleIdPrefix: com.gagaemu
  deploymentTarget:
    iOS: "17.0"
settings:
  SWIFT_VERSION: "5.9"
  DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
targets:
  GagaEmu:
    type: application
    platform: iOS
    sources:
      - path: Sources/App
      - path: Sources/Bridge
      - path: Sources/Metal
      - path: Sources/UI
    dependencies:
      - framework: Sources/Cores/mGBA.framework
      - framework: Sources/Cores/bsnes.framework
      - framework: Sources/Cores/Gambatte.framework
      - framework: Sources/Cores/PCSXReARMed.framework
      - framework: Sources/Cores/Azahar3DS.framework
      - framework: Sources/Cores/PPSSPP.framework
    frameworks:
      - Metal
      - MetalKit
      - GameController
      - CoreHaptics
      - AVFoundation
      - StoreKit
```
