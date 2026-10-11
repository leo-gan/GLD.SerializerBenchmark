/* Official HDF5 C API on the array data set.
 * Core virtual file driver. The byte size is the flushed file image.
 * Dataset shape is (nx, ny), C-order, index x * ny + y.
 * grid_window reads that rectangle with H5Sselect_hyperslab. */
#include "ser_common.h"
#include <hdf5.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_nx, g_ny, g_x0, g_y0, g_wx, g_wy;
static int g_window;

static bool supports_grid(test_data_kind_t kind) {
    return kind == TD_GRID || kind == TD_GRID_WINDOW;
}

static void values_to_xy(const double *values, int nx, int ny, double *xy) {
    for (int y = 0; y < ny; y++) {
        for (int x = 0; x < nx; x++)
            xy[(size_t)x * (size_t)ny + (size_t)y] = values[(size_t)y * (size_t)nx + (size_t)x];
    }
}

static void xy_to_values(const double *xy, int nx, int ny, double *values) {
    for (int y = 0; y < ny; y++) {
        for (int x = 0; x < nx; x++)
            values[(size_t)y * (size_t)nx + (size_t)x] = xy[(size_t)x * (size_t)ny + (size_t)y];
    }
}

static int prep(test_data_kind_t kind, const test_fixture_t *fx) {
    if (!supports_grid(kind) || !fx || !fx->grid.values) return -1;
    g_nx = fx->grid.nx;
    g_ny = fx->grid.ny;
    g_x0 = fx->grid.x0;
    g_y0 = fx->grid.y0;
    g_wx = fx->grid.wx;
    g_wy = fx->grid.wy;
    g_window = kind == TD_GRID_WINDOW;
    return 0;
}

