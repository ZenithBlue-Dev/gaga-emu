// Stand-ins for what libretro.c, plugin.c and cxd4 still name from GLideN64 and glsm, neither of which is
// compiled (core.env). The core options this framework answers (Mupen64PlusNextCore.c) pick paraLLEl-RDP,
// so no GLideN64 entry point is reached in a session. If one ever is, it does nothing and InitiateGFX
// reports failure, so the core stops with an error instead of drawing with GL.
#include <stdbool.h>
#include <stddef.h>

#include "m64p_plugin.h"

// flags.h maps volk's dlopen here: the Vulkan loader is never looked up by name.
void* gaga_mupen_no_dlopen(const char* path, int mode) {
    (void)path;
    (void)mode;
    return NULL;
}

// cxd4's su.h declares these and upstream's link gets them from GLideN64's globals of the same names.
// module.c sets both from RSP_INFO before the RSP runs.
unsigned char* DMEM;
unsigned char* IMEM;

// libretro.c: the GLideN64 threaded renderer, never started (mupen64plus-ThreadedRenderer is False).
bool threaded_gl_safe_shutdown;
void gln64_thr_gl_invoke_command_loop(void) {}

// glsm is the GL state manager. Every call is behind current_rdp_type == RDP_PLUGIN_GLIDEN64.
bool glsm_ctl(int state, void* data) {
    (void)state;
    (void)data;
    return false;
}

m64p_error gln64PluginGetVersion(m64p_plugin_type* type, int* version, int* api, const char** name, int* caps) {
    (void)type; (void)version; (void)api; (void)name; (void)caps;
    return M64ERR_UNSUPPORTED;
}
int gln64InitiateGFX(GFX_INFO info) { (void)info; return 0; }
int gln64RomOpen(void) { return 0; }
void gln64RomClosed(void) {}
void gln64MoveScreen(int x, int y) { (void)x; (void)y; }
void gln64ProcessDList(void) {}
void gln64ProcessRDPList(void) {}
void gln64ShowCFB(void) {}
void gln64UpdateScreen(void) {}
void gln64ViStatusChanged(void) {}
void gln64ViWidthChanged(void) {}
void gln64ChangeWindow(void) {}
void gln64FBWrite(unsigned int addr, unsigned int size) { (void)addr; (void)size; }
void gln64FBRead(unsigned int addr) { (void)addr; }
void gln64FBGetFrameBufferInfo(void* info) { (void)info; }
void gln64ReadScreen2(void* dest, int* width, int* height, int front) { (void)dest; (void)width; (void)height; (void)front; }
void gln64SetRenderingCallback(void (*callback)(int)) { (void)callback; }
void gln64DestroyGfxContext(void) {}
void gln64ReinitGfxContext(void) {}
