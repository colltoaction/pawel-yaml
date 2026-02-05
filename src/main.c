#include <stdio.h>
#include <stdlib.h>
#include "pipeline.h"

extern int parse(FILE *in, FILE *out);
extern int lex(FILE *in, FILE *out);
extern int validate(FILE *in, FILE *out);

int main(void) {
    int parse_result = parse(stdin, stdout);
    int lex_result = lex(stdin, stdout);
    int validate_result = validate(stdin, stdout);
    
    /* Return success only if all stages succeed (Bison-style: 0 = success) */
    if (parse_result == PARSER_SUCCESS && lex_result == PARSER_SUCCESS && validate_result == PARSER_SUCCESS) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}
