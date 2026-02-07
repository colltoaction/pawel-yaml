%code top {
/* Forward declare yyscan_t for reentrant scanner type safety */
typedef void* yyscan_t;
}

%code requires {
/* === LEXER CONTEXT TYPE (defined in scanning.l) === */
/* Forward declaration - full type defined in scanning.l/scanning.lex.c */
typedef struct {
    int indent_stack[100];
    int indent_sp;
    int flow_level;
    int expecting_value;
    int pending_dedents;
    int first_line;
    int last_was_value;
    struct {
        char type;
        int indent;
    } block_scalar;
    struct {
        char *content;
        int len;
        int cap;
    } scalar;
    struct {
        int level;
        int is_flow;
        char context_type;
    } indent_context_stack[100];
    int indent_context_sp;
    int scalar_base_indent;
    char scalar_type;
    int argc;
    char **argv;
} LexerContext;

typedef struct {
    char type;
    char *value;
} ScalarValue;

/* === TYPE DEFINITIONS (from common.h) === */
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

/* === TYPE DEFINITIONS (from event_parser.h) === */
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

/* Pipeline stage exports */
int yaml_parse(void);
int yaml_compose(void);
int yaml_serialize(void);
int yaml_present(void);
}

%glr-parser
%expect 26
%expect-rr 16

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include "parsing.tab.h"  /* Include generated header for type definitions */

/* Types are declared in %code requires and included via parsing.tab.h */

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
extern void* scanning_get_extra(void *scanner);

/* Output buffer for RML IR */
char *rml_ir_buf = NULL;
size_t rml_ir_size = 0;
static IRBuilder *ir = NULL;

/* Global yyout definition for flag-based functionality */
FILE *yyout = NULL;

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

static void ir_scalar(IRBuilder *b, const char *value, char style, const char *anchor, const char *tag) {
    if (!value) value = "";
    ir_write(b, "=VAL");
    if (anchor) ir_write(b, " &%s", anchor);
    if (tag) ir_write(b, " !%s", tag);
    if (style == ':') {
        ir_write(b, " :%s\n", value);
    } else {
        ir_write(b, " %c :%s\n", style, value);
    }
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
    /* Deprecated */
}

/**
 * Tag property alone
 * Format: P:!tag
 */
static void ir_prop_tag(IRBuilder *b, const char *tag) {
    /* Deprecated */
}

/**
 * Both anchor and tag properties
 * Format: P:&anchor !tag
 */
static void ir_prop_both(IRBuilder *b, const char *anchor, const char *tag) {
    /* Deprecated - properties now passed directly to node emission */
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
    ScalarValue scalar;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS MAP_KEY QMAP_KEY SMAP_KEY QPART BPART
%token <string> CH_RAW CH_ESC_N CH_ESC_T CH_ESC_R CH_ESC_0 CH_ESC_BS CH_ESC_QU CH_ESC_SL
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET COLON QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%type <props> node_props
%type <scalar> scalar_item
%type <string> scalar_parts qscalar qparts qpart bscalar

/* TODO Fix destructor double free in GLR mode + manual free in actions */
/* Destructors removed to avoid double free in GLR mode + manual free in actions */
/* %destructor { if ($$) { free($$); $$ = NULL; } } <string> */
/* %destructor { if ($$.anchor) { free($$.anchor); $$.anchor = NULL; } if ($$.tag) { free($$.tag); $$.tag = NULL; } } <props> */
/* %destructor { if ($$.value) { free($$.value); $$.value = NULL; } } <scalar> */

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
    scalar_item[s] { ir_scalar(ir, $s.value, $s.type, NULL, NULL); add_scalar_event($s.value, $s.type); free($s.value); }
    | node_props[p] scalar_item[s] { ir_scalar(ir, $s.value, $s.type, $p.anchor, $p.tag); add_scalar_event($s.value, $s.type); free($s.value); free($p.anchor); free($p.tag); }
    | ALIAS[a] { ir_alias(ir, $a); add_alias_event($a); free($a); }
    | sequence_no_props
    | node_props[p] sequence_with_props { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); free($p.anchor); free($p.tag); }
    | mapping_no_props
    | node_props[p] mapping_with_props { ir_map_end(ir); add_event(EVENT_MAPPING_END); free($p.anchor); free($p.tag); }
    ;

