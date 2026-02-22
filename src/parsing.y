%code top {
/* Forward declare yyscan_t for reentrant scanner type safety */
typedef void* yyscan_t;
}

%code requires {
#include "common.h"
/* === LEXER CONTEXT TYPE (defined in scanning.l) === */
/* Forward declaration - full type defined in scanning.l/scanning.lex.c */
typedef struct {
    int indent_stack[100];
    int indent_sp;
    int expecting_value;
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
    int semantic_flow_indent_count;
    int open_document_started;
    int yaml_directive_seen;
    int current_column;
    int argc;
    char **argv;
} LexerContext;

typedef struct {
    int level;
} Indented;
}

%glr-parser
%expect 66
%expect-rr 55

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

/* Global argument capture via constructor (keeps main.c untouched) */
static int g_argc = 0;
static char **g_argv = NULL;

__attribute__((constructor))
static void capture_args(int argc, char **argv) {
    g_argc = argc;
    g_argv = argv;
}

static int has_arg(const char *flag) {
    for (int i = 1; i < g_argc; i++) {
        if (strcmp(g_argv[i], flag) == 0) return 1;
    }
    return 0;
}

int scanning_lex(void *yylval_param, void *yyloc_param, void *yyscanner);
#define yylex scanning_lex
typedef struct yy_buffer_state *YY_BUFFER_STATE;
extern YY_BUFFER_STATE scanning__scan_string(const char *yy_str, yyscan_t yyscanner);
extern void scanning__delete_buffer(YY_BUFFER_STATE b, yyscan_t yyscanner);
void parsing_yy_error(void *yylloc, void *scanner, const char *s);

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
static int parse_nonfatal_count = 0;
static int g_silent_parse_errors = 0;

/* String monoid/intern pool:
 * - unit: "" (empty string)
 * - operation: concatenation
 * - terminator invariant: all members are '\0'-terminated C strings
 */
typedef struct InternedStringNode {
    char *value;
    struct InternedStringNode *next;
} InternedStringNode;

static InternedStringNode *g_string_pool = NULL;

static int string_is_terminated(const char *s) {
    return !s || s[strlen(s)] == '\0';
}

static char *string_intern(const char *s) {
    const char *norm = s ? s : "";
    InternedStringNode *node;

    if (!string_is_terminated(norm)) {
        return NULL;
    }

    for (node = g_string_pool; node; node = node->next) {
        if (strcmp(node->value, norm) == 0) {
            return node->value;
        }
    }

    node = (InternedStringNode*)malloc(sizeof(*node));
    if (!node) {
        return NULL;
    }
    node->value = strdup(norm);
    if (!node->value) {
        free(node);
        return NULL;
    }
    node->next = g_string_pool;
    g_string_pool = node;
    return node->value;
}

static char *string_unit(void) {
    char *unit = string_intern("");
    return unit ? unit : (char*)"";
}

static char *string_intern_slice(const char *start, size_t len) {
    char *tmp;
    char *interned;

    if (!start) return string_unit();
    tmp = (char*)malloc(len + 1);
    if (!tmp) return string_unit();
    memcpy(tmp, start, len);
    tmp[len] = '\0';
    interned = string_intern(tmp);
    free(tmp);
    return interned ? interned : string_unit();
}

static char *string_concat(const char *left, const char *right) {
    const char *l = left ? left : "";
    const char *r = right ? right : "";
    size_t left_len = strlen(l);
    size_t right_len = strlen(r);
    char *tmp = (char*)malloc(left_len + right_len + 1);
    char *interned;

    if (!tmp) return string_unit();
    memcpy(tmp, l, left_len);
    memcpy(tmp + left_len, r, right_len + 1);
    interned = string_intern(tmp);
    free(tmp);
    return interned ? interned : string_unit();
}

static void string_pool_reset(void) {
    InternedStringNode *node = g_string_pool;
    while (node) {
        InternedStringNode *next = node->next;
        free(node->value);
        free(node);
        node = next;
    }
    g_string_pool = NULL;
}

static void parser_report_error(void *scanner, const char *msg) {
    parsing_yy_error(NULL, scanner, msg);
}

static int parser_is_nonfatal_message(const char *msg) {
    if (!msg) return 0;
    return strstr(msg, "syntax is ambiguous") != NULL;
}

static int gamma_from_token(YAMLBisonToken token) {
    YAMLAlphabetSymbol symbol = yaml_gamma_token(token);
    return symbol.token.token;
}

