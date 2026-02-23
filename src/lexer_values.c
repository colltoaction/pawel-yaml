#include "lexer_values.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

LexerValue val_str(char *s) {
#ifdef STREAM_YY_STYPE_IS_POINTER
    return s;
#else
    LexerValue value;
    memset(&value, 0, sizeof(value));
    value.string = s;
    return value;
#endif
}

LexerValue val_int(int i) {
#ifdef STREAM_YY_STYPE_IS_POINTER
    return (LexerValue)(intptr_t)i;
#else
    LexerValue value;
    memset(&value, 0, sizeof(value));
    value.ival = i;
    return value;
#endif
}

LexerValue val_empty(void) {
#ifdef STREAM_YY_STYPE_IS_POINTER
    return NULL;
#else
    LexerValue value;
    memset(&value, 0, sizeof(value));
    return value;
#endif
}
