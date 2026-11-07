// Builds upstream's sources/src/fpp_native.c (the host-FPU 68881/68882 emulation), which scripts/build-core.sh's
// source audit flags, after reading it (docs/04 section 8). Its one hit writes an x87 fldcw stub and makes it
// executable, inside `#if defined(CPU_i386) || defined(CPU_x86_64)`, which an arm64 build never compiles.
// puae_cpuboard.c covers the other flagged file. retrodep/mman.c, which maps executable memory for the JIT, is left
// out: nothing else needs it. FORBIDDEN_IMPORTS refuses mprotect in the linked binary either way.
#include "upstream/sources/src/fpp_native.c"
