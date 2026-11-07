// A libretro core written for GagaEmu, for debug and test builds only. It renders with Vulkan through
// the adapter's layer path (Cores/shared/LibretroVulkan.c), so the path can be proved without a 3D
// emulator (docs/07 milestone 5.1): a clear and one flat triangle that the D-pad moves, a tone, a boot
// counter in battery RAM, a save state and rumble.
//
// File (.gagavk): "GAGAVK1" and one flags byte (Sources/Debug/VkTestROM.swift writes it).
#include "LibretroVulkan.h"

#include <libretro.h>
#include <libretro_vulkan.h>

#include <string.h>

#include "VkTestShaders.h"

#define VT_WIDTH 320
#define VT_HEIGHT 240
#define VT_RATE 48000
#define VT_FPS 60
#define VT_STEP 2                  // Pixels per frame the D-pad moves the triangle.
#define VT_FLAG_NO_NEGOTIATION 1u  // Offer no negotiation interface, so the adapter makes the device.
#define VT_FLAG_FRONTEND_SUBMIT 2u // Hand command buffers to set_command_buffers instead of submitting them.

static const char s_magic[7] = { 'G', 'A', 'G', 'A', 'V', 'K', '1' };

static retro_environment_t s_env;
static retro_video_refresh_t s_video;
static retro_audio_sample_batch_t s_audio;
static retro_input_poll_t s_poll;
static retro_input_state_t s_input;

static uint8_t s_flags;
static struct { uint32_t magic, boots, reserved[2]; } s_sram; // Battery RAM: counts boots.
static struct { int32_t x, y; uint32_t frame, tone_phase; } s_state;
static bool s_booted;
static int16_t s_samples[VT_RATE / VT_FPS * 2];

static const struct retro_hw_render_interface_vulkan* s_vk;
static VkDevice s_device;
static VkImage s_image;
static VkDeviceMemory s_memory;
static VkImageView s_view;
static VkRenderPass s_pass;
static VkFramebuffer s_framebuffer;
static VkPipelineLayout s_layout;
static VkPipeline s_pipeline;
static VkCommandPool s_pool;
static VkCommandBuffer s_cmd[2];
static VkSemaphore s_done[2];
static struct retro_vulkan_image s_frame;
static bool s_made_device;

// MARK: - Vulkan

static VkShaderModule vt_shader(const uint32_t* code, size_t size) {
    VkShaderModuleCreateInfo info = { .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, .codeSize = size, .pCode = code };
    VkShaderModule module = VK_NULL_HANDLE;
    vkCreateShaderModule(s_device, &info, NULL, &module);
    return module;
}

