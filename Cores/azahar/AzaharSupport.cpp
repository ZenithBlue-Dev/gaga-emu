// GagaEmu's own code for the Azahar core: the refusing stand-ins flags.h sends network calls to.
#include <cerrno>
#include <netdb.h>
#include <sys/socket.h>

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
