// See LibretroVulkan.h. Every call arrives on the host's serial queue, as the rest of the adapter's do,
// so the state below has one writer. The queue lock exists because libretro lets a core submit from
// its own threads, and every vkQueueSubmit and vkQueuePresentKHR here takes it too.
#define VK_USE_PLATFORM_METAL_EXT 1 // VK_EXT_metal_surface, MoltenVK's surface for a CAMetalLayer.
#include "LibretroVulkan.h"

#include <libretro.h>
#include <libretro_vulkan.h>
#include <vulkan/vulkan.h>

#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

#define LR_VK_FRAMES 2     // Frames in flight: the sync index is 0 or 1.
#define LR_VK_MAX_IMAGES 4 // Swapchain images. MoltenVK gives at most 3, CAMetalLayer's drawable limit.
#define LR_VK_MAX_WAITS 8  // Semaphores a core may pass to set_image.
#define LR_VK_MAX_CMDS 8   // Command buffers a core may pass to set_command_buffers.

typedef struct {
    VkImage image;
    VkImageLayout layout;
    VkFormat format;
    VkImageSubresourceRange range;
    uint32_t queue_family;
    uint32_t width, height;
} LrVkImage;

typedef struct {
    bool requested;
    struct retro_hw_render_callback hw;
    const struct retro_hw_render_context_negotiation_interface_vulkan* negotiation;
    bool core_made_device; // The core's create_device succeeded, so its destroy_device is owed.
    bool context_live;     // context_reset ran, so context_destroy is owed.

    VkInstance instance;
    VkPhysicalDevice gpu;
    VkDevice device;
    VkQueue queue;
    uint32_t queue_family;
    struct retro_hw_render_interface_vulkan iface;

    VkCommandPool pool;
    VkCommandBuffer cmd[LR_VK_FRAMES];
    VkFence fence[LR_VK_FRAMES];
    VkSemaphore acquired[LR_VK_FRAMES];
    uint32_t index;

    // What the core handed over for the frame being built.
    bool has_image;
    LrVkImage image;
    VkSemaphore waits[LR_VK_MAX_WAITS];
    uint32_t wait_count;
    VkCommandBuffer core_cmds[LR_VK_MAX_CMDS];
    uint32_t core_cmd_count;
    VkSemaphore signal;

    bool presented; // last holds the frame read_layer_pixels copies.
    LrVkImage last;

    void* layer;
    uint32_t layer_width, layer_height; // Asked for before the device existed, or for a rebuild.
    VkSurfaceKHR surface;
    VkSwapchainKHR swapchain;
    VkExtent2D extent;
    uint32_t image_count;
    VkImage images[LR_VK_MAX_IMAGES];
    VkSemaphore rendered[LR_VK_MAX_IMAGES]; // One per image: a present may still wait on the last use.
} LrVulkan;

static LrVulkan s_vk;
static pthread_mutex_t s_queue_lock = PTHREAD_MUTEX_INITIALIZER;

// GagaEmu's ink letterbox (Palette.ink in AppTheme.swift), as the copy path's renderer clears to.
static const VkClearColorValue s_letterbox = { .float32 = { 0x1C / 255.0f, 0x1A / 255.0f, 0x17 / 255.0f, 1.0f } };

static void lr_vk_lock(void) { pthread_mutex_lock(&s_queue_lock); }
static void lr_vk_unlock(void) { pthread_mutex_unlock(&s_queue_lock); }

static void lr_vk_set_error(char* error, size_t capacity, const char* message) {
    if (error && capacity > 0) snprintf(error, capacity, "%s", message);
}

// MARK: - The interface the core calls

static void lr_vk_set_image(void* handle, const struct retro_vulkan_image* image, uint32_t count,
                            const VkSemaphore* semaphores, uint32_t src_queue_family) {
    (void)handle;
    s_vk.has_image = image != NULL;
    if (image) {
        s_vk.image = (LrVkImage){ .image = image->create_info.image, .layout = image->image_layout,
                                  .format = image->create_info.format, .range = image->create_info.subresourceRange,
                                  .queue_family = src_queue_family };
    }
    s_vk.wait_count = 0;
    for (uint32_t i = 0; i < count && i < LR_VK_MAX_WAITS; ++i) s_vk.waits[s_vk.wait_count++] = semaphores[i];
}

static uint32_t lr_vk_get_sync_index(void* handle) { (void)handle; return s_vk.index; }
static uint32_t lr_vk_get_sync_index_mask(void* handle) { (void)handle; return (1u << LR_VK_FRAMES) - 1; }

