%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Forward declaration for standard Bison non-reentrant parser */
void yyerror(const char *msg);

/**
 * YAML Event Stream (Test-Suite Canonical Format)
 * 
 * RED Phase: Hardcoded C logic (no grammar yet)
 * 
 * Represents canonical event stream from YAML test suite:
 * - Stream: +STR, -STR
 * - Documents: +DOC, -DOC
 * - Collections: +SEQ, -SEQ, +MAP, -MAP
 * - Scalars: =VAL [quote]:[content]
 * - Aliases: =ALI *name
 */

/* Event type enumeration */
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
    char quote_style;        /* ':' plain, '"' double, '\'' single, '|' literal, '>' folded */
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

/* Constructor helpers */
YAMLEvent *event_create(YAMLEventType type) {
    YAMLEvent *e = (YAMLEvent *)malloc(sizeof(YAMLEvent));
    if (!e) return NULL;
    e->type = type;
    e->quote_style = '\0';
    e->value = NULL;
    e->anchor = NULL;
    e->tag = NULL;
    e->explicit_start = 0;
    e->alias_name = NULL;
    return e;
}

YAMLEvent *event_scalar_new(char quote, const char *value) {
    YAMLEvent *e = event_create(EVENT_SCALAR);
    if (!e) return NULL;
    e->quote_style = quote;
    e->value = value ? strdup(value) : NULL;
    return e;
}

YAMLEvent *event_collection_new(YAMLEventType type, const char *anchor, const char *tag) {
    YAMLEvent *e = event_create(type);
    if (!e) return NULL;
    e->anchor = anchor ? strdup(anchor) : NULL;
    e->tag = tag ? strdup(tag) : NULL;
    return e;
}

YAMLEvent *event_doc_new(int explicit) {
    YAMLEvent *e = event_create(EVENT_DOCUMENT_START);
    if (!e) return NULL;
    e->explicit_start = explicit;
    return e;
}

YAMLEvent *event_alias_new(const char *name) {
    YAMLEvent *e = event_create(EVENT_ALIAS);
    if (!e) return NULL;
    e->alias_name = name ? strdup(name) : NULL;
    return e;
}

void event_free(YAMLEvent *e) {
    if (!e) return;
    free(e->value);
    free(e->anchor);
    free(e->tag);
    free(e->alias_name);
    free(e);
}

void event_print(FILE *out, const YAMLEvent *e) {
    if (!e) return;
    
    switch (e->type) {
        case EVENT_STREAM_START:
            fprintf(out, "+STR\n");
            break;
        case EVENT_STREAM_END:
            fprintf(out, "-STR\n");
            break;
        case EVENT_DOCUMENT_START:
            if (e->explicit_start)
                fprintf(out, "+DOC ---\n");
            else
                fprintf(out, "+DOC\n");
            break;
        case EVENT_DOCUMENT_END:
            fprintf(out, "-DOC\n");
            break;
        case EVENT_SEQUENCE_START:
            fprintf(out, "+SEQ");
            if (e->anchor) fprintf(out, " &%s", e->anchor);
            if (e->tag) fprintf(out, " <%s>", e->tag);
            fprintf(out, "\n");
            break;
        case EVENT_SEQUENCE_END:
            fprintf(out, "-SEQ\n");
            break;
        case EVENT_MAPPING_START:
            fprintf(out, "+MAP");
            if (e->anchor) fprintf(out, " &%s", e->anchor);
            if (e->tag) fprintf(out, " <%s>", e->tag);
            fprintf(out, "\n");
            break;
        case EVENT_MAPPING_END:
            fprintf(out, "-MAP\n");
            break;
        case EVENT_SCALAR:
            fprintf(out, "=VAL %c:%s\n", e->quote_style, e->value ? e->value : "");
            break;
        case EVENT_ALIAS:
            fprintf(out, "=ALI *%s\n", e->alias_name ? e->alias_name : "");
            break;
    }
}

/* Global event stream (set by parser) */
static EventStream *current_stream = NULL;

/* Initialize parser */
int yaml_event_parser_init(void) {
    current_stream = NULL;
    return 0;
}

/* Parse event stream from string - moved from yaml_event_parser.c */
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
%}

/* Lexer value types */
%union {
    char *sval;   /* String values */
    char cval;    /* Character values */
}

/* Token declarations with string literal aliases */
%token STR_START   "+STR"
%token STR_END     "-STR"
%token DOC_START   "+DOC"
%token DOC_END     "-DOC"
%token SEQ_START   "+SEQ"
%token SEQ_END     "-SEQ"
%token MAP_START   "+MAP"
%token MAP_END     "-MAP"
%token VALUE_MARK  "=VAL"
%token ALIAS_MARK  "=ALI"
%token <sval> ANCHOR                     /* &anchor */
%token <sval> TAG                        /* <tag> */
%token <sval> QUOTED_STRING IDENTIFIER   /* "value", plain_value */
%token <cval> CHAR                       /* : " ' | > */

%%

/* TOP-LEVEL: Parse a stream of events */
stream : events
       {
           /* Document parsed successfully */
       }
       ;

/* Sequence of zero or more events */
events : %empty
       | events event
       ;

/* Individual event */
event : "+STR"
      | "-STR"
      | doc_event
      | collection_start
      | collection_end
      | "=VAL" char:CHAR value:QUOTED_STRING
      | "=VAL" char:CHAR value:IDENTIFIER
      | "=ALI" name:IDENTIFIER
      ;

/* Document events */
doc_event : "+DOC"
          | "-DOC"
          ;

/* Collection events with optional anchor/tag */
collection_start : "+SEQ"
                 | "+SEQ" anchor:ANCHOR
                 | "+SEQ" tag:TAG
                 | "+SEQ" anchor:ANCHOR tag:TAG
                 | "+MAP"
                 | "+MAP" anchor:ANCHOR
                 | "+MAP" tag:TAG
                 | "+MAP" anchor:ANCHOR tag:TAG
                 ;

collection_end : "-SEQ"
               | "-MAP"
               ;

%%

/* Enhanced error reporting with context */
__attribute__((weak))
void yyerror(const char *msg) {
    extern int yylineno;
    extern char *yytext;
    
    /* Print detailed error information */
    fprintf(stderr, "YAML Error: %s at line %d", msg, yylineno);
    if (yytext && yytext[0]) {
        fprintf(stderr, " near '%s'", yytext);
    }
    fprintf(stderr, "\n");
    
    /* Provide suggestion if this looks like a syntax error */
    if (strstr(msg, "syntax") || strstr(msg, "ambiguous")) {
        fprintf(stderr, "  Hint: Check for proper indentation, quoted strings, or complex key syntax\n");
    }
}
