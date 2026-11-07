// upstream's volk.c with its function pointers renamed (volk_rename.h), so they never meet MoltenVK's
// functions of the same names. The C++ files get the same names from flags.h.
#include "volk_rename.h"
#include "upstream/mupen64plus-video-paraLLEl/parallel-rdp/volk/volk.c"
