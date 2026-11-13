// Sideload JIT build only (jit.env): the SH-4 recompiler's code cache, as upstream's FEAT_NO_RWX_PAGES path wants it.
// The recompiler emits through the RW pointer prepare_jit_block returns and computes every branch, block link and
// absolute address against RW + rx_offset. Here that pair is a Cores/shared/Jit26.c region and its RW alias, so no
// page is ever re-protected. Without a region the buffer is plain heap memory whose code never runs (interpreter).
#include "types.h"
#include "hw/sh4/sh4_if.h"
#include "oslib/virtmem.h"

#include "Jit26.h"

#include <cstdio>
#include <cstdlib>
#include <libkern/OSCacheControl.h>

#define flycast_jit_log(...) \
    do { std::printf("[gaga-core] flycast jit: " __VA_ARGS__); std::printf("\n"); std::fflush(stdout); } while (0)

namespace {
bool s_want_region;   // The next prepare_jit_block asks the debugger for a region.
bool s_region;        // The SH-4 code cache is a debugger region, so its code can run.
bool s_reinitialised; // gaga_flycast_engage_jit ran Init again at least once.
}

// emulator.cpp copy (jit.env), first thing in Emulator::loadGame, with the CPU stopped. retro_init ran
// Sh4Recompiler::Init before the host set GAGA_JIT, on heap memory. The first load, and a later one that asks for JIT
// while there is no region yet, run Init again: on a region when GAGA_JIT=1 and the Jit26 probe ran, else on the heap.
void gaga_flycast_engage_jit(Sh4Executor* recompiler) {
    bool want = gaga_jit26_wanted();
    if (!recompiler || (s_reinitialised && (s_region || !want))) return;
    s_reinitialised = true;
    s_want_region = want;
    recompiler->Term();
    recompiler->Init();
    s_want_region = false;
    if (want) flycast_jit_log("%s", s_region ? "SH-4 recompiler engaged" : "no region for the SH-4 code cache: interpreter");
}

// Replaces config::DynarecEnabled in Emulator::getSh4Executor (emulator.cpp copy).
bool gaga_flycast_sh4_jit() { return s_region && gaga_jit26_wanted(); }

namespace virtmem {

// Only the SH-4 recompiler calls this: TARGET_NO_AREC builds no ARM7 or DSP recompiler.
bool prepare_jit_block(void* code_area, size_t size, void** code_area_rw, ptrdiff_t* rx_offset) {
    (void)code_area;
    void* rx = s_want_region ? gaga_jit26_alloc(size) : nullptr;
    s_region = rx != nullptr;
    if (rx) {
        *code_area_rw = gaga_jit26_writable(rx);
        *rx_offset = (u8*)rx - (u8*)*code_area_rw;
        return true;
    }
    // Upstream initialises the recompiler whatever the executor, and it writes its dispatcher here. Never run.
    *code_area_rw = std::malloc(size);
    *rx_offset = 0;
    return *code_area_rw != nullptr;
}

// Sh4Recompiler::Term passes (RW, RX), the same pointer for the heap buffer.
void release_jit_block(void* code_area1, void* code_area2, size_t size) {
    if (code_area1 == code_area2) std::free(code_area1);
    else gaga_jit26_free(code_area2, size);
}

// The RX range. sys_icache_invalidate also cleans the data cache by address, and the RW alias shares its pages.
void flush_cache(void* icache_start, void* icache_end, void* dcache_start, void* dcache_end) {
    (void)dcache_start;
    (void)dcache_end;
    sys_icache_invalidate(icache_start, (size_t)((u8*)icache_end - (u8*)icache_start));
}

} // namespace virtmem
