// mGBA behind the GagaBridge interface, through mGBA's embedded API, which is far smaller than its
// libretro layer. Single threaded (DISABLE_THREADING): every call and callback stays on the host's queue.
// No BIOS file is ever loaded, so mGBA uses its own HLE BIOS. skipBios also avoids needing a boot logo.
// One instance runs a Game Boy Advance, Game Boy or Game Boy Color game: load_rom swaps in mGBA's GB machine for a
// GB or GBC file. The GB model is detected from the cartridge header, and Super Game Boy borders stay off.
#include "GagaBridge.h"

#include <mgba/core/blip_buf.h>
#include <mgba/core/cheats.h>
#include <mgba/core/core.h>
#include <mgba/core/log.h>
#include <mgba/gb/core.h>
#include <mgba/gba/core.h>
#include <mgba/internal/gb/cheats.h>
#include <mgba/internal/gb/gb.h>
#include <mgba/internal/gb/serialize.h>
#include <mgba/internal/gba/cheats.h>
#include <mgba/internal/gba/gba.h>
#include <mgba/internal/gba/input.h>
#include <mgba/internal/gba/serialize.h>
#include <mgba-util/vfs.h>

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define MGBA_WIDTH 240
#define MGBA_HEIGHT 160
#define MGBA_GB_WIDTH 160
#define MGBA_GB_HEIGHT 144
#define MGBA_BUFFER_PIXELS (256 * 224) // The largest GB picture, a Super Game Boy border, so no setting can overrun it.
#define MGBA_SAMPLE_RATE 32768
#define MGBA_AUDIO_CAPACITY 2048 // About 3.7 frames at 549 samples per frame.
// GBASavestateMagic + GBASavestateVersion. A test checks this against real state bytes. GB states carry their own
// magic inside; the bridge's version is one number per core, and load_state checks size and game either way.
#define MGBA_STATE_VERSION 0x01000007u

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
    color_t video[MGBA_BUFFER_PIXELS];
    unsigned width, height; // The running machine's picture, also the buffer's stride.
    int16_t audio[MGBA_AUDIO_CAPACITY * 2];
    struct mRumble rumble; // A cartridge's motor, such as Drill Dozer's.
    int rumble_on, rumble_off; // Writes this frame.
    bool rumble_last;          // The last write, for a frame with none.
    uint16_t rumble_sent;
    int option_value[2];   // Index into each s_options entry's values, in s_options order.
    bool option_set[2];    // The player chose it, rather than the default.
    char options_json[2048];
} MgbaInstance;

// The settings mGBA's embedded API takes while a game runs, both live. The rest stay fixed: no BIOS file (its own HLE
// BIOS), and the host owns volume, pacing and the picture.
typedef struct { const char* value; const char* label; } MgbaOptionValue;
typedef struct {
    const char* key;
    const char* label;
    const char* info;
    MgbaOptionValue values[4];
    int count;
    int initial; // The default's index: what mGBA does when not told (GBACreate allows opposing directions).
} MgbaOption;

static const MgbaOption s_options[2] = {
    { "allowOpposingDirections", "Allow Opposing Directions",
      "Lets Left and Right, or Up and Down, be held at once. Some games misbehave with it.",
      { { "0", "Off" }, { "1", "On" } }, 2, 1 },
    { "frameskip", "Frame Skip",
      "Draws fewer frames to save power. The game still runs at full speed.",
      { { "0", "Off" }, { "1", "Skip 1" }, { "2", "Skip 2" }, { "3", "Skip 3" } }, 4, 0 },
};

static void mgba_apply_option(MgbaInstance* m, int i);

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

static void mgba_set_rumble(struct mRumble* rumble, int enable) {
    MgbaInstance* m = (MgbaInstance*)((char*)rumble - offsetof(MgbaInstance, rumble));
    if (enable) ++m->rumble_on; else ++m->rumble_off;
    m->rumble_last = enable != 0;
}

