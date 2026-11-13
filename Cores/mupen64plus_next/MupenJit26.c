// Sideload JIT build only (jit.env). The dynarec's init cannot fail, so its region is mapped here, when libretro.c
// reads mupen64plus-cpucore, and the dynarec is chosen only if that worked. new_dynarec_init and _cleanup run again on
// every reset and state load; they reuse this one region rather than asking the debugger each time.
#include "MupenJit26.h"

#include "device/r4300/new_dynarec/new_dynarec.h"

#include <stdio.h>

void* gaga_mupen_jit_region(void) {
    static void* rx; // Set while libretro.c reads its options, before the R4300 starts; only read after that.
    if (!rx) rx = gaga_jit26_alloc(NEW_DYNAREC_CACHE_SIZE);
    return rx;
}

const char* gaga_mupen_cpucore(void) {
    if (gaga_mupen_jit_region()) return "dynamic_recompiler";
    printf("[gaga-core] jit26: no %u-byte region for the R4300 dynarec: cached interpreter\n", NEW_DYNAREC_CACHE_SIZE);
    fflush(stdout);
    return "cached_interpreter";
}
