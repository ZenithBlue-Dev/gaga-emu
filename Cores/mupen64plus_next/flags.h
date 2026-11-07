// Forced into every Mupen64Plus-Next file by core.env (-include flags.h).
#pragma once

// libretro.c's version string. upstream's Makefile asks git; this is the pinned commit.
#define GIT_VERSION " 15bada8"

// volk can load a Vulkan library by name. Here the Vulkan entry point only ever comes from the frontend
// (LibretroVulkan.c, through RETRO_HW_RENDER_INTERFACE_VULKAN), so the name lookup is replaced by one that
// finds nothing (nogl.c) and the framework never imports dlopen.
#define dlopen gaga_mupen_no_dlopen

// libretro.c's cothread entry can return, which crashes libco on aarch64. libco_gaga.c wraps it.
#define co_create gaga_co_create

// zlib's zutil.h replaces fdopen with NULL when it thinks it is on classic Mac OS, which breaks the SDK's
// stdio.h. Its #ifndef fdopen guard keeps the real one.
#define fdopen fdopen

// Every C++ file in this core is paraLLEl-RDP or Granite and calls Vulkan through volk's pointers. The C
// files that call MoltenVK directly (LibretroVulkan.c) must keep the real names.
#ifdef __cplusplus
#include "volk_rename.h"
#endif
