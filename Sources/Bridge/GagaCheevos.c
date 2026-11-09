#include "GagaCheevos.h"
#include "rc_libretro.h"

// One session at a time, as the host has. The map is built on the core's queue and read under the RA queue.
static GagaInstance* s_instance;
static void* (*s_memory_data)(GagaInstance*, uint32_t, size_t*);
static rc_libretro_memory_regions_t s_regions;
static bool s_ready;

static void core_memory_info(uint32_t id, rc_libretro_core_memory_info_t* info) {
    size_t size = 0;
    info->data = s_memory_data(s_instance, id, &size);
    info->size = size;
}

bool gaga_cheevos_memory_init(const GagaCoreInterface* core, GagaInstance* instance, uint32_t console_id) {
    gaga_cheevos_memory_destroy();
    if (!core->memory_data) return false;
    s_instance = instance;
    s_memory_data = core->memory_data;
    const struct retro_memory_map* map = core->memory_map ? core->memory_map(instance) : NULL;
    s_ready = rc_libretro_memory_init(&s_regions, map, core_memory_info, console_id) != 0;
    return s_ready;
}

void gaga_cheevos_memory_destroy(void) {
    if (s_ready) rc_libretro_memory_destroy(&s_regions);
    s_ready = false;
}

uint32_t gaga_cheevos_read_memory(uint32_t address, uint8_t* buffer, uint32_t num_bytes, struct rc_client_t* client) {
    (void)client;
    return s_ready ? rc_libretro_memory_read(&s_regions, address, buffer, num_bytes) : 0;
}

bool gaga_poke_region(const GagaCoreInterface* core, GagaInstance* instance, uint64_t base, GagaPokeRegion* out) {
    size_t size = 0;
    void* data = core->memory_data ? core->memory_data(instance, RETRO_MEMORY_SYSTEM_RAM, &size) : NULL;
    if (!data || !size) return false;
    *out = (GagaPokeRegion){ data, base, size };
    return true;
}
