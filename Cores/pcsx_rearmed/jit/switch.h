// Sideload JIT build only (../jit.env). new_dynarec.c already keeps its translation cache in two mappings on the
// Switch: libnx's Jit gives an RX address it runs and an RW alias it writes (TC_WRITE_OFFSET, ndrc_write_ofs). The JIT
// build compiles new_dynarec.c alone with HAVE_LIBNX and this directory first on its include path, so this file stands
// in for <switch.h> with that API on Cores/shared/Jit26.c memory. No other libnx part is used or compiled.
#pragma once
#include "../../shared/Jit26.h"

#include <libkern/OSCacheControl.h>
#include <stdio.h>
#include <stdlib.h>

typedef int Result;
#define R_FAILED(rc) ((rc) != 0)

typedef enum { JitType_SetProcessMemoryPermission, JitType_CodeMemory } JitType;
typedef struct {
    JitType type;
    size_t size;
    void* rx_addr;
    void* rw_addr;
} Jit;

// CodeMemory: both mappings stay as they are, so new_dynarec.c never asks for a permission change.
static inline Result jitCreate(Jit* jit, size_t size) {
    jit->type = JitType_CodeMemory;
    jit->size = size;
    jit->rx_addr = gaga_jit26_alloc(size);
    // new_dynarec_init runs code at once and never checks. Only reached after gaga_jit26_wanted ran its probe region.
    if (!jit->rx_addr) {
        printf("[gaga-core] jit26: no region for the dynarec's %zu bytes\n", size);
        fflush(stdout);
        abort();
    }
    jit->rw_addr = gaga_jit26_writable(jit->rx_addr);
    return 0;
}

static inline Result jitTransitionToWritable(Jit* jit) { (void)jit; return 0; }
static inline Result jitTransitionToExecutable(Jit* jit) { (void)jit; return 0; }
static inline Result jitClose(Jit* jit) {
    gaga_jit26_free(jit->rx_addr, jit->size);
    jit->rx_addr = jit->rw_addr = NULL;
    return 0;
}

// The trampoline table's RX copy: the end_tcache_write before it already flushed that range.
#define armDCacheFlush(addr, size) ((void)(addr), (void)(size))

// new_dyna_clear_cache takes the __MACH__ branch before the libnx one, with the RW address it wrote. The RX alias is
// the one that runs, so invalidate that (sys_icache_invalidate also cleans the data cache by address on Apple CPUs).
// ndrc_write_ofs is new_dynarec.c's, in scope where the macro expands.
#define sys_cache_control(function, start, len) \
    sys_icache_invalidate((char*)(start) - ndrc_write_ofs, (len))
