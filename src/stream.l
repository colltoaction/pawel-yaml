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

<INDENT_CHECK>[ \t]*#[^\n]* {
    /* Line with only whitespace and comment - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>({VSPACE}|[ \t])*{VEND}[^\n]*\n {
    /* yaml-test-suite end marker line - skip it */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>({VSPACE}|[ \t])*\n {
    /* Blank line - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>({VSPACE}|[ \t])*{VEND} {
    /* End marker without newline */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>[ \t]* {
    int indent = 0;
    int has_tab = 0;
    for (int i=0; i<yyleng; i++) {
        if (yytext[i] == ' ') {
            indent++;
        } else if (yytext[i] == '\t') {
            has_tab = 1;
            /* Tabs OK before flow indicators, error otherwise */
        }
    }
    
    if (has_tab) {
        /* Syntax stage: tokenize indentation without rejecting tabbed lines.
         * Semantic stage decides whether the line is policy-valid.
         */
        int c = input(yyscanner);
        int first_char = c;
        int look_buf[1024];
        int look_n = 0;
        int line_has_mapping_shape = 0;

        if (c != EOF && c != 0) {
            look_buf[look_n++] = c;

            while (look_n < 1023) {
                if (c == '\n' || c == '\r' || c == EOF || c == 0) break;
                c = input(yyscanner);
                if (c == EOF || c == 0) break;
                look_buf[look_n++] = c;
            }

            for (int i = 0; i < look_n; i++) {
                if (look_buf[i] == '#') break;
                if (look_buf[i] == ':' || look_buf[i] == '-') {
                    line_has_mapping_shape = 1;
                    break;
                }
            }
        }

        for (int i = look_n - 1; i >= 0; i--) {
            unput(look_buf[i]);
        }

        /* Policy: tabbed leading whitespace is rejected when line shape
         * indicates structural indentation (mapping/sequence), but allowed
         * for scalar-alignment continuation content.
         */
        if (line_has_mapping_shape && first_char != '[' && first_char != '{') {
            CTX->semantic_error_count++;
            CTX->semantic_indent_tab_count++;
        }
    }

    {
        int look_buf[3];
        int look_n = 0;
        int c = input(yyscanner);
        int is_doc_end_marker = 0;

        if (c != EOF && c != 0) {
            look_buf[look_n++] = c;
            for (int i = 0; i < 2; i++) {
                int d = input(yyscanner);
                if (d == EOF || d == 0) break;
                look_buf[look_n++] = d;
            }
        }

        for (int i = look_n - 1; i >= 0; i--) {
            unput(look_buf[i]);
        }

        if (look_n >= 3 &&
            look_buf[0] == '.' &&
            look_buf[1] == '.' &&
            look_buf[2] == '.') {
            is_doc_end_marker = 1;
        }

        if (look_n > 0) {
            if (look_buf[0] == '%') {
                /* keep current directive allowance */
            } else if (is_doc_end_marker) {
                CTX->open_document_started = 1;
            } else if (look_buf[0] != '#') {
                CTX->open_document_started = 0;
            }
        }
    }
    
    BEGIN(INITIAL);
    CTX->at_line_start = 1;
    int cur = CTX->indent_stack[CTX->indent_sp];
    if (indent > cur) {
        if (CTX->indent_sp < 99) {
            CTX->indent_stack[++CTX->indent_sp] = indent;
        }
        yylval->ival = indent;
return INDENT;
    } else if (indent < cur) {
        int dedent_count = 0;
        int target_sp = CTX->indent_sp;
        while (target_sp > 0 && CTX->indent_stack[target_sp] > indent) {
            target_sp--;
            dedent_count++;
        }
        
        if (indent != CTX->indent_stack[target_sp]) {
            CTX->semantic_error_count++;
            CTX->semantic_indent_mismatch_count++;
        }
        
        CTX->indent_sp = target_sp;
        if (dedent_count > 0) {
            yylval->ival = dedent_count;
            return return_dedent_count(CTX, dedent_count, yylval);
        }
    }
}

<INDENT_CHECK>. {
    /* Not an indent - likely at column 0 */
    int first_char = yytext[0];
    if (first_char != '%' && first_char != '#' && first_char != '.') {
        CTX->open_document_started = 0;
    }
    yyless(0);
    BEGIN(INITIAL);
    CTX->at_line_start = 1;
    int cur = CTX->indent_stack[CTX->indent_sp];
    if (0 < cur) {
        int dedent_count = 0;
        while (0 < CTX->indent_stack[CTX->indent_sp]) {
            if (CTX->indent_sp > 0) CTX->indent_sp--;
            dedent_count++;
        }
        if (dedent_count > 0) {
            return return_dedent_count(CTX, dedent_count, yylval);
        }
    }
}

<INDENT_CHECK><<EOF>> {
    BEGIN(INITIAL);
    {
        int dedent_count = 0;
        while (0 < CTX->indent_stack[CTX->indent_sp]) {
            if (CTX->indent_sp > 0) CTX->indent_sp--;
            dedent_count++;
        }
        if (dedent_count > 0) {
            return return_dedent_count(CTX, dedent_count, yylval);
        }
    }
    return YAML_GAMMA;
}

<INITIAL><<EOF>> {
    if (PENDING_DEDENT_COUNT > 0) {
        yylval->ival = PENDING_DEDENT_COUNT;
        PENDING_DEDENT_COUNT--;
return DEDENT;
    }
    return YAML_GAMMA;
}

\n {
    CTX->current_column = 0;
    CTX->quoted_value_closed_on_line = 0;
    /* In flow context, newlines are just whitespace, don't check indentation */
    if (FLOW_DELIM_SP == 0) {
        BEGIN(INDENT_CHECK);
    } else {
        int top = FLOW_DELIM_SP - 1;
        if (top >= 0 &&
            (FLOW_INDENT_REQUIRED_STACK[top] || flow_key_state_is(CTX, FLOW_KEY_CANDIDATE))) {
            int look_buf[4096];
            int look_n = 0;
            int indent = 0;
            int first_content = -1;
            int c;
            int close_ch = (FLOW_DELIM_STACK[top] == '{') ? '}' : ']';
            int baseline = FLOW_INDENT_REF_STACK[top];

            while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
                look_buf[look_n++] = c;

                if (c == ' ') {
                    indent++;
                    continue;
                }
                if (c == '\t') {
                    indent++;
                    continue;
                }
                if (c == '\r') {
                    continue;
                }
                if (c == '\n') {
                    indent = 0;
                    continue;
                }
                if (c == '#') {
                    while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
                        look_buf[look_n++] = c;
                        if (c == '\n') break;
                    }
                    indent = 0;
                    continue;
                }

                first_content = c;
                break;
            }

            for (int i = look_n - 1; i >= 0; i--) {
                unput(look_buf[i]);
            }

            if (flow_key_state_is(CTX, FLOW_KEY_CANDIDATE) &&
                first_content == ':' &&
                FLOW_DELIM_STACK[top] == '[') {
                yyerror(yylloc, yyscanner, "syntax error, implicit flow key followed by newline");
                CTX->semantic_error_count++;
                CTX->semantic_flow_key_newline_count++;
            }

            if (FLOW_INDENT_REQUIRED_STACK[top] &&
                first_content >= 0 &&
                first_content != close_ch &&
                indent <= baseline) {
                yyerror(yylloc, yyscanner, "syntax error, wrong indentation in flow sequence");
                CTX->semantic_error_count++;
                CTX->semantic_flow_indent_count++;
            }
        }
        flow_key_state_set(CTX, FLOW_KEY_NONE);
    }
    /* Otherwise skip the newline in flow context */
}



