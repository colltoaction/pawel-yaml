#ifndef EVENT_TOKENS_H
#define EVENT_TOKENS_H

#include "common.h"

enum {
    /* Event Structure Tokens */
    STR = 258,
    DOC,
    SEQ,
    MAP,

    /* Event Data Tokens */
    VAL,
    ALI,

    /* Event Attribute Tokens */
    E_ANCHOR,
    E_TAG,
    E_STYLE,

    /* Document Markers */
    E_DOC_EXPLICIT,
    E_DOC_END_EXPLICIT,

    /* Flow Markers */
    FLOW_SEQ_MARKER,
    FLOW_MAP_MARKER,

    /* Content Tokens */
    E_QUOTED_STRING,
    E_IDENTIFIER
};

#endif
