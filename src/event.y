%code requires {
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
#include <stdio.h>
#include "event.tab.h"

static EventStream stream_store;

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

%define parse.error detailed
%locations

%{
int event_lex(void);
#define yylex event_lex
#define yyerror event_yy_error
%}

%%

stream : stream_open docs stream_close ;

stream_open : '+' "STR" ;

stream_close : '-' "STR" ;

docs : %empty
     | compose_docs
     ;

compose_docs : docs doc ;

doc : doc_monoid
    | node
    ;

doc_monoid : doc_closed doc_close_marker ;

doc_core : doc_open doc_nodes ;

doc_closed : doc_core doc_close ;

doc_nodes : %empty
          | compose_doc_nodes
          ;

compose_doc_nodes : doc_nodes node ;

doc_open : '+' "DOC" doc_open_marker ;

doc_open_marker : %empty
                | E_DOC_EXPLICIT
                ;

doc_close : '-' "DOC" ;

doc_close_marker : %empty
                 | E_DOC_END_EXPLICIT
                 ;

node : scalar
     | alias
     | collection
     ;

collection : sequence
           | mapping
           ;

scalar : '=' "VAL" style_val scalar_payload
       | '=' "VAL" E_ANCHOR style_val scalar_payload
       | '=' "VAL" E_TAG style_val scalar_payload
       | '=' "VAL" E_ANCHOR E_TAG style_val scalar_payload
       ;

style_val : E_STYLE ':'
          | E_STYLE
          | ':'
          ;

content : E_QUOTED_STRING
        | E_IDENTIFIER
        ;

scalar_payload : %empty
               | compose_scalar_payload
               ;

compose_scalar_payload : scalar_payload content ;

alias : '=' "ALI" E_IDENTIFIER
      ;

sequence : sequence_body sequence_close ;

sequence_body : sequence_open seq_items ;

sequence_open : '+' "SEQ" collection_props ;

sequence_close : '-' "SEQ" ;

mapping : mapping_body mapping_close ;

mapping_body : mapping_open map_pairs ;

mapping_open : '+' "MAP" collection_props ;

mapping_close : '-' "MAP" ;

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

seq_items : %empty
          | compose_seq_items
          ;

compose_seq_items : seq_items seq_item ;

seq_item : node
         ;

map_pairs : %empty
          | compose_map_pairs
          ;

compose_map_pairs : map_pairs map_pair ;

map_pair : tensor_map_pair
         | tensor_map_pair_implicit
          ;

tensor_map_pair : node node ;

tensor_map_pair_implicit : node implicit_scalar ;

implicit_scalar : %empty ;

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
        result.intermediate_representation = ir;
    } else {
        result.intermediate_representation = NULL;
    }
    return &result;
}

void event_yy_error(const char *msg) {
    fprintf(stderr, "[EVENT] Error: %s\n", msg ? msg : "syntax error");
}
