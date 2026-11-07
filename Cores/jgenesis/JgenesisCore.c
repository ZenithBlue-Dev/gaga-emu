// JGenesis behind the GagaBridge interface. Upstream is Rust and has no libretro core, so shim/ is GagaEmu's
// own crate over its emulation crates (no wgpu, SDL or egui), built into a static library by
// scripts/build-core.sh. This file is only the table, so the C compiler checks it against GagaBridge.h.
// Genesis cartridges need no BIOS. Mega-CD reads the player's own BIOS from system_dir; none is bundled.
#include "GagaBridge.h"

// shim/src/lib.rs. Its structs mirror GagaBridge.h, and these prototypes match its signatures.
GagaInstance* jg_create(const char* system_dir, const char* save_dir);
void jg_destroy(GagaInstance* inst);
bool jg_load_rom(GagaInstance* inst, const char* rom_path, const void* rom_data, size_t rom_size);
void jg_reset(GagaInstance* inst);
void jg_step_frame(GagaInstance* inst, const GagaInputState inputs[4], uint32_t player_count);
void jg_set_video_callback(GagaInstance* inst, void (*cb)(const GagaFrameDescriptor*, void*), void* userdata);
void jg_set_audio_callback(GagaInstance* inst, void (*cb)(const GagaAudioDescriptor*, void*), void* userdata);
void jg_set_event_callback(GagaInstance* inst, void (*cb)(GagaEventSeverity, int32_t, const char*, void*), void* userdata);
size_t jg_state_size(GagaInstance* inst);
bool jg_save_state(GagaInstance* inst, void* buffer, size_t size);
bool jg_load_state(GagaInstance* inst, const void* buffer, size_t size, char* error, size_t error_capacity);
void jg_flush_battery_save(GagaInstance* inst);
bool jg_cheat_add(GagaInstance* inst, uint32_t id, const char* code, bool enabled, char* error, size_t error_capacity);
void jg_cheat_remove(GagaInstance* inst, uint32_t id);
void jg_cheat_set_enabled(GagaInstance* inst, uint32_t id, bool enabled);
bool jg_self_test(char* error, size_t error_capacity);

// Rust's enum is a 32-bit int on this ABI; the shim passes severities as int32_t.
_Static_assert(sizeof(GagaEventSeverity) == sizeof(int32_t), "event severity is passed as int32_t");

// Nothing runs between step_frame calls, so there is nothing to stop or restart.
static void jg_pause(GagaInstance* inst) { (void)inst; }
static void jg_resume(GagaInstance* inst) { (void)inst; }
static bool jg_attach_metal_layer(GagaInstance* inst, void* layer) { (void)inst; (void)layer; return false; }

static const GagaCoreInterface s_interface = {
    .abi_version = GAGA_BRIDGE_ABI_VERSION,
    .core_id = "jgenesis",
    .core_name = "JGenesis",
    .core_version = GAGA_CORE_VERSION,
    // .bin and .cue are also PCSX-ReARMed's; the Library picks the core by platform, not by extension. A
    // Mega-CD .chd also loads, but is not listed, so a lookup by extension finds PCSX-ReARMed for it.
    .supported_extensions = "md|gen|smd|bin|cue",
    // shortcut: NTSC only (53693175 Hz / 3420 / 262). A PAL game runs at 60 Hz pace with 50 Hz music. Give the host a per-game rate if PAL games matter.
    .target_fps = 53693175.0 / 3420.0 / 262.0,
    .native_sample_rate = 48000,
    .create = jg_create,
    .destroy = jg_destroy,
    .load_rom = jg_load_rom,
    .reset = jg_reset,
    .step_frame = jg_step_frame,
    .attach_metal_layer = jg_attach_metal_layer,
    .set_video_callback = jg_set_video_callback,
    .set_audio_callback = jg_set_audio_callback,
    .state_version = 0x000E0001u, // STATE_VERSION in shim/src/lib.rs: upstream's state format 0.14.0-1.
    .state_size = jg_state_size,
    .save_state = jg_save_state,
    .load_state = jg_load_state,
    .flush_battery_save = jg_flush_battery_save,
    .cheat_add = jg_cheat_add,
    .cheat_remove = jg_cheat_remove,
    .cheat_set_enabled = jg_cheat_set_enabled,
    .self_test = jg_self_test,
    .pause = jg_pause,
    .resume = jg_resume,
    .set_event_callback = jg_set_event_callback,
};

const GagaCoreInterface* Jgenesis_GetInterface(void) {
    return &s_interface;
}
