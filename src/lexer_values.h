#ifndef LEXER_VALUES_H
#define LEXER_VALUES_H

#include "common.h"
#include "stream.tab.h" /* For YYSTYPE definition */

/* Constructor for string-based tokens */
/* Takes ownership of the string if it was allocated, or duplicates if needed (but currently we are avoiding allocs) */
/* Ideally this should return YYSTYPE by value */
YYSTYPE val_str(char *s);

/* Constructor for integer-based tokens (indent/dedent) */
YYSTYPE val_int(int i);

/* Constructor for empty/null values */
YYSTYPE val_empty(void);

#endif