static void lr_vk_set_command_buffers(void* handle, uint32_t count, const VkCommandBuffer* cmds) {
    (void)handle;
    for (uint32_t i = 0; i < count && s_vk.core_cmd_count < LR_VK_MAX_CMDS; ++i) s_vk.core_cmds[s_vk.core_cmd_count++] = cmds[i];
}

static void lr_vk_wait_sync_index(void* handle) {
    (void)handle;
    vkWaitForFences(s_vk.device, 1, &s_vk.fence[s_vk.index], VK_TRUE, UINT64_MAX);
}

static void lr_vk_lock_queue(void* handle) { (void)handle; lr_vk_lock(); }
static void lr_vk_unlock_queue(void* handle) { (void)handle; lr_vk_unlock(); }
static void lr_vk_set_signal_semaphore(void* handle, VkSemaphore semaphore) { (void)handle; s_vk.signal = semaphore; }

// MARK: - Environment

bool lr_vk_requested(void) { return s_vk.requested; }

bool lr_vk_environment(unsigned command, void* data) {
    switch (command) {
    case RETRO_ENVIRONMENT_SET_HW_RENDER: {
        struct retro_hw_render_callback* hw = data;
        if (hw->context_type != RETRO_HW_CONTEXT_VULKAN) return false; // No OpenGL of any kind (docs/05 rule 4).
        hw->get_current_framebuffer = NULL; // Both are OpenGL only.
        hw->get_proc_address = NULL;
        s_vk.hw = *hw;
        s_vk.requested = true;
        return true;
    }
    case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER:
        *(unsigned*)data = RETRO_HW_CONTEXT_VULKAN;
        return true;
    case RETRO_ENVIRONMENT_GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT: {
        // Version 1: create_device. A core offering version 2 still gets its v1 entry points.
        struct retro_hw_render_context_negotiation_interface* query = data;
        query->interface_version = query->interface_type == RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN ? 1 : 0;
        return true;
    }
    case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE: {
        const struct retro_hw_render_context_negotiation_interface_vulkan* negotiation = data;
        if (negotiation->interface_type != RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN) return false;
        s_vk.negotiation = negotiation; // A core keeps it static: libretro says it lives until the context is up.
        return true;
    }
    case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE:
        if (!s_vk.device) return false;
        *(const struct retro_hw_render_interface**)data = (const struct retro_hw_render_interface*)&s_vk.iface;
        return true;
    case RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT:
        return true; // One queue for everyone already.
    default:
        return false;
    }
}

// MARK: - Context

static bool lr_vk_has(const VkExtensionProperties* list, uint32_t count, const char* name) {
    for (uint32_t i = 0; i < count; ++i) {
        if (strcmp(list[i].extensionName, name) == 0) return true;
    }
    return false;
}

static bool lr_vk_create_instance(char* error, size_t capacity) {
    VkApplicationInfo fallback = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .pApplicationName = "GagaEmu",
                                   .pEngineName = "GagaEmu", .apiVersion = VK_API_VERSION_1_1 };
    if (s_vk.hw.version_major > 0) {
        uint32_t asked = VK_MAKE_API_VERSION(0, s_vk.hw.version_major, s_vk.hw.version_minor, 0);
        if (asked > fallback.apiVersion) fallback.apiVersion = asked;
    }
    // libretro v1 lets get_application_info return NULL, so the fallback stays ready.
    const VkApplicationInfo* app = s_vk.negotiation && s_vk.negotiation->get_application_info ? s_vk.negotiation->get_application_info() : NULL;

    VkExtensionProperties available[64];
    uint32_t count = 64;
    vkEnumerateInstanceExtensionProperties(NULL, &count, available);
    const char* wanted[] = { VK_KHR_SURFACE_EXTENSION_NAME, VK_EXT_METAL_SURFACE_EXTENSION_NAME,
                             VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME };
    const char* enabled[3];
    uint32_t enabled_count = 0;
    for (size_t i = 0; i < 3; ++i) {
        if (lr_vk_has(available, count, wanted[i])) enabled[enabled_count++] = wanted[i];
    }
    if (enabled_count < 2) {
        lr_vk_set_error(error, capacity, "This device's Vulkan driver cannot draw to the screen.");
        return false;
    }
    VkInstanceCreateInfo info = { .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = app ? app : &fallback,
                                  .enabledExtensionCount = enabled_count, .ppEnabledExtensionNames = enabled };
    if (vkCreateInstance(&info, NULL, &s_vk.instance) != VK_SUCCESS) {
        lr_vk_set_error(error, capacity, "The 3D renderer could not start Vulkan on this device.");
        return false;
    }
    uint32_t gpus = 1;
    VkResult listed = vkEnumeratePhysicalDevices(s_vk.instance, &gpus, &s_vk.gpu);
    if ((listed != VK_SUCCESS && listed != VK_INCOMPLETE) || gpus == 0) {
        lr_vk_set_error(error, capacity, "The 3D renderer found no GPU.");
        return false;
    }
    return true;
}

