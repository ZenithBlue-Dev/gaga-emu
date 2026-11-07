// VICE x64sc (Commodore 64) behind the GagaBridge interface, through the shared libretro adapter. No Commodore ROM
// is compiled in (vice_embedded.c): the player's kernal-901227-03.bin, basic-901226-01.bin and
// chargen-901225-01.bin load from the system folder (vice_sysfile.c). True drive emulation is off, so disks load
// through VICE's KERNAL traps and no 1541 ROM is needed. The keyboard is polled through GagaInputState.keys.
#include "LibretroAdapter.h"
#include "libretro.h"

#include <stdio.h>
#include <unistd.h>

// Every option upstream defines for x64sc (libretro-core.c option_defs_us), at upstream's default unless marked:
// upstream reads an unset option as 0, which turns the palette black. GagaEmu's changes leave the player's disk
// images unwritten (write protection on), read no vicerc, need no drive ROM, and save time. Upstream still makes
// <system>/vice and writes its defaults there once (vicerc-dump-C64SC), and empties <save>/TEMP at start.
static const GagaLibretroVariable s_variables[] = {
    { "vice_c64_model", "C64 PAL auto" },
    { "vice_ram_expansion_unit", "none" },
    { "vice_printer", "disabled" },
    { "vice_jiffydos", "disabled" },
    { "vice_read_vicerc", "disabled" }, // GagaEmu
    { "vice_reset", "autostart" },
    { "vice_autoloadwarp", "disabled" },
    { "vice_warp_boost", "disabled" },
    { "vice_autostart", "enabled" },
    { "vice_drive_true_emulation", "disabled" }, // GagaEmu
    { "vice_virtual_device_traps", "disabled" },
    { "vice_floppy_multidrive", "disabled" },
    { "vice_floppy_write_protection", "enabled" }, // GagaEmu
    { "vice_easyflash_write_protection", "enabled" }, // GagaEmu
    { "vice_work_disk", "disabled" },
    { "vice_cartridge", "none" }, // GagaEmu
    { "vice_video_options_display", "disabled" },
    { "vice_aspect_ratio", "auto" },
    { "vice_crop", "disabled" },
    { "vice_crop_delay", "enabled" },
    { "vice_crop_mode", "both" },
    { "vice_manual_crop_top", "0" },
    { "vice_manual_crop_bottom", "0" },
    { "vice_manual_crop_left", "0" },
    { "vice_manual_crop_right", "0" },
    { "vice_vicii_filter", "disabled" },
    { "vice_vicii_filter_oddline_offset", "1000" },
    { "vice_vicii_filter_oddline_phase", "1000" },
    { "vice_external_palette", "default" },
    { "vice_vicii_color_gamma", "2800" },
    { "vice_vicii_color_brightness", "1000" },
    { "vice_vicii_color_contrast", "1000" },
    { "vice_vicii_color_saturation", "1000" },
    { "vice_vicii_color_tint", "1000" },
    { "vice_gfx_colors", "16bit" }, // GagaEmu
    { "vice_vkbd_theme", "auto" },
    { "vice_vkbd_transparency", "25%" },
    { "vice_vkbd_dimming", "25%" },
    { "vice_statusbar", "bottom" },
    { "vice_statusbar_startup", "disabled" },
    { "vice_statusbar_messages", "disabled" },
    { "vice_joyport_pointer_color", "blue" },
    { "vice_audio_options_display", "disabled" },
    { "vice_drive_sound_emulation", "disabled" }, // GagaEmu
    { "vice_datasette_sound", "disabled" },
    { "vice_audio_leak_emulation", "disabled" },
    { "vice_sid_engine", "ReSID" },
    { "vice_sid_model", "default" },
    { "vice_sid_extra", "disabled" },
    { "vice_resid_sampling", "fast" }, // GagaEmu
    { "vice_resid_passband", "90" },
    { "vice_resid_gain", "97" },
    { "vice_resid_filterbias", "500" },
    { "vice_resid_8580filterbias", "0" },
    { "vice_sfx_sound_expander", "disabled" },
    { "vice_sound_sample_rate", "48000" },
    { "vice_analogmouse", "left" },
    { "vice_analogmouse_deadzone", "20" },
    { "vice_analogmouse_speed", "1.0" },
    { "vice_analogmouse_speed_right", "1.0" },
    { "vice_dpadmouse_speed", "6" },
    { "vice_mouse_speed", "100" },
    { "vice_physical_keyboard_pass_through", "disabled" },
    { "vice_datasette_hotkeys", "disabled" },
    { "vice_keyrah_keypad_mappings", "disabled" },
    { "vice_keyboard_keymap", "positional" },
    { "vice_mapping_options_display", "enabled" },
    { "vice_mapper_vkbd", "---" },
    { "vice_mapper_statusbar", "RETROK_F12" },
    { "vice_mapper_joyport_switch", "RETROK_RCTRL" },
    { "vice_mapper_turbo_fire_toggle", "---" },
    { "vice_mapper_save_disk_toggle", "---" },
    { "vice_mapper_aspect_ratio_toggle", "---" },
    { "vice_mapper_crop_toggle", "---" },
    { "vice_mapper_datasette_toggle_hotkeys", "---" },
    { "vice_mapper_datasette_start", "RETROK_UP" },
    { "vice_mapper_datasette_stop", "RETROK_DOWN" },
    { "vice_mapper_datasette_rewind", "RETROK_LEFT" },
    { "vice_mapper_datasette_forward", "RETROK_RIGHT" },
    { "vice_mapper_datasette_reset", "---" },
    { "vice_mapper_reset", "RETROK_END" },
    { "vice_mapper_warp_mode", "---" },
    { "vice_mapper_up", "---" },
    { "vice_mapper_down", "---" },
    { "vice_mapper_left", "---" },
    { "vice_mapper_right", "---" },
    { "vice_mapper_b", "---" },
    { "vice_mapper_a", "---" },
    { "vice_mapper_y", "---" },
    { "vice_mapper_x", "RETROK_SPACE" },
    { "vice_mapper_select", "TOGGLE_VKBD" },
    { "vice_mapper_start", "---" },
    { "vice_mapper_l", "---" },
    { "vice_mapper_r", "---" },
    { "vice_mapper_l2", "RETROK_ESCAPE" },
    { "vice_mapper_r2", "RETROK_RETURN" },
    { "vice_mapper_l3", "---" },
    { "vice_mapper_r3", "---" },
    { "vice_mapper_lu", "---" },
    { "vice_mapper_ld", "---" },
    { "vice_mapper_ll", "---" },
    { "vice_mapper_lr", "---" },
    { "vice_mapper_ru", "---" },
    { "vice_mapper_rd", "---" },
    { "vice_mapper_rl", "---" },
    { "vice_mapper_rr", "---" },
    { "vice_turbo_fire", "disabled" },
    { "vice_turbo_fire_button", "B" },
    { "vice_turbo_pulse", "6" },
    { "vice_userport_joytype", "disabled" },
    { "vice_joyport", "2" },
    { "vice_joyport_type", "1" },
    { "vice_retropad_options", "disabled" },
    { NULL, NULL },
};

