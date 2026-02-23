#include "lexer_values.h"
#include <stdlib.h>
#include <stdint.h>

YYSTYPE val_str(char *s) {
    return (YYSTYPE)s;
}

YYSTYPE val_int(int i) {
    return (YYSTYPE)(intptr_t)i;
}

YYSTYPE val_empty(void) {
    return NULL;
}
