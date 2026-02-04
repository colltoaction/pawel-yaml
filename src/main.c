#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml.tab.h"
#include "yaml_event_parser.h"
#include "rml_parser.h"

/**
 * Three-Stage Parser Pipeline (Grammar-Native)
 * 
 * Stage 1: YAML Presentation (yaml.y/yaml.l)
 * - Input: Raw YAML text
 * - Output: Tokens/AST
 * 
 * Stage 2: YAML Events (yaml_event.y/yaml_event.l)
 * - Input: YAML tokens or event stream strings
 * - Output: Canonical event stream (+STR, -STR, =VAL, etc.)
 * 
 * Stage 3: RML Monoidal (rml.y/rml.l)
 * - Input: Event stream
 * - Output: Validation result + IR
 * 
 * NOTE: All C logic has been moved into grammar files.
 * main.c only orchestrates the three pipeline stages.
 */

/* Globals for IR exchange between stages */
char *rml_ir_buf = NULL;
size_t rml_ir_size = 0;

/* External lexer/parser functions - Stage 1 (YAML Presentation) */
int yaml_lex_init(void **scanner);
int yaml_lex_destroy(void *scanner);
void yaml_set_in(FILE *in, void *scanner);
int yaml_parse(void *scanner);

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
    /* Parse event stream string through yaml_event grammar */
    yaml_event_parser_init();
    EventStream *events = yaml_event_parse_string(rml_ir_buf);
    yaml_event_parser_cleanup();
    
    if (!events) {
        free(rml_ir_buf);
        return 1;
    }

    /* Stage 3: RML Monoidal Layer */
    /* Validate event stream through rml grammar rules */
    ValidationResult *result = rml_parse_event_stream(events);
    
    if (result && result->is_valid) {
        if (result->intermediate_representation) {
            printf("%s", result->intermediate_representation);
        }
    } else if (result) {
        fprintf(stderr, "Validation error: %s\n", result->error_message);
    }
    
    event_stream_free(events);
    validation_result_free(result);
    free(rml_ir_buf);
    
    return 0;
}

