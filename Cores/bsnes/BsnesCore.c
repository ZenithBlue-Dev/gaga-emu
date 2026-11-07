// bsnes behind the GagaBridge interface, through the shared libretro adapter. Super Famicom cartridges only:
// Super Game Boy and BS-X need Nintendo firmware files, which GagaEmu never ships or asks for. Without
// firmware, coprocessor games use bsnes's HLE where it has one.
#include "LibretroAdapter.h"

#include <string.h>

bool gaga_bsnes_save_battery(void); // BsnesSupport.cpp
void gaga_bsnes_unapply_cheats(void); // BsnesSupport.cpp

// Option values are upstream's spelling. The video options are its defaults, set here because the picture
// tests depend on them. Run-ahead would run frames the host does not ask for.
static const GagaLibretroVariable s_variables[] = {
    { "bsnes_video_filter", "None" },
    { "bsnes_ppu_overscan_v", "8" },
    { "bsnes_blur_emulation", "OFF" },
    { "bsnes_video_luminance", "100" },
    { "bsnes_video_saturation", "100" },
    { "bsnes_video_gamma", "150" },
    { "bsnes_run_ahead_frames", "OFF" },
    { "bsnes_coprocessor_prefer_hle", "ON" },
    { "bsnes_ppu_fast", "ON" },
    { "bsnes_dsp_fast", "ON" },
    { NULL, NULL },
};

// Whether some header bsnes would look at (LoROM, HiROM, ExLoROM, ExHiROM) is plausible: its reset vector
// points into ROM and its checksum pair or its map mode looks real. Dumps with a bad checksum still pass.
static bool bsnes_is_rom(const uint8_t* data, size_t size) {
    if (size % 0x8000 == 0x200) { // A copier header, which bsnes skips.
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

static bool bsnes_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// Pro Action Replay AAAAAADD, or Game Genie XXXX-XXXX. Upstream's parser reads past the end of anything
// shorter, and chains codes with '+', so only these exact shapes reach it. More codes go on more lines.
static bool bsnes_is_cheat(const char* line) {
    size_t length = strlen(line);
    if (length == 8) return bsnes_is_hex(line, 8);
    return length == 9 && line[4] == '-' && bsnes_is_hex(line, 4) && bsnes_is_hex(line + 5, 4);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "bsnes",
    .game_kind = "a Super Famicom or Super NES game",
    .variables = s_variables,
    .is_rom = bsnes_is_rom,
    .is_cheat = bsnes_is_cheat,
    .save_battery = gaga_bsnes_save_battery,
    .unapply_cheats = gaga_bsnes_unapply_cheats,
};

const GagaCoreInterface* Bsnes_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "bsnes",
        .core_name = "bsnes",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "sfc|smc",
        // shortcut: one rate per core, so a PAL game (50 Hz) runs 20% fast. Add a per-game rate to the bridge for PAL.
        .target_fps = 21477272.0 / 357366.0, // 60.0988: NTSC, the master clock over its cycles per frame.
        .native_sample_rate = 48000,         // SAMPLERATE in upstream's libretro.cpp.
        .state_version = 1,                  // bsnes's own header carries its serializer version, which it checks.
    };
    return &interface;
}
