// Sideload JIT build only (jit.env), in place of upstream's cpu/drc/cmn.c. The SH-2 recompiler's code cache on
// Cores/shared/Jit26.c memory: one RX region, written through its RW alias (jit.env's copy of emit_arm64.c stores at
// + gaga_pico_rw_delta), with veneers after the cache for calls to C helpers out of BL range.
#include <libkern/OSCacheControl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Jit26.h"
#include "upstream/pico/pico_types.h"
#include "upstream/cpu/drc/cmn.h"

#define VENEER_SIZE 16 // ldr x16, #8; br x16; .quad target
#define VENEER_COUNT 1024

#define pico_jit_log(...) do { printf("[gaga-core] jit26: " __VA_ARGS__); printf("\n"); fflush(stdout); } while (0)

u8* tcache;
long gaga_pico_rw_delta;

// DRC_SH2 sets up and fills the cache at every 32X start, JIT or not. Without the JIT it is this plain buffer, never run.
static u8 s_plain[DRC_TCACHE_SIZE] __attribute__((aligned(16384)));
static u8* s_region; // the RX region, kept for the life of the process
static bool s_failed;
static uint32_t* s_veneers; // RX, after the cache; NULL with the plain buffer
static const void* s_targets[VENEER_COUNT];
static int s_count;

static u8* pico_jit_region(void) {
    if (!s_region && !s_failed && gaga_jit26_wanted()) {
        s_region = gaga_jit26_alloc(DRC_TCACHE_SIZE + VENEER_COUNT * VENEER_SIZE);
        if (!s_region) {
            s_failed = true;
            pico_jit_log("no region for the SH-2 code cache: interpreter");
        }
    }
    return s_region;
}

// In LibretroAdapterJit26.c's place of gaga_jit26_wanted: picodrive_drc may become "enabled" only when the cache is,
// or will be at the next 32X start, the runnable region. Otherwise the interpreter, as in the store build.
bool gaga_pico_jit_ready(void) {
    if (!gaga_jit26_wanted()) return false;
    u8* region = pico_jit_region();
    return region && (tcache == NULL || tcache == region);
}

void drc_cmn_init(void) {
    u8* region = pico_jit_region();
    tcache = region ? region : s_plain;
    gaga_pico_rw_delta = region ? (long)((u8*)gaga_jit26_writable(region) - region) : 0;
    s_veneers = region ? (uint32_t*)(region + DRC_TCACHE_SIZE) : NULL;
    s_count = 0;
    pico_jit_log("SH-2 code cache %p (%s)", (void*)tcache, region ? "JIT region" : "not executable, interpreter");
}

void drc_cmn_cleanup(void) {
    tcache = NULL; // the next drc_cmn_init chooses again
}

// The BL/B target for emit_arm64.c's emith_jump and emith_call: target itself when in +-128 MiB of from, else a
// veneer in the region. x16 (IP0) is the AAPCS64 veneer register; every such target is a C function, which may
// clobber it anyway.
void* gaga_pico_far(void* target, void* from) {
    intptr_t distance = (u8*)target - (u8*)from;
    if (!s_veneers || (distance >= -(1 << 27) && distance < (1 << 27))) return target;
    for (int i = 0; i < s_count; ++i) {
        if (s_targets[i] == target) return s_veneers + i * VENEER_SIZE / 4;
    }
    if (s_count == VENEER_COUNT) {
        pico_jit_log("out of veneers for C helpers");
        abort();
    }
    uint32_t* rx = s_veneers + s_count * VENEER_SIZE / 4;
    uint32_t* rw = (uint32_t*)((u8*)rx + gaga_pico_rw_delta);
    rw[0] = 0x58000050; // ldr x16, #8
    rw[1] = 0xd61f0200; // br x16
    memcpy(rw + 2, &target, sizeof target);
    sys_icache_invalidate(rx, VENEER_SIZE);
    s_targets[s_count++] = target;
    return rx;
}

// emit_arm64.c's host_instructions_updated: the RX range that runs. Nothing runs from the plain buffer.
void gaga_pico_jit_flush(void* start, void* end) {
    if (tcache != s_plain && (u8*)end > (u8*)start) sys_icache_invalidate(start, (size_t)((u8*)end - (u8*)start));
}
