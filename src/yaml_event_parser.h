/**
 * yaml_event_parser.h - YAML Event Stream Definitions (Stage 2)
 */

#ifndef YAML_EVENT_PARSER_H
#define YAML_EVENT_PARSER_H

#include <stdio.h>
#include "tokens.tab.h"

/* YAMLEventType mapping to centralized tokens */
typedef int YAMLEventType;

#define EVENT_STREAM_START   TOK_EVENT_STREAM_START
#define EVENT_STREAM_END     TOK_EVENT_STREAM_END
#define EVENT_DOCUMENT_START TOK_EVENT_DOCUMENT_START
#define EVENT_DOCUMENT_END   TOK_EVENT_DOCUMENT_END
#define EVENT_SEQUENCE_START TOK_EVENT_SEQUENCE_START
#define EVENT_SEQUENCE_END   TOK_EVENT_SEQUENCE_END
#define EVENT_MAPPING_START  TOK_EVENT_MAPPING_START
#define EVENT_MAPPING_END    TOK_EVENT_MAPPING_END
#define EVENT_SCALAR         TOK_EVENT_SCALAR
#define EVENT_ALIAS          TOK_EVENT_ALIAS

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

/* Stage 2 API */
int yaml_event_parser_init(void);
EventStream* yaml_event_parse_string(const char *input);
void yaml_event_parser_cleanup(void);
void event_stream_free(EventStream *stream);

#endif