static bool vt_create_pipeline(void) {
    VkAttachmentDescription color = {
        .format = VK_FORMAT_R8G8B8A8_UNORM, .samples = VK_SAMPLE_COUNT_1_BIT, .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = VK_ATTACHMENT_STORE_OP_STORE, .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE, .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, // What set_image reports.
    };
    VkAttachmentReference reference = { 0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL };
    VkSubpassDescription subpass = { .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS, .colorAttachmentCount = 1, .pColorAttachments = &reference };
    VkSubpassDependency after = {
        .srcSubpass = 0, .dstSubpass = VK_SUBPASS_EXTERNAL, .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, .srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        .dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT,
    };
    VkRenderPassCreateInfo pass = { .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, .attachmentCount = 1, .pAttachments = &color,
                                    .subpassCount = 1, .pSubpasses = &subpass, .dependencyCount = 1, .pDependencies = &after };
    if (vkCreateRenderPass(s_device, &pass, NULL, &s_pass) != VK_SUCCESS) return false;
    VkFramebufferCreateInfo framebuffer = { .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, .renderPass = s_pass, .attachmentCount = 1,
                                            .pAttachments = &s_view, .width = VT_WIDTH, .height = VT_HEIGHT, .layers = 1 };
    if (vkCreateFramebuffer(s_device, &framebuffer, NULL, &s_framebuffer) != VK_SUCCESS) return false;

    VkPushConstantRange push = { VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(float) * 2 };
    VkPipelineLayoutCreateInfo layout = { .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, .pushConstantRangeCount = 1, .pPushConstantRanges = &push };
    if (vkCreatePipelineLayout(s_device, &layout, NULL, &s_layout) != VK_SUCCESS) return false;

    VkShaderModule vert = vt_shader(vt_vert_spirv, sizeof(vt_vert_spirv));
    VkShaderModule frag = vt_shader(vt_frag_spirv, sizeof(vt_frag_spirv));
    VkPipelineShaderStageCreateInfo stages[2] = {
        { .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_VERTEX_BIT, .module = vert, .pName = "main" },
        { .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_FRAGMENT_BIT, .module = frag, .pName = "main" },
    };
    VkPipelineVertexInputStateCreateInfo input = { .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO };
    VkPipelineInputAssemblyStateCreateInfo assembly = { .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                                                        .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST };
    VkViewport viewport = { 0, 0, VT_WIDTH, VT_HEIGHT, 0, 1 };
    VkRect2D scissor = { { 0, 0 }, { VT_WIDTH, VT_HEIGHT } };
    VkPipelineViewportStateCreateInfo viewports = { .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO, .viewportCount = 1,
                                                    .pViewports = &viewport, .scissorCount = 1, .pScissors = &scissor };
    VkPipelineRasterizationStateCreateInfo raster = { .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                                                      .polygonMode = VK_POLYGON_MODE_FILL, .cullMode = VK_CULL_MODE_NONE, .lineWidth = 1 };
    VkPipelineMultisampleStateCreateInfo multisample = { .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                                                         .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT };
    VkPipelineColorBlendAttachmentState blend = { .colorWriteMask = 0xF };
    VkPipelineColorBlendStateCreateInfo blending = { .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                                                     .attachmentCount = 1, .pAttachments = &blend };
    VkGraphicsPipelineCreateInfo pipeline = {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO, .stageCount = 2, .pStages = stages, .pVertexInputState = &input,
        .pInputAssemblyState = &assembly, .pViewportState = &viewports, .pRasterizationState = &raster,
        .pMultisampleState = &multisample, .pColorBlendState = &blending, .layout = s_layout, .renderPass = s_pass,
    };
    // MoltenVK translates the SPIR-V to MSL with SPIRV-Cross and compiles an MTLLibrary here: GPU code, not CPU code.
    VkResult made = vert && frag ? vkCreateGraphicsPipelines(s_device, VK_NULL_HANDLE, 1, &pipeline, NULL, &s_pipeline) : VK_ERROR_INITIALIZATION_FAILED;
    vkDestroyShaderModule(s_device, vert, NULL);
    vkDestroyShaderModule(s_device, frag, NULL);
    return made == VK_SUCCESS;
}

static bool vt_create_image(void) {
    VkImageCreateInfo image = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO, .flags = VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT, // libretro asks this of 8-bit formats.
        .imageType = VK_IMAGE_TYPE_2D, .format = VK_FORMAT_R8G8B8A8_UNORM, .extent = { VT_WIDTH, VT_HEIGHT, 1 }, .mipLevels = 1,
        .arrayLayers = 1, .samples = VK_SAMPLE_COUNT_1_BIT, .tiling = VK_IMAGE_TILING_OPTIMAL,
        .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
    };
    if (vkCreateImage(s_device, &image, NULL, &s_image) != VK_SUCCESS) return false;
    VkMemoryRequirements needs;
    vkGetImageMemoryRequirements(s_device, s_image, &needs);
    VkPhysicalDeviceMemoryProperties memory;
    vkGetPhysicalDeviceMemoryProperties(s_vk->gpu, &memory);
    uint32_t type = UINT32_MAX;
    for (uint32_t i = 0; i < memory.memoryTypeCount && type == UINT32_MAX; ++i) {
        if ((needs.memoryTypeBits & (1u << i)) && (memory.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) type = i;
    }
    VkMemoryAllocateInfo alloc = { .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, .allocationSize = needs.size, .memoryTypeIndex = type };
    if (type == UINT32_MAX || vkAllocateMemory(s_device, &alloc, NULL, &s_memory) != VK_SUCCESS ||
        vkBindImageMemory(s_device, s_image, s_memory, 0) != VK_SUCCESS) return false;
    s_frame.create_info = (VkImageViewCreateInfo){
        .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, .image = s_image, .viewType = VK_IMAGE_VIEW_TYPE_2D,
        .format = VK_FORMAT_R8G8B8A8_UNORM, .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
    };
    if (vkCreateImageView(s_device, &s_frame.create_info, NULL, &s_view) != VK_SUCCESS) return false;
    s_frame.image_view = s_view;
    s_frame.image_layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    return true;
}

