// PicoDrive behind the GagaBridge interface, through the shared libretro adapter. The 32X core, and an alternate
// Mega Drive, Mega-CD, Master System and Game Gear core, for sideload builds only: its licence forbids
// commercial use (docs/03 section 5), so core.env sets CORE_NONCOMMERCIAL=1 and no App Store or TestFlight build
// may link it. A 32X game needs no BIOS: with none supplied, upstream builds its own small 68000 and SH-2 start-up
// code (pico/32x/memory.c get_bios), written for PicoDrive, not taken from Sega's ROMs. A Mega-CD disc needs the
// player's own BIOS (bios_CD_U.bin, bios_CD_E.bin or bios_CD_J.bin in the system folder); none is bundled.
#include "LibretroAdapter.h"

#include <errno.h>
#include <libkern/OSCacheControl.h>
#include <string.h>
#include <sys/mman.h>

// The stubs no_exec.h points upstream's calls at. Only the left-out recompiler would reach them.
int gaga_picodrive_no_mprotect(void* address, size_t length, int protection) {
    (void)address, (void)length, (void)protection;
    errno = EPERM;
    return -1;
}
void gaga_picodrive_no_icache_invalidate(void* start, size_t length) { (void)start, (void)length; }
void gaga_picodrive_no_dcache_flush(void* start, size_t length) { (void)start, (void)length; }

// Option values are upstream's spelling. The six-button pad is what most later games and MDTestROM read.
static const GagaLibretroVariable s_variables[] = {
    { "picodrive_input1", "6 button pad" },
    { "picodrive_region", "Auto" },
    { "picodrive_renderer", "accurate" },
    { "picodrive_sound_rate", "44100" },
    { "picodrive_drc", "disabled" },
    { "picodrive_frameskip", "disabled" },
    { "picodrive_overclk68k", "disabled" },
    { NULL, NULL },
};

static bool pd_in(const char* text, size_t count, const char* allowed) {
    for (size_t i = 0; i < count; ++i) {
        if (!text[i] || !strchr(allowed, text[i])) return false;
    }
    return true;
}

// The shapes upstream's decode (pico/patch.c) reads. Mega Drive: Game Genie ABCD-EFGH, or AAAAAA:DDDD. Master
// System and Game Gear: Game Genie XXX-XXX or XXX-XXX-XXX, Action Replay XXXX-XXXX, or Fusion AAAA:DD and
// CCAAAA:DD. Exact lengths matter: upstream copies a code into 256 bytes and reads past a short one.
static bool pd_is_cheat(const char* line) {
    static const char hex[] = "0123456789ABCDEFabcdef";
    static const char genie[] = "AaBbCcDdEeFfGgHhJjKkLlMmNnPpRrSsTtVvWwXxYyZz0O1I23456789";
    size_t n = strlen(line);
    if (n == 9 && line[4] == '-') {
        return (pd_in(line, 4, genie) && pd_in(line + 5, 4, genie)) || (pd_in(line, 4, hex) && pd_in(line + 5, 4, hex));
    }
    if (n == 11 && line[6] == ':') return pd_in(line, 6, hex) && pd_in(line + 7, 4, hex);
    if (n == 9 && line[6] == ':') return pd_in(line, 6, hex) && pd_in(line + 7, 2, hex);
    if ((n == 7 || n == 11) && line[3] == '-' && pd_in(line, 3, hex) && pd_in(line + 4, 3, hex)) {
        return n == 7 || (line[7] == '-' && pd_in(line + 8, 3, hex));
    }
    return n == 7 && line[4] == ':' && pd_in(line, 4, hex) && pd_in(line + 5, 2, hex);
}

// No is_rom: the core loads by path, and a disc image is far larger than anything worth reading twice.
const GagaLibretroCore gaga_libretro_core = {
    .name = "PicoDrive",
    .game_kind = "a 32X, Mega Drive, Mega-CD, Master System or Game Gear game",
    .variables = s_variables,
    .is_cheat = pd_is_cheat,
};

const GagaCoreInterface* Picodrive_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "picodrive",
        .core_name = "PicoDrive",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "32x|md|gen|smd|sms|gg|sg|bin|cue|chd|iso|m3u",
        // shortcut: one rate per core, so a PAL game (50 Hz) runs 20% fast, as with JGenesis. Add a per-game rate to the bridge for PAL.
        .target_fps = 60.0,          // retro_get_system_av_info: Pico.m.pal ? 50 : 60.
        .native_sample_rate = 44100, // picodrive_sound_rate, set above.
        .state_version = 1,          // Upstream's own state data carries its version.
    };
    return &interface;
}
