// Upstream's statesav.c, compiled with its file names kept whole. Retro_SaveFNAME drops the working directory and
// one more character from a name under it, as a relative path. An iOS app runs in "/", so every absolute path lost
// "/p" ("rivate/var/..."), a loaded state reinserted a cartridge that does not exist, and the next state was
// another size (device run 6). With getcwd failing here, the full path is saved and the cartridge stays in.
#include <unistd.h>

static char* gaga_no_working_directory(char* buffer, size_t size) {
    (void)buffer;
    (void)size;
    return NULL;
}
#define getcwd gaga_no_working_directory

#include "upstream/atari800/src/statesav.c"
