// PUAE (Commodore Amiga) behind the GagaBridge interface, through the shared libretro adapter. Kickstart is the
// player's (kick34005.A500 and the other names upstream looks for, in the system folder); without one, upstream boots
// its built-in AROS replacement. WHDLoad's bundled Amiga files and the HRTmon ROM are not built (retrodep/, stubs),
// so .lha is not offered. The keyboard is polled through GagaInputState.keys. The adapter has no mouse device: the
// Amiga mouse moves with the analog sticks, and L2/R2 are its buttons (upstream's RetroPad defaults).
#include "LibretroAdapter.h"
#include "libretro.h"

// Every option upstream defines (libretro-core.c option_defs_us), at upstream's default unless marked; upstream reads
// an unset option as 0. GagaEmu's changes: floppies write-protected so the player's files are never changed, no
// WHDLoad, no shared NVRAM file, no floppy sounds, RGB565, no physical-mouse polling.
static const GagaLibretroVariable s_variables[] = {
    { "puae_model", "auto" },
    { "puae_model_options_display", "disabled" },
    { "puae_model_fd", "A500" },
    { "puae_model_hd", "A1200" },
    { "puae_model_cd", "CD32" },
    { "puae_kickstart", "auto" }, // GagaEmu
    { "puae_chipmem_size", "auto" },
    { "puae_bogomem_size", "auto" },
    { "puae_fastmem_size", "auto" },
    { "puae_z3mem_size", "auto" },
    { "puae_cpu_model", "auto" },
    { "puae_fpu_model", "auto" },
    { "puae_cpu_throttle", "0.0" },
    { "puae_cpu_multiplier", "0" },
    { "puae_cpu_compatibility", "normal" },
    { "puae_immediate_blits", "waiting" },
    { "puae_collision_level", "playfields" },
    { "puae_autoloadfastforward", "disabled" },
    { "puae_floppy_speed", "100" },
    { "puae_floppy_multidrive", "enabled" },
    { "puae_floppy_write_protection", "enabled" }, // GagaEmu
    { "puae_floppy_write_redirect", "disabled" },
    { "puae_cd_speed", "100" },
    { "puae_cd_startup_delayed_insert", "disabled" },
    { "puae_shared_nvram", "disabled" }, // GagaEmu
    { "puae_use_whdload", "disabled" }, // GagaEmu
    { "puae_use_whdload_theme", "default" },
    { "puae_use_whdload_prefs", "disabled" },
    { "puae_use_whdload_buttonwait", "enabled" },
    { "puae_use_whdload_nowritecache", "disabled" },
    { "puae_use_boot_hd", "disabled" },
    { "puae_cart_file", "none" }, // GagaEmu
    { "puae_video_options_display", "disabled" },
    { "puae_video_allow_hz_change", "locked" },
    { "puae_video_standard", "PAL auto" },
    { "puae_video_aspect", "auto" },
    { "puae_video_resolution", "auto" },
    { "puae_video_vresolution", "auto" },
    { "puae_crop", "disabled" },
    { "puae_crop_delay", "enabled" },
    { "puae_crop_mode", "both" },
    { "puae_vertical_pos", "auto" },
    { "puae_horizontal_pos", "auto" },
    { "puae_gfx_flickerfixer", "disabled" },
    { "puae_gfx_framerate", "disabled" },
    { "puae_gfx_gamma", "0" },
    { "puae_gfx_colors", "16bit" }, // GagaEmu
    { "puae_vkbd_theme", "auto" },
    { "puae_vkbd_transparency", "25%" },
    { "puae_vkbd_dimming", "25%" },
    { "puae_statusbar", "bottom" },
    { "puae_statusbar_startup", "disabled" },
    { "puae_statusbar_messages", "disabled" },
    { "puae_joyport_pointer_color", "blue" },
    { "puae_audio_options_display", "disabled" },
    { "puae_sound_stereo_separation", "100%" },
    { "puae_sound_interpol", "anti" },
    { "puae_sound_filter", "emulated" },
    { "puae_sound_filter_type", "auto" },
    { "puae_floppy_sound", "100" }, // GagaEmu
    { "puae_floppy_sound_empty_mute", "enabled" },
    { "puae_floppy_sound_type", "internal" },
    { "puae_sound_volume_cd", "100%" },
    { "puae_analogmouse", "both" },
    { "puae_analogmouse_deadzone", "20" },
    { "puae_analogmouse_speed", "1.0" },
    { "puae_dpadmouse_speed", "6" },
    { "puae_mouse_speed", "100" },
    { "puae_physicalmouse", "disabled" }, // GagaEmu
    { "puae_physical_keyboard_pass_through", "disabled" },
    { "puae_keyrah_keypad_mappings", "disabled" },
    { "puae_mapping_options_display", "enabled" },
    { "puae_mapper_vkbd", "---" },
    { "puae_mapper_statusbar", "RETROK_F12" },
    { "puae_mapper_mouse_toggle", "RETROK_RCTRL" },
    { "puae_mapper_turbo_fire_toggle", "---" },
    { "puae_mapper_save_disk_toggle", "---" },
    { "puae_mapper_aspect_ratio_toggle", "---" },
    { "puae_mapper_crop_toggle", "---" },
    { "puae_mapper_reset", "---" },
    { "puae_mapper_up", "---" },
    { "puae_mapper_down", "---" },
    { "puae_mapper_left", "---" },
    { "puae_mapper_right", "---" },
    { "puae_mapper_b", "---" },
    { "puae_mapper_a", "---" },
    { "puae_mapper_y", "---" },
    { "puae_mapper_x", "RETROK_SPACE" },
    { "puae_mapper_select", "TOGGLE_VKBD" },
    { "puae_mapper_start", "---" },
    { "puae_mapper_l", "---" }, // GagaEmu
    { "puae_mapper_r", "---" }, // GagaEmu
    { "puae_mapper_l2", "MOUSE_LEFT_BUTTON" },
    { "puae_mapper_r2", "MOUSE_RIGHT_BUTTON" },
    { "puae_mapper_l3", "---" },
    { "puae_mapper_r3", "---" },
    { "puae_mapper_lu", "---" },
    { "puae_mapper_ld", "---" },
    { "puae_mapper_ll", "---" },
    { "puae_mapper_lr", "---" },
    { "puae_mapper_ru", "---" },
    { "puae_mapper_rd", "---" },
    { "puae_mapper_rl", "---" },
    { "puae_mapper_rr", "---" },
    { "puae_turbo_fire", "disabled" },
    { "puae_turbo_fire_button", "B" },
    { "puae_turbo_pulse", "6" },
    { "puae_joyport", "joystick" }, // GagaEmu
    { "puae_joyport_order", "1234" },
    { "puae_retropad_options", "disabled" },
    { "puae_cd32pad_options", "disabled" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "PUAE",
    .game_kind = "an Amiga game",
    .variables = s_variables,
};

// Upstream reads no joystick until the frontend names a device for the port, and the shared adapter names none:
// a RetroPad on both ports, as RetroArch sets by default.
static bool puae_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    retro_set_controller_port_device(1, RETRO_DEVICE_JOYPAD);
    return gaga_lr_load_rom(inst, rom_path, rom_data, rom_size);
}

const GagaCoreInterface* Puae_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .load_rom = puae_load_rom,
        .core_id = "puae",
        .core_name = "PUAE",
        .core_version = GAGA_CORE_VERSION,
        // Upstream also takes .adz, .dms, .ipf, CD images, .lha (WHDLoad, not built), .m3u (taken by disc platforms
        // here) and archives.
        .supported_extensions = "adf|hdf",
        .target_fps = 50.0,             // PAL.
        .native_sample_rate = 44100,
        .state_version = 1,
    };
    return &interface;
}
