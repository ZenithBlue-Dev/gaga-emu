// DOSBox Pure behind the GagaBridge interface, through the shared libretro adapter.
// Software video only, interpreter CPU cores only, no network. The content is mounted as C: and runs at
// once when it is an .exe, .com or .bat. Where the program's own files go:
// - ZIP or DOSZ content: <save dir>/<content>.pure.zip, upstream's save file over the read-only archive.
// - A loose .exe, .com, .bat or .conf: upstream mounts the file's folder as a writable C:, which in the app
//   is the ROM folder with every other game in it. So the file is copied to <save dir>/DOS/<file name>/
//   and runs from there: that folder is its C:, and what it writes stays there.
#include "LibretroAdapter.h"

#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>

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
static char s_save_dir[PATH_MAX];

static void dbp_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata) {
    s_event_cb = cb;
    s_event_userdata = userdata;
    gaga_lr_set_event_callback(inst, cb, userdata);
}

static GagaInstance* dbp_create(const char* system_dir, const char* save_dir) {
    GagaInstance* inst = gaga_lr_create(system_dir, save_dir);
    if (inst) strlcpy(s_save_dir, save_dir ? save_dir : "", sizeof(s_save_dir));
    return inst;
}

static void dbp_fatal(GagaInstance* inst, const char* message) {
    if (inst && s_event_cb) s_event_cb(GAGA_EVENT_FATAL, 1, message, s_event_userdata);
}

// Upstream mounts these by their folder (DBP_Mount, "path or executable file").
static bool dbp_runs_from_its_folder(const char* path) {
    const char* dot = strrchr(path, '.');
    if (!dot || strchr(dot, '/')) return false;
    return !strcasecmp(dot, ".exe") || !strcasecmp(dot, ".com") || !strcasecmp(dot, ".bat") || !strcasecmp(dot, ".conf");
}

// Copies rom_path to <save dir>/DOS/<file name>/<file name> by temp file and rename, and puts that path in
// out. Files the program wrote there before are kept.
static bool dbp_copy_to_drive_c(const char* rom_path, char* out, size_t out_size) {
    const char* slash = strrchr(rom_path, '/');
    const char* name = slash ? slash + 1 : rom_path;
    char dir[PATH_MAX], temp[PATH_MAX];
    if (!s_save_dir[0] || snprintf(dir, sizeof(dir), "%s/DOS", s_save_dir) >= (int)sizeof(dir)) return false;
    mkdir(dir, 0755);
    if (strlcat(dir, "/", sizeof(dir)) >= sizeof(dir) || strlcat(dir, name, sizeof(dir)) >= sizeof(dir)) return false;
    mkdir(dir, 0755);
    if (snprintf(out, out_size, "%s/%s", dir, name) >= (int)out_size) return false;
    if (snprintf(temp, sizeof(temp), "%s.tmp", out) >= (int)sizeof(temp)) return false;

    FILE* from = fopen(rom_path, "rb");
    FILE* to = from ? fopen(temp, "wb") : NULL;
    bool ok = from && to;
    char buffer[65536];
    for (size_t got; ok && (got = fread(buffer, 1, sizeof(buffer), from)) > 0;) ok = fwrite(buffer, 1, got, to) == got;
    if (from && ferror(from)) ok = false;
    if (from) fclose(from);
    if (to && fclose(to) != 0) ok = false;
    if (ok) ok = rename(temp, out) == 0;
    if (!ok) remove(temp);
    return ok;
}

static bool dbp_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    FILE* file = rom_path ? fopen(rom_path, "rb") : NULL;
    if (!file) {
        dbp_fatal(inst, "The game file could not be opened.");
        return false;
    }
    fclose(file);
    char drive_c_path[PATH_MAX];
    if (dbp_runs_from_its_folder(rom_path)) {
        if (!dbp_copy_to_drive_c(rom_path, drive_c_path, sizeof(drive_c_path))) {
            dbp_fatal(inst, "The DOS program could not be copied to its own drive C: folder.");
            return false;
        }
        rom_path = drive_c_path;
    }
    gaga_dbp_forget_content();
    return gaga_lr_load_rom(inst, rom_path, rom_data, rom_size);
}

const GagaCoreInterface* DosboxPure_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .create = dbp_create,
        .load_rom = dbp_load_rom,
        .set_event_callback = dbp_set_event_callback,
        .core_id = "dosbox_pure",
        .core_name = "DOSBox Pure",
        .core_version = GAGA_CORE_VERSION,
        // Upstream's valid_extensions, less "/" (a folder): the app imports files.
        .supported_extensions = "zip|dosz|exe|com|bat|iso|chd|cue|ins|img|ima|vhd|jrc|m3u|m3u8|conf",
        .target_fps = 60.0,           // dosbox_pure_force60fps.
        .native_sample_rate = 48000,  // dosbox_pure_audiorate.
        .state_version = 8,           // DBPSerialize_All's version, after the 0xD05B5747 magic. A test checks real bytes.
    };
    return &interface;
}
