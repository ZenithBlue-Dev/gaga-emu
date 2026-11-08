// GagaEmu's own code for the Azahar core: the refusing stand-ins flags.h sends network calls to, and the
// settings upstream's libretro frontend has no option for.
#include <cerrno>
#include <netdb.h>
#include <sys/socket.h>

#include "common/settings.h"

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
