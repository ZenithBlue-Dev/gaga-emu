// Vulkan hardware rendering for a libretro core, on MoltenVK, presenting to the host's CAMetalLayer
// (docs/05 section 2.3). Under libretro the frontend owns the Vulkan context, so this file is that
// frontend: it creates the instance and device (or lets the core create the device through the context
// negotiation interface), answers RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE, and copies the image the
// core hands set_image into the layer's swapchain. Host shaders do not run on this path. Attached with no
// layer, it hands each frame to the host as a Metal texture instead, for host shaders (docs/05 section 2.4).
//
// A core that asks for RETRO_HW_CONTEXT_VULKAN:
//   - sets CORE_USES_MOLTENVK=1 in core.env, which links MoltenVK statically into its framework,
//   - adds -DGAGA_LIBRETRO_VULKAN and -I../../build/moltenvk/include to both flag sets,
//   - lists ../shared/LibretroVulkan.c after ../shared/LibretroAdapter.c in sources.txt,
//   - adds GAGA_LIBRETRO_VULKAN_LAYER to its getter, after GAGA_LIBRETRO_ENTRY_POINTS.
#ifndef GAGA_LIBRETRO_VULKAN_H
#define GAGA_LIBRETRO_VULKAN_H

#include "LibretroAdapter.h"

#ifdef __cplusplus
extern "C" {
#endif

bool gaga_lr_attach_metal_layer(GagaInstance* inst, void* layer, uint32_t width_px, uint32_t height_px, float content_scale);
void gaga_lr_detach_metal_layer(GagaInstance* inst);
bool gaga_lr_read_layer_pixels(GagaInstance* inst, void* pixels, size_t capacity, uint32_t* width, uint32_t* height);

#define GAGA_LIBRETRO_VULKAN_LAYER \
    .capabilities = GAGA_CORE_CAP_METAL_LAYER | GAGA_CORE_CAP_OUTPUT_TEXTURE, \
    .attach_metal_layer = gaga_lr_attach_metal_layer, \
    .detach_metal_layer = gaga_lr_detach_metal_layer, \
    .read_layer_pixels = gaga_lr_read_layer_pixels

// The rest is for LibretroAdapter.c, which calls these only when built with GAGA_LIBRETRO_VULKAN.

// The hardware rendering environment calls. False for any other command.
bool lr_vk_environment(unsigned command, void* data);
// True once the core asked for a Vulkan context, until lr_vk_release.
bool lr_vk_requested(void);
// After retro_load_game: instance, device, then the core's context_reset. False fills error.
bool lr_vk_create_context(char* error, size_t capacity);
// Before retro_unload_game: the core's context_destroy.
void lr_vk_destroy_context(void);
// After retro_unload_game: the core's destroy_device, then everything this file created.
void lr_vk_release(void);
// From retro_video_refresh. dupe is a NULL frame. skip is a frame the host drops (fast-forward): its
// semaphores are still waited on, but nothing is presented. True when a new frame went to the layer path.
bool lr_vk_present(unsigned width, unsigned height, bool dupe, bool skip);
// After lr_vk_present returned true: on the output-texture path fills frame and returns true. The caller
// must then hand frame to the host, which owes the done signal from then on.
bool lr_vk_output_frame(GagaMetalTextureFrame* frame);
// Returns with no GPU work in flight, so nothing runs after the host pauses for the background.
void lr_vk_wait_idle(void);
// Debug pacing log, only with GAGA_PACE_LOG in the environment: begin and end bracket retro_run, and a frame over
// 25 ms logs its waits. before_present takes the uptime its wait started at.
void lr_vk_pace_begin(void);
void lr_vk_pace_end(void);
void lr_vk_pace_before_present(uint64_t start);
// Defined by LibretroAdapter.c: a FATAL event for the running game, such as a lost device.
void gaga_lr_report_fatal(const char* message);

#ifdef __cplusplus
}
#endif

#endif // GAGA_LIBRETRO_VULKAN_H
