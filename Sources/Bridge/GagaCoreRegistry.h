#ifndef GAGA_CORE_REGISTRY_H
#define GAGA_CORE_REGISTRY_H

#include "GagaBridge.h"
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Compile-time core getters
const GagaCoreInterface* PcsxReArmed_GetInterface(void);
const GagaCoreInterface* BeetlePsx_GetInterface(void);
const GagaCoreInterface* Mgba_GetInterface(void);
const GagaCoreInterface* Gpsp_GetInterface(void);
const GagaCoreInterface* Bsnes_GetInterface(void);
const GagaCoreInterface* Gambatte_GetInterface(void);
const GagaCoreInterface* Jgenesis_GetInterface(void);
const GagaCoreInterface* MelonDS_GetInterface(void);
const GagaCoreInterface* Azahar_GetInterface(void);
const GagaCoreInterface* Flycast_GetInterface(void);
const GagaCoreInterface* Ppsspp_GetInterface(void);

// Fully operational Mock Core for testing, preview, and verification
const GagaCoreInterface* MockCore_GetInterface(void);

// Core Registry lookup APIs
size_t GagaCoreRegistry_GetCount(void);
const GagaCoreInterface* GagaCoreRegistry_GetAtIndex(size_t index);
const GagaCoreInterface* GagaCoreRegistry_FindByID(const char* core_id);
const GagaCoreInterface* GagaCoreRegistry_FindByExtension(const char* extension);

#ifdef __cplusplus
}
#endif

#endif // GAGA_CORE_REGISTRY_H
