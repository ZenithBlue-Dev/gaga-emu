// Builds upstream's jlink_tcp.c with its own inert stubs (the "socketless console targets" branch): the core gets
// no TCP JagLink on iOS. That branch is chosen when __APPLE__ is not defined, so the system headers are included
// first and the macro is dropped only for upstream's file.
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef __APPLE__
#include "upstream/src/jerry/jlink_tcp.c"
