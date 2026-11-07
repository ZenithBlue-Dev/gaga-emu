// See LibretroAdapter.h. Every retro_* call happens on the host's one serial queue, so every libretro
// callback fires there too, inside a host call, and hands the host only pointers valid for that call.
#include "LibretroAdapter.h"

#include <libretro.h>

#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

enum { LR_EVENT_BAD_ROM = 1, LR_EVENT_BAD_SAVE = 2, LR_EVENT_CORE_STOPPED = 3, LR_EVENT_BAD_VIDEO = 4 };

#define LR_MAX_PLAYERS 4
#define LR_FLUSH_INTERVAL_FRAMES 300    // About 5 seconds. Bounds what a crash can lose: the core's RAM is not a file.
#define LR_MAX_ROM_BYTES (1024u * 1024u * 1024u) // A core that takes bigger files sets need_fullpath.
#define LR_STATE_MAGIC "GLR1"

typedef struct {
    char magic[4];
    uint32_t payload_size;
    uint64_t rom_id;
} LrStateHeader; // In front of the core's own state bytes: libretro states do not say which ROM they belong to.

typedef struct {
    unsigned memory_id;
    const char* extension;
    char path[PATH_MAX];
    uint8_t* written; // What the file holds, so a flush with nothing new writes nothing.
    size_t size;
} LrBattery;

typedef struct {
    uint32_t id;
    bool enabled;
    char* code;
} LrCheat;

typedef struct {
    char system_dir[PATH_MAX];
    char save_dir[PATH_MAX];
    void (*video_cb)(const GagaFrameDescriptor*, void*);
    void* video_userdata;
    void (*audio_cb)(const GagaAudioDescriptor*, void*);
    void* audio_userdata;
    void (*event_cb)(GagaEventSeverity, int32_t, const char*, void*);
    void* event_userdata;

    bool loaded;
    bool save_write_failed;
    bool bad_video_reported;
    enum retro_pixel_format pixel_format;
    uint32_t sample_rate;
    uint64_t rom_id;
    GagaInputState inputs[LR_MAX_PLAYERS];
    uint32_t* opaque;
    size_t opaque_pixels;
    uint32_t frames_since_flush;
    LrBattery batteries[2];
    LrCheat* cheats;
    size_t cheat_count;
} LrInstance;

// The instance libretro's callbacks reach. Set before the core can call back and cleared before the
// instance is freed. The callbacks are static, so the pointers a core keeps after retro_deinit stay
// valid, and with no instance they do nothing.
static _Atomic(LrInstance*) s_current;
static LrInstance s_probe; // Stands in during self_test, which has no instance.

static LrInstance* lr_current(void) { return atomic_load_explicit(&s_current, memory_order_acquire); }

static bool lr_claim(LrInstance* a) {
    LrInstance* expected = NULL;
    return atomic_compare_exchange_strong(&s_current, &expected, a);
}

static void lr_release(void) { atomic_store_explicit(&s_current, NULL, memory_order_release); }

static void lr_emit(LrInstance* a, GagaEventSeverity severity, int32_t code, const char* message) {
    if (a->event_cb) a->event_cb(severity, code, message, a->event_userdata);
}

static void lr_error(char* error, size_t capacity, const char* format, const char* detail) {
    if (error && capacity > 0) snprintf(error, capacity, format, detail);
}

// MARK: - Environment

static void lr_log(enum retro_log_level level, const char* format, ...) {
    (void)level;
    (void)format; // Without this a core prints to stdout. FATAL is the only message the host acts on.
}

