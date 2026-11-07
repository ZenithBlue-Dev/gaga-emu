// Hosts one statically linked libretro core behind GagaCoreInterface. Add LibretroAdapter.c to a core's
// sources.txt, define gaga_libretro_core and write its getter. docs/06 section 2.5 has the steps.
//
// libretro cores keep their state in globals and their callbacks take no userdata, so a framework can
// run one instance at a time: `create` returns NULL while another is alive. The host runs one session.
//
// RETRO_ENVIRONMENT_SET_HW_RENDER is refused, so a core renders in software, unless the core's build
// adds LibretroVulkan.c for a Vulkan context on the layer path (LibretroVulkan.h).
#ifndef GAGA_LIBRETRO_ADAPTER_H
#define GAGA_LIBRETRO_ADAPTER_H

#include "GagaBridge.h"

#ifdef __cplusplus
extern "C" {
#endif

// The core's options, frozen at the values GagaEmu ships. A key not listed reads as unset, which
// sends the core to its own default.
typedef struct {
    const char* key;
    const char* value;
} GagaLibretroVariable;

typedef struct {
    const char* name;                       // In messages for the player, such as "Gambatte".
    const char* game_kind;                  // Ends "This file is not ...", such as "a Game Boy game".
    const GagaLibretroVariable* variables;  // Ends with a NULL key.
    // Optional. Checks a file's bytes before the core sees them. A need_fullpath core that sets it gets the
    // file read once for the check, and still loads it by path.
    bool (*is_rom)(const uint8_t* data, size_t size);
    // Needed with GAGA_LIBRETRO_CHEATS. libretro's cheat call cannot refuse a code, so this checks one line.
    bool (*is_cheat)(const char* line);
    // Optional, for a core that writes its own battery files and returns no RETRO_MEMORY_SAVE_RAM: writes
    // them now, and returns false if one could not be written. Called after load and at every flush.
    bool (*save_battery)(void);
    // Optional, for a core that cannot add a code to ones it already applied: takes every applied code
    // back out, keeping the core's list. Called before each retro_cheat_set.
    void (*unapply_cheats)(void);
    // Optional, for a core whose retro_deinit leaves state that a later retro_init and retro_deinit trip on
    // (MAME tears its finished game down again). Called after every retro_deinit.
    void (*after_deinit)(void);
    // True when one cheat's lines must reach retro_cheat_set as one code, joined by '+', because the
    // core's format spans lines (Action Replay DS conditionals). False: one index per line.
    bool cheat_lines_are_one_code;
    // True for a core whose state size changes from save to save (RETRO_SERIALIZATION_QUIRK_CORE_VARIABLE_SIZE,
    // Azahar's compressed states): load_state takes the size from the state's header, not from the running game.
    bool state_size_varies;
    // Optional. A message for the player when this game cannot start, such as a BIOS the player has not added,
    // or NULL. Called with the system folder before the core sees the game.
    const char* (*refuse_load)(const char* system_dir, const char* rom_path);
} GagaLibretroCore;

extern const GagaLibretroCore gaga_libretro_core;

GagaInstance* gaga_lr_create(const char* system_dir, const char* save_dir);
void gaga_lr_destroy(GagaInstance* inst);
bool gaga_lr_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size);
void gaga_lr_reset(GagaInstance* inst);
void gaga_lr_step_frame(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count);
void gaga_lr_set_video_callback(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor*, void*), void* userdata);
void gaga_lr_set_audio_callback(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor*, void*), void* userdata);
size_t gaga_lr_state_size(GagaInstance* inst);
bool gaga_lr_save_state(GagaInstance* inst, void* buffer, size_t size);
bool gaga_lr_load_state(GagaInstance* inst, const void* buffer, size_t size, char* error, size_t error_capacity);
void gaga_lr_flush_battery_save(GagaInstance* inst);
bool gaga_lr_cheat_add(GagaInstance* inst, uint32_t id, const char* code, bool enabled, char* error, size_t error_capacity);
void gaga_lr_cheat_remove(GagaInstance* inst, uint32_t id);
void gaga_lr_cheat_set_enabled(GagaInstance* inst, uint32_t id, bool enabled);
bool gaga_lr_self_test(char* error, size_t error_capacity);
void gaga_lr_pause(GagaInstance* inst);
void gaga_lr_resume(GagaInstance* inst);
void gaga_lr_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata);

// First in a core's GagaCoreInterface initialiser. The core adds its ID, names, rates and state_version.
#define GAGA_LIBRETRO_ENTRY_POINTS \
    .abi_version = GAGA_BRIDGE_ABI_VERSION, \
    .create = gaga_lr_create, \
    .destroy = gaga_lr_destroy, \
    .load_rom = gaga_lr_load_rom, \
    .reset = gaga_lr_reset, \
    .step_frame = gaga_lr_step_frame, \
    .set_video_callback = gaga_lr_set_video_callback, \
    .set_audio_callback = gaga_lr_set_audio_callback, \
    .state_size = gaga_lr_state_size, \
    .save_state = gaga_lr_save_state, \
    .load_state = gaga_lr_load_state, \
    .flush_battery_save = gaga_lr_flush_battery_save, \
    .self_test = gaga_lr_self_test, \
    .pause = gaga_lr_pause, \
    .resume = gaga_lr_resume, \
    .set_event_callback = gaga_lr_set_event_callback

// Add for a core whose retro_cheat_set does something, with is_cheat set. Without it the menu row hides.
#define GAGA_LIBRETRO_CHEATS \
    .cheat_add = gaga_lr_cheat_add, \
    .cheat_remove = gaga_lr_cheat_remove, \
    .cheat_set_enabled = gaga_lr_cheat_set_enabled

#ifdef __cplusplus
}
#endif

#endif // GAGA_LIBRETRO_ADAPTER_H