static void vt_context_destroy(void) {
    if (!s_device) return;
    vkDeviceWaitIdle(s_device);
    for (int i = 0; i < 2; ++i) vkDestroySemaphore(s_device, s_done[i], NULL);
    vkDestroyCommandPool(s_device, s_pool, NULL);
    vkDestroyPipeline(s_device, s_pipeline, NULL);
    vkDestroyPipelineLayout(s_device, s_layout, NULL);
    vkDestroyFramebuffer(s_device, s_framebuffer, NULL);
    vkDestroyRenderPass(s_device, s_pass, NULL);
    vkDestroyImageView(s_device, s_view, NULL);
    vkDestroyImage(s_device, s_image, NULL);
    vkFreeMemory(s_device, s_memory, NULL);
    s_device = VK_NULL_HANDLE;
    s_vk = NULL;
}

static void vt_context_reset(void) {
    const struct retro_hw_render_interface* iface = NULL;
    if (!s_env(RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE, &iface) || !iface ||
        iface->interface_type != RETRO_HW_RENDER_INTERFACE_VULKAN || iface->interface_version != RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION) return;
    s_vk = (const struct retro_hw_render_interface_vulkan*)iface;
    s_device = s_vk->device;
    VkCommandPoolCreateInfo pool = { .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                                     .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, .queueFamilyIndex = s_vk->queue_index };
    VkCommandBufferAllocateInfo alloc = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                                          .commandBufferCount = 2 };
    VkSemaphoreCreateInfo semaphore = { .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
    bool ok = vt_create_image() && vt_create_pipeline() && vkCreateCommandPool(s_device, &pool, NULL, &s_pool) == VK_SUCCESS;
    alloc.commandPool = s_pool;
    ok = ok && vkAllocateCommandBuffers(s_device, &alloc, s_cmd) == VK_SUCCESS &&
         vkCreateSemaphore(s_device, &semaphore, NULL, &s_done[0]) == VK_SUCCESS &&
         vkCreateSemaphore(s_device, &semaphore, NULL, &s_done[1]) == VK_SUCCESS;
    if (!ok) vt_context_destroy(); // retro_run then draws nothing, which the tests see.
}

// What a real core does with the negotiation interface: pick the queue, add its own needs, make the device.
static bool vt_create_device(struct retro_vulkan_context* context, VkInstance instance, VkPhysicalDevice gpu, VkSurfaceKHR surface,
                             PFN_vkGetInstanceProcAddr get_instance_proc_addr, const char** extensions, unsigned extension_count,
                             const char** layers, unsigned layer_count, const VkPhysicalDeviceFeatures* features) {
    (void)surface;
    (void)get_instance_proc_addr; // Linked to MoltenVK directly, as the adapter is.
    if (gpu == VK_NULL_HANDLE) {
        uint32_t count = 1;
        vkEnumeratePhysicalDevices(instance, &count, &gpu);
    }
    VkQueueFamilyProperties families[16];
    uint32_t family_count = 16, family = UINT32_MAX;
    vkGetPhysicalDeviceQueueFamilyProperties(gpu, &family_count, families);
    for (uint32_t i = 0; i < family_count && family == UINT32_MAX; ++i) {
        if ((families[i].queueFlags & (VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT)) == (VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT)) family = i;
    }
    if (family == UINT32_MAX) return false;
    float priority = 1.0f;
    VkDeviceQueueCreateInfo queue = { .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO, .queueFamilyIndex = family, .queueCount = 1,
                                      .pQueuePriorities = &priority };
    VkDeviceCreateInfo info = { .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, .queueCreateInfoCount = 1, .pQueueCreateInfos = &queue,
                                .enabledLayerCount = layer_count, .ppEnabledLayerNames = layers,
                                .enabledExtensionCount = extension_count, .ppEnabledExtensionNames = extensions, .pEnabledFeatures = features };
    VkDevice device = VK_NULL_HANDLE;
    if (vkCreateDevice(gpu, &info, NULL, &device) != VK_SUCCESS) return false;
    *context = (struct retro_vulkan_context){ .gpu = gpu, .device = device, .queue_family_index = family,
                                              .presentation_queue_family_index = family };
    vkGetDeviceQueue(device, family, 0, &context->queue);
    context->presentation_queue = context->queue;
    s_made_device = true;
    return true;
}

