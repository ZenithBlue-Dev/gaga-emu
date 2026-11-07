// What GagaEmu's MAME needs beside upstream: battery saves on demand, and offline replacements for the two
// upstream files that open sockets (generate.py leaves them out of sources.txt).
#include "emu.h"

#include "emuopts.h"
#include "http.h"
#include "mame.h"
#include "server_http.hpp"
#include "server_ws.hpp"
#include "server_ws_impl.hpp" // The member types' destructors; nothing here makes a server.
#include "server_http_impl.hpp"

#include "posixfile.h"

#include "modules/osdmodule.h"
#include "modules/output/output_module.h"
#include "plib/pdynlib.h"

#include "sqlite3.h"

// running_machine writes NVRAM files only when the machine stops, and keeps nvram_save() private. An
// explicit instantiation may name a private member, so this reaches it without editing upstream.
namespace {
void nvram_save(running_machine& machine);
template <void (running_machine::*Member)()> struct nvram_save_access {
    friend void nvram_save(running_machine& machine) { (machine.*Member)(); }
};
template struct nvram_save_access<&running_machine::nvram_save>;
} // namespace

// Writes every NVRAM device's file into nvram_directory (the save_dir the adapter was given, plus
// "mame/nvram"), as MAME does on exit. False without a running machine or when a file cannot be written.
extern "C" bool gaga_mame_save_battery(void) {
    mame_machine_manager* manager = mame_machine_manager::instance();
    running_machine* machine = manager ? manager->machine() : nullptr;
    if (!machine) return false;
    try {
        nvram_save(*machine);
    } catch (...) {
        return false;
    }
    return true;
}

// The web server is off unless -http is passed, and this build never passes it.
http_manager::http_manager(bool active, short, const char* root) : m_active(false), m_root(root ? root : "") {
    (void)active;
}
http_manager::~http_manager() = default;
void http_manager::clear() {}
void http_manager::add_template(const std::string&, substitution, char, char) {}
void http_manager::remove_template(const std::string&) {}
void http_manager::serve_template(http_request_ptr, http_response_ptr, const std::string&, substitution, char, char) {}
void http_manager::serve_document(http_request_ptr, http_response_ptr, const std::string&) {}
void http_manager::add_http_handler(const std::string&, http_handler) {}
void http_manager::remove_http_handler(const std::string&) {}
http_manager::websocket_endpoint_ptr http_manager::add_endpoint(const std::string&, websocket_open_handler,
        websocket_message_handler, websocket_close_handler, websocket_error_handler) {
    return std::make_shared<websocket_endpoint>();
}
void http_manager::remove_endpoint(const std::string&) {}

// The "network" output module listens on a TCP port; here it is one the OSD reports as unsupported.
namespace osd { namespace { MODULE_NOT_SUPPORTED(output_network, OSD_OUTPUT_PROVIDER, "network") } }
MODULE_DEFINITION(OUTPUT_NETWORK, osd::output_network)

// Netlist can load compiled solvers from a library; this build never loads code, so none is found and
// netlist uses its built-in solvers.
namespace plib {
dynamic_library::dynamic_library(const pstring&) : m_lib(nullptr) {}
dynamic_library::dynamic_library(const pstring&, const pstring&) : m_lib(nullptr) {}
dynamic_library::~dynamic_library() = default;
void* dynamic_library::get_symbol_pointer(const pstring&) const noexcept { return nullptr; }
} // namespace plib

// SQLite is built without extension loading (dlopen); the Lua binding still names these two, so they fail.
extern "C" int sqlite3_enable_load_extension(sqlite3*, int) { return SQLITE_ERROR; }
extern "C" int sqlite3_load_extension(sqlite3*, const char*, const char*, char** error) {
    if (error) *error = nullptr;
    return SQLITE_ERROR;
}

// "socket.<host>:<port>" and "domain.<path>" names are ordinary file names here.
bool posix_check_socket_path(std::string const&) noexcept { return false; }
bool posix_check_domain_path(std::string const&) noexcept { return false; }
std::error_condition posix_open_socket(std::string const&, std::uint32_t, osd_file::ptr&, std::uint64_t&) noexcept {
    return std::errc::not_supported;
}
std::error_condition posix_open_domain(std::string const&, std::uint32_t, osd_file::ptr&, std::uint64_t&) noexcept {
    return std::errc::not_supported;
}
