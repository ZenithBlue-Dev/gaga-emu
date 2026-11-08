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
    // Player 1's slot only: true when the host drops this frame's picture (fast-forward runs several frames
    // per tick and shows the last). A layer-path core then renders but does not present. It sits in what was
    // tail padding, so the size and every offset stay as ABI 5 shipped, and zero keeps the old behaviour.
    bool     skip_present;
} GagaInputState;
#ifndef __cplusplus
_Static_assert(sizeof(GagaInputState) == 72, "GagaInputState must keep its ABI 5 size");
#endif

// Pixel formats emitted by core
typedef enum {
    GAGA_PIXEL_FORMAT_RGB565   = 0,
    GAGA_PIXEL_FORMAT_XRGB8888 = 1,
    GAGA_PIXEL_FORMAT_RGBA8888 = 2,
    // Only from a GAGA_CORE_CAP_OUTPUT_TEXTURE core the host attached with no layer: pixel_data points to a
    // GagaMetalTextureFrame and pitch is 0. A host that never attaches that way never sees it.
    GAGA_PIXEL_FORMAT_METAL_TEXTURE = 3,
} GagaPixelFormat;

// A frame rendered off-screen for host shaders (docs/05 section 2.4). The objects belong to the core and are
// valid only during the callback. The host encodes, on its own MTLCommandQueue, a wait for ready_event to
// reach ready_value, its reads of texture, then a signal of done_event to done_value. It does this for every
// such frame, including one it does not show: the core writes texture again only once done_value is reached.
typedef struct {
    void*    texture;     // id<MTLTexture>, MTLPixelFormatBGRA8Unorm, the descriptor's width and height
    void*    ready_event; // id<MTLSharedEvent>, signalled by the core
    uint64_t ready_value;
    void*    done_event;  // id<MTLSharedEvent>, signalled by the host
    uint64_t done_value;
} GagaMetalTextureFrame;

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
    GAGA_EVENT_RUMBLE  = 3, // Not a message: one motor's new strength, sent when it changes. message is NULL.
} GagaEventSeverity;

// A GAGA_EVENT_RUMBLE code: player port in bits 17-18, motor in bit 16, strength (0 off, 0xFFFF full) in bits 0-15.
// The motors are libretro's: strong is the low-frequency one, weak the high-frequency one.
typedef enum {
    GAGA_RUMBLE_STRONG = 0,
    GAGA_RUMBLE_WEAK   = 1,
} GagaRumbleMotor;
#define GAGA_RUMBLE_CODE(port, motor, strength) \
    ((int32_t)((((uint32_t)(port) & 3u) << 17) | (((uint32_t)(motor) & 1u) << 16) | ((uint32_t)(strength) & 0xFFFFu)))

// Bit 0 is kept for the host-buffer path (docs/06 section 2.4).
typedef enum {
    GAGA_CORE_CAP_METAL_LAYER = 1u << 1, // Presents to an attached CAMetalLayer. Host shaders do not run.
    // With METAL_LAYER: attach_metal_layer with a NULL layer switches the core to off-screen frames of
    // GAGA_PIXEL_FORMAT_METAL_TEXTURE, so host shaders run. A core without the bit returns false for NULL.
    // Older cores lack the bit and older hosts never pass NULL, so the ABI stays at 5.
    GAGA_CORE_CAP_OUTPUT_TEXTURE = 1u << 2,
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
    // attached render but are not shown. Detach returns with no GPU work using the layer. A NULL layer is
    // the output-texture path (GAGA_CORE_CAP_OUTPUT_TEXTURE); detach ends it.
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

    // Errors and events. A FATAL event during load_rom supplies the message the player sees. A core that
    // drives rumble sends RUMBLE events from step_frame.
    void (*set_event_callback)(GagaInstance* inst,
        void (*cb)(GagaEventSeverity severity, int32_t code, const char* message, void* userdata), void* userdata);
} GagaCoreInterface;

#ifdef __cplusplus
}
#endif

#endif // GAGA_BRIDGE_H
