// DOSBox Pure behind the GagaBridge interface, through the shared libretro adapter.
// Software video only, interpreter CPU cores only, no network. The content is mounted as C: and runs at
// once when it is an .exe, .com or .bat. Files the program writes go to <save dir>/<content>.pure.zip.
#include "LibretroAdapter.h"

#include <stdio.h>

// GagaDosboxPure.cpp, built with upstream's static state.
void gaga_dbp_forget_content(void);
bool gaga_dbp_save_drives(void);

// Option values are upstream's spelling (core_options.h).
static const GagaLibretroVariable s_variables[] = {
    { "dosbox_pure_cpu_core", "normal" },  // An interpreter. DISABLE_DYNAREC leaves no other choice but simple.
    { "dosbox_pure_voodoo_perf", "1" },    // Software 3dfx. "auto" and "4" would ask for an OpenGL context.
    { "dosbox_pure_force60fps", "true" },  // DOS modes run at 70 Hz. The host paces 60 frames a second.
    { "dosbox_pure_audiorate", "48000" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "DOSBox Pure",
    .game_kind = "a DOS program",
    .variables = s_variables,
    .save_battery = gaga_dbp_save_drives,
};

// DOSBox Pure boots to its own start menu when the content is missing, so the missing file is reported here.
static void (*s_event_cb)(GagaEventSeverity, int32_t, const char*, void*);
static void* s_event_userdata;

static void dbp_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata) {
    s_event_cb = cb;
    s_event_userdata = userdata;
    gaga_lr_set_event_callback(inst, cb, userdata);
}

static bool dbp_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    FILE* file = rom_path ? fopen(rom_path, "rb") : NULL;
    if (!file) {
        if (inst && s_event_cb) s_event_cb(GAGA_EVENT_FATAL, 1, "The game file could not be opened.", s_event_userdata);
        return false;
    }
    fclose(file);
    gaga_dbp_forget_content();
    return gaga_lr_load_rom(inst, rom_path, rom_data, rom_size);
}

const GagaCoreInterface* DosboxPure_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .load_rom = dbp_load_rom,
        .set_event_callback = dbp_set_event_callback,
        .core_id = "dosbox_pure",
        .core_name = "DOSBox Pure",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "zip|dosz|exe|com|bat|iso|cue",
        .target_fps = 60.0,           // dosbox_pure_force60fps.
        .native_sample_rate = 48000,  // dosbox_pure_audiorate.
        .state_version = 8,           // DBPSerialize_All's version, after the 0xD05B5747 magic. A test checks real bytes.
    };
    return &interface;
}
