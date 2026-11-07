// Gearsystem behind the GagaBridge interface, through the shared libretro adapter. Master System, Game Gear
// and SG-1000. The BIOS options stay at upstream's "Disabled", so no Sega boot ROM is read: the core starts
// the cartridge itself.
#include "LibretroAdapter.h"

#include <string.h>

static const GagaLibretroVariable s_variables[] = {
    { "gearsystem_bios_sms", "Disabled" },
    { "gearsystem_bios_gg", "Disabled" },
    { "gearsystem_up_down_allowed", "Disabled" },
    { NULL, NULL },
};

static bool gearsystem_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// The two formats GearsystemCore::SetCheat takes. Pro Action Replay: 00AAAA:VV or 00AAAAVV. Game Genie:
// VVA-AAA or VVA-AAA-CCC. Anything else upstream would read as a Pro Action Replay code of garbage.
static bool gearsystem_is_cheat(const char* line) {
    size_t length = strlen(line);
    if (length == 8) return gearsystem_is_hex(line, 8);
    if (length == 9) return line[6] == ':' && gearsystem_is_hex(line, 6) && gearsystem_is_hex(line + 7, 2);
    if (length != 7 && length != 11) return false;
    if (line[3] != '-' || !gearsystem_is_hex(line, 3) || !gearsystem_is_hex(line + 4, 3)) return false;
    return length == 7 || (line[7] == '-' && gearsystem_is_hex(line + 8, 3));
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Gearsystem",
    .game_kind = "a Master System, Game Gear or SG-1000 game",
    .variables = s_variables,
    .is_cheat = gearsystem_is_cheat,
};

const GagaCoreInterface* Gearsystem_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "gearsystem",
        .core_name = "Gearsystem",
        .core_version = GAGA_CORE_VERSION,
        // Upstream's valid_extensions, less .bin and .rom: those go to other platforms by content (CoreCatalog).
        .supported_extensions = "sms|gg|sg|mv",
        .target_fps = 3579545.0 / (262 * 228), // 59.9227: the NTSC clock over its cycles per frame.
        .native_sample_rate = 44100,           // retro_get_system_av_info.
        .state_version = 111,                  // GS_SAVESTATE_VERSION, in the state's last 4 bytes. A test checks real bytes.
    };
    return &interface;
}
