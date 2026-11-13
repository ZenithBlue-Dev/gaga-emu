// Sideload JIT only (Jit26.h): the shared adapter unchanged, behind an environment callback that answers two more
// questions. The JIT build compiles this file in place of LibretroAdapter.c (Cores/<core>/jit.env), so the store
// build's adapter stays byte for byte what it was. GAGA_JIT_OPTION_KEY and _VALUE come from the core's jit.env.
#include <libretro.h>

#include "Jit26.h"

static bool lr_jit_environment(unsigned command, void* data);
#define retro_set_environment(cb) retro_set_environment(lr_jit_environment)
#include "LibretroAdapter.c"
#undef retro_set_environment

static bool lr_jit_environment(unsigned command, void* data) {
    if (command == RETRO_ENVIRONMENT_GET_JIT_CAPABLE) {
        *(bool*)data = gaga_jit26_wanted();
        return true;
    }
    // The CPU core option is locked to the interpreter for the player (s_locked_words); only a working JIT moves it.
    if (command == RETRO_ENVIRONMENT_GET_VARIABLE) {
        struct retro_variable* variable = data;
        if (variable->key && strcmp(variable->key, GAGA_JIT_OPTION_KEY) == 0 && gaga_jit26_wanted()) {
            variable->value = GAGA_JIT_OPTION_VALUE;
            return true;
        }
    }
    return lr_environment(command, data);
}