static bool lr_environment(unsigned command, void* data) {
    LrInstance* a = lr_current();
    if (!a) return false;
    switch (command) {
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        *(const char**)data = a->system_dir;
        return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        *(const char**)data = a->save_dir;
        return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
        enum retro_pixel_format format = *(const enum retro_pixel_format*)data;
        if (format != RETRO_PIXEL_FORMAT_XRGB8888 && format != RETRO_PIXEL_FORMAT_RGB565) return false;
        a->pixel_format = format;
        return true;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        struct retro_variable* variable = data;
        variable->value = NULL;
        for (const GagaLibretroVariable* v = gaga_libretro_core.variables; v && v->key; ++v) {
            if (strcmp(v->key, variable->key) == 0) {
                variable->value = v->value;
                return true;
            }
        }
        return false;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        *(bool*)data = false;
        return true;
    case RETRO_ENVIRONMENT_GET_CAN_DUPE:
        *(bool*)data = true; // A NULL frame leaves the last one on screen.
        return true;
    case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
        return true;
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
        ((struct retro_log_callback*)data)->log = lr_log;
        return true;
    case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
        a->sample_rate = (uint32_t)lround(((const struct retro_system_av_info*)data)->timing.sample_rate);
        return true;
    case RETRO_ENVIRONMENT_SHUTDOWN:
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_CORE_STOPPED, "The core stopped this game.");
        return true;
    default:
        return false; // No rumble, messages, VFS, core options UI, hardware rendering or other frontend extras.
    }
}

// MARK: - Video, audio, input

static void lr_video(const void* data, unsigned width, unsigned height, size_t pitch) {
    LrInstance* a = lr_current();
    if (!a || !data) return;
    GagaFrameDescriptor frame = { .pixel_data = data, .width = width, .height = height, .pitch = pitch };
    switch (a->pixel_format) {
    case RETRO_PIXEL_FORMAT_RGB565:
        frame.pixel_format = GAGA_PIXEL_FORMAT_RGB565;
        break;
    case RETRO_PIXEL_FORMAT_XRGB8888: {
        // libretro leaves X undefined, and the host's shaders pass alpha through.
        size_t pixels = (size_t)width * height;
        if (pixels > a->opaque_pixels) {
            uint32_t* grown = realloc(a->opaque, pixels * sizeof(uint32_t));
            if (!grown) return;
            a->opaque = grown;
            a->opaque_pixels = pixels;
        }
        for (unsigned y = 0; y < height; ++y) {
            const uint32_t* source = (const uint32_t*)((const uint8_t*)data + y * pitch);
            uint32_t* target = a->opaque + (size_t)y * width;
            for (unsigned x = 0; x < width; ++x) target[x] = source[x] | 0xFF000000u;
        }
        frame.pixel_data = a->opaque;
        frame.pitch = (size_t)width * sizeof(uint32_t);
        frame.pixel_format = GAGA_PIXEL_FORMAT_XRGB8888;
        break;
    }
    default:
        // A core that never sets a format means 0RGB1555, which the bridge does not take.
        if (!a->bad_video_reported) {
            a->bad_video_reported = true;
            lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_VIDEO, "This core draws in a pixel format GagaEmu cannot show.");
        }
        return;
    }
    if (a->video_cb) a->video_cb(&frame, a->video_userdata);
}

static size_t lr_audio_batch(const int16_t* data, size_t frames) {
    LrInstance* a = lr_current();
    if (a && a->audio_cb && frames > 0) {
        GagaAudioDescriptor audio = { .pcm_samples = data, .frames = frames, .sample_rate = a->sample_rate, .channels = 2 };
        a->audio_cb(&audio, a->audio_userdata);
    }
    return frames;
}

// shortcut: one packet per sample, which the host copies each time. Buffer per step_frame when a core that uses this arrives.
static void lr_audio_sample(int16_t left, int16_t right) {
    int16_t frame[2] = { left, right };
    lr_audio_batch(frame, 1);
}

static void lr_input_poll(void) {} // step_frame already holds this frame's input.