// Swapchain, plus portability_subset where the driver lists it: Vulkan requires enabling it then.
static uint32_t lr_vk_device_extensions(const char** names) {
    VkExtensionProperties available[256];
    uint32_t count = 256;
    vkEnumerateDeviceExtensionProperties(s_vk.gpu, NULL, &count, available);
    uint32_t used = 0;
    names[used++] = VK_KHR_SWAPCHAIN_EXTENSION_NAME;
    if (lr_vk_has(available, count, "VK_KHR_portability_subset")) names[used++] = "VK_KHR_portability_subset";
    return used;
}

static bool lr_vk_create_device(char* error, size_t capacity) {
    const char* extensions[2];
    uint32_t extension_count = lr_vk_device_extensions(extensions);
    const struct retro_hw_render_context_negotiation_interface_vulkan* negotiation = s_vk.negotiation;
    if (negotiation && negotiation->create_device) {
        // No surface yet: the layer may attach later, and every MoltenVK queue can present.
        struct retro_vulkan_context context = { 0 };
        VkPhysicalDeviceFeatures features = { 0 };
        if (negotiation->create_device(&context, s_vk.instance, s_vk.gpu, VK_NULL_HANDLE, vkGetInstanceProcAddr,
                                       extensions, extension_count, NULL, 0, &features)) {
            s_vk.gpu = context.gpu;
            s_vk.device = context.device;
            s_vk.queue = context.queue;
            s_vk.queue_family = context.queue_family_index;
            s_vk.core_made_device = true;
            return true;
        }
    }

    // libretro's default: one queue that does graphics and compute, no optional features.
    VkQueueFamilyProperties families[16];
    uint32_t family_count = 16;
    vkGetPhysicalDeviceQueueFamilyProperties(s_vk.gpu, &family_count, families);
    uint32_t family = UINT32_MAX;
    for (uint32_t i = 0; i < family_count && family == UINT32_MAX; ++i) {
        VkQueueFlags need = VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT;
        if ((families[i].queueFlags & need) == need) family = i;
    }
    float priority = 1.0f;
    VkDeviceQueueCreateInfo queue = { .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO, .queueFamilyIndex = family,
                                      .queueCount = 1, .pQueuePriorities = &priority };
    VkDeviceCreateInfo info = { .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, .queueCreateInfoCount = 1, .pQueueCreateInfos = &queue,
                                .enabledExtensionCount = extension_count, .ppEnabledExtensionNames = extensions };
    if (family == UINT32_MAX || vkCreateDevice(s_vk.gpu, &info, NULL, &s_vk.device) != VK_SUCCESS) {
        s_vk.device = VK_NULL_HANDLE;
        lr_vk_set_error(error, capacity, "The 3D renderer could not open the GPU.");
        return false;
    }
    vkGetDeviceQueue(s_vk.device, family, 0, &s_vk.queue);
    s_vk.queue_family = family;
    return true;
}

static bool lr_vk_create_sync(void) {
    VkCommandPoolCreateInfo pool = { .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                                     .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, .queueFamilyIndex = s_vk.queue_family };
    if (vkCreateCommandPool(s_vk.device, &pool, NULL, &s_vk.pool) != VK_SUCCESS) return false;
    VkCommandBufferAllocateInfo alloc = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = s_vk.pool,
                                          .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = LR_VK_FRAMES };
    if (vkAllocateCommandBuffers(s_vk.device, &alloc, s_vk.cmd) != VK_SUCCESS) return false;
    VkFenceCreateInfo fence = { .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, .flags = VK_FENCE_CREATE_SIGNALED_BIT };
    VkSemaphoreCreateInfo semaphore = { .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
    for (int i = 0; i < LR_VK_FRAMES; ++i) {
        if (vkCreateFence(s_vk.device, &fence, NULL, &s_vk.fence[i]) != VK_SUCCESS ||
            vkCreateSemaphore(s_vk.device, &semaphore, NULL, &s_vk.acquired[i]) != VK_SUCCESS) return false;
    }
    return true;
}