static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *out_len) {
    const grid_t *g = &fx->grid;
    size_t n = (size_t)g->nx * (size_t)g->ny;
    double *xy = (double *)malloc(n * sizeof(double));
    hid_t fapl = H5I_INVALID_HID;
    hid_t file = H5I_INVALID_HID;
    hid_t space = H5I_INVALID_HID;
    hid_t dset = H5I_INVALID_HID;
    hsize_t dims[2];
    ssize_t image = 0;
    int rc = -1;
    if (!xy) return -1;
    values_to_xy(g->values, g->nx, g->ny, xy);
    dims[0] = (hsize_t)g->nx;
    dims[1] = (hsize_t)g->ny;
    fapl = H5Pcreate(H5P_FILE_ACCESS);
    if (fapl < 0) goto done;
    if (H5Pset_fapl_core(fapl, 4 * 1024 * 1024, 0) < 0) goto done;
    file = H5Fcreate("gld.h5", H5F_ACC_TRUNC, H5P_DEFAULT, fapl);
    if (file < 0) goto done;
    space = H5Screate_simple(2, dims, NULL);
    if (space < 0) goto done;
    dset = H5Dcreate2(file, "grid", H5T_NATIVE_DOUBLE, space, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    if (dset < 0) goto done;
    if (H5Dwrite(dset, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, xy) < 0) goto done;
    if (H5Fflush(file, H5F_SCOPE_LOCAL) < 0) goto done;
    image = H5Fget_file_image(file, NULL, 0);
    if (image <= 0 || (size_t)image > cap) goto done;
    if (H5Fget_file_image(file, buf, (size_t)image) < 0) goto done;
    *out_len = (size_t)image;
    rc = 0;
done:
    if (dset >= 0) H5Dclose(dset);
    if (space >= 0) H5Sclose(space);
    if (file >= 0) H5Fclose(file);
    if (fapl >= 0) H5Pclose(fapl);
    free(xy);
    return rc;
}

static int de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind) {
    hid_t fapl = H5I_INVALID_HID;
    hid_t file = H5I_INVALID_HID;
    hid_t dset = H5I_INVALID_HID;
    hid_t space = H5I_INVALID_HID;
    hid_t mem = H5I_INVALID_HID;
    int nx = g_nx;
    int ny = g_ny;
    int read_nx = g_window ? g_wx : nx;
    int read_ny = g_window ? g_wy : ny;
    size_t nread;
    double *xy = NULL;
    double *values = NULL;
    hsize_t start[2], count[2], mdims[2];
    int rc = -1;
    (void)kind;
    if (nx <= 0 || ny <= 0 || read_nx <= 0 || read_ny <= 0) return -1;
    nread = (size_t)read_nx * (size_t)read_ny;
    xy = (double *)malloc(nread * sizeof(double));
    values = (double *)malloc(nread * sizeof(double));
    if (!xy || !values) goto done;
    fapl = H5Pcreate(H5P_FILE_ACCESS);
    if (fapl < 0) goto done;
    if (H5Pset_fapl_core(fapl, 0, 0) < 0) goto done;
    if (H5Pset_file_image(fapl, (void *)buf, len) < 0) goto done;
    file = H5Fopen("gld.h5", H5F_ACC_RDONLY, fapl);
    if (file < 0) goto done;
    dset = H5Dopen2(file, "grid", H5P_DEFAULT);
    if (dset < 0) goto done;
    if (g_window) {
        space = H5Dget_space(dset);
        if (space < 0) goto done;
        start[0] = (hsize_t)g_x0;
        start[1] = (hsize_t)g_y0;
        count[0] = (hsize_t)g_wx;
        count[1] = (hsize_t)g_wy;
        if (H5Sselect_hyperslab(space, H5S_SELECT_SET, start, NULL, count, NULL) < 0) goto done;
        mdims[0] = count[0];
        mdims[1] = count[1];
        mem = H5Screate_simple(2, mdims, NULL);
        if (mem < 0) goto done;
        if (H5Dread(dset, H5T_NATIVE_DOUBLE, mem, space, H5P_DEFAULT, xy) < 0) goto done;
        xy_to_values(xy, read_nx, read_ny, values);
    } else {
        if (H5Dread(dset, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, xy) < 0) goto done;
        xy_to_values(xy, nx, ny, values);
    }
    data_free_grid(out);
    memset(out, 0, sizeof(*out));
    out->kind = kind;
    out->grid.nx = read_nx;
    out->grid.ny = read_ny;
    out->grid.nvalues = (int)nread;
    out->grid.values = values;
    values = NULL;
    rc = 0;
done:
    if (mem >= 0) H5Sclose(mem);
    if (space >= 0) H5Sclose(space);
    if (dset >= 0) H5Dclose(dset);
    if (file >= 0) H5Fclose(file);
    if (fapl >= 0) H5Pclose(fapl);
    free(xy);
    free(values);
    return rc;
}

static bool fid(const test_fixture_t *a, const test_fixture_t *b) {
    const grid_t *src = &a->grid;
    const grid_t *got = &b->grid;
    if (!src->values || !got->values) return false;
    if (a->kind == TD_GRID_WINDOW) {
        int expect = src->wx * src->wy;
        int i = 0;
        if (got->nvalues != expect) return false;
        for (int y = src->y0; y < src->y0 + src->wy; y++) {
            for (int x = src->x0; x < src->x0 + src->wx; x++) {
                double want = src->values[(size_t)y * (size_t)src->nx + (size_t)x];
                if (got->values[i] != want) return false;
                i++;
            }
        }
        return true;
    }
    if (got->nvalues != src->nx * src->ny) return false;
    return memcmp(src->values, got->values, (size_t)got->nvalues * sizeof(double)) == 0;
}

static const char *hdf5_version(void) {
    static char text[32];
    unsigned maj = 0, min = 0, rel = 0;
    if (text[0]) return text;
    H5get_libversion(&maj, &min, &rel);
    snprintf(text, sizeof text, "%u.%u.%u", maj, min, rel);
    return text;
}

void bench_register_hdf5(serializer_t *o, int *c) {
    BENCH_ADD(o, c, "hdf5", hdf5_version(), "binary", prep, ser, de, fid);
    o[*c - 1].supports = supports_grid;
}
