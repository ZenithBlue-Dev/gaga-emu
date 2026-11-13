// Sideload JIT build only (jit.env). lightrec's code buffer on Cores/shared/Jit26.c memory: one RX region, written
// through its RW alias. Lightning (jit.env's copies) emits at RX addresses and stores at + gaga_lightning_rw_delta;
// TLSF, whose block headers live inside the pool, runs on the RW alias while lightrec only ever sees RX addresses.
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "Jit26.h"
#include "upstream/deps/lightrec/tlsf/tlsf.h"

// cpu.c's lightrec_codebuffer (renamed by jit.env), LIGHTREC_CODEBUFFER_SIZE bytes, or NULL: no JIT.
uint8_t* gaga_beetle_codebuffer;
long gaga_lightning_rw_delta;

// In LibretroAdapterJit26.c's place of gaga_jit26_wanted: the host asked, a debugger gave runnable memory, and the
// code buffer exists, so beetle_psx_hw_cpu_dynarec may become "execute". Otherwise the interpreter, as in the store
// build. The buffer is kept for the life of the process; lightrec's re-inits reuse it.
bool gaga_beetle_jit_ready(void) {
    static bool failed;
    if (!gaga_jit26_wanted()) return false;
    if (!gaga_beetle_codebuffer && !failed) {
        uint8_t* rx = gaga_jit26_alloc(LIGHTREC_CODEBUFFER_SIZE);
        if (rx) {
            gaga_lightning_rw_delta = (long)((uint8_t*)gaga_jit26_writable(rx) - rx);
            gaga_beetle_codebuffer = rx;
        } else {
            failed = true;
            printf("[gaga-core] jit26: no region for lightrec's %d-byte code buffer: interpreter\n", LIGHTREC_CODEBUFFER_SIZE);
            fflush(stdout);
        }
    }
    return gaga_beetle_codebuffer != NULL;
}

// lightrec.c's TLSF calls (renamed by jit.env): the pool and its headers on the RW alias, RX addresses out.
tlsf_t gaga_tlsf_create_with_pool(void* mem, size_t bytes) {
    return tlsf_create_with_pool((uint8_t*)mem + gaga_lightning_rw_delta, bytes);
}

void* gaga_tlsf_malloc(tlsf_t tlsf, size_t bytes) {
    uint8_t* rw = tlsf_malloc(tlsf, bytes);
    return rw ? rw - gaga_lightning_rw_delta : NULL;
}

void* gaga_tlsf_realloc(tlsf_t tlsf, void* ptr, size_t size) {
    uint8_t* rw = tlsf_realloc(tlsf, ptr ? (uint8_t*)ptr + gaga_lightning_rw_delta : NULL, size);
    return rw ? rw - gaga_lightning_rw_delta : NULL;
}

void gaga_tlsf_free(tlsf_t tlsf, void* ptr) {
    if (ptr) tlsf_free(tlsf, (uint8_t*)ptr + gaga_lightning_rw_delta);
}
