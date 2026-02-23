#include "lexer_values.h"
#include <stdlib.h>

YYSTYPE val_str(char *s) {
    YYSTYPE val;
    val.string = s;
    return val;
}

YYSTYPE val_int(int i) {
    YYSTYPE val;
    val.ival = i;
    return val;
}

YYSTYPE val_empty(void) {
    YYSTYPE val;
    val.string = NULL;
    /* val.ival = 0; union overlap */
    return val;
}
