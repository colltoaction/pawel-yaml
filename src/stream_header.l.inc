%{
#include "stream.tab.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* LexerContext type is provided by lexer_context.h via stream.tab.h */

#define YYSTYPE STREAM_YY_STYPE
#define YYLTYPE STREAM_YY_LTYPE

/* Forward declaration for error handling */
void stream_yy_error(void *yylloc, yyscan_t scanner, const char *msg);
#define yyerror stream_yy_error

/* Lexer context - replaces all global variables */
#define CTX yyextra

#define FLOW_IMPLICIT_KEY_CANDIDATE CTX->flow.implicit_key_candidate
#define FLOW_DELIM_STACK CTX->flow.delim_stack
#define FLOW_INDENT_REF_STACK CTX->flow.indent_ref_stack
#define FLOW_INDENT_REQUIRED_STACK CTX->flow.indent_required_stack
#define FLOW_DELIM_SP CTX->flow.delim_sp
#define PENDING_DEDENT_COUNT CTX->flow.pending_dedent_count

/* Column tracking */
#define YY_USER_ACTION CTX->current_column += yyleng;

typedef enum {
    FLOW_KEY_NONE = 0,
    FLOW_KEY_CANDIDATE = 1
} FlowKeyState;

typedef enum {
    COLON_STATE_NONE = 0,
    COLON_STATE_SYNTHETIC = 1
} ColonState;

static inline void flow_key_state_set(LexerContext *ctx, FlowKeyState state) {
    ctx->flow.implicit_key_candidate = state;
}

static inline int flow_key_state_is(const LexerContext *ctx, FlowKeyState state) {
    return ctx->flow.implicit_key_candidate == state;
}

static inline void colon_state_set(LexerContext *ctx, ColonState state) {
    ctx->pending_colon = state;
}

static inline int colon_state_is(const LexerContext *ctx, ColonState state) {
    return ctx->pending_colon == state;
}

static int return_dedent_count(LexerContext *ctx, int dedent_count, YYSTYPE *yylval) {
    if (dedent_count <= 0) {
        return 0;
    }
    ctx->flow.pending_dedent_count = dedent_count - 1;
    yylval->ival = dedent_count;
return DEDENT;
}

/* === INLINED: lexer_context.c - Unified Lexer State Management === */

/**
 * Create a new lexer context with default initialization
 */
static LexerContext *lexer_context_new_internal(void) {
    LexerContext *ctx = (LexerContext*)malloc(sizeof(LexerContext));
    if (!ctx) return NULL;

    /* Initialize indentation tracking */
    ctx->indent_stack[0] = 0;
    ctx->indent_sp = 0;

    /* Initialize flow and value tracking */
    ctx->expecting_value = 0;
    ctx->yaml_directive_seen = 0;
    ctx->current_column = 0;

    /* Initialize document state */
    ctx->first_line = 1;
    ctx->last_was_value = 0;
    ctx->at_line_start = 1;
    ctx->complex_key_pending = 0;
    ctx->pending_colon = COLON_STATE_NONE;

    /* Initialize block scalar state */
    ctx->block_scalar.type = '\0';
    ctx->block_scalar.indent = -1;
    ctx->block_scalar.leading_empty_max_indent = 0;
    ctx->block_scalar.first_content_seen = 0;

    /* Initialize scalar accumulation buffer */
    ctx->scalar.content = (char*)malloc(1024);
    ctx->scalar.len = 0;
    ctx->scalar.cap = 1024;
    if (ctx->scalar.content) {
        ctx->scalar.content[0] = '\0';
    }

    /* Initialize indent context stack */
    ctx->indent_context_sp = 0;
    ctx->scalar_base_indent = 0;
    ctx->scalar_type = '\0';
    ctx->quoted_value_closed_on_line = 0;
    ctx->semantic_error_count = 0;
    ctx->semantic_indent_tab_count = 0;
    ctx->semantic_indent_mismatch_count = 0;
    ctx->semantic_directive_mid_doc_count = 0;
    ctx->semantic_flow_glue_count = 0;
    ctx->semantic_flow_comma_count = 0;
    ctx->semantic_flow_leading_comma_count = 0;
    ctx->semantic_flow_comment_comma_count = 0;
    ctx->semantic_flow_key_newline_count = 0;
    ctx->semantic_multiline_qkey_count = 0;
    ctx->semantic_inline_key_count = 0;
    /* Categorical Flow State initialization */
    ctx->flow.implicit_key_candidate = 0;
    ctx->flow.delim_sp = 0;
    ctx->flow.pending_dedent_count = 0;
    memset(ctx->flow.delim_stack, 0, sizeof(ctx->flow.delim_stack));
    memset(ctx->flow.indent_ref_stack, 0, sizeof(ctx->flow.indent_ref_stack));
    memset(ctx->flow.indent_required_stack, 0, sizeof(ctx->flow.indent_required_stack));

    ctx->semantic_flow_indent_count = 0;
    ctx->open_document_started = 1;
    ctx->yaml_directive_seen = 0;

    return ctx;
}

/**
 * Create a new lexer context with argc/argv for mode selection
 */
static LexerContext *lexer_context_new_with_args(int argc, char **argv) {
    LexerContext *ctx = lexer_context_new_internal();
    if (ctx) {
        ctx->argc = argc;
        ctx->argv = argv;
    }
    return ctx;
}

/**
 * Free lexer context and all associated resources
 */
static void lexer_context_free_internal(LexerContext *ctx) {
    if (ctx) {
        if (ctx->scalar.content) {
            free(ctx->scalar.content);
        }
        free(ctx);
    }
}

/**
 * Reset context for a new document stream
 * Preserves allocated buffers but resets state
 */
static void lexer_context_reset(LexerContext *ctx) {
    if (!ctx) return;

    ctx->indent_stack[0] = 0;
    ctx->indent_sp = 0;
    ctx->expecting_value = 0;
    ctx->first_line = 1;
    ctx->last_was_value = 0;
    ctx->at_line_start = 1;
    ctx->complex_key_pending = 0;
    ctx->pending_colon = COLON_STATE_NONE;

    ctx->block_scalar.type = '\0';
    ctx->block_scalar.indent = -1;
    ctx->block_scalar.leading_empty_max_indent = 0;
    ctx->block_scalar.first_content_seen = 0;

    ctx->scalar.len = 0;
    if (ctx->scalar.content) {
        ctx->scalar.content[0] = '\0';
    }

    ctx->indent_context_sp = 0;
    ctx->scalar_base_indent = 0;
    ctx->scalar_type = '\0';
    ctx->quoted_value_closed_on_line = 0;
    ctx->semantic_error_count = 0;
    ctx->semantic_indent_tab_count = 0;
    ctx->semantic_indent_mismatch_count = 0;
    ctx->semantic_directive_mid_doc_count = 0;
    ctx->semantic_flow_glue_count = 0;
    ctx->semantic_flow_comma_count = 0;
    ctx->semantic_flow_leading_comma_count = 0;
    ctx->semantic_flow_comment_comma_count = 0;
    ctx->semantic_flow_key_newline_count = 0;
    ctx->semantic_multiline_qkey_count = 0;
    ctx->semantic_inline_key_count = 0;
    ctx->flow.implicit_key_candidate = 0;
    ctx->flow.delim_sp = 0;
    ctx->flow.pending_dedent_count = 0;
    memset(ctx->flow.delim_stack, 0, sizeof(ctx->flow.delim_stack));
    memset(ctx->flow.indent_ref_stack, 0, sizeof(ctx->flow.indent_ref_stack));
    memset(ctx->flow.indent_required_stack, 0, sizeof(ctx->flow.indent_required_stack));

    ctx->semantic_flow_indent_count = 0;
    ctx->open_document_started = 1;
    ctx->yaml_directive_seen = 0;
}

/**
 * Push a new indentation level onto the stack
 * Implements bounds checking to prevent overflow
 */
static void ctx_push_indent(LexerContext *ctx, int col) {
    if (!ctx) return;
    if (ctx->indent_sp < 99) {
        ctx->indent_stack[++ctx->indent_sp] = col;
    }
}

/**
 * Pop the current indentation level from the stack
 * Returns the popped value, or 0 if stack is empty
 */
static int ctx_pop_indent(LexerContext *ctx) {
    if (!ctx) return 0;
    return (ctx->indent_sp > 0) ? ctx->indent_stack[ctx->indent_sp--] : 0;
}

/**
 * Get the current indentation level without modifying the stack
 */
/* static int ctx_current_indent(const LexerContext *ctx) {
    if (!ctx) return 0;
    return ctx->indent_stack[ctx->indent_sp];
} */

/**
 * Push an indentation context for multiline scalar tracking
 */
static void ctx_push_indent_context(LexerContext *ctx, int level, int is_flow, char type) {
    if (!ctx) return;
    if (ctx->indent_context_sp < 99) {
        ctx->indent_context_stack[ctx->indent_context_sp].level = level;
        ctx->indent_context_stack[ctx->indent_context_sp].is_flow = is_flow;
        ctx->indent_context_stack[ctx->indent_context_sp].context_type = type;
        ctx->indent_context_sp++;
    }
}

/**
 * Pop the current indentation context
 */
static void ctx_pop_indent_context(LexerContext *ctx) {
    if (!ctx) return;
    if (ctx->indent_context_sp > 0) {
        ctx->indent_context_sp--;
    }
}

/**
 * Check if we're currently in a flow context
 */
/* static int ctx_in_flow_context(const LexerContext *ctx) {
    if (!ctx) return 0;
    return FLOW_DELIM_SP > 0 ||
           (ctx->indent_context_sp > 0 &&
            ctx->indent_context_stack[ctx->indent_context_sp - 1].is_flow);
} */

/**
 * Initialize scalar accumulation buffer
 * Resets length to 0 but preserves allocated capacity
 */
/* static void ctx_scalar_init(LexerContext *ctx) {
    if (!ctx) return;
    ctx->scalar.len = 0;
    if (ctx->scalar.content) {
        ctx->scalar.content[0] = '\0';
    }
} */

/**
 * Grow scalar buffer if needed to accommodate additional data
 */
static void ctx_try_grow_scalar(LexerContext *ctx, int additional_size) {
    if (!ctx || !ctx->scalar.content) return;

    int required = ctx->scalar.len + additional_size + 2;  /* +2 for null terminator and safety */
    if (required >= ctx->scalar.cap) {
        /* Double capacity until sufficient */
        while (ctx->scalar.cap < required) {
            ctx->scalar.cap *= 2;
        }
        ctx->scalar.content = (char*)realloc(ctx->scalar.content, ctx->scalar.cap);
    }
}

/**
 * Append text to scalar accumulation buffer
 * Automatically grows buffer if needed
 */
/* static void ctx_scalar_append(LexerContext *ctx, const char *text, int len) {
    if (!ctx || !text || len <= 0) return;

    ctx_try_grow_scalar(ctx, len);
    if (!ctx->scalar.content) return;

    memcpy(ctx->scalar.content + ctx->scalar.len, text, len);
    ctx->scalar.len += len;
    ctx->scalar.content[ctx->scalar.len] = '\0';
} */

/**
 * Finalize scalar and return a copy of the accumulated text
 * Resets the buffer for next use
 */
/* static char *ctx_scalar_finalize(LexerContext *ctx) {
    if (!ctx || !ctx->scalar.content) return strdup("");

    char *result = strdup(ctx->scalar.content);
    ctx_scalar_init(ctx);
    return result;
} */

/**
 * Start block scalar accumulation
 * Sets type ('|' or '>') and initializes buffer
 */
/* static void ctx_block_scalar_start(LexerContext *ctx, char type) {
    if (!ctx) return;
    ctx->block_scalar.type = type;
    ctx->block_scalar.indent = -1;
    ctx_scalar_init(ctx);
} */

/**
 * Append a line to block scalar with newline
 */
/* static void ctx_block_scalar_append(LexerContext *ctx, const char *line, int len) {
    if (!ctx || !line) return;
    ctx_scalar_append(ctx, line, len);
    ctx_scalar_append(ctx, "\n", 1);
} */

/* === END INLINED: lexer_context.c === */

/* Check if UTF-8 bytes represent visible space U+2423 */
static int is_visible_space(const unsigned char *s) {
    return s[0] == 0xE2 && s[1] == 0x90 && s[2] == 0xA3;
}

/* Comments require whitespace (space/tab) before them (or start of line)
 * This prevents invalid YAML like: "value"# comment or ># comment
 */
inline static int check_comment_valid(LexerContext *ctx) {
    return !ctx->last_was_value;
}


static void push_indent(LexerContext *ctx, int col) {
    ctx_push_indent(ctx, col);
}

static int pop_indent(LexerContext *ctx) {
    return ctx_pop_indent(ctx);
}

/* static int current_indent(LexerContext *ctx) {
    return ctx_current_indent(ctx);
} */

static void push_indent_context(LexerContext *ctx, int level, int is_flow, char type) {
    ctx_push_indent_context(ctx, level, is_flow, type);
}

static void pop_indent_context(LexerContext *ctx) {
    ctx_pop_indent_context(ctx);
}

/* static int in_flow_context(LexerContext *ctx) {
    return ctx_in_flow_context(ctx);
} */

/* Simple lookahead - just check if we're at end of file or line */
static int check_scalar_continuation() {
    /* For now, simple approach: plain scalars end at newline in block context */
    return 0;
}

/**
 * Trim trailing whitespace (spaces and tabs) from string in-place
 * Returns pointer to the same string for chaining
 */
static char *trim_trailing_spaces(char *str) {
    if (!str) return str;
    char *end = str + strlen(str);
    while (end > str && (end[-1] == ' ' || end[-1] == '\t')) {
        end--;
    }
    *end = '\0';
    return str;
}

/**
 * Extract key text after a prefix token (tag or anchor) for map key patterns
 * Input: "prefix key_text" where prefix is followed by spaces
 * Output: "key_text" with trailing spaces trimmed
 * Caller must free the returned string
 */
static char *extract_key_after_prefix(const char *text) {
    if (!text) return strdup("");

    /* Find first space after prefix */
    const char *space = strchr(text, ' ');
    if (!space) return strdup(text);

    /* Skip spaces to get to key text */
    while (*space == ' ') space++;

    char *key = strdup(space);
    trim_trailing_spaces(key);

    /* Also trim trailing colon if present (from lookahead) */
    size_t len = strlen(key);
    if (len > 0 && key[len - 1] == ':') {
        key[len - 1] = '\0';
    }

    return key;
}

/*
 * Extract key text from a quoted key candidate:
 *   "\"key\"   " -> "key"
 *   "'key'   "   -> "key"
 * Trailing spaces are removed; escapes are preserved as-is.
 */
static char *extract_quoted_key(const char *text, char quote_char) {
    char *key;
    size_t len;

    if (!text) return strdup("");

    key = strdup(text);
    if (!key) return NULL;
    trim_trailing_spaces(key);

    len = strlen(key);
    if (len >= 2 && key[0] == quote_char && key[len - 1] == quote_char) {
        memmove(key, key + 1, len - 2);
        key[len - 2] = '\0';
    }
    return key;
}

static int flow_close_follow_char_ok(int c) {
    if (c == EOF || c == 0) return 1;
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') return 1;
    if (c == ',' || c == ':' || c == ']' || c == '}' || c == '#') return 1;
    return 0;
}

/*
 * Parse explicit indentation indicator from a block scalar header.
 * Returns 1..9 when present, otherwise 0.
 */
static int parse_block_indent_indicator(const char *text) {
    const char *p;
    if (!text || (text[0] != '|' && text[0] != '>')) return 0;
    for (p = text + 1; *p; p++) {
        if (*p >= '1' && *p <= '9') return *p - '0';
        if (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r' || *p == '#') break;
    }
    return 0;
}

/* static void init_scalar(LexerContext *ctx) {
    ctx_scalar_init(ctx);
} */

/* static void append_scalar(LexerContext *ctx, const char *str, int len) {
    ctx_scalar_append(ctx, str, len);
} */

/* static void init_block_scalar(LexerContext *ctx, char type) {
    ctx_block_scalar_start(ctx, type);
} */

/* static void append_block_line(LexerContext *ctx, const char *line, int len) {
    ctx_block_scalar_append(ctx, str, len);
} */


%}

%option noyywrap
%option reentrant
%option bison-bridge
%option bison-locations
%option prefix="scanning_"
%option extra-type="LexerContext *"

%x BLOCK_SCALAR
%x BLOCK_CONTENT
%x DIRECTIVE_MODE
%x INDENT_CHECK
%x PLAIN_SCALAR_CONT
%x QUOTED

NSCAL [a-zA-Z0-9\-\._%:/]
ANCHOR_CHAR [^ \t\n\r\[\]{},]
ALIAS_CHAR [^ \t\n\r\[\]{},]
VSPACE \xE2\x90\xA3
VEND \xE2\x88\x8E
TAG_TOKEN ("!<"[^>\n\r]+">"|"!!"{NSCAL}+|"!"{NSCAL}+"!"{NSCAL}*|"!"{NSCAL}+)
PKEY_HEAD [^ \t\n\r\[\]{}!,&*%@|>\`'"]
PKEY_BODY [^:\n\r]*

%%
