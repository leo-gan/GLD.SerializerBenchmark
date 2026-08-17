#include "bench.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#ifdef HAS_ZSTD
#include <zstd.h>
#endif

/* gzip format (header + CRC), level 6 — matches Python gzip.compress(..., 6). */
static size_t gzip_size(const uint8_t *data, size_t n) {
    if (!data || n == 0) return 0;
    z_stream strm;
    memset(&strm, 0, sizeof strm);
    /* windowBits 15+16 = gzip wrapper. */
    if (deflateInit2(&strm, 6, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return 0;
    }
    uLong bound = compressBound((uLong)n) + 32;
    uint8_t *out = (uint8_t *)malloc(bound);
    if (!out) {
        deflateEnd(&strm);
        return 0;
    }
    strm.next_in = (Bytef *)data;
    strm.avail_in = (uInt)n;
    strm.next_out = out;
    strm.avail_out = (uInt)bound;
    int rc = deflate(&strm, Z_FINISH);
    size_t len = (rc == Z_STREAM_END) ? (size_t)strm.total_out : 0;
    deflateEnd(&strm);
    free(out);
    return len;
}

#ifdef HAS_ZSTD
static size_t zstd_size(const uint8_t *data, size_t n) {
    if (!data || n == 0) return 0;
    size_t bound = ZSTD_compressBound(n);
    void *out = malloc(bound);
    if (!out) return 0;
    size_t got = ZSTD_compress(out, bound, data, n, 3);
    free(out);
    return ZSTD_isError(got) ? 0 : got;
}
#endif

void bench_compress_sizes(const uint8_t *data, size_t n, size_t *out_gzip, size_t *out_zstd) {
    if (out_gzip) *out_gzip = gzip_size(data, n);
#ifdef HAS_ZSTD
    if (out_zstd) *out_zstd = zstd_size(data, n);
#else
    if (out_zstd) *out_zstd = 0;
#endif
}
