%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
<<<<<<<< HEAD:src/yaml_event.y

void yyerror(const char *msg);
========
#include "event_parser.h"
>>>>>>>> 62fd093 (refactor: argv-based pipeline mode selection, cleanup old parsers):src/event.y

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

<<<<<<<< HEAD:src/yaml_event.y
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
========
%}

%define api.prefix {event_yy_}

%union {
    char *sval;   /* String values */
    char cval;    /* Character values */
}

/* Tokens match values in common.h for consistency */
%token E_STR_START   300 "+STR"
%token E_STR_END     301 "-STR"
%token E_DOC_START   302 "+DOC"
%token E_DOC_END     303 "-DOC"
%token E_SEQ_START   304 "+SEQ"
%token E_SEQ_END     305 "-SEQ"
%token E_MAP_START   306 "+MAP"
%token E_MAP_END     307 "-MAP"
%token E_SCALAR      308 "=VAL"
%token E_ALIAS       309 "=ALI"

%token <sval> E_ANCHOR                     /* &anchor */
%token <sval> E_TAG                        /* <tag> */
%token <sval> E_QUOTED_STRING E_IDENTIFIER /* "value", plain_value */
%token <cval> E_CHAR                       /* : " ' | > */

%define parse.error detailed
%locations

%{
int stream_lex(void);
void event_error(const char *msg);
#define yylex stream_lex
#define yyerror event_error
%}

%%

/* TOP-LEVEL: Unified RML structure validation */
stream : "+STR" { push_event(event_create(EVENT_STREAM_START)); }
         docs 
         "-STR" { push_event(event_create(EVENT_STREAM_END)); }
       ;

docs : %empty
     | docs doc
     ;

doc : doc_start node "-DOC" { push_event(event_create(EVENT_DOCUMENT_END)); }
    | node
    ;

doc_start: "+DOC"      { push_event(event_doc_new(0)); }
         | "+DOC" "---" { push_event(event_doc_new(1)); }
         ;

node : scalar
     | alias
     | sequence
     | mapping
     ;

scalar : "=VAL" E_CHAR[style] E_QUOTED_STRING[content] { push_event(event_scalar_new($style, $content)); free($content); }
       | "=VAL" E_CHAR[style] E_IDENTIFIER[content]    { push_event(event_scalar_new($style, $content)); free($content); }
       | "=VAL" E_CHAR[style]                          { push_event(event_scalar_new($style, NULL)); }
       ;

alias : "=ALI" E_IDENTIFIER[target] { push_event(event_alias_new($target)); free($target); }
      ;

sequence : seq_start seq_items "-SEQ" { push_event(event_create(EVENT_SEQUENCE_END)); }
         ;

seq_start : "+SEQ"                        { push_event(event_collection_new(EVENT_SEQUENCE_START, NULL, NULL)); }
          | "+SEQ" E_ANCHOR[a]            { push_event(event_collection_new(EVENT_SEQUENCE_START, $a, NULL)); free($a); }
          | "+SEQ" E_TAG[t]               { push_event(event_collection_new(EVENT_SEQUENCE_START, NULL, $t)); free($t); }
          | "+SEQ" E_ANCHOR[a] E_TAG[t]   { push_event(event_collection_new(EVENT_SEQUENCE_START, $a, $t)); free($a); free($t); }
          ;

mapping : map_start map_pairs "-MAP"   { push_event(event_create(EVENT_MAPPING_END)); }
        ;

map_start : "+MAP"                        { push_event(event_collection_new(EVENT_MAPPING_START, NULL, NULL)); }
          | "+MAP" E_ANCHOR[a]            { push_event(event_collection_new(EVENT_MAPPING_START, $a, NULL)); free($a); }
          | "+MAP" E_TAG[t]               { push_event(event_collection_new(EVENT_MAPPING_START, NULL, $t)); free($t); }
          | "+MAP" E_ANCHOR[a] E_TAG[t]   { push_event(event_collection_new(EVENT_MAPPING_START, $a, $t)); free($a); free($t); }
          ;

seq_items : %empty
          | seq_items node
          ;