// RetroPad button number to the bridge's mask. The bridge's SOUTH is Nintendo's B, as RetroPad's B is.
static const uint32_t s_retropad[16] = {
    [RETRO_DEVICE_ID_JOYPAD_B] = GAGA_BTN_SOUTH, [RETRO_DEVICE_ID_JOYPAD_Y] = GAGA_BTN_WEST,
    [RETRO_DEVICE_ID_JOYPAD_SELECT] = GAGA_BTN_SELECT, [RETRO_DEVICE_ID_JOYPAD_START] = GAGA_BTN_START,
    [RETRO_DEVICE_ID_JOYPAD_UP] = GAGA_BTN_UP, [RETRO_DEVICE_ID_JOYPAD_DOWN] = GAGA_BTN_DOWN,
    [RETRO_DEVICE_ID_JOYPAD_LEFT] = GAGA_BTN_LEFT, [RETRO_DEVICE_ID_JOYPAD_RIGHT] = GAGA_BTN_RIGHT,
    [RETRO_DEVICE_ID_JOYPAD_A] = GAGA_BTN_EAST, [RETRO_DEVICE_ID_JOYPAD_X] = GAGA_BTN_NORTH,
    [RETRO_DEVICE_ID_JOYPAD_L] = GAGA_BTN_L1, [RETRO_DEVICE_ID_JOYPAD_R] = GAGA_BTN_R1,
    [RETRO_DEVICE_ID_JOYPAD_L2] = GAGA_BTN_L2, [RETRO_DEVICE_ID_JOYPAD_R2] = GAGA_BTN_R2,
    [RETRO_DEVICE_ID_JOYPAD_L3] = GAGA_BTN_L3, [RETRO_DEVICE_ID_JOYPAD_R3] = GAGA_BTN_R3,
};

static int16_t lr_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    LrInstance* a = lr_current();
    if (!a || port >= LR_MAX_PLAYERS) return 0;
    const GagaInputState* input = &a->inputs[port];
    if (device == RETRO_DEVICE_JOYPAD) {
        if (id == RETRO_DEVICE_ID_JOYPAD_MASK) {
            int16_t mask = 0;
            for (unsigned button = 0; button < 16; ++button) {
                if (input->buttons & s_retropad[button]) mask |= (int16_t)(1 << button);
            }
            return mask;
        }
        return id < 16 && (input->buttons & s_retropad[id]) ? 1 : 0;
    }
    if (device == RETRO_DEVICE_ANALOG && id <= RETRO_DEVICE_ID_ANALOG_Y) {
        if (index == RETRO_DEVICE_INDEX_ANALOG_LEFT) return id == RETRO_DEVICE_ID_ANALOG_X ? input->left_x : input->left_y;
        if (index == RETRO_DEVICE_INDEX_ANALOG_RIGHT) return id == RETRO_DEVICE_ID_ANALOG_X ? input->right_x : input->right_y;
    }
    return 0;
}

// MARK: - Battery saves

// Temp file, fsync, rename: a crash leaves the old save or the new one, never half of one.
static bool lr_write_file(const char* path, const void* data, size_t size) {
    char temp[PATH_MAX];
    int written = snprintf(temp, sizeof(temp), "%s.tmp", path);
    if (written < 0 || (size_t)written >= sizeof(temp)) return false;
    int fd = open(temp, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) return false;
    const uint8_t* cursor = data;
    size_t left = size;
    while (left > 0) {
        ssize_t wrote = write(fd, cursor, left);
        if (wrote <= 0) break;
        cursor += wrote;
        left -= (size_t)wrote;
    }
    bool ok = left == 0 && fsync(fd) == 0;
    close(fd);
    if (ok) ok = rename(temp, path) == 0;
    if (!ok) unlink(temp);
    return ok;
}

// The player learns once that progress is not reaching storage. Every later flush still tries.
static void lr_flush(LrInstance* a) {
    for (size_t i = 0; i < 2; ++i) {
        LrBattery* battery = &a->batteries[i];
        const void* memory = battery->written ? retro_get_memory_data(battery->memory_id) : NULL;
        if (!memory || memcmp(battery->written, memory, battery->size) == 0) continue;
        if (lr_write_file(battery->path, memory, battery->size)) {
            memcpy(battery->written, memory, battery->size);
        } else if (!a->save_write_failed) {
            a->save_write_failed = true;
            lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_SAVE, "The save file for this game could not be written.");
        }
    }
}

