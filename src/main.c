#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml.tab.h"
#include "rml.tab.h"

/**
 * Three-Stage Parser Pipeline
 * 
 * Stage 1: YAML Presentation (yaml.y/yaml.l)
 * - Input: Raw YAML text
 * - Output: Tokens/AST
 * 
 * Stage 2: YAML Events (yaml_event.y/yaml_event.l)
 * - Input: YAML tokens
 * - Output: Canonical event stream (+STR, -STR, =VAL, etc.)
 * 
 * Stage 3: RML Monoidal (rml.y/rml.l)
 * - Input: Event stream
 * - Output: Validation result + IR
 */

/* Globals for IR exchange between stages */
char *rml_ir_buf = NULL;
size_t rml_ir_size = 0;

/* External lexer/parser functions - Stage 1 (YAML Presentation) */
int yaml_lex_init(void **scanner);
int yaml_lex_destroy(void *scanner);
void yaml_set_in(FILE *in, void *scanner);
int yaml_parse(void *scanner);

/* External lexer/parser functions - Stage 3 (RML Validation) */
/* Temporarily disabled - grammar in rml.y, wrapper in rml_parser.c */
/* Will be integrated when rml_parse_event_stream is wired to main */

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    void *y_scanner;
    
    /* Stage 1: YAML Presentation Layer */
    /* Parses YAML text into token stream */
    yaml_lex_init(&y_scanner);
    yaml_set_in(stdin, y_scanner);
    if (yaml_parse(y_scanner) != 0) {
        yaml_lex_destroy(y_scanner);
        return 1;
    }
    yaml_lex_destroy(y_scanner);

    if (!rml_ir_buf) return 0;

    /* Stage 2: YAML Events Layer */
    /* TODO: Process rml_ir_buf through yaml_event parser */
    /* This will generate canonical event stream */

    /* Stage 3: RML Monoidal Layer */
    /* TODO: Call rml_parse_event_stream(event_stream) via wrapper */
    /* Grammar validation via rml.y rules, enforced in rml_parser.c */
    
    free(rml_ir_buf);
    
    return 0;
}