// The cartridge switches its motor many times a frame, so the share of writes that turned it on is the
// strength, as in mGBA's libretro port. Both motors get it.
static void mgba_send_rumble(MgbaInstance* m) {
    int writes = m->rumble_on + m->rumble_off;
    uint16_t strength = writes ? (uint16_t)((uint32_t)m->rumble_on * 0xFFFFu / (uint32_t)writes) : (m->rumble_last ? 0xFFFF : 0);
    m->rumble_on = m->rumble_off = 0;
    if (strength == m->rumble_sent) return;
    m->rumble_sent = strength;
    mgba_emit(m, GAGA_EVENT_RUMBLE, GAGA_RUMBLE_CODE(0, GAGA_RUMBLE_STRONG, strength), NULL);
    mgba_emit(m, GAGA_EVENT_RUMBLE, GAGA_RUMBLE_CODE(0, GAGA_RUMBLE_WEAK, strength), NULL);
}

// Sets a new machine up the way the bridge drives it and makes it the instance's. Frees it on failure.
static bool mgba_start_core(MgbaInstance* m, struct mCore* core) {
    if (!core || !core->init(core)) {
        free(core);
        return false;
    }
    mCoreInitConfig(core, NULL);
    core->opts.skipBios = true;
    m->core = core;
    bool gb = core->platform(core) == mPLATFORM_GB;
    m->width = gb ? MGBA_GB_WIDTH : MGBA_WIDTH;
    m->height = gb ? MGBA_GB_HEIGHT : MGBA_HEIGHT;
    m->rumble.setRumble = mgba_set_rumble;
    core->setPeripheral(core, mPERIPH_RUMBLE, &m->rumble);
    core->setVideoBuffer(core, m->video, m->width);
    core->setAudioBufferSize(core, MGBA_AUDIO_CAPACITY / 2);
    blip_set_rates(core->getAudioChannel(core, 0), core->frequency(core), MGBA_SAMPLE_RATE);
    blip_set_rates(core->getAudioChannel(core, 1), core->frequency(core), MGBA_SAMPLE_RATE);
    return true;
}

// Unmaps and flushes the save file.
static void mgba_stop_core(struct mCore* core) {
    mCoreConfigDeinit(&core->config);
    core->deinit(core);
}

static GagaInstance* mgba_create(const char* system_dir, const char* save_dir) {
    (void)system_dir; // No BIOS or other system file is read.
    MgbaInstance* m = calloc(1, sizeof(MgbaInstance));
    if (!m) return NULL;
    if (save_dir) strlcpy(m->save_dir, save_dir, sizeof(m->save_dir));
    for (int i = 0; i < 2; ++i) m->option_value[i] = s_options[i].initial;

    mLogSetDefaultLogger(&s_logger);
    s_log_target = m;

    // A GBA machine until load_rom sees a GB or GBC file.
    if (!mgba_start_core(m, GBACoreCreate())) {
        if (s_log_target == m) s_log_target = NULL;
        free(m);
        return NULL;
    }
    return (GagaInstance*)m;
}

static void mgba_destroy(GagaInstance* inst) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    if (s_log_target == m) s_log_target = NULL;
    mgba_stop_core(m->core);
    free(m);
}

