// Beetle PSX HW behind the GagaBridge interface, through the shared libretro adapter and its Vulkan layer path.
// An alternate PS1 core. No JIT anywhere (docs/04): core.env builds without HAVE_LIGHTREC, so the R3000A is
// Mednafen's interpreter, and without HAVE_OPENGL, so the only hardware renderer is Vulkan on MoltenVK. The
// software rasterizer is compiled too and runs beside it at native resolution for framebuffer effects
// (renderer_software_fb, upstream's default). With no BIOS file in the system folder the core boots the
// OpenBIOS build it embeds (upstream/deps/openbios, MIT), so GagaEmu ships no Sony BIOS. Memory card 1 is the
// battery save; card 2 is off.
#include "LibretroAdapter.h"
#include "LibretroVulkan.h"

#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

// The stub flags.h points the Vulkan renderer's library lookup at.
void* gaga_beetle_psx_no_dlopen(const char* path, int mode) {
    (void)path, (void)mode;
    return NULL;
}

// Option values are upstream's spelling (upstream/libretro_core_options.h). A key not listed reads as unset,
// which upstream treats as its default; the renderer key unset means software, so it is set.
static const GagaLibretroVariable s_variables[] = {
    { "beetle_psx_hw_renderer", "hardware_vk" },
    { "beetle_psx_hw_cpu_dynarec", "disabled" },        // Not compiled; the interpreter either way.
    { "beetle_psx_hw_pgxp_mode", "memory only" },       // Subpixel geometry, upstream's recommended mode.
    { "beetle_psx_hw_use_mednafen_memcard0_method", "libretro" }, // RETRO_MEMORY_SAVE_RAM, the adapter's <game>.sav.
    { "beetle_psx_hw_enable_memcard1", "disabled" },
    { "beetle_psx_hw_cd_access_method", "sync" },       // Disc reads in step with retro_run, so states are exact.
    { "beetle_psx_hw_display_osd", "disabled" },
    { "beetle_psx_hw_track_textures", "disabled" },     // No texture dumps or HD packs beside the game.
    { "beetle_psx_hw_dump_textures", "disabled" },
    { "beetle_psx_hw_replace_textures", "disabled" },
    // The Vulkan renderer's own fallback for these is 0 (rhi_lib_vulkan.c), not upstream's 239 and 287, so
    // unset it scans out one line: device run 7's 2800x8 frame of border and field, no cube.
    { "beetle_psx_hw_last_scanline", "239" },
    { "beetle_psx_hw_last_scanline_pal", "287" },
    { NULL, NULL },
};

// upstream starts a PS-EXE by patching a Sony BIOS at a fixed offset (LoadEXE in libretro.c), so on OpenBIOS
// the program never runs. An EXE has no region, and upstream then looks for the North American BIOS under
// these names (firmware_is_present). Discs boot on OpenBIOS and need no check.
static const char* psx_refuse_load(const char* system_dir, const char* rom_path) {
    const char* dot = strrchr(rom_path, '.');
    if (!dot || (strcasecmp(dot, ".exe") != 0 && strcasecmp(dot, ".psexe") != 0)) return NULL;
    static const char* const names[] = { "scph5501.bin", "SCPH5501.bin", "SCPH5501.BIN", "SCPH-5501.bin", "SCPH-5501.BIN",
                                         "scph5503.bin", "SCPH5503.bin", "SCPH5503.BIN", "SCPH-5503.bin", "SCPH-5503.BIN",
                                         "scph7003.bin", "SCPH7003.bin", "SCPH7003.BIN", "SCPH-7003.bin", "SCPH-7003.BIN" };
    char path[1024];
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        if (snprintf(path, sizeof(path), "%s/%s", system_dir, names[i]) < (int)sizeof(path) && access(path, R_OK) == 0) return NULL;
    }
    return "Beetle PSX HW needs the PlayStation BIOS scph5501.bin in System to start a PS-EXE program. Add it on the BIOS Files screen, or play this program with PCSX-ReARMed.";
}

static bool psx_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// GameShark "TTAAAAAA VVVV" codes that stand alone, as for PCSX-ReARMed and SwanStation: constant writes (30, 80),
// increments and decrements (10, 11, 20, 21) and the scratchpad write (1F). The adapter gives each line its own
// libretro cheat, so conditional codes and slides, which act on the line after them, are refused.
static bool psx_is_cheat(const char* line) {
    if (strlen(line) != 13 || line[8] != ' ' || !psx_is_hex(line, 8) || !psx_is_hex(line + 9, 4)) return false;
    static const char* const types[] = { "30", "80", "10", "11", "20", "21", "1F", "1f" };
    for (size_t i = 0; i < sizeof(types) / sizeof(types[0]); ++i) {
        if (line[0] == types[i][0] && line[1] == types[i][1]) return true;
    }
    return false;
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle PSX HW",
    .game_kind = "a PlayStation game",
    .variables = s_variables,
    .is_cheat = psx_is_cheat,
    .refuse_load = psx_refuse_load,
};

const GagaCoreInterface* BeetlePsx_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "beetle_psx",
        .core_name = "Beetle PSX HW",
        .core_version = GAGA_CORE_VERSION,
        // MEDNAFEN_CORE_EXTENSIONS in libretro_options.h. ".exe" needs a Sony BIOS (psx_refuse_load).
        .supported_extensions = "exe|cue|toc|ccd|m3u|pbp|chd|bin|img|iso",
        .target_fps = 59.826, // NTSC progressive (rhi_intf.h). PAL games report 49.761.
        .native_sample_rate = 44100,
        .state_version = 9386, // MEDNAFEN_VERSION_NUMERIC, which upstream writes into every state's header.
    };
    return &interface;
}
