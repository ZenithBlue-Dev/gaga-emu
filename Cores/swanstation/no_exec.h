// Included before every SwanStation source (core.env). These names point upstream's calls at stubs in
// SwanStationCore.c, so the binary imports none of them:
// - dlopen, dlsym, dlclose: the GL and Vulkan loaders (glad.c, vulkan_loader.cpp) look for system libraries.
//   This build runs only the software renderer, so they find none and the core never loads code.
// - mprotect: the stub refuses PROT_EXEC and passes every other protection on. libretro-common memmap.c
//   commits reserved pages with it for formats/data_transfer.c, and its memprotect (RWX, never called here)
//   would be refused. MemoryArena::SetPageProtection is fastmem only, which needs the recompiler.
// - shm_open, shm_unlink: MemoryArena backs the 2 MB RAM with POSIX shared memory, which the iOS sandbox may
//   refuse. The stub gives an unlinked file in the app's tmp folder instead, which MAP_SHARED maps the same way.
#define dlopen gaga_swanstation_no_dlopen
#define dlsym gaga_swanstation_no_dlsym
#define dlclose gaga_swanstation_no_dlclose
#define mprotect gaga_swanstation_no_exec_mprotect
#define shm_open gaga_swanstation_shm_open
#define shm_unlink gaga_swanstation_shm_unlink
