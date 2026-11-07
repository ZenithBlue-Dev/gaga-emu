// Builds upstream's sources/src/cpuboard.c (accelerator boards), which scripts/build-core.sh's source audit flags,
// after reading it (docs/04 section 8). Its hits toggle a map-ROM area between read-only and read-write, never
// executable, and only when currprefs.cachesize (the JIT cache) is set, which a build without JIT never does.
#include "upstream/sources/src/cpuboard.c"
