// FinalBurn Neo behind the GagaBridge interface, through the shared libretro adapter. An alternate arcade core
// for sideload builds only: its licence forbids seeking profit from it and asking for donations for a project
// that uses it (docs/03 section 5), so core.env sets CORE_NONCOMMERCIAL=1 and no App Store or TestFlight build
// may link it. FBNeo and MAME name their sets differently, so the player picks it per game (docs/03 section 8).
// No BIOS is bundled: a Neo Geo set needs the player's own neogeo.zip next to it or in the system folder.
#include "LibretroAdapter.h"

#include <errno.h>
#include <pthread.h>
#include <semaphore.h>
#include <string.h>

// The stubs no_thread.h points upstream's calls at: no semaphore, so thready.h never starts its thread.
sem_t* gaga_fbneo_no_sem_open(const char* name, int flags, ...) {
    (void)name, (void)flags;
    errno = ENOSYS;
    return SEM_FAILED;
}
int gaga_fbneo_no_pthread_create(pthread_t* thread, const pthread_attr_t* attributes, void* (*start)(void*), void* argument) {
    (void)thread, (void)attributes, (void)start, (void)argument;
    return EAGAIN;
}

// Option values are upstream's spelling. Patched sets (system/fbneo/patched) keep upstream's default: on.
static const GagaLibretroVariable s_variables[] = {
    { "fbneo-allow-patched-romsets", "enabled" },
    { "fbneo-samplerate", "48000" },
    { "fbneo-frameskip-type", "disabled" },
    { "fbneo-cpu-speed-adjust", "100%" },
    { "fbneo-diagnostic-input", "None" },
    { "fbneo-vertical-mode", "disabled" },
    { "fbneo-cyclone", "disabled" },
    { NULL, NULL },
};

// A zip or 7z archive. Upstream also takes cue, ccd, chd and m3u (Neo Geo CD); those stay out of this build's
// list, so a disc never reaches a core that needs a CD BIOS GagaEmu does not ship.
static bool fbneo_is_rom(const uint8_t* data, size_t size) {
    static const uint8_t zip[] = { 'P', 'K', 3, 4 };
    static const uint8_t sevenzip[] = { '7', 'z', 0xBC, 0xAF, 0x27, 0x1C };
    return (size >= sizeof(zip) && memcmp(data, zip, sizeof(zip)) == 0)
        || (size >= sizeof(sevenzip) && memcmp(data, sevenzip, sizeof(sevenzip)) == 0);
}

// No cheats: upstream's retro_cheat_set does nothing. NVRAM is upstream's own file, written when the game
// closes, in the save folder's fbneo subfolder.
const GagaLibretroCore gaga_libretro_core = {
    .name = "FinalBurn Neo",
    .game_kind = "an FBNeo ROM set (a .zip named after the game) for a game in this build",
    .variables = s_variables,
    .is_rom = fbneo_is_rom,
};

const GagaCoreInterface* Fbneo_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        .core_id = "fbneo",
        .core_name = "FinalBurn Neo",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "zip|7z",
        // shortcut: one rate per core; arcade boards run from about 50 to 60 Hz. Add a per-game rate to the bridge.
        .target_fps = 60.0,
        .native_sample_rate = 48000, // fbneo-samplerate, set above.
        .state_version = 1,          // Upstream's state data carries the driver's version, which it checks.
    };
    return &interface;
}
