// PrBoom (Doom, Heretic, Hexen engine) behind the GagaBridge interface, through the shared libretro adapter. The game
// WAD is the player's: no IWAD is bundled. PrBoom's own engine lumps (prboom.wad, GPL) are compiled into upstream's
// d_main.c. A PWAD looks for its IWAD (doom2.wad, freedoom2.wad and so on) in its own folder and the system folder.
// Savegames and prboom.cfg go to <save directory>/<game name>/, written by upstream. Upstream has no cheat interface.
#include "LibretroAdapter.h"
#include "libretro.h"

// Every option upstream defines (libretro_core_options.h), at upstream's default unless marked. GagaEmu's changes: no
// IWAD search up through parent folders, audio at the app's 48 kHz.
static const GagaLibretroVariable s_variables[] = {
    { "prboom-resolution", "320x200" },
    { "prboom-render_threads", "OFF" }, // Built without HAVE_THREADS, so this has no effect.
    { "prboom-color_format", "16bits" },
    { "prboom-hdr_emissive", "2x" },
    { "prboom-mouse_on", "disabled" },
    { "prboom-wall_decals", "disabled" },
    { "prboom-dynlight_wall_falloff", "disabled" },
    { "prboom-find_recursive_on", "disabled" }, // GagaEmu
    { "prboom-rumble", "disabled" },
    { "prboom-mmap_wads", "disabled" },
    { "prboom-analog_deadzone", "15" },
    { "prboom-purge_limit", "16" },
    { "prboom-complevel", "-1" },
    { "prboom-sound_samplerate", "48000" }, // GagaEmu
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "PrBoom",
    .game_kind = "a Doom WAD",
    .variables = s_variables,
};

// The shared adapter names no device for the port; this is upstream's own fallback, the classic RetroPad layout.
static bool prboom_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    return gaga_lr_load_rom(inst, rom_path, rom_data, rom_size);
}

const GagaCoreInterface* Prboom_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .load_rom = prboom_load_rom,
        .core_id = "prboom",
        .core_name = "PrBoom",
        .core_version = GAGA_CORE_VERSION,
        // Upstream also takes .iwad, .pwad, .lmp (demos), .pk3, .ipk3, .m3u (taken by disc platforms here) and .zip.
        .supported_extensions = "wad",
        .target_fps = 60.0,             // PrBoom's "uncapped_framerate" default (3); 35 Hz is the original tic rate.
        .native_sample_rate = 48000,    // prboom-sound_samplerate above.
        .state_version = 1,
    };
    return &interface;
}