const GagaLibretroCore gaga_libretro_core = {
    .name = "VICE",
    .game_kind = "a Commodore 64 game",
    .variables = s_variables,
};

static char s_system_dir[1024];
static void (*s_event_cb)(GagaEventSeverity, int32_t, const char*, void*);
static void* s_event_userdata;

static GagaInstance* vice_create(const char* system_dir, const char* save_dir) {
    snprintf(s_system_dir, sizeof(s_system_dir), "%s", system_dir ? system_dir : "");
    return gaga_lr_create(system_dir, save_dir);
}

static void vice_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*),
                                    void* userdata) {
    s_event_cb = cb;
    s_event_userdata = userdata;
    gaga_lr_set_event_callback(inst, cb, userdata);
}

// Where vice_sysfile.c finds it: the top of the system folder, or upstream's own <system>/vice/C64.
static bool vice_has_system_file(const char* name) {
    char path[1200];
    snprintf(path, sizeof(path), "%s/%s", s_system_dir, name);
    if (access(path, R_OK) == 0) return true;
    snprintf(path, sizeof(path), "%s/vice/C64/%s", s_system_dir, name);
    return access(path, R_OK) == 0;
}

// Upstream crashes when a ROM file is missing, so the game is refused first. Upstream also reads no joystick until
// the frontend names a device for the port (it starts as RETRO_DEVICE_NONE), and the shared adapter names none: a
// RetroPad on both ports, as RetroArch sets by default.
static bool vice_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size) {
    static const char* const required[] = { "kernal-901227-03.bin", "basic-901226-01.bin", "chargen-901225-01.bin" };
    for (size_t i = 0; i < sizeof(required) / sizeof(required[0]); ++i) {
        if (!vice_has_system_file(required[i])) {
            if (s_event_cb) {
                s_event_cb(GAGA_EVENT_FATAL, 1, "VICE needs the C64 KERNAL, BASIC and character ROMs. Add "
                           "kernal-901227-03.bin, basic-901226-01.bin and chargen-901225-01.bin in BIOS Files.",
                           s_event_userdata);
            }
            return false;
        }
    }
    retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    retro_set_controller_port_device(1, RETRO_DEVICE_JOYPAD);
    return gaga_lr_load_rom(inst, rom_path, rom_data, rom_size);
}

const GagaCoreInterface* Vice_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .create = vice_create,
        .load_rom = vice_load_rom,
        .set_event_callback = vice_set_event_callback,
        .core_id = "vice",
        .core_name = "VICE",
        .core_version = GAGA_CORE_VERSION,
        // Upstream takes many more (.g64, .d71, .d81, .p00, .vsf, archives); these are the common C64 formats.
        .supported_extensions = "d64|t64|prg|crt|tap",
        .target_fps = 50.12,            // PAL: 985248 Hz / (312 lines * 63 cycles).
        .native_sample_rate = 48000,    // vice_sound_sample_rate.
        .state_version = 1,
    };
    return &interface;
}
