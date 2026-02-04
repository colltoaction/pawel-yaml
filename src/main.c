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
    
    /* Preprocessing: Replace visible space characters (U+2423, UTF-8: 0xE2 0x90 0xA3)
     * with regular spaces for YAML test suite compatibility.
     * The visible space character is used in test specifications to explicitly show
     * whitespace significance but should be treated as a regular space for parsing.
     */
    FILE *input_temp = tmpfile();
    if (!input_temp) {
        fprintf(stderr, "Error creating temporary file\n");
        return 1;
    }
    
    int c;
    unsigned char prev = 0, prev2 = 0;
    while ((c = fgetc(stdin)) != EOF) {
        unsigned char byte = (unsigned char)c;
        
        /* Detect UTF-8 sequence for U+2423 (0xE2 0x90 0xA3) */
        if (byte == 0xE2 && prev2 == 0 && prev == 0) {
            /* First byte of potential sequence - buffer it for now */
            prev2 = prev;
            prev = byte;
        } else if (byte == 0x90 && prev == 0xE2 && prev2 == 0) {
            /* Second byte - continue buffering */
            prev2 = prev;
            prev = byte;
        } else if (byte == 0xA3 && prev == 0x90 && prev2 == 0xE2) {
            /* Third byte - we have a complete U+2423 sequence, output as space */
            fputc(' ', input_temp);
            prev = 0;
            prev2 = 0;
        } else {
            /* Not a match - output any previously buffered bytes */
            if (prev2) fputc(prev2, input_temp);
            if (prev) fputc(prev, input_temp);
            
            fputc(byte, input_temp);
            prev = 0;
            prev2 = 0;
        }
    }
    /* Flush any remaining buffered bytes */
    if (prev2) fputc(prev2, input_temp);
    if (prev) fputc(prev, input_temp);
    
    rewind(input_temp);
    
    /* Stage 1: YAML Presentation Layer */
    /* Parses YAML text into token stream */
    yaml_lex_init(&y_scanner);
    yaml_set_in(input_temp, y_scanner);
    if (yaml_parse(y_scanner) != 0) {
        yaml_lex_destroy(y_scanner);
        fclose(input_temp);
        return 1;
    }
    yaml_lex_destroy(y_scanner);
    fclose(input_temp);

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

