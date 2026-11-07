// SwanStation behind the GagaBridge interface, through the shared libretro adapter. An alternate PS1 core: the
// cached interpreter and the software renderer only. core.env builds it with WITH_RECOMPILER and fastmem off,
// so no code is generated at run time. With no BIOS file in the system folder the core boots the OpenBIOS
// build it embeds (upstream/dep/openbios, MIT), so GagaEmu ships no Sony BIOS. Memory card 1 is the battery
// save; card 2 is off.
#include "LibretroAdapter.h"

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

// The stubs no_exec.h points upstream's calls at (see that file).
void* gaga_swanstation_no_dlopen(const char* path, int mode) {
    (void)path, (void)mode;
    return NULL;
}
void* gaga_swanstation_no_dlsym(void* handle, const char* symbol) {
    (void)handle, (void)symbol;
    return NULL;
}
int gaga_swanstation_no_dlclose(void* handle) {
    (void)handle;
    return 0;
}
// The system mprotect, which no_exec.h renamed in <sys/mman.h>. Called only for none, read and write.
#undef mprotect
int mprotect(void* address, size_t size, int protection);
int gaga_swanstation_no_exec_mprotect(void* address, size_t size, int protection) {
    if (protection & ~(PROT_READ | PROT_WRITE)) {
        errno = EPERM;
        return -1;
    }
    return mprotect(address, size, protection);
}
// An unlinked temporary file in place of a shared memory object. Only MemoryArena::Create calls this.
int gaga_swanstation_shm_open(const char* name, int flags, ...) {
    (void)name, (void)flags;
    const char* folder = getenv("TMPDIR");
    char path[1024];
    if (snprintf(path, sizeof(path), "%s/gaga-swanstation-XXXXXX", folder && *folder ? folder : "/tmp") >= (int)sizeof(path)) {
        errno = ENAMETOOLONG;
        return -1;
    }
    int fd = mkstemp(path);
    if (fd >= 0) unlink(path);
    return fd;
}
int gaga_swanstation_shm_unlink(const char* name) {
    (void)name;
    return 0;
}

// Option values are upstream's spelling. A key not listed reads as unset, which upstream treats as its default.
static const GagaLibretroVariable s_variables[] = {
    { "swanstation_CPU_ExecutionMode", "CachedInterpreter" },
    { "swanstation_CPU_FastmemMode", "Disabled" },
    { "swanstation_GPU_Renderer", "Software" },
    { "swanstation_GPU_UseThread", "false" },    // Frames come back in step with retro_run.
    { "swanstation_CDROM_ReadThread", "false" }, // Disc reads in step with retro_run, so states are exact.
    { "swanstation_Console_Region", "Auto" },
    { "swanstation_MemoryCards_Card1Type", "Libretro" }, // RETRO_MEMORY_SAVE_RAM, which the adapter writes to <game>.sav.
    { "swanstation_MemoryCards_Card2Type", "None" },
    { "swanstation_Display_ShowOSDMessages", "false" },
    { "swanstation_Controller_EnableRumble", "false" },
    { "swanstation_Main_RunaheadFrameCount", "0" },
    { NULL, NULL },
};

static bool ss_is_hex(const char* text, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        char c = text[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) return false;
    }
    return true;
}

// GameShark "TTAAAAAA VVVV" codes that stand alone, as for PCSX-ReARMed: constant writes (30, 80), increments
// and decrements (10, 11, 20, 21) and the scratchpad write (1F). The adapter gives each line its own libretro
// cheat, so conditional codes and slides, which act on the line after them, are refused.
static bool ss_is_cheat(const char* line) {
    if (strlen(line) != 13 || line[8] != ' ' || !ss_is_hex(line, 8) || !ss_is_hex(line + 9, 4)) return false;
    static const char* const types[] = { "30", "80", "10", "11", "20", "21", "1F", "1f" };
    for (size_t i = 0; i < sizeof(types) / sizeof(types[0]); ++i) {
        if (line[0] == types[i][0] && line[1] == types[i][1]) return true;
    }
    return false;
}

const GagaLibretroCore gaga_libretro_core = {
    .name = "SwanStation",
    .game_kind = "a PlayStation game",
    .variables = s_variables,
    .is_cheat = ss_is_cheat,
};

const GagaCoreInterface* SwanStation_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_CHEATS,
        .core_id = "swanstation",
        .core_name = "SwanStation",
        .core_version = GAGA_CORE_VERSION,
        // libretro_host_interface.cpp's list. ".exe" boots a PS-EXE, ".m3u" is a disc list.
        .supported_extensions = "exe|psexe|cue|bin|img|iso|chd|pbp|ecm|mds|psf|m3u",
        .target_fps = 60.0,          // NTSC. PAL games want 50.
        .native_sample_rate = 44100, // retro_get_system_av_info.
        .state_version = 57,         // SAVE_STATE_VERSION in core/save_state_version.h.
    };
    return &interface;
}
