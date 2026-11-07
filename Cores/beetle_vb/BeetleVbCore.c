// Beetle VB behind the GagaBridge interface, through the shared libretro adapter. The Virtual Boy has no BIOS.
// The picture is one eye, red on black, at 384x224: anaglyph mode with no anaglyph colours is upstream's flat
// view. Side by side and the other stereo modes need a viewer this app does not have, so they stay off.
#include "LibretroAdapter.h"

#include <stddef.h>

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "vb_3dmode", "anaglyph" },
    { "vb_anaglyph_preset", "disabled" },
    { "vb_color_mode", "black & red" },
    { "vb_vr", "disabled" },
    { NULL, NULL },
};

// Upstream's own checks in Load(): a power-of-two size from 256 bytes to 16 MB. It has no header to test.
static bool vb_is_rom(const uint8_t* data, size_t size) {
    (void)data;
    return size >= 256 && size <= (1u << 24) && (size & (size - 1)) == 0;
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle VB",
    .game_kind = "a Virtual Boy game",
    .variables = s_variables,
    .is_rom = vb_is_rom,
};

// No cheat entry points: upstream's retro_cheat_set does nothing.
const GagaCoreInterface* BeetleVb_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "beetle_vb",
        .core_name = "Beetle VB",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "vb|vboy", // MEDNAFEN_CORE_EXTENSIONS, less .bin, which other platforms own.
        .target_fps = 50.27,         // MEDNAFEN_CORE_TIMING_FPS.
        .native_sample_rate = 44100, // retro_get_system_av_info.
        .state_version = 931,        // MEDNAFEN_VERSION_NUMERIC, which MDFNSS_SaveSM writes at byte 16 of its header.
    };
    return &interface;
}
