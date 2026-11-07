// See LibretroAdapter.h. Every retro_* call happens on the host's one serial queue, so every libretro
// callback fires there too, inside a host call, and hands the host only pointers valid for that call.
#include "LibretroAdapter.h"
#ifdef GAGA_LIBRETRO_VULKAN
#include "LibretroVulkan.h" // Vulkan hardware rendering: every call into it sits under this define.
#endif

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
    retro_keyboard_event_t keyboard_cb;
    uint8_t keys_sent[32]; // Player 1's keys as keyboard_cb last heard them.
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
    case RETRO_ENVIRONMENT_SET_VARIABLES:
        return true; // Values come from the table above, but melonDS DS reads none until this succeeds.
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
    case RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK:
        a->keyboard_cb = ((const struct retro_keyboard_callback*)data)->callback;
        return true;
    default:
#ifdef GAGA_LIBRETRO_VULKAN
        return lr_vk_environment(command, data);
#else
        return false; // No rumble, messages, VFS, core options UI, hardware rendering or other frontend extras.
#endif
    }
}

#ifdef GAGA_LIBRETRO_VULKAN
void gaga_lr_report_fatal(const char* message) {
    LrInstance* a = lr_current();
    if (a) lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_VIDEO, message);
}
#endif

// MARK: - Video, audio, input

