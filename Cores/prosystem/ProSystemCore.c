// ProSystem (Atari 7800) behind the GagaBridge interface, through the shared libretro adapter. The 7800 BIOS is
// optional: upstream looks for "7800 BIOS (U).rom" (or "(E)" for PAL carts) in the system directory and boots the
// cart directly without it. Upstream's libretro target has no cheats and no battery memory.
#include "LibretroAdapter.h"

// Option values are upstream's spelling (libretro_core_options.h).
static const GagaLibretroVariable s_variables[] = {
    { "prosystem_color_depth", "16bit" },
    { "prosystem_low_pass_filter", "disabled" },
    { "prosystem_low_pass_range", "60" },
    { "prosystem_gamepad_dual_stick_hack", "disabled" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "ProSystem",
    .game_kind = "an Atari 7800 game",
    .variables = s_variables,
};

const GagaCoreInterface* ProSystem_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "prosystem",
        .core_name = "ProSystem",
        .core_version = GAGA_CORE_VERSION,
        // Upstream also takes .bin and .cdf. A .bin is placed by content elsewhere, and .cdf names loose files.
        .supported_extensions = "a78",
        .target_fps = 60.0,             // NTSC. A PAL cart reports 50 through its av info.
        .native_sample_rate = 31440,    // 60 frames * 262 lines * 2 samples per line.
        .state_version = 1,
    };
    return &interface;
}
