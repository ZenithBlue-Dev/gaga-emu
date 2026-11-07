// mGBA behind the GagaBridge interface, through mGBA's embedded API, which is far smaller than its
// libretro layer. Single threaded (DISABLE_THREADING): every call and callback stays on the host's queue.
// No BIOS file is ever loaded, so mGBA uses its own HLE BIOS. skipBios also avoids needing a boot logo.
#include "GagaBridge.h"

#include <mgba/core/blip_buf.h>
#include <mgba/core/core.h>
#include <mgba/core/log.h>
#include <mgba/gba/core.h>
#include <mgba/internal/gba/input.h>
#include <mgba-util/vfs.h>

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MGBA_WIDTH 240
#define MGBA_HEIGHT 160
#define MGBA_SAMPLE_RATE 32768
#define MGBA_AUDIO_CAPACITY 2048 // About 3.7 frames at 549 samples per frame.

enum { MGBA_EVENT_FATAL_LOG = 1, MGBA_EVENT_BAD_ROM = 2, MGBA_EVENT_BAD_SAVE = 3 };

typedef struct {
    struct mCore* core;
    char save_dir[PATH_MAX];
    void (*video_cb)(const GagaFrameDescriptor* frame, void* userdata);
    void* video_userdata;
    void (*audio_cb)(const GagaAudioDescriptor* audio, void* userdata);
    void* audio_userdata;
    void (*event_cb)(GagaEventSeverity severity, int32_t code, const char* message, void* userdata);
    void* event_userdata;
    color_t video[MGBA_WIDTH * MGBA_HEIGHT];
    int16_t audio[MGBA_AUDIO_CAPACITY * 2];
} MgbaInstance;

// shortcut: mGBA's logger is one process-wide pointer, so only the newest instance gets FATAL logs. The host runs one session at a time; pass the instance through mLogger if that changes.
static MgbaInstance* s_log_target;

static void mgba_emit(MgbaInstance* m, GagaEventSeverity severity, int32_t code, const char* message) {
    if (m->event_cb) m->event_cb(severity, code, message, m->event_userdata);
}

static void mgba_log(struct mLogger* logger, int category, enum mLogLevel level, const char* format, va_list args) {
    (void)logger;
    (void)category;
    if (level != mLOG_FATAL || !s_log_target) return;
    char detail[192];
    vsnprintf(detail, sizeof(detail), format, args);
    char message[256];
    snprintf(message, sizeof(message), "mGBA stopped: %s", detail);
    mgba_emit(s_log_target, GAGA_EVENT_FATAL, MGBA_EVENT_FATAL_LOG, message);
}

static struct mLogger s_logger = { .log = mgba_log };

static GagaInstance* mgba_create(const char* system_dir, const char* save_dir) {
    (void)system_dir; // No BIOS or other system file is read.
    MgbaInstance* m = calloc(1, sizeof(MgbaInstance));
    if (!m) return NULL;
    if (save_dir) strlcpy(m->save_dir, save_dir, sizeof(m->save_dir));

    mLogSetDefaultLogger(&s_logger);
    s_log_target = m;

    m->core = GBACoreCreate();
    if (!m->core || !m->core->init(m->core)) {
        if (s_log_target == m) s_log_target = NULL;
        free(m->core);
        free(m);
        return NULL;
    }
    mCoreInitConfig(m->core, NULL);
    m->core->opts.skipBios = true;
    m->core->setVideoBuffer(m->core, m->video, MGBA_WIDTH);
    m->core->setAudioBufferSize(m->core, MGBA_AUDIO_CAPACITY / 2);
    blip_set_rates(m->core->getAudioChannel(m->core, 0), m->core->frequency(m->core), MGBA_SAMPLE_RATE);
    blip_set_rates(m->core->getAudioChannel(m->core, 1), m->core->frequency(m->core), MGBA_SAMPLE_RATE);
    return (GagaInstance*)m;
}

