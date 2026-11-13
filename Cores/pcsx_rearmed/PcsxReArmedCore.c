// PCSX-ReARMed behind the GagaBridge interface, through the shared libretro adapter. Interpreter only: no
// dynarec is compiled (core.env). The BIOS option is HLE, so the core never looks for a Sony BIOS file and
// runs its own high-level BIOS. Memory card 1 is the battery save; card 2 is off.
#include "LibretroAdapter.h"

#include <libretro.h>
#include <string.h>

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "pcsx_rearmed_bios", "HLE" },
    { "pcsx_rearmed_show_bios_bootlogo", "disabled" },
    { "pcsx_rearmed_region", "auto" },
    { "pcsx_rearmed_memcard1", "libretro" }, // RETRO_MEMORY_SAVE_RAM, which the adapter writes to <game>.sav.
    { "pcsx_rearmed_memcard2", "none" },     // Otherwise the core writes a shared card file of its own.
    { "pcsx_rearmed_fractional_framerate", "disabled" }, // 60 Hz, the host's target_fps, for NTSC.
    { "pcsx_rearmed_frameskip_type", "disabled" },
    { "pcsx_rearmed_rgb32_output", "disabled" },
    { "pcsx_rearmed_display_fps_v2", "disabled" },
    { "pcsx_rearmed_display_info", "disabled" },
    { "pcsx_rearmed_vibration", "disabled" },
    { "pcsx_rearmed_multitap", "disabled" }, // s_multitap_port1 replaces it while players 3 to 5 play.
#ifdef GAGA_CORE_JIT
    // Sideload JIT build (jit.env): the interpreter unless LibretroAdapterJit26.c finds runnable memory.
    { "pcsx_rearmed_drc", "disabled" },
#endif
    { NULL, NULL },
};

static bool pcsx_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// GameShark "TTAAAAAA VVVV" codes that stand alone: constant writes (30, 80), increments and decrements (10, 11,
// 20, 21) and the scratchpad write (1F). The adapter gives each line its own libretro cheat, so conditional
// codes and slides, which act on the line after them, are refused rather than doing something else.
static bool pcsx_is_cheat(const char* line) {
    if (strlen(line) != 13 || line[8] != ' ' || !pcsx_is_hex(line, 8) || !pcsx_is_hex(line + 9, 4)) return false;
    static const char* const types[] = { "30", "80", "10", "11", "20", "21", "1F", "1f" };
    for (size_t i = 0; i < sizeof(types) / sizeof(types[0]); ++i) {
        if (line[0] == types[i][0] && line[1] == types[i][1]) return true;
    }
    return false;
}

// Players 3 to 5: a Multitap in port 1 takes libretro ports 0 to 3, and port 2 moves to libretro port 4
// (libpcsxcore/pad.c). Pads past the first two start unplugged, so they are plugged in with it.
static const GagaLibretroVariable s_multitap_port1[] = {
    { "pcsx_rearmed_multitap", "port 1" },
    { NULL, NULL },
};

static const GagaLibretroMultitap s_multitap = {
    .base_players = 2,
    .variables = s_multitap_port1,
    .in = { { 2, RETRO_DEVICE_JOYPAD }, { 3, RETRO_DEVICE_JOYPAD }, { 4, RETRO_DEVICE_JOYPAD } },
    .in_count = 3,
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "PCSX-ReARMed",
    .game_kind = "a PlayStation game",
    .variables = s_variables,
    .is_cheat = pcsx_is_cheat,
    .multitap = &s_multitap,
};

const GagaCoreInterface* PcsxReArmed_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "pcsx_rearmed",
        .core_name = "PCSX-ReARMed",
        .core_version = GAGA_CORE_VERSION,
        // libretro.c's own list, which it also reads by name: ".exe" boots a PS-EXE, ".m3u" is a disc list.
        .supported_extensions = "bin|cue|img|mdf|pbp|toc|cbn|m3u|chd|iso|exe",
        .target_fps = 60.0,          // psxGetFps() for NTSC with fractional_framerate off. PAL games want 50.
        .native_sample_rate = 44100, // retro_get_system_av_info.
        .state_version = 0x8b410006, // SaveVersion in libpcsxcore/misc.c, after the 32-byte header. A test reads it.
    };
    return &interface;
}
