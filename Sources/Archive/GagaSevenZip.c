#include "GagaSevenZip.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "LZMA/7z.h"
#include "LZMA/7zAlloc.h"
#include "LZMA/7zCrc.h"
#include "LZMA/Lzma2Dec.h"
#include "LZMA/LzmaDec.h"

#define METHOD_COPY 0
#define METHOD_LZMA2 0x21
#define METHOD_LZMA 0x30101
#define CHUNK ((size_t)1 << 20)

static const ISzAlloc allocator = { SzAlloc, SzFree };

/// ISeekInStream over a FILE, which the SDK reads the headers through.
typedef struct {
    ISeekInStream vt;
    FILE *file;
} FileStream;

static SRes file_read(ISeekInStreamPtr p, void *buf, size_t *size) {
    FileStream *stream = (FileStream *)(void *)p;
    if (*size == 0) return SZ_OK;
    *size = fread(buf, 1, *size, stream->file);
    return ferror(stream->file) ? SZ_ERROR_READ : SZ_OK;
}

static SRes file_seek(ISeekInStreamPtr p, Int64 *pos, ESzSeek origin) {
    FileStream *stream = (FileStream *)(void *)p;
    int whence = origin == SZ_SEEK_CUR ? SEEK_CUR : origin == SZ_SEEK_END ? SEEK_END : SEEK_SET;
    if (fseeko(stream->file, (off_t)*pos, whence) != 0) return SZ_ERROR_READ;
    *pos = (Int64)ftello(stream->file);
    return SZ_OK;
}

struct GagaSevenZip {
    FileStream stream;
    CLookToRead2 look;
    CSzArEx db;
};

GagaSevenZip *gaga_7z_open(const char *path) {
    static int crcReady = 0;
    if (!crcReady) { CrcGenerateTable(); crcReady = 1; }
    GagaSevenZip *archive = calloc(1, sizeof(GagaSevenZip));
    if (!archive) return NULL;
    archive->stream.file = fopen(path, "rb");
    archive->look.buf = malloc(1 << 16);
    if (!archive->stream.file || !archive->look.buf) {
        if (archive->stream.file) fclose(archive->stream.file);
        free(archive->look.buf);
        free(archive);
        return NULL;
    }
    archive->stream.vt.Read = file_read;
    archive->stream.vt.Seek = file_seek;
    LookToRead2_CreateVTable(&archive->look, False);
    archive->look.bufSize = 1 << 16;
    archive->look.realStream = &archive->stream.vt;
    LookToRead2_INIT(&archive->look);
    SzArEx_Init(&archive->db);
    if (SzArEx_Open(&archive->db, &archive->look.vt, &allocator, &allocator) != SZ_OK) {
        gaga_7z_close(archive);
        return NULL;
    }
    return archive;
}

void gaga_7z_close(GagaSevenZip *archive) {
    if (!archive) return;
    SzArEx_Free(&archive->db, &allocator);
    fclose(archive->stream.file);
    free(archive->look.buf);
    free(archive);
}

uint32_t gaga_7z_count(const GagaSevenZip *archive) { return archive->db.NumFiles; }

size_t gaga_7z_name(const GagaSevenZip *archive, uint32_t index, uint16_t *dest) {
    return index < archive->db.NumFiles ? SzArEx_GetFileNameUtf16(&archive->db, index, dest) : 0;
}

int gaga_7z_is_dir(const GagaSevenZip *archive, uint32_t index) {
    return index < archive->db.NumFiles && SzArEx_IsDir(&archive->db, index);
}

uint64_t gaga_7z_size(const GagaSevenZip *archive, uint32_t index) {
    return index < archive->db.NumFiles ? SzArEx_GetFileSize(&archive->db, index) : 0;
}

int gaga_7z_crc(const GagaSevenZip *archive, uint32_t index, uint32_t *crc) {
    if (index >= archive->db.NumFiles || !SzBitWithVals_Check(&archive->db.CRCs, index)) return 0;
    *crc = archive->db.CRCs.Vals[index];
    return 1;
}

static int status(SRes res) {
    switch (res) {
    case SZ_OK: return GAGA_7Z_OK;
    case SZ_ERROR_UNSUPPORTED: return GAGA_7Z_UNSUPPORTED;
    case SZ_ERROR_MEM: return GAGA_7Z_NO_MEMORY;
    default: return GAGA_7Z_CORRUPT;
    }
}

