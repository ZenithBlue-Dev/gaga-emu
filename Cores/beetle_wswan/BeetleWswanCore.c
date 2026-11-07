// Beetle WonderSwan behind the GagaBridge interface, through the shared libretro adapter. It runs WonderSwan
// and WonderSwan Color cartridges from reset with no boot ROM, so no Bandai firmware is needed or bundled.
// The app is landscape only, so a vertical game turns upright inside the landscape screen: upstream's manual
// rotation, on Select, which the console does not have. Its keymap follows the picture.
#include "LibretroAdapter.h"

#include <stdlib.h>
#include <string.h>

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "wswan_rotate_display", "manual" },
    { "wswan_rotate_keymap", "auto" },
    { "wswan_60hz_mode", "enabled" }, // Every fifth frame of 75.47 dropped, for a 60 Hz screen.
    { "wswan_sound_sample_rate", "44100" },
    { "wswan_gfx_colors", "16bit" },
    { "wswan_frameskip", "disabled" },
    { NULL, NULL },
};

// Upstream's own check in Load(): at least 64 KB. The footer is the last 10 bytes.
static bool wswan_is_rom(const uint8_t* data, size_t size) {
    (void)data;
    return size >= 65536 && size <= (16u << 20);
}

static bool wswan_is_hex(char c) { return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'); }

// Upstream's raw code AAAAA:VV, one to five address digits. It ignores an address outside RAM without saying
// so, so those are refused here. SRAM codes, which upstream takes only on a cartridge with SRAM, are not offered.
static bool wswan_is_cheat(const char* line) {
    const char* colon = strchr(line, ':');
    size_t digits = colon ? (size_t)(colon - line) : 0;
    if (digits < 1 || digits > 5 || strlen(colon + 1) != 2 || !wswan_is_hex(colon[1]) || !wswan_is_hex(colon[2])) return false;
    for (size_t i = 0; i < digits; ++i) {
        if (!wswan_is_hex(line[i])) return false;
    }
    return strtoul(line, NULL, 16) < 0x10000;
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle WonderSwan",
    .game_kind = "a WonderSwan game",
    .variables = s_variables,
    .is_rom = wswan_is_rom,
    .is_cheat = wswan_is_cheat,
};

const GagaCoreInterface* BeetleWswan_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "beetle_wswan",
        .core_name = "Beetle WonderSwan",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "ws|wsc|pc2", // MEDNAFEN_CORE_EXTENSIONS in libretro.c.
        .target_fps = 60.38,         // RETRO_60HZ_FPS, four fifths of 3072000 / (159 * 256).
        .native_sample_rate = 44100, // RETRO_SAMPLE_RATE at the option above.
        .state_version = 931,        // MEDNAFEN_VERSION_NUMERIC, which MDFNSS_SaveSM writes at byte 16 of its header.
    };
    return &interface;
}
