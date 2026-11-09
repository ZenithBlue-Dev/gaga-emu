#ifndef GAGA_CHEEVOS_H
#define GAGA_CHEEVOS_H

#include "GagaBridge.h"

#ifdef __cplusplus
extern "C" {
#endif

struct rc_client_t;

// Builds rcheevos' address map for the running game from the core's memory (GagaCoreInterface.memory_data and
// memory_map). False when the core exposes none. Call after load_rom, once, before any read.
bool gaga_cheevos_memory_init(const GagaCoreInterface* core, GagaInstance* instance, uint32_t console_id);
// Call before the core's instance goes away. Reads after it return no bytes.
void gaga_cheevos_memory_destroy(void);
// The rc_client read_memory callback.
uint32_t gaga_cheevos_read_memory(uint32_t address, uint8_t* buffer, uint32_t num_bytes, struct rc_client_t* client);

#ifdef __cplusplus
}
#endif

#endif
