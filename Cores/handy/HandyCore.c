// Handy (Atari Lynx) behind the GagaBridge interface, through the shared libretro adapter. The boot ROM is the
// player's: upstream opens "lynxboot.img" from the system directory and, without it, emulates the boot ROM's loader
// (HLE). Cart EEPROM is written by upstream itself to <save directory>/<game name>.eeprom, not through SAVE_RAM.
// Upstream's libretro target has no cheats.
#include "LibretroAdapter.h"

// Option values are upstream's spelling (libretro_core_options.h).
static const GagaLibretroVariable s_variables[] = {
    { "handy_refresh_rate", "60" },
    { "handy_rot", "Auto" },
    { "handy_gfx_colors", "16bit" },
    { "handy_lcd_ghosting", "disabled" },
    { "handy_overclock", "1" },
    { "handy_frameskip", "disabled" },
    { "handy_frameskip_threshold", "33" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Handy",
    .game_kind = "an Atari Lynx game",
    .variables = s_variables,
};

const GagaCoreInterface* Handy_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "handy",
        .core_name = "Handy",
        .core_version = GAGA_CORE_VERSION,
        // Upstream also takes .lyx and .o. Handy picks the format from the file's bytes, not its name.
        .supported_extensions = "lnx",
        .target_fps = 60.0,             // handy_refresh_rate. The Lynx itself draws at a variable rate up to 75 Hz.
        .native_sample_rate = 48000,    // HANDY_AUDIO_SAMPLE_FREQ.
        .state_version = 1,
    };
    return &interface;
}
