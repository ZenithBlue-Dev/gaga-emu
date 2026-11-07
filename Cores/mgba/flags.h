// Forced into every compile with -include. Upstream's CMake passes the same names as -D flags.
// Everything unset here is off: debugger, GDB stub, scripting, Qt, SDL, FFmpeg, zip, PNG, SQLite,
// ELF, networking, the updater, OpenGL and the Game Boy core.
#ifndef FLAGS_H
#define FLAGS_H

#define MINIMAL_CORE 2
#define DISABLE_THREADING 1
#define M_CORE_GBA 1

#define HAVE_LOCALE 1
#define HAVE_LOCALTIME_R 1
#define HAVE_SNPRINTF_L 1
#define HAVE_STRDUP 1
#define HAVE_STRLCPY 1
#define HAVE_STRTOF_L 1
#define HAVE_XLOCALE 1

#endif
