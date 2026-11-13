// Sideload JIT build only (jit.env), in libretro.c's place for emu_core_preinit. That call leaves Config.Cpu at
// CPU_DYNAREC, so psxInit in retro_init would start the dynarec, whose init runs generated code at once. It starts
// only when Cores/shared/Jit26.c has runnable memory; otherwise the interpreter, as in the store build.
#include "upstream/frontend/main.h"
#include "upstream/libpcsxcore/psxcommon.h"

#include "Jit26.h"

int gaga_pcsx_jit_preinit(void) {
    int ret = emu_core_preinit();
    if (!gaga_jit26_wanted()) Config.Cpu = CPU_INTERPRETER;
    return ret;
}
