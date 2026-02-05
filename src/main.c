#include <stdio.h>
#include <stdlib.h>

extern int parse(FILE *in, FILE *out);
extern void lex(FILE *in, FILE *out);
extern void validate(FILE *in, FILE *out);

int main(void) {
    int result = parse(stdin, stdout);
    lex(stdin, stdout);
    validate(stdin, stdout);
    
    if (result == 0) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}
