// The files upstream's embed-binaries step turns into C arrays, included as they are. build-core.sh
// compiles from Cores/melonds_ds, which the paths are relative to. A size that differs from
// include/embedded/assets.h stops the build. The wfc.cfg copy ends with a NUL, as upstream's does.
#define GAGA_ASSET(name, path, size, extra) \
    ".globl _" name "\n.p2align 4\n_" name ":\n.incbin \"" path "\"\n" extra \
    ".if . - _" name " != " #size "\n.error \"" path " is not " #size " bytes\"\n.endif\n"

__asm__(".section __TEXT,__const\n"
    GAGA_ASSET("embedded_melondsds_default_wfc_config", "upstream/src/libretro/assets/wfc.cfg", 970, ".byte 0\n")
    GAGA_ASSET("embedded_melondsds_graphic_error", "upstream/src/libretro/assets/melon-error.png", 2136, "")
    GAGA_ASSET("embedded_melondsds_graphic_sorry", "upstream/src/libretro/assets/melon-sorry.png", 2121, "")
    GAGA_ASSET("embedded_melondsds_error_title_font", "upstream/src/libretro/assets/OpenSans-ExtraBold.ttf", 131248, "")
    GAGA_ASSET("embedded_melondsds_error_body_font", "upstream/src/libretro/assets/OpenSans_Condensed-SemiBold.ttf", 130528, "")
    ".text\n");
