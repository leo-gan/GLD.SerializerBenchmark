/* Separate translation unit so gfortran cannot delete a timed result. */
#include <stddef.h>
#include <stdint.h>

static volatile unsigned char sink;

void black_box_bytes(const void *p, size_t n) {
    const unsigned char *b = (const unsigned char *)p;
    unsigned char x = 0;
    if (p && n > 0) {
        x = b[0];
        x = (unsigned char)(x + b[n - 1]);
    }
    sink = x;
}
