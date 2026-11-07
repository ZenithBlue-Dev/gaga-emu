#include "GagaCoreRegistry.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ============================================================================
// MOCK CORE IMPLEMENTATION (Animated Test Pattern + 440Hz Sine Wave)
// ============================================================================

#define MOCK_WIDTH 256
#define MOCK_HEIGHT 224
#define MOCK_SAMPLE_RATE 44100
#define MOCK_FPS 60.0

#define MOCK_SMALL_WIDTH 160
#define MOCK_SMALL_HEIGHT 144

enum { MOCK_EVENT_PAUSED = 1, MOCK_EVENT_RESUMED = 2, MOCK_EVENT_STEP_WHILE_PAUSED = 3, MOCK_EVENT_BAD_ROM = 4 };

typedef struct {
    char system_dir[512];
    char save_dir[512];
    uint32_t frame_counter;
    double audio_phase;
    uint32_t framebuffer[MOCK_WIDTH * MOCK_HEIGHT];
    uint16_t framebuffer565[MOCK_WIDTH * MOCK_HEIGHT];
    int16_t audio_buffer[(MOCK_SAMPLE_RATE / 60 + 16) * 2]; // Stereo
    void (*video_cb)(const GagaFrameDescriptor* frame, void* userdata);
    void* video_userdata;
    void (*audio_cb)(const GagaAudioDescriptor* audio, void* userdata);
    void* audio_userdata;
    void (*event_cb)(GagaEventSeverity severity, int32_t code, const char* message, void* userdata);
    void* event_userdata;
    bool rom_loaded;
    bool paused;
    uint32_t last_buttons;
    uint32_t pixel_format; // Start cycles it
    bool small_frame;      // Select toggles it
} MockCoreInstance;

static void mock_emit(MockCoreInstance* m, GagaEventSeverity severity, int32_t code, const char* message) {
    if (m->event_cb) m->event_cb(severity, code, message, m->event_userdata);
}

static GagaInstance* mock_create(const char* system_dir, const char* save_dir) {
    MockCoreInstance* inst = (MockCoreInstance*)calloc(1, sizeof(MockCoreInstance));
    if (!inst) return NULL;
    if (system_dir) strncpy(inst->system_dir, system_dir, sizeof(inst->system_dir) - 1);
    if (save_dir) strncpy(inst->save_dir, save_dir, sizeof(inst->save_dir) - 1);
    inst->frame_counter = 0;
    inst->audio_phase = 0.0;
    inst->rom_loaded = false;
    inst->pixel_format = GAGA_PIXEL_FORMAT_RGBA8888;
    return (GagaInstance*)inst;
}

static void mock_destroy(GagaInstance* inst) {
    if (inst) {
        free(inst);
    }
}

static bool mock_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return false;

    // Any non-empty file is a "ROM", so the host's load failure path can be exercised for real.
    size_t size = rom_data ? rom_size : 0;
    if (!rom_data && rom_path) {
        FILE* fp = fopen(rom_path, "rb");
        if (fp) {
            if (fseek(fp, 0, SEEK_END) == 0) {
                long end = ftell(fp);
                size = end > 0 ? (size_t)end : 0;
            }
            fclose(fp);
        }
    }
    if (size == 0) {
        mock_emit(m, GAGA_EVENT_FATAL, MOCK_EVENT_BAD_ROM, "The game file is empty or unreadable.");
        return false;
    }

    m->rom_loaded = true;
    m->frame_counter = 0;
    m->audio_phase = 0.0;
    return true;
}

static void mock_reset(GagaInstance* inst) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;
    m->frame_counter = 0;
    m->audio_phase = 0.0;
}