"%"/[ \t:] {
    if (FLOW_DELIM_SP > 0) {
        yylval->string = strdup("%");
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    return yytext[0];
}

"%TAG"           {
    if (!CTX->open_document_started) {
        yyerror(yylloc, yyscanner, "syntax error, missing document-end marker before directive");
        CTX->semantic_error_count++;
        CTX->semantic_directive_mid_doc_count++;
    }
    BEGIN(DIRECTIVE_MODE);
return TAG_DIRECTIVE;
}
"%YAML"[ ]?"1"[.,][0-9][ \t]+[^#\n][^\n]* {
    if (!CTX->open_document_started) {
        yylval->string = strdup(yytext);
        CTX->at_line_start = 0;
        CTX->last_was_value = 1;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->yaml_directive_seen) {
        yyerror(yylloc, yyscanner, "syntax error, duplicate %YAML directive");
        CTX->semantic_error_count++;
    } else {
        CTX->yaml_directive_seen = 1;
    }
    yyerror(yylloc, yyscanner, "syntax error, extra content on %YAML directive");
    CTX->semantic_error_count++;
    if (!CTX->open_document_started) {
        CTX->semantic_directive_mid_doc_count++;
    }
return YAML_DIRECTIVE;
}
"%YAML"[ ]?"1"[.,][0-9]"#"[^\n]* {
    if (!CTX->open_document_started) {
        yylval->string = strdup(yytext);
        CTX->at_line_start = 0;
        CTX->last_was_value = 1;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->yaml_directive_seen) {
        yyerror(yylloc, yyscanner, "syntax error, duplicate %YAML directive");
        CTX->semantic_error_count++;
    } else {
        CTX->yaml_directive_seen = 1;
    }
    yyerror(yylloc, yyscanner, "syntax error, missing whitespace before %YAML comment");
    CTX->semantic_error_count++;
    if (!CTX->open_document_started) {
        CTX->semantic_directive_mid_doc_count++;
    }
return YAML_DIRECTIVE;
}
"%YAML"[ ]?"1"[.,][0-9][ \t]*(#[^\n]*)?  {
    if (!CTX->open_document_started) {
        yylval->string = strdup(yytext);
        CTX->at_line_start = 0;
        CTX->last_was_value = 1;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->yaml_directive_seen) {
        yyerror(yylloc, yyscanner, "syntax error, duplicate %YAML directive");
        CTX->semantic_error_count++;
    } else {
        CTX->yaml_directive_seen = 1;
    }
    if (!CTX->open_document_started) {
        yyerror(yylloc, yyscanner, "syntax error, missing document-end marker before directive");
        CTX->semantic_error_count++;
        CTX->semantic_directive_mid_doc_count++;
    }
return YAML_DIRECTIVE;
}
"%"[a-zA-Z][^\n]* {
    if (!CTX->open_document_started) {
        yyerror(yylloc, yyscanner, "syntax error, missing document-end marker before directive");
        CTX->semantic_error_count++;
        CTX->semantic_directive_mid_doc_count++;
    }
    /* Unknown directive - skip */
}
"---"[ \t]+"&"{ANCHOR_CHAR}+[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    yyerror(yylloc, yyscanner, "syntax error, anchored mapping key is not allowed on document-start line");
    CTX->semantic_error_count++;
    yyless(3);
    CTX->expecting_value = 1;
    CTX->last_was_value = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 0;
    CTX->yaml_directive_seen = 0;
return DOC_START;
}
"---" {
    CTX->expecting_value = 1;
    CTX->last_was_value = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 0;
    CTX->yaml_directive_seen = 0;
return DOC_START;
}
"..."[ \t]*[^ \t\n\r#] {
    yyerror(yylloc, yyscanner, "content after document-end marker");
    CTX->semantic_error_count++;
    yyless(3);
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 1;
    CTX->yaml_directive_seen = 0;
return DOC_END;
}
"..." {
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 1;
    CTX->yaml_directive_seen = 0;
return DOC_END;
}
<DIRECTIVE_MODE>{
    [ \t]+          { /* skip space */ }
    \n              { BEGIN(INITIAL); }
}
"-"[ \t]*"#"[^\n]*\n {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP == 0) BEGIN(INDENT_CHECK);
return BULLET_EOL;
}
"-"[ \t]*\n {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP == 0) BEGIN(INDENT_CHECK);
return BULLET_EOL;
}
"-"/[ \t\n]      {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    colon_state_set(CTX, COLON_STATE_NONE);
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return BULLET;
}
"-"[ \t]*"," {
    if (FLOW_DELIM_SP > 0) {
        yyerror(yylloc, yyscanner, "syntax error, bare dash is not a valid flow scalar");
        CTX->semantic_error_count++;
    }
    yyless(1);
    yylval->string = strdup("-");
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}
"-"[ \t]*"]" {
    if (FLOW_DELIM_SP > 0) {
        yyerror(yylloc, yyscanner, "syntax error, bare dash is not a valid flow scalar");
        CTX->semantic_error_count++;
    }
    yyless(1);
    yylval->string = strdup("-");
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}
":"/[ \t\n] {
    if (CTX->complex_key_pending) {
        CTX->complex_key_pending = 0;
        CTX->at_line_start = 0;
        CTX->expecting_value = 1;
        colon_state_set(CTX, COLON_STATE_NONE);
        flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
    }
    if (FLOW_DELIM_SP == 0 && (CTX->at_line_start || CTX->expecting_value)) {
        /* Missing block mapping key, e.g. ": value" */
        yylval->string = strdup("");
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        yyless(0); /* Rescan ':' as the actual separator token */
return MAP_KEY;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
}
":"/[ \t]*[,}]   {
    CTX->at_line_start = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP > 0) {
        CTX->expecting_value = 1;
return COLON_EMPTY;
    }
    if (CTX->expecting_value) {
        yylval->string = strdup(":");
        CTX->expecting_value = 0;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    CTX->expecting_value = 1;
return COLON;
}
"&"{ANCHOR_CHAR}+[ \t]+{TAG_TOKEN}[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Anchored+tagged key: &anchor !!tag key: value -> "&anchor\tkey" */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *space = strchr(text, ' ');
    char *rest = NULL;
    char *packed = NULL;
    size_t packed_len = 0;

    if (!space) {
        yylval->string = text;
return MAP_KEY;
    }

    *space = '\0'; /* anchor part */
    rest = space + 1;
    while (*rest == ' ' || *rest == '\t') rest++;
    if (*rest == '!') {
        while (*rest && *rest != ' ' && *rest != '\t') rest++;
        while (*rest == ' ' || *rest == '\t') rest++;
    }
    trim_trailing_spaces(rest);

    packed_len = strlen(text) + 1 + strlen(rest) + 1;
    packed = (char*)malloc(packed_len);
    if (!packed) {
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    snprintf(packed, packed_len, "%s\t%s", text, rest);
    free(text);
    yylval->string = packed;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+{TAG_TOKEN}[ ]+\"([^\\\"\n\r]|\\.)*\"[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Anchored+tagged+double-quoted key: &anchor !!tag "key": value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *space = strpbrk(text, " \t");
    char *rest = NULL;
    char *key = NULL;
    char *packed = NULL;
    size_t packed_len = 0;

    if (!space) {
        yylval->string = text;
return MAP_KEY;
    }

    *space = '\0'; /* anchor part */
    rest = space + 1;
    while (*rest == ' ' || *rest == '\t') rest++;
    if (*rest == '!') {
        while (*rest && *rest != ' ' && *rest != '\t') rest++;
        while (*rest == ' ' || *rest == '\t') rest++;
    }
    key = extract_quoted_key(rest, '"');
    if (!key) {
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }

    packed_len = strlen(text) + 1 + strlen(key) + 1;
    packed = (char*)malloc(packed_len);
    if (!packed) {
        free(key);
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    snprintf(packed, packed_len, "%s\t%s", text, key);
    free(key);
    free(text);
    yylval->string = packed;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+{TAG_TOKEN}[ ]+\'(\'\'|\\'|[^'\n\r])*\'[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Anchored+tagged+single-quoted key: &anchor !!tag 'key': value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *space = strpbrk(text, " \t");
    char *rest = NULL;
    char *key = NULL;
    char *packed = NULL;
    size_t packed_len = 0;

    if (!space) {
        yylval->string = text;
return MAP_KEY;
    }

    *space = '\0'; /* anchor part */
    rest = space + 1;
    while (*rest == ' ' || *rest == '\t') rest++;
    if (*rest == '!') {
        while (*rest && *rest != ' ' && *rest != '\t') rest++;
        while (*rest == ' ' || *rest == '\t') rest++;
    }
    key = extract_quoted_key(rest, '\'');
    if (!key) {
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }

    packed_len = strlen(text) + 1 + strlen(key) + 1;
    packed = (char*)malloc(packed_len);
    if (!packed) {
        free(key);
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    snprintf(packed, packed_len, "%s\t%s", text, key);
    free(key);
    free(text);
    yylval->string = packed;
return ANCHOR_MAP_KEY;
}
{TAG_TOKEN}[ ]+"&"{ANCHOR_CHAR}+[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Tagged+anchored key: !!tag &anchor key: value -> "&anchor\tkey" */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *anchor = strchr(text, '&');
    char *space = anchor ? strchr(anchor, ' ') : NULL;
    char *rest = NULL;
    char *packed = NULL;
    size_t packed_len = 0;

    if (!anchor || !space) {
        yylval->string = text;
return MAP_KEY;
    }

    *space = '\0'; /* anchor part */
    rest = space + 1;
    while (*rest == ' ' || *rest == '\t') rest++;
    trim_trailing_spaces(rest);

    packed_len = strlen(anchor) + 1 + strlen(rest) + 1;
    packed = (char*)malloc(packed_len);
    if (!packed) {
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    snprintf(packed, packed_len, "%s\t%s", anchor, rest);
    free(text);
    yylval->string = packed;
return ANCHOR_MAP_KEY;
}
{TAG_TOKEN}[ ]+"&"{ANCHOR_CHAR}+[ \t]+\"([^\\\"\n\r]|\\.)*\"[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Tagged+anchored+double-quoted key: !!tag &anchor "key": value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *anchor = strchr(text, '&');
    char *space = anchor ? strpbrk(anchor, " \t") : NULL;
    char *rest = NULL;
    char *key = NULL;
    char *packed = NULL;
    size_t packed_len = 0;

    if (!anchor || !space) {
        yylval->string = text;
return MAP_KEY;
    }

    *space = '\0'; /* anchor part */
    rest = space + 1;
    while (*rest == ' ' || *rest == '\t') rest++;
    key = extract_quoted_key(rest, '"');
    if (!key) {
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }

    packed_len = strlen(anchor) + 1 + strlen(key) + 1;
    packed = (char*)malloc(packed_len);
    if (!packed) {
        free(key);
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    snprintf(packed, packed_len, "%s\t%s", anchor, key);
    free(key);
    free(text);
    yylval->string = packed;
return ANCHOR_MAP_KEY;
}
{TAG_TOKEN}[ ]+"&"{ANCHOR_CHAR}+[ \t]+\'(\'\'|\\'|[^'\n\r])*\'[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Tagged+anchored+single-quoted key: !!tag &anchor 'key': value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *anchor = strchr(text, '&');
    char *space = anchor ? strpbrk(anchor, " \t") : NULL;
    char *rest = NULL;
    char *key = NULL;
    char *packed = NULL;
    size_t packed_len = 0;

    if (!anchor || !space) {
        yylval->string = text;
return MAP_KEY;
    }

    *space = '\0'; /* anchor part */
    rest = space + 1;
    while (*rest == ' ' || *rest == '\t') rest++;
    key = extract_quoted_key(rest, '\'');
    if (!key) {
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }

    packed_len = strlen(anchor) + 1 + strlen(key) + 1;
    packed = (char*)malloc(packed_len);
    if (!packed) {
        free(key);
        free(text);
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    snprintf(packed, packed_len, "%s\t%s", anchor, key);
    free(key);
    free(text);
    yylval->string = packed;
return ANCHOR_MAP_KEY;
}
{TAG_TOKEN}[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Tagged map key: !!str key: value (tag prefix is discarded, only key text returned) */
    yylval->string = extract_key_after_prefix(yytext);
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
return MAP_KEY;
}
\"([^\\\"\n\r]|\\.)*\"[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Double-quoted map key: "key" : value */
    if (FLOW_DELIM_SP == 0 && CTX->expecting_value && !CTX->at_line_start) {
        yylval->string = extract_quoted_key(yytext, '"');
        if (!yylval->string) {
            yyerror(yylloc, yyscanner, "memory allocation failed");
            return 0;
        }
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        CTX->quoted_value_closed_on_line = 1;
return QSCALAR;
    }

    yylval->string = extract_quoted_key(yytext, '"');
    if (!yylval->string) {
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
return MAP_KEY;
}
\'(\'\'|\\'|[^'\n\r])*\'[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Single-quoted map key: 'key' : value */
    if (FLOW_DELIM_SP == 0 && CTX->expecting_value && !CTX->at_line_start) {
        yylval->string = extract_quoted_key(yytext, '\'');
        if (!yylval->string) {
            yyerror(yylloc, yyscanner, "memory allocation failed");
            return 0;
        }
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        CTX->quoted_value_closed_on_line = 1;
return SSCALAR;
    }

    yylval->string = extract_quoted_key(yytext, '\'');
    if (!yylval->string) {
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
return MAP_KEY;
}
\"([^\\\"\n\r]|\\.)*\n([^\\\"\n\r]|\\.)*\"[ ]*/":"([ \t\n]|{VSPACE}) {
    if (FLOW_DELIM_SP > 0) {
        yylval->string = extract_quoted_key(yytext, '"');
        if (!yylval->string) {
            yyerror(yylloc, yyscanner, "memory allocation failed");
            return 0;
        }
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
return MAP_KEY;
    }
    yyerror(yylloc, yyscanner, "syntax error, multiline quoted key is not allowed");
    CTX->semantic_error_count++;
    CTX->semantic_multiline_qkey_count++;
    return 0;
}
\'(\'\'|\\'|[^'\n\r])*\n(\'\'|\\'|[^'\n\r])*\'[ ]*/":"([ \t\n]|{VSPACE}) {
    if (FLOW_DELIM_SP > 0) {
        yylval->string = extract_quoted_key(yytext, '\'');
        if (!yylval->string) {
            yyerror(yylloc, yyscanner, "memory allocation failed");
            return 0;
        }
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
return MAP_KEY;
    }
    yyerror(yylloc, yyscanner, "syntax error, multiline quoted key is not allowed");
    CTX->semantic_error_count++;
    CTX->semantic_multiline_qkey_count++;
    return 0;
}
"&"{ANCHOR_CHAR}+[ \t]+\"[^\\"\n\r]*\"[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Anchored double-quoted map key: &anchor "key": value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *sep = strpbrk(text, " \t");
    if (sep) {
        char *key = sep + 1;
        *sep = '\t';
        while (*key == ' ' || *key == '\t') key++;
        trim_trailing_spaces(key);
        size_t klen = strlen(key);
        if (klen >= 2 && key[0] == '"' && key[klen - 1] == '"') {
            memmove(key, key + 1, klen - 2);
            key[klen - 2] = '\0';
        }
    }
    yylval->string = text;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+'[^'\n\r]*'[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Anchored single-quoted map key: &anchor 'key': value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *sep = strpbrk(text, " \t");
    if (sep) {
        char *key = sep + 1;
        *sep = '\t';
        while (*key == ' ' || *key == '\t') key++;
        trim_trailing_spaces(key);
        size_t klen = strlen(key);
        if (klen >= 2 && key[0] == '\'' && key[klen - 1] == '\'') {
            memmove(key, key + 1, klen - 2);
            key[klen - 2] = '\0';
        }
    }
    yylval->string = text;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Anchored map key: &anchor key: value (returns tab-delimited "&anchor\tkey") */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    
    /* Split on first space: "&anchor key" -> "&anchor\tkey" */
    char *text = strdup(yytext);
    char *space = strchr(text, ' ');
    if (space) {
        *space = '\t';  /* Tab delimiter separates anchor from key */
        trim_trailing_spaces(space + 1);  /* Trim key part only */
    }
    yylval->string = text;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+\[[^\]\n\r]*\][ ]*/":"([ \t\n]|{VSPACE}) {
    /* Anchored flow-sequence key: &anchor [ ... ]: value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *space = strchr(text, ' ');
    if (space) {
        *space = '\t';
        trim_trailing_spaces(space + 1);
    }
    yylval->string = text;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+\{[^\}\n\r]*\}[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Anchored flow-mapping key: &anchor { ... }: value */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;

    char *text = strdup(yytext);
    char *space = strchr(text, ' ');
    if (space) {
        *space = '\t';
        trim_trailing_spaces(space + 1);
    }
    yylval->string = text;
return ANCHOR_MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+"-"/[ \t\n] {
    int anchor_len = 0;
    yyerror(yylloc, yyscanner, "syntax error, anchor cannot prefix a sequence indicator on the same line");
    CTX->semantic_error_count++;

    while (anchor_len < yyleng &&
           yytext[anchor_len] != ' ' &&
           yytext[anchor_len] != '\t') {
        anchor_len++;
    }

    yylval->string = (char*)malloc((size_t)anchor_len + 1);
    if (!yylval->string) {
        yyerror(yylloc, yyscanner, "memory allocation failed");
        return 0;
    }
    memcpy(yylval->string, yytext, (size_t)anchor_len);
    yylval->string[anchor_len] = '\0';

    yyless(anchor_len);
    CTX->at_line_start = 0;
return ANCHOR;
}
"*"{ALIAS_CHAR}+[ ]+/":"([ \t\n]|{VSPACE}) {
    /* Alias map key with explicit separating whitespace before ':' */
    CTX->at_line_start = 0;
    yylval->string = strdup(yytext + 1);
    trim_trailing_spaces(yylval->string);
    CTX->expecting_value = 0;
return MAP_KEY;
}
"*"{ALIAS_CHAR}+":"/([ \t\n]|{VSPACE}) {
    CTX->at_line_start = 0;

    if (CTX->expecting_value) {
        /* Value-position alias ending with ':' keeps the ':' in the alias name. */
        yylval->string = strdup(yytext);
        CTX->expecting_value = 0;
        if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return ALIAS;
    }

    /* Key-position alias: split before ':' and let parser consume ':' token. */
    yyless(yyleng - 1);
    yylval->string = strdup(yytext + 1);
    CTX->expecting_value = 0;
return MAP_KEY;
}
"["              {
    int require_flow_indent = (FLOW_DELIM_SP == 0 && !CTX->at_line_start);
    int flow_ref_indent = CTX->indent_stack[CTX->indent_sp];
    CTX->at_line_start = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP < 100) {
        FLOW_DELIM_STACK[FLOW_DELIM_SP] = '[';
        FLOW_INDENT_REF_STACK[FLOW_DELIM_SP] = flow_ref_indent;
        FLOW_INDENT_REQUIRED_STACK[FLOW_DELIM_SP] = require_flow_indent;
        FLOW_DELIM_SP++;
    }
    CTX->expecting_value = 1;
return LBRACK;
}
"]"              {
    if (FLOW_DELIM_SP > 0) {
        FLOW_DELIM_SP--;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    flow_key_state_set(CTX, FLOW_DELIM_SP > 0 ? FLOW_KEY_CANDIDATE : FLOW_KEY_NONE);
return RBRACK;
}
"{"              {
    int require_flow_indent = (FLOW_DELIM_SP == 0 && !CTX->at_line_start);
    int flow_ref_indent = CTX->indent_stack[CTX->indent_sp];
    CTX->at_line_start = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP < 100) {
        FLOW_DELIM_STACK[FLOW_DELIM_SP] = '{';
        FLOW_INDENT_REF_STACK[FLOW_DELIM_SP] = flow_ref_indent;
        FLOW_INDENT_REQUIRED_STACK[FLOW_DELIM_SP] = require_flow_indent;
        FLOW_DELIM_SP++;
    }
    CTX->expecting_value = 1;
return LBRACE;
}
"}"              {
    if (FLOW_DELIM_SP > 0) {
        FLOW_DELIM_SP--;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    flow_key_state_set(CTX, FLOW_DELIM_SP > 0 ? FLOW_KEY_CANDIDATE : FLOW_KEY_NONE);
return RBRACE;
}
":"              { 
    if (CTX->expecting_value && FLOW_DELIM_SP > 0) {
         yylval->string = strdup(":");
         CTX->expecting_value = 0;
         flow_key_state_set(CTX, FLOW_KEY_NONE);
         BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    } else if (CTX->expecting_value && FLOW_DELIM_SP == 0) {
         yylval->string = strdup(":");
         flow_key_state_set(CTX, FLOW_KEY_NONE);
         BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    } else if (FLOW_DELIM_SP > 0) {
         CTX->expecting_value = 1;
         flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
    } else {
         return ':'; 
    }
}
","/"#" {
    if (FLOW_DELIM_SP > 0) {
        CTX->semantic_error_count++;
        CTX->semantic_flow_comment_comma_count++;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COMMA;
}
","/[ \t]*"," {
    if (FLOW_DELIM_SP > 0) {
        CTX->semantic_error_count++;
        CTX->semantic_flow_comma_count++;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COMMA;
}
"," {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COMMA;
}
\" {
    BEGIN(QUOTED);
}

<QUOTED>{
    \" {
        BEGIN(INITIAL);
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        CTX->quoted_value_closed_on_line = 1;
        if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return QSCALAR;
    }
    
    \\n {
        yylval->string = strdup("\\n");
return CH_ESC_N;
    }
    \\t {
        yylval->string = strdup("\\t");
return CH_ESC_T;
    }
    \\r {
        yylval->string = strdup("\\r");
return CH_ESC_R;
    }
    \\\\ {
        yylval->string = strdup("\\\\");
return CH_ESC_BS;
    }
    \\\" {
        yylval->string = strdup("\\\"");
return CH_ESC_QU;
    }
    \\\' {
        yyerror(yylloc, yyscanner, "syntax error, invalid escape in quoted string");
        BEGIN(INITIAL);
        return 0;
    }
    \\\/ {
        yylval->string = strdup("\\/");
return CH_ESC_SL;
    }
    \\. {
        if (yytext[1] == '.') {
            yyerror(yylloc, yyscanner, "syntax error, invalid escape in quoted string");
            BEGIN(INITIAL);
            return 0;
        }
        yylval->string = strdup(yytext);
return CH_RAW;
    }
    \\0 {
        yylval->string = strdup("\\0");
return CH_ESC_0;
    }
    [^\\\"\n]+ {
        yylval->string = strdup(yytext);
return CH_RAW;
    }
    \n("---"|"...")([ \t]|#|\r?\n) {
        yyerror(yylloc, yyscanner, "syntax error, document marker inside quoted string");
        BEGIN(INITIAL);
        return 0;
    }
    \n {
        yylval->string = strdup("\n");
return CH_RAW;
    }

    <<EOF>> {
        yyerror(yylloc, yyscanner, "syntax error, unterminated quoted string");
        BEGIN(INITIAL);
        return 0;
    }
}
\'(\'\'|[^\'])*\n("---"|"...")([ \t]|#|\r?\n)(\'\'|[^\'])*\'  {
    yyerror(yylloc, yyscanner, "syntax error, document marker inside single-quoted string");
    CTX->semantic_error_count++;

    int len = strlen(yytext);
    char *content = malloc(len);
    int j = 0;

    for (int i = 1; i < len - 1; i++) {
        if (yytext[i] == '\'' && yytext[i+1] == '\'') {
            content[j++] = '\'';
            i++;
        } else {
            content[j++] = yytext[i];
        }
    }
    content[j] = '\0';

    yylval->string = content;
    CTX->expecting_value = 0;
    CTX->last_was_value = 1;
    CTX->quoted_value_closed_on_line = 1;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return SSCALAR;
}
\'(\'\'|[^\'])*\'  { 
    /* Single-quoted string: '' is escaped quote, [^'] is any char except quote */
    int len = strlen(yytext);
    char *content = malloc(len);  /* Temp buffer to process escapes */
    int j = 0;
    
    /* Copy content (between quotes), handling '' -> ' */
    for (int i = 1; i < len - 1; i++) {
        if (yytext[i] == '\'' && yytext[i+1] == '\'') {
            content[j++] = '\'';
            i++;  /* Skip next quote */
        } else {
            content[j++] = yytext[i];
        }
    }
    content[j] = '\0';
    
    yylval->string = content;
    CTX->expecting_value = 0;
    CTX->last_was_value = 1;
    CTX->quoted_value_closed_on_line = 1;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return SSCALAR;
}
"|"([1-9][-+]?|[-+][1-9]?|[-+]|[1-9])?[ \t]*(\n|[ \t]+#.*)      {
    int explicit_indent = parse_block_indent_indicator(yytext);
    CTX->expecting_value = 0;
    CTX->last_was_value = 0;
    CTX->block_scalar.type = '|';
    CTX->block_scalar.indent = explicit_indent > 0
        ? CTX->indent_stack[CTX->indent_sp] + explicit_indent
        : -1;
    CTX->block_scalar.leading_empty_max_indent = 0;
    CTX->block_scalar.first_content_seen = 0;
    BEGIN(BLOCK_SCALAR);
}
">"([1-9][-+]?|[-+][1-9]?|[-+]|[1-9])?[ \t]*(\n|[ \t]+#.*)      {
    int explicit_indent = parse_block_indent_indicator(yytext);
    CTX->expecting_value = 0;
    CTX->last_was_value = 0;
    CTX->block_scalar.type = '>';
    CTX->block_scalar.indent = explicit_indent > 0
        ? CTX->indent_stack[CTX->indent_sp] + explicit_indent
        : -1;
    CTX->block_scalar.leading_empty_max_indent = 0;
    CTX->block_scalar.first_content_seen = 0;
    BEGIN(BLOCK_SCALAR);
}

<BLOCK_SCALAR>^([ \t]|{VSPACE})*\n {
    int indent = 0;
    int i = 0;
    int had_tab_in_prefix = 0;
    while (i < yyleng && yytext[i] != '\n') {
        unsigned char ch = (unsigned char)yytext[i];
        if (ch == ' ' || ch == '\t') {
            if (ch == '\t') had_tab_in_prefix = 1;
            indent++;
            i++;
        } else if (ch == 0xE2 && (i + 2) < yyleng &&
                   (unsigned char)yytext[i + 1] == 0x90 &&
                   (unsigned char)yytext[i + 2] == 0xA3) {
            indent++;
            i += 3;
        } else {
            i++;
        }
    }
    if (!CTX->block_scalar.first_content_seen &&
        !had_tab_in_prefix &&
        indent > CTX->block_scalar.leading_empty_max_indent) {
        CTX->block_scalar.leading_empty_max_indent = indent;
    }
    yylval->string = strdup("\n");
return BPART;
}

<BLOCK_SCALAR>^([ \t]|{VSPACE})+ {
    int indent = 0;
    int effective_indent = 0;
    int i = 0;
    int had_tab_in_prefix = 0;
    int first_tab_col = -1;
    char line_buf[4096];
    int line_len = 0;
    int c;
    int is_blank_line = 1;

    while (i < yyleng) {
        unsigned char ch = (unsigned char)yytext[i];
        if (ch == ' ' || ch == '\t') {
            if (ch == '\t') {
                had_tab_in_prefix = 1;
                if (first_tab_col < 0) {
                    first_tab_col = indent;
                }
            }
            indent++;
            i++;
        } else if (ch == 0xE2 && (i + 2) < yyleng &&
                   (unsigned char)yytext[i + 1] == 0x90 &&
                   (unsigned char)yytext[i + 2] == 0xA3) {
            indent++;
            i += 3;
        } else {
            i++;
        }
    }

    effective_indent = indent;
    if (CTX->block_scalar.indent == -1 && first_tab_col >= 0) {
        /* For implicit indentation, treat first tab as content boundary.
         * Tabs before that boundary are still indentation and rejected.
         */
        effective_indent = first_tab_col;
    }

    if (had_tab_in_prefix) {
        int required_indent = CTX->block_scalar.indent;
        if (required_indent == -1) {
            required_indent = effective_indent;
        }
        if (first_tab_col >= 0 && first_tab_col < required_indent) {
        yyerror(yylloc, yyscanner, "syntax error, tab indentation is not allowed in block scalars");
        CTX->semantic_error_count++;
        CTX->semantic_indent_tab_count++;
        }
    }

    while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0) {
        if (line_len < 4095) line_buf[line_len++] = c;
        if (c != ' ' && c != '\t') {
            is_blank_line = 0;
        }
    }
    if (c == '\n') line_buf[line_len++] = '\n';
    line_buf[line_len] = '\0';

    if (!CTX->block_scalar.first_content_seen) {
        if (is_blank_line && !had_tab_in_prefix) {
            if (indent > CTX->block_scalar.leading_empty_max_indent) {
                CTX->block_scalar.leading_empty_max_indent = indent;
            }
        } else {
            CTX->block_scalar.first_content_seen = 1;
            if (indent < CTX->block_scalar.leading_empty_max_indent) {
                yyerror(yylloc, yyscanner, "syntax error, wrong indentation after leading empty block-scalar lines");
                CTX->semantic_error_count++;
            }
        }
    }

    if (CTX->block_scalar.indent == -1) {
        CTX->block_scalar.indent = effective_indent;
    }
    
    if (effective_indent >= CTX->block_scalar.indent) {
        /* This is content line */
        int skip = CTX->block_scalar.indent;
        
        /* copy extra spaces if indent > block_indent */
        if (effective_indent > skip) {
            int extra = effective_indent - skip;
            char out_buf[4096];
            int out_len = 0;
            for (int k = 0; k < extra && out_len < 4095; k++) {
                out_buf[out_len++] = ' ';
            }
            for (int k = 0; line_buf[k] != '\0' && out_len < 4095; k++) {
                out_buf[out_len++] = line_buf[k];
            }
            out_buf[out_len] = '\0';
            yylval->string = strdup(out_buf);
        } else {
            yylval->string = strdup(line_buf);
        }
return BPART;
    } else {
        /* End of block scalar - line is less indented */
        int push_start = line_len - 1;
        if (line_len > 0 && line_buf[line_len - 1] == '\n') {
            push_start = line_len - 2;
            unput('\n');
        }
        for (int k = push_start; k >= 0; k--) {
            unput(line_buf[k]);
        }
        yyless(0); 
        BEGIN(INDENT_CHECK);
        CTX->at_line_start = 1;
        /* No token, grammar will reduce bscalar */
    }
}

