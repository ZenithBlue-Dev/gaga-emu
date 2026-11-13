// melonDS DS behind the GagaBridge interface, through the shared libretro adapter.
// Built-In mode uses melonDS's own free BIOS and generated firmware, so no Nintendo file is ever read,
// and Built-In mode can only boot a game directly. DS mode only: DSi mode needs native files.
#include "LibretroAdapter.h"

#include <string.h>

// Option values are upstream's spelling (config/constants.hpp). Landscape only, so the two screens sit
// side by side, top screen left, with no gap and no second layout for R3 to cycle to. The lower screen
// takes the touch, and the frame passed to the host is the whole layout, so the host sends the pointer
// in that frame's coordinates and the core maps it onto the lower screen.
static const GagaLibretroVariable s_variables[] = {
    { "melonds_console_mode", "ds" },
    { "melonds_sysfile_mode", "builtin" },
    { "melonds_boot_mode", "direct" },
    { "melonds_firmware_username", "guess_username" }, // Unset falls back to "melonDS DS"; this asks for the player name.
    { "melonds_render_mode", "software" },
    { "melonds_screen_layout1", "left-right" },
    { "melonds_number_of_screen_layouts", "1" },
    { "melonds_screen_gap", "0" },
    { "melonds_touch_mode", "touch" }, // Pointer only: the right stick and R2 do not move a cursor.
    { "melonds_show_cursor", "disabled" }, // A finger is the cursor. A drawn one would also change the picture.
    { "melonds_show_bios_warnings", "disabled" },
#ifdef GAGA_CORE_JIT
    // Sideload JIT build (jit.env): upstream's default is "enabled". LibretroAdapterJit26.c serves "enabled" only
    // when Cores/shared/Jit26.c has runnable memory.
    { "melonds_jit_enable", "disabled" },
#endif
    { NULL, NULL },
};

static uint16_t melonds_crc16(const uint8_t* data, size_t size) {
    uint16_t crc = 0xFFFF;
    for (size_t i = 0; i < size; ++i) {
        crc ^= data[i];
        for (int bit = 0; bit < 8; ++bit) crc = (crc & 1) ? (uint16_t)((crc >> 1) ^ 0xA001) : (uint16_t)(crc >> 1);
    }
    return crc;
}

static uint32_t melonds_u32(const uint8_t* data) {
    return (uint32_t)data[0] | (uint32_t)data[1] << 8 | (uint32_t)data[2] << 16 | (uint32_t)data[3] << 24;
}

// The header CRC a real DS checks, and melonDS's own ValidateROM limits on where the two binaries are.
static bool melonds_is_rom(const uint8_t* data, size_t size) {
    if (size < 0x1000 || size > 512u * 1024 * 1024) return false;
    if (melonds_crc16(data, 0x15E) != (uint16_t)(data[0x15E] | data[0x15F] << 8)) return false;
    uint64_t arm9 = melonds_u32(data + 0x20), arm9_size = melonds_u32(data + 0x2C);
    uint64_t arm7 = melonds_u32(data + 0x30), arm7_size = melonds_u32(data + 0x3C);
    return arm9 >= 0x200 && arm9 + arm9_size <= size && arm7 >= 0x200 && arm7 + arm7_size <= size;
}

static bool melonds_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// Action Replay DS, one "XXXXXXXX YYYYYYYY" pair per line. The lines of one cheat reach the core as one
// code, because AR conditionals span lines.
static bool melonds_is_cheat(const char* line) {
    return strlen(line) == 17 && line[8] == ' ' && melonds_is_hex(line, 8) && melonds_is_hex(line + 9, 8);
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "melonDS DS",
    .game_kind = "a Nintendo DS game",
    .variables = s_variables,
    .is_rom = melonds_is_rom,
    .is_cheat = melonds_is_cheat,
    .cheat_lines_are_one_code = true,
};

const GagaCoreInterface* MelonDS_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "melonds_ds",
        .core_name = "melonDS DS",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "nds",
        .target_fps = 33513982.0 / 560190.0, // 59.8261: the ARM7 clock over its cycles per frame.
        .native_sample_rate = 32728,         // The clock over 1024, rounded as the adapter rounds it.
        .state_version = 14,                 // melonDS's SAVESTATE_MAJOR, after "MELN". A test checks it against real bytes.
    };
    return &interface;
}