static void mgba_destroy(GagaInstance* inst) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    if (s_log_target == m) s_log_target = NULL;
    // Unmaps and flushes the save file.
    mCoreConfigDeinit(&m->core->config);
    m->core->deinit(m->core);
    free(m);
}

// Opens <save_dir>/<rom name>.sav, mapped read-write, so a battery save survives the app being killed.
static bool mgba_open_save(MgbaInstance* m, const char* rom_path) {
    const char* slash = strrchr(rom_path, '/');
    const char* name = slash ? slash + 1 : rom_path;
    const char* dot = strrchr(name, '.');
    int stem = dot ? (int)(dot - name) : (int)strlen(name);
    char path[PATH_MAX];
    int written = snprintf(path, sizeof(path), "%s/%.*s.sav", m->save_dir, stem, name);
    if (written < 0 || (size_t)written >= sizeof(path)) return false;
    struct VFile* save = VFileOpen(path, O_CREAT | O_RDWR);
    if (!save) return false;
    if (!m->core->loadSave(m->core, save)) {
        save->close(save);
        return false;
    }
    return true;
}

static bool mgba_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    (void)rom_data; // The host passes a path only, so large games stay mapped rather than copied.
    (void)rom_size;
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m || !rom_path) return false;

    struct VFile* rom = VFileOpen(rom_path, O_RDONLY);
    if (!rom) {
        mgba_emit(m, GAGA_EVENT_FATAL, MGBA_EVENT_BAD_ROM, "The game file could not be opened.");
        return false;
    }
    if (!m->core->isROM(rom)) {
        rom->close(rom);
        mgba_emit(m, GAGA_EVENT_FATAL, MGBA_EVENT_BAD_ROM, "This file is not a Game Boy Advance game.");
        return false;
    }
    if (!m->core->loadROM(m->core, rom)) {
        rom->close(rom);
        mgba_emit(m, GAGA_EVENT_FATAL, MGBA_EVENT_BAD_ROM, "mGBA could not load this game.");
        return false;
    }
    // Refuse to run rather than let a player lose progress to a save that never reaches disk.
    if (!mgba_open_save(m, rom_path)) {
        mgba_emit(m, GAGA_EVENT_FATAL, MGBA_EVENT_BAD_SAVE, "The save file for this game could not be opened.");
        return false;
    }
    m->core->reset(m->core);
    return true;
}

static void mgba_reset(GagaInstance* inst) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (m) m->core->reset(m->core);
}

static uint32_t mgba_keys(uint32_t buttons) {
    uint32_t keys = 0;
    if (buttons & GAGA_BTN_EAST) keys |= 1 << GBA_KEY_A;
    if (buttons & GAGA_BTN_SOUTH) keys |= 1 << GBA_KEY_B;
    if (buttons & GAGA_BTN_SELECT) keys |= 1 << GBA_KEY_SELECT;
    if (buttons & GAGA_BTN_START) keys |= 1 << GBA_KEY_START;
    if (buttons & GAGA_BTN_RIGHT) keys |= 1 << GBA_KEY_RIGHT;
    if (buttons & GAGA_BTN_LEFT) keys |= 1 << GBA_KEY_LEFT;
    if (buttons & GAGA_BTN_UP) keys |= 1 << GBA_KEY_UP;
    if (buttons & GAGA_BTN_DOWN) keys |= 1 << GBA_KEY_DOWN;
    if (buttons & GAGA_BTN_R1) keys |= 1 << GBA_KEY_R;
    if (buttons & GAGA_BTN_L1) keys |= 1 << GBA_KEY_L;
    return keys;
}

