// Snes9x behind the GagaBridge interface, through the shared libretro adapter. An alternate Super Famicom
// core for sideload builds only: its licence forbids commercial use (docs/03 section 5), so core.env sets
// CORE_NONCOMMERCIAL=1 and no App Store or TestFlight build may link it. Cartridges only: no BS-X, Sufami
// Turbo or Super Game Boy firmware is read.
#include "LibretroAdapter.h"

#include <string.h>

// Option values are upstream's spelling. MSU-1 enhanced audio would change the output rate mid-game.
static const GagaLibretroVariable s_variables[] = {
    { "snes9x_region", "auto" },
    { "snes9x_overscan", "auto" },
    { "snes9x_blargg", "disabled" },
    { "snes9x_hires_blend", "disabled" },
    { "snes9x_up_down_allowed", "disabled" },
    { "snes9x_randomize_memory", "disabled" },
    { "snes9x_msu1_enhanced_audio", "disabled" },
    { NULL, NULL },
};

// Same check as Cores/bsnes: some header Snes9x would look at (LoROM, HiROM, ExLoROM, ExHiROM) has a reset
// vector into ROM and a plausible checksum pair or map mode. Dumps with a bad checksum still pass.
static bool snes9x_is_rom(const uint8_t* data, size_t size) {
    if (size % 0x8000 == 0x200) { // A copier header, which Snes9x skips.
        data += 0x200;
        size -= 0x200;
    }
    if (size < 0x8000 || size > 0x1000000) return false;
    static const size_t headers[] = { 0x7FB0, 0xFFB0, 0x407FB0, 0x40FFB0 };
    for (size_t i = 0; i < sizeof(headers) / sizeof(headers[0]); ++i) {
        if (headers[i] + 0x50 > size) continue;
        const uint8_t* h = data + headers[i];
        unsigned reset = h[0x4C] | h[0x4D] << 8;
        unsigned sum = (h[0x2C] | h[0x2D] << 8) + (h[0x2E] | h[0x2F] << 8);
        unsigned map = h[0x25] & ~0x10u;
        if (reset >= 0x8000 && (sum == 0xFFFF || (map >= 0x20 && map <= 0x2A))) return true;
    }
    return false;
}

static bool snes9x_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// Pro Action Replay AAAAAADD, Game Genie XXXX-XXXX, or a raw AAAAAA:DD write. Upstream copies the line into a
// 256-byte buffer and splits it on "+,.; ", so only these exact shapes reach it; more codes go on more lines.
static bool snes9x_is_cheat(const char* line) {
    size_t length = strlen(line);
    if (length == 8) return snes9x_is_hex(line, 8);
    if (length == 9 && line[4] == '-') return snes9x_is_hex(line, 4) && snes9x_is_hex(line + 5, 4);
    return length == 9 && line[6] == ':' && snes9x_is_hex(line, 6) && snes9x_is_hex(line + 7, 2);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Snes9x",
    .game_kind = "a Super Famicom or Super NES game",
    .variables = s_variables,
    .is_rom = snes9x_is_rom,
    .is_cheat = snes9x_is_cheat,
};

const GagaCoreInterface* Snes9x_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "snes9x",
        .core_name = "Snes9x",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "sfc|smc",
        // shortcut: one rate per core, so a PAL game (50 Hz) runs 20% fast, as with bsnes. Add a per-game rate to the bridge for PAL.
        .target_fps = 21477272.0 / 357366.0, // 60.0988: NTSC, upstream's retro_get_system_av_info.
        .native_sample_rate = 32040,         // The DSP's own rate, which upstream emits with MSU-1 enhanced audio off.
        .state_version = 1,                  // Snes9x's own snapshot header names its version, which it checks.
    };
    return &interface;
}
