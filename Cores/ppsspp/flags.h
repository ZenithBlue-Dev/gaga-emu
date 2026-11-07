// Forced into every PPSSPP file by core.env (-include flags.h).
#pragma once

#include "ppsspp_config.h"

// No OpenGL of any kind (docs/05). GPU.cpp and Config.cpp then never offer the GLES back end, and
// Common/GPU/OpenGL is not compiled (generate.py). Video is Vulkan on MoltenVK, or the software renderer.
#undef PPSSPP_API_ANY_GL

// VulkanLoader.cpp can load a Vulkan library by name. Here the Vulkan entry point only ever comes from the
// frontend (LibretroVulkan.c, through the context negotiation interface), so the name lookup is replaced by
// one that finds nothing (PpssppSupport.cpp) and the framework never imports dlopen.
#define dlopen gaga_ppsspp_no_dlopen
#ifdef __cplusplus
extern "C"
#endif
void* gaga_ppsspp_no_dlopen(const char* path, int mode);
