// Stands in for upstream's src/bios/*.c, which embed Atari's Jaguar, Jaguar CD and developer CD boot ROMs. GagaEmu
// bundles no boot ROM, so these are zero-filled at the sizes upstream declares. The player's own jagboot.rom is
// loaded from the system folder (virtualjaguar_bios_type "custom"); without it the core boots carts by HLE.
#include "jagbios.h"
#include "jagbios_m.h"
#include "jagcdbios.h"
#include "jagdevcdbios.h"

uint8_t jaguarBootROM[0x20000];
uint8_t jaguarBootROM_M[0x20000];
uint8_t jaguarCDBootROM[0x40000];
uint8_t jaguarDevCDBootROM[0x40000];
