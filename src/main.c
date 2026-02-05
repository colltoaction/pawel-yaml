#include <stdio.h>

extern void parse(FILE *in, FILE *out);
extern void lex(FILE *in, FILE *out);
extern void validate(FILE *in, FILE *out);

void main(void) {
    parse(stdin, stdout);
    lex(stdin, stdout);
    validate(stdin, stdout);
}
