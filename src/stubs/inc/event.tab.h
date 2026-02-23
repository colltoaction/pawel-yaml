#ifndef EVENT_TAB_H
#define EVENT_TAB_H

#include "event_tokens.h"

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
