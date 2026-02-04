%code requires {
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;
}

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "yaml_event_parser.h"

int yaml_lex(void *yylval_param, void *yyloc_param, void *yyscanner);
void yaml_error(void *yylloc, void *scanner, const char *s);

/* Output buffer for RML IR */
extern char *rml_ir_buf;
extern size_t rml_ir_size;
static FILE *ir_out;

#define EMIT(...) fprintf(ir_out, __VA_ARGS__)

/* Option 2: EventStream accumulator for direct building */
static EventStream *current_event_stream = NULL;

/* Helper: Add event to stream */
static void add_event(YAMLEventType type) {
    if (!current_event_stream) return;
    
    YAMLEvent *evt = (YAMLEvent*)malloc(sizeof(YAMLEvent));
    evt->type = type;
    evt->quote_style = 0;
    evt->value = NULL;
    evt->anchor = NULL;
    evt->tag = NULL;
    evt->explicit_start = 0;
    evt->alias_name = NULL;
    
    if (current_event_stream->count >= current_event_stream->capacity) {
        current_event_stream->capacity = (current_event_stream->capacity + 1) * 2;
        current_event_stream->events = (YAMLEvent**)realloc(current_event_stream->events, 
                                        current_event_stream->capacity * sizeof(YAMLEvent*));
    }
    current_event_stream->events[current_event_stream->count++] = evt;
}

/* Helper: Add scalar event */
static void add_scalar_event(const char *value, char quote_style) {
    if (!current_event_stream || !value) return;
    
    YAMLEvent *evt = (YAMLEvent*)malloc(sizeof(YAMLEvent));
    evt->type = EVENT_SCALAR;
    evt->quote_style = quote_style;
    evt->value = (char*)malloc(strlen(value) + 1);
    strcpy(evt->value, value);
    evt->anchor = NULL;
    evt->tag = NULL;
    evt->explicit_start = 0;
    evt->alias_name = NULL;
    
    if (current_event_stream->count >= current_event_stream->capacity) {
        current_event_stream->capacity = (current_event_stream->capacity + 1) * 2;
        current_event_stream->events = (YAMLEvent**)realloc(current_event_stream->events,
                                        current_event_stream->capacity * sizeof(YAMLEvent*));
    }
    current_event_stream->events[current_event_stream->count++] = evt;
}

/* Helper: Add alias event */
static void add_alias_event(const char *name) {
    if (!current_event_stream || !name) return;
    
    YAMLEvent *evt = (YAMLEvent*)malloc(sizeof(YAMLEvent));
    evt->type = EVENT_ALIAS;
    evt->quote_style = 0;
    evt->value = NULL;
    evt->anchor = NULL;
    evt->tag = NULL;
    evt->explicit_start = 0;
    evt->alias_name = (char*)malloc(strlen(name) + 1);
    strcpy(evt->alias_name, name);
    
    if (current_event_stream->count >= current_event_stream->capacity) {
        current_event_stream->capacity = (current_event_stream->capacity + 1) * 2;
        current_event_stream->events = (YAMLEvent**)realloc(current_event_stream->events,
                                        current_event_stream->capacity * sizeof(YAMLEvent*));
    }
    current_event_stream->events[current_event_stream->count++] = evt;
}

%}

%define api.pure true
%define api.prefix {yaml_}
%locations
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    NodeProps props;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET COLON QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%type <props> node_props

/* Destructors for memory safety */
%destructor { free($$); } <string>
%destructor { free($$.anchor); free($$.tag); } <props>

%glr-parser
%expect 45
%expect-rr 34

%%

stream:
    { ir_out = open_memstream(&rml_ir_buf, &rml_ir_size); add_event(EVENT_STREAM_START); }
    documents
    { fclose(ir_out); add_event(EVENT_STREAM_END); }
    ;

documents:
    implicit_document
    | explicit_documents
    | implicit_document explicit_documents
    | DOC_END
    ;

explicit_documents:
    explicit_document
    | explicit_documents explicit_document
    ;

explicit_document:
    DOC_START { EMIT("D+\n"); add_event(EVENT_DOCUMENT_START); } document_body { EMIT("D-\n"); add_event(EVENT_DOCUMENT_END); } optional_doc_end
    | DOC_START { EMIT("D+\nS::\n"); add_event(EVENT_DOCUMENT_START); add_scalar_event("", ':'); } optional_doc_end { EMIT("D-\n"); add_event(EVENT_DOCUMENT_END); }
    | directives DOC_START { EMIT("D+\n"); add_event(EVENT_DOCUMENT_START); } document_body { EMIT("D-\n"); add_event(EVENT_DOCUMENT_END); } optional_doc_end
    | directives DOC_START { EMIT("D+\nS::\n"); add_event(EVENT_DOCUMENT_START); add_scalar_event("", ':'); } optional_doc_end { EMIT("D-\n"); add_event(EVENT_DOCUMENT_END); }
    ;

directives: directive | directives directive ;
directive: YAML_DIRECTIVE | TAG_DIRECTIVE SCALAR SCALAR { free($2); free($3); } ;

optional_doc_end: /* empty */ | DOC_END ;

implicit_document:
    document_body { EMIT("D-\n"); add_event(EVENT_DOCUMENT_END); } optional_doc_end
    ;

