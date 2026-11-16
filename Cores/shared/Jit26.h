// Sideload JIT only (docs/04 section 8.1): compiled into build/cores-jit by GAGA_JIT=1 scripts/build-core.sh, never
// into build/cores. Executable memory on iOS 26 TXM devices comes from an attached debugger: StikDebug's universal.js
// script or scripts/jit26_lldb.py answers `brk #0xf00d` (x16 = 1, x0 = 0, x1 = size) with an RX region it prepared,
// and the core writes through a second, RW mapping of the same pages. Without a debugger nothing here maps code.
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// The process runs under a debugger: csops CS_DEBUGGED and a live tracer (sysctl KERN_PROC_PID, P_TRACED). Needed
// before any brk, which would kill it otherwise. CS_DEBUGGED alone stays set after a debugger detaches.
bool gaga_jit26_debugged(void);
// The rule above on given flags (csops status, kp_proc.p_flag), for scripts/test-release-gate.sh.
bool gaga_jit26_may_brk(uint32_t cs_flags, int p_flag);
// A debugger-prepared RX region, size rounded up to 16 KiB, or NULL. Its RW alias: gaga_jit26_writable.
void* gaga_jit26_alloc(size_t size);
void gaga_jit26_free(void* rx, size_t size);
// The RW address of an RX address inside a region from gaga_jit26_alloc, or rx itself when it is in none.
void* gaga_jit26_writable(const void* rx);
// The host asked for JIT (GAGA_JIT=1, set by the DevJIT app) and a test region ran code. Logged once per answer.
bool gaga_jit26_wanted(void);

#ifdef __cplusplus
}
#endif
