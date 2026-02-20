%code requires {
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/**
 * Node properties structure for anchor/tag pairs
 */
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;

/**
 * Stable Event Types (Alphabet for all stages)
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
    YAMLEvent *events;
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

/* Stage 3 API */
EventStream* event_parse_string(const char *input);
void event_stream_free(EventStream *stream);
ValidationResult* rml_parse_event_stream(const EventStream *stream);
}

%define api.prefix {event_yy_}

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "event.tab.h"

/* Intermediate EventStream being built */
static EventStream *current_stream = NULL;

static void event_destroy(YAMLEvent *e) {
    if (e) {
        free(e->value);
        free(e->anchor);
        free(e->tag);
        free(e->alias_name);
    }
}

/* Helper to add events to the stream during parsing */
static void push_event(YAMLEvent e) {
    if (!current_stream) {
        event_destroy(&e);
        return;
    }
    if (current_stream->count >= current_stream->capacity) {
        current_stream->capacity = current_stream->capacity * 2 + 10;
        current_stream->events = (YAMLEvent *)realloc(current_stream->events, 
                                                       current_stream->capacity * sizeof(YAMLEvent));
    }
    current_stream->events[current_stream->count++] = e;
}

static YAMLEvent event_create(YAMLEventType type) {
    YAMLEvent e;
    memset(&e, 0, sizeof(YAMLEvent));
    e.type = type;
    return e;
}

static YAMLEvent event_scalar_new(char style, char *val) {
    YAMLEvent e = event_create(EVENT_SCALAR);
    e.quote_style = style;
    e.value = val;
    return e;
}

static YAMLEvent event_collection_new(YAMLEventType type, char *anchor, char *tag) {
    YAMLEvent e = event_create(type);
    e.anchor = anchor;
    e.tag = tag;
    return e;
}

static YAMLEvent event_scalar_complex(char style, char *val, char *anchor, char *tag) {
    YAMLEvent e = event_create(EVENT_SCALAR);
    e.quote_style = style;
    e.value = val;
    e.anchor = anchor;
    e.tag = tag;
    return e;
}

static YAMLEvent event_doc_new(int explicit) {
    YAMLEvent e = event_create(EVENT_DOCUMENT_START);
    e.explicit_start = explicit;
    return e;
}

static YAMLEvent event_alias_new(char *name) {
    YAMLEvent e = event_create(EVENT_ALIAS);
    e.alias_name = name;
    return e;
}


void event_yy_error(const char *msg);
%}

%union {
    char *sval;
    char cval;
    NodeProps props;
    YAMLEvent evt;
}

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

%token <sval> E_ANCHOR
%token <sval> E_TAG
%token E_DOC_EXPLICIT "---"
%token <sval> E_QUOTED_STRING E_IDENTIFIER
%token <cval> E_STYLE

%type <sval> content opt_content
%type <cval> style_val
%type <props> opt_props
%type <evt> evt_stream_start evt_stream_end evt_doc_start evt_doc_end
%type <evt> evt_seq_start evt_seq_end evt_map_start evt_map_end
%type <evt> evt_scalar evt_alias

%destructor { free($$); } <sval>
%destructor { free($$.anchor); free($$.tag); } <props>
%destructor { event_destroy(&$$); } <evt>

%define parse.error detailed
%locations

%{
int event_lex(void);
#undef yylex
#define yylex event_lex
#define yyerror event_yy_error
%}

%%

stream : stream_start docs stream_end ;

stream_start : evt_stream_start { push_event($1); } ;
evt_stream_start : "+STR" { $$ = event_create(EVENT_STREAM_START); } ;

stream_end : evt_stream_end { push_event($1); } ;
evt_stream_end : "-STR" { $$ = event_create(EVENT_STREAM_END); } ;

docs : %empty
     | docs doc
     ;

doc : doc_start node doc_end
    | node
    ;

doc_end : evt_doc_end { push_event($1); } ;
evt_doc_end : "-DOC" { $$ = event_create(EVENT_DOCUMENT_END); } ;

doc_start: evt_doc_start { push_event($1); } ;
evt_doc_start: "+DOC" { $$ = event_doc_new(0); }
             | "+DOC" "---" { $$ = event_doc_new(1); }
             ;

node : scalar
     | alias
     | sequence
     | mapping
     ;

opt_props:
    %empty { $$.anchor = NULL; $$.tag = NULL; }
    | E_ANCHOR { $$.anchor = $1; $$.tag = NULL; }
    | E_TAG { $$.anchor = NULL; $$.tag = $1; }
    | E_ANCHOR E_TAG { $$.anchor = $1; $$.tag = $2; }
    ;

opt_content:
    %empty { $$ = NULL; }
    | content { $$ = $1; }
    ;

scalar : evt_scalar { push_event($1); } ;

evt_scalar : "=VAL" opt_props style_val opt_content { $$ = event_scalar_complex($3, $4, $2.anchor, $2.tag); } ;

style_val : E_STYLE ':' { $$ = $1; }
          | E_STYLE     { $$ = $1; }
          | ':'           { $$ = ':'; }
          ;

content : E_QUOTED_STRING { $$ = $1; }
        | E_IDENTIFIER    { $$ = $1; }
        ;

alias : evt_alias { push_event($1); } ;

evt_alias : "=ALI" E_IDENTIFIER { $$ = event_alias_new($2); } ;

sequence : seq_start seq_items seq_end ;

seq_start : evt_seq_start { push_event($1); } ;
evt_seq_start : "+SEQ" opt_props { $$ = event_collection_new(EVENT_SEQUENCE_START, $2.anchor, $2.tag); } ;

seq_end : evt_seq_end { push_event($1); } ;
evt_seq_end : "-SEQ" { $$ = event_create(EVENT_SEQUENCE_END); } ;

mapping : map_start map_pairs map_end ;

map_start : evt_map_start { push_event($1); } ;
evt_map_start : "+MAP" opt_props { $$ = event_collection_new(EVENT_MAPPING_START, $2.anchor, $2.tag); } ;

map_end : evt_map_end { push_event($1); } ;
evt_map_end : "-MAP" { $$ = event_create(EVENT_MAPPING_END); } ;

seq_items : %empty
          | seq_items node
          ;

map_pairs : %empty
          | map_pairs node node
          ;

%%

extern void *event__scan_string(const char *);
extern void event__delete_buffer(void *);

EventStream* event_parse_string(const char *input) {
    if (!input) return NULL;
    
    current_stream = (EventStream *)malloc(sizeof(EventStream));
    current_stream->events = NULL;
    current_stream->count = 0;
    current_stream->capacity = 10;
    current_stream->events = (YAMLEvent *)malloc(current_stream->capacity * sizeof(YAMLEvent));

    void *buf = event__scan_string(input);
    int res = event_yy_parse();
    event__delete_buffer(buf);

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
        event_destroy(&stream->events[i]);
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
            YAMLEvent *e = &stream->events[i];
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

void event_yy_error(const char *msg) {
    fprintf(stderr, "[EVENT] Error: %s\n", msg ? msg : "syntax error");
}
