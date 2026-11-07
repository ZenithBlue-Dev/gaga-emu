// What the interpreter-only build needs from mednafen/ss/sh7095_jit_x86.c, which is not compiled so that no
// file of a recompiler is in the binary (core.env). On a non-x86 host upstream's copy is only these stubs and
// tables, so SH2JIT_Available() is false and ss.c always runs the interpreter loop. Without WANT_JIT nothing
// references the SCU and SCSP DSP recompilers, so they need no stand-in.
#include <stdbool.h>
#include <stdint.h>

struct SH7095;

void (*SH2JIT_Table[65536])(struct SH7095*);
uint8_t SH2JIT_OpID[65536];

void SH2JIT_Init(struct SH7095* a, struct SH7095* d, int32_t* b, const int32_t* c, int32_t q) { (void)a; (void)d; (void)b; (void)c; (void)q; }
bool SH2JIT_Available(void) { return false; }
void SH2JIT_RunChain(struct SH7095* z) { (void)z; }
void SH2JIT_SetSingleStep(bool on) { (void)on; }
void SH2JIT_SetCounting(bool on) { (void)on; }
bool SH2JIT_RunBlock(struct SH7095* z) { (void)z; return false; }
void SH2JIT_InvalidateBlocks(void) {}
uint64_t SH2JIT_BlockStats[4];
uint64_t SH2JIT_NativeCount, SH2JIT_ChainCount, SH2JIT_FallbackCount;
void (*SH2JIT_Handler(uint32_t instr))(struct SH7095*) { (void)instr; return 0; }
