#ifndef COMMON_TOKENS_H
#define COMMON_TOKENS_H

#include "common.h"
#include "lexer_context.h"

typedef union {
    char *string;
    int ival;
    NodeProps props;
    ScalarValue scalar;
} YYSTYPE;

typedef struct YYLTYPE {
    int first_line;
    int first_column;
    int last_line;
    int last_column;
} YYLTYPE;

enum yytokentype {
    SCALAR = 258,
    BSCALAR,
    QSCALAR,
    SSCALAR,
    TAG,
    ANCHOR,
    ALIAS,
    MAP_KEY,
    ANCHOR_MAP_KEY,
    QPART,
    BPART,
    BAD_TAG,
    CH_RAW,
    CH_ESC_N,
    CH_ESC_T,
    CH_ESC_R,
    CH_ESC_0,
    CH_ESC_BS,
    CH_ESC_QU,
    CH_ESC_SL,
    YAML_DIRECTIVE,
    TAG_DIRECTIVE,
    DOC_START,
    DOC_END,
    BULLET,
    BULLET_EOL,
    COLON,
    COLON_EMPTY,
    COLON_IMPLICIT,
    QUESTION,
    INDENT,
    DEDENT,
    LBRACK,
    RBRACK,
    LBRACE,
    RBRACE,
    COMMA
};

#endif
