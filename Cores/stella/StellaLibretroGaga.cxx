// Upstream's src/os/libretro/libretro.cxx, with one fix at its retro_run.
//
// StellaLIBRETRO::getVideoBuffer keeps the TIA surface's address from the first frame it is asked for, and
// destroy() and create() do not forget it. Every later load (a second game, or a reset_system) builds a new
// surface, so retro_run handed the frontend the freed surface of the game before: a frozen or garbled picture
// once the allocator put the new surface elsewhere (device run 9: the state round trip read other heap bytes).
// The cached address is cleared before each frame, so it is looked up again from the live surface.
#include "libretro.h"
#include "StellaLIBRETRO.hxx"

#define retro_run gaga_stella_upstream_run
#include "upstream/src/os/libretro/libretro.cxx"
#undef retro_run

namespace {
using SurfaceCache = uInt32* StellaLIBRETRO::*;

// render_surface is private. An explicit instantiation may name a private member, and this one hands it out.
template <SurfaceCache Member> struct SurfaceCacheMember {
    friend SurfaceCache surfaceCache() { return Member; }
};
SurfaceCache surfaceCache();
template struct SurfaceCacheMember<&StellaLIBRETRO::render_surface>;
}  // namespace

void retro_run() {
    stella.*surfaceCache() = nullptr;
    gaga_stella_upstream_run();
}
