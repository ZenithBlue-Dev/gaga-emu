#ifndef GAGA_SEVEN_ZIP_H
#define GAGA_SEVEN_ZIP_H

#include <stddef.h>
#include <stdint.h>

/// A .7z archive read with the LZMA SDK (Sources/Archive/LZMA). Entries are listed from the headers, and one
/// file is decoded at a time, streamed to a sink in chunks, never held whole in memory.
typedef struct GagaSevenZip GagaSevenZip;

enum {
    GAGA_7Z_OK = 0,
    GAGA_7Z_CORRUPT = 1,      // damaged data, a short stream or a CRC mismatch
    GAGA_7Z_UNSUPPORTED = 2,  // encryption, or a method or filter chain this reader does not stream
    GAGA_7Z_STOPPED = 3,      // the sink returned nonzero
    GAGA_7Z_NO_MEMORY = 4
};

/// Nil when the file is not a readable 7z archive.
GagaSevenZip *gaga_7z_open(const char *path);
void gaga_7z_close(GagaSevenZip *archive);

uint32_t gaga_7z_count(const GagaSevenZip *archive);
/// The entry's path as UTF-16 with a trailing 0. Returns the length in units including that 0; pass NULL to ask.
size_t gaga_7z_name(const GagaSevenZip *archive, uint32_t index, uint16_t *dest);
int gaga_7z_is_dir(const GagaSevenZip *archive, uint32_t index);
uint64_t gaga_7z_size(const GagaSevenZip *archive, uint32_t index);
/// 1 and the CRC-32 when the archive records one, else 0.
int gaga_7z_crc(const GagaSevenZip *archive, uint32_t index, uint32_t *crc);

/// Bytes of the entry at `index`, in order. Nonzero stops the extraction with GAGA_7Z_STOPPED.
typedef int (*gaga_7z_sink)(void *context, uint32_t index, const uint8_t *bytes, size_t count);

/// Decodes the `count` entries at `indices` into `sink` and checks each CRC-32. Each solid block is decoded once,
/// however many of the entries it holds. Copy, LZMA and LZMA2 stream in 1 MiB chunks, skipping files nobody
/// asked for. Any other chain (BCJ, BCJ2, Delta and other filters) is decoded by the SDK in memory, only when
/// its block unpacks to at most `memory_limit` bytes; past that it is unsupported.
int gaga_7z_extract(GagaSevenZip *archive, const uint32_t *indices, uint32_t count, uint64_t memory_limit,
                    gaga_7z_sink sink, void *context);

/// Solid blocks decoded since launch, so a test can count them.
uint64_t gaga_7z_block_decodes(void);

#endif
