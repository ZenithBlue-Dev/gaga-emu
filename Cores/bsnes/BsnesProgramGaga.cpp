// Upstream's target-libretro/program.cpp, with GagaEmu's clean-room SPC700 boot program (GagaIPL.s) in
// place of the Nintendo IPL that upstream's resources.hpp holds (docs/03 section 5).
//
// program.h is #pragma once and includes resources.hpp, so it is included here first with upstream's array
// renamed. Nothing uses the renamed array, so the compiler drops it, and scripts/bootrom-gate.py fails the
// build if it ever comes back. Program::open then hands "ipl.rom" this file's iplrom.
#define iplrom gaga_upstream_iplrom_unused
#include "program.h"
#undef iplrom

static const unsigned char iplrom[64] = {
#include "GagaIPL.inc"
};

#include "upstream/bsnes/target-libretro/program.cpp"