static bool mgba_is_gb(const MgbaInstance* m) {
    return m->core->platform(m->core) == mPLATFORM_GB;
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

// GBIsROM looks for the Nintendo logo, which homebrew may leave out. A .gb or .gbc file whose header checksum is
// right, the check the console's own boot ROM makes, is taken as a Game Boy game.
static bool mgba_gb_by_name_and_header(const char* rom_path, struct VFile* rom) {
    const char* dot = strrchr(rom_path, '.');
    if (!dot || (strcasecmp(dot, ".gb") != 0 && strcasecmp(dot, ".gbc") != 0)) return false;
    uint8_t header[0x50];
    if (rom->seek(rom, 0x100, SEEK_SET) < 0 || rom->read(rom, header, sizeof(header)) != (ssize_t)sizeof(header)) return false;
    uint8_t sum = 0;
    for (int i = 0x34; i < 0x4D; ++i) sum = (uint8_t)(sum - header[i] - 1);
    return sum == header[0x4D];
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
    enum mPlatform platform = mCoreIsCompatible(rom);
    if (platform == mPLATFORM_NONE && mgba_gb_by_name_and_header(rom_path, rom)) platform = mPLATFORM_GB;
    if (platform == mPLATFORM_NONE) {
        rom->close(rom);
        mgba_emit(m, GAGA_EVENT_FATAL, MGBA_EVENT_BAD_ROM, "This file is not a Game Boy, Game Boy Color or Game Boy Advance game.");
        return false;
    }
    if (platform != m->core->platform(m->core)) {
        struct mCore* old = m->core;
        if (!mgba_start_core(m, mCoreCreate(platform))) {
            rom->close(rom);
            mgba_emit(m, GAGA_EVENT_FATAL, MGBA_EVENT_BAD_ROM, "mGBA could not start.");
            return false;
        }
        mgba_stop_core(old);
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
    for (int i = 0; i < 2; ++i) mgba_apply_option(m, i); // Values set before the game, now on its machine.
    if (mgba_is_gb(m)) {
        // A Super Game Boy game would otherwise draw a 256x224 frame. Its palettes still apply.
        mCoreConfigSetIntValue(&m->core->config, "sgb.borders", 0);
        m->core->reloadConfigOption(m->core, "sgb.borders", NULL);
    }
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
    mgba_send_rumble(m);

    if (m->video_cb) {
        // mGBA leaves the top byte zero, and the host's shaders pass alpha through.
        for (size_t i = 0; i < (size_t)m->width * m->height; ++i) m->video[i] |= 0xFF000000u;
        GagaFrameDescriptor frame = {
            .pixel_data = m->video,
            .width = m->width,
            .height = m->height,
            .pitch = m->width * sizeof(color_t),
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

static size_t mgba_state_size(GagaInstance* inst) {
    MgbaInstance* m = (MgbaInstance*)inst;
    return m ? m->core->stateSize(m->core) : 0;
}

static bool mgba_save_state(GagaInstance* inst, void* buffer, size_t size) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m || !buffer || size != m->core->stateSize(m->core)) return false;
    return m->core->saveState(m->core, buffer);
}

static void mgba_error(char* error, size_t capacity, const char* message) {
    if (error && capacity > 0) snprintf(error, capacity, "%s", message);
}

// GBADeserialize checks everything it refuses before it changes anything. It only warns about a
// different ROM CRC, which would run a state on code it was not made for, so that is refused here.
static bool mgba_load_state(GagaInstance* inst, const void* buffer, size_t size, char* error, size_t error_capacity) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m || !buffer || size != m->core->stateSize(m->core)) {
        mgba_error(error, error_capacity, "This save state is the wrong size for mGBA.");
        return false;
    }
    // GBDeserialize also checks before it changes anything, and also only warns about the ROM CRC.
    bool same_game = mgba_is_gb(m)
        ? ((const struct GBSerializedState*)buffer)->romCrc32 == ((const struct GB*)m->core->board)->romCrc32
        : ((const struct GBASerializedState*)buffer)->romCrc32 == ((const struct GBA*)m->core->board)->romCrc32;
    if (!same_game || !m->core->loadState(m->core, buffer)) {
        mgba_error(error, error_capacity, "This save state belongs to another game or another version of this game.");
        return false;
    }
    return true;
}

// The save is a shared mapping, so a killed app keeps it. This also reaches storage if the OS goes down.
static void mgba_flush_battery_save(GagaInstance* inst) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    if (mgba_is_gb(m)) {
        struct GB* gb = m->core->board;
        if (gb->sramVf && gb->memory.sram) gb->sramVf->sync(gb->sramVf, gb->memory.sram, gb->sramSize);
        return;
    }
    struct GBA* gba = m->core->board;
    struct GBASavedata* save = &gba->memory.savedata;
    if (save->vf && save->data && (save->mapMode & MAP_WRITE)) save->vf->sync(save->vf, save->data, GBASavedataSize(save));
}