static void lr_video(const void* data, unsigned width, unsigned height, size_t pitch) {
    LrInstance* a = lr_current();
    if (!a) return;
#ifdef GAGA_LIBRETRO_VULKAN
    if (lr_vk_requested()) { // The frame goes to the layer. The host hears only its size.
        if (lr_vk_present(width, height, data != RETRO_HW_FRAME_BUFFER_VALID) && a->video_cb) {
            GagaFrameDescriptor sized = { .width = width, .height = height, .pixel_format = GAGA_PIXEL_FORMAT_XRGB8888 };
            a->video_cb(&sized, a->video_userdata);
        }
        return;
    }
#endif
    if (!data) return;
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

// USB HID keyboard usage (GagaInputState.keys) to libretro's key code. 0 for a key libretro has no name for.
static unsigned lr_retrok(unsigned usage) {
    if (usage >= 0x04 && usage <= 0x1D) return RETROK_a + (usage - 0x04);
    if (usage >= 0x1E && usage <= 0x26) return RETROK_1 + (usage - 0x1E);
    if (usage >= 0x3A && usage <= 0x45) return RETROK_F1 + (usage - 0x3A);
    if (usage >= 0x59 && usage <= 0x61) return RETROK_KP1 + (usage - 0x59);
    static const uint16_t named[256] = {
        [0x27] = RETROK_0, [0x28] = RETROK_RETURN, [0x29] = RETROK_ESCAPE, [0x2A] = RETROK_BACKSPACE,
        [0x2B] = RETROK_TAB, [0x2C] = RETROK_SPACE, [0x2D] = RETROK_MINUS, [0x2E] = RETROK_EQUALS,
        [0x2F] = RETROK_LEFTBRACKET, [0x30] = RETROK_RIGHTBRACKET, [0x31] = RETROK_BACKSLASH,
        [0x32] = RETROK_BACKSLASH, [0x33] = RETROK_SEMICOLON, [0x34] = RETROK_QUOTE, [0x35] = RETROK_BACKQUOTE,
        [0x36] = RETROK_COMMA, [0x37] = RETROK_PERIOD, [0x38] = RETROK_SLASH, [0x39] = RETROK_CAPSLOCK,
        [0x46] = RETROK_PRINT, [0x47] = RETROK_SCROLLOCK, [0x48] = RETROK_PAUSE, [0x49] = RETROK_INSERT,
        [0x4A] = RETROK_HOME, [0x4B] = RETROK_PAGEUP, [0x4C] = RETROK_DELETE, [0x4D] = RETROK_END,
        [0x4E] = RETROK_PAGEDOWN, [0x4F] = RETROK_RIGHT, [0x50] = RETROK_LEFT, [0x51] = RETROK_DOWN,
        [0x52] = RETROK_UP, [0x53] = RETROK_NUMLOCK, [0x54] = RETROK_KP_DIVIDE, [0x55] = RETROK_KP_MULTIPLY,
        [0x56] = RETROK_KP_MINUS, [0x57] = RETROK_KP_PLUS, [0x58] = RETROK_KP_ENTER, [0x62] = RETROK_KP0,
        [0x63] = RETROK_KP_PERIOD, [0x64] = RETROK_LESS, [0x65] = RETROK_MENU,
        [0xE0] = RETROK_LCTRL, [0xE1] = RETROK_LSHIFT, [0xE2] = RETROK_LALT, [0xE3] = RETROK_LSUPER,
        [0xE4] = RETROK_RCTRL, [0xE5] = RETROK_RSHIFT, [0xE6] = RETROK_RALT, [0xE7] = RETROK_RSUPER,
    };
    return usage < 256 ? named[usage] : 0;
}

static bool lr_key_held(const uint8_t keys[32], unsigned usage) { return keys[usage >> 3] & (1u << (usage & 7)); }

// Tells a core that registered a keyboard callback which keys changed since the last frame.
static void lr_send_keys(LrInstance* a) {
    const uint8_t* keys = a->inputs[0].keys;
    if (!a->keyboard_cb || memcmp(keys, a->keys_sent, sizeof(a->keys_sent)) == 0) return;
    uint16_t modifiers = 0;
    if (lr_key_held(keys, 0xE1) || lr_key_held(keys, 0xE5)) modifiers |= RETROKMOD_SHIFT;
    if (lr_key_held(keys, 0xE0) || lr_key_held(keys, 0xE4)) modifiers |= RETROKMOD_CTRL;
    if (lr_key_held(keys, 0xE2) || lr_key_held(keys, 0xE6)) modifiers |= RETROKMOD_ALT;
    if (lr_key_held(keys, 0xE3) || lr_key_held(keys, 0xE7)) modifiers |= RETROKMOD_META;
    for (unsigned usage = 0; usage < 256; ++usage) {
        bool down = lr_key_held(keys, usage);
        if (down == lr_key_held(a->keys_sent, usage)) continue;
        unsigned code = lr_retrok(usage);
        if (code) a->keyboard_cb(down, code, 0, modifiers);
    }
    memcpy(a->keys_sent, keys, sizeof(a->keys_sent));
}

static int16_t lr_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    LrInstance* a = lr_current();
    if (!a || port >= LR_MAX_PLAYERS) return 0;
    const GagaInputState* input = &a->inputs[port];
    if (device == RETRO_DEVICE_KEYBOARD) {
        for (unsigned usage = 0; port == 0 && id && usage < 256; ++usage) {
            if (lr_retrok(usage) == id && lr_key_held(input->keys, usage)) return 1;
        }
        return 0;
    }
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
    if (device == RETRO_DEVICE_POINTER && index == 0) { // One finger, already in libretro's pointer scale.
        if (id == RETRO_DEVICE_ID_POINTER_X) return input->pointer_x;
        if (id == RETRO_DEVICE_ID_POINTER_Y) return input->pointer_y;
        if (id == RETRO_DEVICE_ID_POINTER_PRESSED) return input->pointer_down ? 1 : 0;
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
    bool ok = !gaga_libretro_core.save_battery || gaga_libretro_core.save_battery();
    for (size_t i = 0; i < 2; ++i) {
        LrBattery* battery = &a->batteries[i];
        const void* memory = battery->written ? retro_get_memory_data(battery->memory_id) : NULL;
        if (!memory || memcmp(battery->written, memory, battery->size) == 0) continue;
        if (lr_write_file(battery->path, memory, battery->size)) {
            memcpy(battery->written, memory, battery->size);
        } else {
            ok = false;
        }
    }
    if (!ok && !a->save_write_failed) {
        a->save_write_failed = true;
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_SAVE, "The save file for this game could not be written.");
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
#ifdef GAGA_LIBRETRO_VULKAN
        lr_vk_destroy_context(); // libretro order: context_destroy, unload, then the device.
        retro_unload_game();
        lr_vk_release();
#else
        retro_unload_game();
#endif
    }
    retro_deinit();
    if (gaga_libretro_core.after_deinit) gaga_libretro_core.after_deinit();
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
    const char* refusal = gaga_libretro_core.refuse_load ? gaga_libretro_core.refuse_load(a->system_dir, rom_path) : NULL;
    if (refusal) {
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_ROM, refusal);
        return false;
    }

    struct retro_system_info system = { 0 };
    retro_get_system_info(&system);
    struct retro_game_info game = { .path = rom_path };
    uint8_t* bytes = NULL;
    if (system.need_fullpath && !gaga_libretro_core.is_rom) {
        // shortcut: identifies a state's ROM by file name, because hashing a disc on every load is slow. Hash a sample of the file if renamed games matter.
        a->rom_id = lr_hash((const uint8_t*)rom_path, strlen(rom_path));
    } else {
        size_t size = 0;
        bytes = lr_read_rom(a, rom_path, &size);
        if (!bytes) return false;
        if (!system.need_fullpath) {
            game.data = bytes;
            game.size = size;
        }
        a->rom_id = lr_hash(bytes, size);
    }

    bool loaded = retro_load_game(&game);
    free(bytes); // libretro lets a core keep the pointer only through this call.
    if (!loaded) {
#ifdef GAGA_LIBRETRO_VULKAN
        lr_vk_release(); // Forgets a context the core asked for before it failed.
#endif
        char message[192];
        snprintf(message, sizeof(message), "%s could not load this game.", gaga_libretro_core.name);
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_ROM, message);
        return false;
    }
    if (gaga_libretro_core.finish_load) gaga_libretro_core.finish_load();

    // Refuse to run rather than let a player lose progress to a save that never reaches disk.
    if (!lr_open_battery(a, &a->batteries[0], RETRO_MEMORY_SAVE_RAM, "sav", rom_path) ||
        !lr_open_battery(a, &a->batteries[1], RETRO_MEMORY_RTC, "rtc", rom_path) ||
        (gaga_libretro_core.save_battery && !gaga_libretro_core.save_battery())) {
        retro_unload_game();
#ifdef GAGA_LIBRETRO_VULKAN
        lr_vk_release();
#endif
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_SAVE, "The save file for this game could not be opened.");
        return false;
    }

    // Nestopia fixes its state size on the first call, and its state is longer in the first frames after
    // power on. Asking before any frame runs gives every session of a game the same size.
    (void)retro_serialize_size();

    struct retro_system_av_info av = { 0 };
    retro_get_system_av_info(&av);
    a->sample_rate = (uint32_t)lround(av.timing.sample_rate);
