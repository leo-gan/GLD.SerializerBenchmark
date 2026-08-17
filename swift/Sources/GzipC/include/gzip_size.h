#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One-shot gzip(6) length of already-written bytes. 0 on empty input or error. */
size_t bench_gzip_size(const uint8_t *data, size_t n);

#ifdef __cplusplus
}
#endif
