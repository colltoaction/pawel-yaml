#ifndef LEXER_CORE_H
#define LEXER_CORE_H

#include "lexer_values.h"

/* Common Macros for Actions */

#define SET_FLOW_CTX(state) flow_key_state_set(CTX, state)
#define RESET_LINE() do { CTX->at_line_start = 0; CTX->expecting_value = 0; } while(0)

#define EMIT_RAW(token) do { \
    RESET_LINE(); \
    if (FLOW_DELIM_SP > 0) SET_FLOW_CTX(FLOW_KEY_CANDIDATE); \
    BEGIN(PLAIN_SCALAR_CONT); \
    *yylval = val_str(strdup(yytext)); \
    return token; \
} while(0)

#define EMIT_SCALAR(type_char) do { \
    RESET_LINE(); \
    *yylval = val_str(strdup(yytext)); /* In real impl, handle type/processing */ \
    return SCALAR; /* Or generic token */ \
} while(0)

/* Helper for anchor/tag/key composition */
static int compose_complex_key(YYSTYPE *val, const char *text, int has_anchor, int has_tag, int quoted) {
    /* Implementation of extraction logic */
    *val = val_str(strdup(text)); /* simplified for stub/demo */
    return ANCHOR_MAP_KEY;
}

#endif
