/**
 * yaml_event_parser.h - YAML Event Stream Definitions (Stage 2)
 * 
 * Defines structures for canonical event format.
 * Implementation moved to yaml_event.y grammar file.
 */

#ifndef YAML_EVENT_PARSER_H
#define YAML_EVENT_PARSER_H

#include <stdio.h>

typedef enum {
    EVENT_STREAM_START,
    EVENT_STREAM_END,
    EVENT_DOCUMENT_START,
    EVENT_DOCUMENT_END,
    EVENT_SEQUENCE_START,
    EVENT_SEQUENCE_END,
    EVENT_MAPPING_START,
    EVENT_MAPPING_END,
    EVENT_SCALAR,
    EVENT_ALIAS,
} YAMLEventType;

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

/* Initialize event parser */
int yaml_event_parser_init(void);

/* Parse event stream from string */
EventStream* yaml_event_parse_string(const char *input);

/* Cleanup */
void yaml_event_parser_cleanup(void);
void event_stream_free(EventStream *stream);

#endif
