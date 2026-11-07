// Upstream's libretro/LibretroVulkanContext.cpp, with one change at its seam to libretro_vulkan.cpp.
//
// Upstream needs a VkSurfaceKHR from the frontend's create_device: it asserts one, and asks the real driver
// for that surface's formats and capabilities. Our frontend has none yet when the device is made (the layer
// attaches later, Cores/shared/LibretroVulkan.c), so the device is made with a surface of a CAMetalLayer of
// its own that is never shown. PPSSPP renders into the frontend's images (set_image), never to that layer.
#include <objc/message.h>
#include <objc/runtime.h>

#define vk_libretro_init gaga_ppsspp_vk_init
#define vk_libretro_shutdown gaga_ppsspp_vk_shutdown
#include "upstream/libretro/LibretroVulkanContext.cpp"
#undef vk_libretro_init
#undef vk_libretro_shutdown

void vk_libretro_init(VkInstance instance, VkPhysicalDevice gpu, VkSurfaceKHR surface, PFN_vkGetInstanceProcAddr get_instance_proc_addr, const char **required_device_extensions, unsigned num_required_device_extensions, const char **required_device_layers, unsigned num_required_device_layers, const VkPhysicalDeviceFeatures *required_features);
void vk_libretro_shutdown();

static VkInstance s_surface_instance;
static VkSurfaceKHR s_surface;
static id s_layer;
static PFN_vkDestroySurfaceKHR s_destroy_surface;

void gaga_ppsspp_vk_init(VkInstance instance, VkPhysicalDevice gpu, VkSurfaceKHR surface, PFN_vkGetInstanceProcAddr get_instance_proc_addr, const char **required_device_extensions, unsigned num_required_device_extensions, const char **required_device_layers, unsigned num_required_device_layers, const VkPhysicalDeviceFeatures *required_features) {
	if (!surface && !s_surface) {
		auto create = (PFN_vkCreateMetalSurfaceEXT)get_instance_proc_addr(instance, "vkCreateMetalSurfaceEXT");
		s_destroy_surface = (PFN_vkDestroySurfaceKHR)get_instance_proc_addr(instance, "vkDestroySurfaceKHR");
		s_layer = ((id (*)(id, SEL))objc_msgSend)((id)objc_getClass("CAMetalLayer"), sel_registerName("new"));
		VkMetalSurfaceCreateInfoEXT info{ VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT };
		info.pLayer = (const CAMetalLayer *)s_layer;
		if (create && s_layer && create(instance, &info, nullptr, &s_surface) == VK_SUCCESS)
			s_surface_instance = instance;
		else
			s_surface = VK_NULL_HANDLE;
	}
	vk_libretro_init(instance, gpu, surface ? surface : s_surface, get_instance_proc_addr, required_device_extensions, num_required_device_extensions, required_device_layers, num_required_device_layers, required_features);
}

void gaga_ppsspp_vk_shutdown() {
	vk_libretro_shutdown();
	if (s_surface && s_destroy_surface) s_destroy_surface(s_surface_instance, s_surface, nullptr);
	s_surface = VK_NULL_HANDLE;
	if (s_layer) ((void (*)(id, SEL))objc_msgSend)(s_layer, sel_registerName("release"));
	s_layer = nullptr;
}
