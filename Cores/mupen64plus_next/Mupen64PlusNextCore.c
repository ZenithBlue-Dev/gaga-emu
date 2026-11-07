// Mupen64Plus-Next behind the GagaBridge interface, through the shared libretro adapter and its Vulkan
// layer path. No JIT anywhere (docs/04): the R4300 is the pure interpreter, the RSP is cxd4 (an
// interpreter), and video is paraLLEl-RDP's Vulkan compute renderer on MoltenVK. The PIF boot is the
// core's HLE (bootrom_hle.c), so no PIF ROM is read.
#include "LibretroAdapter.h"
#include "LibretroVulkan.h"

#include <string.h>

// Option values are upstream's spelling (upstream/libretro/libretro_core_options.h).
static const GagaLibretroVariable s_variables[] = {
    { "mupen64plus-rdp-plugin", "parallel" },
    { "mupen64plus-rsp-plugin", "cxd4" },
    { "mupen64plus-cpucore", "pure_interpreter" },
    { "mupen64plus-ThreadedRenderer", "False" },
    { NULL, NULL },
};

// The first word of a cartridge image in its three byte orders: big-endian .z64, byte-swapped .v64 and
// little-endian .n64. The core converts the other two itself.
static bool mupen_is_rom(const uint8_t* data, size_t size) {
    if (size < 0x1000) return false;
    uint32_t word = (uint32_t)data[0] << 24 | (uint32_t)data[1] << 16 | (uint32_t)data[2] << 8 | data[3];
    return word == 0x80371240u || word == 0x37804012u || word == 0x40123780u;
}

static bool mupen_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// GameShark "XXXXXXXX YYYY", one per line. retro_cheat_set pairs any hex runs it finds and cannot refuse,
// so anything else is refused here rather than read as some other address.
static bool mupen_is_cheat(const char* line) {
    return strlen(line) == 13 && line[8] == ' ' && mupen_is_hex(line, 8) && mupen_is_hex(line + 9, 4);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Mupen64Plus-Next",
    .game_kind = "a Nintendo 64 game",
    .variables = s_variables,
    .is_rom = mupen_is_rom,
    .is_cheat = mupen_is_cheat,
};

const GagaCoreInterface* Mupen64PlusNext_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "mupen64plus_next",
        .core_name = "Mupen64Plus-Next",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "n64|v64|z64",
        .target_fps = 60.0,           // vi_expected_refresh_rate_from_tv_standard for NTSC. PAL reports 50.
        .native_sample_rate = 44100,  // audio_backend_libretro.c resamples to this.
        .state_version = 0x00010900,  // savestate_latest_version in upstream's savestates.c, bytes 8 to 11 of a state.
    };
    return &interface;
}
