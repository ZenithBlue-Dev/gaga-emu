// Atari800 (Atari 5200 and the 8-bit computers) behind the GagaBridge interface, through the shared libretro
// adapter. System ROMs are the player's: upstream scans the system directory for 5200.rom, the XL/XE OS, the
// 400/800 OS and BASIC by checksum, and otherwise uses the bundled AltirraOS replacements. A .a52 runs on the 5200;
// everything else on the 800XL. The keyboard is read by polling RETRO_DEVICE_KEYBOARD. No cheats or battery upstream.
#include "LibretroAdapter.h"

// Upstream's defaults (libretro_core_options.h), except the P: printer device: off, so nothing is written as a
// print file. atari800_cfg stays disabled, so no atari800.cfg is written either.
static const GagaLibretroVariable s_variables[] = {
    { "atari800_ntscpal", "disabled" },
    { "atari800_artifacting_mode", "none" },
    { "atari800_resolution", "336x240" },
    { "atari800_opt2", "none" },
    { "atari800_keyboard", "poll" },
    { "atari800_vkbd_enabled", "disabled" },
    { "atari800_system", "800XL (64K)" },
    { "atari800_internalbasic", "disabled" },
    { "atari800_os_800", "auto" },
    { "atari800_os_xl", "auto" },
    { "atari800_os_5200", "auto" },
    { "atari800_basic_version", "auto" },
    { "atari800_mosaic", "disabled" },
    { "atari800_axlon", "disabled" },
    { "atari800_axlon_shadow", "disabled" },
    { "atari800_mapram", "disabled" },
    { "atari800_autofire", "disabled" },
    { "atari800_show_speed", "disabled" },
    { "atari800_show_diskled", "enabled" },
    { "atari800_show_sector", "disabled" },
    { "atari800_show_1200leds", "enabled" },
    { "atari800_xep80", "disabled" },
    { "atari800_rtime", "enabled" },
    { "atari800_pdevice", "disabled" },
    { "atari800_rdevice", "disabled" },
    { "atari800_slowxex", "disabled" },
    { "atari800_sioaccel", "enabled" },
    { "atari800_cassboot", "disabled" },
    { "atari800_pokey_stereo", "disabled" },
    { "atari800_cfg", "disabled" },
    { "atari800_opt1", "disabled" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Atari800",
    .game_kind = "an Atari 5200 or 8-bit game",
    .variables = s_variables,
};

const GagaCoreInterface* Atari800_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "atari800",
        .core_name = "Atari800",
        .core_version = GAGA_CORE_VERSION,
        // Upstream also takes .bin, .rom, .car, .cas, .com, .zip and .m3u; .bin and .com belong to other platforms here.
        .supported_extensions = "a52|xex|atr|xfd|dcm|atx",
        .target_fps = 59.92,            // NTSC; upstream reports it through av info.
        .native_sample_rate = 44100,
        .state_version = 1,
    };
    return &interface;
}
