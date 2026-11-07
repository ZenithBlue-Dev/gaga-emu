// Common/MemoryUtil.h for GagaEmu, in place of upstream's MemoryUtil.cpp: memory is only ever readable and
// writable. Nothing here maps executable pages or changes a page's protection (docs/04).
#include "Common/MemoryUtil.h"

#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

static size_t page_round(size_t size) {
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    return (size + page - 1) & ~(page - 1);
}

void* AllocateExecutableMemory(size_t size) {
    (void)size;
    return nullptr;
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
    FreeMemoryPages(ptr, size);
}

void FreeAlignedMemory(void* ptr) {
    free(ptr);
}

bool PlatformIsWXExclusive() {
    return true;
}

bool ProtectMemoryPages(const void* ptr, size_t size, uint32_t memProtFlags) {
    (void)ptr;
    (void)size;
    (void)memProtFlags;
    return false;
}

int GetMemoryProtectPageSize() {
    return (int)sysconf(_SC_PAGESIZE);
}
