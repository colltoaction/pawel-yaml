%code requires {
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "common.h"

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

void event_yy_error(const char *msg);
%}

%token STR "STR"
%token DOC "DOC"
%token SEQ "SEQ"
%token MAP "MAP"
%token VAL "VAL"
%token ALI "ALI"

%token E_ANCHOR
%token E_TAG
%token E_DOC_EXPLICIT "---"
%token E_DOC_END_EXPLICIT "..."
%token E_QUOTED_STRING E_IDENTIFIER
%token FLOW_SEQ_MARKER FLOW_MAP_MARKER
%token E_STYLE

%type style_val doc_open_marker
%type stream stream_complete stream_open stream_close stream_body docs doc doc_monoid doc_core doc_closed doc_open doc_close doc_close_marker doc_nodes
%type node collection scalar alias sequence sequence_open sequence_close mapping mapping_open mapping_close
%type sequence_body mapping_body seq_items seq_item map_pairs map_pair scalar_payload implicit_scalar

%define parse.error detailed
%locations

%{
int event_lex(void);
#define yylex event_lex
#define yyerror event_yy_error
%}

%%

stream : stream_open docs stream_close ;

stream_open : '+' "STR" { $$ = word_atom(EVENT_STREAM_START, 0, 0); } ;

stream_close : '-' "STR" { $$ = word_atom(EVENT_STREAM_END, 0, 0); } ;

docs : %empty { $$ = 0; }
     | docs[left] doc[right] { $$ = word_binary($left, $right); }
     ;

doc : doc_monoid[value] { $$ = $value; }
    | node[value] { $$ = $value; }
    ;

doc_monoid : doc_closed[left] doc_close_marker[right] { $$ = word_binary($left, $right); } ;

doc_core : doc_open[left] doc_nodes[right] { $$ = word_binary($left, $right); } ;

doc_closed : doc_core[left] doc_close[right] { $$ = word_binary($left, $right); } ;

doc_nodes : %empty { $$ = 0; }
          | doc_nodes[left] node[right] { $$ = word_binary($left, $right); }
          ;

doc_open : '+' "DOC" doc_open_marker[explicit_start] { $$ = word_atom(EVENT_DOCUMENT_START, 0, $explicit_start); } ;

doc_open_marker : %empty { $$ = 0; }
                | E_DOC_EXPLICIT { $$ = 1; }
                ;

doc_close : '-' "DOC" { $$ = word_atom(EVENT_DOCUMENT_END, 0, 0); } ;

doc_close_marker : %empty { $$ = 0; }
                 | E_DOC_END_EXPLICIT { $$ = 0; }
                 ;

node : scalar[value] { $$ = $value; }
     | alias[value] { $$ = $value; }
     | collection[value] { $$ = $value; }
     ;

collection : sequence[value] { $$ = $value; }
           | mapping[value] { $$ = $value; }
           ;

scalar : '=' "VAL" style_val[style] scalar_payload[payload]
       {
           int atom = word_atom(EVENT_SCALAR, $style, 0);
           $$ = word_binary(atom, $payload);
       }
       | '=' "VAL" E_ANCHOR style_val[style] scalar_payload[payload]
       {
           int atom = word_atom(EVENT_SCALAR, $style, 0);
           $$ = word_binary(atom, $payload);
       }
       | '=' "VAL" E_TAG style_val[style] scalar_payload[payload]
       {
           int atom = word_atom(EVENT_SCALAR, $style, 0);
           $$ = word_binary(atom, $payload);
       }
       | '=' "VAL" E_ANCHOR E_TAG style_val[style] scalar_payload[payload]
       {
           int atom = word_atom(EVENT_SCALAR, $style, 0);
           $$ = word_binary(atom, $payload);
       }
       ;

style_val : E_STYLE[style] ':' { $$ = $style; }
          | E_STYLE[style]     { $$ = $style; }
          | ':'         { $$ = ':'; }
          ;

content : E_QUOTED_STRING
        | E_IDENTIFIER
        ;

scalar_payload : %empty { $$ = 0; }
               | scalar_payload[left] content[right] { $$ = word_binary($left, $right); }
               ;

alias : '=' "ALI" E_IDENTIFIER { $$ = word_atom(EVENT_ALIAS, 0, 0); }
      ;

sequence : sequence_body[left] sequence_close[right] { $$ = word_binary($left, $right); } ;

sequence_body : sequence_open[left] seq_items[right] { $$ = word_binary($left, $right); } ;