// Reads <save_dir>/<rom stem>.<extension> into the core's memory, or creates it, so a folder that
// cannot be written refuses the game now and not after the player has made progress.
static bool lr_open_battery(LrInstance* a, LrBattery* battery, unsigned memory_id, const char* extension, const char* rom_path) {
    size_t size = retro_get_memory_size(memory_id);
    uint8_t* memory = retro_get_memory_data(memory_id);
    if (!memory || size == 0) return true;

    const char* slash = strrchr(rom_path, '/');
    const char* name = slash ? slash + 1 : rom_path;
    const char* dot = strrchr(name, '.');
    int stem = dot ? (int)(dot - name) : (int)strlen(name);
    int written = snprintf(battery->path, sizeof(battery->path), "%s/%.*s.%s", a->save_dir, stem, name, extension);
    if (written < 0 || (size_t)written >= sizeof(battery->path)) return false;

    FILE* file = fopen(battery->path, "rb");
    if (file) {
        // A size mismatch is another game's save under this file name. Refuse, so a flush cannot overwrite it.
        bool ok = fseeko(file, 0, SEEK_END) == 0 && (size_t)ftello(file) == size;
        if (ok) {
            rewind(file);
            ok = fread(memory, 1, size, file) == size;
        }
        fclose(file);
        if (!ok) return false;
    } else if (!lr_write_file(battery->path, memory, size)) {
        return false;
    }
    battery->written = malloc(size);
    if (!battery->written) return false;
    memcpy(battery->written, memory, size);
    battery->memory_id = memory_id;
    battery->extension = extension;
    battery->size = size;
    return true;
}

// MARK: - Lifecycle

GagaInstance* gaga_lr_create(const char* system_dir, const char* save_dir) {
    LrInstance* a = calloc(1, sizeof(LrInstance));
    if (!a) return NULL;
    if (!lr_claim(a)) { // Another instance is alive, and this core has one set of globals.
        free(a);
        return NULL;
    }
    if (system_dir) strlcpy(a->system_dir, system_dir, sizeof(a->system_dir));
    if (save_dir) strlcpy(a->save_dir, save_dir, sizeof(a->save_dir));
    a->pixel_format = RETRO_PIXEL_FORMAT_0RGB1555; // libretro's default until the core says otherwise.

    retro_set_environment(lr_environment);
    retro_set_video_refresh(lr_video);
    retro_set_audio_sample(lr_audio_sample);
    retro_set_audio_sample_batch(lr_audio_batch);
    retro_set_input_poll(lr_input_poll);
    retro_set_input_state(lr_input_state);
    retro_init();
    return (GagaInstance*)a;
}

void gaga_lr_destroy(GagaInstance* inst) {
    LrInstance* a = (LrInstance*)inst;
    if (!a) return;
    a->video_cb = NULL;
    a->audio_cb = NULL;
    a->event_cb = NULL;
    if (a->loaded) {
        lr_flush(a);
        retro_cheat_reset();
        retro_unload_game();
    }
    retro_deinit();
    lr_release();
    for (size_t i = 0; i < 2; ++i) free(a->batteries[i].written);
    for (size_t i = 0; i < a->cheat_count; ++i) free(a->cheats[i].code);
    free(a->cheats);
    free(a->opaque);
    free(a);
}

// FNV-1a, for telling ROMs apart, not for security: the host's SHA-256 covers damage to the state file.
static uint64_t lr_hash(const uint8_t* data, size_t size) {
    uint64_t hash = 0xcbf29ce484222325ull;
    for (size_t i = 0; i < size; ++i) hash = (hash ^ data[i]) * 0x100000001b3ull;
    return hash;
}

