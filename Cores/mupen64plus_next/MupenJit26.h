// Sideload JIT build only (jit.env): forced into LibretroAdapterJit26.c and the new_dynarec.c copy.
#pragma once
#include "Jit26.h"

// The R4300 dynarec's 32 MiB translation cache: a Jit26 RX region, mapped once and kept for the process, or NULL.
void* gaga_mupen_jit_region(void);
// mupen64plus-cpucore once gaga_jit26_wanted: "dynamic_recompiler" with a region, else "cached_interpreter".
const char* gaga_mupen_cpucore(void);