static void mock_step_frame(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;

    // Contract check: the host must not step between pause and resume.
    if (m->paused) {
        mock_emit(m, GAGA_EVENT_FATAL, MOCK_EVENT_STEP_WHILE_PAUSED, "step_frame ran while paused.");
        return;
    }

    uint32_t buttons = 0;
    if (inputs && player_count > 0) {
        buttons = inputs[0].buttons;
    }

    // Start cycles the pixel format and Select toggles the frame size, on the press only.
    uint32_t pressed = buttons & ~m->last_buttons;
    m->last_buttons = buttons;
    if (pressed & GAGA_BTN_START) m->pixel_format = (m->pixel_format + 1) % 3;
    if (pressed & GAGA_BTN_SELECT) m->small_frame = !m->small_frame;

    uint32_t width = m->small_frame ? MOCK_SMALL_WIDTH : MOCK_WIDTH;
    uint32_t height = m->small_frame ? MOCK_SMALL_HEIGHT : MOCK_HEIGHT;

    m->frame_counter++;
    uint32_t fc = m->frame_counter;

    // Render animated test pattern: smooth plasma / color gradient
    // Buttons modify palette shifts or add visual indicators
    uint8_t red_boost = (buttons & (GAGA_BTN_SOUTH | GAGA_BTN_EAST)) ? 80 : 0;
    uint8_t blue_boost = (buttons & (GAGA_BTN_WEST | GAGA_BTN_NORTH)) ? 80 : 0;

    for (uint32_t y = 0; y < height; ++y) {
        for (uint32_t x = 0; x < width; ++x) {
            uint8_t r = (uint8_t)(((x + fc * 2) & 0xFF) + red_boost);
            uint8_t g = (uint8_t)((y + fc) & 0xFF);
            uint8_t b = (uint8_t)(((x + y + fc * 3) & 0xFF) + blue_boost);
            uint8_t a = 255;

            // Draw a center indicator box when any D-Pad button is pressed
            if ((buttons & (GAGA_BTN_UP | GAGA_BTN_DOWN | GAGA_BTN_LEFT | GAGA_BTN_RIGHT)) &&
                x + 10 >= width / 2 && x <= width / 2 + 10 && y + 10 >= height / 2 && y <= height / 2 + 10) {
                r = 255; g = 255; b = 255;
            }

            // Rows keep the full buffer's stride, so the small frame has a pitch wider than its width.
            if (m->pixel_format == GAGA_PIXEL_FORMAT_RGB565) {
                m->framebuffer565[y * MOCK_WIDTH + x] = (uint16_t)(((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3));
            } else if (m->pixel_format == GAGA_PIXEL_FORMAT_XRGB8888) {
                m->framebuffer[y * MOCK_WIDTH + x] = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
            } else {
                // Little-endian RGBA in memory
                m->framebuffer[y * MOCK_WIDTH + x] = ((uint32_t)a << 24) |
                                                     ((uint32_t)b << 16) |
                                                     ((uint32_t)g << 8)  |
                                                     ((uint32_t)r);
            }
        }
    }

    if (m->video_cb) {
        bool is565 = m->pixel_format == GAGA_PIXEL_FORMAT_RGB565;
        GagaFrameDescriptor frame;
        frame.pixel_data = is565 ? (const void*)m->framebuffer565 : (const void*)m->framebuffer;
        frame.width = width;
        frame.height = height;
        frame.pitch = MOCK_WIDTH * (is565 ? sizeof(uint16_t) : sizeof(uint32_t));
        frame.pixel_format = m->pixel_format;
        m->video_cb(&frame, m->video_userdata);
    }

    // Audio: 440 Hz Sine Tone (A4)
    size_t frames = MOCK_SAMPLE_RATE / 60; // 735 samples
    double freq = 440.0;
    if (buttons & GAGA_BTN_UP) freq = 880.0;
    if (buttons & GAGA_BTN_DOWN) freq = 220.0;

    double phase_inc = (2.0 * M_PI * freq) / (double)MOCK_SAMPLE_RATE;
    for (size_t i = 0; i < frames; ++i) {
        int16_t sample = (int16_t)(sin(m->audio_phase) * 8000.0); // Gentle volume
        m->audio_buffer[i * 2 + 0] = sample; // Left
        m->audio_buffer[i * 2 + 1] = sample; // Right
        m->audio_phase += phase_inc;
        if (m->audio_phase >= 2.0 * M_PI) {
            m->audio_phase -= 2.0 * M_PI;
        }
    }

    if (m->audio_cb) {
        GagaAudioDescriptor audio;
        audio.pcm_samples = m->audio_buffer;
        audio.frames = frames;
        audio.sample_rate = MOCK_SAMPLE_RATE;
        audio.channels = 2;
        m->audio_cb(&audio, m->audio_userdata);
    }
}

static bool mock_attach_metal_layer(GagaInstance* inst, void* ca_metal_layer) {
    (void)inst;
    (void)ca_metal_layer;
    return true;
}

static void mock_set_video_callback(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor* frame, void* userdata), void* userdata) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;
    m->video_cb = cb;
    m->video_userdata = userdata;
}

