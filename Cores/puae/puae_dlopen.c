// Builds upstream's sources/src/caps/uae_dlopen.c without dlopen. retrodep/sysconfig.h sets HAVE_DLOPEN so caps.c can
// load the capsimg plug-in for IPF images at run time; an iOS app may not load code it did not ship. With HAVE_DLOPEN
// cleared, upstream's own fallback returns NULL, caps.c reports the library missing, and IPF images do not load.
#include "sysconfig.h"
#undef HAVE_DLOPEN
#include "upstream/sources/src/caps/uae_dlopen.c"
