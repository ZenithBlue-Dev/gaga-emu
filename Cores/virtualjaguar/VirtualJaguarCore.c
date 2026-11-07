// Virtual Jaguar (Atari Jaguar) behind the GagaBridge interface, through the shared libretro adapter. No boot ROM is
// compiled in (bios_stub.c): carts boot by upstream's HLE, and "custom" boot ROM type loads the player's own
// jagboot.rom from the system folder into the BIOS window when present. Cart EEPROM goes through SAVE_RAM, so the
// adapter keeps it in the game's .sav. JagLink, the GDB stub and voice chat are built without sockets (nonet_*.c).
#include "LibretroAdapter.h"

// Upstream's spelling (libretro_core_options.h). Everything that writes extra files or opens the network is off.
static const GagaLibretroVariable s_variables[] = {
    { "virtualjaguar_bios", "disabled" },
    { "virtualjaguar_bios_type", "custom" },
    { "virtualjaguar_pal", "disabled" },
    { "virtualjaguar_usefastblitter", "disabled" },
    { "virtualjaguar_frameskip", "disabled" },
    { "virtualjaguar_enhancement_hooks", "disabled" },
    { "virtualjaguar_netlink", "disabled" },
    { "virtualjaguar_voice_chat", "disabled" },
    { "virtualjaguar_gdb_stub", "disabled" },
    { "virtualjaguar_texture_dump", "disabled" },
    { "virtualjaguar_texture_replace", "disabled" },
    { "virtualjaguar_jgd", "disabled" },
    { "virtualjaguar_p1_device", "pad" },
    { "virtualjaguar_p2_device", "pad" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Virtual Jaguar",
    .game_kind = "an Atari Jaguar game",
    .variables = s_variables,
};

const GagaCoreInterface* VirtualJaguar_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "virtualjaguar",
        .core_name = "Virtual Jaguar",
        .core_version = GAGA_CORE_VERSION,
        // Cartridges only. Upstream also takes .rom, .abs, .cof, .bin, .prg and CD images; those clash with other
        // platforms here or need the player's Jaguar CD BIOS.
        .supported_extensions = "j64|jag",
        .target_fps = 60.05,            // JaguarGetFieldRateHz for NTSC.
        .native_sample_rate = 48044,    // 800 samples a field (BUFNTSC / 2) at 60.054 Hz.
        .state_version = 1,
    };
    return &interface;
}
