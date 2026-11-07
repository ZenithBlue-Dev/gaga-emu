// Builds upstream's jlink_discover.c with its own "no networking" stubs: no UDP JagLink discovery on iOS. See
// nonet_jlink_tcp.c for why __APPLE__ is dropped after the system headers.
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef __APPLE__
#include "upstream/src/jerry/jlink_discover.c"
