// Upstream's libretro/LibretroGraphicsContext.cpp without its OpenGL context, which is not compiled (flags.h).
// Its OpenGL branch, taken only when the frontend prefers OpenGL or names nothing, makes the Vulkan context
// instead. ppsspp_backend is "vulkan" (PpssppCore.c), so that branch is not reached.
#include "libretro/LibretroGLContext.h"
#define LibretroGLContext LibretroVulkanContext
#include "upstream/libretro/LibretroGraphicsContext.cpp"