<BLOCK_SCALAR>. {
    /* Root-level block scalars may legitimately use zero-indented content. */
    if (CTX->block_scalar.indent <= 0 &&
        yytext[0] != '\n' &&
        yytext[0] != '\r') {
        char line_buf[4096];
        int line_len = 0;
        int c = yytext[0];

        line_buf[line_len++] = (char)c;
        while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0) {
            if (line_len < 4095) {
                line_buf[line_len++] = (char)c;
            }
        }
        if (c == '\n' && line_len < 4095) {
            line_buf[line_len++] = '\n';
        }
        line_buf[line_len] = '\0';

        if (CTX->block_scalar.indent == -1) {
            CTX->block_scalar.indent = 0;
        }
        CTX->block_scalar.first_content_seen = 1;
        yylval->string = strdup(line_buf);
return BPART;
    }

    /* Non-indented line starts a new construct once block scalar is closed. */
    yyless(0);
    BEGIN(INDENT_CHECK);
}

<BLOCK_SCALAR><<EOF>> {
    BEGIN(INITIAL);
}




[^ \t\n\r\[\]{}!,&*%@|>\`'":]([^ \n\r:]|[ ]|:[^ \t\n\r\xE2])*/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Plain map key: key: value (complex pattern allows colons inside key text) */
    if (FLOW_DELIM_SP == 0 && !CTX->at_line_start && !CTX->expecting_value && CTX->quoted_value_closed_on_line) {
        CTX->semantic_error_count++;
        CTX->semantic_inline_key_count++;
    }
    if (FLOW_DELIM_SP > 0) {
        /* In flow context, parse key text incrementally; avoid swallowing commas/brackets. */
        yyless(1);
        if (yytext[0] == ':') {
            CTX->expecting_value = 1;
            flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
        }
        yylval->string = strdup(yytext);
        CTX->expecting_value = 0;
        flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->at_line_start && yytext[0] == '-' && yyleng > 1 &&
        (yytext[1] == ' ' || yytext[1] == '\t')) {
        /* Reuse BULLET tokenization for sequence indicators at line start. */
        yyless(1);
        CTX->at_line_start = 0;
        CTX->expecting_value = 1;
return BULLET;
    }
    yylval->string = strdup(yytext);
    trim_trailing_spaces(yylval->string);  /* Remove trailing spaces from key */
    if (strstr(yylval->string, " #") != NULL) {
        yyerror(yylloc, yyscanner, "syntax error, comment cannot appear inside an unquoted mapping key");
        CTX->semantic_error_count++;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    CTX->quoted_value_closed_on_line = 0;
return MAP_KEY;
}

[^ \t\n\r\[\]{}!,&*%@|>\`'"] {
    yylval->string = strdup(yytext);
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}

":"[a-zA-Z0-9\-\._]+ {
    if (FLOW_DELIM_SP > 0 && !CTX->expecting_value) {
        yyless(1);
        CTX->expecting_value = 1;
        flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
    }
    yylval->string = strdup(yytext);
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}

<PLAIN_SCALAR_CONT>":"/[ \t\n\r] {
    /* Colon followed by space/tab/newline ends the scalar */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>":"/[ \t]*[,}] {
    /* In explicit-key contexts, ':' before ','/'}' is a key/value separator. */
    if (CTX->complex_key_pending) {
        yyless(0);
        BEGIN(INITIAL);
    } else {
        yylval->string = strdup(":");
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT>\n[ ]*-[ \t][^\n\r]*/\n {
    /* A nested/sibling block sequence indicator terminates plain continuation. */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>\n[ ]*-[ \t]*\n {
    /* Also terminate on bare dash items ("-" with optional trailing spaces). */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>\n[ ]*\n[ ]+([^:\n\r]|:[^ \t\n\r])*/\n {
    /* Blank line + indented continuation => preserve one logical newline. */
    const char *p = yytext + 1; /* skip first newline */
    while (*p == ' ') p++;
    if (*p == '\n') p++;
    while (*p == ' ') p++;
    if (FLOW_DELIM_SP > 0 && (*p == ']' || *p == '}' || *p == ',')) {
        yyless(0);
        BEGIN(INITIAL);
    } else {
    size_t n = strlen(p);
    char *s = malloc(n + 2);
    s[0] = '\n';
    memcpy(s + 1, p, n + 1);
    yylval->string = s;
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT>\n[ ]+([^:\n\r]|:[^ \t\n\r])*/\n {
    /* Indented continuation line => fold to space. */
    const char *p = yytext + 1; /* skip newline */
    while (*p == ' ') p++;
    if (FLOW_DELIM_SP > 0 && (*p == ']' || *p == '}' || *p == ',')) {
        yyless(0);
        BEGIN(INITIAL);
    } else {
    size_t n = strlen(p);
    char *s = malloc(n + 2);
    s[0] = ' ';
    memcpy(s + 1, p, n + 1);
    yylval->string = s;
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT>[ \t]+/#[^\n\r]* {
    /* Comment starts after whitespace; terminate scalar before comment. */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>[ \t]+ {
    yylval->string = strdup(yytext);
return CH_RAW;
}

<PLAIN_SCALAR_CONT>[^:\n\r\t,\[\]{} ]+ {
    yylval->string = strdup(yytext);
return CH_RAW;
}

<PLAIN_SCALAR_CONT>":" {
    yylval->string = strdup(":");
return CH_RAW;
}

<PLAIN_SCALAR_CONT>"\n" {
    /* Terminator for plain scalar */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>[\{\}\[\],] {
    if (FLOW_DELIM_SP > 0) {
        /* Flow indicators terminate plain scalars in flow context. */
        yyless(0);
        BEGIN(INITIAL);
    } else {
        yylval->string = strdup(yytext);
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT><<EOF>> {
    BEGIN(INITIAL);
}

[ \t]+"#" {
    /* Skip rest of line */
    int c;
    while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0);
    if (c == '\n') unput('\n');
}

^"#" {
    /* Skip rest of line */
    int c;
    while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0);
    if (c == '\n') unput('\n');
}
[ \t\r]+       { CTX->last_was_value = 0; /* skip whitespace */ }
{VSPACE}+      { CTX->last_was_value = 0; /* yaml-test-suite visible space marker */ }
{VEND}         { CTX->last_was_value = 0; /* yaml-test-suite end marker */ }
.                { return yytext[0]; }

<<EOF>> {
    if (PENDING_DEDENT_COUNT > 0) {
        yylval->ival = PENDING_DEDENT_COUNT;
        PENDING_DEDENT_COUNT--;
return DEDENT;
    }
    if (CTX->indent_sp > 0) {
        int dedent_count = CTX->indent_sp;
        CTX->indent_sp = 0;
        return return_dedent_count(CTX, dedent_count, yylval);
    }
    return YAML_GAMMA;
}

%%
