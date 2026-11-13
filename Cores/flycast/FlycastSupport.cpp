// What GagaEmu's Flycast build uses in place of the upstream files core.env leaves out:
// - core/linux/posix_vmem.cpp: no memory mapping or page protection at all (docs/04 section 8). Flycast
//   then runs on plain heap memory, the path its interpreter takes when virtual memory is unavailable.
//   Its texture cache learns of writes to video memory from page faults, so here the "locked" pages are
//   copied instead and compared once per frame (gaga_flycast_check_vram).
// - core/linux/common.cpp: no signal handlers. Nothing here faults on purpose.
// - core/oslib/resources.cpp and its generated resource library: only the HLE BIOS font, read from
//   upstream's own zip at build time. The Naomi flash and printer resources are not included.
// - core/oslib/i18n.cpp and tinygettext: messages stay in English.
// - core/archive: no zip or 7z content. Dreamcast discs are .gdi, .cdi and .chd files.
// - shell/libretro/oslib_apple.mm: the same normalisation through Core Foundation, so no Objective-C.
// - the socket and name lookup calls that flags.h renames: all refused.
#include "types.h"
#include "archive/archive.h"
#include "hw/mem/addrspace.h"
#include "hw/pvr/pvr_mem.h"
#include "oslib/i18n.h"
#include "oslib/resources.h"
#include "oslib/virtmem.h"

#include <CoreFoundation/CoreFoundation.h>
#include <bitset>
#include <cerrno>
#include <cstring>
#include <netdb.h>
#include <sys/socket.h>
#include <zlib.h>

bool VramLockedWriteOffset(size_t offset); // rend/TexCache.cpp

// MARK: - Video memory write tracking

namespace {
constexpr size_t kVramPages = VRAM_SIZE_MAX / PAGE_SIZE;
std::bitset<kVramPages> s_locked;
u8* s_shadow; // A copy of each locked page, taken when it was locked. Allocated on first use.
}

// Called before every frame. A texture whose page changed is dropped, and Flycast decodes it again from
// video memory when the game next draws with it. A page written and drawn from in the same frame shows
// its old contents for that one frame; the page fault this replaces would have caught that.
extern "C" void gaga_flycast_check_vram(void) {
    if (!s_shadow || s_locked.none()) return;
    for (size_t page = 0; page < kVramPages; ++page) {
        if (!s_locked.test(page)) continue;
        size_t offset = page * PAGE_SIZE;
        if (memcmp(s_shadow + offset, &vram[offset], PAGE_SIZE) == 0) continue;
        // VramLockedWriteOffset unlocks the page through region_unlock. It returns false only before the
        // texture cache exists, and then nothing needs the page.
        if (!VramLockedWriteOffset(offset)) s_locked.reset(page);
    }
}

namespace virtmem {

// False: Flycast allocates its memory on the heap and every access takes the handler path (addrspace.cpp).
bool init(void** vmem_base_addr, void** sh4rcb_addr, size_t ramSize) {
    (void)vmem_base_addr;
    (void)sh4rcb_addr;
    (void)ramSize;
    return false;
}
void reset_mem(void* ptr, unsigned size_bytes) { (void)ptr; (void)size_bytes; }
void ondemand_page(void* address, unsigned size_bytes) { (void)address; (void)size_bytes; }
void create_mappings(const Mapping* vmem_maps, unsigned nummaps) { (void)vmem_maps; (void)nummaps; }
void destroy() {}

// The recompilers that call these are not compiled (TARGET_NO_REC). Each refuses. The sideload JIT build
// (jit.env) takes the RW/RX pair functions from FlycastJit26.cpp; region_set_exec stays a refusal there, since
// its code memory is never re-protected.
bool prepare_jit_block(void* code_area, size_t size, void** code_area_rwx) {
    (void)code_area; (void)size; (void)code_area_rwx;
    return false;
}
#ifndef GAGA_CORE_JIT
bool prepare_jit_block(void* code_area, size_t size, void** code_area_rw, ptrdiff_t* rx_offset) {
    (void)code_area; (void)size; (void)code_area_rw; (void)rx_offset;
    return false;
}
void flush_cache(void* icache_start, void* icache_end, void* dcache_start, void* dcache_end) {
    (void)icache_start; (void)icache_end; (void)dcache_start; (void)dcache_end;
}
void release_jit_block(void* code_area1, void* code_area2, size_t size) { (void)code_area1; (void)code_area2; (void)size; }
#endif
void jit_set_exec(void* code, size_t size, bool enable) { (void)code; (void)size; (void)enable; }
void release_jit_block(void* code_area, size_t size) { (void)code_area; (void)size; }
bool region_set_exec(void* start, std::size_t len) { (void)start; (void)len; return false; }

// Only video memory is locked in this build: the RAM and sound RAM watchers belong to GGPO, which
// LIBRETRO builds leave out.
bool region_lock(void* start, std::size_t len) {
    u32 offset = addrspace::getVramOffset(start);
    if (offset == (u32)-1) return true;
    if (!s_shadow && !(s_shadow = (u8*)malloc(VRAM_SIZE_MAX))) return false;
    for (size_t page = offset / PAGE_SIZE; page * PAGE_SIZE < offset + len && page < kVramPages; ++page) {
        memcpy(s_shadow + page * PAGE_SIZE, &vram[page * PAGE_SIZE], PAGE_SIZE);
        s_locked.set(page);
    }
    return true;
}

bool region_unlock(void* start, std::size_t len) {
    u32 offset = addrspace::getVramOffset(start);
    if (offset == (u32)-1) return true;
    for (size_t page = offset / PAGE_SIZE; page * PAGE_SIZE < offset + len && page < kVramPages; ++page) s_locked.reset(page);
    return true;
}

} // namespace virtmem

