// Sideload JIT build only (jit.env), in place of MemoryUtil.cpp: executable memory is a debugger-prepared RX region
// (Cores/shared/Jit26.c) that is never re-protected. The JIT writes through its RW alias: the CodeBlock.h copy that
// jit.env writes takes it from gaga_jit26_writable. Everything else matches MemoryUtil.cpp.
#include "Common/MemoryUtil.h"

#include "../shared/Jit26.h"

#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

static size_t page_round(size_t size) {
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    return (size + page - 1) & ~(page - 1);
}

void* AllocateExecutableMemory(size_t size) {
    return gaga_jit26_alloc(size);
}

void* AllocateMemoryPages(size_t size, uint32_t memProtFlags) {
    if (memProtFlags & ~(uint32_t)(MEM_PROT_READ | MEM_PROT_WRITE)) return nullptr;  // never executable
    void* ptr = mmap(nullptr, page_round(size), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    return ptr == MAP_FAILED ? nullptr : ptr;
}

void* AllocateAlignedMemory(size_t size, size_t alignment) {
    void* ptr = nullptr;
    if (alignment < sizeof(void*)) alignment = sizeof(void*);
    return posix_memalign(&ptr, alignment, size) == 0 ? ptr : nullptr;
}

void FreeMemoryPages(void* ptr, size_t size) {
    if (ptr) munmap(ptr, page_round(size));
}

void FreeExecutableMemory(void* ptr, size_t size) {
    gaga_jit26_free(ptr, size);
}

void FreeAlignedMemory(void* ptr) {
    free(ptr);
}

// RX and RW are separate mappings, so CodeBlock never flips a page's protection (TXM would refuse it).
bool PlatformIsWXExclusive() {
    return false;
}

bool ProtectMemoryPages(const void* ptr, size_t size, uint32_t memProtFlags) {
    (void)ptr;
    (void)size;
    (void)memProtFlags;
    return true;
}

int GetMemoryProtectPageSize() {
    return (int)sysconf(_SC_PAGESIZE);
}