static bool lr_vk_build_swapchain(void);

bool lr_vk_create_context(char* error, size_t capacity) {
    if (!lr_vk_create_instance(error, capacity) || !lr_vk_create_device(error, capacity)) return false;
    if (!lr_vk_create_sync()) {
        lr_vk_set_error(error, capacity, "The 3D renderer ran out of GPU memory.");
        return false;
    }
    s_vk.iface = (struct retro_hw_render_interface_vulkan){
        .interface_type = RETRO_HW_RENDER_INTERFACE_VULKAN,
        .interface_version = RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION,
        .handle = &s_vk,
        .instance = s_vk.instance,
        .gpu = s_vk.gpu,
        .device = s_vk.device,
        .get_device_proc_addr = vkGetDeviceProcAddr,
        .get_instance_proc_addr = vkGetInstanceProcAddr,
        .queue = s_vk.queue,
        .queue_index = s_vk.queue_family,
        .set_image = lr_vk_set_image,
        .get_sync_index = lr_vk_get_sync_index,
        .get_sync_index_mask = lr_vk_get_sync_index_mask,
        .set_command_buffers = lr_vk_set_command_buffers,
        .wait_sync_index = lr_vk_wait_sync_index,
        .lock_queue = lr_vk_lock_queue,
        .unlock_queue = lr_vk_unlock_queue,
        .set_signal_semaphore = lr_vk_set_signal_semaphore,
    };
    if (s_vk.hw.context_reset) s_vk.hw.context_reset();
    s_vk.context_live = true;
    if (s_vk.layer) lr_vk_build_swapchain(); // A layer attached while the game was loading.
    return true;
}

void lr_vk_wait_idle(void) {
    if (!s_vk.device) return;
    lr_vk_lock();
    vkQueueWaitIdle(s_vk.queue);
    lr_vk_unlock();
}

void lr_vk_destroy_context(void) {
    if (!s_vk.context_live) return;
    lr_vk_wait_idle();
    s_vk.context_live = false;
    s_vk.presented = false; // The core frees its images now.
    s_vk.has_image = false;
    if (s_vk.hw.context_destroy) s_vk.hw.context_destroy();
}

static void lr_vk_destroy_swapchain(void) {
    for (uint32_t i = 0; i < s_vk.image_count; ++i) vkDestroySemaphore(s_vk.device, s_vk.rendered[i], NULL);
    s_vk.image_count = 0;
    if (s_vk.swapchain) vkDestroySwapchainKHR(s_vk.device, s_vk.swapchain, NULL);
    s_vk.swapchain = VK_NULL_HANDLE;
}

static void lr_vk_destroy_surface(void) {
    if (s_vk.device) {
        lr_vk_wait_idle();
        lr_vk_destroy_swapchain();
    }
    if (s_vk.surface) vkDestroySurfaceKHR(s_vk.instance, s_vk.surface, NULL);
    s_vk.surface = VK_NULL_HANDLE;
}

void lr_vk_release(void) {
    if (s_vk.device) {
        lr_vk_wait_idle();
        if (s_vk.core_made_device && s_vk.negotiation && s_vk.negotiation->destroy_device) s_vk.negotiation->destroy_device();
        lr_vk_destroy_surface();
        for (int i = 0; i < LR_VK_FRAMES; ++i) {
            vkDestroyFence(s_vk.device, s_vk.fence[i], NULL);
            vkDestroySemaphore(s_vk.device, s_vk.acquired[i], NULL);
        }
        vkDestroyCommandPool(s_vk.device, s_vk.pool, NULL);
        vkDestroyDevice(s_vk.device, NULL); // The frontend owns the device, even one the core created.
    }
    if (s_vk.instance) vkDestroyInstance(s_vk.instance, NULL);
    memset(&s_vk, 0, sizeof(s_vk));
}

// MARK: - Layer

