// Builds upstream's libretro core (sources.txt lists this file instead of upstream/libretro.cpp) and adds what
// BeetleSupergrafxCore.c needs from its static state. Upstream stays unmodified.
#include "upstream/libretro.cpp"

// last_sound_rate outlives retro_unload_game, but the next game gets new Blip_Buffers with no sample rate. retro_run
// sets the rate only when it changes, so the second game in one process wrote PSG output into a NULL buffer.
extern "C" const char* gaga_sgx_finish_load(void)
{
   last_sound_rate = 0;
   return NULL;
}
