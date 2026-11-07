// Stands in for upstream/src/audio/emu2413/emu2413.c, the YM2413 (FM Sound Unit) emulation. That file is
// Jarek Burczynski's MAME ym2413.c by way of Genesis Plus GX and states no licence, so it is not compiled
// (docs/03 section 5). FM music, which only Japanese Master System games use, is silent; the PSG plays as
// normal. The context is kept so save states keep upstream's layout.
#include "audio/emu2413/emu2413.h"

#include <string.h>

static YM2413_OPLL s_opll;

void YM2413Init(void) { memset(&s_opll, 0, sizeof(s_opll)); }
void YM2413ResetChip(void) { memset(&s_opll, 0, sizeof(s_opll)); }
int YM2413Update(void) { return 0; }
void YM2413Write(unsigned int a, unsigned int v) { (void)a; (void)v; }
unsigned int YM2413Read(void) { return 0; }
unsigned char* YM2413GetContextPtr(void) { return (unsigned char*)&s_opll; }
unsigned int YM2413GetContextSize(void) { return sizeof(s_opll); }
