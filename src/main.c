#include <stdio.h>
#include <stdlib.h>

extern int parse(FILE *in, FILE *out);
extern int lex(FILE *in, FILE *out);
extern int validate(FILE *in, FILE *out);

int main(void) {
    int parse_result = parse(stdin, stdout);
    int lex_result = lex(stdin, stdout);
    int validate_result = validate(stdin, stdout);
    
    /* Return success only if all stages succeed (Bison: 0 = YYACCEPT) */
    if (parse_result == 0 && lex_result == 0 && validate_result == 0) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}
