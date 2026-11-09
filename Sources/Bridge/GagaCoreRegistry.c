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

#define MOCK_PORTS 8
static _Atomic uint32_t s_mock_last_player_count;
static _Atomic uint32_t s_mock_last_buttons[MOCK_PORTS];

uint32_t MockCore_LastPlayerCount(void) { return s_mock_last_player_count; }
uint32_t MockCore_LastButtons(uint32_t port) { return port < MOCK_PORTS ? s_mock_last_buttons[port] : 0; }

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
    s_mock_last_player_count = player_count;
    for (uint32_t port = 0; port < MOCK_PORTS; ++port) {
        // The host passes max(player_count, 4) states.
        s_mock_last_buttons[port] = inputs && port < (player_count > 4 ? player_count : 4) ? inputs[port].buttons : 0;
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

// A NES-sized work RAM (0x800), for the achievement tests.
static uint8_t s_mock_memory[0x800];
void MockCore_SetMemory(uint32_t address, uint8_t value) { s_mock_memory[address % sizeof s_mock_memory] = value; }

static void* mock_memory_data(GagaInstance* inst, uint32_t region, size_t* size) {
    (void)inst;
    enum { RETRO_MEMORY_SYSTEM_RAM_ID = 2 };
    *size = region == RETRO_MEMORY_SYSTEM_RAM_ID ? sizeof s_mock_memory : 0;
    return *size ? s_mock_memory : NULL;
}

static const GagaCoreInterface s_mock_interface = {
    .abi_version = GAGA_BRIDGE_ABI_VERSION,
    .memory_data = mock_memory_data,
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
#ifndef GAGA_HAS_MELONDS_DS
DEFINE_CORE_INTERFACE(MelonDS_GetInterface,       "melonds_ds",      "melonDS DS",        GAGA_CORE_EXCLUDED, "nds",      59.8261, 32728)
#endif
// The layer-path test core (Cores/vktest). CoreCatalog lists it in Debug builds only, and
// scripts/appstore_release.sh leaves it out of the core set.
#ifndef GAGA_HAS_VKTEST
DEFINE_CORE_INTERFACE(VkTest_GetInterface,        "vktest",          "Vulkan Test",       GAGA_CORE_EXCLUDED, "gagavk",   60.0,    48000)
#endif
#ifndef GAGA_HAS_DOSBOX_PURE
DEFINE_CORE_INTERFACE(DosboxPure_GetInterface,    "dosbox_pure",     "DOSBox Pure",       GAGA_CORE_EXCLUDED, "zip|dosz|exe|com|bat|iso|chd|cue|ins|img|ima|vhd|jrc|m3u|m3u8|conf", 60.0, 48000)
#endif
#ifndef GAGA_HAS_MAME
DEFINE_CORE_INTERFACE(Mame_GetInterface,          "mame",            "MAME",              GAGA_CORE_EXCLUDED, "zip|7z",   60.0,    48000)
#endif

#ifndef GAGA_HAS_BEETLE_SATURN
DEFINE_CORE_INTERFACE(BeetleSaturn_GetInterface,  "beetle_saturn",   "Beetle Saturn",     GAGA_CORE_EXCLUDED, "cue|ccd|chd|toc|m3u", 59.8265, 44100)
#endif

#ifndef GAGA_HAS_BEETLE_PSX
DEFINE_CORE_INTERFACE(BeetlePsx_GetInterface,     "beetle_psx",      "Beetle PSX HW",     GAGA_CORE_EXCLUDED, "exe|cue|toc|ccd|m3u|pbp|chd|bin|img|iso", 59.826, 44100)
#endif
DEFINE_CORE_INTERFACE(Gpsp_GetInterface,          "gpsp",            "gpSP",              "0.9.1",  "gba|bin",             59.7275, 44100)
#ifndef GAGA_HAS_JGENESIS
DEFINE_CORE_INTERFACE(Jgenesis_GetInterface,      "jgenesis",        "JGenesis",          GAGA_CORE_EXCLUDED, "md|smd|gen|bin|cue",  59.9227, 48000)
#endif
#ifndef GAGA_HAS_MUPEN64PLUS_NEXT
DEFINE_CORE_INTERFACE(Mupen64PlusNext_GetInterface, "mupen64plus_next", "Mupen64Plus-Next", GAGA_CORE_EXCLUDED, "n64|v64|z64", 60.0, 44100)
#endif
#ifndef GAGA_HAS_BEETLE_PCE_FAST
DEFINE_CORE_INTERFACE(BeetlePceFast_GetInterface, "beetle_pce_fast", "Beetle PCE Fast",  GAGA_CORE_EXCLUDED, "pce|cue|ccd|chd|toc|m3u", 59.82, 44100)
#endif
#ifndef GAGA_HAS_BEETLE_SUPERGRAFX
DEFINE_CORE_INTERFACE(BeetleSupergrafx_GetInterface, "beetle_supergrafx", "Beetle SuperGrafx", GAGA_CORE_EXCLUDED, "pce|sgx|cue|ccd|chd|toc|m3u", 59.82, 44100)
#endif
#ifndef GAGA_HAS_BEETLE_VB
DEFINE_CORE_INTERFACE(BeetleVb_GetInterface,     "beetle_vb",       "Beetle VB",         GAGA_CORE_EXCLUDED, "vb|vboy", 50.27, 44100)
#endif
#ifndef GAGA_HAS_BEETLE_NGP
DEFINE_CORE_INTERFACE(BeetleNgp_GetInterface,    "beetle_ngp",      "Beetle NeoPop",     GAGA_CORE_EXCLUDED, "ngp|ngc|ngpc|npc", 60.25, 44100)
#endif
#ifndef GAGA_HAS_BEETLE_WSWAN
DEFINE_CORE_INTERFACE(BeetleWswan_GetInterface,  "beetle_wswan",    "Beetle WonderSwan", GAGA_CORE_EXCLUDED, "ws|wsc|pc2", 60.38, 44100)
#endif
#ifndef GAGA_HAS_POKEMINI
DEFINE_CORE_INTERFACE(PokeMini_GetInterface,     "pokemini",        "PokeMini",          GAGA_CORE_EXCLUDED, "min", 60.0, 44100)
#endif
#ifndef GAGA_HAS_AZAHAR
DEFINE_CORE_INTERFACE(Azahar_GetInterface,       "azahar",          "Azahar",            GAGA_CORE_EXCLUDED, "3ds|3dsx|cci|cxi|app|elf|axf", 60.0, 32728)
#endif
#ifndef GAGA_HAS_FLYCAST
DEFINE_CORE_INTERFACE(Flycast_GetInterface,       "flycast",         "Flycast",           GAGA_CORE_EXCLUDED, "gdi|cdi|chd|cue", 59.9453, 44100)
#endif
#ifndef GAGA_HAS_PPSSPP
DEFINE_CORE_INTERFACE(Ppsspp_GetInterface,        "ppsspp",          "PPSSPP",            GAGA_CORE_EXCLUDED, "iso|cso|pbp|elf", 59.94, 44100)
#endif

// Non-commercial licences (docs/03 section 5): only GAGA_CORE_SET=sideload links these, so every App Store
// and TestFlight build has the refusing row and CoreCatalog hides the core.
#ifndef GAGA_HAS_SNES9X
DEFINE_CORE_INTERFACE(Snes9x_GetInterface,        "snes9x",          "Snes9x",            GAGA_CORE_EXCLUDED, "sfc|smc",  60.0988, 32040)
#endif
#ifndef GAGA_HAS_GENESIS_PLUS_GX
DEFINE_CORE_INTERFACE(GenesisPlusGX_GetInterface, "genesis_plus_gx", "Genesis Plus GX",   GAGA_CORE_EXCLUDED, "md|gen|smd|sms|gg|sg|bin|cue|chd|iso|m3u", 59.9227, 44100)
#endif
#ifndef GAGA_HAS_PICODRIVE
DEFINE_CORE_INTERFACE(Picodrive_GetInterface,     "picodrive",       "PicoDrive",         GAGA_CORE_EXCLUDED, "32x|md|gen|smd|sms|gg|sg|bin|cue|chd|iso|m3u", 60.0, 44100)
#endif
#ifndef GAGA_HAS_FBNEO
DEFINE_CORE_INTERFACE(Fbneo_GetInterface,         "fbneo",           "FinalBurn Neo",     GAGA_CORE_EXCLUDED, "zip|7z",   60.0,    48000)
#endif
#ifndef GAGA_HAS_SWANSTATION
DEFINE_CORE_INTERFACE(SwanStation_GetInterface,   "swanstation",     "SwanStation",       GAGA_CORE_EXCLUDED, "exe|psexe|cue|bin|img|iso|chd|pbp|ecm|mds|psf|m3u", 60.0, 44100)
#endif
// Backlog cores, group-retro (docs/07 section 8.x).
#ifndef GAGA_HAS_GEARSYSTEM
DEFINE_CORE_INTERFACE(Gearsystem_GetInterface,    "gearsystem",      "Gearsystem",        GAGA_CORE_EXCLUDED, "sms|gg|sg|mv", 59.9227, 44100)
#endif
#ifndef GAGA_HAS_STELLA
DEFINE_CORE_INTERFACE(Stella_GetInterface,        "stella",          "Stella",            GAGA_CORE_EXCLUDED, "a26|bin",  60.0,    31440)
#endif
#ifndef GAGA_HAS_PROSYSTEM
DEFINE_CORE_INTERFACE(ProSystem_GetInterface,     "prosystem",       "ProSystem",         GAGA_CORE_EXCLUDED, "a78",      60.0,    31440)
#endif
#ifndef GAGA_HAS_HANDY
DEFINE_CORE_INTERFACE(Handy_GetInterface,         "handy",           "Handy",             GAGA_CORE_EXCLUDED, "lnx",      60.0,    48000)
#endif
#ifndef GAGA_HAS_ATARI800
DEFINE_CORE_INTERFACE(Atari800_GetInterface,      "atari800",        "Atari800",          GAGA_CORE_EXCLUDED, "a52|xex|atr|xfd|dcm|atx", 59.92, 44100)
#endif
#ifndef GAGA_HAS_VIRTUALJAGUAR
DEFINE_CORE_INTERFACE(VirtualJaguar_GetInterface, "virtualjaguar",   "Virtual Jaguar",    GAGA_CORE_EXCLUDED, "j64|jag",  60.05,   48044)
#endif
#ifndef GAGA_HAS_VICE
DEFINE_CORE_INTERFACE(Vice_GetInterface,          "vice",            "VICE",              GAGA_CORE_EXCLUDED, "d64|t64|prg|crt|tap", 50.12, 48000)
#endif
#ifndef GAGA_HAS_PUAE
DEFINE_CORE_INTERFACE(Puae_GetInterface,          "puae",            "PUAE",              GAGA_CORE_EXCLUDED, "adf|hdf",  50.0,    44100)
#endif
#ifndef GAGA_HAS_PRBOOM
DEFINE_CORE_INTERFACE(Prboom_GetInterface,        "prboom",          "PrBoom",            GAGA_CORE_EXCLUDED, "wad",      60.0,    48000)
#endif

// ============================================================================
// REGISTRY DISPATCH TABLE
// ============================================================================

typedef const GagaCoreInterface* (*CoreGetterFunc)(void);

// FindByExtension returns the first core here that claims the extension, so order is policy: each extension goes to
// the default core of the platform CoreCatalog.platformID(forExtension:) names, or for a shared disc or archive
// extension, of the first platform CoreCatalog.unplacedPlatforms(forExtension:) offers whose default core claims it.
// Import decides the real platform by content. CoreRoutingTests checks every claimed extension against this rule.
static const CoreGetterFunc s_core_getters[] = {
    Mgba_GetInterface,
    Gambatte_GetInterface,
    Nestopia_GetInterface,
    Bsnes_GetInterface,
    PcsxReArmed_GetInterface, // First disc core: PS1 leads the disc platforms, so .cue, .bin, .chd, .iso, .m3u and .toc.
    Jgenesis_GetInterface,
    BeetleSaturn_GetInterface, // Before Beetle PSX and PCE Fast: .ccd, which PCSX-ReARMed does not claim, goes to Saturn.
    BeetlePsx_GetInterface,
    Gpsp_GetInterface,
    MelonDS_GetInterface,
    Mame_GetInterface, // Before DOSBox Pure and FBNeo: .zip and .7z offer Arcade first.
    Mupen64PlusNext_GetInterface,
    Ppsspp_GetInterface, // Before Azahar: an .elf is a PSP program unless its header says ARM.
    Azahar_GetInterface,
    Flycast_GetInterface,
    VkTest_GetInterface,
    BeetlePceFast_GetInterface, // After PCSX-ReARMed: FindByExtension gives .cue, .chd and .m3u to the PS1 core.
    BeetleSupergrafx_GetInterface, // After PCE Fast, which keeps .pce; this one is first for .sgx.
    BeetleVb_GetInterface,
    BeetleNgp_GetInterface,
    BeetleWswan_GetInterface,
    PokeMini_GetInterface,
    // group-retro. Gearsystem before Genesis Plus GX and PicoDrive, so it keeps .sms, .gg and .sg.
    Gearsystem_GetInterface,
    Stella_GetInterface,
    ProSystem_GetInterface,
    Handy_GetInterface,
    Atari800_GetInterface,
    VirtualJaguar_GetInterface,
    Vice_GetInterface,
    Puae_GetInterface,
    Prboom_GetInterface,
    Snes9x_GetInterface, // After the default core of each platform, so FindByExtension keeps the default.
    GenesisPlusGX_GetInterface,
    Picodrive_GetInterface,
    Fbneo_GetInterface,
    SwanStation_GetInterface,
    DosboxPure_GetInterface, // After PCSX-ReARMed: FindByExtension gives .exe, .iso and .cue to the PS1 core.
    MockCore_GetInterface, // Last: its "bin" must not shadow the PS1 core.
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
        // A core this build left out is never the answer, so the next claimant (the platform's default) is.
        if (!core || !core->supported_extensions || strcmp(core->core_version, GAGA_CORE_EXCLUDED) == 0) continue;

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