// Waits for the GPU first: the old swapchain's semaphores go with it.
static bool lr_vk_build_swapchain(void) {
    lr_vk_wait_idle();
    if (!s_vk.surface) {
        VkMetalSurfaceCreateInfoEXT info = { .sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT, .pLayer = s_vk.layer };
        if (vkCreateMetalSurfaceEXT(s_vk.instance, &info, NULL, &s_vk.surface) != VK_SUCCESS) return false;
    }
    VkBool32 presentable = VK_FALSE;
    vkGetPhysicalDeviceSurfaceSupportKHR(s_vk.gpu, s_vk.queue_family, s_vk.surface, &presentable);
    VkSurfaceCapabilitiesKHR caps;
    if (!presentable || vkGetPhysicalDeviceSurfaceCapabilitiesKHR(s_vk.gpu, s_vk.surface, &caps) != VK_SUCCESS) return false;

    uint32_t count = caps.minImageCount + 1;
    if (caps.maxImageCount > 0 && count > caps.maxImageCount) count = caps.maxImageCount;
    if (count > LR_VK_MAX_IMAGES) count = LR_VK_MAX_IMAGES;
    VkExtent2D extent = { s_vk.layer_width, s_vk.layer_height };
    if (extent.width < caps.minImageExtent.width) extent.width = caps.minImageExtent.width;
    if (extent.height < caps.minImageExtent.height) extent.height = caps.minImageExtent.height;
    if (extent.width > caps.maxImageExtent.width) extent.width = caps.maxImageExtent.width;
    if (extent.height > caps.maxImageExtent.height) extent.height = caps.maxImageExtent.height;

    VkSwapchainKHR old = s_vk.swapchain;
    // shortcut: FIFO presents every frame, so fast-forward runs no faster than the display refreshes. Skip
    // presenting frames the host drops (GagaCoreWrapper.presentVideo) if a layer-path core needs more.
    VkSwapchainCreateInfoKHR info = {
        .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, .surface = s_vk.surface, .minImageCount = count,
        .imageFormat = VK_FORMAT_B8G8R8A8_UNORM, .imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR, .imageExtent = extent,
        .imageArrayLayers = 1, .imageUsage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = VK_SHARING_MODE_EXCLUSIVE, .preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, .presentMode = VK_PRESENT_MODE_FIFO_KHR, .clipped = VK_TRUE,
        .oldSwapchain = old,
    };
    VkSwapchainKHR made = VK_NULL_HANDLE;
    VkResult result = vkCreateSwapchainKHR(s_vk.device, &info, NULL, &made);
    lr_vk_destroy_swapchain();
    if (result != VK_SUCCESS) return false;
    s_vk.swapchain = made;
    s_vk.extent = extent;
    uint32_t images = LR_VK_MAX_IMAGES;
    vkGetSwapchainImagesKHR(s_vk.device, made, &images, s_vk.images);
    VkSemaphoreCreateInfo semaphore = { .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
    for (uint32_t i = 0; i < images; ++i) {
        if (vkCreateSemaphore(s_vk.device, &semaphore, NULL, &s_vk.rendered[i]) != VK_SUCCESS) break;
        s_vk.image_count = i + 1;
    }
    return s_vk.image_count == images;
}

bool gaga_lr_attach_metal_layer(GagaInstance* inst, void* layer, uint32_t width_px, uint32_t height_px, float content_scale) {
    (void)content_scale; // The host sets the layer's contentsScale. MoltenVK sizes drawables from the extent.
    if (!inst || !layer || width_px == 0 || height_px == 0) return false;
    if (layer != s_vk.layer) {
        lr_vk_destroy_surface();
        s_vk.layer = layer;
    } else if (s_vk.swapchain && s_vk.layer_width == width_px && s_vk.layer_height == height_px) {
        return true;
    }
    s_vk.layer_width = width_px;
    s_vk.layer_height = height_px;
    if (!s_vk.device) return true; // lr_vk_create_context builds the swapchain.
    return lr_vk_build_swapchain();
}

void gaga_lr_detach_metal_layer(GagaInstance* inst) {
    if (!inst) return;
    lr_vk_destroy_surface();
    s_vk.layer = NULL;
}

// MARK: - Frames

// Scales the core's image into dst, aspect fit on ink, and leaves dst in dst_final. The core's image
// goes back to its own layout, and its queue family gets ownership back if it lent it.
static void lr_vk_record_copy(VkCommandBuffer cmd, const LrVkImage* src, VkImage dst, VkExtent2D dst_extent, VkImageLayout dst_final) {
    bool general = src->layout == VK_IMAGE_LAYOUT_GENERAL; // libretro: no transitions on a GENERAL image.
    VkImageLayout src_layout = general ? VK_IMAGE_LAYOUT_GENERAL : VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    bool lent = src->queue_family != VK_QUEUE_FAMILY_IGNORED && src->queue_family != s_vk.queue_family;
    VkImageSubresourceRange whole = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
    VkImageMemoryBarrier in[2] = {
        { .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, .srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT,
          .dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT, .oldLayout = src->layout, .newLayout = src_layout,
          .srcQueueFamilyIndex = lent ? src->queue_family : VK_QUEUE_FAMILY_IGNORED,
          .dstQueueFamilyIndex = lent ? s_vk.queue_family : VK_QUEUE_FAMILY_IGNORED, .image = src->image, .subresourceRange = src->range },
        { .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
          .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED, .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
          .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, .image = dst, .subresourceRange = whole },
    };
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, NULL, 0, NULL, 2, in);
    vkCmdClearColorImage(cmd, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &s_letterbox, 1, &whole);
    VkMemoryBarrier cleared = { .sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER, .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                                .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT };
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &cleared, 0, NULL, 0, NULL);

    // shortcut: square pixels, as the copy path's renderer assumes. Use the core's aspect_ratio when a core needs it.
    float scale = fminf((float)dst_extent.width / (float)src->width, (float)dst_extent.height / (float)src->height);
    int32_t fit_w = (int32_t)lroundf(src->width * scale), fit_h = (int32_t)lroundf(src->height * scale);
    int32_t x = ((int32_t)dst_extent.width - fit_w) / 2, y = ((int32_t)dst_extent.height - fit_h) / 2;
    VkImageBlit blit = {
        .srcSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, src->range.baseMipLevel, src->range.baseArrayLayer, 1 },
        .srcOffsets = { { 0, 0, 0 }, { (int32_t)src->width, (int32_t)src->height, 1 } },
        .dstSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 },
        .dstOffsets = { { x, y, 0 }, { x + fit_w, y + fit_h, 1 } },
    };
    vkCmdBlitImage(cmd, src->image, src_layout, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &blit, VK_FILTER_LINEAR);

    bool to_present = dst_final == VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    VkImageMemoryBarrier out[2] = {
        { .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, .srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT,
          .oldLayout = src_layout, .newLayout = src->layout,
          .srcQueueFamilyIndex = lent ? s_vk.queue_family : VK_QUEUE_FAMILY_IGNORED,
          .dstQueueFamilyIndex = lent ? src->queue_family : VK_QUEUE_FAMILY_IGNORED, .image = src->image, .subresourceRange = src->range },
        { .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
          .dstAccessMask = to_present ? 0 : VK_ACCESS_TRANSFER_READ_BIT,
          .oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .newLayout = dst_final,
          .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, .image = dst, .subresourceRange = whole },
    };
    // The core's next use of its image waits for the sync index's fence, so ALL_COMMANDS covers it.
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, NULL, 0, NULL, 2, out);
}

