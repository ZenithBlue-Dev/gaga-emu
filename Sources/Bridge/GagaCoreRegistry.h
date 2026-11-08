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
const GagaCoreInterface* SwanStation_GetInterface(void);
// Non-commercial licences, sideload builds only (docs/03 section 5).
const GagaCoreInterface* Snes9x_GetInterface(void);
const GagaCoreInterface* GenesisPlusGX_GetInterface(void);
const GagaCoreInterface* Picodrive_GetInterface(void);
const GagaCoreInterface* Fbneo_GetInterface(void);
// group-retro backlog cores (docs/07 section 8.x).
const GagaCoreInterface* Gearsystem_GetInterface(void);
const GagaCoreInterface* Stella_GetInterface(void);
const GagaCoreInterface* ProSystem_GetInterface(void);
const GagaCoreInterface* Handy_GetInterface(void);
const GagaCoreInterface* Atari800_GetInterface(void);
const GagaCoreInterface* VirtualJaguar_GetInterface(void);
const GagaCoreInterface* Vice_GetInterface(void);
const GagaCoreInterface* Puae_GetInterface(void);
const GagaCoreInterface* Prboom_GetInterface(void);

// Fully operational Mock Core for testing, preview, and verification
const GagaCoreInterface* MockCore_GetInterface(void);
// The last step_frame the mock core ran, for tests: its player_count and one port's buttons.
uint32_t MockCore_LastPlayerCount(void);
uint32_t MockCore_LastButtons(uint32_t port);

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
