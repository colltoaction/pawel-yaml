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
#include <stdarg.h>
#include "common.h"
#include "event_parser.h"
#include "lexer_context.h"

/* === TYPE DEFINITIONS (from ir_builder.h) === */
/**
 * IRBuilder: Encapsulates output destination for RML IR
 * Supports two modes: file mode (direct output) and memory mode (buffer)
 */
typedef struct {
    FILE *out;              /* Output stream for IR (file mode) */
    char *buffer;           /* Internal buffer (memory mode) */
    size_t buffer_size;     /* Current buffer size */
    size_t buffer_cap;      /* Buffer capacity */
} IRBuilder;

/* === EXTERNAL DECLARATIONS FROM scanning.l === */
/* These are defined in scanning.l as non-static functions */
extern LexerContext *lexer_context_new(void);
extern void lexer_context_free(LexerContext *ctx);

int scanning_lex(void *yylval_param, void *yyloc_param, void *yyscanner);
#define yylex scanning_lex
void parsing_yy_error(void *yylloc, void *scanner, const char *s);

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

/* === INLINED: ir_builder.c - RML IR Builder Implementation === */

/**
 * Internal helper: Write formatted output to IR builder
 */
static void ir_write(IRBuilder *b, const char *format, ...) {
    if (!b) return;
    
    va_list args;
    va_start(args, format);
    
    if (b->out) {
        /* File mode: direct output to stream */
        vfprintf(b->out, format, args);
    } else if (b->buffer) {
        /* Memory mode: append to buffer */
        va_list args_copy;
        va_copy(args_copy, args);
        
        /* Calculate required space */
        int needed = vsnprintf(NULL, 0, format, args_copy);
        va_end(args_copy);
        
        /* Grow buffer if needed */
        if (b->buffer_size + needed + 1 >= b->buffer_cap) {
            while (b->buffer_cap < b->buffer_size + needed + 1) {
                b->buffer_cap *= 2;
            }
            b->buffer = (char*)realloc(b->buffer, b->buffer_cap);
        }
        
        /* Write to buffer */
        vsprintf(b->buffer + b->buffer_size, format, args);
        b->buffer_size += needed;
    }
    
    va_end(args);
}

/**
 * Create IR builder for file output
 */
static IRBuilder *ir_builder_new_file(FILE *out) {
    IRBuilder *b = (IRBuilder*)malloc(sizeof(IRBuilder));
    if (!b) return NULL;
    
    b->out = out;
    b->buffer = NULL;
    b->buffer_size = 0;
    b->buffer_cap = 0;
    
    return b;
}

/**
 * Create IR builder for memory output
 */
static IRBuilder *ir_builder_new_memory(void) {
    IRBuilder *b = (IRBuilder*)malloc(sizeof(IRBuilder));
    if (!b) return NULL;
    
    b->out = NULL;
    b->buffer_cap = 4096;
    b->buffer = (char*)malloc(b->buffer_cap);
    b->buffer_size = 0;
    if (b->buffer) {
        b->buffer[0] = '\0';
    }
    
    return b;
}

/**
 * Free IR builder resources
 */
static void ir_builder_free(IRBuilder *b) {
    if (b) {
        if (b->buffer) {
            free(b->buffer);
        }
        free(b);
    }
}

/**
 * Finalize and retrieve memory buffer
 * Caller owns the returned string and must free() it
 * Returns NULL in file mode
 */
static char *ir_builder_finalize(IRBuilder *b) {
    if (!b || !b->buffer) return NULL;
    
    char *result = strdup(b->buffer);
    b->buffer_size = 0;
    if (b->buffer) {
        b->buffer[0] = '\0';
    }
    
    return result;
}

/**
 * Stream start marker
 * Format: +STR
 */
static void ir_stream_start(IRBuilder *b) {
    ir_write(b, "+STR\n");
}

/**
 * Stream end marker
 * Format: -STR
 */
static void ir_stream_end(IRBuilder *b) {
    ir_write(b, "-STR\n");
}

/**
 * Document start marker
 * Format: +DOC
 */
static void ir_doc_start(IRBuilder *b) {
    ir_write(b, "+DOC\n");
}

/**
 * Document end marker
 * Format: -DOC
 */
static void ir_doc_end(IRBuilder *b) {
    ir_write(b, "-DOC\n");
}

/**
 * Sequence start with optional properties
 * Format: +SEQ [&anchor] [!tag]
 */