// One frame: the core's command buffers if it passed any, then the copy into the next swapchain image,
// signalling what the core asked, then present. A frame with no layer still runs, so the core's
// semaphores and sync index keep moving while the view is away.
bool lr_vk_present(unsigned width, unsigned height, bool dupe) {
    if (!s_vk.device) return false;
    bool show = !dupe && s_vk.has_image && width > 0 && height > 0;
    // A dupe waits on no semaphore (libretro), and one with nothing to run or signal is a no-op.
    if (!show && s_vk.core_cmd_count == 0 && !s_vk.signal) return false;
    uint32_t slot = s_vk.index;
    vkWaitForFences(s_vk.device, 1, &s_vk.fence[slot], VK_TRUE, UINT64_MAX);

    uint32_t target = UINT32_MAX;
    if (show && s_vk.swapchain) {
        VkResult acquired = vkAcquireNextImageKHR(s_vk.device, s_vk.swapchain, UINT64_MAX, s_vk.acquired[slot], VK_NULL_HANDLE, &target);
        if (acquired == VK_ERROR_OUT_OF_DATE_KHR && lr_vk_build_swapchain()) {
            acquired = vkAcquireNextImageKHR(s_vk.device, s_vk.swapchain, UINT64_MAX, s_vk.acquired[slot], VK_NULL_HANDLE, &target);
        }
        if (acquired != VK_SUCCESS && acquired != VK_SUBOPTIMAL_KHR) target = UINT32_MAX; // Skipped, not fatal.
    }

    VkCommandBuffer cmd = s_vk.cmd[slot];
    vkResetCommandBuffer(cmd, 0);
    VkCommandBufferBeginInfo begin = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
    vkBeginCommandBuffer(cmd, &begin);
    if (show) {
        s_vk.image.width = width;
        s_vk.image.height = height;
        if (target != UINT32_MAX) lr_vk_record_copy(cmd, &s_vk.image, s_vk.images[target], s_vk.extent, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);
    }
    vkEndCommandBuffer(cmd);

    VkSemaphore waits[LR_VK_MAX_WAITS + 1];
    VkPipelineStageFlags stages[LR_VK_MAX_WAITS + 1];
    uint32_t wait_count = 0;
    if (show && s_vk.core_cmd_count == 0) { // With set_command_buffers, libretro skips the semaphores.
        for (uint32_t i = 0; i < s_vk.wait_count; ++i) waits[wait_count++] = s_vk.waits[i];
    }
    if (target != UINT32_MAX) waits[wait_count++] = s_vk.acquired[slot];
    for (uint32_t i = 0; i < wait_count; ++i) stages[i] = VK_PIPELINE_STAGE_TRANSFER_BIT;
    VkCommandBuffer cmds[LR_VK_MAX_CMDS + 1];
    uint32_t cmd_count = 0;
    for (uint32_t i = 0; i < s_vk.core_cmd_count; ++i) cmds[cmd_count++] = s_vk.core_cmds[i];
    cmds[cmd_count++] = cmd;
    VkSemaphore signals[2];
    uint32_t signal_count = 0;
    if (target != UINT32_MAX) signals[signal_count++] = s_vk.rendered[target];
    if (s_vk.signal) signals[signal_count++] = s_vk.signal;
    VkSubmitInfo submit = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, .waitSemaphoreCount = wait_count, .pWaitSemaphores = waits,
                            .pWaitDstStageMask = stages, .commandBufferCount = cmd_count, .pCommandBuffers = cmds,
                            .signalSemaphoreCount = signal_count, .pSignalSemaphores = signals };

    vkResetFences(s_vk.device, 1, &s_vk.fence[slot]);
    lr_vk_lock();
    VkResult submitted = vkQueueSubmit(s_vk.queue, 1, &submit, s_vk.fence[slot]);
    if (submitted == VK_SUCCESS && target != UINT32_MAX) {
        VkPresentInfoKHR present = { .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR, .waitSemaphoreCount = 1,
                                     .pWaitSemaphores = &s_vk.rendered[target], .swapchainCount = 1,
                                     .pSwapchains = &s_vk.swapchain, .pImageIndices = &target };
        vkQueuePresentKHR(s_vk.queue, &present); // Out of date only means the next frame rebuilds.
    }
    lr_vk_unlock();

    s_vk.wait_count = 0;
    s_vk.core_cmd_count = 0;
    s_vk.signal = VK_NULL_HANDLE;
    s_vk.index = (slot + 1) % LR_VK_FRAMES;
    if (submitted != VK_SUCCESS) {
        // An unsignalled fence would hang the next wait, so leave it signalled for teardown.
        VkSubmitInfo empty = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO };
        lr_vk_lock();
        vkQueueSubmit(s_vk.queue, 1, &empty, s_vk.fence[slot]);
        lr_vk_unlock();
        gaga_lr_report_fatal("The 3D renderer stopped working.");
        return false;
    }
    if (show) {
        s_vk.last = s_vk.image;
        s_vk.presented = true;
    }
    return show;
}

