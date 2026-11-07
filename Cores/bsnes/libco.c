// GagaEmu's own arm64 libco, in place of upstream/libco. Upstream's arm64 switch routine is machine code
// kept in a data array, which libco.c makes executable at run time under Clang. Here it is an ordinary
// compiled function, so nothing is ever made executable. Same API as upstream/libco/libco.h.
//
// One global active context, as upstream's single-threaded build has: the host's serial queue may run
// each step on a different thread, and bsnes takes co_active() as its host context on every entry.
#include <libco/libco.h>

#include <stdint.h>
#include <stdlib.h>

#if !defined(__aarch64__)
#error "libco.c is arm64 only, which is every slice this project builds"
#endif

// sp, lr, x19 to x29, d8 to d15: the registers AAPCS64 says a callee keeps.
typedef struct {
    uint64_t sp, lr, x[11], d[8];
} CoContext;

static CoContext co_host;
static cothread_t co_current = 0;

// Saves the caller's context into `from` and resumes `to`. A new context resumes at its entry point.
__attribute__((naked, noinline)) static void co_swap(cothread_t to, cothread_t from) {
    __asm__ volatile(
        "mov x16, sp\n"
        "stp x16, x30, [x1]\n"
        "stp x19, x20, [x1, #16]\n"
        "stp x21, x22, [x1, #32]\n"
        "stp x23, x24, [x1, #48]\n"
        "stp x25, x26, [x1, #64]\n"
        "stp x27, x28, [x1, #80]\n"
        "str x29, [x1, #96]\n"
        "stp d8, d9, [x1, #104]\n"
        "stp d10, d11, [x1, #120]\n"
        "stp d12, d13, [x1, #136]\n"
        "stp d14, d15, [x1, #152]\n"
        "ldp x16, x30, [x0]\n"
        "mov sp, x16\n"
        "ldp x19, x20, [x0, #16]\n"
        "ldp x21, x22, [x0, #32]\n"
        "ldp x23, x24, [x0, #48]\n"
        "ldp x25, x26, [x0, #64]\n"
        "ldp x27, x28, [x0, #80]\n"
        "ldr x29, [x0, #96]\n"
        "ldp d8, d9, [x0, #104]\n"
        "ldp d10, d11, [x0, #120]\n"
        "ldp d12, d13, [x0, #136]\n"
        "ldp d14, d15, [x0, #152]\n"
        "br x30\n");
}

cothread_t co_active(void) {
    if (!co_current) co_current = &co_host;
    return co_current;
}

// The context sits at the start of `memory` and the stack grows down from its end, as upstream lays it
// out, so bsnes can reuse a thread's memory and serialize it. The entry point must never return.
cothread_t co_derive(void* memory, unsigned int size, void (*entrypoint)(void)) {
    co_active();
    if (!memory || size < sizeof(CoContext) + 256) return 0;
    CoContext* context = memory;
    uint64_t top = ((uint64_t)(uintptr_t)memory + size) & ~(uint64_t)15;
    *context = (CoContext){ .sp = top, .lr = (uint64_t)(uintptr_t)entrypoint };
    context->x[10] = top; // x29, the frame pointer, so a backtrace stops here.
    return context;
}

cothread_t co_create(unsigned int size, void (*entrypoint)(void)) {
    void* memory = malloc(size);
    cothread_t thread = memory ? co_derive(memory, size, entrypoint) : 0;
    if (!thread) free(memory);
    return thread;
}

void co_delete(cothread_t thread) {
    if (thread != &co_host) free(thread);
}

void co_switch(cothread_t thread) {
    cothread_t previous = co_active();
    co_current = thread;
    co_swap(thread, previous);
}

// Contexts live inside their thread's memory, so a copy of that memory is a copy of the thread.
int co_serializable(void) { return 1; }
