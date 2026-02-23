#ifndef STREAM_TAB_H
#define STREAM_TAB_H

#include "common.h"
#include "lexer_context.h"
#include "stream_tokens.h"

typedef void * YYSTYPE;

typedef struct YYLTYPE {
    int first_line;
    int first_column;
    int last_line;
    int last_column;
} YYLTYPE;

typedef YYSTYPE STREAM_YY_STYPE;
typedef YYLTYPE STREAM_YY_LTYPE;

#define STREAM_YY_STYPE_IS_DECLARED 1
#define STREAM_YY_STYPE_IS_TRIVIAL 1
#define STREAM_YY_STYPE_IS_POINTER 1

#endif
