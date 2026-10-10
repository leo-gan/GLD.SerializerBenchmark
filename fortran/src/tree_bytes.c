/* Directory size and cleanup for file-only engines (ADIOS2 BP5). */
#define _GNU_SOURCE
#include <dirent.h>
#include <ftw.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int64_t gld_total;

static int gld_sum_fn(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf) {
    (void)fpath;
    (void)ftwbuf;
    if (typeflag == FTW_F) gld_total += (int64_t)sb->st_size;
    return 0;
}

int64_t gld_tree_bytes(const char *path) {
    gld_total = 0;
    if (path == NULL || path[0] == '\0') return -1;
    if (nftw(path, gld_sum_fn, 16, FTW_PHYS) != 0) return -1;
    return gld_total;
}

static int gld_rm_fn(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf) {
    (void)sb;
    (void)ftwbuf;
    if (typeflag == FTW_DP) {
        if (rmdir(fpath) != 0) return -1;
    } else if (unlink(fpath) != 0) {
        return -1;
    }
    return 0;
}

int gld_rm_rf(const char *path) {
    struct stat st;
    if (path == NULL || path[0] == '\0') return 0;
    if (lstat(path, &st) != 0) return 0;
    return nftw(path, gld_rm_fn, 16, FTW_DEPTH | FTW_PHYS);
}

enum { GLD_MAX_FILES = 64, GLD_MAX_PATH = 512 };

static char gld_paths[GLD_MAX_FILES][GLD_MAX_PATH];
static int gld_npaths;

static int gld_collect_fn(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf) {
    (void)sb;
    (void)ftwbuf;
    if (typeflag != FTW_F) return 0;
    if (gld_npaths >= GLD_MAX_FILES) return 0;
    snprintf(gld_paths[gld_npaths], GLD_MAX_PATH, "%s", fpath);
    gld_npaths++;
    return 0;
}

static int gld_path_cmp(const void *a, const void *b) {
    return strcmp((const char *)a, (const char *)b);
}

int gld_tree_slurp(const char *path, uint8_t *buf, int cap) {
    int i, filled = 0;
    if (path == NULL || buf == NULL || cap <= 0) return 0;
    gld_npaths = 0;
    if (nftw(path, gld_collect_fn, 16, FTW_PHYS) != 0) return 0;
    qsort(gld_paths, (size_t)gld_npaths, GLD_MAX_PATH, gld_path_cmp);
    for (i = 0; i < gld_npaths && filled < cap; i++) {
        FILE *f = fopen(gld_paths[i], "rb");
        if (f == NULL) continue;
        filled += (int)fread(buf + filled, 1, (size_t)(cap - filled), f);
        fclose(f);
    }
    return filled;
}
