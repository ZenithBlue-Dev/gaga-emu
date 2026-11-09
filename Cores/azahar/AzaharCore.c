// Azahar (Nintendo 3DS) behind the GagaBridge interface, through the shared libretro adapter and its Vulkan
// layer path. Upstream's own libretro frontend (src/citra_libretro) is the core.
// No JIT anywhere (docs/04): the ARM11 runs the dyncom interpreter and PICA200 vertex shaders run in
// shader_interpreter.cpp. Dynarmic and the shader JIT are not compiled (core.env), and flags.h stops the
// source from choosing them. Video is Azahar's Vulkan renderer on MoltenVK; GPU shaders are SPIR-V that
// MoltenVK turns into Metal, never CPU code.
// Only decrypted games and homebrew run. No console keys, firmware or system files ship (ENABLE_BUILTIN_KEYBLOB
// is off); Azahar's own open-source system archives stand in for the shared font and Mii data.
#include "LibretroAdapter.h"
#include "LibretroVulkan.h"
#include <ctype.h>
#include <stdio.h>
#include <string.h>

// Azahar returns no RETRO_MEMORY_SAVE_RAM: the emulated 3DS writes its save data, extdata and SD card as files
// under <game's save folder>/Azahar/ through stdio. Pushing every buffered write out on each flush (pause,
// background, quit and the periodic one) means a kill after pause loses nothing.
// shortcut: fflush reaches the kernel, not the disk (no fsync), enough for an app kill, not for power loss.
static bool azahar_save_battery(void) {
    return fflush(NULL) == 0;
}

// Option values are upstream's spelling (upstream/src/citra_libretro/core_settings.cpp).
static const GagaLibretroVariable s_variables[] = {
    // Read as off already: no JIT is compiled. Listed so the settings never claim one.
    { "citra_use_cpu_jit", "disabled" },
    { "citra_use_shader_jit", "disabled" },
    { "citra_graphics_api", "Vulkan" },
    // Both screens in one picture, top screen left and bottom screen right, as melonDS DS draws the DS. A
    // finger on the right half reaches the touch screen through the libretro pointer.
    { "citra_layout_option", "side_by_side" },
    { "citra_swap_screen", "Top" },
    // The right stick is the C-Stick only, so it never moves an on-screen touch cursor.
    { "citra_analog_function", "c_stick" },
    // No microphone, no motion sensor: the app asks for neither.
    { "citra_input_type", "none" },
    { "citra_enable_motion", "disabled" },
    { "citra_enable_mouse_touchscreen", "disabled" },
    { "citra_render_3d", "off" },
    { "citra_custom_textures", "disabled" },
    { "citra_dump_textures", "disabled" },
    // Saves, the virtual SD card and the shader cache live in <save dir>/Azahar.
    { "citra_use_libretro_save_path", "LibRetro Default" },
    // Upstream's defaults, listed so they stay: the disk cache keeps compiled pipelines across launches, and 1x
    // is the 3DS's own 400x240. citra_cpu_clock_percentage is left at upstream's 100.
    { "citra_use_disk_shader_cache", "enabled" },
    { "citra_resolution_factor", "1" },
    { NULL, NULL },
};

const char* gaga_azahar_finish_load(void); // AzaharSupport.cpp: asynchronous shader compilation.
void gaga_azahar_before_present(void);     // AzaharSupport.cpp: the frame's draw is submitted before the copy.

// Citra picks a loader by the file's magic and falls back to the extension, so a .3dsx with no 3DSX header reached
// the 3DSX loader and stopped the app in an assert (SetupMainThread, device run 5). Only files that carry one of
// the magics a loader checks are passed on.
// Azahar loads no encrypted NCCH, keys or not: NCCHContainer::Load returns ErrorEncrypted when NoCrypto is clear,
// and keys.txt in its sysdata folder only serves system data. Device run 13: three encrypted dumps gave no
// message for minutes, so they are refused here from the header. NoCrypto is bit 2 of the NCCH flags byte at
// 0x18F (upstream/src/core/file_sys/ncch_container.h). An NCSD (.3ds, .cci) holds the game's NCCH in
// partition 0, whose offset at 0x120 counts 0x200-byte media units.
static bool azahar_encrypted(FILE* file, const uint8_t* head) {
    uint8_t ncch[0x200];
    if (memcmp(head + 0x100, "NCSD", 4) == 0) {
        uint32_t units = (uint32_t)head[0x120] | (uint32_t)head[0x121] << 8 | (uint32_t)head[0x122] << 16 |
                         (uint32_t)head[0x123] << 24;
        // An NCCH that cannot be read is left to Azahar's own loader, which refuses it.
        if (fseeko(file, (off_t)units * 0x200, SEEK_SET) != 0 || fread(ncch, 1, sizeof(ncch), file) != sizeof(ncch) ||
            memcmp(ncch + 0x100, "NCCH", 4) != 0) return false;
        head = ncch;
    }
    return (head[0x18F] & 0x04) == 0;
}

static const char* azahar_refuse_load(const char* system_dir, const char* rom_path) {
    (void)system_dir;
    uint8_t head[0x200] = { 0 };
    FILE* file = fopen(rom_path, "rb");
    size_t got = file ? fread(head, 1, sizeof(head), file) : 0;
    const char* refusal = "This file is not a decrypted Nintendo 3DS game or 3DS homebrew.";
    if (got >= 4 && (memcmp(head, "3DSX", 4) == 0 || memcmp(head, "\x7f" "ELF", 4) == 0)) {
        refusal = NULL;
    } else if (got == sizeof(head) && (memcmp(head + 0x100, "NCSD", 4) == 0 || memcmp(head + 0x100, "NCCH", 4) == 0)) {
        refusal = azahar_encrypted(file, head) ? "This 3DS game is encrypted. GagaEmu plays decrypted dumps only." : NULL;
    }
    if (file) fclose(file);
    return refusal;
}

void gaga_azahar_cheat_reset(void);                                     // AzaharSupport.cpp: Azahar's Gateway engine.
void gaga_azahar_cheat_set(unsigned index, bool enabled, const char* code);

// One Gateway line: XXXXXXXX YYYYYYYY. The engine ignores what it cannot run, so the shape is checked here.
static bool azahar_is_cheat(const char* line) {
    for (int i = 0; i < 17; ++i) {
        if (i == 8 ? line[i] != ' ' : !isxdigit((unsigned char)line[i])) return false;
    }
    return line[17] == '\0';
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "Azahar",
    .is_cheat = azahar_is_cheat,
    .cheat_lines_are_one_code = true,
    .cheat_reset = gaga_azahar_cheat_reset,
    .cheat_set = gaga_azahar_cheat_set,
    .refuse_load = azahar_refuse_load,
    .game_kind = "a decrypted Nintendo 3DS game or 3DS homebrew",
    .variables = s_variables,
    // retro_serialize_size returns the size of a fresh, compressed state each time.
    .state_size_varies = true,
    .save_battery = azahar_save_battery,
    .finish_load = gaga_azahar_finish_load,
    .before_present = gaga_azahar_before_present,
};

const GagaCoreInterface* Azahar_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "azahar",
        .core_name = "Azahar",
        .core_version = GAGA_CORE_VERSION,
        // upstream's valid_extensions without the compressed z3dsx, zcci and zcxi forms.
        .supported_extensions = "3ds|3dsx|cci|cxi|app|elf|axf",
        .target_fps = 60.0,           // retro_get_system_av_info.
        .native_sample_rate = 32728,  // AudioCore::native_sample_rate.
        .state_version = 21262,       // Azahar refuses states from another build; this is release 2126.2.
    };
    return &interface;
}
