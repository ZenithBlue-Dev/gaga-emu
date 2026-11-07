// Beetle SuperGrafx behind the GagaBridge interface, through the shared libretro adapter. A .sgx card runs in
// SuperGrafx mode, as do the known SuperGrafx titles by CRC; a .pce card runs as a plain PC Engine. HuCards
// need no BIOS. A CD game needs the player's own syscard3.pce in the system folder. Nothing from NEC or Hudson
// is bundled.
#include "LibretroAdapter.h"

#include <stdlib.h>
#include <string.h>

const char* gaga_sgx_finish_load(void); // GagaSupergrafx.cpp

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "sgx_cdbios", "System Card 3" }, // syscard3.pce, the one Settings > BIOS Files lists.
    { "sgx_forcesgx", "disabled" },    // The .sgx extension and upstream's CRC list choose the mode.
    { "sgx_turbo_toggle", "disabled" },
    { "sgx_cdimagecache", "disabled" },
    { NULL, NULL },
};

static bool sgx_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// Upstream's raw RAM code AAAAAA:VV. It ignores an address outside work RAM and CD RAM without saying so,
// so those are refused here instead. The exact length check also keeps a long line out of upstream's
// 256-byte strcpy buffer.
static bool sgx_is_cheat(const char* line) {
    if (strlen(line) != 9 || line[6] != ':' || !sgx_is_hex(line, 6) || !sgx_is_hex(line + 7, 2)) return false;
    char digits[7] = { 0 };
    memcpy(digits, line, 6);
    unsigned long address = strtoul(digits, NULL, 16);
    if ((address & 0xFFE000) == 0xF82000) return true;
    return (address >= 0x1F0000 && address < 0x1F2000) || (address >= 0x00D000 && address < 0x10FFFF);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle SuperGrafx",
    .game_kind = "a SuperGrafx game",
    .variables = s_variables,
    .is_cheat = sgx_is_cheat,
    .finish_load = gaga_sgx_finish_load,
};

const GagaCoreInterface* BeetleSupergrafx_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "beetle_supergrafx",
        .core_name = "Beetle SuperGrafx",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "pce|sgx|cue|ccd|chd|toc|m3u", // MEDNAFEN_CORE_EXTENSIONS in libretro.cpp.
        .target_fps = 59.82,         // MEDNAFEN_CORE_TIMING_FPS.
        .native_sample_rate = 44100, // SAMPLE_RATE.
        .state_version = 1290,       // MEDNAFEN_VERSION_NUMERIC, which MDFNSS_SaveSM writes at byte 16 of its header.
    };
    return &interface;
}
