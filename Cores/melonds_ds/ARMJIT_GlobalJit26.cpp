// Sideload JIT build only (jit.env), in place of melonDS's ARMJIT_Global.cpp. Code memory is a debugger-prepared RX
// region (Cores/shared/Jit26.c); the JIT writes through its RW alias, which the ARMJIT_Compiler.cpp copy that jit.env
// writes hands the emitter. Without one (no debugger, JIT not requested) it is plain RW memory: the compiler still
// builds its trampolines at start-up, but melonds_jit_enable stays "disabled", so nothing there ever runs.
#include "ARMJIT_Global.h"
#include "ARMJIT_Memory.h"

#include "../shared/Jit26.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include <mutex>

namespace melonDS
{
namespace ARMJIT_Global
{

std::mutex globalMutex;
int RefCounter = 0;

void* AllocateCodeMem()
{
    std::lock_guard guard(globalMutex);
    if (void* rx = gaga_jit26_alloc(CodeMemorySliceSize)) return rx;
    if (gaga_jit26_wanted()) printf("[gaga-core] jit26: melonDS got no JIT region; its JIT must not run\n");
    void* rw = mmap(nullptr, CodeMemorySliceSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    return rw == MAP_FAILED ? nullptr : rw;
}

void FreeCodeMem(void* codeMem)
{
    std::lock_guard guard(globalMutex);
    // gaga_jit26_free unmaps a plain region as well: it only drops the RW alias of one it handed out.
    gaga_jit26_free(codeMem, CodeMemorySliceSize);
}

void Init()
{
    std::lock_guard guard(globalMutex);
    if (++RefCounter == 1) ARMJIT_Memory::RegisterFaultHandler();
}

void DeInit()
{
    std::lock_guard guard(globalMutex);
    if (--RefCounter == 0) ARMJIT_Memory::UnregisterFaultHandler();
}

}
}

// ARMJIT_Memory.cpp backs the emulated RAM with a shared memory object even without fastmem (which melonDS never
// uses on Apple). MelonDSJit26.h routes its shm_open here: when the sandbox refuses one, an unlinked temporary file.
extern "C" int gaga_melonds_shm_open(const char* name, int flags, mode_t mode)
{
    int fd = shm_open(name, flags, mode);
    if (fd >= 0) return fd;
    char path[1024];
    size_t n = confstr(_CS_DARWIN_USER_TEMP_DIR, path, sizeof path);
    if (n == 0 || n + sizeof "melonds-ram-XXXXXX" > sizeof path) return -1;
    strcat(path, "melonds-ram-XXXXXX");
    fd = mkstemp(path);
    if (fd >= 0) unlink(path);
    return fd;
}