static void ir_seq_start(IRBuilder *b, const char *anchor, const char *tag) {
    ir_write(b, "+SEQ");
    if (anchor) ir_write(b, " &%s", anchor);
    if (tag) ir_write(b, " !%s", tag);
    ir_write(b, "\n");
}

/**
 * Sequence end marker
 * Format: -SEQ
 */
static void ir_seq_end(IRBuilder *b) {
    ir_write(b, "-SEQ\n");
}

/**
 * Mapping start with optional properties
 * Format: +MAP [&anchor] [!tag]
 */
static void ir_map_start(IRBuilder *b, const char *anchor, const char *tag) {
    ir_write(b, "+MAP");
    if (anchor) ir_write(b, " &%s", anchor);
    if (tag) ir_write(b, " !%s", tag);
    ir_write(b, "\n");
}

/**
 * Mapping end marker
 * Format: -MAP
 */
static void ir_map_end(IRBuilder *b) {
    ir_write(b, "-MAP\n");
}

/**
 * Plain scalar value
 * Format: =VAL ::value
 */
static void ir_scalar_plain(IRBuilder *b, const char *value) {
    if (!value) value = "";
    ir_write(b, "=VAL :%s\n", value);
}

/**
 * Quoted scalar value
 * Format: =VAL ":value or =VAL ':value
 */
static void ir_scalar_quoted(IRBuilder *b, const char *value, char quote) {
    if (!value) value = "";
    ir_write(b, "=VAL %c:%s\n", quote, value);
}

/**
 * Block scalar value
 * Format: =VAL |:value or =VAL >:value
 */
static void ir_scalar_block(IRBuilder *b, const char *value, char type) {
    if (!value) value = "";
    ir_write(b, "=VAL %c:%s\n", type, value);
}

/**
 * Empty scalar value
 * Format: =VAL :
 */
static void ir_scalar_empty(IRBuilder *b) {
    ir_write(b, "=VAL :\n");
}

/**
 * Alias reference
 * Format: =ALI *name
 */
static void ir_alias(IRBuilder *b, const char *name) {
    if (!name) name = "";
    ir_write(b, "=ALI *%s\n", name);
}

/**
 * Anchor property alone
 * Format: P:&anchor
 */
static void ir_prop_anchor(IRBuilder *b, const char *anchor) {
    if (!anchor) return;
    ir_write(b, "P:&%s\n", anchor);
}

/**
 * Tag property alone
 * Format: P:!tag
 */
static void ir_prop_tag(IRBuilder *b, const char *tag) {
    if (!tag) return;
    ir_write(b, "P:!%s\n", tag);
}

/**
 * Both anchor and tag properties
 * Format: P:&anchor !tag
 */
static void ir_prop_both(IRBuilder *b, const char *anchor, const char *tag) {
    if (!anchor && !tag) return;
    ir_write(b, "P:");
    if (anchor) ir_write(b, "&%s", anchor);
    if (anchor && tag) ir_write(b, " ");
    if (tag) ir_write(b, "!%s", tag);
    ir_write(b, "\n");
}

/* === END INLINED: ir_builder.c === */

%}

%define api.pure true
%define api.prefix {parsing_yy_}
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
extern int composition_yy_parse(void);

/* Flex lexer functions */
extern int scanning_lex_init(void **scanner);
extern int scanning_lex_init_extra(void *user_defined, void **scanner);
extern int scanning_lex_destroy(void *scanner);
extern void scanning_set_in(FILE *in, void *scanner);
extern void scanning_set_extra(void *extra, void *scanner);

/**
 * Stage 1: Parse - Scanning -> Parsing (Presentation -> Events)
 * Reads YAML from stdin, produces event stream
 */
int yaml_parse(void) {
    void *scanner;
    LexerContext *ctx = lexer_context_new();
    if (!ctx) {
        fprintf(stderr, "Failed to create lexer context\n");
        return 1;
    }
    
    if (scanning_lex_init_extra(ctx, &scanner) != 0) {
        fprintf(stderr, "Failed to initialize lexer\n");
        return 1;
    }
    scanning_set_in(stdin, scanner);
    int result = parsing_yy_parse(scanner);
    scanning_lex_destroy(scanner);
    lexer_context_free(ctx);
    return result;
}

/**
 * Stage 2: Compose - Events -> Representation (IR)
 * Composes IR from event stream
 */
int yaml_compose(void) {
    return composition_yy_parse();
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

/* Error handler for parsing stage */
void parsing_yy_error(void *yylloc, void *scanner, const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}
