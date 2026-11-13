// Sideload JIT build only (jit.env): force-included into melonDS's ARMJIT.cpp and ARMJIT_Memory.cpp. The system
// headers come first, so the macros below change the calls in those files and not the declarations.
#pragma once
#include <pthread.h>
#include <sys/mman.h>

// The code region's RX and RW sides are separate mappings (Cores/shared/Jit26.c), so there is no MAP_JIT region to flip.
#define pthread_jit_write_protect_np(enabled) ((void)(enabled))
// Only fastmem, which melonDS never enables on Apple (IsFastMemSupported), protects pages. TXM would refuse it anyway.
#define mprotect(addr, len, prot) (-1)
// The emulated RAM's backing object: ARMJIT_GlobalJit26.cpp.
#ifdef __cplusplus
extern "C"
#endif
int gaga_melonds_shm_open(const char* name, int flags, mode_t mode);
#define shm_open gaga_melonds_shm_open
