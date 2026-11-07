// Included before every PicoDrive source (core.env). upstream/platform/libretro/libretro.c keeps the glue its
// recompilers use: plat_mem_set_exec makes memory RWX with mprotect, and the cache helpers call the Mach
// icache calls. This build has no recompiler, so nothing calls them, but the calls would still link. These
// names point them at stubs in PicodriveCore.c that refuse or do nothing, and the binary imports none of them.
#define mprotect gaga_picodrive_no_mprotect
#define sys_icache_invalidate gaga_picodrive_no_icache_invalidate
#define sys_dcache_flush gaga_picodrive_no_dcache_flush
