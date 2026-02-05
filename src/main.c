#include <stdio.h>
#include "pipeline.h"

int main(void) {
    parse(stdin, stdout);
    lex(stdin, stdout);
    validate(stdin, stdout);
    return 0;
}