static void mock_set_audio_callback(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor* audio, void* userdata), void* userdata) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;
    m->audio_cb = cb;
    m->audio_userdata = userdata;
}

typedef struct {
    uint32_t frame_counter;
    double audio_phase;
} MockState;

static size_t mock_state_size(GagaInstance* inst) {
    (void)inst;
    return sizeof(MockState);
}

static bool mock_save_state(GagaInstance* inst, void* buffer, size_t size) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m || !buffer || size != sizeof(MockState)) return false;
    MockState state = { m->frame_counter, m->audio_phase };
    memcpy(buffer, &state, sizeof(state));
    return true;
}

static bool mock_load_state(GagaInstance* inst, const void* buffer, size_t size, char* error, size_t error_capacity) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m || !buffer || size != sizeof(MockState)) {
        if (error && error_capacity > 0) snprintf(error, error_capacity, "This save state is the wrong size.");
        return false;
    }
    MockState state;
    memcpy(&state, buffer, sizeof(state));
    m->frame_counter = state.frame_counter;
    m->audio_phase = state.audio_phase;
    return true;
}

static bool mock_self_test(char* error, size_t error_capacity) {
    (void)error;
    (void)error_capacity;
    return true;
}

static void mock_pause(GagaInstance* inst) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;
    m->paused = true;
    mock_emit(m, GAGA_EVENT_INFO, MOCK_EVENT_PAUSED, "paused");
}

static void mock_resume(GagaInstance* inst) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;
    m->paused = false;
    mock_emit(m, GAGA_EVENT_INFO, MOCK_EVENT_RESUMED, "resumed");
}

static void mock_set_event_callback(GagaInstance* inst,
                                    void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata) {
    MockCoreInstance* m = (MockCoreInstance*)inst;
    if (!m) return;
    m->event_cb = cb;
    m->event_userdata = userdata;
}

static const GagaCoreInterface s_mock_interface = {
    .abi_version = GAGA_BRIDGE_ABI_VERSION,
    .core_id = "mock",
    .core_name = "Mock Validation Core",
    .core_version = "1.0.0",
    .supported_extensions = "mock|bin|rom",
    .target_fps = MOCK_FPS,
    .native_sample_rate = MOCK_SAMPLE_RATE,
    .create = mock_create,
    .destroy = mock_destroy,
    .load_rom = mock_load_rom,
    .reset = mock_reset,
    .step_frame = mock_step_frame,
    .attach_metal_layer = mock_attach_metal_layer,
    .set_video_callback = mock_set_video_callback,
    .set_audio_callback = mock_set_audio_callback,
    .state_version = 1,
    .state_size = mock_state_size,
    .save_state = mock_save_state,
    .load_state = mock_load_state,
    .self_test = mock_self_test,
    .pause = mock_pause,
    .resume = mock_resume,
    .set_event_callback = mock_set_event_callback,
};

const GagaCoreInterface* MockCore_GetInterface(void) {
    return &s_mock_interface;
}

// ============================================================================
// DEFAULT STUB HANDLERS FOR REGISTERED CORES
// ============================================================================

typedef struct {
    char name[32];
} StubInstance;

static GagaInstance* stub_create(const char* s, const char* v) {
    (void)s; (void)v;
    return (GagaInstance*)calloc(1, sizeof(StubInstance));
}

