#ifndef LEXER_VALUES_H
#define LEXER_VALUES_H

#include "common.h"
#include "stream.tab.h"

/* Use the parser semantic type selected by stream.tab.h. */
typedef STREAM_YY_STYPE LexerValue;

/* Constructor for string-based tokens */
LexerValue val_str(char *s);

/* Constructor for integer-based tokens (indent/dedent) */
LexerValue val_int(int i);

/* Constructor for empty/null values */
LexerValue val_empty(void);

#endif
