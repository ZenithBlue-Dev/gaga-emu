// Beetle NeoPop behind the GagaBridge interface, through the shared libretro adapter. It runs Neo Geo Pocket
// and Neo Geo Pocket Color cartridges with its own high-level BIOS, so no SNK BIOS is needed or bundled.
// Game saves are the cartridge's flash blocks, which upstream keeps in <save folder>/<game>.flash.
#include "LibretroAdapter.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// From upstream's mednafen/ngp/flash.h and system.h, whose own includes need the core's build setup.
uint8_t* make_flash_commit(int32_t* length);
bool system_io_flash_write(uint8_t* buffer, uint32_t buffer_length);

static const GagaLibretroVariable s_variables[] = {
    { "ngp_language", "english" },
    { NULL, NULL },
};

// The header is 64 bytes, which upstream reads without a size check. The start address must be in the
// cartridge's first 2 MB at 0x200000, where its BIOS jumps. Cartridges go up to 32 Mbit.
static bool ngp_is_rom(const uint8_t* data, size_t size) {
    if (size < 0x40 || size > (4u << 20)) return false;
    uint32_t start = (uint32_t)data[0x1C] | (uint32_t)data[0x1D] << 8 | (uint32_t)data[0x1E] << 16;
    return start >= 0x200000 && start < 0x400000;
}

// Upstream writes flash only when the game unloads. This writes it at each flush as well, when it changed,
// so a crash keeps what the last flush saw.
static uint8_t* s_written;
static int32_t s_written_length;

static bool ngp_save_battery(void) {
    int32_t length = 0;
    uint8_t* data = make_flash_commit(&length);
    if (!data) return true; // Nothing written to flash yet.
    if (s_written && length == s_written_length && memcmp(data, s_written, (size_t)length) == 0) {
        free(data);
        return true;
    }
    bool ok = system_io_flash_write(data, (uint32_t)length);
    free(s_written);
    s_written = ok ? data : NULL;
    s_written_length = ok ? length : 0;
    if (!ok) free(data);
    return ok;
}

static void ngp_after_deinit(void) {
    free(s_written);
    s_written = NULL;
    s_written_length = 0;
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Beetle NeoPop",
    .game_kind = "a Neo Geo Pocket game",
    .variables = s_variables,
    .is_rom = ngp_is_rom,
    .save_battery = ngp_save_battery,
    .after_deinit = ngp_after_deinit,
};

// No cheat entry points: upstream's retro_cheat_set does nothing.
const GagaCoreInterface* BeetleNgp_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "beetle_ngp",
        .core_name = "Beetle NeoPop",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "ngp|ngc|ngpc|npc", // MEDNAFEN_CORE_EXTENSIONS in libretro.c.
        .target_fps = 60.25,         // MEDNAFEN_CORE_TIMING_FPS.
        .native_sample_rate = 44100, // retro_get_system_av_info.
        .state_version = 931,        // MEDNAFEN_VERSION_NUMERIC, which MDFNSS_SaveSM writes at byte 16 of its header.
    };
    return &interface;
}