// MARK: - Read back

static uint32_t lr_vk_memory_type(uint32_t bits, VkMemoryPropertyFlags flags) {
    VkPhysicalDeviceMemoryProperties memory;
    vkGetPhysicalDeviceMemoryProperties(s_vk.gpu, &memory);
    for (uint32_t i = 0; i < memory.memoryTypeCount; ++i) {
        if ((bits & (1u << i)) && (memory.memoryTypes[i].propertyFlags & flags) == flags) return i;
    }
    return UINT32_MAX;
}

static bool lr_vk_bind(VkMemoryRequirements needs, VkMemoryPropertyFlags flags, VkDeviceMemory* memory) {
    uint32_t type = lr_vk_memory_type(needs.memoryTypeBits, flags);
    VkMemoryAllocateInfo info = { .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, .allocationSize = needs.size, .memoryTypeIndex = type };
    return type != UINT32_MAX && vkAllocateMemory(s_vk.device, &info, NULL, memory) == VK_SUCCESS;
}

// Rare, so it builds and frees what it needs each time and waits for the GPU.
bool gaga_lr_read_layer_pixels(GagaInstance* inst, void* pixels, size_t capacity, uint32_t* width, uint32_t* height) {
    if (!inst || !width || !height || !s_vk.device) return false;
    if (!s_vk.presented) {
        fprintf(stderr, "[gaga-vk] read back: nothing presented (has_image %d)\n", s_vk.has_image);
        return false;
    }
    LrVkImage src = s_vk.last;
    src.queue_family = VK_QUEUE_FAMILY_IGNORED; // The present gave it back already.
    *width = src.width;
    *height = src.height;
    size_t bytes = (size_t)src.width * src.height * 4;
    if (!pixels || capacity < bytes) return false;

    VkDevice device = s_vk.device;
    VkImage image = VK_NULL_HANDLE;
    VkBuffer buffer = VK_NULL_HANDLE;
    VkDeviceMemory image_memory = VK_NULL_HANDLE, buffer_memory = VK_NULL_HANDLE;
    VkCommandBuffer cmd = VK_NULL_HANDLE;
    VkFence fence = VK_NULL_HANDLE;
    bool ok = false;
    // Device run 5: PPSSPP's 3rd and later games in one process read back nothing although they present.
    // Logs the step that failed, so the next run names the cause.
    const char* step = "image";

    VkImageCreateInfo image_info = { .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO, .imageType = VK_IMAGE_TYPE_2D,
                                     .format = VK_FORMAT_B8G8R8A8_UNORM, .extent = { src.width, src.height, 1 }, .mipLevels = 1,
                                     .arrayLayers = 1, .samples = VK_SAMPLE_COUNT_1_BIT, .tiling = VK_IMAGE_TILING_OPTIMAL,
                                     .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT };
    VkBufferCreateInfo buffer_info = { .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO, .size = bytes, .usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT };
    VkMemoryRequirements needs;
    if (vkCreateImage(device, &image_info, NULL, &image) != VK_SUCCESS) goto done;
    vkGetImageMemoryRequirements(device, image, &needs);
    step = "image memory";
    if (!lr_vk_bind(needs, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &image_memory) || vkBindImageMemory(device, image, image_memory, 0) != VK_SUCCESS) goto done;
    step = "buffer";
    if (vkCreateBuffer(device, &buffer_info, NULL, &buffer) != VK_SUCCESS) goto done;
    vkGetBufferMemoryRequirements(device, buffer, &needs);
    step = "buffer memory";
    if (!lr_vk_bind(needs, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &buffer_memory) ||
        vkBindBufferMemory(device, buffer, buffer_memory, 0) != VK_SUCCESS) goto done;
    step = "command buffer";

    VkCommandBufferAllocateInfo alloc = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = s_vk.pool,
                                          .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = 1 };
    VkFenceCreateInfo fence_info = { .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO };
    if (vkAllocateCommandBuffers(device, &alloc, &cmd) != VK_SUCCESS || vkCreateFence(device, &fence_info, NULL, &fence) != VK_SUCCESS) goto done;
    VkCommandBufferBeginInfo begin = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
    vkBeginCommandBuffer(cmd, &begin);
    lr_vk_record_copy(cmd, &src, image, (VkExtent2D){ src.width, src.height }, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL);
    VkBufferImageCopy region = { .imageSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 }, .imageExtent = { src.width, src.height, 1 } };
    vkCmdCopyImageToBuffer(cmd, image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, buffer, 1, &region);
    VkBufferMemoryBarrier host = { .sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                                   .dstAccessMask = VK_ACCESS_HOST_READ_BIT, .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                                   .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED, .buffer = buffer, .size = VK_WHOLE_SIZE };
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_HOST_BIT, 0, 0, NULL, 1, &host, 0, NULL);
    vkEndCommandBuffer(cmd);
    VkSubmitInfo submit = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, .commandBufferCount = 1, .pCommandBuffers = &cmd };
    lr_vk_lock();
    VkResult submitted = vkQueueSubmit(s_vk.queue, 1, &submit, fence);
    lr_vk_unlock();
    void* mapped = NULL;
    step = "submit";
    if (submitted != VK_SUCCESS) goto done;
    step = "wait";
    if ((submitted = vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_MAX)) != VK_SUCCESS) goto done;
    step = "map";
    if (vkMapMemory(device, buffer_memory, 0, bytes, 0, &mapped) != VK_SUCCESS) goto done;
    memcpy(pixels, mapped, bytes);
    vkUnmapMemory(device, buffer_memory);
    ok = true;

done:
    if (!ok) fprintf(stderr, "[gaga-vk] read back %ux%u failed at %s\n", src.width, src.height, step);
    if (fence) vkDestroyFence(device, fence, NULL);
    if (cmd) vkFreeCommandBuffers(device, s_vk.pool, 1, &cmd);
    if (buffer) vkDestroyBuffer(device, buffer, NULL);
    if (buffer_memory) vkFreeMemory(device, buffer_memory, NULL);
    if (image) vkDestroyImage(device, image, NULL);
    if (image_memory) vkFreeMemory(device, image_memory, NULL);
    return ok;
}