document_body:
    { EMIT("D+\n"); } node
    | { EMIT("D+\nM+\n"); add_event(EVENT_MAPPING_START); } map_entries { EMIT("M-\n"); add_event(EVENT_MAPPING_END); } %dprec 3
    | { EMIT("D+\nQ+\n"); add_event(EVENT_SEQUENCE_START); } seq_entries { EMIT("Q-\n"); add_event(EVENT_SEQUENCE_END); } %dprec 2
    | node_props[p] { EMIT("D+\nP&%s<%s>\nM+\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); add_event(EVENT_MAPPING_START); } 
      map_entries { EMIT("M-\n"); add_event(EVENT_MAPPING_END); free($p.anchor); free($p.tag); } %dprec 4
    | node_props[p] { EMIT("D+\nP&%s<%s>\nQ+\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); add_event(EVENT_SEQUENCE_START); } 
      seq_entries { EMIT("Q-\n"); add_event(EVENT_SEQUENCE_END); free($p.anchor); free($p.tag); } %dprec 3
    ;

node:
    node_body %dprec 2
    | node_props[p] { EMIT("P&%s<%s>\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); free($p.anchor); free($p.tag); } node_body %dprec 3
    | node_props[p] { EMIT("P&%s<%s>\nS::\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); free($p.anchor); free($p.tag); } %dprec 1
    ;

node_body:
    scalar
    | ALIAS[a] { EMIT("A:%s\n", $a+1); add_alias_event($a+1); free($a); }
    | flow_seq
    | flow_map
    | collection
    ;

node_props:
    TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    | TAG[t] ANCHOR[a] { $$.anchor = $a; $$.tag = $t; }
    ;

scalar:
    SCALAR[s] { EMIT("S:%s\n", $s); add_scalar_event($s, ':'); free($s); }
    | QSCALAR[s] { EMIT("S\":%s\n", $s); add_scalar_event($s, '"'); free($s); }
    | SSCALAR[s] { EMIT("S\':%s\n", $s); add_scalar_event($s, '\''); free($s); }
    | BSCALAR[s] { EMIT("S%c:%s\n", $s[0], $s+1); add_scalar_event($s+1, $s[0]); free($s); }
    ;

collection: map | seq ;

seq:
    INDENT { EMIT("Q+\n"); add_event(EVENT_SEQUENCE_START); } seq_entries DEDENT { EMIT("Q-\n"); add_event(EVENT_SEQUENCE_END); }
    ;

seq_entries:
    seq_entry
    | seq_entries seq_entry
    ;

seq_entry:
    BULLET node %dprec 2
    | BULLET { EMIT("M+\n"); add_event(EVENT_MAPPING_START); } map_entries { EMIT("M-\n"); add_event(EVENT_MAPPING_END); } %dprec 3
    | BULLET { EMIT("S::\n"); add_scalar_event("", ':'); } %dprec 1
    ;

map:
    INDENT { EMIT("M+\n"); add_event(EVENT_MAPPING_START); } map_entries DEDENT { EMIT("M-\n"); add_event(EVENT_MAPPING_END); }
    ;

map_entries:
    map_entry
    | map_entries map_entry
    ;

map_entry:
    entry_key COLON node %dprec 3
    | entry_key COLON INDENT node DEDENT %dprec 3
    | QUESTION node COLON node %dprec 5
    | entry_key COLON { EMIT("S::\n"); } %dprec 1
    | QUESTION node COLON { EMIT("S::\n"); } %dprec 1
    | QUESTION node { EMIT("S::\n"); } %dprec 2
    | COLON node %dprec 2 { EMIT("S::\n"); }
    ;

entry_key: scalar | ALIAS[a] { EMIT("A:%s\n", $a+1); add_alias_event($a+1); free($a); } | flow_seq | flow_map | node_props[p] scalar { EMIT("P&%s<%s>\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); free($p.anchor); free($p.tag); } ;

flow_seq:
    LBRACK { EMIT("Q+\n"); add_event(EVENT_SEQUENCE_START); } flow_seq_entries RBRACK { EMIT("Q-\n"); add_event(EVENT_SEQUENCE_END); }
    | LBRACK RBRACK { EMIT("Q+\nQ-\n"); add_event(EVENT_SEQUENCE_START); add_event(EVENT_SEQUENCE_END); }
    ;

flow_seq_entries:
    flow_node
    | flow_seq_entries COMMA flow_node
    | flow_seq_entries COMMA
    | flow_node COLON node { /* simplified */ }
    ;

flow_map:
    LBRACE { EMIT("M+\n"); add_event(EVENT_MAPPING_START); } flow_map_entries RBRACE { EMIT("M-\n"); add_event(EVENT_MAPPING_END); }
    | LBRACE RBRACE { EMIT("M+\nM-\n"); add_event(EVENT_MAPPING_START); add_event(EVENT_MAPPING_END); }
    ;

flow_map_entries:
    node COLON node
    | flow_map_entries COMMA node COLON node
    | flow_map_entries COMMA
    ;

flow_node: node ;

%%

void yaml_error(void *yylloc, void *scanner, const char *s) {
    fprintf(stderr, "YAML Error: %s\n", s);
}
/* Option 2: Public API for direct EventStream building */
EventStream* yaml_parse_to_event_stream(const char *input) {
    /* Create new event stream */
    current_event_stream = (EventStream*)malloc(sizeof(EventStream));
    current_event_stream->capacity = 128;
    current_event_stream->count = 0;
    current_event_stream->events = (YAMLEvent**)malloc(current_event_stream->capacity * sizeof(YAMLEvent*));
    
    /* Initialize lexer with input */
    extern int yaml_lex_init_extra(void *user_defined, void **scanner);
    extern int yaml_lex_destroy(void *scanner);
    
    void *scanner;
    yaml_lex_init_extra((void*)input, &scanner);
    
    /* Parse */
    int ret = yaml_parse(scanner);
    
    /* Cleanup */
    yaml_lex_destroy(scanner);
    
    EventStream *result = current_event_stream;
    current_event_stream = NULL;
    
    return result;
}