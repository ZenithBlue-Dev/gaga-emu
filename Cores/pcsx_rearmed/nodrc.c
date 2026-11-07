// What the interpreter-only build needs from libpcsxcore/new_dynarec/emu_if.c, which is not compiled so that
// no file from the dynarec's folder is in the binary (core.env). With DRC_DISABLE upstream's copy is only these
// stubs. The header is read for the struct, which declares nothing that runs.
#include "upstream/libpcsxcore/new_dynarec/new_dynarec.h"

struct ndrc_globals ndrc_g; // Option flags the frontend and the game database write and nothing reads.

// The dynarec's block list in a save state. This build never has one, so it never writes one, and the states
// it loads are its own.
void ndrc_freeze(void* f, int mode) {
    (void)f;
    (void)mode;
}

void ndrc_clear_full(void) {}
