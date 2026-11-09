// PrBoom (Doom, Heretic, Hexen engine) behind the GagaBridge interface, through the shared libretro adapter. The game
// WAD is the player's: no IWAD is bundled. PrBoom's own engine lumps (prboom.wad, GPL) are compiled into upstream's
// d_main.c. A PWAD looks for its IWAD (doom2.wad, freedoom2.wad and so on) in its own folder and the system folder.
// Savegames and prboom.cfg go to <save directory>/<game name>/, written by upstream.
#include "LibretroAdapter.h"
#include "libretro.h"
#include <ctype.h>
#include <string.h>

// Every option upstream defines (libretro_core_options.h), at upstream's default unless marked. GagaEmu's changes: no
// IWAD search up through parent folders, audio at the app's 48 kHz.
static const GagaLibretroVariable s_variables[] = {
    { "prboom-resolution", "320x200" },
    { "prboom-render_threads", "OFF" }, // Built without HAVE_THREADS, so this has no effect.
    { "prboom-color_format", "16bits" },
    { "prboom-hdr_emissive", "2x" },
    { "prboom-mouse_on", "disabled" },
    { "prboom-wall_decals", "disabled" },
    { "prboom-dynlight_wall_falloff", "disabled" },
    { "prboom-find_recursive_on", "disabled" }, // GagaEmu
    { "prboom-rumble", "disabled" },
    { "prboom-mmap_wads", "disabled" },
    { "prboom-analog_deadzone", "15" },
    { "prboom-purge_limit", "16" },
    { "prboom-complevel", "-1" },
    { "prboom-sound_samplerate", "48000" }, // GagaEmu
    { NULL, NULL },
};

// Upstream types the word into Doom's own cheat reader. A second typing switches iddqd back off, and the adapter sends
// every enabled cheat again on each change, so each word is typed once per game. Upstream cannot take one back.
#define PRBOOM_MAX_CHEATS 32
static char s_typed[PRBOOM_MAX_CHEATS][16];
static unsigned s_typed_count;

static bool prboom_is_cheat(const char* line) {
    size_t length = strlen(line);
    if (length < 3 || length >= sizeof(s_typed[0]) || strncmp(line, "id", 2) != 0) return false;
    for (const char* c = line; *c; ++c) {
        if (!islower((unsigned char)*c) && !isdigit((unsigned char)*c)) return false;
    }
    return true;
}

static void prboom_cheat_reset(void) {}

static void prboom_cheat_set(unsigned index, bool enabled, const char* code) {
    for (unsigned i = 0; i < s_typed_count; ++i) {
        if (strcmp(s_typed[i], code) == 0) return;
    }
    if (s_typed_count == PRBOOM_MAX_CHEATS) return;
    strcpy(s_typed[s_typed_count++], code); // prboom_is_cheat bounds the length.
    retro_cheat_set(index, enabled, code);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "PrBoom",
    .game_kind = "a Doom WAD",
    .variables = s_variables,
    .is_cheat = prboom_is_cheat,
    .cheat_reset = prboom_cheat_reset,
    .cheat_set = prboom_cheat_set,
};

// The shared adapter names no device for the port; this is upstream's own fallback, the classic RetroPad layout.
static bool prboom_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    s_typed_count = 0;
    retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    return gaga_lr_load_rom(inst, rom_path, rom_data, rom_size);
}

const GagaCoreInterface* Prboom_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .load_rom = prboom_load_rom,
        .core_id = "prboom",
        .core_name = "PrBoom",
        .core_version = GAGA_CORE_VERSION,
        // Upstream also takes .iwad, .pwad, .lmp (demos), .pk3, .ipk3, .m3u (taken by disc platforms here) and .zip.
        .supported_extensions = "wad",
        .target_fps = 60.0,             // PrBoom's "uncapped_framerate" default (3); 35 Hz is the original tic rate.
        .native_sample_rate = 48000,    // prboom-sound_samplerate above.
        .state_version = 1,
    };
    return &interface;
}