/// The smallest LZMA2 dictionary property covering `size`: a stream never reaches back past its own start,
/// so a block needs no more dictionary than it unpacks to, whatever its header asks.
static Byte lzma2_prop(Byte prop, UInt64 size) {
    for (Byte p = 0; p < prop && p < 40; p++)
        if ((UInt64)((2 | (p & 1)) << (p / 2 + 11)) >= size) return p;
    return prop;
}

/// Streams one single-coder block (copy, LZMA or LZMA2), passing on bytes [skip, skip + size).
static int stream_block(GagaSevenZip *archive, const CSzCoderInfo *coder, const Byte *props, UInt64 packPos,
                        UInt64 packSize, UInt64 unpackSize, UInt64 skip, UInt64 size, UInt32 *crc,
                        gaga_7z_sink sink, void *context) {
    CLzmaDec lzma;
    CLzma2Dec lzma2;
    LzmaDec_CONSTRUCT(&lzma)
    Lzma2Dec_CONSTRUCT(&lzma2)
    SRes res = SZ_OK;
    if (coder->MethodID == METHOD_LZMA) {
        if (coder->PropsSize != 5) return GAGA_7Z_UNSUPPORTED;
        Byte clamped[5];
        memcpy(clamped, props, 5);
        UInt32 dict = (UInt32)clamped[1] | (UInt32)clamped[2] << 8 | (UInt32)clamped[3] << 16 | (UInt32)clamped[4] << 24;
        if (unpackSize < dict) {
            UInt32 smaller = (UInt32)(unpackSize < 4096 ? 4096 : unpackSize);
            for (int i = 0; i < 4; i++) clamped[1 + i] = (Byte)(smaller >> (8 * i));
        }
        res = LzmaDec_Allocate(&lzma, clamped, 5, &allocator);
        if (res == SZ_OK) LzmaDec_Init(&lzma);
    } else if (coder->MethodID == METHOD_LZMA2) {
        if (coder->PropsSize != 1) return GAGA_7Z_UNSUPPORTED;
        res = Lzma2Dec_Allocate(&lzma2, lzma2_prop(props[0], unpackSize), &allocator);
        if (res == SZ_OK) Lzma2Dec_Init(&lzma2);
    }
    Byte *in = malloc(CHUNK), *out = malloc(CHUNK);
    int result = GAGA_7Z_OK;
    if (res != SZ_OK || !in || !out) { result = res == SZ_OK ? GAGA_7Z_NO_MEMORY : status(res); goto done; }
    FILE *file = archive->stream.file;
    if (fseeko(file, (off_t)packPos, SEEK_SET) != 0) { result = GAGA_7Z_CORRUPT; goto done; }

    UInt64 packLeft = packSize, produced = 0, want = skip + size;
    size_t inPos = 0, inLen = 0;
    while (produced < want) {
        if (inPos == inLen && packLeft > 0) {
            size_t n = fread(in, 1, packLeft < CHUNK ? (size_t)packLeft : CHUNK, file);
            if (n == 0) { result = GAGA_7Z_CORRUPT; goto done; }
            packLeft -= n;
            inPos = 0;
            inLen = n;
        }
        SizeT outLen = want - produced < CHUNK ? (SizeT)(want - produced) : CHUNK;
        SizeT consumed = inLen - inPos;
        const Byte *chunk = out;
        if (coder->MethodID == METHOD_COPY) {
            if (consumed < outLen) outLen = consumed;
            consumed = outLen;
            chunk = in + inPos;
        } else {
            ELzmaStatus state;
            res = coder->MethodID == METHOD_LZMA
                ? LzmaDec_DecodeToBuf(&lzma, out, &outLen, in + inPos, &consumed, LZMA_FINISH_ANY, &state)
                : Lzma2Dec_DecodeToBuf(&lzma2, out, &outLen, in + inPos, &consumed, LZMA_FINISH_ANY, &state);
            if (res != SZ_OK) { result = status(res); goto done; }
        }
        inPos += consumed;
        // Nothing in and nothing out with input left, or with no input left at all: the stream ended early.
        if (outLen == 0 && consumed == 0 && (inPos < inLen || packLeft == 0)) { result = GAGA_7Z_CORRUPT; goto done; }
        UInt64 from = produced < skip ? skip - produced : 0;
        if (from < outLen) {
            *crc = CrcUpdate(*crc, chunk + from, outLen - from);
            if (sink(context, chunk + from, outLen - (size_t)from)) { result = GAGA_7Z_STOPPED; goto done; }
        }
        produced += outLen;
    }
done:
    free(in);
    free(out);
    LzmaDec_Free(&lzma, &allocator);
    Lzma2Dec_Free(&lzma2, &allocator);
    return result;
}

