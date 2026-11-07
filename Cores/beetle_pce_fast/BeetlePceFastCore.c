// Beetle PCE Fast behind the GagaBridge interface, through the shared libretro adapter. HuCards run with no
// BIOS. A CD game needs the player's own System Card image, syscard3.pce, in the system folder; the core
// refuses the disc without it. Nothing from NEC or Hudson is bundled.
#include "LibretroAdapter.h"

#include <stdlib.h>
#include <string.h>

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "pce_fast_cdbios", "System Card 3" }, // syscard3.pce, the one Settings > BIOS Files lists.
    { "pce_fast_frameskip", "disabled" },
    { "pce_fast_turbo_toggling", "disabled" },
    { "pce_fast_default_joypad_type_p1", "2 Buttons" },
    { "pce_fast_cdimagecache", "disabled" },
    { NULL, NULL },
};

static bool pce_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// Upstream's raw RAM code AAAAAA:VV. It ignores an address outside work RAM and CD RAM without saying so,
// so those are refused here instead. F82xxx is the physical alias of work RAM, which upstream also takes.
static bool pce_is_cheat(const char* line) {
    if (strlen(line) != 9 || line[6] != ':' || !pce_is_hex(line, 6) || !pce_is_hex(line + 7, 2)) return false;
    char digits[7] = { 0 };
    memcpy(digits, line, 6);
    unsigned long address = strtoul(digits, NULL, 16);
    if ((address & 0xFFE000) == 0xF82000) return true;
    return (address >= 0x1F0000 && address < 0x1F2000) || (address >= 0x00D000 && address < 0x10FFFF);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle PCE Fast",
    .game_kind = "a PC Engine game",
    .variables = s_variables,
    .is_cheat = pce_is_cheat,
};

const GagaCoreInterface* BeetlePceFast_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "beetle_pce_fast",
        .core_name = "Beetle PCE Fast",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "pce|cue|ccd|chd|toc|m3u", // MEDNAFEN_CORE_EXTENSIONS in libretro.c.
        .target_fps = 59.82,         // MEDNAFEN_CORE_TIMING_FPS.
        .native_sample_rate = 44100, // retro_get_system_av_info.
        .state_version = 931,        // MEDNAFEN_VERSION_NUMERIC, which MDFNSS_SaveSM writes at byte 16 of its header.
    };
    return &interface;
}
