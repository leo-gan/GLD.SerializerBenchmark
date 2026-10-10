/* Untimed payload sizes. gzip level 6 matches the C runner. zstd level 3
 * when the headers are present at build time. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#ifdef HAS_ZSTD
#include <zstd.h>
#endif

static size_t gzip_size(const uint8_t *data, size_t n) {
    z_stream strm;
    uLong bound;
    uint8_t *out;
    int rc;
    size_t len;
    if (!data || n == 0) return 0;
    memset(&strm, 0, sizeof strm);
    if (deflateInit2(&strm, 6, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY) != Z_OK)
        return 0;
    bound = compressBound((uLong)n) + 32;
    out = (uint8_t *)malloc(bound);
    if (!out) {
        deflateEnd(&strm);
        return 0;
    }
    strm.next_in = (Bytef *)data;
    strm.avail_in = (uInt)n;
    strm.next_out = out;
    strm.avail_out = (uInt)bound;
    rc = deflate(&strm, Z_FINISH);
    len = (rc == Z_STREAM_END) ? (size_t)strm.total_out : 0;
    deflateEnd(&strm);
    free(out);
    return len;
}

void bench_compress_sizes(const uint8_t *data, size_t n, size_t *out_gzip, size_t *out_zstd) {
    if (out_gzip) *out_gzip = gzip_size(data, n);
#ifdef HAS_ZSTD
    if (out_zstd) {
        size_t bound = ZSTD_compressBound(n);
        void *out = malloc(bound);
        size_t got = out ? ZSTD_compress(out, bound, data, n, 3) : 0;
        free(out);
        *out_zstd = (out && !ZSTD_isError(got)) ? got : 0;
    }
#else
    if (out_zstd) *out_zstd = 0;
#endif
}
