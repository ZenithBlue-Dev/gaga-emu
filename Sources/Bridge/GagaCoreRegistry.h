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
const GagaCoreInterface* BeetleSaturn_GetInterface(void);
const GagaCoreInterface* Mgba_GetInterface(void);
const GagaCoreInterface* Gpsp_GetInterface(void);
const GagaCoreInterface* Bsnes_GetInterface(void);
const GagaCoreInterface* Gambatte_GetInterface(void);
const GagaCoreInterface* Nestopia_GetInterface(void);
const GagaCoreInterface* Jgenesis_GetInterface(void);
const GagaCoreInterface* MelonDS_GetInterface(void);
const GagaCoreInterface* Mame_GetInterface(void);
const GagaCoreInterface* Azahar_GetInterface(void);
const GagaCoreInterface* Flycast_GetInterface(void);
const GagaCoreInterface* Ppsspp_GetInterface(void);
const GagaCoreInterface* VkTest_GetInterface(void); // Layer-path test core, Debug builds only.
const GagaCoreInterface* DosboxPure_GetInterface(void);
const GagaCoreInterface* Mupen64PlusNext_GetInterface(void);
const GagaCoreInterface* BeetlePceFast_GetInterface(void);
const GagaCoreInterface* BeetleSupergrafx_GetInterface(void);
const GagaCoreInterface* BeetleVb_GetInterface(void);
const GagaCoreInterface* BeetleNgp_GetInterface(void);
const GagaCoreInterface* BeetleWswan_GetInterface(void);
const GagaCoreInterface* PokeMini_GetInterface(void);

// Fully operational Mock Core for testing, preview, and verification
const GagaCoreInterface* MockCore_GetInterface(void);

// Core Registry lookup APIs
size_t GagaCoreRegistry_GetCount(void);
const GagaCoreInterface* GagaCoreRegistry_GetAtIndex(size_t index);
const GagaCoreInterface* GagaCoreRegistry_FindByID(const char* core_id);
const GagaCoreInterface* GagaCoreRegistry_FindByExtension(const char* extension);
// True for a core with a framework in Cores/ that GAGA_CORE_SET left out of this build.
bool GagaCoreRegistry_IsExcluded(const char* core_id);

#ifdef __cplusplus
}
#endif

#endif // GAGA_CORE_REGISTRY_H
