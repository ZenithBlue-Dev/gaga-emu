// What GagaEmu's MAME needs beside upstream: battery saves on demand, and offline replacements for the two
// upstream files that open sockets (generate.py leaves them out of sources.txt).
#include "emu.h"

#include "audit.h"
#include "cheat.h"
#include "drivenum.h"
#include "emuopts.h"
#include "fileio.h"
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

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstring>
#include <string_view>

// running_machine writes NVRAM files only when the machine stops, keeps nvram_filename() private, and its
// nvram_save() skips a file it cannot open without saying so. An explicit instantiation may name a private
// member, so this reaches it without editing upstream.
namespace {
std::string nvram_filename(running_machine const& machine, device_t& device);
template <std::string (running_machine::*Member)(device_t&) const> struct nvram_filename_access {
    friend std::string nvram_filename(running_machine const& machine, device_t& device) { return (machine.*Member)(device); }
};
template struct nvram_filename_access<&running_machine::nvram_filename>;
} // namespace

// Writes every NVRAM device's file into nvram_directory (the save_dir the adapter was given, plus
// "mame/nvram"), as running_machine::nvram_save() does on exit. False without a running machine or when a
// file cannot be written, so the adapter refuses a game whose progress would never reach disk.
extern "C" bool gaga_mame_save_battery(void) {
    mame_machine_manager* manager = mame_machine_manager::instance();
    running_machine* machine = manager ? manager->machine() : nullptr;
    if (!machine) return false;
    try {
        for (device_nvram_interface& nvram : nvram_interface_enumerator(machine->root_device())) {
            if (!nvram.nvram_can_save()) continue;
            emu_file file(machine->options().nvram_directory(), OPEN_FLAG_WRITE | OPEN_FLAG_CREATE | OPEN_FLAG_CREATE_PATHS);
            if (file.open(nvram_filename(*machine, nvram.device()))) return false;
            bool const saved = nvram.nvram_save(file);
            if (!saved || file.size() == 0) file.remove_on_close(); // As upstream: no empty files.
            file.close();
            if (!saved) return false;
        }
    } catch (...) {
        return false;
    }
    return true;
}

// Upstream's retro_deinit tears the game down while retro_load_ok is set, and never clears it, so the next
// retro_deinit (the adapter's self test before the next game) would tear down the freed game again.
// A load that failed inside MAME (a set with missing files, an unknown machine) returns without retro_finish,
// so the machine manager and the half-started machine stay alive, and the next load reuses that manager: device
// run 6 died there with "memory corruption of free block". Upstream's own frontend frees both after a failed
// run (cli_frontend::execute, mame_machine_manager::execute), so this does too.
extern bool retro_load_ok; // libretro_shared.h
void free_machineconfig(); // upstream/src/frontend/mame/mame.cpp
void free_man();           // upstream/src/frontend/mame/clifront.cpp
extern "C" void gaga_mame_after_deinit(void) {
    mame_machine_manager* manager = retro_load_ok ? nullptr : mame_machine_manager::instance();
    if (manager) {
        if (manager->machine()) free_machineconfig();
        free_man();
    }
    retro_load_ok = false;
}

// Checks a set against its machine's ROM list with MAME's own auditor before MAME starts it, so a set MAME
// cannot run gets a message that says why and never reaches MAME's failed start. Wrong checksums are left to
// MAME, which runs such a set and only warns. NULL when the set can start.
extern "C" const char* gaga_mame_refuse_load(const char* system_dir, const char* rom_path) {
    static std::string message;
    // Only an archive is audited; anything else gets the adapter's own messages (is_rom, an unopenable file).
    unsigned char magic[6] = {};
    if (FILE* file = std::fopen(rom_path, "rb")) {
        std::size_t const read = std::fread(magic, 1, sizeof(magic), file);
        std::fclose(file);
        bool const zip = read >= 4 && !std::memcmp(magic, "PK\3\4", 4);
        bool const sevenzip = read == 6 && !std::memcmp(magic, "7z\xBC\xAF\x27\x1C", 6);
        if (!zip && !sevenzip) return nullptr;
    } else {
        return nullptr;
    }
    try {
        std::string const path(rom_path);
        std::string::size_type const slash = path.find_last_of('/');
        std::string const folder = slash == std::string::npos ? "." : path.substr(0, slash);
        std::string name = path.substr(slash == std::string::npos ? 0 : slash + 1);
        name = name.substr(0, name.find_last_of('.'));
        for (char& c : name) c = char(std::tolower(static_cast<unsigned char>(c)));
        if (name.empty() || name[0] == '_' || driver_list::find(name.c_str()) < 0) {
            message = "This build of MAME has no machine named \"" + name + "\". A ROM set's file name must be the machine's short name.";
            return message.c_str();
        }
        // The folders upstream's Set_Path_Option searches: the game's own, then System/mame/bios and System/mame/roms.
        std::string const system = system_dir ? system_dir : "";
        emu_options options;
        options.set_value(OPTION_MEDIAPATH, folder + ";" + system + "/mame/bios;" + system + "/mame/roms", OPTION_PRIORITY_MAXIMUM);
        driver_enumerator drivers(options, name.c_str());
        if (!drivers.next()) return nullptr;
        media_auditor auditor(drivers);
        auditor.audit_media(AUDIT_VALIDATE_FAST);
        for (media_auditor::audit_record const& record : auditor.records()) {
            if (record.status() == media_auditor::audit_status::NOT_FOUND && record.substatus() == media_auditor::audit_substatus::NOT_FOUND) {
                message = "This ROM set is missing files that " + name + " needs, such as " + record.name() + ". Its parent or BIOS set may be missing too.";
                return message.c_str();
            }
        }
    } catch (...) {
        return nullptr; // The audit could not run; MAME's own load still checks the set.
    }
    return nullptr;
}