sequence_open : '+' "SEQ" collection_props { $$ = word_atom(EVENT_SEQUENCE_START, 0, 0); } ;

sequence_close : '-' "SEQ" { $$ = word_atom(EVENT_SEQUENCE_END, 0, 0); } ;

mapping : mapping_body[left] mapping_close[right] { $$ = word_binary($left, $right); } ;

mapping_body : mapping_open[left] map_pairs[right] { $$ = word_binary($left, $right); } ;

mapping_open : '+' "MAP" collection_props { $$ = word_atom(EVENT_MAPPING_START, 0, 0); } ;

mapping_close : '-' "MAP" { $$ = word_atom(EVENT_MAPPING_END, 0, 0); } ;

collection_props : %empty
                 | E_ANCHOR
                 | E_TAG
                 | E_ANCHOR E_TAG
                 | E_TAG E_ANCHOR
                 | FLOW_SEQ_MARKER
                 | FLOW_MAP_MARKER
                 | FLOW_SEQ_MARKER E_ANCHOR
                 | FLOW_SEQ_MARKER E_TAG
                 | FLOW_MAP_MARKER E_ANCHOR
                 | FLOW_MAP_MARKER E_TAG
                 ;

seq_items : %empty { $$ = 0; }
          | seq_items[left] seq_item[right] { $$ = word_binary($left, $right); }
          ;

seq_item : node[value] { $$ = $value; }
         ;

map_pairs : %empty { $$ = 0; }
          | map_pairs[left] map_pair[right] { $$ = word_binary($left, $right); }
          ;

map_pair : node[key] node[value] { $$ = word_binary($key, $value); }
         | node[key] implicit_scalar[value] { $$ = word_binary($key, $value); }
          ;

implicit_scalar : %empty { $$ = word_atom(EVENT_SCALAR, ':', 0); } ;

%%

extern void *event__scan_string(const char *);
extern void event__delete_buffer(void *);

EventStream* event_parse_string(const char *input) {
    if (!input) return NULL;

    g_stream_store.events = g_event_refs;
    g_stream_store.count = 0;
    g_stream_store.capacity = EVENT_STREAM_MAX_EVENTS;
    g_stream_overflow = 0;
    current_stream = &g_stream_store;

    void *buf = event__scan_string(input);
    int res = event_yy_parse();
    event__delete_buffer(buf);

    if (res != 0 || g_stream_overflow) {
        current_stream = NULL;
        return NULL;
    }

    current_stream = NULL;
    return &g_stream_store;
}

void event_stream_free(EventStream *stream) {
    (void)stream;
}

ValidationResult* rml_parse_event_stream(const EventStream *stream) {
    static ValidationResult result;
    static char error_message[] = "Invalid event stream structure";
    static char ir[1024 * 1024];

    result.is_valid = (stream != NULL);
    result.error_message = stream ? NULL : error_message;
    result.error_line = -1;

    if (stream) {
        ir[0] = '\0';
        int pos = 0;
        for (int i = 0; i < stream->count; i++) {
            YAMLEvent *e = stream->events[i];
            switch (e->type) {
                case EVENT_STREAM_START: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "+STR\n"); break;
                case EVENT_STREAM_END: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "-STR\n"); break;
                case EVENT_DOCUMENT_START:
                    if (e->explicit_start) pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "+DOC ---\n");
                    else pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "+DOC\n");
                    break;
                case EVENT_DOCUMENT_END: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "-DOC\n"); break;
                case EVENT_SEQUENCE_START: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "+SEQ\n"); break;
                case EVENT_SEQUENCE_END: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "-SEQ\n"); break;
                case EVENT_MAPPING_START: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "+MAP\n"); break;
                case EVENT_MAPPING_END: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "-MAP\n"); break;
                case EVENT_SCALAR:
                    if (e->quote_style == ':') pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "=VAL :\n");
                    else pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "=VAL %c:\n", e->quote_style ? e->quote_style : ':');
                    break;
                case EVENT_ALIAS: pos += snprintf(ir + pos, sizeof(ir) - (size_t)pos, "=ALI *\n"); break;
            }
            if ((size_t)pos >= sizeof(ir)) {
                ir[sizeof(ir) - 1] = '\0';
                break;
            }
        }
        result.intermediate_representation = ir;
    } else {
        result.intermediate_representation = NULL;
    }
    return &result;
}

void event_yy_error(const char *msg) {
    fprintf(stderr, "[EVENT] Error: %s\n", msg ? msg : "syntax error");
}
