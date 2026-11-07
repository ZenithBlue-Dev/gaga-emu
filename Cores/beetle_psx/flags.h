// Forced into every Beetle PSX file by core.env (-include flags.h).
#pragma once

// libretro.c's version string. upstream's Makefile asks git; this is the pinned commit.
#define GIT_VERSION " 71ee81e7"

// The Vulkan renderer can load a Vulkan library by name when the frontend gives it no vkGetInstanceProcAddr
// (rhi_lib_vulkan.c, context_init_loader). LibretroVulkan.c always gives it one, so the lookup is replaced
// by one that finds nothing (BeetlePsxCore.c) and the framework never imports dlopen.
#define dlopen gaga_beetle_psx_no_dlopen
