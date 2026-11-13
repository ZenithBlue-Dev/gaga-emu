// Sideload JIT build only (Cores/dosbox_pure/jit.env): the one file compiled with HAVE_LIBNX is
// upstream/src/cpu/core_dynrec.cpp, whose dyn_cache.h already keeps the code cache as two mappings, as libnx's
// Jit does: it executes at the RX address and every cache_add* write goes through the RW one. This header stands
// in for <switch.h> there and takes both mappings from Cores/shared/Jit26.c. Not libnx; nothing else includes it.
#pragma once
#include <stddef.h>
#include <sys/types.h>

#include "Jit26.h"

typedef unsigned int Result;
#define R_SUCCEEDED(res) ((res) == 0)

typedef struct { void* rx; void* rw; size_t size; } Jit;

// Always "succeeds": a region the debugger did not give leaves rx NULL, so dyn_cache.h's nxmmap returns NULL and
// cache_init stops with "Allocating dynamic cache failed" instead of writing to a bad address. The dynamic core is
// only chosen when gaga_jit26_wanted() ran its probe region (LibretroAdapterJit26.c), so that is not expected.
static inline Result jitCreate(Jit* j, size_t size) {
    j->rx = gaga_jit26_alloc(size);
    j->rw = j->rx ? gaga_jit26_writable(j->rx) : NULL;
    j->size = size;
    return 0;
}
static inline void* jitGetRwAddr(Jit* j) { return j->rw; }
static inline void* jitGetRxAddr(Jit* j) { return j->rx; }
// The RX side is executable from the start and never re-protected (TXM would refuse a flip).
static inline Result jitTransitionToExecutable(Jit* j) { (void)j; return 0; }
static inline Result jitClose(Jit* j) {
    gaga_jit26_free(j->rx, j->size);
    j->rx = j->rw = NULL;
    return 0;
}
