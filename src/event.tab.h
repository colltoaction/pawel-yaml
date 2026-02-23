#ifndef EVENT_TAB_H
#define EVENT_TAB_H

#include "common.h"

enum {
    STR = 258,
    DOC,
    SEQ,
    MAP,
    VAL,
    ALI,
    E_ANCHOR,
    E_TAG,
    E_DOC_EXPLICIT,
    E_DOC_END_EXPLICIT,
    E_QUOTED_STRING,
    E_IDENTIFIER,
    FLOW_SEQ_MARKER,
    FLOW_MAP_MARKER,
    E_STYLE
};

extern int event_yy_lval;

/**
 * Validation result after RML parsing
 */
typedef struct {
    int is_valid;
    char *error_message;
    int error_line;
    char *intermediate_representation;
} ValidationResult;

/* Stage 3 API */
EventStream* event_parse_string(const char *input);
void event_stream_free(EventStream *stream);
ValidationResult* rml_parse_event_stream(const EventStream *stream);
int event_yy_parse(void);

#endif
