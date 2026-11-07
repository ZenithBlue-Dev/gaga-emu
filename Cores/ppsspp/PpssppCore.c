// PPSSPP behind the GagaBridge interface, through the shared libretro adapter and its Vulkan layer path.
// No JIT anywhere (docs/04): the Allegrex runs on upstream's IR interpreter, every JIT back end and code
// emitter is left out of the build (generate.py), and video is PPSSPP's Vulkan renderer on MoltenVK. The PSP
// operating system is upstream's HLE, so no firmware is read.
#include "LibretroAdapter.h"
#include "LibretroVulkan.h"

// Option values are upstream's spelling (upstream/libretro/libretro_core_options.h).
static const GagaLibretroVariable s_variables[] = {
    { "ppsspp_cpu_core", "IR JIT" },  // "IR JIT" is the IR interpreter; the frontend reports no JIT either.
    { "ppsspp_backend", "vulkan" },
    { "ppsspp_internal_resolution", "480x272" },
    { "ppsspp_enable_wlan", "disabled" },
    { "ppsspp_enable_upnp", "disabled" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "PPSSPP",
    .game_kind = "a PSP game",
    .variables = s_variables,
};

const GagaCoreInterface* Ppsspp_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
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
