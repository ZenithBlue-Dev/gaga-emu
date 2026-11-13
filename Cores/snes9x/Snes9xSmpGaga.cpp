// Upstream's apu/bapu/smp/smp.cpp, with GagaEmu's clean-room SPC700 boot program (Cores/bsnes/GagaIPL.s) in
// place of the Nintendo IPL that upstream's iplrom.cpp holds (docs/03 section 5).
//
// core_prepare in core.env writes a copy of smp.cpp without its iplrom.cpp include, and fails the build if
// upstream's line moves. sources.txt gives this file -Iupstream/apu/bapu/smp, so the copy's other includes
// still find upstream's files. scripts/bootrom-gate.py fails the build if Nintendo's IPL ever comes back.
#include "../../build/cores/snes9x/gen/smp.cpp"

namespace SNES {
const uint8 SMP::iplrom[64] = {
#include "../bsnes/GagaIPL.inc"
};
}
