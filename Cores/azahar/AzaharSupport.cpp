// GagaEmu's own code for the Azahar core: the refusing stand-ins flags.h sends network calls to, and the
// settings upstream's libretro frontend has no option for.
#include <cerrno>
#include <netdb.h>
#include <sys/socket.h>

#include "common/settings.h"
#include "core/core.h"
#include "video_core/gpu.h"
#include "video_core/renderer_vulkan/renderer_vulkan.h"

// MARK: - Frame order

// RendererVulkan::RenderToWindow records the frame's draw, hands it to the VulkanWorker thread (Scheduler::Flush),
// then presents at once: set_image with no semaphore, then the video callback. The worker may submit the draw after
// the adapter's copy, which then reads an image the frame has not drawn yet (device runs 14 and 15: an all-black 3DS
// picture in the second session). The scheduler is private, so its address comes from an explicit instantiation,
// which skips access checks ([temp.spec.general]); upstream stays unpatched.
namespace {
Vulkan::Scheduler Vulkan::RendererVulkan::* gaga_scheduler_member();
template <Vulkan::Scheduler Vulkan::RendererVulkan::* Member>
struct GagaSchedulerAccess {
    friend Vulkan::Scheduler Vulkan::RendererVulkan::* gaga_scheduler_member() { return Member; }
};
template struct GagaSchedulerAccess<&Vulkan::RendererVulkan::scheduler>;
} // namespace

extern "C" void gaga_azahar_before_present(void) {
    Core::System& system = Core::System::GetInstance();
    if (!system.IsPoweredOn() || Settings::values.graphics_api.GetValue() != Settings::GraphicsAPI::Vulkan) return;
    auto& renderer = static_cast<Vulkan::RendererVulkan&>(system.GPU().Renderer());
    (renderer.*gaga_scheduler_member()).WaitWorker();
}

// MARK: - Settings

// Runs after retro_load_game and before context_reset, where the Vulkan rasterizer reads it. Device run 10's 3DS
// game hitched up to 886 ms throughout the run with the core thread mostly off the CPU: Metal compiles pipelines
// out of process while the emulation thread waits. Asynchronous compilation hands them to Azahar's pipeline
// workers and skips a draw meanwhile. No CPU code is generated: these are GPU shaders.
extern "C" const char* gaga_azahar_finish_load(void) {
    Settings::values.async_shader_compilation = true;
    return nullptr;
}

// MARK: - Network, refused (flags.h)

extern "C" {
int gaga_azahar_no_socket(int domain, int type, int protocol) {
    (void)domain; (void)type; (void)protocol;
    errno = EACCES;
    return -1;
}
int gaga_azahar_no_connect(int fd, const struct sockaddr* address, socklen_t length) {
    (void)fd; (void)address; (void)length;
    errno = EBADF;
    return -1;
}
int gaga_azahar_no_bind(int fd, const struct sockaddr* address, socklen_t length) {
    (void)fd; (void)address; (void)length;
    errno = EBADF;
    return -1;
}
int gaga_azahar_no_listen(int fd, int backlog) {
    (void)fd; (void)backlog;
    errno = EBADF;
    return -1;
}
int gaga_azahar_no_accept(int fd, struct sockaddr* address, socklen_t* length) {
    (void)fd; (void)address; (void)length;
    errno = EBADF;
    return -1;
}
int gaga_azahar_no_getaddrinfo(const char* node, const char* service, const struct addrinfo* hints,
                               struct addrinfo** result) {
    (void)node; (void)service; (void)hints;
    if (result) *result = nullptr;
    return EAI_FAIL;
}
struct hostent* gaga_azahar_no_gethostbyname(const char* name) {
    (void)name;
    h_errno = NO_RECOVERY;
    return nullptr;
}
}
