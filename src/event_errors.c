#include <stdio.h>

void event_yy_error(const char *msg) {
    fprintf(stderr, "[EVENT] Error: %s\n", msg ? msg : "syntax error");
}
