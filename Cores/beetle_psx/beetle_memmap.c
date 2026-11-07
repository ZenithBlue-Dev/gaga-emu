// Stands in for upstream/libretro-common/memmap/memmap.c, which is not compiled: besides the page reservation
// below it holds read-write-execute allocators for dynarecs (memjit_alloc, memprotect). Only data_transfer.c calls
// into it, for these six. They answer as on a platform that cannot reserve address space, which memmap.h names
// as a supported case: memreserve returns NULL and data_transfer.c reads the whole file into the heap instead.
// So no page protection ever changes, and the framework imports no mprotect.
#include <memmap.h>

size_t mempagesize(void) { return 0; }

void* memreserve(size_t len) {
    (void)len;
    return NULL;
}

bool memcommit(void* addr, size_t len) {
    (void)addr, (void)len;
    return false;
}

bool memrearm(void* addr, size_t len) {
    (void)addr, (void)len;
    return false;
}

void memdecommit(void* addr, size_t len, bool strict) { (void)addr, (void)len, (void)strict; }

void memrelease(void* addr, size_t len) { (void)addr, (void)len; }
