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
    int at_line_start;
    int complex_key_pending;
    int pending_colon;
    struct {
        char type;
        int indent;
        int leading_empty_max_indent;
        int first_content_seen;
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
    int quoted_value_closed_on_line;
    int semantic_error_count;
    int semantic_indent_tab_count;
    int semantic_indent_mismatch_count;
    int semantic_directive_mid_doc_count;
    int semantic_flow_glue_count;
    int semantic_flow_comma_count;
    int semantic_flow_leading_comma_count;
    int semantic_flow_comment_comma_count;
    int semantic_flow_key_newline_count;
    int semantic_multiline_qkey_count;
    int semantic_inline_key_count;
    int semantic_doc_end_inline_count;
    int flow_implicit_key_candidate;
    int flow_delim_stack[100];
    int flow_indent_ref_stack[100];
    int flow_indent_required_stack[100];
    int flow_delim_sp;
    int semantic_flow_indent_count;
    int open_document_started;
    int yaml_directive_seen;
    int argc;
    char **argv;
} LexerContext;

typedef struct {
    char type;      /* Quote style: ':', '"', '\'', '*' (alias), '&' (anchored) */
    char *value;    /* Key text */
    char *anchor;   /* Anchor name (without '&' prefix) or NULL */
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
%expect 85
%expect-rr 123

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

/* Error tracking for extensive recovery */
static int parse_error_count = 0;
static void parser_report_error(void *scanner, const char *msg) {
    parsing_yy_error(NULL, scanner, msg);
}

#define RECOVER(msg) do { parser_report_error(scanner, (msg)); } while(0)
#define RECOVER_SYNC(msg) do { parser_report_error(scanner, (msg)); yyerrok; } while(0)

static int validate_lexical_semantics(const LexerContext *ctx, void *scanner) {
    char errbuf[512];

    if (!ctx) return 0;
    if (ctx->semantic_error_count <= 0) return 0;

    snprintf(errbuf, sizeof(errbuf),
             "semantic policy violations: %d (tab-leading lines: %d, indent-mismatch lines: %d, directive-mid-doc lines: %d, flow-glue lines: %d, flow-comma lines: %d, flow-leading-comma lines: %d, flow-comma-comment lines: %d, flow-key-newline lines: %d, flow-indent lines: %d, multiline-qkey lines: %d, inline-keys: %d, doc-end-inline lines: %d)",
             ctx->semantic_error_count,
             ctx->semantic_indent_tab_count,
             ctx->semantic_indent_mismatch_count,
             ctx->semantic_directive_mid_doc_count,
             ctx->semantic_flow_glue_count,
             ctx->semantic_flow_comma_count,
             ctx->semantic_flow_leading_comma_count,
             ctx->semantic_flow_comment_comma_count,
             ctx->semantic_flow_key_newline_count,
             ctx->semantic_flow_indent_count,
             ctx->semantic_multiline_qkey_count,
             ctx->semantic_inline_key_count,
             ctx->semantic_doc_end_inline_count);
    parser_report_error(scanner, errbuf);
    return 1;
}

static YAMLEvent *new_event(YAMLEventType type) {
    YAMLEvent *evt = (YAMLEvent*)malloc(sizeof(YAMLEvent));
    if (!evt) return NULL;
    evt->type = type;
    evt->quote_style = 0;
    evt->value = NULL;
    evt->anchor = NULL;
    evt->tag = NULL;
    evt->explicit_start = 0;
    evt->alias_name = NULL;
    return evt;
}

static int ensure_event_capacity(EventStream *stream) {
    YAMLEvent **grown;
    int new_capacity;

    if (!stream) return 0;
    if (stream->count < stream->capacity) return 1;

    new_capacity = (stream->capacity + 1) * 2;
    grown = (YAMLEvent**)realloc(stream->events, new_capacity * sizeof(YAMLEvent*));
    if (!grown) return 0;

    stream->events = grown;
    stream->capacity = new_capacity;
    return 1;
}

static void append_event(YAMLEvent *evt) {
    if (!current_event_stream || !evt) {
        free(evt);
        return;
    }
    if (!ensure_event_capacity(current_event_stream)) {
        free(evt->value);
        free(evt->anchor);
        free(evt->tag);
        free(evt->alias_name);
        free(evt);
        return;
    }
    current_event_stream->events[current_event_stream->count++] = evt;
}

/* Helper: Add event to the stream */
static void add_event(YAMLEventType type) {
    append_event(new_event(type));
}

/* Helper: Add scalar event */
static void add_scalar_event(const char *value, char quote_style) {
    if (!current_event_stream || !value) return;

    YAMLEvent *evt = new_event(EVENT_SCALAR);
    if (!evt) return;
    evt->quote_style = quote_style;
    evt->value = strdup(value);
    append_event(evt);
}

/* Helper: Add alias event */
static void add_alias_event(const char *name) {
    if (!current_event_stream || !name) return;

    YAMLEvent *evt = new_event(EVENT_ALIAS);
    if (!evt) return;
    evt->alias_name = strdup(name);
    append_event(evt);
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

/* Escape line breaks so each IR event stays on one physical line. */
static char *ir_escape_scalar_value(const char *value) {
    if (!value) return strdup("");
    size_t len = strlen(value);
    char *out = (char*)malloc(len * 2 + 1);
    if (!out) return strdup("");
    size_t j = 0;
    for (size_t i = 0; i < len; i++) {
        if (value[i] == '\n') {
            out[j++] = '\\';
            out[j++] = 'n';
        } else if (value[i] == '\r') {
            out[j++] = '\\';
            out[j++] = 'r';
        } else {
            out[j++] = value[i];
        }
    }
    out[j] = '\0';
    return out;
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

/*
 * Render tag once in IR.
 * Scanner already returns tags with YAML sigils (e.g. !foo, !!str), so
 * we only add a leading '!' when the value is a bare handle/name.
 */
static void ir_write_tag(IRBuilder *b, const char *tag) {
    if (!tag || !*tag) return;
    if (tag[0] == '!' || tag[0] == '<') {
        ir_write(b, " %s", tag);
    } else {
        ir_write(b, " !%s", tag);
    }
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
    if (anchor) ir_write(b, " &%s", anchor[0] == '&' ? anchor + 1 : anchor);
    ir_write_tag(b, tag);
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
    if (anchor) ir_write(b, " &%s", anchor[0] == '&' ? anchor + 1 : anchor);
    ir_write_tag(b, tag);
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
    char *escaped = ir_escape_scalar_value(value);
    ir_write(b, "=VAL");
    if (anchor) ir_write(b, " &%s", anchor[0] == '&' ? anchor + 1 : anchor);
    ir_write_tag(b, tag);
    if (style == ':') {
        ir_write(b, " :%s\n", escaped);
    } else if (style == '|' || style == '>') {
        /* Tree format: block style followed immediately by value */
        ir_write(b, " %c%s\n", style, escaped);
    } else {
        ir_write(b, " %c :%s\n", style, escaped);
    }
    free(escaped);
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
    if (name[0] == '*') name++;
    ir_write(b, "=ALI *%s\n", name);
}

static void emit_map_key(const ScalarValue *k) {
    if (!k || !k->value) return;
    
    if (k->type == '*') {
        /* Alias as map key */
        ir_alias(ir, k->value);
        add_alias_event(k->value);
    } else {
        /* Regular key (plain, quoted, or anchored) */
        ir_scalar(ir, k->value, k->type, k->anchor, NULL);
        add_scalar_event(k->value, k->type);
    }
}

/**
 * Parse anchored map key from lexer-provided tab-delimited format
 * Input: "&anchor\tkey" (from ANCHOR_MAP_KEY token)
 * Output: Populates scalar.anchor and scalar.value fields
 * 
 * Format contract with lexer:
 * - Anchor name with '&' prefix
 * - Tab delimiter (\t)
 * - Key text (already trimmed by lexer)
 */
static ScalarValue parse_anchored_map_key(char *delimited_string) {
    ScalarValue result;
    result.type = ':';
    result.anchor = NULL;
    result.value = NULL;
    
    if (!delimited_string) {
        result.value = strdup("");
        return result;
    }
    
    /* Find tab delimiter */
    char *tab = strchr(delimited_string, '\t');
    if (tab) {
        /* Split at tab: "&anchor" and "key" */
        *tab = '\0';
        
        /* Extract anchor name (skip '&' prefix if present) */
        const char *anchor_start = delimited_string;
        if (anchor_start[0] == '&') anchor_start++;
        result.anchor = strdup(anchor_start);
        
        /* Extract key text */
        result.value = strdup(tab + 1);
        
        free(delimited_string);
    } else {
        /* No delimiter: treat as plain key (fallback) */
        result.anchor = NULL;
        result.value = delimited_string;
    }
    
    return result;
}

static char *concat_and_free(char *left, char *right) {
    size_t left_len;
    size_t right_len;
    char *out;

    if (!left) left = strdup("");
    if (!right) right = strdup("");
    if (!left || !right) {
        free(left);
        free(right);
        return strdup("");
    }

    left_len = strlen(left);
    right_len = strlen(right);
    out = (char*)malloc(left_len + right_len + 1);
    if (!out) {
        free(left);
        free(right);
        return strdup("");
    }

    memcpy(out, left, left_len);
    memcpy(out + left_len, right, right_len + 1);
    free(left);
    free(right);
    return out;
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
%define parse.error verbose
%locations
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    NodeProps props;
    ScalarValue scalar;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS MAP_KEY QMAP_KEY SMAP_KEY ANCHOR_MAP_KEY QPART BPART
%token BAD_TAG
%token <string> CH_RAW CH_ESC_N CH_ESC_T CH_ESC_R CH_ESC_0 CH_ESC_BS CH_ESC_QU CH_ESC_SL
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET BULLET_EOL COLON COLON_EMPTY COLON_IMPLICIT QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%type <props> node_props
%type <scalar> scalar_item
%type <scalar> map_key
%type <string> scalar_parts qscalar qparts qpart bscalar

/* TODO Fix destructor double free in GLR mode + manual free in actions */
/* Destructors removed to avoid double free in GLR mode + manual free in actions */
/* %destructor { if ($$) { free($$); $$ = NULL; } } <string> */
/* %destructor { if ($$.anchor) { free($$.anchor); $$.anchor = NULL; } if ($$.tag) { free($$.tag); $$.tag = NULL; } } <props> */
/* %destructor { if ($$.value) { free($$.value); $$.value = NULL; } } <scalar> */

%locations

/* Precedence declarations for disambiguation */
%left COMMA RBRACE RBRACK
%precedence COLON
%precedence SCALAR QSCALAR SSCALAR BSCALAR

%%

stream:
    stream_init documents stream_finish
    ;

stream_init:
    %empty { ir = ir_builder_new_memory(); add_event(EVENT_STREAM_START); ir_stream_start(ir); }
    ;

stream_finish:
    %empty {
        ir_stream_end(ir);
        rml_ir_buf = ir_builder_finalize(ir);
        rml_ir_size = strlen(rml_ir_buf);
        ir_builder_free(ir);
        ir = NULL;
        add_event(EVENT_STREAM_END);
    }
    ;

documents:
    %empty
    | implicit_document
    | implicit_document DOC_END
    | implicit_document DOC_END explicit_documents
    | explicit_documents
    | explicit_documents bare_doc_after_explicit
    | implicit_document explicit_documents
    | DOC_END
    | DOC_END explicit_documents
    ;

bare_doc_after_explicit:
    DOC_END doc_start node doc_end
    | DOC_END doc_start INDENT node DEDENT doc_end
    ;

doc_start:
    %empty { ir_doc_start(ir); add_event(EVENT_DOCUMENT_START); }
    ;

doc_end:
    %empty { ir_doc_end(ir); add_event(EVENT_DOCUMENT_END); }
    ;

doc_empty:
    %empty { ir_scalar_empty(ir); add_scalar_event("", ':'); }
    ;

directives:
    directive
    | directives directive
    ;

directive:
    YAML_DIRECTIVE
    | TAG_DIRECTIVE SCALAR SCALAR { free($2); free($3); }
    | TAG_DIRECTIVE TAG SCALAR { free($2); free($3); }
    ;

explicit_documents:
    explicit_document
    | explicit_documents explicit_document
    | explicit_documents error DOC_END { RECOVER_SYNC("Skipping malformed document"); }
    ;

explicit_document:
    DOC_START doc_start node doc_end optional_doc_end
    | DOC_START doc_start INDENT node DEDENT doc_end optional_doc_end
    | DOC_START doc_start doc_empty DOC_END doc_end
    | DOC_START doc_start doc_empty doc_end
    | directives DOC_START doc_start node doc_end optional_doc_end
    | directives DOC_START doc_start INDENT node DEDENT doc_end optional_doc_end
    | directives DOC_START doc_start doc_empty DOC_END doc_end
    | directives DOC_START doc_start doc_empty doc_end
    ;

optional_doc_end:
    %empty
    | DOC_END
    ;

implicit_document:
    doc_start node doc_end
    | doc_start INDENT node DEDENT doc_end
    ;

node:
    scalar_node
    | alias_node
    | sequence_no_props
    | node_props[p] sequence_with_props { free($p.anchor); free($p.tag); }
    | mapping_no_props
    | node_props[p] mapping_with_props { free($p.anchor); free($p.tag); }
    | error { RECOVER("Recovering at node boundary"); }
    ;

scalar_node:
    scalar_item[s] { ir_scalar(ir, $s.value, $s.type, NULL, NULL); add_scalar_event($s.value, $s.type); free($s.value); }
    | node_props[p] scalar_item[s] { ir_scalar(ir, $s.value, $s.type, $p.anchor, $p.tag); add_scalar_event($s.value, $s.type); free($s.value); free($p.anchor); free($p.tag); }
    | node_props[p] { ir_scalar(ir, "", ':', $p.anchor, $p.tag); add_scalar_event("", ':'); free($p.anchor); free($p.tag); }
    ;

alias_node:
    ALIAS[a] { ir_alias(ir, $a); add_alias_event($a); free($a); }
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
    | scalar_parts CH_RAW { $$ = concat_and_free($1, $2); }
    ;

qparts:
    %empty { $$ = strdup(""); }
    | qparts qpart { $$ = concat_and_free($1, $2); }
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
    | bscalar BPART { $$ = concat_and_free($1, $2); }
    ;

node_props:
    ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    | TAG[t] ANCHOR[a] { $$.anchor = $a; $$.tag = $t; }
    | BAD_TAG { RECOVER_SYNC("Malformed tag syntax"); $$.anchor = NULL; $$.tag = NULL; }
    | error { RECOVER("Invalid node properties"); $$.anchor = NULL; $$.tag = NULL; }
    ;

sequence_no_props:
    seq_start seq_entries seq_end %dprec 3
    | LBRACK flow_seq_init flow_seq_entries RBRACK seq_end flow_lvl_dec
    ;

flow_lvl_dec:
    %empty { ((LexerContext*)scanning_get_extra(scanner))->flow_level--; }
    ;

seq_start:
    %empty { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    ;

seq_end:
    %empty { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); }
    ;

flow_seq_init:
    %empty { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    ;

sequence_with_props:
    seq_start_with_props seq_entries seq_end %dprec 3
    | INDENT seq_start_with_props seq_entries DEDENT seq_end %dprec 3
    | LBRACK flow_seq_init_with_props flow_seq_entries RBRACK seq_end flow_lvl_dec
    ;

seq_start_with_props:
    %empty { ir_seq_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_SEQUENCE_START); }
    ;

flow_seq_init_with_props:
    %empty { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_seq_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_SEQUENCE_START); }
    ;

seq_entries:
    seq_entry
    | seq_entries seq_entry
    ;

seq_entry:
    BULLET node %dprec 5
    | BULLET BULLET { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); } node INDENT seq_entries DEDENT { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); } %dprec 6
    | BULLET map_key[k] { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); emit_map_key(&$k); free($k.value); free($k.anchor); } COLON node INDENT map_entries DEDENT { ir_map_end(ir); add_event(EVENT_MAPPING_END); } %dprec 6
    | BULLET_EOL INDENT { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); } map_entries DEDENT { ir_map_end(ir); add_event(EVENT_MAPPING_END); } %dprec 4
    | BULLET_EOL INDENT seq_entries DEDENT %dprec 3
    | BULLET error { RECOVER("Malformed sequence item"); } %dprec 2
    | BULLET_EOL error { RECOVER("Malformed sequence item"); } %dprec 2
    ;

