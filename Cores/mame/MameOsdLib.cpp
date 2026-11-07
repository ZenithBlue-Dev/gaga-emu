// Replaces upstream/src/osd/modules/lib/osdlib_retro.cpp (generate.py). Upstream's file also maps executable
// memory, changes page protection, flushes the instruction cache and opens libraries, all for MAME's
// recompilers and optional OSD modules. None of those is compiled here, so they are left undefined: a
// recompiler that came back would fail to link instead of asking iOS for executable memory.
#include <cstdio>
#include <cstdlib>
#include <signal.h>
#include <unistd.h>

#include "osdcore.h"
#include "osdlib.h"

const char* osd_getenv(const char* name) {
    return getenv(name);
}

int osd_setenv(const char* name, const char* value, int overwrite) {
    return setenv(name, value, overwrite);
}

void osd_process_kill() {
    kill(getpid(), SIGKILL);
}

void osd_break_into_debugger(const char* message) {
    std::printf("Ignoring MAME exception: %s\n", message);
}

std::pair<std::error_condition, unsigned> osd_get_cache_line_size() noexcept {
    return std::make_pair(std::errc::not_supported, 0U);
}

// Upstream returns NULL into a std::string here, which throws.
std::string osd_get_clipboard_text() noexcept {
    return std::string();
}

std::error_condition osd_set_clipboard_text(std::string_view) noexcept {
    return std::errc::io_error;
}

int osd_getpid() noexcept {
    return getpid();
}