scalar_item:
    scalar_parts { $$.type = ':'; $$.value = $1; }
    | qscalar { $$.type = '"'; $$.value = $1; }
    | SSCALAR[val] { $$.type = '\''; $$.value = $val; }
    | bscalar { $$.type = '|'; /* Placeholder type, fix later */ $$.value = $1; }
    ;

qscalar:
    qparts QSCALAR { $$ = $1; }
    ;

scalar_parts:
    CH_RAW { $$ = $1; }
    | scalar_parts CH_RAW {
        char *s = malloc(strlen($1) + strlen($2) + 1);
        strcpy(s, $1);
        strcat(s, $2);
        free($1); free($2);
        $$ = s;
    }
    ;

qparts:
    %empty { $$ = strdup(""); }
    | qparts qpart {
        char *s = malloc(strlen($1) + strlen($2) + 1);
        strcpy(s, $1);
        strcat(s, $2);
        free($1); free($2);
        $$ = s;
    }
    ;

qpart:
    CH_RAW { $$ = $1; }
    | CH_ESC_N { $$ = strdup("\n"); free($1); }
    | CH_ESC_T { $$ = strdup("\t"); free($1); }
    | CH_ESC_R { $$ = strdup("\r"); free($1); }
    | CH_ESC_BS { $$ = strdup("\\"); free($1); }
    | CH_ESC_QU { $$ = strdup("\""); free($1); }
    | CH_ESC_SL { $$ = strdup("/"); free($1); }
    | CH_ESC_0 { $$ = strdup("\0"); free($1); }
    ;

bscalar:
    BPART { $$ = $1; }
    | bscalar BPART {
        char *s = malloc(strlen($1) + strlen($2) + 1);
        strcpy(s, $1);
        strcat(s, $2);
        free($1); free($2);
        $$ = s;
    }
    ;

node_props:
    ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    ;

sequence_no_props:
    { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    seq_entries { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); } %dprec 3
    | LBRACK { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    flow_seq_entries RBRACK { ((LexerContext*)scanning_get_extra(scanner))->flow_level--; ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); }
    ;

sequence_with_props:
    { ir_seq_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_SEQUENCE_START); }
    seq_entries %dprec 3
    | LBRACK { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_seq_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_SEQUENCE_START); }
    flow_seq_entries RBRACK { ((LexerContext*)scanning_get_extra(scanner))->flow_level--; }
    ;

seq_entries:
    seq_entry
    | seq_entries seq_entry
    ;

seq_entry:
    BULLET node %dprec 1
    | BULLET INDENT seq_entries DEDENT %dprec 2
    | BULLET %dprec 3
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