flow_seq_entries:
    %empty
    | flow_seq_entry
    | flow_seq_entries COMMA flow_seq_entry
    | flow_seq_entries COMMA
    ;

flow_seq_entry:
    node
    | node COLON node %dprec 1
    | error { RECOVER("Malformed flow sequence entry"); }
    ;

mapping_no_props:
    map_init map_entries map_end
    | LBRACE flow_map_init flow_map_entries RBRACE map_end flow_lvl_dec
    ;

map_init:
     %empty { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    ;

map_end:
    %empty { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;

flow_map_init:
    %empty { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    ;

mapping_with_props:
    map_start_with_props map_entries map_end
    | INDENT map_start_with_props map_entries DEDENT map_end
    | LBRACE flow_map_init_with_props flow_map_entries RBRACE map_end flow_lvl_dec
    ;

map_start_with_props:
    %empty { ir_map_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_MAPPING_START); }
    ;

flow_map_init_with_props:
    %empty { ((LexerContext*)scanning_get_extra(scanner))->flow_level++; ir_map_start(ir, $<props>0.anchor, $<props>0.tag); add_event(EVENT_MAPPING_START); }
    ;

map_entries:
    map_entry
    | map_entries map_entry
    ;

map_key:
    MAP_KEY[val] { $$.type = ':'; $$.value = $val; $$.anchor = NULL; }
    | QMAP_KEY[val] { $$.type = '"'; $$.value = $val; $$.anchor = NULL; }
    | SMAP_KEY[val] { $$.type = '\''; $$.value = $val; $$.anchor = NULL; }
    | ANCHOR_MAP_KEY[val] { $$ = parse_anchored_map_key($val); }
    ;

map_entry:
    map_key[k] { emit_map_key(&$k); free($k.value); free($k.anchor); } COLON node %dprec 1
    | map_key[k] { emit_map_key(&$k); free($k.value); free($k.anchor); } COLON INDENT node DEDENT %dprec 2
    | map_key[k] { emit_map_key(&$k); free($k.value); free($k.anchor); } COLON { ir_scalar_empty(ir); add_scalar_event("", ':'); }
    | map_key[k] { emit_map_key(&$k); free($k.value); free($k.anchor); } COLON_IMPLICIT { ir_scalar_empty(ir); add_scalar_event("", ':'); }
    | QUESTION node COLON node %dprec 2
    | QUESTION INDENT node DEDENT COLON node %dprec 3
    | QUESTION node COLON INDENT node DEDENT %dprec 3
    | QUESTION INDENT node DEDENT COLON INDENT node DEDENT %dprec 4
    | QUESTION node { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
    | QUESTION INDENT node DEDENT { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 2
    | MAP_KEY error { RECOVER("Malformed mapping entry"); }
    | QMAP_KEY error { RECOVER("Malformed mapping entry"); }
    | SMAP_KEY error { RECOVER("Malformed mapping entry"); }
    | QUESTION error { RECOVER("Malformed complex mapping entry"); }
    | error { RECOVER("Invalid mapping structure"); }
    ;

flow_map_entries:
    %empty
    | flow_map_entry
    | flow_map_entries COMMA flow_map_entry
    | flow_map_entries COMMA
    ;

flow_map_entry:
    node COLON node %dprec 3
    | node COLON_EMPTY { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 2
    | node { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 2
    | node COLON { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
    | error { RECOVER("Malformed flow mapping entry"); }
    ;

%%

void stream_yy_error(void *yylloc, void *scanner, const char *s) {
    if (s) {
        parsing_yy_error(yylloc, scanner, s);
    }
}



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
        parsing_yy_error(NULL, NULL, "Failed to create lexer context");
        return 1;
    }
    
    /* Initialize reentrant scanner with lexer context as user-defined data */
    if (scanning_lex_init_extra(ctx, &scanner) != 0) {
        parsing_yy_error(NULL, NULL, "Failed to initialize lexer");
        lexer_context_free(ctx);
        return 1;
    }
    
    /* Reset error count for this run */
    parse_error_count = 0;
    
    /* Scanner now manages stdin internally; just parse */
    int result = parsing_yy_parse(scanner);

    if (result == 0 && validate_lexical_semantics(ctx, scanner) != 0) {
        result = 1;
    }
    
    /* If errors occurred but we recovered, still signal failure to caller */
    if (parse_error_count > 0 && result == 0) {
        result = 1;
    }
    
    /* Cleanup */
    scanning_lex_destroy(scanner);
    lexer_context_free(ctx);
    
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
 * 
 * This function is invoked automatically by the parser when:
 * - A syntax error is detected (unexpected token)
 * - Error recovery is initiated (via 'error' token in grammar)
 * 
 * The parser will attempt to recover by:
 * 1. Discarding tokens until it finds a valid synchronization point
 * 2. Matching the 'error' token in the grammar
 * 3. Calling yyerrok to resume normal parsing
 */
void parsing_yy_error(void *yylloc, yyscan_t scanner, const char *s) {
    (void)scanner;
    parse_error_count++;
    if (yylloc) {
        PARSING_YY_LTYPE *loc = (PARSING_YY_LTYPE*)yylloc;
        if (loc->first_line > 0) {
            fprintf(stderr, "[PARSE] %d:%d: %s\n",
                    loc->first_line, loc->first_column,
                    s ? s : "syntax error");
            return;
        }
    }
    fprintf(stderr, "[PARSE] %s\n", s ? s : "syntax error");
}
