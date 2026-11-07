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
#include <stdio.h>

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
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "Azahar",
    .game_kind = "a decrypted Nintendo 3DS game or 3DS homebrew",
    .variables = s_variables,
    // retro_serialize_size returns the size of a fresh, compressed state each time.
    .state_size_varies = true,
    .save_battery = azahar_save_battery,
};

const GagaCoreInterface* Azahar_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
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