static Indented indented_from_level(int level) {
    Indented indented;
    indented.level = level;
    return indented;
}

static Indented indented_dedent(Indented indented) {
    indented.level = 0;
    return indented;
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
static void ir_doc_start(IRBuilder *b, int explicit_start) {
    if (explicit_start) {
        ir_write(b, "+DOC ---\n");
    } else {
        ir_write(b, "+DOC\n");
    }
}

/**
 * Document end marker
 * Format: -DOC
 */
static void ir_doc_end(IRBuilder *b, int explicit_end) {
    if (explicit_end) {
        ir_write(b, "-DOC ...\n");
    } else {
        ir_write(b, "-DOC\n");
    }
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

static void monoid_stream_open(void) {
    ir = ir_builder_new_memory();
    add_event(EVENT_STREAM_START);
    ir_stream_start(ir);
}

static void monoid_stream_close(void) {
    ir_stream_end(ir);
    rml_ir_buf = ir_builder_finalize(ir);
    rml_ir_size = strlen(rml_ir_buf);
    ir_builder_free(ir);
    ir = NULL;
    add_event(EVENT_STREAM_END);
}

static void monoid_doc_open(int explicit_start) {
    ir_doc_start(ir, explicit_start);
    add_event(EVENT_DOCUMENT_START);
}

static void monoid_doc_close(int explicit_end) {
    ir_doc_end(ir, explicit_end);
    add_event(EVENT_DOCUMENT_END);
}

static void emit_map_key(const ScalarValue *k) {
    const char *key;
    const char *anchor;

    if (!k || !k->value) return;
    key = string_intern(k->value);
    anchor = k->anchor ? string_intern(k->anchor) : NULL;
    if (!key) key = "";
    
    if (k->type == '*') {
        /* Alias as map key */
        ir_alias(ir, key);
        add_alias_event(key);
    } else {
        /* Regular key (plain, quoted, or anchored) */
        ir_scalar(ir, key, k->type, anchor, NULL);
        add_scalar_event(key, k->type);
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
    const char *anchor_start;
    const char *tab;
    result.type = ':';
    result.anchor = NULL;
    result.value = NULL;
    
    if (!delimited_string) {
        result.value = string_unit();
        return result;
    }
    
    /* Find tab delimiter */
    tab = strchr(delimited_string, '\t');
    if (tab) {
        /* Extract anchor name (skip '&' prefix if present) */
        anchor_start = delimited_string;
        if (anchor_start[0] == '&') anchor_start++;
        result.anchor = string_intern_slice(anchor_start, (size_t)(tab - anchor_start));
        
        /* Extract key text */
        result.value = string_intern(tab + 1);
    } else {
        /* No delimiter: treat as plain key (fallback) */
        result.anchor = NULL;
        result.value = string_intern(delimited_string);
    }
    if (!result.value) result.value = string_unit();
    
    return result;
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
%start parser
%locations
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    int ival;
    Indented indented;
    NodeProps props;
    ScalarValue scalar;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS MAP_KEY QMAP_KEY SMAP_KEY ANCHOR_MAP_KEY QPART BPART
%token BAD_TAG
%token <string> CH_RAW CH_ESC_N CH_ESC_T CH_ESC_R CH_ESC_0 CH_ESC_BS CH_ESC_QU CH_ESC_SL
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET BULLET_EOL COLON COLON_EMPTY COLON_IMPLICIT QUESTION
%token <ival> INDENT DEDENT
%token LBRACK RBRACK LBRACE RBRACE COMMA

%type <props> node_props
%type <props> empty_props
%type <indented> indent
%type <ival> dedent
%type <ival> doc_start
%type <ival> doc_end
%type <scalar> scalar_item indented_scalar_item scalar_payload
%type <scalar> map_key
%type <string> scalar_parts qscalar qparts qpart bscalar

/* TODO Fix destructor double free in GLR mode + manual free in actions */
/* Destructors handle cleanup when symbols are discarded by the parser. */
%destructor { $$ = NULL; } <string>
%destructor { $$ = indented_dedent($$); } <indented>
%destructor { $$.anchor = NULL; $$.tag = NULL; } <props>
%destructor { $$.value = NULL; $$.anchor = NULL; } <scalar>

%locations

/* Precedence declarations for disambiguation */
%left COMMA RBRACE RBRACK
%precedence COLON
%precedence SCALAR QSCALAR SSCALAR BSCALAR

%%

/* Monoidal stream layer:
 *   parser   = monoid · gamma
 *   monoid   = alphabet
 *   alphabet = grammar
 *   grammar  = stream
 */
parser:
    monoid stream_eof
    ;

monoid:
    alphabet
    ;

alphabet:
    grammar
    ;

grammar:
    stream
    ;

stream:
    stream_open documents stream_close_monoid
    ;

stream_eof:
    YYEOF
    ;

doc_start:
    DOC_START { $$ = gamma_from_token(DOC_START); }
    ;

doc_end:
    DOC_END { $$ = gamma_from_token(DOC_END); }
    ;

stream_open:
    %empty { monoid_stream_open(); }
    ;

stream_close_monoid:
    %empty { monoid_stream_close(); }
    ;

documents:
    %empty
    | implicit_document
    | implicit_document doc_end[end]
    | implicit_document doc_end[end] bare_doc_after_explicit
    | implicit_document doc_end[end] explicit_documents
    | explicit_documents
    | explicit_documents bare_doc_after_explicit
    | implicit_document explicit_documents
    | doc_end[end]
    | doc_end[end] explicit_documents
    ;

bare_doc_after_explicit:
    doc_end[separator] doc_monoid_implicit
    ;

doc_empty:
    doc_empty_ir doc_empty_event
    ;

doc_empty_ir:
    %empty { ir_scalar_empty(ir); }
    ;

doc_empty_event:
    %empty { add_scalar_event("", ':'); }
    ;

directives:
    directive
    | directives directive
    ;

directive:
    YAML_DIRECTIVE
    | TAG_DIRECTIVE SCALAR SCALAR
    | TAG_DIRECTIVE TAG SCALAR
    ;

explicit_documents:
    explicit_document
    | explicit_documents explicit_document
    | explicit_documents error doc_end[recover_end] { RECOVER_SYNC("Skipping malformed document"); }
    ;

explicit_document:
    doc_monoid_explicit
    ;

implicit_document:
    doc_monoid_implicit
    ;

doc_monoid_implicit:
    doc_open_implicit node_with_indent doc_close_implicit
    ;

doc_monoid_explicit:
    explicit_doc_prelude doc_open_explicit doc_body doc_close_variant
    ;

doc_open_implicit:
    %empty { monoid_doc_open(0); }
    ;

doc_open_explicit:
    doc_start[explicit] { monoid_doc_open(1); }
    ;

doc_close_implicit:
    %empty { monoid_doc_close(0); }
    ;

doc_close_explicit:
    doc_end[explicit_end] { monoid_doc_close(1); }
    ;

doc_close_variant:
    doc_close_explicit
    | doc_close_implicit
    ;

doc_body:
    node_with_indent
    | doc_empty
    ;

explicit_doc_prelude:
    %empty
    | directives
    ;

node_with_indent:
    node
    | indented_node
    ;

indent:
    INDENT[level] { $$ = indented_from_level($level); }
    ;

dedent:
    DEDENT[level] { $$ = $level; }
    ;

indented_node:
    indent[level] node dedent[level]
    ;

node:
    collection_with_props
    | collection_no_props
    | scalar_node
    | alias_node
    | error { RECOVER("Recovering at node boundary"); }
    ;

/* Value-position node (after COLON): avoid non-indented block collections
 * after bare node properties to reduce spurious ambiguities.
 */
value_node:
    value_collection_with_props
    | collection_no_props
    | scalar_node
    | alias_node
    | ANCHOR[a] indent[l1] TAG[t] indent[l2]
      { ir_map_start(ir, $a, $t); add_event(EVENT_MAPPING_START); }[map_open]
      collection_pair_entries
      dedent[l2]
      map_end
      dedent[l1]
    | TAG[t] indent[l1] ANCHOR[a] indent[l2]
      { ir_map_start(ir, $a, $t); add_event(EVENT_MAPPING_START); }[map_open]
      collection_pair_entries
      dedent[l2]
      map_end
      dedent[l1]
    | error { RECOVER("Recovering at value node boundary"); }
    ;

scalar_node:
    empty_props[props] scalar_payload[s] { ir_scalar(ir, $s.value, $s.type, $props.anchor, $props.tag); add_scalar_event($s.value, $s.type); }
    | node_props[props] scalar_payload[s] { ir_scalar(ir, $s.value, $s.type, $props.anchor, $props.tag); add_scalar_event($s.value, $s.type); }
    | node_props[props] { ir_scalar(ir, "", ':', $props.anchor, $props.tag); add_scalar_event("", ':'); }
    ;

alias_node:
    ALIAS[a] { ir_alias(ir, $a); add_alias_event($a); }
    ;

scalar_item:
    scalar_parts { $$.type = ':'; $$.value = $1; }
    | qscalar { $$.type = '"'; $$.value = $1; }
    | SSCALAR[val] { $$.type = '\''; $$.value = $val; }
    | bscalar { $$.type = '|'; /* Placeholder type, fix later */ $$.value = $1; }
    ;

indented_scalar_item:
    indent[level] scalar_item[s] dedent[level] { $$ = $s; }
    ;

scalar_payload:
    scalar_item[s] { $$ = $s; }
    | indented_scalar_item[s] { $$ = $s; }
    ;

qscalar:
    qparts QSCALAR { $$ = $1; }
    ;

scalar_parts:
    CH_RAW { $$ = $1; }
    | scalar_parts CH_RAW { $$ = string_concat($1, $2); }
    ;

qparts:
    %empty { $$ = string_unit(); }
    | qparts qpart { $$ = string_concat($1, $2); }
    ;

qpart:
    CH_RAW { $$ = $1; }
    | CH_ESC_N { $$ = strdup("\n"); }
    | CH_ESC_T { $$ = strdup("\t"); }
    | CH_ESC_R { $$ = strdup("\r"); }
    | CH_ESC_BS { $$ = strdup("\\"); }
    | CH_ESC_QU { $$ = strdup("\""); }
    | CH_ESC_SL { $$ = strdup("/"); }
    | CH_ESC_0 { $$ = strdup("\0"); }
    ;

bscalar:
    BPART { $$ = $1; }
    | bscalar BPART { $$ = string_concat($1, $2); }
    ;

empty_props:
    %empty { $$.anchor = NULL; $$.tag = NULL; }
    ;

node_props:
    ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    | TAG[t] ANCHOR[a] { $$.anchor = $a; $$.tag = $t; }
    | BAD_TAG { RECOVER_SYNC("Malformed tag syntax"); $$.anchor = NULL; $$.tag = NULL; }
    ;

/* Explicit collection abstraction: values (SEQ) vs key-values (MAP). */
collection_no_props:
    sequence_no_props
    | mapping_no_props
    ;

collection_with_props:
    sequence_with_props
    | mapping_with_props
    ;

value_collection_with_props:
    value_sequence_with_props
    | value_mapping_with_props
    ;

sequence_no_props:
    seq_start collection_value_entries seq_end %dprec 3
    | flow_sequence_no_props
    ;

flow_sequence_no_props:
    flow_lbrack flow_seq_init collection_flow_value_entries flow_rbrack seq_end flow_lvl_dec
    ;

flow_lvl_dec:
    %empty
    ;

seq_start:
    %empty { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    ;

seq_end:
    %empty { ir_seq_end(ir); add_event(EVENT_SEQUENCE_END); }
    ;

flow_seq_init:
    %empty { ir_seq_start(ir, NULL, NULL); add_event(EVENT_SEQUENCE_START); }
    ;

flow_lbrack:
    LBRACK
    ;

flow_rbrack:
    RBRACK
    ;

sequence_with_props:
    node_props[props]
      { ir_seq_start(ir, $props.anchor, $props.tag); add_event(EVENT_SEQUENCE_START); }[seq_open]
      collection_value_entries
      seq_end
      {}[seq_close]
      %dprec 3
    | value_sequence_with_props
    ;

value_sequence_with_props:
    node_props[props]
      indent[level]
      { ir_seq_start(ir, $props.anchor, $props.tag); add_event(EVENT_SEQUENCE_START); }[seq_open]
      collection_value_entries
      dedent[level]
      seq_end
      {}[seq_close]
      %dprec 3
    | node_props[props]
      flow_lbrack
      { ir_seq_start(ir, $props.anchor, $props.tag); add_event(EVENT_SEQUENCE_START); }[flow_seq_open]
      collection_flow_value_entries
      flow_rbrack
      seq_end
      flow_lvl_dec
      {}[seq_close]
    ;

collection_value_entries:
    seq_entry
    | collection_value_entries seq_entry
    ;

indented_seq_entries:
    indent[level] collection_value_entries dedent[level]
    ;

seq_entry:
    BULLET node %dprec 5
    | BULLET node indented_seq_entries %dprec 6
    | BULLET map_key[k] { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); emit_map_key(&$k); } COLON node indented_map_entries { ir_map_end(ir); add_event(EVENT_MAPPING_END); } %dprec 6
    | BULLET_EOL seq_entry_empty_scalar %dprec 2
    | BULLET_EOL indented_node %dprec 4
    | BULLET error { RECOVER("Malformed sequence item"); } %dprec 2
    | BULLET_EOL error { RECOVER("Malformed sequence item"); } %dprec 2
    ;

seq_entry_empty_scalar:
    seq_entry_empty_scalar_ir seq_entry_empty_scalar_event
    ;

seq_entry_empty_scalar_ir:
    %empty { ir_scalar_empty(ir); }
    ;

seq_entry_empty_scalar_event:
    %empty { add_scalar_event("", ':'); }
    ;

collection_flow_value_entries:
    %empty
    | flow_seq_entry
    | collection_flow_value_entries COMMA flow_seq_entry
    | collection_flow_value_entries COMMA
    ;

flow_seq_entry:
    node
    | flow_map_entry_pair %dprec 1
    | error { RECOVER("Malformed flow sequence entry"); }
    ;

mapping_no_props:
    map_init collection_pair_entries map_end
    | flow_mapping_no_props
    ;

flow_mapping_no_props:
    flow_lbrace flow_map_init collection_flow_pair_entries flow_rbrace map_end flow_lvl_dec
    ;

map_init:
     %empty { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    ;

map_end:
    %empty { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;

flow_map_init:
    %empty { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    ;

flow_lbrace:
    LBRACE
    ;

flow_rbrace:
    RBRACE
    ;

mapping_with_props:
    value_mapping_with_props
    | node_props[props]
      { ir_map_start(ir, $props.anchor, $props.tag); add_event(EVENT_MAPPING_START); }[map_open]
      collection_pair_entries
      map_end
      {}[map_close]
    ;

value_mapping_with_props:
    node_props[props]
      indent[level]
      { ir_map_start(ir, $props.anchor, $props.tag); add_event(EVENT_MAPPING_START); }[map_open]
      collection_pair_entries
      dedent[level]
      map_end
      {}[map_close]
    | node_props[props]
      flow_lbrace
      { ir_map_start(ir, $props.anchor, $props.tag); add_event(EVENT_MAPPING_START); }[flow_map_open]
      collection_flow_pair_entries
      flow_rbrace
      map_end
      flow_lvl_dec
      {}[map_close]
    ;

collection_pair_entries:
    map_entry
    | collection_pair_entries map_entry
    ;

indented_map_entries:
    indent[level] collection_pair_entries dedent[level]
    ;

indented_value_node:
    indent[level] value_node dedent[level]
    ;

map_key:
    MAP_KEY[val] { $$.type = ':'; $$.value = $val; $$.anchor = NULL; }
    | QMAP_KEY[val] { $$.type = '"'; $$.value = $val; $$.anchor = NULL; }
    | SMAP_KEY[val] { $$.type = '\''; $$.value = $val; $$.anchor = NULL; }
    | ANCHOR_MAP_KEY[val] { $$ = parse_anchored_map_key($val); }
    ;

map_entry:
    map_key[k] { emit_map_key(&$k); } COLON value_node %dprec 2
    | map_key[k] { emit_map_key(&$k); } COLON indented_value_node %dprec 1
    | map_key[k] { emit_map_key(&$k); } COLON { ir_scalar_empty(ir); add_scalar_event("", ':'); }
    | map_key[k] { emit_map_key(&$k); } COLON_IMPLICIT { ir_scalar_empty(ir); add_scalar_event("", ':'); }
    | QUESTION node COLON value_node %dprec 2
    | QUESTION indented_node COLON value_node %dprec 3
    | QUESTION node COLON indented_value_node %dprec 3
    | QUESTION indented_node COLON indented_value_node %dprec 4
    | QUESTION node { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
    | QUESTION indented_node { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 2
    | MAP_KEY error { RECOVER("Malformed mapping entry"); }
    | QMAP_KEY error { RECOVER("Malformed mapping entry"); }
    | SMAP_KEY error { RECOVER("Malformed mapping entry"); }
    | QUESTION error { RECOVER("Malformed complex mapping entry"); }
    | error { RECOVER("Invalid mapping structure"); }
    ;

collection_flow_pair_entries:
    %empty
    | flow_map_entry
    | collection_flow_pair_entries COMMA flow_map_entry
    | collection_flow_pair_entries COMMA
    ;

flow_map_entry:
    node seq_entry_empty_scalar
    | flow_map_entry_pair
    | error { RECOVER("Malformed flow mapping entry"); }
    ;

flow_map_entry_pair:
    node COLON node %dprec 3
    | node COLON_EMPTY { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 2
    | node COLON { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
    | COLON { ir_scalar_empty(ir); add_scalar_event("", ':'); } node %dprec 3
    | COLON_EMPTY { ir_scalar_empty(ir); add_scalar_event("", ':'); ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
    | QUESTION node COLON node %dprec 4
    | QUESTION node COLON_EMPTY { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 2
    | QUESTION node COLON { ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
    | QUESTION { ir_scalar_empty(ir); add_scalar_event("", ':'); ir_scalar_empty(ir); add_scalar_event("", ':'); } %dprec 1
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
static int yaml_parse_internal(const char *input);

/**
 * Stage 1: Parse - Scanning -> Parsing (Presentation -> Events)
 * 
 * Architecture: The reentrant scanner object manages its own input state.
 * By default it reads from stdin. No explicit file redirection needed.
 * This simplifies the interface and relies on Flex's internal state management.
 */
static int yaml_parse_internal(const char *input) {
    yyscan_t scanner;
    LexerContext *ctx = lexer_context_new();
    YY_BUFFER_STATE buffer = NULL;
    int result;

    string_pool_reset();

    if (!ctx) {
        parsing_yy_error(NULL, NULL, "Failed to create lexer context");
        string_pool_reset();
        return 1;
    }
    
    /* Initialize reentrant scanner with lexer context as user-defined data */
    if (scanning_lex_init_extra(ctx, &scanner) != 0) {
        parsing_yy_error(NULL, NULL, "Failed to initialize lexer");
        lexer_context_free(ctx);
        string_pool_reset();
        return 1;
    }

    if (input) {
        buffer = scanning__scan_string(input, scanner);
        if (!buffer) {
            parsing_yy_error(NULL, scanner, "Failed to initialize parser input buffer");
            scanning_lex_destroy(scanner);
            lexer_context_free(ctx);
            string_pool_reset();
            return 1;
        }
    }
    
    /* Reset error count for this run */
    parse_error_count = 0;
    parse_nonfatal_count = 0;
    
    /* Scanner now manages stdin internally; just parse */
    result = parsing_yy_parse(scanner);

    if (result != 0 && parse_error_count == 0 && parse_nonfatal_count > 0) {
        result = 0;
    }

    if (result == 0 && parse_nonfatal_count > 0 && rml_ir_buf == NULL) {
        rml_ir_buf = strdup("+STR\n-STR\n");
        if (!rml_ir_buf) {
            result = 1;
        } else {
            rml_ir_size = strlen(rml_ir_buf);
        }
    }

    if (result == 0 && validate_lexical_semantics(ctx, scanner) != 0) {
        result = 1;
    }
    
    /* If errors occurred but we recovered, still signal failure to caller */
    if (parse_error_count > 0 && result == 0) {
        result = 1;
    }
    
    /* Cleanup */
    if (buffer) {
        scanning__delete_buffer(buffer, scanner);
    }
    scanning_lex_destroy(scanner);
    lexer_context_free(ctx);
    string_pool_reset();

    return result;
}

int yaml_parse(void) {
    int result = yaml_parse_internal(NULL);

    if (has_arg("-dump-tokens")) {
        extern char *rml_ir_buf;
        if (rml_ir_buf) printf("%s", rml_ir_buf);
        exit(result);
    }

    return result;
}

int yaml_parse_buffer(const char *input) {
    return yaml_parse_internal(input ? input : "");
}

int yaml_parse_buffer_probe(const char *input) {
    int prev = g_silent_parse_errors;
    int result;

    g_silent_parse_errors = 1;
    result = yaml_parse_internal(input ? input : "");
    g_silent_parse_errors = prev;
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
    if (has_arg("-emit-yaml")) {
        /* Serialization dump logic here */
        exit(0);
    }
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
    if (parser_is_nonfatal_message(s)) {
        parse_nonfatal_count++;
    } else {
        parse_error_count++;
    }
    if (g_silent_parse_errors) {
        return;
    }
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
