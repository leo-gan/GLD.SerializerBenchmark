#include "optional_io.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_OPT 64
#define MAX_NAME 128

static char names[MAX_OPT][MAX_NAME];
static int name_count = -1;

static int find_file(char *out, size_t n) {
    char cwd[1024];
    if (!getcwd(cwd, sizeof cwd)) return 0;
    char dir[1024];
    snprintf(dir, sizeof dir, "%s", cwd);
    for (;;) {
        snprintf(out, n, "%s/config/optional-io.txt", dir);
        if (access(out, R_OK) == 0) return 1;
        char *slash = strrchr(dir, '/');
        if (!slash || slash == dir) return 0;
        *slash = 0;
    }
}

static void load_names(void) {
    name_count = 0;
    char path[1200];
    if (!find_file(path, sizeof path)) return;
    FILE *f = fopen(path, "r");
    if (!f) return;
    char line[256];
    while (fgets(line, sizeof line, f)) {
        char *tab = strchr(line, '\t');
        if (!tab) continue;
        *tab = 0;
        if (strcmp(line, "c") != 0) continue;
        char *name = tab + 1;
        size_t len = strlen(name);
        while (len && (name[len - 1] == '\n' || name[len - 1] == '\r')) name[--len] = 0;
        if (!len || name_count >= MAX_OPT) continue;
        snprintf(names[name_count], MAX_NAME, "%s", name);
        name_count++;
    }
    fclose(f);
}

int bench_optional_stream(const char *language, const char *name) {
    (void)language;
    if (name_count < 0) load_names();
    if (!name) return 0;
    for (int i = 0; i < name_count; i++) {
        if (strcmp(names[i], name) == 0) return 1;
    }
    return 0;
}
