/**
 * yaml_event_parser.c - YAML Event Stream Parser (Stage 2)
 * 
 * Parses canonical event stream syntax and creates EventStream
 * Uses yaml_event.y/yaml_event.l for parsing
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml_event_parser.h"
#include "yaml_event.tab.h"

/* Global event stream (set by parser) */
static EventStream *current_stream = NULL;

/* Forward declarations from yaml_event.y stubs */
int yylex(void);
void yyerror(const char *msg);
extern FILE *yyin;
int yyparse(void);

/* Initialize parser */
int yaml_event_parser_init(void) {
    current_stream = NULL;
    return 0;
}

/* Parse event stream from string */
EventStream* yaml_event_parse_string(const char *input) {
    if (!input) return NULL;
    
    /* Create event stream */
    EventStream *stream = (EventStream *)malloc(sizeof(EventStream));
    if (!stream) return NULL;
    
    stream->events = NULL;
    stream->count = 0;
    stream->capacity = 0;
    
    /* Parse input string line by line */
    char *input_copy = strdup(input);
    if (!input_copy) {
        free(stream);
        return NULL;
    }
    
    char *line = strtok(input_copy, "\n");
    while (line && *line) {
        /* Expand capacity if needed */
        if (stream->count >= stream->capacity) {
            stream->capacity = stream->capacity * 2 + 10;
            YAMLEvent **new_events = (YAMLEvent **)realloc(stream->events, 
                                                           stream->capacity * sizeof(YAMLEvent *));
            if (!new_events) {
                free(input_copy);
                event_stream_free(stream);
                return NULL;
            }
            stream->events = new_events;
        }
        
        /* Parse line into event */
        YAMLEvent *event = (YAMLEvent *)malloc(sizeof(YAMLEvent));
        if (!event) {
            free(input_copy);
            event_stream_free(stream);
            return NULL;
        }
        
        /* Initialize event */
        event->type = EVENT_SCALAR;
        event->quote_style = '\0';
        event->value = NULL;
        event->anchor = NULL;
        event->tag = NULL;
        event->explicit_start = 0;
        event->alias_name = NULL;
        
        /* Parse event markers */
        if (strcmp(line, "+STR") == 0) {
            event->type = EVENT_STREAM_START;
        } else if (strcmp(line, "-STR") == 0) {
            event->type = EVENT_STREAM_END;
        } else if (strcmp(line, "+DOC") == 0) {
            event->type = EVENT_DOCUMENT_START;
        } else if (strcmp(line, "-DOC") == 0) {
            event->type = EVENT_DOCUMENT_END;
        } else if (strcmp(line, "+SEQ") == 0) {
            event->type = EVENT_SEQUENCE_START;
        } else if (strcmp(line, "-SEQ") == 0) {
            event->type = EVENT_SEQUENCE_END;
        } else if (strcmp(line, "+MAP") == 0) {
            event->type = EVENT_MAPPING_START;
        } else if (strcmp(line, "-MAP") == 0) {
            event->type = EVENT_MAPPING_END;
        } else if (strncmp(line, "=VAL ", 5) == 0) {
            /* Parse scalar: =VAL [quote_char][value]  or =VAL [quote]:[value] */
            event->type = EVENT_SCALAR;
            char *rest = line + 5;
            
            if (rest[0] == '"' || rest[0] == '\'') {
                /* Quoted format: "value" or 'value' */
                event->quote_style = rest[0];
                char *end_quote = strchr(rest + 1, rest[0]);
                if (end_quote) {
                    size_t len = end_quote - (rest + 1);
                    event->value = (char *)malloc(len + 1);
                    strncpy(event->value, rest + 1, len);
                    event->value[len] = '\0';
                }
            } else if (rest[0] == ':') {
                /* Plain format: :value */
                event->quote_style = ':';
                event->value = strdup(rest + 1);
            } else {
                /* Format: [quote_char]:[value] where quote_char is literal */
                char *colon = strchr(rest, ':');
                if (colon && colon > rest) {
                    event->quote_style = rest[0];
                    event->value = strdup(colon + 1);
                }
            }
        } else if (strncmp(line, "=ALI ", 5) == 0) {
            /* Parse alias: =ALI *name */
            event->type = EVENT_ALIAS;
            char *rest = line + 5;
            if (rest[0] == '*') {
                event->alias_name = strdup(rest + 1);
            }
        }
        
        stream->events[stream->count++] = event;
        line = strtok(NULL, "\n");
    }
    
    free(input_copy);
    return stream;
}

/* Cleanup parser */
void yaml_event_parser_cleanup(void) {
    current_stream = NULL;
}

/* Free event stream */
void event_stream_free(EventStream *stream) {
    if (!stream) return;
    
    for (int i = 0; i < stream->count; i++) {
        if (stream->events[i]) {
            free(stream->events[i]->value);
            free(stream->events[i]->anchor);
            free(stream->events[i]->tag);
            free(stream->events[i]->alias_name);
            free(stream->events[i]);
        }
    }
    
    free(stream->events);
    free(stream);
}