static void stub_destroy(GagaInstance* inst) {
    if (inst) free(inst);
}

static bool stub_load_rom(GagaInstance* i, const char* p, const void* d, size_t s) {
    (void)i; (void)p; (void)d; (void)s;
    return true;
}

static void stub_reset(GagaInstance* i) { (void)i; }
static void stub_step_frame(GagaInstance* i, const GagaInputState in[4], uint32_t c) { (void)i; (void)in; (void)c; }
static bool stub_attach_metal_layer(GagaInstance* i, void* l) { (void)i; (void)l; return true; }
static void stub_set_video_callback(GagaInstance* i, void (*cb)(const GagaFrameDescriptor*, void*), void* u) { (void)i; (void)cb; (void)u; }
static void stub_set_audio_callback(GagaInstance* i, void (*cb)(const GagaAudioDescriptor*, void*), void* u) { (void)i; (void)cb; (void)u; }
static void stub_pause(GagaInstance* i) { (void)i; }
static void stub_resume(GagaInstance* i) { (void)i; }
static void stub_set_event_callback(GagaInstance* i, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* u) { (void)i; (void)cb; (void)u; }

// A stub emits no frames, so it must fail here rather than show a black screen.
static bool stub_self_test(char* error, size_t error_capacity) {
    if (error && error_capacity > 0) snprintf(error, error_capacity, "This core is not part of this build yet.");
    return false;
}

#define DEFINE_CORE_INTERFACE(getter, id, name, ver, ext, fps, sr) \
__attribute__((weak)) const GagaCoreInterface* getter(void) { \
    static const GagaCoreInterface s_interface = { \
        .abi_version = GAGA_BRIDGE_ABI_VERSION, \
        .core_id = id, \
        .core_name = name, \
        .core_version = ver, \
        .supported_extensions = ext, \
        .target_fps = fps, \
        .native_sample_rate = sr, \
        .create = stub_create, \
        .destroy = stub_destroy, \
        .load_rom = stub_load_rom, \
        .reset = stub_reset, \
        .step_frame = stub_step_frame, \
        .attach_metal_layer = stub_attach_metal_layer, \
        .set_video_callback = stub_set_video_callback, \
        .set_audio_callback = stub_set_audio_callback, \
        .self_test = stub_self_test, \
        .pause = stub_pause, \
        .resume = stub_resume, \
        .set_event_callback = stub_set_event_callback, \
    }; \
    return &s_interface; \
}

// A real core's framework supplies its getter. GAGA_CORE_SET (scripts/generate-project.sh) can leave one out
// of a build, and then this refusing row stands in and CoreCatalog hides the core.
#define GAGA_CORE_EXCLUDED "excluded"
#ifndef GAGA_HAS_MGBA
DEFINE_CORE_INTERFACE(Mgba_GetInterface,          "mgba",            "mGBA",              GAGA_CORE_EXCLUDED, "gba",      59.7275, 32768)
#endif
#ifndef GAGA_HAS_GAMBATTE
DEFINE_CORE_INTERFACE(Gambatte_GetInterface,      "gambatte",        "Gambatte",          GAGA_CORE_EXCLUDED, "gb|gbc",   59.7275, 32768)
#endif
#ifndef GAGA_HAS_NESTOPIA
DEFINE_CORE_INTERFACE(Nestopia_GetInterface,      "nestopia",        "Nestopia UE",       GAGA_CORE_EXCLUDED, "nes",      60.0988, 48000)
#endif
#ifndef GAGA_HAS_PCSX_REARMED
DEFINE_CORE_INTERFACE(PcsxReArmed_GetInterface,   "pcsx_rearmed",    "PCSX-ReARMed",      GAGA_CORE_EXCLUDED, "bin|cue|img|mdf|pbp|toc|cbn|m3u|chd|iso|exe", 60.0, 44100)
#endif
#ifndef GAGA_HAS_BSNES
DEFINE_CORE_INTERFACE(Bsnes_GetInterface,         "bsnes",           "bsnes",             GAGA_CORE_EXCLUDED, "sfc|smc",  60.0988, 48000)
#endif

