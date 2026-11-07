// Upstream's libretro frontend (libretro-core.c, which #includes cmdline.c), compiled here rather than listed in
// sources.txt so atari800_forget_last_game can reach cmdline.c's static argument lists. Upstream assumes the
// frontend unloads the whole core between games; GagaEmu keeps it loaded, so every global the last game left
// behind is reset before the next one.
#include "upstream/libretro/libretro-core.c"
#include "cartridge.h"
#include "input.h"

extern int pauseg;

// retro_unload_game sets pauseg to -1, which retro_run never clears: the next game would draw nothing.
// pre_main appends to PARAMCOUNT and ARGUC on every load: the next game would boot with the last game's
// command line in front of its own, and Atari800_Initialise refuses that ("-cart" twice, or a stale path).
// PLATFORM_Initialise sets INPUT_direct_mouse after INPUT_Initialise has checked it, so a second
// INPUT_Initialise refuses with "-directmouse only valid with -mouse pad|touch|koala".
// CARTRIDGE_Initialise inserts the last game's cartridge again by its file name, which turns an .xex after a
// .a52 into a 5200 ("binload: can't run Atari programs directly on the 5200").
void atari800_forget_last_game(void) {
    pauseg = 0;
    INPUT_direct_mouse = 0;
    CARTRIDGE_Remove();
    CARTRIDGE_main.filename[0] = '\0';
    CARTRIDGE_piggyback.filename[0] = '\0';
    PARAMCOUNT = 0;
    ARGUC = 0;
    memset(ARGUV, 0, sizeof(ARGUV));
}
