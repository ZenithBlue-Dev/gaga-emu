// The C++ half of BsnesCore.c: battery saves, and the one video filter the libretro target uses.
#include <sfc/sfc.hpp>
#include <filter/filter.hpp>

// upstream/bsnes/filter/filter.cpp is not compiled: it bundles third-party scalers, among them blargg's
// snes_ntsc (LGPL-2.1). bsnes_video_filter is frozen at None, so None is all the core ever draws with.
// none.cpp is bsnes's own file, under the core's licence.
#include <filter/none.cpp>

// libretro.cpp also names the NTSC filters, reachable only through that option. Here they draw unfiltered.
namespace Filter::NTSC_RF { auto size(uint& w, uint& h) -> void { None::size(w, h); }
auto render(uint32_t* t, uint32_t* o, uint op, const uint16_t* i, uint p, uint w, uint h) -> void { None::render(t, o, op, i, p, w, h); } }
namespace Filter::NTSC_Composite { auto size(uint& w, uint& h) -> void { None::size(w, h); }
auto render(uint32_t* t, uint32_t* o, uint op, const uint16_t* i, uint p, uint w, uint h) -> void { None::render(t, o, op, i, p, w, h); } }
namespace Filter::NTSC_SVideo { auto size(uint& w, uint& h) -> void { None::size(w, h); }
auto render(uint32_t* t, uint32_t* o, uint op, const uint16_t* i, uint p, uint w, uint h) -> void { None::render(t, o, op, i, p, w, h); } }
namespace Filter::NTSC_RGB { auto size(uint& w, uint& h) -> void { None::size(w, h); }
auto render(uint32_t* t, uint32_t* o, uint op, const uint16_t* i, uint p, uint w, uint h) -> void { None::render(t, o, op, i, p, w, h); } }

// Passes every file open through to the libretro target's Program, and notes a battery file that would
// not open for writing.
namespace {
struct SaveWatch : Emulator::Platform {
    Emulator::Platform* inner = nullptr;
    bool failed = false;

    auto open(uint id, string name, vfs::file::mode mode, bool required) -> shared_pointer<vfs::file> override {
        auto file = inner->open(id, name, mode, required);
        if (mode == vfs::file::mode::write && !file) failed = true;
        return file;
    }
};
}

// bsnes writes its battery files itself (<rom stem>.srm and others in the save directory) and returns no
// RETRO_MEMORY_SAVE_RAM, so the adapter calls this instead. It runs between frames, on the host's queue.
// shortcut: bsnes truncates and rewrites each file in place, so a crash mid-write can damage it. Write to a temp file and rename if that is ever seen.
extern "C" bool gaga_bsnes_save_battery(void) {
    SaveWatch watch;
    watch.inner = platform; // emulator.hpp defines platform as Emulator::platform.
    platform = &watch;
    SuperFamicom::system.save();
    platform = watch.inner;
    return !watch.failed;
}

// Upstream's retro_cheat_set adds one code and passes the whole list to Interface::cheats. That rebuilds
// every code it already had with enable false and no saved byte, so only the newest code is held each
// frame and the others are never put back. With nothing applied, each call builds all codes fresh.
// Last first, so two codes on one address put the first saved byte back last.
extern "C" void gaga_bsnes_unapply_cheats(void) {
    using namespace SuperFamicom;
    auto& codes = cheat.codes;
    Memory::GlobalWriteEnable = true;
    for (uint i = codes.size(); i-- > 0;) {
        if (codes[i].enable) bus.write(codes[i].address, codes[i].restore);
    }
    Memory::GlobalWriteEnable = false;
    cheat.reset();
}