// Returns the file's bytes, or NULL after a FATAL event.
static uint8_t* lr_read_rom(LrInstance* a, const char* rom_path, size_t* size) {
    FILE* file = fopen(rom_path, "rb");
    if (!file) {
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_ROM, "The game file could not be opened.");
        return NULL;
    }
    off_t length = fseeko(file, 0, SEEK_END) == 0 ? ftello(file) : -1;
    uint8_t* data = NULL;
    if (length > 0 && length <= LR_MAX_ROM_BYTES && fseeko(file, 0, SEEK_SET) == 0 && (data = malloc((size_t)length))) {
        if (fread(data, 1, (size_t)length, file) != (size_t)length) {
            free(data);
            data = NULL;
        }
    }
    fclose(file);
    if (data && (!gaga_libretro_core.is_rom || gaga_libretro_core.is_rom(data, (size_t)length))) {
        *size = (size_t)length;
        return data;
    }
    free(data);
    char message[192];
    snprintf(message, sizeof(message), "This file is not %s.", gaga_libretro_core.game_kind);
    lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_ROM, message);
    return NULL;
}

bool gaga_lr_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    (void)rom_data; // The host passes a path only.
    (void)rom_size;
    LrInstance* a = (LrInstance*)inst;
    if (!a || !rom_path || a->loaded) return false;

    struct retro_system_info system = { 0 };
    retro_get_system_info(&system);
    struct retro_game_info game = { .path = rom_path };
    uint8_t* bytes = NULL;
    if (system.need_fullpath) {
        // shortcut: identifies a state's ROM by file name, because hashing a disc on every load is slow. Hash a sample of the file if renamed games matter.
        a->rom_id = lr_hash((const uint8_t*)rom_path, strlen(rom_path));
    } else {
        size_t size = 0;
        bytes = lr_read_rom(a, rom_path, &size);
        if (!bytes) return false;
        game.data = bytes;
        game.size = size;
        a->rom_id = lr_hash(bytes, size);
    }

    bool loaded = retro_load_game(&game);
    free(bytes); // libretro lets a core keep the pointer only through this call.
    if (!loaded) {
        char message[192];
        snprintf(message, sizeof(message), "%s could not load this game.", gaga_libretro_core.name);
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_ROM, message);
        return false;
    }

    // Refuse to run rather than let a player lose progress to a save that never reaches disk.
    if (!lr_open_battery(a, &a->batteries[0], RETRO_MEMORY_SAVE_RAM, "sav", rom_path) ||
        !lr_open_battery(a, &a->batteries[1], RETRO_MEMORY_RTC, "rtc", rom_path)) {
        retro_unload_game();
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_SAVE, "The save file for this game could not be opened.");
        return false;
    }

    struct retro_system_av_info av = { 0 };
    retro_get_system_av_info(&av);
    a->sample_rate = (uint32_t)lround(av.timing.sample_rate);
    a->loaded = true;
    return true;
}

void gaga_lr_reset(GagaInstance* inst) {
    LrInstance* a = (LrInstance*)inst;
    if (a && a->loaded) retro_reset();
}

// The host's timer sets the pace, and fast-forward calls this several times in a tick. retro_run runs
// exactly one frame and keeps nothing from one call to the next that this adapter has to reset.
void gaga_lr_step_frame(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count) {
    LrInstance* a = (LrInstance*)inst;
    if (!a || !a->loaded) return;
    memset(a->inputs, 0, sizeof(a->inputs));
    if (inputs) memcpy(a->inputs, inputs, sizeof(GagaInputState) * (player_count < LR_MAX_PLAYERS ? player_count : LR_MAX_PLAYERS));
    retro_run();
    if (++a->frames_since_flush >= LR_FLUSH_INTERVAL_FRAMES) {
        a->frames_since_flush = 0;
        lr_flush(a);
    }
}

bool gaga_lr_attach_metal_layer(GagaInstance* inst, void* layer) {
    (void)inst;
    (void)layer;
    return false;
}