#ifdef GAGA_LIBRETRO_VULKAN
    // libretro brings the context up after retro_load_game returns and before the first retro_run.
    char vk_error[160] = "The 3D renderer could not start.";
    if (lr_vk_requested() && !lr_vk_create_context(vk_error, sizeof(vk_error))) {
        lr_vk_destroy_context();
        retro_unload_game();
        lr_vk_release();
        lr_emit(a, GAGA_EVENT_FATAL, LR_EVENT_BAD_VIDEO, vk_error);
        return false;
    }
#endif
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
    lr_send_keys(a);
    retro_run();
    if (++a->frames_since_flush >= LR_FLUSH_INTERVAL_FRAMES) {
        a->frames_since_flush = 0;
        lr_flush(a);
    }
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

// Nothing runs between step_frame calls, so there is nothing to stop or restart. A Vulkan core's last
// frame may still be on the GPU, which must be idle before the app leaves the foreground.
void gaga_lr_pause(GagaInstance* inst) {
    (void)inst;
#ifdef GAGA_LIBRETRO_VULKAN
    lr_vk_wait_idle();
#endif
}
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
        if (copy && gaga_libretro_core.cheat_lines_are_one_code) {
            for (char* c = copy; *c; ++c) {
                if (*c == '\n') *c = c[1] ? '+' : '\0'; // Cleaned codes end with a newline.
            }
        }
        char* cursor = NULL;
        for (char* line = copy ? strtok_r(copy, "\r\n", &cursor) : NULL; line; line = strtok_r(NULL, "\r\n", &cursor)) {
            if (gaga_libretro_core.unapply_cheats) gaga_libretro_core.unapply_cheats();
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
        if (gaga_libretro_core.after_deinit) gaga_libretro_core.after_deinit();
        lr_release();
    }
    if (!api) lr_error(error, error_capacity, "%s was built for another libretro version.", gaga_libretro_core.name);
    return api;
}
