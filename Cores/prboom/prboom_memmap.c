// Stands in for libretro-common's memmap/memmap.c, which is not built: it also holds helpers that map executable memory
// (memprotect, memjit_alloc). formats/data_transfer.c is the only caller, of the six address-reservation functions
// below. These are upstream's own answers on a platform without MEMMAP_HAVE_RESERVE: nothing reserved, so
// data_transfer reads whole files instead of windows. shortcut: large PK3/WAD files are read whole, upgrade if memory
// use on device says so.
#include <stddef.h>
#include <boolean.h>

size_t mempagesize(void) { return 0; }
void *memreserve(size_t len) { (void)len; return NULL; }
bool memcommit(void *addr, size_t len) { (void)addr; (void)len; return false; }
bool memrearm(void *addr, size_t len) { (void)addr; (void)len; return false; }
void memdecommit(void *addr, size_t len, bool strict) { (void)addr; (void)len; (void)strict; }
void memrelease(void *addr, size_t len) { (void)addr; (void)len; }
