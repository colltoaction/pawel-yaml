#include <stdio.h>
#include <stdlib.h>

/* Bison parser entry points */
extern int stream_yy_parse(void *scanner);
extern int event_yy_parse(void);

/* Flex lexer initialization and input management */
extern int presentation_lex_init(void **scanner);
extern int presentation_lex_destroy(void *scanner);
extern void presentation_set_in(FILE *in_str, void *scanner);

/* Error handler for Bison parser */
void stream_yy_error(void *yylloc, void *scanner, const char *msg) {
    fprintf(stderr, "Parse error: %s\n", msg);
}

/* Global state for pipeline stages */
static int stage1_complete = 0;
static int stage2_complete = 0;
static int stage3_complete = 0;

/**
 * Stage 1: Parse - Presentation -> Serialization
 * Reads YAML text from stdin, produces event stream
 */
int yaml_parse(void) {
    void *scanner;
    if (presentation_lex_init(&scanner) != 0) {
        fprintf(stderr, "Failed to initialize lexer\n");
        return 1;
    }
    presentation_set_in(stdin, scanner);
    int result = stream_yy_parse(scanner);
    presentation_lex_destroy(scanner);
    if (result != 0) return 1;
    stage1_complete = 1;
    return 0;
}

/**
 * Stage 2: Compose - Serialization -> Representation
 * Composes IR (data structures) from event stream
 */
int yaml_compose(void) {
    if (stage1_complete == 0) return 1;  /* Requires stage 1 */
    if (event_yy_parse() != 0) return 1;
    stage2_complete = 1;
    return 0;
}

/**
 * Stage 3: Serialize - Representation -> Serialization
 * Creates event stream from IR (inverse of compose)
 */
int yaml_serialize(void) {
    if (stage2_complete == 0) return 1;  /* Requires stage 2 */
    /* For now, pass through - full serialization to be implemented */
    stage3_complete = 1;
    return 0;
}

/**
 * Stage 4: Present - Serialization -> Presentation
 * Renders event stream back to YAML text
 */
int yaml_present(void) {
    if (stage3_complete == 0) return 1;  /* Requires stage 3 */
    /* For now, pass through - full presentation to be implemented */
    return 0;
}
