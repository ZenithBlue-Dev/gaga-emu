// Builds upstream's sysfile.c with one change: a system file VICE cannot find under <system>/vice/<machine> is also
// looked for at the top of the system folder, where the BIOS Files screen puts it (kernal-901227-03.bin and so on).
char *gaga_vice_findpath(const char *cmd, const char *syspath, const char *subpath, int mode);
#define findpath gaga_vice_findpath
#include "upstream/vice/src/sysfile.c"
#undef findpath

char *findpath(const char *cmd, const char *syspath, const char *subpath, int mode);
extern char retro_system_directory[];

char *gaga_vice_findpath(const char *cmd, const char *syspath, const char *subpath, int mode) {
    char *found = findpath(cmd, syspath, subpath, mode);
    if (found == NULL && retro_system_directory[0] != '\0') {
        found = findpath(cmd, retro_system_directory, NULL, mode);
    }
    return found;
}