// A set is named after the host's ID, so the device's own list is the only table.
static struct mCheatSet* mgba_find_cheat(struct mCheatDevice* device, uint32_t id) {
    char name[16];
    snprintf(name, sizeof(name), "%u", id);
    for (size_t i = 0; i < mCheatSetsSize(&device->cheats); ++i) {
        struct mCheatSet* set = *mCheatSetsGetPointer(&device->cheats, i);
        if (set->name && strcmp(set->name, name) == 0) return set;
    }
    return NULL;
}

// One or more lines of GameShark, Action Replay, CodeBreaker or VBA codes, or for GB and GBC, GameShark or Game Genie.
// mGBA detects the format.
static bool mgba_cheat_add(GagaInstance* inst, uint32_t id, const char* code, bool enabled, char* error, size_t error_capacity) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m || !code) return false;
    bool gb = mgba_is_gb(m);
    struct mCheatDevice* device = m->core->cheatDevice(m->core);
    char name[16];
    snprintf(name, sizeof(name), "%u", id);
    struct mCheatSet* set = device->createSet(device, name);
    char* copy = strdup(code);
    char* cursor = NULL;
    int lines = 0;
    bool valid = set && copy;
    for (char* line = copy ? strtok_r(copy, "\r\n", &cursor) : NULL; line && valid; line = strtok_r(NULL, "\r\n", &cursor)) {
        while (isspace((unsigned char)*line)) ++line;
        if (!*line) continue;
        if (mCheatAddLine(set, line, gb ? GB_CHEAT_AUTODETECT : GBA_CHEAT_AUTODETECT)) {
            ++lines;
        } else {
            valid = false;
            if (error && error_capacity > 0) snprintf(error, error_capacity, "mGBA does not recognise this code: %.32s", line);
        }
    }
    free(copy);
    if (valid && lines == 0) {
        valid = false;
        mgba_error(error, error_capacity, "Enter a cheat code.");
    }
    // Only GBA codes span lines; a GB code is whole on one.
    const struct GBACheatSet* parsed = (const struct GBACheatSet*)set;
    if (valid && !gb && (parsed->incompleteCheat != COMPLETE || parsed->incompletePatch)) {
        valid = false;
        mgba_error(error, error_capacity, "This code is missing its last line.");
    }
    if (!valid) {
        if (set) mCheatSetDeinit(set);
        return false;
    }
    set->enabled = enabled;
    mCheatAddSet(device, set);
    return true;
}

static void mgba_cheat_set_enabled(GagaInstance* inst, uint32_t id, bool enabled) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    struct mCheatDevice* device = m->core->cheatDevice(m->core);
    struct mCheatSet* set = mgba_find_cheat(device, id);
    if (!set) return;
    set->enabled = enabled;
    mCheatRefresh(device, set); // Undoes any ROM patch at once, not at the next frame.
}

static void mgba_cheat_remove(GagaInstance* inst, uint32_t id) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m) return;
    struct mCheatDevice* device = m->core->cheatDevice(m->core);
    struct mCheatSet* set = mgba_find_cheat(device, id);
    if (!set) return;
    set->enabled = false;
    mCheatRefresh(device, set);
    mCheatRemoveSet(device, set);
    mCheatSetDeinit(set);
}

// Brings up the whole machine with no game, which proves the framework loaded and links correctly.
static bool mgba_self_test(char* error, size_t error_capacity) {
    for (int i = 0; i < 2; ++i) {
        struct mCore* core = i ? GBCoreCreate() : GBACoreCreate();
        if (!core || !core->init(core)) {
            free(core);
            if (error && error_capacity > 0) snprintf(error, error_capacity, "mGBA could not start.");
            return false;
        }
        core->deinit(core);
    }
    return true;
}

// MARK: - Options

static void mgba_apply_option(MgbaInstance* m, int i) {
    mCoreConfigSetIntValue(&m->core->config, s_options[i].key, m->option_value[i]);
    m->core->reloadConfigOption(m->core, s_options[i].key, NULL);
}