void gaga_lr_set_video_callback(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor*, void*), void* userdata) {
    LrInstance* a = (LrInstance*)inst;
    if (!a) return;
    a->video_cb = cb;
    a->video_userdata = userdata;
}

void gaga_lr_set_audio_callback(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor*, void*), void* userdata) {
    LrInstance* a = (LrInstance*)inst;
    if (!a) return;
    a->audio_cb = cb;
    a->audio_userdata = userdata;
}

void gaga_lr_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata) {
    LrInstance* a = (LrInstance*)inst;
    if (!a) return;
    a->event_cb = cb;
    a->event_userdata = userdata;
}

// Nothing runs between step_frame calls, so there is nothing to stop or restart.
void gaga_lr_pause(GagaInstance* inst) { (void)inst; }
void gaga_lr_resume(GagaInstance* inst) { (void)inst; }

void gaga_lr_flush_battery_save(GagaInstance* inst) {
    LrInstance* a = (LrInstance*)inst;
    if (a && a->loaded) lr_flush(a);
}

// MARK: - Save states

size_t gaga_lr_state_size(GagaInstance* inst) {
    LrInstance* a = (LrInstance*)inst;
    if (!a || !a->loaded) return 0;
    size_t payload = retro_serialize_size();
    return payload > 0 ? sizeof(LrStateHeader) + payload : 0;
}

bool gaga_lr_save_state(GagaInstance* inst, void* buffer, size_t size) {
    LrInstance* a = (LrInstance*)inst;
    size_t payload = a && a->loaded ? retro_serialize_size() : 0;
    if (payload == 0 || !buffer || size != sizeof(LrStateHeader) + payload) return false;
    LrStateHeader header = { .payload_size = (uint32_t)payload, .rom_id = a->rom_id };
    memcpy(header.magic, LR_STATE_MAGIC, sizeof(header.magic));
    memcpy(buffer, &header, sizeof(header));
    return retro_serialize((uint8_t*)buffer + sizeof(header), payload);
}

// A core may overwrite its memory before it finds a state is bad, so it gets a snapshot to go back to.
bool gaga_lr_load_state(GagaInstance* inst, const void* buffer, size_t size, char* error, size_t error_capacity) {
    LrInstance* a = (LrInstance*)inst;
    size_t payload = a && a->loaded ? retro_serialize_size() : 0;
    const char* name = gaga_libretro_core.name;
    LrStateHeader header;
    if (payload == 0 || !buffer || size != sizeof(header) + payload) {
        lr_error(error, error_capacity, "This save state is the wrong size for %s.", name);
        return false;
    }
    memcpy(&header, buffer, sizeof(header));
    if (memcmp(header.magic, LR_STATE_MAGIC, sizeof(header.magic)) != 0 || header.payload_size != payload || header.rom_id != a->rom_id) {
        lr_error(error, error_capacity, "This save state belongs to another game or another version of this game.", NULL);
        return false;
    }
    void* snapshot = malloc(payload);
    if (!snapshot || !retro_serialize(snapshot, payload)) {
        free(snapshot);
        lr_error(error, error_capacity, "%s could not load this save state.", name);
        return false;
    }
    bool loaded = retro_unserialize((const uint8_t*)buffer + sizeof(header), payload);
    if (!loaded) {
        retro_unserialize(snapshot, payload);
        lr_error(error, error_capacity, "%s could not load this save state.", name);
    }
    free(snapshot);
    return loaded;
}

// MARK: - Cheats

// libretro has no remove: the only way to take a code back is to reset and set the rest again.
// Each line gets its own index, so a core that picks a format per index can mix formats in one cheat.
static void lr_apply_cheats(LrInstance* a) {
    retro_cheat_reset();
    unsigned index = 0;
    for (size_t i = 0; i < a->cheat_count; ++i) {
        if (!a->cheats[i].enabled) continue;
        char* copy = strdup(a->cheats[i].code);
        char* cursor = NULL;
        for (char* line = copy ? strtok_r(copy, "\r\n", &cursor) : NULL; line; line = strtok_r(NULL, "\r\n", &cursor)) {
            retro_cheat_set(index++, true, line);
        }
        free(copy);
    }
}

