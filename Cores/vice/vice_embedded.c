// Stands in for upstream's retrodep/embedded.c and retrodep/embedded/c64embedded.c, which compile Commodore's
// KERNAL, BASIC, character and drive ROMs into the core. Nothing is embedded here, so sysfile_load falls through to
// the player's own files in the system folder (vice_sysfile.c), and palettes to VICE's internal one.
#include "embedded.h"

size_t embedded_check_extra(const char *name, uint8_t *dest, int minsize, int maxsize) {
    (void)name; (void)dest; (void)minsize; (void)maxsize;
    return 0;
}

size_t embedded_check_file(const char *name, uint8_t *dest, int minsize, int maxsize) {
    (void)name; (void)dest; (void)minsize; (void)maxsize;
    return 0;
}

int embedded_palette_load(const char *file_name, palette_t *palette_return) {
    (void)file_name; (void)palette_return;
    return -1;
}