DEFINE_CORE_INTERFACE(BeetlePsx_GetInterface,     "beetle_psx",      "Beetle PSX HW",     "0.9.44", "cue|bin|chd|pbp",     60.0, 44100)
DEFINE_CORE_INTERFACE(Gpsp_GetInterface,          "gpsp",            "gpSP",              "0.9.1",  "gba|bin",             59.7275, 44100)
DEFINE_CORE_INTERFACE(Jgenesis_GetInterface,      "jgenesis",        "JGenesis",          "0.0.0",  "md|smd|gen|bin|cue",  60.0, 48000)
DEFINE_CORE_INTERFACE(MelonDS_GetInterface,       "melonds",         "melonDS DS",        "0.9.5",  "nds|dsi",             60.0, 44100)
DEFINE_CORE_INTERFACE(Azahar_GetInterface,        "azahar",          "Azahar 3DS",        "1.0.0",  "3ds|cia|cxi",         60.0, 48000)
DEFINE_CORE_INTERFACE(Flycast_GetInterface,       "flycast",         "Flycast Dreamcast", "2.1",    "cdi|gdi|chd",         60.0, 44100)
DEFINE_CORE_INTERFACE(Ppsspp_GetInterface,        "ppsspp",          "PPSSPP",            "1.17.1", "iso|cso|pbp",         60.0, 44100)

// ============================================================================
// REGISTRY DISPATCH TABLE
// ============================================================================

typedef const GagaCoreInterface* (*CoreGetterFunc)(void);

static const CoreGetterFunc s_core_getters[] = {
    MockCore_GetInterface,
    Mgba_GetInterface,
    Gambatte_GetInterface,
    Nestopia_GetInterface,
    Bsnes_GetInterface,
    Jgenesis_GetInterface,
    PcsxReArmed_GetInterface,
    BeetlePsx_GetInterface,
    Gpsp_GetInterface,
    MelonDS_GetInterface,
    Azahar_GetInterface,
    Flycast_GetInterface,
    Ppsspp_GetInterface,
};

static const size_t s_core_count = sizeof(s_core_getters) / sizeof(s_core_getters[0]);

size_t GagaCoreRegistry_GetCount(void) {
    return s_core_count;
}

const GagaCoreInterface* GagaCoreRegistry_GetAtIndex(size_t index) {
    if (index >= s_core_count) return NULL;
    return s_core_getters[index]();
}

const GagaCoreInterface* GagaCoreRegistry_FindByID(const char* core_id) {
    if (!core_id) return NULL;
    for (size_t i = 0; i < s_core_count; ++i) {
        const GagaCoreInterface* core = s_core_getters[i]();
        if (core && core->core_id && strcmp(core->core_id, core_id) == 0) {
            return core;
        }
    }
    return NULL;
}

bool GagaCoreRegistry_IsExcluded(const char* core_id) {
    const GagaCoreInterface* core = GagaCoreRegistry_FindByID(core_id);
    return core && strcmp(core->core_version, GAGA_CORE_EXCLUDED) == 0;
}

const GagaCoreInterface* GagaCoreRegistry_FindByExtension(const char* extension) {
    if (!extension) return NULL;
    // Strip leading dot if present
    if (extension[0] == '.') {
        extension++;
    }

    for (size_t i = 0; i < s_core_count; ++i) {
        const GagaCoreInterface* core = s_core_getters[i]();
        if (!core || !core->supported_extensions) continue;

        // Supported extensions is pipe-delimited list e.g. "gba|bin|zip"
        const char* ext_list = core->supported_extensions;
        const char* cursor = ext_list;
        while (*cursor != '\0') {
            const char* next_pipe = strchr(cursor, '|');
            size_t token_len = next_pipe ? (size_t)(next_pipe - cursor) : strlen(cursor);
            if (strlen(extension) == token_len && strncasecmp(cursor, extension, token_len) == 0) {
                return core;
            }
            if (!next_pipe) break;
            cursor = next_pipe + 1;
        }
    }
    return NULL;
}
