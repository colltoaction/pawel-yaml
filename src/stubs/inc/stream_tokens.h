#ifndef STREAM_TOKENS_H
#define STREAM_TOKENS_H

enum {
    /* Stream Structure Tokens */
    INDENT = 258,
    DEDENT,
    DOC_START,
    DOC_END,

    /* Directives */
    YAML_DIRECTIVE,
    TAG_DIRECTIVE,

    /* Block Structure Tokens */
    BULLET,
    BULLET_EOL,
    COLON,
    COLON_EMPTY,
    COLON_IMPLICIT,
    QUESTION,

    /* Flow Structure Tokens */
    LBRACK,
    RBRACK,
    LBRACE,
    RBRACE,
    COMMA,

    /* Data Tokens */
    SCALAR,
    BSCALAR,
    QSCALAR,
    SSCALAR,
    TAG,
    ANCHOR,
    ALIAS,
    MAP_KEY,
    ANCHOR_MAP_KEY,
    BAD_TAG,

    /* Scalar Parts (Low Level) */
    CH_RAW,
    CH_ESC_N,
    CH_ESC_T,
    CH_ESC_R,
    CH_ESC_0,
    CH_ESC_BS,
    CH_ESC_QU,
    CH_ESC_SL,
    QPART,
    BPART
};

#endif