int gaga_7z_extract(GagaSevenZip *archive, uint32_t index, uint64_t memory_limit, gaga_7z_sink sink, void *context) {
    const CSzArEx *db = &archive->db;
    if (index >= db->NumFiles || SzArEx_IsDir(db, index)) return GAGA_7Z_CORRUPT;
    UInt64 size = SzArEx_GetFileSize(db, index);
    UInt32 crc = CRC_INIT_VAL;
    UInt32 folderIndex = db->FileToFolder[index];
    int result = GAGA_7Z_OK;
    if (folderIndex == (UInt32)-1) {
        if (size != 0) return GAGA_7Z_CORRUPT;
    } else {
        const CSzAr *ar = &db->db;
        CSzFolder folder;
        CSzData sd;
        const Byte *data = ar->CodersData + ar->FoCodersOffsets[folderIndex];
        sd.Data = data;
        sd.Size = ar->FoCodersOffsets[folderIndex + 1] - ar->FoCodersOffsets[folderIndex];
        if (SzGetNextFolderItem(&folder, &sd) != SZ_OK) return GAGA_7Z_CORRUPT;
        UInt64 unpackSize = SzAr_GetFolderUnpackSize(ar, folderIndex);
        UInt64 skip = db->UnpackPositions[index] - db->UnpackPositions[db->FolderToFile[folderIndex]];
        if (skip + size > unpackSize) return GAGA_7Z_CORRUPT;
        const CSzCoderInfo *coder = &folder.Coders[0];
        if (folder.NumCoders == 1 && folder.NumPackStreams == 1 &&
            (coder->MethodID == METHOD_COPY || coder->MethodID == METHOD_LZMA || coder->MethodID == METHOD_LZMA2)) {
            UInt32 pack = ar->FoStartPackStreamIndex[folderIndex];
            result = stream_block(archive, coder, data + coder->PropsOffset, db->dataPos + ar->PackPositions[pack],
                                  ar->PackPositions[pack + 1] - ar->PackPositions[pack], unpackSize, skip, size,
                                  &crc, sink, context);
            if (result != GAGA_7Z_OK) return result;
        } else {
            // shortcut: a filter chain decodes its whole block in memory, so it stops at memory_limit; stream BCJ too if real dumps need it.
            if (unpackSize > memory_limit) return GAGA_7Z_UNSUPPORTED;
            UInt32 block = (UInt32)-1;
            Byte *buffer = NULL;
            size_t bufferSize = 0, offset = 0, processed = 0;
            SRes res = SzArEx_Extract(db, &archive->look.vt, index, &block, &buffer, &bufferSize, &offset, &processed,
                                      &allocator, &allocator);
            if (res == SZ_OK && processed != size) res = SZ_ERROR_DATA;
            if (res == SZ_OK) {
                crc = CrcUpdate(crc, buffer + offset, processed);
                // SzArEx_Extract already checked the CRC; a slice of 1 MiB at a time keeps the sink's contract.
                for (size_t at = 0; at < processed && result == GAGA_7Z_OK; at += CHUNK) {
                    size_t n = processed - at < CHUNK ? processed - at : CHUNK;
                    if (sink(context, buffer + offset + at, n)) result = GAGA_7Z_STOPPED;
                }
            }
            ISzAlloc_Free(&allocator, buffer);
            if (res != SZ_OK) return status(res);
            if (result != GAGA_7Z_OK) return result;
        }
    }
    if (SzBitWithVals_Check(&db->CRCs, index) && CRC_GET_DIGEST(crc) != db->CRCs.Vals[index]) return GAGA_7Z_CORRUPT;
    return GAGA_7Z_OK;
}
