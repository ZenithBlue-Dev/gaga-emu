// Flycast behind the GagaBridge interface, through the shared libretro adapter and its Vulkan layer path.
// No JIT anywhere (docs/04): TARGET_NO_REC builds the SH-4 interpreter, the ARM7 interpreter and the
// AICA DSP interpreter only, and no recompiler file is compiled (core.env). Video is Flycast's Vulkan
// renderer on MoltenVK. A player-supplied BIOS in System/dc is used when present; otherwise Flycast's
// HLE BIOS (reios) boots the disc, so no BIOS ships.
#include "LibretroAdapter.h"
#include "LibretroVulkan.h"

void gaga_flycast_check_vram(void);       // FlycastSupport.cpp
void gaga_flycast_upstream_retro_run(void); // Flycast's retro_run, renamed by flags.h

// The adapter calls this once per frame.
void retro_run(void) {
    gaga_flycast_check_vram();
    gaga_flycast_upstream_retro_run();
}

// Option values are upstream's spelling (upstream/shell/libretro/libretro_core_options.h).
static const GagaLibretroVariable s_variables[] = {
    // A BIOS in System/dc wins; without one Flycast falls back to reios on its own (emulator.cpp).
    { "reicast_hle_bios", "disabled" },
    // One thread: the frame is drawn inside retro_run, after gaga_flycast_check_vram.
    { "reicast_threaded_rendering", "disabled" },
    // The bridge's triggers are buttons. Flycast would otherwise read analog trigger values, always 0.
    { "reicast_digital_triggers", "enabled" },
    { "reicast_internal_resolution", "640x480" },
    // Per-pixel sorting is the order-independent transparency renderer, which needs more than MoltenVK offers.
    { "reicast_alpha_sorting", "per-triangle (normal)" },
    // VMU A1 is saved per game in the save folder; the others stay in System/dc.
    { "reicast_per_content_vmus", "VMU A1" },
    { "reicast_emulate_bba", "disabled" },
    { "reicast_dcnet", "disabled" },
    { "reicast_upnp", "disabled" },
    { "reicast_network_output", "disabled" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Flycast",
    .game_kind = "a Dreamcast game",
    .variables = s_variables,
};

const GagaCoreInterface* Flycast_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
        .core_id = "flycast",
        .core_name = "Flycast",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "gdi|cdi|chd|cue", // A .cue import reaches Dreamcast through its IP.BIN (AppState).
        .target_fps = 59.9453,        // retro_get_system_av_info for NTSC. PAL reports 50.
        .native_sample_rate = 44100,  // The AICA's rate, as retro_get_system_av_info reports it.
        .state_version = 854,         // Serializer::Current (V59) in upstream's core/serialize.h.
    };
    return &interface;
}
