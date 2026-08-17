#include "gzip_size.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

size_t bench_gzip_size(const uint8_t *data, size_t n) {
    if (!data || n == 0) return 0;
    z_stream strm;
    memset(&strm, 0, sizeof strm);
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
