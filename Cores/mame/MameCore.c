// MAME behind the GagaBridge interface, through the shared libretro adapter. Arcade ROM sets as MAME reads
// them: one zip or 7z per machine, named after its short name, with any parent or BIOS set beside it in the
// same folder. Only the machines in drivers.flt are listed (docs/03 section 5).
#include "LibretroAdapter.h"

#include <string.h>

bool gaga_mame_save_battery(void); // MameSupport.cpp
void gaga_mame_after_deinit(void);
const char* gaga_mame_refuse_load(const char* system_dir, const char* rom_path);

// Option values are upstream's spelling (libretro_core_options.h). MAME runs on the host's queue alone
// (no work-queue threads), reads no ini file, and rotates vertical games itself, because the adapter
// does not answer SET_ROTATION. Software lists and the mouse are console and computer features.
static const GagaLibretroVariable s_variables[] = {
    { "mame_thread_mode", "disabled" },
    { "mame_cheats_enable", "disabled" },
    { "mame_throttle", "disabled" },
    { "mame_boot_to_bios", "disabled" },
    { "mame_boot_to_osd", "disabled" },
    { "mame_read_config", "disabled" },
    { "mame_write_config", "disabled" },
    { "mame_mame_paths_enable", "disabled" },
    { "mame_auto_save", "disabled" },
    { "mame_softlists_enable", "disabled" },
    { "mame_media_type", "rom" }, // Start the set as a machine. Unset, upstream passes the folder's name as one.
    { "mame_mouse_enable", "disabled" },
    { "mame_lightgun_mode", "none" },
    { "mame_rotation_mode", "internal" },
    { "mame_alternate_renderer", "disabled" },
    { "mame_autoloadfastforward", "disabled" },
    { NULL, NULL },
};

// A zip or 7z archive. Upstream also takes .cmd files, which hold a MAME command line; those are refused,
// so no option reaches MAME that this file does not set.
static bool mame_is_rom(const uint8_t* data, size_t size) {
    static const uint8_t zip[] = { 'P', 'K', 3, 4 };
    static const uint8_t sevenzip[] = { '7', 'z', 0xBC, 0xAF, 0x27, 0x1C };
    return (size >= sizeof(zip) && memcmp(data, zip, sizeof(zip)) == 0)
        || (size >= sizeof(sevenzip) && memcmp(data, sevenzip, sizeof(sevenzip)) == 0);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "MAME",
    .game_kind = "a MAME ROM set (a .zip named after the machine) for a machine in this build",
    .variables = s_variables,
    .is_rom = mame_is_rom,
    .save_battery = gaga_mame_save_battery,
    .after_deinit = gaga_mame_after_deinit,
    .refuse_load = gaga_mame_refuse_load,
};

// No cheats: upstream's retro_cheat_set does nothing, and MAME's own cheat engine reads cheat.dat files.
const GagaCoreInterface* Mame_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "mame",
        .core_name = "MAME",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "zip|7z",
        // shortcut: one rate per core. MAME reports each machine's own rate through SET_SYSTEM_AV_INFO.
        .target_fps = 60.0,          // retro_fps in upstream's libretro.cpp, before a machine starts.
        .native_sample_rate = 48000, // sample_rate in upstream's libretro.cpp.
        .state_version = 2,          // SAVE_VERSION in upstream/src/emu/save.cpp, byte 8 of MAME's state.
    };
    return &interface;
}
