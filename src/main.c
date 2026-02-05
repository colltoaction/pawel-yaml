#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lexer_context.h"

/* Bison parser entry points */
extern int stream_yy_parse(void *scanner);
extern int event_yy_parse(void);

/* Flex lexer initialization and input management */
extern int presentation_lex_init_extra(LexerContext *user_defined, void **scanner);
extern int presentation_lex_destroy(void *scanner);
extern void presentation_set_in(FILE *in_str, void *scanner);

/**
 * Stage 1: Parse - Presentation -> Serialization
 * Reads YAML text from stdin, produces event stream
 */
static int yaml_parse(void) {
    void *scanner;
    LexerContext *ctx = lexer_context_new();
    if (!ctx) {
        fprintf(stderr, "Failed to create lexer context\n");
        return 1;
    }
    
    if (presentation_lex_init_extra(ctx, &scanner) != 0) {
        fprintf(stderr, "Failed to initialize lexer\n");
        return 1;
    }
    presentation_set_in(stdin, scanner);
    int result = stream_yy_parse(scanner);
    presentation_lex_destroy(scanner);
    if (result != 0) return 1;
    return 0;
}

/**
 * Stage 2: Compose - Serialization -> Representation
 * Composes IR (data structures) from event stream
 */
static int yaml_compose(void) {
    if (event_yy_parse() != 0) return 1;
    return 0;
}

/**
 * Stage 3: Serialize - Representation -> Serialization
 * Creates event stream from IR (inverse of compose)
 */
static int yaml_serialize(void) {
    /* For now, pass through - full serialization to be implemented */
    return 0;
}

/**
 * Stage 4: Present - Serialization -> Presentation
 * Renders event stream back to YAML text
 */
static int yaml_present(void) {
    /* For now, pass through - full presentation to be implemented */
    return 0;
}

/* YAML Compilation Pipeline with intermediate steps */
int main(int argc, char **argv) {
    if (yaml_parse() != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "-dump-tokens") == 0) return 0;

    if (yaml_compose() != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "-ast-dump") == 0) return 0;

    if (yaml_serialize() != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "-emit-yaml") == 0) return 0;

    return yaml_present();
}