static void vt_destroy_device(void) { s_made_device = false; } // Nothing of its own beyond the device.

static const VkApplicationInfo* vt_application_info(void) {
    static const VkApplicationInfo info = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .pApplicationName = "GagaEmu Vulkan Test",
                                            .applicationVersion = 1, .apiVersion = VK_API_VERSION_1_1 };
    return &info;
}

static const struct retro_hw_render_context_negotiation_interface_vulkan s_negotiation = {
    .interface_type = RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN,
    .interface_version = 1,
    .get_application_info = vt_application_info,
    .create_device = vt_create_device,
    .destroy_device = vt_destroy_device,
};

static void vt_render(void) {
    s_vk->wait_sync_index(s_vk->handle);
    uint32_t index = s_vk->get_sync_index(s_vk->handle) & 1;
    VkCommandBuffer cmd = s_cmd[index];
    vkResetCommandBuffer(cmd, 0);
    VkCommandBufferBeginInfo begin = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
    vkBeginCommandBuffer(cmd, &begin);
    VkClearValue clear = { .color = { .float32 = { 0.0f, 0.25f, 0.5f, 1.0f } } };
    VkRenderPassBeginInfo pass = { .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, .renderPass = s_pass, .framebuffer = s_framebuffer,
                                   .renderArea = { { 0, 0 }, { VT_WIDTH, VT_HEIGHT } }, .clearValueCount = 1, .pClearValues = &clear };
    vkCmdBeginRenderPass(cmd, &pass, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, s_pipeline);
    float offset[2] = { s_state.x / (VT_WIDTH / 2.0f), s_state.y / (VT_HEIGHT / 2.0f) }; // Pixels to clip space.
    vkCmdPushConstants(cmd, s_layout, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(offset), offset);
    vkCmdDraw(cmd, 3, 1, 0, 0);
    vkCmdEndRenderPass(cmd);
    vkEndCommandBuffer(cmd);

    if (s_flags & VT_FLAG_FRONTEND_SUBMIT) {
        s_vk->set_command_buffers(s_vk->handle, 1, &cmd);
        s_vk->set_image(s_vk->handle, &s_frame, 0, NULL, VK_QUEUE_FAMILY_IGNORED);
    } else {
        VkSubmitInfo submit = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, .commandBufferCount = 1, .pCommandBuffers = &cmd,
                                .signalSemaphoreCount = 1, .pSignalSemaphores = &s_done[index] };
        s_vk->lock_queue(s_vk->handle);
        vkQueueSubmit(s_vk->queue, 1, &submit, VK_NULL_HANDLE);
        s_vk->unlock_queue(s_vk->handle);
        s_vk->set_image(s_vk->handle, &s_frame, 1, &s_done[index], VK_QUEUE_FAMILY_IGNORED);
    }
    s_video(RETRO_HW_FRAME_BUFFER_VALID, VT_WIDTH, VT_HEIGHT, 0);
}

// MARK: - libretro

