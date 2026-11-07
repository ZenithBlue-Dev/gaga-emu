// Stands in for upstream's sources/src/hrtmon.rom.c, the HRTmon monitor cartridge ROM, whose licence is unclear.
// ar.c opens it only when the player picks the HRTmon cartridge, which GagaEmu never sets; empty, it fails to open.
unsigned char hrtrom[1] = { 0 };
unsigned int hrtrom_len = 0;

// The one symbol others take from retrodep/mman.c, which is not built (puae_fpp_native.c says why). mman.c only
// raises it when it reserves natmem, which this build never does, so it stays 0 as in upstream's own iOS build.
unsigned int max_z3fastmem = 0;
