// libco for Mupen64Plus-Next, with a cothread entry that cannot return. flags.h renames libretro.c's
// co_create to gaga_co_create; this file compiles upstream's libco.c under the real name.
//
// Why: libretro.c never resets load_game_successful, so after one game a later retro_deinit with no game
// running (the adapter's self-test, or a failed load) switches to a fresh cothread. Its EmuThreadFunction
// finds no ROM and returns, and libco's aarch64 cothread has nothing to return to: the device crashed at
// pc 0 on the next core instance in the same process. Here the entry switches back to the cothread that
// created it, which is where libretro.c's retro_thread already points.
#undef co_create
#include "upstream/libretro-common/libco/libco.c"

cothread_t gaga_co_create(unsigned int size, void (*entrypoint)(void));

static void (*s_entry)(void);
static cothread_t s_creator;
static cothread_t s_thread;

static void gaga_co_entry(void) {
    s_entry();
    for (;;) co_switch(s_creator);
}

cothread_t gaga_co_create(unsigned int size, void (*entrypoint)(void)) {
    // libretro.c makes one per retro_init and never deletes it. The previous one has finished or never
    // run by now: retro_deinit switched back from it, and retro_init runs on the creating cothread.
    if (s_thread) co_delete(s_thread);
    s_entry = entrypoint;
    s_creator = co_active();
    s_thread = co_create(size, gaga_co_entry);
    return s_thread;
}
