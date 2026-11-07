// Beetle Saturn (Mednafen SS) behind the GagaBridge interface, through the shared libretro adapter. Interpreter
// only: no recompiler is compiled (core.env). Saturn games need the console's BIOS, which GagaEmu never ships:
// the core reads the player's own copy from system_dir, and a game is refused with a message when none is there.
// Internal backup RAM is the battery save (save method "libretro"); the core writes the backup cartridge and the
// clock to their own files per game, and nothing is shared between games.
#include "LibretroAdapter.h"

#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "beetle_saturn_region", "Auto Detect" },
    { "beetle_saturn_cart", "Auto Detect" },
    { "beetle_saturn_save_method", "libretro" }, // RETRO_MEMORY_SAVE_RAM, which the adapter writes to <game>.sav.
    { "beetle_saturn_shared_int", "disabled" },  // Otherwise every game shares one backup RAM file of the core's.
    { "beetle_saturn_shared_ext", "disabled" },
    { "beetle_saturn_cdimagecache", "disabled" }, // Reads the disc as it plays instead of loading it all into RAM.
    { "beetle_saturn_sh2_jit", "disabled" },      // The recompilers are not compiled; these keep the options honest.
    { "beetle_saturn_jit_scu", "disabled" },
    { "beetle_saturn_jit_scsp", "disabled" },
    { "beetle_saturn_autortc", "enabled" },
    // Upstream's option defaults. libretro.c's own statics, which an unset key leaves, show overscan instead.
    { "beetle_saturn_initial_scanline", "8" },
    { "beetle_saturn_last_scanline", "231" },
    { "beetle_saturn_initial_scanline_pal", "16" },
    { "beetle_saturn_last_scanline_pal", "271" },
    { "beetle_saturn_horizontal_overscan", "0" },
    { NULL, NULL },
};

// ss.c's names: sega_101.bin for Japan and Asia NTSC, mpr-17933.bin for every other region.
static const char* const s_bios[] = { "mpr-17933.bin", "sega_101.bin" };

// ss.c refuses a BIOS that is not 512 KiB.
static bool saturn_has_bios(const char* dir, const char* name) {
    char path[4096];
    struct stat info;
    return snprintf(path, sizeof(path), "%s/%s", dir, name) < (int)sizeof(path) && access(path, R_OK) == 0 &&
           stat(path, &info) == 0 && info.st_size == 512 * 1024;
}

static const char* saturn_refuse_load(const char* system_dir, const char* rom_path) {
    // upstream's MDFNI_LoadGame boots the BIOS with no disc for any other file, which looks like a broken game.
    const char* ext = strrchr(rom_path, '.');
    static const char* const discs[] = { ".cue", ".ccd", ".chd", ".toc", ".m3u" };
    bool disc = false;
    for (size_t i = 0; ext && i < sizeof(discs) / sizeof(discs[0]); ++i) disc |= strcasecmp(ext, discs[i]) == 0;
    if (!disc) return "Open this Saturn disc's .cue, .ccd, .chd, .toc or .m3u file. Beetle Saturn cannot start a disc from its track file.";
    for (size_t i = 0; i < sizeof(s_bios) / sizeof(s_bios[0]); ++i) {
        if (saturn_has_bios(system_dir, s_bios[i])) return NULL;
    }
    return "This Saturn game needs a Saturn BIOS file (mpr-17933.bin or sega_101.bin). GagaEmu does not include one.";
}

bool SS_FlushCartNV(void);    // mednafen/ss/ss.c
void SS_SaveRTC(void);         // mednafen/ss/ss.c
void save_writer_drain(void);  // mednafen/save_writer.c

// The backup cartridge (<game>.bcr) and the clock (<game>.smpc) are files the core writes itself, on a timer
// and at unload, through a writer thread. This writes both at every host flush and waits for the writer, so
// they are on disk when the flush returns.
// shortcut: a failed cartridge write is reported by the next flush, about 5 s later, because upstream keeps the
// failure flag private. Expose it if that delay matters.
static bool saturn_save_battery(void) {
    bool ok = SS_FlushCartNV(); // False when the previous write failed.
    save_writer_drain();
    SS_SaveRTC();
    return ok;
}

// upstream's failed-write flag is a static that outlives a game: the last session's unload into a folder that
// could not be written left it set, and this game's first flush then refused to load. Flushing here takes that
// stale report and starts this game's own cartridge write, whose outcome save_battery reports.
static void saturn_finish_load(void) {
    (void)SS_FlushCartNV();
    save_writer_drain();
}

static bool saturn_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// Pro Action Replay "TTAAAAAA VVVV" or a raw "AAAAAAAA VVVV" write, the one-line forms ss_cheat_parse_one in
// libretro.c accepts. Every line is its own libretro cheat.
static bool saturn_is_cheat(const char* line) {
    return strlen(line) == 13 && line[8] == ' ' && saturn_is_hex(line, 8) && saturn_is_hex(line + 9, 4);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle Saturn",
    .game_kind = "a Saturn game",
    .variables = s_variables,
    .is_cheat = saturn_is_cheat,
    .save_battery = saturn_save_battery,
    .refuse_load = saturn_refuse_load,
    .finish_load = saturn_finish_load,
};

const GagaCoreInterface* BeetleSaturn_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "beetle_saturn",
        .core_name = "Beetle Saturn",
        .core_version = GAGA_CORE_VERSION,
        // libretro.c's discs. Its .zip is ST-V arcade content, which GagaEmu sends to MAME.
        .supported_extensions = "cue|ccd|chd|toc|m3u",
        .target_fps = 59.82650314089141, // retro_get_system_av_info for NTSC. PAL games run at 49.92.
        .native_sample_rate = 44100,
        .state_version = 0x00103201, // MEDNAFEN_CORE_VERSION_NUMERIC, at byte 16 of the MDFNSVST header. A test reads it.
    };
    return &interface;
}