static LrCheat* lr_find_cheat(LrInstance* a, uint32_t id) {
    for (size_t i = 0; i < a->cheat_count; ++i) {
        if (a->cheats[i].id == id) return &a->cheats[i];
    }
    return NULL;
}

// Whole lines only: leading and trailing spaces go, and blank lines drop out.
static char* lr_clean_cheat(const char* code, char* error, size_t error_capacity) {
    char* copy = strdup(code);
    char* clean = calloc(strlen(code) + 2, 1);
    char* cursor = NULL;
    bool valid = copy && clean;
    size_t lines = 0;
    for (char* line = valid ? strtok_r(copy, "\r\n", &cursor) : NULL; line && valid; line = strtok_r(NULL, "\r\n", &cursor)) {
        while (*line == ' ' || *line == '\t') ++line;
        size_t length = strlen(line);
        while (length > 0 && (line[length - 1] == ' ' || line[length - 1] == '\t')) line[--length] = '\0';
        if (length == 0) continue;
        if (!gaga_libretro_core.is_cheat || !gaga_libretro_core.is_cheat(line)) {
            valid = false;
            if (error && error_capacity > 0) snprintf(error, error_capacity, "%s does not recognise this code: %.32s", gaga_libretro_core.name, line);
            break;
        }
        strcat(clean, line);
        strcat(clean, "\n");
        ++lines;
    }
    free(copy);
    if (valid && lines == 0) {
        valid = false;
        lr_error(error, error_capacity, "Enter a cheat code.", NULL);
    }
    if (!valid) {
        free(clean);
        return NULL;
    }
    return clean;
}

bool gaga_lr_cheat_add(GagaInstance* inst, uint32_t id, const char* code, bool enabled, char* error, size_t error_capacity) {
    LrInstance* a = (LrInstance*)inst;
    if (!a || !code) return false;
    char* clean = lr_clean_cheat(code, error, error_capacity);
    if (!clean) return false;
    LrCheat* cheat = lr_find_cheat(a, id);
    if (!cheat) {
        LrCheat* grown = realloc(a->cheats, (a->cheat_count + 1) * sizeof(LrCheat));
        if (!grown) {
            free(clean);
            return false;
        }
        a->cheats = grown;
        cheat = &a->cheats[a->cheat_count++];
        cheat->code = NULL;
    }
    free(cheat->code);
    *cheat = (LrCheat){ .id = id, .enabled = enabled, .code = clean };
    lr_apply_cheats(a);
    return true;
}

void gaga_lr_cheat_remove(GagaInstance* inst, uint32_t id) {
    LrInstance* a = (LrInstance*)inst;
    LrCheat* cheat = a ? lr_find_cheat(a, id) : NULL;
    if (!cheat) return;
    free(cheat->code);
    *cheat = a->cheats[--a->cheat_count];
    lr_apply_cheats(a);
}

void gaga_lr_cheat_set_enabled(GagaInstance* inst, uint32_t id, bool enabled) {
    LrInstance* a = (LrInstance*)inst;
    LrCheat* cheat = a ? lr_find_cheat(a, id) : NULL;
    if (!cheat) return;
    cheat->enabled = enabled;
    lr_apply_cheats(a);
}

// MARK: - Self-test

// Brings the core up and down with no game, which proves the framework loaded and links. While a game
// is running the core is plainly up, and retro_init must not touch its globals, so only the API is checked.
bool gaga_lr_self_test(char* error, size_t error_capacity) {
    bool api = retro_api_version() == RETRO_API_VERSION;
    if (api && lr_claim(&s_probe)) {
        retro_set_environment(lr_environment);
        retro_init();
        retro_deinit();
        lr_release();
    }
    if (!api) lr_error(error, error_capacity, "%s was built for another libretro version.", gaga_libretro_core.name);
    return api;
}
