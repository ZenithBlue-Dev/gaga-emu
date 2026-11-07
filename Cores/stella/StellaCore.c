// Stella (Atari 2600) behind the GagaBridge interface, through the shared libretro adapter. The 2600 has no
// BIOS. Upstream's libretro target has no cheats and no battery memory.
#include "LibretroAdapter.h"

// Option values are upstream's spelling (libretro.cxx).
static const GagaLibretroVariable s_variables[] = {
    { "stella_filter", "disabled" },
    { "stella_phosphor", "auto" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Stella",
    .game_kind = "an Atari 2600 game",
    .variables = s_variables,
};

const GagaCoreInterface* Stella_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "stella",
        .core_name = "Stella",
        .core_version = GAGA_CORE_VERSION,
        // Upstream's valid_extensions. A .bin reaches this core only when CoreCatalog places it as a 2600 image.
        .supported_extensions = "a26|bin",
        .target_fps = 60.0,             // getVideoRate for NTSC. A PAL cart changes it through SET_SYSTEM_AV_INFO.
        .native_sample_rate = 31440,    // getAudioRate for NTSC: 262 lines * 76 cycles * 60 / 38.
        .state_version = 1,
    };
    return &interface;
}
