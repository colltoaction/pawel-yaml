#include <stdio.h>
#include <stdlib.h>

/* Bison parser entry points */
extern int stream_yy_parse(void *scanner);
extern int event_yy_parse(void);

/* Error handler for Bison parser */
void stream_yy_error(void *yylloc, void *scanner, const char *msg) {
    fprintf(stderr, "Parse error: %s\n", msg);
}

/**
 * Stage 1: Presentation -> Events
 * Reads YAML from stdin, produces event stream
 */
int stream_parse(void) {
    /* Use global lexer state initialized by presentation.l */
    return stream_yy_parse(NULL);
}

/**
 * Stage 2: Events -> Representation (IR)
 * Composes IR from event stream
 */
int compose_events(void) {
    return event_yy_parse();
}
