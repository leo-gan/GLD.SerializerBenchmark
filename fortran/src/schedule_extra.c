/* Thin queries over c/src/schedule.c. The hash stays in that file so the
 * golden vector cannot drift from the C runner. */
#include "schedule.h"

#include <string.h>

int fsched_is_none(void) {
    const char *s = schedule_resolve_strategy();
    return (s && strcmp(s, "none") == 0) ? 1 : 0;
}

int fsched_record_run_order(void) {
    return schedule_resolve_record_run_order();
}