map_pairs : %empty
          | map_pairs node node
          ;

%%

void event_error(const char *msg) {
    fprintf(stderr, "Event Parse Error: %s\n", msg);
}

/* Global state for string parsing */
extern void *stream__scan_string(const char *);
extern void stream__delete_buffer(void *);
>>>>>>>> 62fd093 (refactor: argv-based pipeline mode selection, cleanup old parsers):src/event.y

/* Initialize parser */
int yaml_event_parser_init(void) {
    current_stream = NULL;
    return 0;
}

<<<<<<<< HEAD:src/yaml_event.y
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
========
void yaml_event_parser_cleanup(void) {
}

/* Stage 3 API: Uses Bison to parse and build EventStream */
EventStream* event_parse_string(const char *input) {
    if (!input) return NULL;
    
    current_stream = (EventStream *)malloc(sizeof(EventStream));
    current_stream->events = NULL;
    current_stream->count = 0;
    current_stream->capacity = 10;
    current_stream->events = (YAMLEvent **)malloc(current_stream->capacity * sizeof(YAMLEvent *));

    void *buf = stream__scan_string(input);
    int res = event_yy_parse();
    stream__delete_buffer(buf);

    if (res != 0) {
        event_stream_free(current_stream);
        current_stream = NULL;
>>>>>>>> 62fd093 (refactor: argv-based pipeline mode selection, cleanup old parsers):src/event.y
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

<<<<<<<< HEAD:src/yaml_event.y
/* Lexer value types */
%union {
    char *sval;   /* String values */
    char cval;    /* Character values */
========
ValidationResult* rml_parse_event_stream(const EventStream *stream) {
    ValidationResult *result = (ValidationResult*)malloc(sizeof(ValidationResult));
    result->is_valid = (stream != NULL);
    result->error_message = stream ? NULL : strdup("Invalid event stream structure");
    result->error_line = -1;
    
    if (stream) {
        char *ir = (char*)malloc(stream->count * 128 + 1024);
        ir[0] = '\0';
        int pos = 0;
        for (int i = 0; i < stream->count; i++) {
            YAMLEvent *e = stream->events[i];
            switch (e->type) {
                case EVENT_STREAM_START: pos += sprintf(ir + pos, "+STR\n"); break;
                case EVENT_STREAM_END: pos += sprintf(ir + pos, "-STR\n"); break;
                case EVENT_DOCUMENT_START: 
                    if (e->explicit_start) pos += sprintf(ir + pos, "+DOC ---\n");
                    else pos += sprintf(ir + pos, "+DOC\n");
                    break;
                case EVENT_DOCUMENT_END: pos += sprintf(ir + pos, "-DOC\n"); break;
                case EVENT_SEQUENCE_START: pos += sprintf(ir + pos, "+SEQ\n"); break;
                case EVENT_SEQUENCE_END: pos += sprintf(ir + pos, "-SEQ\n"); break;
                case EVENT_MAPPING_START: pos += sprintf(ir + pos, "+MAP\n"); break;
                case EVENT_MAPPING_END: pos += sprintf(ir + pos, "-MAP\n"); break;
                case EVENT_SCALAR: 
                    if (e->quote_style == ':') pos += sprintf(ir + pos, "=VAL :%s\n", e->value ? e->value : "");
                    else pos += sprintf(ir + pos, "=VAL %c:%s\n", e->quote_style, e->value ? e->value : "");
                    break;
                case EVENT_ALIAS: pos += sprintf(ir + pos, "=ALI *%s\n", e->alias_name); break;
            }
        }
        result->intermediate_representation = ir;
    } else {
        result->intermediate_representation = NULL;
    }
    return result;
>>>>>>>> 62fd093 (refactor: argv-based pipeline mode selection, cleanup old parsers):src/event.y
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

%define parse.error detailed
%locations

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

/* Bison's detailed error messages via %define parse.error detailed
   are passed as 'msg' parameter to this function.
   Simply printing them ensures all error information reaches stderr. */
void yyerror(const char *msg) {
    if (msg) {
        fprintf(stderr, "YAML Parse Error: %s\n", msg);
    }
}
