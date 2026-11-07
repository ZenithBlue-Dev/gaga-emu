// Builds upstream's gdbsock.c with its own "no BSD sockets" stubs: no GDB remote stub listener on iOS. See
// nonet_jlink_tcp.c for why __APPLE__ is dropped after the system headers.
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef __APPLE__
#include "upstream/src/debug/gdbsock.c"