// The JSON GagaBridge.h describes. "served" is what the core runs with now; with no instance, nothing is running.
static const char* mgba_options(GagaInstance* inst) {
    static char s_probe_json[2048];
    MgbaInstance* m = (MgbaInstance*)inst;
    char* json = m ? m->options_json : s_probe_json;
    size_t size = m ? sizeof(m->options_json) : sizeof(s_probe_json), used = 0;
#define MGBA_JSON(...) used += (size_t)snprintf(json + used, used < size ? size - used : 0, __VA_ARGS__)
    MGBA_JSON("{\"categories\":[],\"options\":[");
    for (int i = 0; i < 2; ++i) {
        const MgbaOption* o = &s_options[i];
        const char* current = m ? o->values[m->option_value[i]].value : NULL;
        MGBA_JSON("%s{\"key\":\"%s\",\"label\":\"%s\",\"info\":\"%s\",\"category\":null,\"default\":\"%s\",", i ? "," : "",
                  o->key, o->label, o->info, o->values[o->initial].value);
        if (m && m->option_set[i]) MGBA_JSON("\"value\":\"%s\",", current); else MGBA_JSON("\"value\":null,");
        if (current) MGBA_JSON("\"served\":\"%s\",", current); else MGBA_JSON("\"served\":null,");
        MGBA_JSON("\"visible\":true,\"locked\":false,\"restart\":false,\"values\":[");
        for (int v = 0; v < o->count; ++v) {
            MGBA_JSON("%s{\"value\":\"%s\",\"label\":\"%s\"}", v ? "," : "", o->values[v].value, o->values[v].label);
        }
        MGBA_JSON("]}");
    }
    MGBA_JSON("]}");
#undef MGBA_JSON
    return used < size ? json : NULL;
}

static bool mgba_set_option(GagaInstance* inst, const char* key, const char* value) {
    MgbaInstance* m = (MgbaInstance*)inst;
    if (!m || !key) return false;
    for (int i = 0; i < 2; ++i) {
        const MgbaOption* o = &s_options[i];
        if (strcmp(o->key, key) != 0) continue;
        int chosen = value ? -1 : o->initial;
        for (int v = 0; value && v < o->count; ++v) {
            if (strcmp(o->values[v].value, value) == 0) chosen = v;
        }
        if (chosen < 0) return false;
        m->option_value[i] = chosen;
        m->option_set[i] = value != NULL;
        mgba_apply_option(m, i);
        return true;
    }
    return false;
}

static const GagaCoreInterface s_interface = {
    .abi_version = GAGA_BRIDGE_ABI_VERSION,
    .core_id = "mgba",
    .core_name = "mGBA",
    .core_version = GAGA_CORE_VERSION,
    .supported_extensions = "gba|gb|gbc",
    .target_fps = 16777216.0 / 280896.0, // 59.7275: the GBA's clock over its cycles per frame, and the GB's 4194304 / 70224.
    .native_sample_rate = MGBA_SAMPLE_RATE,
    .create = mgba_create,
    .destroy = mgba_destroy,
    .load_rom = mgba_load_rom,
    .reset = mgba_reset,
    .step_frame = mgba_step_frame,
    .set_video_callback = mgba_set_video_callback,
    .set_audio_callback = mgba_set_audio_callback,
    .state_version = MGBA_STATE_VERSION,
    .state_size = mgba_state_size,
    .save_state = mgba_save_state,
    .load_state = mgba_load_state,
    .flush_battery_save = mgba_flush_battery_save,
    .cheat_add = mgba_cheat_add,
    .cheat_remove = mgba_cheat_remove,
    .cheat_set_enabled = mgba_cheat_set_enabled,
    .self_test = mgba_self_test,
    .pause = mgba_pause,
    .resume = mgba_resume,
    .set_event_callback = mgba_set_event_callback,
    .options = mgba_options,
    .set_option = mgba_set_option,
};

const GagaCoreInterface* Mgba_GetInterface(void) {
    return &s_interface;
}