void retro_set_environment(retro_environment_t cb) { s_env = cb; }
void retro_set_video_refresh(retro_video_refresh_t cb) { s_video = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) { (void)cb; }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { s_audio = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { s_poll = cb; }
void retro_set_input_state(retro_input_state_t cb) { s_input = cb; }
void retro_set_controller_port_device(unsigned port, unsigned device) { (void)port; (void)device; }

unsigned retro_api_version(void) { return RETRO_API_VERSION; }
void retro_init(void) {}
void retro_deinit(void) {}

void retro_get_system_info(struct retro_system_info* info) {
    *info = (struct retro_system_info){ .library_name = "GagaEmu Vulkan Test", .library_version = "1", .valid_extensions = "gagavk" };
}

void retro_get_system_av_info(struct retro_system_av_info* info) {
    *info = (struct retro_system_av_info){
        .geometry = { VT_WIDTH, VT_HEIGHT, VT_WIDTH, VT_HEIGHT, 4.0f / 3.0f },
        .timing = { VT_FPS, VT_RATE },
    };
}

bool retro_load_game(const struct retro_game_info* game) {
    if (!game || !game->data || game->size < sizeof(s_magic) + 1 || memcmp(game->data, s_magic, sizeof(s_magic)) != 0) return false;
    s_flags = ((const uint8_t*)game->data)[sizeof(s_magic)];
    struct retro_hw_render_callback hw = { .context_type = RETRO_HW_CONTEXT_VULKAN, .version_major = 1, .version_minor = 1,
                                           .context_reset = vt_context_reset, .context_destroy = vt_context_destroy };
    if (!s_env(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw)) return false; // No software renderer to fall back to.
    if (!(s_flags & VT_FLAG_NO_NEGOTIATION)) s_env(RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE, (void*)&s_negotiation);
    memset(&s_state, 0, sizeof(s_state));
    memset(&s_sram, 0, sizeof(s_sram));
    s_booted = false;
    return true;
}

bool retro_load_game_special(unsigned type, const struct retro_game_info* info, size_t count) {
    (void)type; (void)info; (void)count;
    return false;
}

void retro_unload_game(void) {}
void retro_reset(void) { memset(&s_state, 0, sizeof(s_state)); }

void retro_run(void) {
    if (!s_booted) { // The adapter loads battery RAM after retro_load_game, so count the boot here.
        s_booted = true;
        s_sram.magic = 0x4B564147; // "GAVK"
        s_sram.boots++;
    }
    s_poll();
    if (s_input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT)) s_state.x += VT_STEP;
    if (s_input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT)) s_state.x -= VT_STEP;
    if (s_input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN)) s_state.y += VT_STEP;
    if (s_input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP)) s_state.y -= VT_STEP;
    s_state.frame++;

    // Rumble on player 2's port, so a test sees the port carried: A holds the strong motor full, B the weak one at half.
    struct retro_rumble_interface rumble = { 0 };
    if (s_env(RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE, &rumble) && rumble.set_rumble_state) {
        rumble.set_rumble_state(1, RETRO_RUMBLE_STRONG, s_input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A) ? 0xFFFF : 0);
        rumble.set_rumble_state(1, RETRO_RUMBLE_WEAK, s_input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B) ? 0x8000 : 0);
    }

    // A 500 Hz square wave.
    for (size_t i = 0; i < VT_RATE / VT_FPS; ++i, ++s_state.tone_phase) {
        int16_t sample = (s_state.tone_phase / (VT_RATE / 1000)) % 2 ? 3000 : -3000;
        s_samples[i * 2] = s_samples[i * 2 + 1] = sample;
    }
    s_audio(s_samples, VT_RATE / VT_FPS);

    if (s_vk) vt_render();
}

size_t retro_serialize_size(void) { return sizeof(s_state); }
bool retro_serialize(void* data, size_t size) {
    if (size < sizeof(s_state)) return false;
    memcpy(data, &s_state, sizeof(s_state));
    return true;
}
bool retro_unserialize(const void* data, size_t size) {
    if (size < sizeof(s_state)) return false;
    memcpy(&s_state, data, sizeof(s_state));
    return true;
}

void retro_cheat_reset(void) {}
void retro_cheat_set(unsigned index, bool enabled, const char* code) { (void)index; (void)enabled; (void)code; }
unsigned retro_get_region(void) { return RETRO_REGION_NTSC; }

void* retro_get_memory_data(unsigned id) { return id == RETRO_MEMORY_SAVE_RAM ? &s_sram : NULL; }
size_t retro_get_memory_size(unsigned id) { return id == RETRO_MEMORY_SAVE_RAM ? sizeof(s_sram) : 0; }

// MARK: - Bridge

static bool vt_is_rom(const uint8_t* data, size_t size) { return size >= sizeof(s_magic) + 1 && memcmp(data, s_magic, sizeof(s_magic)) == 0; }

const GagaLibretroCore gaga_libretro_core = {
    .name = "Vulkan Test",
    .game_kind = "a GagaEmu Vulkan test file",
    .is_rom = vt_is_rom,
};

const GagaCoreInterface* VkTest_GetInterface(void) {
    static const GagaCoreInterface interface = {
        GAGA_LIBRETRO_ENTRY_POINTS,
        GAGA_LIBRETRO_VULKAN_LAYER,
        .core_id = "vktest",
        .core_name = "Vulkan Test",
        .core_version = GAGA_CORE_VERSION,
        .supported_extensions = "gagavk",
        .target_fps = VT_FPS,
        .native_sample_rate = VT_RATE,
        .state_version = 1,
    };
    return &interface;
}
