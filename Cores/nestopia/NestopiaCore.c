// Nestopia UE behind the GagaBridge interface, through the shared libretro adapter.
// Cartridges only: an FDS disk needs the Nintendo disk BIOS (disksys.rom), which GagaEmu never ships,
// so .fds is not offered. Upstream's own palette and database are compiled in; nothing is downloaded.
#include "LibretroAdapter.h"

#include <string.h>

// Option values are upstream's spelling. The NTSC filter is off, so the host gets the 256 pixel PPU
// picture and its own shaders do any CRT look. The top and bottom 8 lines are upstream's default crop.
static const GagaLibretroVariable s_variables[] = {
    { "nestopia_blargg_ntsc_filter", "disabled" },
    { "nestopia_palette", "royaltea" },
    { "nestopia_overscan_v_top", "8" },
    { "nestopia_overscan_v_bottom", "8" },
    { "nestopia_overscan_h_left", "0" },
    { "nestopia_overscan_h_right", "0" },
    { "nestopia_favored_system", "ntsc" },
    { "nestopia_force_system", "auto" },
    { "nestopia_fds_auto_insert", "disabled" },
    { "nestopia_genie_distortion", "disabled" },
    { "nestopia_ram_power_state", "0x00" },
    { NULL, NULL },
};

// iNES and NES 2.0 both start with this. Nestopia checks the rest of the header itself.
static bool nestopia_is_rom(const uint8_t* data, size_t size) {
    return size > 16 && memcmp(data, "NES\x1A", 4) == 0;
}

static bool nestopia_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// The Game Genie letter's value, or -1.
static int nestopia_genie_value(char c) {
    static const char letters[] = "APZLGITYEOXUKSVN";
    if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
    const char* found = c ? strchr(letters, c) : NULL;
    return found ? (int)(found - letters) : -1;
}

// One code per line, so a line is never longer than 10 characters: upstream copies each code into a
// 256 byte buffer with strcpy. Raw RAM codes AAAA:VV and AAAA?CC:VV, and Game Genie, whose third letter
// says whether it has 6 letters or 8. Pro Action Rocky is not offered.
static bool nestopia_is_cheat(const char* line) {
    size_t length = strlen(line);
    if (length == 7 && line[4] == ':') return nestopia_is_hex(line, 4) && nestopia_is_hex(line + 5, 2);
    if (length == 10 && line[4] == '?' && line[7] == ':') {
        return nestopia_is_hex(line, 4) && nestopia_is_hex(line + 5, 2) && nestopia_is_hex(line + 8, 2);
    }
    if (length != 6 && length != 8) return false;
    for (size_t i = 0; i < length; ++i) {
        if (nestopia_genie_value(line[i]) < 0) return false;
    }
    return (length == 8) == ((nestopia_genie_value(line[2]) & 8) != 0);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Nestopia",
    .game_kind = "an NES cartridge image",
    .variables = s_variables,
    .is_rom = nestopia_is_rom,
    .is_cheat = nestopia_is_cheat,
};

const GagaCoreInterface* Nestopia_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "nestopia",
        .core_name = "Nestopia UE",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "nes",
        .target_fps = 39375000.0 / 655171.0, // 60.0988: 341 x 262 - 0.5 dots per NTSC frame, at 236.25 / 44 MHz.
        .native_sample_rate = 48000,         // SAMPLERATE in upstream/libretro/libretro.cpp.
        .state_version = 1,                  // Nestopia's state has no version field; bump when its chunks change meaning.
    };
    return &interface;
}