static void mgba_step_frame(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    m->core->setKeys(m->core, inputs && player_count > 0 ? mgba_keys(inputs[0].buttons) : 0);
    m->core->runFrame(m->core);

    if (m->video_cb) {
        // mGBA leaves the top byte zero, and the host's shaders pass alpha through.
        for (size_t i = 0; i < MGBA_WIDTH * MGBA_HEIGHT; ++i) m->video[i] |= 0xFF000000u;
        GagaFrameDescriptor frame = {
            .pixel_data = m->video,
            .width = MGBA_WIDTH,
            .height = MGBA_HEIGHT,
            .pitch = MGBA_WIDTH * sizeof(color_t),
            .pixel_format = GAGA_PIXEL_FORMAT_RGBA8888,
        };
        m->video_cb(&frame, m->video_userdata);
    }

    // Always drained, so a host without an audio callback cannot back up the core's buffers.
    blip_t* left = m->core->getAudioChannel(m->core, 0);
    blip_t* right = m->core->getAudioChannel(m->core, 1);
    int available = blip_samples_avail(left);
    if (available > MGBA_AUDIO_CAPACITY) available = MGBA_AUDIO_CAPACITY;
    if (available <= 0) return;
    blip_read_samples(left, m->audio, available, true);
    blip_read_samples(right, m->audio + 1, available, true);
    if (m->audio_cb) {
        GagaAudioDescriptor audio = {
            .pcm_samples = m->audio,
            .frames = (size_t)available,
            .sample_rate = MGBA_SAMPLE_RATE,
            .channels = 2,
        };
        m->audio_cb(&audio, m->audio_userdata);
    }
}

static void mgba_set_video_callback(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor*, void*), void* userdata) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    m->video_cb = cb;
    m->video_userdata = userdata;
}

static void mgba_set_audio_callback(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor*, void*), void* userdata) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    m->audio_cb = cb;
    m->audio_userdata = userdata;
}

static void mgba_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    m->event_cb = cb;
    m->event_userdata = userdata;
}

// Nothing runs between step_frame calls, so there is nothing to stop or restart.
static void mgba_pause(GagaInstance* inst) { (void)inst; }
static void mgba_resume(GagaInstance* inst) { (void)inst; }

// shortcut: save states and cheats return with milestones 2.6 and 2.10, which add their UI. Until then these report failure rather than pretend.
static bool mgba_save_state_file(GagaInstance* inst, const char* path) { (void)inst; (void)path; return false; }
static bool mgba_load_state_file(GagaInstance* inst, const char* path) { (void)inst; (void)path; return false; }
static void mgba_apply_cheat(GagaInstance* inst, uint32_t index, bool enabled, const char* code) {
    (void)inst; (void)index; (void)enabled; (void)code;
}

static bool mgba_attach_metal_layer(GagaInstance* inst, void* layer) { (void)inst; (void)layer; return false; }

// Brings up the whole machine with no game, which proves the framework loaded and links correctly.
static bool mgba_self_test(char* error, size_t error_capacity) {
    struct mCore* core = GBACoreCreate();
    if (!core || !core->init(core)) {
        free(core);
        if (error && error_capacity > 0) snprintf(error, error_capacity, "mGBA could not start.");
        return false;
    }
    core->deinit(core);
    return true;
}

static const GagaCoreInterface s_interface = {
    .abi_version = GAGA_BRIDGE_ABI_VERSION,
    .core_id = "mgba",
    .core_name = "mGBA",
    .core_version = GAGA_CORE_VERSION,
    .supported_extensions = "gba",
    .target_fps = 16777216.0 / 280896.0, // 59.7275: the GBA's clock over its cycles per frame.
    .native_sample_rate = MGBA_SAMPLE_RATE,
    .create = mgba_create,
    .destroy = mgba_destroy,
    .load_rom = mgba_load_rom,
    .reset = mgba_reset,
    .step_frame = mgba_step_frame,
    .attach_metal_layer = mgba_attach_metal_layer,
    .set_video_callback = mgba_set_video_callback,
    .set_audio_callback = mgba_set_audio_callback,
    .save_state_file = mgba_save_state_file,
    .load_state_file = mgba_load_state_file,
    .apply_cheat = mgba_apply_cheat,
    .self_test = mgba_self_test,
    .pause = mgba_pause,
    .resume = mgba_resume,
    .set_event_callback = mgba_set_event_callback,
};

const GagaCoreInterface* Mgba_GetInterface(void) {
    return &s_interface;
}
