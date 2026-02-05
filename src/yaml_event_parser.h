/**
 * yaml_event_parser.h - YAML Event Stream & RML Validation
 */

#ifndef YAML_EVENT_PARSER_H
#define YAML_EVENT_PARSER_H

#include <stdio.h>
#include "common.h"

/* YAMLEventType mapping */
typedef YAMLEventType_t YAMLEventType;

typedef struct {
    YAMLEventType type;
    char quote_style;
    char *value;
    char *anchor;
    char *tag;
    int explicit_start;
    char *alias_name;
} YAMLEvent;

typedef struct {
    YAMLEvent **events;
    int count;
    int capacity;
} EventStream;

typedef struct {
    int is_valid;
    char *error_message;
    int error_line;
    char *intermediate_representation;
} ValidationResult;

/* Stage 2 & 3 API (implemented in yaml_event.y) */
int yaml_event_parser_init(void);
EventStream* yaml_event_parse_string(const char *input);
void yaml_event_parser_cleanup(void);
void event_stream_free(EventStream *stream);

/* Folded RML API */
ValidationResult* rml_parse_event_stream(const EventStream *stream);
void validation_result_free(ValidationResult *result);

#endif
