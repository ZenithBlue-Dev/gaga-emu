// Genesis Plus GX behind the GagaBridge interface, through the shared libretro adapter. An alternate Mega Drive,
// Mega-CD, Master System and Game Gear core for sideload builds only: its licence forbids commercial use
// (docs/03 section 5), so core.env sets CORE_NONCOMMERCIAL=1 and no App Store or TestFlight build may link it.
// The boot ROM option stays off, so no TMSS or Master System BIOS is read. A Mega-CD disc needs the player's
// own BIOS (bios_CD_U.bin, bios_CD_E.bin or bios_CD_J.bin in the system folder); none is bundled.
#include "LibretroAdapter.h"

#include <libretro.h>
#include <string.h>

// Option values are upstream's spelling. Per-game BRAM keeps one Mega-CD game from filling another's memory.
static const GagaLibretroVariable s_variables[] = {
    { "genesis_plus_gx_bios", "disabled" },
    { "genesis_plus_gx_system_bram", "per game" },
    { "genesis_plus_gx_blargg_ntsc_filter", "disabled" },
    { "genesis_plus_gx_lcd_filter", "disabled" },
    { "genesis_plus_gx_frameskip", "disabled" },
    { "genesis_plus_gx_overclock", "100%" },
    { NULL, NULL },
};

static bool gpgx_in(const char* text, size_t count, const char* allowed) {
    for (size_t i = 0; i < count; ++i) {
        if (!text[i] || !strchr(allowed, text[i])) return false;
    }
    return true;
}

// The shapes upstream's decode_cheat reads, in its own upper-case alphabets; it ignores anything else without
// saying so. Mega Drive: Game Genie ABCD-EFGH, or AAAAAA:DDDD. Master System and Game Gear: Game Genie
// XXX-XXX or XXX-XXX-XXX, Pro Action Replay XXXX-XXXX, or AAAA:DD. Several codes go on several lines.
static bool gpgx_is_cheat(const char* line) {
    static const char hex[] = "0123456789ABCDEF";
    static const char genie[] = "ABCDEFGHJKLMNPRSTVWXYZ0123456789";
    size_t n = strlen(line);
    if (n == 9 && line[4] == '-') {
        return (gpgx_in(line, 4, genie) && gpgx_in(line + 5, 4, genie)) || (gpgx_in(line, 4, hex) && gpgx_in(line + 5, 4, hex));
    }
    if (n == 11 && line[6] == ':') return gpgx_in(line, 6, hex) && gpgx_in(line + 7, 4, hex);
    if ((n == 7 || n == 11) && line[3] == '-' && gpgx_in(line, 3, hex) && gpgx_in(line + 4, 3, hex)) {
        return n == 7 || (line[7] == '-' && gpgx_in(line + 8, 3, hex));
    }
    return n == 7 && line[4] == ':' && gpgx_in(line, 4, hex) && gpgx_in(line + 5, 2, hex);
}

// No is_rom: the core loads by path, and a disc image is far larger than anything worth reading twice.
// Upstream refuses what it cannot load, and the adapter turns that into a message.
// Players 3 to 5: Sega's Team Player in port 2, 3-button pads, after the pad in port 1 (upstream's
// RETRO_DEVICE_MDPAD_3B_TEAMPLAYER). shortcut: EA's 4 Way Play is not offered; add a choice if its games matter.
static const GagaLibretroMultitap s_multitap = {
    .base_players = 2,
    .in = { { 1, RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 5) } },
    .in_count = 1,
    .out = { { 1, RETRO_DEVICE_JOYPAD } },
    .out_count = 1,
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Genesis Plus GX",
    .game_kind = "a Mega Drive, Mega-CD, Master System or Game Gear game",
    .variables = s_variables,
    .is_cheat = gpgx_is_cheat,
    .multitap = &s_multitap,
};

const GagaCoreInterface* GenesisPlusGX_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "genesis_plus_gx",
        .core_name = "Genesis Plus GX",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "md|gen|smd|sms|gg|sg|bin|cue|chd|iso|m3u",
        // shortcut: one rate per core, so a PAL game (50 Hz) runs 20% fast, as with JGenesis. Add a per-game rate to the bridge for PAL.
        .target_fps = 53693175.0 / (262.0 * 3420.0), // 59.9227: NTSC Mega Drive, upstream's own formula.
        .native_sample_rate = 44100,                 // SOUND_FREQUENCY in upstream's libretro.c.
        .state_version = 1,                          // Upstream's own state header names its version, which it checks.
    };
    return &interface;
}
