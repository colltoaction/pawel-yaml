%code requires {
#include "common.h"
#include "lexer_context.h"

/* Pipeline stage exports */
int yaml_parse(void);
int yaml_compose(void);
int yaml_serialize(void);
int yaml_present(void);
}

%glr-parser
%expect 15
%expect-rr 14

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "common.h"
#include "event_parser.h"
#include "ir_builder.h"
#include "lexer_context.h"

int presentation_lex(void *yylval_param, void *yyloc_param, void *yyscanner);
#define yylex presentation_lex
void stream_yy_error(void *yylloc, void *scanner, const char *s);

/* Output buffer for RML IR */
char *rml_ir_buf = NULL;
size_t rml_ir_size = 0;
static IRBuilder *ir = NULL;

/* Current event stream being built */
static EventStream *current_event_stream = NULL;

/* Helper: Add event to the stream */
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
    evt->value = strdup(value);
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
    evt->alias_name = strdup(name);
    
    if (current_event_stream->count >= current_event_stream->capacity) {
        current_event_stream->capacity = (current_event_stream->capacity + 1) * 2;
        current_event_stream->events = (YAMLEvent**)realloc(current_event_stream->events,
                                        current_event_stream->capacity * sizeof(YAMLEvent*));
    }
    current_event_stream->events[current_event_stream->count++] = evt;
}

%}

%define api.pure true
%define api.prefix {stream_yy_}
%locations
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    NodeProps props;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS MAP_KEY QMAP_KEY SMAP_KEY
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET COLON QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%type <props> node_props

/* Destructors for memory safety */
%destructor { free($$); } <string>
%destructor { free($$.anchor); free($$.tag); } <props>

%locations
%define parse.error detailed

/* Precedence declarations for disambiguation */
%left COMMA RBRACE RBRACK
%precedence COLON
%precedence SCALAR QSCALAR SSCALAR BSCALAR

%%

stream:
    { ir = ir_builder_new_memory(); add_event(EVENT_STREAM_START); ir_stream_start(ir); }
    documents
    { ir_stream_end(ir); rml_ir_buf = ir_builder_finalize(ir); rml_ir_size = strlen(rml_ir_buf); ir_builder_free(ir); ir = NULL; add_event(EVENT_STREAM_END); }
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
    DOC_START { ir_doc_start(ir); add_event(EVENT_DOCUMENT_START); }
    node
    { ir_doc_end(ir); add_event(EVENT_DOCUMENT_END); }
    ;

implicit_document:
    { ir_doc_start(ir); add_event(EVENT_DOCUMENT_START); } node { ir_doc_end(ir); add_event(EVENT_DOCUMENT_END); }
    ;

node:
    plain_node
    ;

plain_node:
    SCALAR[val] { ir_scalar_plain(ir, $val); add_scalar_event($val, ':'); free($val); }
    | QSCALAR[val] { ir_scalar_quoted(ir, $val, '"'); add_scalar_event($val, '"'); free($val); }
    | SSCALAR[val] { ir_scalar_quoted(ir, $val, '\''); add_scalar_event($val, '\''); free($val); }
    | BSCALAR[val] { ir_scalar_block(ir, $val+1, $val[0]); add_scalar_event($val+1, $val[0]); free($val); }
    | TAG[t] node_body { ir_prop_tag(ir, $t); free($t); }
    | node_props[p] node_body { ir_prop_both(ir, $p.anchor, $p.tag); free($p.anchor); free($p.tag); }
    | ALIAS[a] { ir_alias(ir, $a); add_alias_event($a); free($a); }
    | sequence
    | mapping
    ;

node_body: 
    plain_node
    ;

node_props:
    ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    ;

sequence:
    { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    seq_entries { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); } %dprec 3
    | LBRACK { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    flow_seq_entries RBRACK { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); }
    ;

seq_entries:
    seq_entry
    | seq_entries seq_entry
    ;

seq_entry:
    BULLET node
    | BULLET
    ;

flow_seq_entries:
    %empty
    | flow_seq_entry
    | flow_seq_entries COMMA flow_seq_entry
    ;

flow_seq_entry:
    node
    | %empty
    ;

mapping:
    { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    map_entries { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    | LBRACE { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    flow_map_entries RBRACE { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;

map_entries:
    map_entry
    | map_entries map_entry
    ;


map_entry:
    MAP_KEY[val] { ir_scalar_plain(ir, $val); add_scalar_event($val, ':'); free($val); } COLON node
    | QMAP_KEY[val] { ir_scalar_quoted(ir, $val, '"'); add_scalar_event($val, '"'); free($val); } COLON node
    | SMAP_KEY[val] { ir_scalar_quoted(ir, $val, '\''); add_scalar_event($val, '\''); free($val); } COLON node
    | QUESTION node COLON node
    ;

flow_map_entries:
    %empty
    | flow_map_entry
    | flow_map_entries COMMA flow_map_entry
    ;

flow_map_entry:
    node COLON node
    | node
    | %empty
    ;

%%

void stream_yy_error(void *yylloc, void *scanner, const char *s) {
    if (s) {
        fprintf(stderr, "Stream Parse Error: %s\n", s);
    }
}

/* Bison parser entry point */
extern int event_yy_parse(void);

/* Flex lexer functions */
extern int presentation_lex_init(void **scanner);
extern int presentation_lex_init_extra(void *user_defined, void **scanner);
extern int presentation_lex_destroy(void *scanner);
extern void presentation_set_in(FILE *in, void *scanner);
extern void presentation_set_extra(void *extra, void *scanner);

/**
 * Stage 1: Parse - Presentation -> Events
 * Reads YAML from stdin, produces event stream
 */
int yaml_parse(void) {
    void *scanner;
    LexerContext *ctx = lexer_context_new();
    if (!ctx) {
        fprintf(stderr, "Failed to create lexer context\n");
        return 1;
    }
    
    if (presentation_lex_init_extra(ctx, &scanner) != 0) {
        fprintf(stderr, "Failed to initialize lexer\n");
        return 1;
    }
    presentation_set_in(stdin, scanner);
    int result = stream_yy_parse(scanner);
    presentation_lex_destroy(scanner);
    lexer_context_free(ctx);
    return result;
}

/**
 * Stage 2: Compose - Events -> Representation (IR)
 * Composes IR from event stream
 */
int yaml_compose(void) {
    return event_yy_parse();
}

/**
 * Stage 3: Serialize - Representation -> Events
 * Creates event stream from IR (inverse of compose)
 */
int yaml_serialize(void) {
    /* Placeholder - to be implemented */
    return 0;
}

/**
 * Stage 4: Present - Events -> Presentation
 * Renders event stream back to YAML text
 */
int yaml_present(void) {
    /* Placeholder - to be implemented */
    return 0;
}
