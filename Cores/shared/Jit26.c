// Sideload JIT only: see Jit26.h. Protocol: StikDebug's universal.js (StikDebug/Scripts/universal.js upstream),
// also used by Play! (jpd002/Play--CodeGen pull 34) and the other apps StikDebug lists for iOS 26.
#include "Jit26.h"

#include <TargetConditionals.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/proc.h>
#include <sys/sysctl.h>
#include <unistd.h>

// scripts/nojit-gate.sh refuses any build but the DevJIT configuration that holds this string (DevJITOption.swift).
__attribute__((used)) static const char s_marker[] = "GAGA_DEV_JIT_OPTION_MARKER";

#define JIT26_PAGE 0x4000u
#define CS_OPS_STATUS 0
#define CS_DEBUGGED 0x10000000u
int csops(pid_t pid, unsigned int ops, void* useraddr, size_t usersize);

typedef struct { uintptr_t rx, rw; size_t size; } Jit26Map;
static Jit26Map s_maps[16]; // PPSSPP asks for two: the CPU JIT's 16 MiB and the vertex decoder's 256 KiB.
static pthread_mutex_t s_lock = PTHREAD_MUTEX_INITIALIZER;

#define jit26_log(...) do { printf("[gaga-core] jit26: " __VA_ARGS__); printf("\n"); fflush(stdout); } while (0)

bool gaga_jit26_may_brk(uint32_t cs_flags, int p_flag) {
    return (cs_flags & CS_DEBUGGED) && (p_flag & P_TRACED);
}

// Both flags of this process, so the log can say which one is missing.
static void jit26_flags(uint32_t* cs_flags, int* p_flag) {
    *cs_flags = 0;
    *p_flag = 0;
#if !TARGET_OS_SIMULATOR
    if (csops(getpid(), CS_OPS_STATUS, cs_flags, sizeof *cs_flags) != 0) *cs_flags = 0;
    struct kinfo_proc info;
    size_t len = sizeof info;
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    memset(&info, 0, sizeof info);
    if (sysctl(mib, 4, &info, &len, NULL, 0) == 0) *p_flag = info.kp_proc.p_flag;
#endif
}

bool gaga_jit26_debugged(void) {
    uint32_t cs;
    int p;
    jit26_flags(&cs, &p);
    return gaga_jit26_may_brk(cs, p);
}

// mov x16, #1; brk #0xf00d: the debugger returns the region in x0. Naked, so x0 and x1 reach it untouched.
__attribute__((naked, noinline)) static void* jit26_prepare_region(void* addr, size_t len) {
    __asm__ volatile("mov x16, #1\n brk #0xf00d\n ret");
}

void* gaga_jit26_alloc(size_t size) {
    if (!gaga_jit26_debugged() || size == 0) return NULL; // A brk with no debugger is SIGTRAP.
    size = (size + JIT26_PAGE - 1) & ~(size_t)(JIT26_PAGE - 1);
    uintptr_t rx = (uintptr_t)jit26_prepare_region(NULL, size);
    // An unserviced brk leaves junk in x0 (universal.js answers 0xE0000069 to the old protocol): demand a page.
    if (rx == 0 || (rx & (JIT26_PAGE - 1))) {
        jit26_log("the debugger gave no region for %zu bytes (x0 = 0x%lx)", size, (unsigned long)rx);
        return NULL;
    }
    vm_address_t rw = 0;
    vm_prot_t cur = 0, max = 0;
    kern_return_t kr = vm_remap(mach_task_self(), &rw, size, 0, VM_FLAGS_ANYWHERE, mach_task_self(), rx, FALSE,
                                &cur, &max, VM_INHERIT_NONE);
    if (kr == KERN_SUCCESS) kr = vm_protect(mach_task_self(), rw, size, FALSE, VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        jit26_log("no RW alias for 0x%lx: kern_return %d", (unsigned long)rx, kr);
        if (rw) vm_deallocate(mach_task_self(), rw, size);
        return NULL;
    }
    pthread_mutex_lock(&s_lock);
    Jit26Map* slot = NULL;
    for (size_t i = 0; i < sizeof s_maps / sizeof s_maps[0] && !slot; ++i) {
        if (!s_maps[i].rx) slot = &s_maps[i];
    }
    if (slot) *slot = (Jit26Map){ rx, rw, size };
    pthread_mutex_unlock(&s_lock);
    if (!slot) {
        vm_deallocate(mach_task_self(), rw, size);
        jit26_log("too many regions");
        return NULL;
    }
    jit26_log("region rx=0x%lx rw=0x%lx size=%zu", (unsigned long)rx, (unsigned long)rw, size);
    return (void*)rx;
}

void* gaga_jit26_writable(const void* rx) {
    uintptr_t p = (uintptr_t)rx, rw = p;
    pthread_mutex_lock(&s_lock);
    for (size_t i = 0; i < sizeof s_maps / sizeof s_maps[0]; ++i) {
        if (s_maps[i].rx && p >= s_maps[i].rx && p < s_maps[i].rx + s_maps[i].size) rw = s_maps[i].rw + (p - s_maps[i].rx);
    }
    pthread_mutex_unlock(&s_lock);
    return (void*)rw;
}

void gaga_jit26_free(void* rx, size_t size) {
    if (!rx) return;
    pthread_mutex_lock(&s_lock);
    for (size_t i = 0; i < sizeof s_maps / sizeof s_maps[0]; ++i) {
        if (s_maps[i].rx == (uintptr_t)rx) {
            vm_deallocate(mach_task_self(), s_maps[i].rw, s_maps[i].size);
            size = s_maps[i].size;
            s_maps[i] = (Jit26Map){ 0, 0, 0 };
        }
    }
    pthread_mutex_unlock(&s_lock);
    munmap(rx, size);
}

// Writes `mov w0, #42; ret` through the RW alias and runs it from the RX side. Kept, so it runs once per process.
static bool jit26_probe(void) {
    void* rx = gaga_jit26_alloc(JIT26_PAGE);
    if (!rx) return false;
    uint32_t* rw = gaga_jit26_writable(rx);
    rw[0] = 0x52800540; // mov w0, #42
    rw[1] = 0xd65f03c0; // ret
    sys_icache_invalidate(rx, 8);
    return ((int (*)(void))rx)() == 42;
}

bool gaga_jit26_wanted(void) {
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    static int works = -1, said = -1;
    const char* v = getenv("GAGA_JIT");
    bool want = v && strcmp(v, "1") == 0, ok = false;
    pthread_mutex_lock(&lock);
    if (want && works != 1 && gaga_jit26_debugged()) works = jit26_probe() ? 1 : 0;
    ok = want && works == 1;
    int state = !want ? 0 : ok ? 1 : 2;
    if (state != said) {
        said = state;
        if (state == 0) jit26_log("not requested: interpreter (%s)", s_marker);
        else if (state == 1) jit26_log("JIT engaged");
        else {
            uint32_t cs;
            int p;
            jit26_flags(&cs, &p);
            // CS_DEBUGGED outlives a detached debugger: without a tracer the brk would be SIGTRAP, so none is issued.
            if ((cs & CS_DEBUGGED) && !(p & P_TRACED)) jit26_log("requested, but CS_DEBUGGED without a tracer (debugger detached, or no JIT script): interpreter");
            else jit26_log("requested, but no debugger gave runnable memory (CS_DEBUGGED=%d P_TRACED=%d): interpreter", !!(cs & CS_DEBUGGED), !!(p & P_TRACED));
        }
    }
    pthread_mutex_unlock(&lock);
    return ok;
}
