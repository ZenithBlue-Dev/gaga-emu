// PPSSPP behind the GagaBridge interface, through the shared libretro adapter and its Vulkan layer path.
// No JIT anywhere (docs/04): the Allegrex runs on upstream's IR interpreter, every JIT back end and code
// emitter is left out of the build (generate.py), and video is PPSSPP's Vulkan renderer on MoltenVK. The PSP
// operating system is upstream's HLE, so no firmware is read.
#include "LibretroAdapter.h"
#include "LibretroVulkan.h"

#include <ctype.h>

// Option values are upstream's spelling (upstream/libretro/libretro_core_options.h).
static const GagaLibretroVariable s_variables[] = {
    { "ppsspp_cpu_core", "IR JIT" },  // "IR JIT" is the IR interpreter; the frontend reports no JIT either.
    { "ppsspp_backend", "vulkan" },
    { "ppsspp_internal_resolution", "480x272" },
    { "ppsspp_enable_wlan", "disabled" },
    { "ppsspp_enable_upnp", "disabled" },
    { "ppsspp_cheats", "enabled" }, // Upstream reads cheats only from <memory stick>/PSP/Cheats/<disc ID>.ini.
    { NULL, NULL },
};

const char* gaga_ppsspp_finish_load(void); // PpssppSupport.cpp
const char* gaga_ppsspp_install_assets(const char* system_dir, const char* rom_path); // PpssppSupport.cpp

// "0x" and 8 hex digits, one CWCheat word.
static bool cw_word(const char** text) {
    const char* p = *text;
    if (p[0] != '0' || (p[1] != 'x' && p[1] != 'X')) return false;
    p += 2;
    for (int i = 0; i < 8; ++i, ++p) {
        if (!isxdigit((unsigned char)*p)) return false;
    }
    *text = p;
    return true;
}

// CWCheat "_L 0xAAAAAAAA 0xVVVVVVVV", one line of a cheat; "_L " may be left off. Upstream's retro_cheat_set
// writes the code to <save folder>/PSP/Cheats/<disc ID>.ini, where its cheat engine reads it. It pairs any words
// it finds and cannot refuse, so only this shape reaches it. A cheat's lines go as one code, because CWCheat's
// conditional and multi-write types act on the lines after them.
static bool ppsspp_is_cheat(const char* line) {
    if (line[0] == '_' && (line[1] == 'L' || line[1] == 'l') && line[2] == ' ') line += 3;
    while (*line == ' ') ++line;
    if (!cw_word(&line) || *line != ' ') return false;
    while (*line == ' ') ++line;
    return cw_word(&line) && *line == '\0';
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "PPSSPP",
    .game_kind = "a PSP game",
    .variables = s_variables,
    .is_cheat = ppsspp_is_cheat,
    .cheat_lines_are_one_code = true,
    .finish_load = gaga_ppsspp_finish_load,
    .refuse_load = gaga_ppsspp_install_assets, // Installs PPSSPP's assets and refuses nothing.
};

const GagaCoreInterface* Ppsspp_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "ppsspp",
        .core_name = "PPSSPP",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "iso|cso|pbp|elf",
        .target_fps = 59.94,          // 60/1.001, retro_get_system_av_info.
        .native_sample_rate = 44100,  // SAMPLERATE in libretro.cpp.
        .state_version = 1,           // PPSSPP versions every section of its state itself and refuses others.
    };
    return &interface;
}
