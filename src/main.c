#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml.tab.h"
#include "rml.tab.h"

/* Globals for IR exchange */
char *rml_ir_buf = NULL;
size_t rml_ir_size = 0;

/* External lexer/parser functions */
int yaml_lex_init(void **scanner);
int yaml_lex_destroy(void *scanner);
void yaml_set_in(FILE *in, void *scanner);
int yaml_parse(void *scanner);

int rml_lex_init(void **scanner);
int rml_lex_destroy(void *scanner);
typedef struct yy_buffer_state *YY_BUFFER_STATE;
YY_BUFFER_STATE rml__scan_string(const char *str, void *scanner);
int rml_parse(void *scanner);

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    void *y_scanner;
    
    /* Stage 1: YAML to Monoidal IR */
    yaml_lex_init(&y_scanner);
    yaml_set_in(stdin, y_scanner);
    if (yaml_parse(y_scanner) != 0) {
        yaml_lex_destroy(y_scanner);
        return 1;
    }
    yaml_lex_destroy(y_scanner);

    if (!rml_ir_buf) return 0;

    /* Stage 2: Monoidal IR to Canonical Events */
    void *r_scanner;
    rml_lex_init(&r_scanner);
    rml__scan_string(rml_ir_buf, r_scanner);
    int result = rml_parse(r_scanner);
    
    rml_lex_destroy(r_scanner);
    free(rml_ir_buf);
    
    return result;
}