void os_InstallFaultHandler() {}
void os_UninstallFaultHandler() {}

// MARK: - Resources

// upstream/fonts/biosfont.bin.zip, one deflated entry: the HLE BIOS font, built by upstream's
// fonts/biosfont.cpp from free fonts (docs/03). The path is relative to Cores/flycast, where it compiles.
__asm__(".section __TEXT,__const\n"
        ".globl _gaga_flycast_biosfont_zip\n"
        ".private_extern _gaga_flycast_biosfont_zip\n"
        ".p2align 4\n"
        "_gaga_flycast_biosfont_zip:\n"
        ".incbin \"upstream/fonts/biosfont.bin.zip\"\n"
        ".globl _gaga_flycast_biosfont_zip_end\n"
        ".private_extern _gaga_flycast_biosfont_zip_end\n"
        "_gaga_flycast_biosfont_zip_end:\n"
        ".text\n");
extern "C" const u8 gaga_flycast_biosfont_zip[];
extern "C" const u8 gaga_flycast_biosfont_zip_end[];

static u32 read_le(const u8* p, int bytes) {
    u32 value = 0;
    for (int i = bytes - 1; i >= 0; --i) value = value << 8 | p[i];
    return value;
}

// The zip's first local header, deflate only. Anything else is refused, and the HLE BIOS then draws no text.
static std::unique_ptr<u8[]> inflate_first_entry(const u8* zip, size_t zip_size, size_t& size) {
    size = 0;
    if (zip_size < 30 || read_le(zip, 4) != 0x04034b50 || read_le(zip + 8, 2) != 8 || (read_le(zip + 6, 2) & 8)) return nullptr;
    size_t packed = read_le(zip + 18, 4), unpacked = read_le(zip + 22, 4);
    size_t data = 30 + read_le(zip + 26, 2) + read_le(zip + 28, 2);
    if (data > zip_size || packed > zip_size - data || unpacked == 0) return nullptr;
    auto buffer = std::make_unique<u8[]>(unpacked);
    z_stream stream {};
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return nullptr;
    stream.next_in = const_cast<u8*>(zip + data);
    stream.avail_in = (uInt)packed;
    stream.next_out = buffer.get();
    stream.avail_out = (uInt)unpacked;
    int rc = inflate(&stream, Z_FINISH);
    inflateEnd(&stream);
    if (rc != Z_STREAM_END || stream.total_out != unpacked) return nullptr;
    size = unpacked;
    return buffer;
}

namespace resource {

std::unique_ptr<u8[]> load(const std::string& path, size_t& size) {
    size = 0;
    if (path != "fonts/biosfont.bin") return nullptr;
    return inflate_first_entry(gaga_flycast_biosfont_zip, (size_t)(gaga_flycast_biosfont_zip_end - gaga_flycast_biosfont_zip), size);
}

std::vector<std::string> listDirectory(const std::string& path) {
    (void)path;
    return {};
}

} // namespace resource

// MARK: - Messages, archives, file names

namespace i18n {
void init() {}
void reloadLanguage() {}
std::string Ts(const std::string& msg) { return msg; }
const char* T(const char* msg) { return msg; }
const char* translateCtx(const std::string& context, const char* msg) {
    (void)context;
    return msg;
}
const char* translatePlural(const char* msg, const char* msgPlural, int num) { return num == 1 ? msg : msgPlural; }
} // namespace i18n

Archive* OpenArchive(const std::string& path) {
    (void)path;
    return nullptr;
}

// Directory listings on Apple file systems come back decomposed; Flycast compares names composed.
std::string os_PrecomposedString(std::string string) {
    CFStringRef source = CFStringCreateWithCString(kCFAllocatorDefault, string.c_str(), kCFStringEncodingUTF8);
    if (!source) return string;
    CFMutableStringRef text = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, source);
    CFRelease(source);
    if (!text) return string;
    CFStringNormalize(text, kCFStringNormalizationFormC);
    std::string result(CFStringGetMaximumSizeForEncoding(CFStringGetLength(text), kCFStringEncodingUTF8) + 1, '\0');
    if (CFStringGetCString(text, result.data(), (CFIndex)result.size(), kCFStringEncodingUTF8)) {
        result.resize(strlen(result.c_str()));
    } else {
        result = string;
    }
    CFRelease(text);
    return result;
}

// MARK: - Network, refused (flags.h)

extern "C" {
int gaga_flycast_no_socket(int domain, int type, int protocol) {
    (void)domain; (void)type; (void)protocol;
    errno = EACCES;
    return -1;
}
int gaga_flycast_no_connect(int fd, const struct sockaddr* address, socklen_t length) {
    (void)fd; (void)address; (void)length;
    errno = EBADF;
    return -1;
}
int gaga_flycast_no_bind(int fd, const struct sockaddr* address, socklen_t length) {
    (void)fd; (void)address; (void)length;
    errno = EBADF;
    return -1;
}
int gaga_flycast_no_listen(int fd, int backlog) {
    (void)fd; (void)backlog;
    errno = EBADF;
    return -1;
}
int gaga_flycast_no_accept(int fd, struct sockaddr* address, socklen_t* length) {
    (void)fd; (void)address; (void)length;
    errno = EBADF;
    return -1;
}
int gaga_flycast_no_getaddrinfo(const char* node, const char* service, const struct addrinfo* hints, struct addrinfo** result) {
    (void)node; (void)service; (void)hints;
    if (result) *result = nullptr;
    return EAI_FAIL;
}
struct hostent* gaga_flycast_no_gethostbyname(const char* name) {
    (void)name;
    h_errno = NO_RECOVERY;
    return nullptr;
}
}
