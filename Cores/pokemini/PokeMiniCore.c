// PokeMini behind the GagaBridge interface, through the shared libretro adapter. It runs Pokemon Mini cartridges
// with its own free BIOS. A player's bios.min in the system folder replaces it; none is needed or bundled.
// Game saves are the console's 8 KB EEPROM, which upstream keeps in <save folder>/<game>.eep.
#include "LibretroAdapter.h"

#include <stdbool.h>
#include <stdio.h>

#include "PMCommon.h"
#include "CommandLine.h"

// From upstream's MinxIO.h and PokeMini.h, whose own includes need the core's build setup.
extern int PokeMini_EEPROMWritten;
int PokeMini_SaveEEPROMFile(const char* filename);

static const GagaLibretroVariable s_variables[] = {
    { "pokemini_video_scale", "1x" },     // 96x64; the app scales and filters.
    { "pokemini_lcdfilter", "none" },
    { "pokemini_lcdmode", "2shades" },   // Analog mode blends frames, so a picture lags its game by several.
    { "pokemini_60hz_mode", "enabled" }, // Runs 6 frames of 72 Hz in 5 of 60 Hz, so the display paces it.
    { NULL, NULL },
};

// Upstream aborts the process when retro_load_game gets a size outside this range.
static bool pm_is_rom(const uint8_t* data, size_t size) {
    (void)data;
    return size > 0x2100 && size <= 0x200000;
}

// Upstream writes EEPROM only when the game unloads. This writes it at each flush as well, when the game
// changed it, through a temporary file so a crash mid-write keeps the previous save.
static bool pm_save_battery(void) {
    if (!PokeMini_EEPROMWritten || !CommandLine.eeprom_file[0]) return true;
    char temporary[PMTMPV + 8];
    if (snprintf(temporary, sizeof(temporary), "%s.tmp", CommandLine.eeprom_file) >= (int)sizeof(temporary)) return false;
    if (!PokeMini_SaveEEPROMFile(temporary) || rename(temporary, CommandLine.eeprom_file) != 0) {
        remove(temporary);
        return false;
    }
    PokeMini_EEPROMWritten = 0;
    return true;
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "PokeMini",
    .game_kind = "a Pokémon Mini game",
    .variables = s_variables,
    .is_rom = pm_is_rom,
    .save_battery = pm_save_battery,
};

// No cheat entry points: upstream's retro_cheat_set does nothing.
const GagaCoreInterface* PokeMini_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "pokemini",
        .core_name = "PokeMini",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "min", // valid_extensions in libretro.c.
        .target_fps = 60.0,            // RETRO_60HZ_FPS, with pokemini_60hz_mode on.
        .native_sample_rate = 44100,   // MINX_AUDIOFREQ.
        .state_version = 0x006B4D50,   // PokeMini_ID, after the 12-byte "PokeMiniStat" magic.
    };
    return &interface;
}