// Cheats. mame_cheats_enable makes MAME load System/mame/cheat/<set>.xml (or the same inside cheat.7z or
// cheat.zip there) when the machine starts. A code is one cheat's description from that file, "Infinite Lives",
// or for a cheat with settings, "Starting Level = 5", the setting as MAME's own cheat menu shows it.
// mame_machine_manager::cheat() asserts, so the engine is reached as nvram_filename is, and checked for null.
namespace {
std::unique_ptr<cheat_manager>& cheat_engine(mame_machine_manager& manager);
template <std::unique_ptr<cheat_manager> mame_machine_manager::*Member> struct cheat_engine_access {
    friend std::unique_ptr<cheat_manager>& cheat_engine(mame_machine_manager& manager) { return manager.*Member; }
};
template struct cheat_engine_access<&mame_machine_manager::m_cheat>;

cheat_manager* running_cheats() {
    mame_machine_manager* manager = mame_machine_manager::instance();
    if (!manager || !manager->machine()) return nullptr;
    cheat_manager* engine = cheat_engine(*manager).get();
    return engine && engine->enabled() ? engine : nullptr;
}

std::string trimmed(std::string_view text) {
    std::string_view::size_type const start = text.find_first_not_of(" \t\r\n");
    if (start == std::string_view::npos) return std::string();
    return std::string(text.substr(start, text.find_last_not_of(" \t\r\n") - start + 1));
}

bool same(std::string_view a, std::string_view b) {
    return a.size() == b.size() && std::equal(a.begin(), a.end(), b.begin(), [](char x, char y) {
        return std::tolower(static_cast<unsigned char>(x)) == std::tolower(static_cast<unsigned char>(y));
    });
}

struct cheat_choice {
    cheat_entry* entry = nullptr;
    std::string setting; // Empty for an on/off or one-shot cheat.
};

cheat_choice find_cheat(cheat_manager& engine, std::string_view line) {
    auto named = [&](std::string const& name) -> cheat_entry* {
        for (auto const& entry : engine.entries()) {
            if (!entry->is_text_only() && same(trimmed(entry->description()), name)) return entry.get();
        }
        return nullptr;
    };
    cheat_choice choice;
    if ((choice.entry = named(trimmed(line)))) {
        if (!choice.entry->is_onoff() && !choice.entry->is_oneshot()) choice.entry = nullptr; // Needs "= setting".
        return choice;
    }
    std::string_view::size_type const equals = line.rfind('=');
    if (equals == std::string_view::npos) return choice;
    choice.entry = named(trimmed(line.substr(0, equals)));
    choice.setting = trimmed(line.substr(equals + 1));
    if (!choice.entry || choice.setting.empty() || !(choice.entry->is_value_parameter() || choice.entry->is_itemlist_parameter()))
        choice.entry = nullptr;
    return choice;
}

// Steps a cheat with settings from off to the one named, as MAME's menu does. False if none has that name.
bool select_setting(cheat_entry& entry, std::string const& setting) {
    entry.select_default_state();
    for (int step = 0; step < 4096 && entry.select_next_state(); ++step) {
        std::string description, state;
        uint32_t flags = 0;
        entry.menu_text(description, state, flags);
        if (same(trimmed(state), setting)) return true;
    }
    entry.select_default_state();
    return false;
}
} // namespace

extern "C" bool gaga_mame_is_cheat(const char* line) {
    cheat_manager* engine = running_cheats();
    if (!engine || !line) return false;
    cheat_choice const choice = find_cheat(*engine, line);
    if (!choice.entry) return false;
    if (choice.setting.empty()) return true;
    bool const found = select_setting(*choice.entry, choice.setting); // The adapter resets and applies next.
    choice.entry->select_default_state();
    return found;
}

extern "C" void gaga_mame_cheat_reset(void) {
    if (cheat_manager* engine = running_cheats()) {
        for (auto const& entry : engine->entries()) entry->select_default_state();
    }
}

extern "C" void gaga_mame_cheat_set(unsigned, bool enabled, const char* code) {
    cheat_manager* engine = running_cheats();
    if (!engine || !enabled || !code) return;
    cheat_choice const choice = find_cheat(*engine, code);
    if (!choice.entry) return;
    if (choice.entry->is_oneshot()) {
        choice.entry->activate(); // shortcut: a one-shot runs again whenever the list changes. Fine for "set" cheats.
    } else if (choice.setting.empty()) {
        choice.entry->select_default_state();
        choice.entry->select_next_state(); // Off to on.
    } else if (select_setting(*choice.entry, choice.setting) && choice.entry->is_oneshot_parameter()) {
        choice.entry->activate();
    }
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
