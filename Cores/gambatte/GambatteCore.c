// Gambatte behind the GagaBridge interface, through the shared libretro adapter.
// The bootloader option stays off, so no Nintendo boot ROM is ever read and the core starts from its
// own post-boot state. Nothing checks the cartridge logo.
#include "LibretroAdapter.h"

#include <cc_resampler.h>

#include <string.h>

// Option values are upstream's spelling. Colourisation off shows a mono game in greys.
static const GagaLibretroVariable s_variables[] = {
    { "gambatte_gb_bootloader", "disabled" },
    { "gambatte_gb_hwmode", "Auto" },
    { "gambatte_gb_colorization", "disabled" },
    { "gambatte_gbc_color_correction", "GBC only" },
    { "gambatte_mix_frames", "disabled" },
    { "gambatte_up_down_allowed", "disabled" },
    { NULL, NULL },
};

// upstream/libgambatte/libretro/cc_resampler.c says GPLv3 while Gambatte says GPL-2.0, so it is not
// compiled (docs/03 section 5). The core picks this resampler only if its default one fails to
// allocate, and then the game runs silent.
void CC_init(void) {}
void CC_renderaudio(audio_frame_t* sound_buf, unsigned samples) {
    (void)sound_buf;
    (void)samples;
}

// The header's complement check, which a real Game Boy boot also makes. The logo is never compared.
static bool gambatte_is_rom(const uint8_t* data, size_t size) {
    if (size < 0x150) return false;
    uint8_t sum = 0;
    for (size_t i = 0x134; i <= 0x14C; ++i) sum = (uint8_t)(sum - data[i] - 1);
    return sum == data[0x14D];
}

static bool gambatte_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// GameShark 01VVLLHH: the core ignores every other type, so those are refused rather than doing nothing.
// Game Genie VVA-AAA or VVA-AAA-CCC.
static bool gambatte_is_cheat(const char* line) {
    size_t length = strlen(line);
    if (length == 8) return line[0] == '0' && line[1] == '1' && gambatte_is_hex(line, 8);
    if (length != 7 && length != 11) return false;
    if (line[3] != '-' || !gambatte_is_hex(line, 3) || !gambatte_is_hex(line + 4, 3)) return false;
    return length == 7 || (line[7] == '-' && gambatte_is_hex(line + 8, 3));
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Gambatte",
    .game_kind = "a Game Boy or Game Boy Color game",
    .variables = s_variables,
    .is_rom = gambatte_is_rom,
    .is_cheat = gambatte_is_cheat,
};

const GagaCoreInterface* Gambatte_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "gambatte",
        .core_name = "Gambatte",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "gb|gbc",
        .target_fps = 4194304.0 / 70224.0, // 59.7275: the clock over its cycles per frame.
        .native_sample_rate = 32768,       // The clock over 128, from upstream's default resampler.
        .state_version = 1,                // Byte 1 of the core's own state. A test checks this against real bytes.
    };
    return &interface;
}
