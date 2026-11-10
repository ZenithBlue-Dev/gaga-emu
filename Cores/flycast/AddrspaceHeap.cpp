// upstream/core/hw/mem/addrspace.cpp, with one change: the heap blocks that hold the machine's memory stay put.
//
// Without virtual memory (FlycastSupport.cpp) Flycast's machine memory lives on the heap, and upstream frees and
// allocates it again in two places: initMappings (Emulator::init, then every Emulator::loadGame through
// setPlatform) and release (retro_deinit). The SH-4 interpreter, its caches and the cycle counter took a pointer
// into p_sh4rcb once, in Sh4Interpreter::Init, and the libretro core calls that only once per process (emuInited
// in retro_init). From the second game or the second retro_deinit on, they point into freed memory. It went
// unseen while the allocator handed the same block back. Once other cores had dirtied the heap, Sh4Interpreter::
// Reset read a stale CpuRunning: the disc drew no frame, or the process crashed (FlycastCoreTests after
// CoreOptionsTests; MallocScribble=1 shows it on an empty heap). With virtual memory the blocks never move, so
// this is also what upstream's other builds do: clear them, keep them.
//
// shortcut: the blocks are kept for the life of the process (about 26 MB touched after a Dreamcast game) and
// reused while the sizes match. Another platform's sizes take upstream's path, which moves them.
#include "hw/mem/addrspace.h"
#include "hw/aica/aica_if.h"
#include "hw/pvr/pvr_mem.h"
#include "hw/pvr/elan.h"
#include "hw/sh4/dyna/blockmanager.h"
#include "hw/sh4/sh4_mem.h"
#include "oslib/oslib.h"
#include "oslib/virtmem.h"
#include <cassert>

#define initMappings gaga_flycast_upstream_initMappings
#define release gaga_flycast_upstream_release
#include "hw/mem/addrspace.cpp"
#undef initMappings
#undef release

namespace addrspace {

static u32 s_kept[4]; // RAM, VRAM, ARAM and Elan RAM sizes the live blocks were allocated for.

void initMappings() {
    const u32 now[4] = { (u32)RAM_SIZE, (u32)VRAM_SIZE, (u32)ARAM_SIZE, (u32)elan::ERAM_SIZE };
    if (ram_base == nullptr && p_sh4rcb != nullptr && memcmp(s_kept, now, sizeof(now)) == 0) {
        memset(&p_sh4rcb->cntx, 0, sizeof(p_sh4rcb->cntx));
        aica::aica_ram.zero();
        vram.zero();
        mem_b.zero();
        return;
    }
    gaga_flycast_upstream_initMappings();
    memcpy(s_kept, now, sizeof(now));
}

void release() {
    if (ram_base != nullptr) gaga_flycast_upstream_release();
}

} // namespace addrspace
