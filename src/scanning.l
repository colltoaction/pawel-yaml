%{
#include "parsing.tab.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* LexerContext type is defined in parsing.y's %code requires and included via parsing.tab.h */

#define YYSTYPE PARSING_YY_STYPE
#define YYLTYPE PARSING_YY_LTYPE

/* Forward declaration for error handling */
void parsing_yy_error(void *yylloc, yyscan_t scanner, const char *msg);

/* Lexer context - replaces all global variables */
#define CTX yyextra

/* === INLINED: lexer_context.c - Unified Lexer State Management === */

/**
 * Create a new lexer context with default initialization
 */
LexerContext *lexer_context_new(void) {
    LexerContext *ctx = (LexerContext*)malloc(sizeof(LexerContext));
    if (!ctx) return NULL;
    
    /* Initialize indentation tracking */
    ctx->indent_stack[0] = 0;
    ctx->indent_sp = 0;
    
    /* Initialize flow and value tracking */
    ctx->flow_level = 0;
    ctx->expecting_value = 0;
    ctx->pending_dedents = 0;
    
    /* Initialize document state */
    ctx->first_line = 1;
    ctx->last_was_value = 0;
    ctx->at_line_start = 1;
    ctx->complex_key_pending = 0;
    ctx->pending_colon = 0;
    
    /* Initialize block scalar state */
    ctx->block_scalar.type = '\0';
    ctx->block_scalar.indent = -1;
    
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
    ctx->semantic_error_count = 0;
    ctx->semantic_indent_tab_count = 0;
    
    return ctx;
}

/**
 * Create a new lexer context with argc/argv for mode selection
 */
static LexerContext *lexer_context_new_with_args(int argc, char **argv) {
    LexerContext *ctx = lexer_context_new();
    if (ctx) {
        ctx->argc = argc;
        ctx->argv = argv;
    }
    return ctx;
}

/**
 * Free lexer context and all associated resources
 */
void lexer_context_free(LexerContext *ctx) {
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
    ctx->flow_level = 0;
    ctx->expecting_value = 0;
    ctx->pending_dedents = 0;
    ctx->first_line = 1;
    ctx->last_was_value = 0;
    ctx->at_line_start = 1;
    ctx->complex_key_pending = 0;
    ctx->pending_colon = 0;
    
    ctx->block_scalar.type = '\0';
    ctx->block_scalar.indent = -1;
    
    ctx->scalar.len = 0;
    if (ctx->scalar.content) {
        ctx->scalar.content[0] = '\0';
    }
    
    ctx->indent_context_sp = 0;
    ctx->scalar_base_indent = 0;
    ctx->scalar_type = '\0';
    ctx->semantic_error_count = 0;
    ctx->semantic_indent_tab_count = 0;
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
    return ctx->flow_level > 0 || 
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
TAG_TOKEN ("!!"{NSCAL}+|"!"{NSCAL}+"!"{NSCAL}*|"!"{NSCAL}+)
PKEY_HEAD [^ \t\n\r\[\]{}!,&*%@|>\`'"]
PKEY_BODY [^:\n\r]*

%%

    if (CTX->first_line) {
        
        CTX->first_line = 0;
        BEGIN(INDENT_CHECK);
    }

    /* Handle pending dedents first */
    if (CTX->pending_dedents > 0) {
        CTX->pending_dedents--;
        return DEDENT;
    }

    /* Synthetic ':' after explicit-key shorthand '? key' */
    if (CTX->pending_colon) {
        CTX->pending_colon = 0;
        CTX->at_line_start = 0;
        CTX->expecting_value = 1;
        return COLON_IMPLICIT;
    }


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
    
    BEGIN(INITIAL);
    CTX->at_line_start = 1;
    int cur = CTX->indent_stack[CTX->indent_sp];
    if (indent > cur) {
        if (CTX->indent_sp < 99) {
            CTX->indent_stack[++CTX->indent_sp] = indent;
        }
        return INDENT;
    } else if (indent < cur) {
        while (indent < CTX->indent_stack[CTX->indent_sp]) {
            if (CTX->indent_sp > 0) CTX->indent_sp--;
            CTX->pending_dedents++;
        }
        if (CTX->pending_dedents > 0) {
            CTX->pending_dedents--;
            return DEDENT;
        }
    }
}

<INDENT_CHECK>. {
    /* Not an indent - likely at column 0 */
    yyless(0);
    BEGIN(INITIAL);
    CTX->at_line_start = 1;
    int cur = CTX->indent_stack[CTX->indent_sp];
    if (0 < cur) {
        while (0 < CTX->indent_stack[CTX->indent_sp]) {
            if (CTX->indent_sp > 0) CTX->indent_sp--;
            CTX->pending_dedents++;
        }
        if (CTX->pending_dedents > 0) {
            CTX->pending_dedents--;
            return DEDENT;
        }
    }
}

<INDENT_CHECK><<EOF>> {
    BEGIN(INITIAL);
    while (0 < CTX->indent_stack[CTX->indent_sp]) {
        if (CTX->indent_sp > 0) CTX->indent_sp--;
        CTX->pending_dedents++;
    }
    if (CTX->pending_dedents > 0) {
        CTX->pending_dedents--;
        return DEDENT;
    }
    yyterminate();
}

\n {
    /* In flow context, newlines are just whitespace, don't check indentation */
    if (CTX->flow_level == 0) {
        BEGIN(INDENT_CHECK);
    }
    /* Otherwise skip the newline in flow context */
}



"%TAG"           { BEGIN(DIRECTIVE_MODE); return TAG_DIRECTIVE; }
"%YAML"[ ]?"1"[.,][0-9]  { return YAML_DIRECTIVE; }
"%"[a-zA-Z][^\n]* { /* Unknown directive - skip */ }
"---"            { CTX->expecting_value = 1; CTX->last_was_value = 0; return DOC_START; }
"..."            { CTX->expecting_value = 1; return DOC_END; }

<DIRECTIVE_MODE>{
    [ \t]+          { /* skip space */ }
    \n              { BEGIN(INITIAL); }
    "!!!"{NSCAL}*   { parsing_yy_error(yylloc, yyscanner, "syntax error, malformed tag (triple '!')"); return BAD_TAG; }
    "!"{NSCAL}+"!"  { yylval->string = strdup(yytext); return TAG; }
    "!!"{NSCAL}+    { yylval->string = strdup(yytext); return TAG; }
    "!"{NSCAL}+     { yylval->string = strdup(yytext); return TAG; }
    [^ \t\n]+       { yylval->string = strdup(yytext); return SCALAR; }
}
"-"[ \t]*"#"[^\n]*\n {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    if (CTX->flow_level == 0) BEGIN(INDENT_CHECK);
    return BULLET_EOL;
}
"-"[ \t]*\n {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    if (CTX->flow_level == 0) BEGIN(INDENT_CHECK);
    return BULLET_EOL;
}
"-"/[ \t\n]      { CTX->at_line_start = 0; CTX->expecting_value = 1; return BULLET; }
":"/[ \t\n] {
    if (CTX->complex_key_pending) {
        CTX->complex_key_pending = 0;
        CTX->at_line_start = 0;
        CTX->expecting_value = 1;
        return COLON;
    }
    if (CTX->flow_level == 0 && CTX->at_line_start && !CTX->expecting_value) {
        /* Missing block mapping key, e.g. ": value" */
        yylval->string = strdup("");
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        yyless(0); /* Rescan ':' as the actual separator token */
        return MAP_KEY;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    return COLON;
}
":"/[ \t]*[,}]   { CTX->at_line_start = 0; if (CTX->flow_level > 0) { CTX->expecting_value = 1; return COLON_EMPTY; } CTX->expecting_value = 1; return COLON; }
":"/{VSPACE}     { CTX->at_line_start = 0; CTX->expecting_value = 1; return COLON; }

"?"[ ]+[^:\n\r]+[ ]*\n {
    /* If next logical line starts with ':', this is a complex key, not shorthand. */
    int look_buf[1024];
    int look_n = 0;
    int c = input(yyscanner);
    
    /* Skip whitespace, blank lines, and comments to find next real content */
    while (look_n < 1023) {
        if (c == ' ' || c == '\t') {
            look_buf[look_n++] = c;
            c = input(yyscanner);
        } else if (c == '\n') {
            /* Blank line - skip it */
            look_buf[look_n++] = c;
            c = input(yyscanner);
        } else if (c == '#') {
            /* Comment - skip to end of line */
            look_buf[look_n++] = c;
            while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0 && look_n < 1023) {
                look_buf[look_n++] = c;
            }
            if (c == '\n' && look_n < 1023) {
                look_buf[look_n++] = c;
                c = input(yyscanner);
            }
        } else {
            break;
        }
    }
    
    /* Save the final character we looked at */
    if (c != EOF && c != 0 && look_n < 1023) {
        look_buf[look_n++] = c;
    }
    
    /* Put everything back */
    for (int i = look_n - 1; i >= 0; i--) {
        unput(look_buf[i]);
    }
    
    if (c == ':') {
        yyless(1);
        CTX->at_line_start = 0;
        CTX->complex_key_pending = 1;
        CTX->expecting_value = 1;
        return QUESTION;
    }

    char *raw = strdup(yytext + 1);
    char *p = raw;
    while (*p == ' ' || *p == '\t') p++;
    yylval->string = strdup(p);
    free(raw);
    char *end = yylval->string + strlen(yylval->string);
    while (end > yylval->string && (end[-1] == '\n' || end[-1] == '\r' || end[-1] == ' ' || end[-1] == '\t')) end--;
    *end = '\0';
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    CTX->pending_colon = 1;
    if (CTX->flow_level == 0) BEGIN(INDENT_CHECK);
    return MAP_KEY;
}

"?"/[ \t\n]      { CTX->at_line_start = 0; CTX->complex_key_pending = 1; CTX->expecting_value = 1; return QUESTION; }
"?"/{VSPACE}     { CTX->at_line_start = 0; CTX->complex_key_pending = 1; CTX->expecting_value = 1; return QUESTION; }
"!!!"{NSCAL}*    { parsing_yy_error(yylloc, yyscanner, "syntax error, malformed tag (triple '!')"); return BAD_TAG; }
{TAG_TOKEN}[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Tagged map key: !!str key: value (tag prefix is discarded, only key text returned) */
    yylval->string = extract_key_after_prefix(yytext);
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    return MAP_KEY;
}
"!"              { CTX->at_line_start = 0; yylval->string = strdup("!"); return TAG; }
"!!"{NSCAL}+     { CTX->at_line_start = 0; yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+"!"{NSCAL}* { CTX->at_line_start = 0; yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+      { CTX->at_line_start = 0; yylval->string = strdup(yytext); return TAG; }
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
"&"{ANCHOR_CHAR}+     { CTX->at_line_start = 0; yylval->string = strdup(yytext); return ANCHOR; }
"*"{ALIAS_CHAR}+/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Alias as map key: *alias: value (returns alias name without '*' prefix) */
    CTX->at_line_start = 0;
    yylval->string = strdup(yytext + 1);
    CTX->expecting_value = 0;
    return MAP_KEY;
}
"*"{ALIAS_CHAR}+      { CTX->at_line_start = 0; yylval->string = strdup(yytext); CTX->expecting_value = 0; return ALIAS; }
"["              {
    if (CTX->flow_level == 0 && CTX->at_line_start && !CTX->expecting_value && !CTX->complex_key_pending) {
        int depth = 1;
        int look_buf[4096];
        int look_n = 0;
        int c;
        int found = 0;
        while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
            look_buf[look_n++] = c;
            if (c == '\n') break;
            if (c == '[' || c == '{') depth++;
            if (c == ']' || c == '}') depth--;
            if (depth == 0) {
                while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
                    look_buf[look_n++] = c;
                    if (c == ':') { found = 1; break; }
                    if (c == '\n' || c == '#') break;
                    if (c != ' ' && c != '\t') break;
                }
                break;
            }
        }
        for (int i = look_n - 1; i >= 0; i--) {
            unput(look_buf[i]);
        }
        if (found) {
            yyless(0);
            CTX->at_line_start = 0;
            CTX->complex_key_pending = 1;
            CTX->expecting_value = 1;
            return QUESTION;
        }
    }
    CTX->at_line_start = 0;
    CTX->flow_level++;
    CTX->expecting_value = 1;
    return LBRACK;
}
"]"              { CTX->at_line_start = 0; if (CTX->flow_level > 0) CTX->flow_level--; CTX->expecting_value = 0; return RBRACK; }
"{"              {
    if (CTX->flow_level == 0 && CTX->at_line_start && !CTX->expecting_value && !CTX->complex_key_pending) {
        int depth = 1;
        int look_buf[4096];
        int look_n = 0;
        int c;
        int found = 0;
        while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
            look_buf[look_n++] = c;
            if (c == '\n') break;
            if (c == '[' || c == '{') depth++;
            if (c == ']' || c == '}') depth--;
            if (depth == 0) {
                while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
                    look_buf[look_n++] = c;
                    if (c == ':') { found = 1; break; }
                    if (c == '\n' || c == '#') break;
                    if (c != ' ' && c != '\t') break;
                }
                break;
            }
        }
        for (int i = look_n - 1; i >= 0; i--) {
            unput(look_buf[i]);
        }
        if (found) {
            yyless(0);
            CTX->at_line_start = 0;
            CTX->complex_key_pending = 1;
            CTX->expecting_value = 1;
            return QUESTION;
        }
    }
    CTX->at_line_start = 0;
    CTX->flow_level++;
    CTX->expecting_value = 1;
    return LBRACE;
}
"}"              { CTX->at_line_start = 0; if (CTX->flow_level > 0) CTX->flow_level--; CTX->expecting_value = 0; return RBRACE; }
":"              { 
    if (CTX->expecting_value && CTX->flow_level > 0) {
         yylval->string = strdup(":");
         CTX->expecting_value = 0;
         BEGIN(PLAIN_SCALAR_CONT);
         return CH_RAW;
    } else if (CTX->expecting_value && CTX->flow_level == 0) {
         yylval->string = strdup(":");
         BEGIN(PLAIN_SCALAR_CONT);
         return CH_RAW;
    } else if (CTX->flow_level > 0) {
         CTX->expecting_value = 1;
         return COLON; 
    } else {
         return ':'; 
    }
}
","              { CTX->at_line_start = 0; CTX->expecting_value = 1; return COMMA; }

\"[^\"]*\"[ ]*: {
    // Extract quoted content
    size_t len = yyleng;
    // Remove trailing ':'
    while (len > 0 && yytext[len - 1] == ':') len--;
    // Remove trailing spaces
    while (len > 0 && yytext[len - 1] == ' ') len--;
    // Remove closing quote for content extraction
    if (len > 1 && yytext[len - 1] == '"') yytext[len - 1] = '\0';
    yylval->string = strdup(yytext + 1);  // Skip opening quote
    
    if (CTX->flow_level > 0) {
        // Flow context: return as QSCALAR, put back colon and spaces
        yyless(len);  // Keep only the quoted string part
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        return QSCALAR;
    } else {
        // Block context: return as QMAP_KEY, put back only colon
        yyless(yyleng - 1);
        CTX->at_line_start = 0;
        return QMAP_KEY;
    }
}

'[^']*'[ ]*: {
    // Extract quoted content
    size_t len = yyleng;
    // Remove trailing ':'
    while (len > 0 && yytext[len - 1] == ':') len--;
    // Remove trailing spaces
    while (len > 0 && yytext[len - 1] == ' ') len--;
    // Remove closing quote for content extraction
    if (len > 1 && yytext[len - 1] == '\'') yytext[len - 1] = '\0';
    yylval->string = strdup(yytext + 1);  // Skip opening quote
    
    if (CTX->flow_level > 0) {
        // Flow context: return as SSCALAR, put back colon and spaces
        yyless(len);  // Keep only the quoted string part
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        return SSCALAR;
    } else {
        // Block context: return as SMAP_KEY, put back only colon
        yyless(yyleng - 1);
        CTX->at_line_start = 0;
        return SMAP_KEY;
    }
}
\" {
    BEGIN(QUOTED);
}

<QUOTED>{
    \" {
        BEGIN(INITIAL);
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        return QSCALAR; 
    }
    
    \\n { yylval->string = strdup("\\n"); return CH_ESC_N; }
    \\t { yylval->string = strdup("\\t"); return CH_ESC_T; }
    \\r { yylval->string = strdup("\\r"); return CH_ESC_R; }
    \\\\ { yylval->string = strdup("\\\\"); return CH_ESC_BS; }
    \\\" { yylval->string = strdup("\\\""); return CH_ESC_QU; }
    \\\/ { yylval->string = strdup("\\/"); return CH_ESC_SL; }
    \\. {
        if (yytext[1] == '.') {
            parsing_yy_error(yylloc, yyscanner, "syntax error, invalid escape in quoted string");
            BEGIN(INITIAL);
            return 0;
        }
        yylval->string = strdup(yytext);
        return CH_RAW;
    }
    \\0 { yylval->string = strdup("\\0"); return CH_ESC_0; }
    
    [^\\\"\n]+ { yylval->string = strdup(yytext); return CH_RAW; }
    \n { yylval->string = strdup("\n"); return CH_RAW; }
    
    <<EOF>> {
        parsing_yy_error(yylloc, yyscanner, "syntax error, unterminated quoted string");
        BEGIN(INITIAL);
        return 0;
    }
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
    return SSCALAR;
}
"|"[1-9]*[-+]*[ \t]*(\n|[ \t]+#.*)      { yylval->string = strdup(yytext); CTX->expecting_value = 0; CTX->last_was_value = 0; CTX->block_scalar.indent = -1; BEGIN(BLOCK_SCALAR); return BPART; }
">"[1-9]*[-+]*[ \t]*(\n|[ \t]+#.*)      { yylval->string = strdup(yytext); CTX->expecting_value = 0; CTX->last_was_value = 0; CTX->block_scalar.indent = -1; BEGIN(BLOCK_SCALAR); return BPART; }

<BLOCK_SCALAR>^([ \t]|{VSPACE})*\n {
    yylval->string = strdup("\n");
    return BPART;
}

<BLOCK_SCALAR>^([ \t]|{VSPACE})+ {
    int indent = 0;
    int i = 0;
    while (i < yyleng) {
        unsigned char ch = (unsigned char)yytext[i];
        if (ch == ' ' || ch == '\t') {
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
    if (CTX->block_scalar.indent == -1) {
        CTX->block_scalar.indent = indent;
    }
    
    if (indent >= CTX->block_scalar.indent) {
        /* This is content line */
        char line_buf[4096];
        int line_len = 0;
        int c;
        int skip = CTX->block_scalar.indent;
        
        /* copy extra spaces if indent > block_indent */
        for (int i = 0; i < (indent - skip); i++) {
            if (line_len < 4095) line_buf[line_len++] = ' ';
        }
        
        while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0) {
            if (line_len < 4095) line_buf[line_len++] = c;
        }
        if (c == '\n') line_buf[line_len++] = '\n';
        line_buf[line_len] = '\0';
        
        yylval->string = strdup(line_buf);
        return BPART;
    } else {
        /* End of block scalar - line is less indented */
        yyless(0); 
        BEGIN(INITIAL);
        /* No token, grammar will reduce bscalar */
    }
}

<BLOCK_SCALAR>. {
    /* Non-indented line starts with a character - check indentation */
    yyless(0);
    BEGIN(INDENT_CHECK);
}

<BLOCK_SCALAR><<EOF>> {
    BEGIN(INITIAL);
}




[^ \t\n\r\[\]{}!,&*%@|>\`'"]([^ \n\r:]|[ ]|:[^ \t\n\r\xE2])*/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Plain map key: key: value (complex pattern allows colons inside key text) */
    if (CTX->flow_level > 0) {
        /* In flow context, parse key text incrementally; avoid swallowing commas/brackets. */
        yyless(1);
        if (yytext[0] == ':') {
            CTX->expecting_value = 1;
            return COLON;
        }
        yylval->string = strdup(yytext);
        CTX->expecting_value = 0;
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
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    return MAP_KEY;
}

[^ \t\n\r\[\]{}!,&*%@|>\`'"] {
    yylval->string = strdup(yytext);
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    BEGIN(PLAIN_SCALAR_CONT);
    return CH_RAW;
}

":"[a-zA-Z0-9\-\._]+ {
    if (CTX->flow_level > 0 && !CTX->expecting_value) {
        yyless(1);
        CTX->expecting_value = 1;
        return COLON;
    }
    yylval->string = strdup(yytext);
    CTX->expecting_value = 0;
    BEGIN(PLAIN_SCALAR_CONT);
    return CH_RAW;
}

<PLAIN_SCALAR_CONT>":"/[ \t\n\r] {
    /* Colon followed by space/tab/newline ends the scalar */
    yyless(0);
    BEGIN(INITIAL);
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

<PLAIN_SCALAR_CONT>\n[ ]*\n[ ]+[^:\n\r]*/\n {
    /* Blank line + indented continuation => preserve one logical newline. */
    const char *p = yytext + 1; /* skip first newline */
    while (*p == ' ') p++;
    if (*p == '\n') p++;
    while (*p == ' ') p++;
    size_t n = strlen(p);
    char *s = malloc(n + 2);
    s[0] = '\n';
    memcpy(s + 1, p, n + 1);
    yylval->string = s;
    return CH_RAW;
}

<PLAIN_SCALAR_CONT>\n[ ]+[^:\n\r]*/\n {
    /* Indented continuation line => fold to space. */
    const char *p = yytext + 1; /* skip newline */
    while (*p == ' ') p++;
    size_t n = strlen(p);
    char *s = malloc(n + 2);
    s[0] = ' ';
    memcpy(s + 1, p, n + 1);
    yylval->string = s;
    return CH_RAW;
}

<PLAIN_SCALAR_CONT>[ \t]+/#[^\n\r]* {
    /* Comment starts after whitespace; terminate scalar before comment. */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>[ \t]+ { yylval->string = strdup(yytext); return CH_RAW; }
<PLAIN_SCALAR_CONT>[^:\n\r\t,\[\]{} ]+ { yylval->string = strdup(yytext); return CH_RAW; }
<PLAIN_SCALAR_CONT>":" { yylval->string = strdup(":"); return CH_RAW; }

<PLAIN_SCALAR_CONT>"\n" {
    /* Terminator for plain scalar */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>[\{\}\[\],] {
    if (CTX->flow_level > 0) {
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
    if (CTX->indent_sp > 0) {
        CTX->indent_sp--;
        return DEDENT;
    }
    yyterminate();
}

%%