mapping_no_props:
    { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    map_entries { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    | LBRACE { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    flow_map_entries RBRACE { ((LexerContext*)scanning_get_extra(scanner))->flow_level--; ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;

mapping_with_props:
    { ir_map_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_MAPPING_START); }
    map_entries
    | LBRACE { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_map_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_MAPPING_START); }
    flow_map_entries RBRACE { ((LexerContext*)scanning_get_extra(scanner))->flow_level--; }
    ;

map_entries:
    map_entry
    | map_entries map_entry
    ;


map_entry:
    MAP_KEY[val] { ir_scalar(ir, $val, ':', NULL, NULL); add_scalar_event($val, ':'); free($val); } COLON node %dprec 1
    | MAP_KEY[val] { ir_scalar(ir, $val, ':', NULL, NULL); add_scalar_event($val, ':'); free($val); } COLON INDENT map_entries DEDENT %dprec 2
    | QMAP_KEY[val] { ir_scalar(ir, $val, '"', NULL, NULL); add_scalar_event($val, '"'); free($val); } COLON node %dprec 1
    | QMAP_KEY[val] { ir_scalar(ir, $val, '"', NULL, NULL); add_scalar_event($val, '"'); free($val); } COLON INDENT map_entries DEDENT %dprec 2
    | SMAP_KEY[val] { ir_scalar(ir, $val, '\'', NULL, NULL); add_scalar_event($val, '\''); free($val); } COLON node %dprec 1
    | SMAP_KEY[val] { ir_scalar(ir, $val, '\'', NULL, NULL); add_scalar_event($val, '\''); free($val); } COLON INDENT map_entries DEDENT %dprec 2
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

/* Flex lexer functions - "Just the Scanner" pattern */
/* The reentrant scanner manages its own input/output state */
extern int scanning_lex_init_extra(void *user_defined, yyscan_t *scanner);
extern int scanning_lex_destroy(yyscan_t scanner);

/**
 * Stage 1: Parse - Scanning -> Parsing (Presentation -> Events)
 * 
 * Architecture: The reentrant scanner object manages its own input state.
 * By default it reads from stdin. No explicit file redirection needed.
 * This simplifies the interface and relies on Flex's internal state management.
 */
int yaml_parse(void) {
    yyscan_t scanner;
    LexerContext *ctx = lexer_context_new();
    if (!ctx) {
        fprintf(stderr, "Failed to create lexer context\n");
        return 1;
    }
    
    /* Initialize reentrant scanner with lexer context as user-defined data */
    if (scanning_lex_init_extra(ctx, &scanner) != 0) {
        fprintf(stderr, "Failed to initialize lexer\n");
        lexer_context_free(ctx);
        return 1;
    }
    
    /* Scanner now manages stdin internally; just parse */
    int result = parsing_yy_parse(scanner);
    
    /* Cleanup */
    scanning_lex_destroy(scanner);
    lexer_context_free(ctx);
    
    return result;
}

/* Composition stage scanner functions - uses string scanning model */
extern void *composition__scan_string(const char *);
extern void composition__delete_buffer(void *);

/**
 * Stage 2: Compose - Events -> Representation (IR)
 * 
 * Transforms the RML IR (generated by parsing stage 1) into composed form.
 * Uses composition scanner to parse the IR buffer we previously generated.
 * 
 * String scanning model: composition stage reads from a memory buffer
 * (the IR output from parsing), not from stdin.
 */
int yaml_compose(void) {
    if (!rml_ir_buf) {
        fprintf(stderr, "No IR buffer to compose\n");
        return 1;
    }
    
    /* Create scanner for IR buffer (memory-based, not stdin) */
    void *buf = composition__scan_string(rml_ir_buf);
    if (!buf) {
        fprintf(stderr, "Failed to create composition scanner for IR buffer\n");
        return 1;
    }
    
    /* Parse the IR */
    int result = composition_yy_parse();
    
    /* Cleanup scanner */
    composition__delete_buffer(buf);
    
    return result;
}

/**
 * Stage 3: Serialize - Representation -> Events
 * 
 * Creates event stream from IR representation.
 * (Inverse of compose stage: transforms IR back to events)
 * 
 * Placeholder for future implementation.
 */
int yaml_serialize(void) {
    /* Placeholder - to be implemented */
    return 0;
}

/**
 * Stage 4: Present - Events -> Presentation
 * 
 * Renders event stream back to YAML document text.
 * Final output stage producing user-readable YAML.
 * 
 * Placeholder for future implementation.
 */
int yaml_present(void) {
    /* Placeholder - to be implemented */
    return 0;
}

/**
 * Error handler for parsing stage
 * Called by Bison when a syntax error occurs
 */
void parsing_yy_error(void *yylloc, yyscan_t scanner, const char *s) {
    if (s) {
        fprintf(stderr, "Parse error: %s\n", s);
    } else {
        fprintf(stderr, "Parse error: syntax error\n");
    }
}
