%code requires {
/* === TYPE DEFINITIONS (from common.h & event_parser.h) === */

/**
 * Node properties structure for anchor/tag pairs
 */
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;

/**
 * Stable Event Types (Alphabet for all stages)
 * Matches values expected in event stream (300+)
 */
typedef enum {
    EVENT_STREAM_START = 300,
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

/**
 * Individual YAML event representation
 */
typedef struct {
    YAMLEventType type;
    char quote_style;
    char *value;
    char *anchor;
    char *tag;
    int explicit_start;
    char *alias_name;
} YAMLEvent;

/**
 * Event stream container
 */
typedef struct {
    YAMLEvent **events;
    int count;
    int capacity;
} EventStream;

/**
 * Validation result after RML parsing
 */
typedef struct {
    int is_valid;
    char *error_message;
    int error_line;
    char *intermediate_representation;
} ValidationResult;
}

%define api.prefix {composition_yy_}

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "composition.tab.h"  /* Include for type definitions */

/* Forward declaration for cleanup function */
void event_stream_free(EventStream *stream);

/* Intermediate EventStream being built */
static EventStream *current_stream = NULL;

/* Helper to add events to the stream during parsing */
static void push_event(YAMLEvent *e) {
    if (!current_stream) return;
    if (current_stream->count >= current_stream->capacity) {
        current_stream->capacity = current_stream->capacity * 2 + 10;
        current_stream->events = (YAMLEvent **)realloc(current_stream->events, 
                                                       current_stream->capacity * sizeof(YAMLEvent *));
    }
    current_stream->events[current_stream->count++] = e;
}

static YAMLEvent* event_create(YAMLEventType type) {
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

static YAMLEvent* event_scalar_new(char style, const char *val) {
    YAMLEvent *e = event_create(EVENT_SCALAR);
    if (!e) return NULL;
    e->quote_style = style;
    e->value = val ? strdup(val) : NULL;
    return e;
}

static YAMLEvent* event_collection_new(YAMLEventType type, const char *anchor, const char *tag) {
    YAMLEvent *e = event_create(type);
    if (!e) return NULL;
    e->anchor = anchor ? strdup(anchor) : NULL;
    e->tag = tag ? strdup(tag) : NULL;
    return e;
}

static YAMLEvent* event_scalar_complex(char style, const char *val, const char *anchor, const char *tag) {
    YAMLEvent *e = event_create(EVENT_SCALAR);
    if (!e) return NULL;
    e->quote_style = style;
    e->value = val ? strdup(val) : NULL;
    e->anchor = anchor ? strdup(anchor) : NULL;
    e->tag = tag ? strdup(tag) : NULL;
    return e;
}

static YAMLEvent* event_doc_new(int explicit) {
    YAMLEvent *e = event_create(EVENT_DOCUMENT_START);
    if (!e) return NULL;
    e->explicit_start = explicit;
    return e;
}

static YAMLEvent* event_alias_new(const char *name) {
    YAMLEvent *e = event_create(EVENT_ALIAS);
    if (!e) return NULL;
    e->alias_name = name ? strdup(name) : NULL;
    return e;
}

%}



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
%token <cval> E_STYLE                      /* : " ' | > */

%type <sval> content
%type <cval> style_val

%define parse.error detailed
%locations

%{
int composition_lex(void);
void composition_yy_error(const char *msg);
#define yylex composition_lex
#define yyerror composition_yy_error
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

scalar : "=VAL" style_val content { push_event(event_scalar_new($2, $3)); free($3); }
       | "=VAL" style_val { push_event(event_scalar_new($2, NULL)); }
       | "=VAL" E_ANCHOR[a] style_val content { push_event(event_scalar_complex($3, $4, $a, NULL)); free($4); free($a); }
       | "=VAL" E_ANCHOR[a] style_val { push_event(event_scalar_complex($3, NULL, $a, NULL)); free($a); }
       | "=VAL" E_TAG[t] style_val content { push_event(event_scalar_complex($3, $4, NULL, $t)); free($4); free($t); }
       | "=VAL" E_TAG[t] style_val { push_event(event_scalar_complex($3, NULL, NULL, $t)); free($t); }
       | "=VAL" E_ANCHOR[a] E_TAG[t] style_val content { push_event(event_scalar_complex($4, $5, $a, $t)); free($5); free($a); free($t); }
       | "=VAL" E_ANCHOR[a] E_TAG[t] style_val { push_event(event_scalar_complex($4, NULL, $a, $t)); free($a); free($t); }
       ;

style_val : E_STYLE ':' { $$ = $1; }
          | ':'           { $$ = ':'; }
          ;

content : E_QUOTED_STRING
        | E_IDENTIFIER
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
extern void *composition__scan_string(const char *);
extern void composition__delete_buffer(void *);

int yaml_event_parser_init(void) {
    return 0;
}

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

    void *buf = composition__scan_string(input);
    int res = composition_yy_parse();
    composition__delete_buffer(buf);

    if (res != 0) {
        event_stream_free(current_stream);
        current_stream = NULL;
        return NULL;
    }

    EventStream *res_stream = current_stream;
    current_stream = NULL;
    return res_stream;
}

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
}

void validation_result_free(ValidationResult *result) {
    if (!result) return;
    free(result->error_message);
    free(result->intermediate_representation);
    free(result);
}

/* Error handler for composition stage */
void composition_yy_error(const char *msg) {
    fprintf(stderr, "Composition error: %s\n", msg);
}