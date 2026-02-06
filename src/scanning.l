%{
#include "parsing.tab.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* LexerContext type is defined in parsing.y's %code requires and included via parsing.tab.h */

#define YYSTYPE PARSING_YY_STYPE
#define YYLTYPE PARSING_YY_LTYPE

/* Forward declaration for error handling */
void parsing_yy_error(void *yylloc, void *scanner, const char *msg);

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
    
    ctx->block_scalar.type = '\0';
    ctx->block_scalar.indent = -1;
    
    ctx->scalar.len = 0;
    if (ctx->scalar.content) {
        ctx->scalar.content[0] = '\0';
    }
    
    ctx->indent_context_sp = 0;
    ctx->scalar_base_indent = 0;
    ctx->scalar_type = '\0';
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
static int ctx_current_indent(const LexerContext *ctx) {
    if (!ctx) return 0;
    return ctx->indent_stack[ctx->indent_sp];
}

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
static int ctx_in_flow_context(const LexerContext *ctx) {
    if (!ctx) return 0;
    return ctx->flow_level > 0 || 
           (ctx->indent_context_sp > 0 && 
            ctx->indent_context_stack[ctx->indent_context_sp - 1].is_flow);
}

/**
 * Initialize scalar accumulation buffer
 * Resets length to 0 but preserves allocated capacity
 */
static void ctx_scalar_init(LexerContext *ctx) {
    if (!ctx) return;
    ctx->scalar.len = 0;
    if (ctx->scalar.content) {
        ctx->scalar.content[0] = '\0';
    }
}

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
static void ctx_scalar_append(LexerContext *ctx, const char *text, int len) {
    if (!ctx || !text || len <= 0) return;
    
    ctx_try_grow_scalar(ctx, len);
    if (!ctx->scalar.content) return;
    
    memcpy(ctx->scalar.content + ctx->scalar.len, text, len);
    ctx->scalar.len += len;
    ctx->scalar.content[ctx->scalar.len] = '\0';
}

/**
 * Finalize scalar and return a copy of the accumulated text
 * Resets the buffer for next use
 */
static char *ctx_scalar_finalize(LexerContext *ctx) {
    if (!ctx || !ctx->scalar.content) return strdup("");
    
    char *result = strdup(ctx->scalar.content);
    ctx_scalar_init(ctx);
    return result;
}

/**
 * Start block scalar accumulation
 * Sets type ('|' or '>') and initializes buffer
 */
static void ctx_block_scalar_start(LexerContext *ctx, char type) {
    if (!ctx) return;
    ctx->block_scalar.type = type;
    ctx->block_scalar.indent = -1;
    ctx_scalar_init(ctx);
}

/**
 * Append a line to block scalar with newline
 */
static void ctx_block_scalar_append(LexerContext *ctx, const char *line, int len) {
    if (!ctx || !line) return;
    ctx_scalar_append(ctx, line, len);
    ctx_scalar_append(ctx, "\n", 1);
}

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

static int current_indent(LexerContext *ctx) {
    return ctx_current_indent(ctx);
}

static void push_indent_context(LexerContext *ctx, int level, int is_flow, char type) {
    ctx_push_indent_context(ctx, level, is_flow, type);
}

static void pop_indent_context(LexerContext *ctx) {
    ctx_pop_indent_context(ctx);
}

static int in_flow_context(LexerContext *ctx) {
    return ctx_in_flow_context(ctx);
}

/* Simple lookahead - just check if we're at end of file or line */
static int check_scalar_continuation() {
    /* For now, simple approach: plain scalars end at newline in block context */
    return 0;
}

static void init_scalar(LexerContext *ctx) {
    ctx_scalar_init(ctx);
}

static void append_scalar(LexerContext *ctx, const char *str, int len) {
    ctx_scalar_append(ctx, str, len);
}

static void init_block_scalar(LexerContext *ctx, char type) {
    ctx_block_scalar_start(ctx, type);
}

static void append_block_line(LexerContext *ctx, const char *line, int len) {
    ctx_block_scalar_append(ctx, line, len);
}


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
%x SIMPLE_SCALAR
%x INDENT_CHECK
%x PLAIN_SCALAR_CONT
%x QUOTED

NSCAL [a-zA-Z0-9\-\._%:/]

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

<INDENT_CHECK>[ \t]*#[^\n]* {
    /* Line with only whitespace and comment - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>[ \t]*\n {
    /* Blank line - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>[ \t]*\n {
    /* Blank line - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>[ \t]* {
    int indent = 0;
    for (int i=0; i<yyleng; i++) {
        if (yytext[i] == ' ') {
            indent++;
        } else if (yytext[i] == '\t') {
            fprintf(stderr, "syntax error, tabs used for indentation\n");
            exit(1);
        }
    }
    
    BEGIN(INITIAL);
    int cur = current_indent(CTX);
    if (indent > cur) {
        push_indent(CTX, indent);
        return INDENT;
    } else if (indent < cur) {
        while (indent < current_indent(CTX)) {
            pop_indent(CTX);
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
    int cur = current_indent(CTX);
    if (0 < cur) {
        while (0 < current_indent(CTX)) {
            pop_indent(CTX);
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
    int cur = current_indent(CTX);
    while (0 < current_indent(CTX)) {
        pop_indent(CTX);
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
    "!"{NSCAL}+"!"  { yylval->string = strdup(yytext); return TAG; }
    "!!"{NSCAL}+    { yylval->string = strdup(yytext); return TAG; }
    "!"{NSCAL}+     { yylval->string = strdup(yytext); return TAG; }
    [^ \t\n]+       { yylval->string = strdup(yytext); return SCALAR; }
}
"-"/[ \t\n]      { CTX->expecting_value = 1; return BULLET; }
":"/[ \t\n]      { CTX->expecting_value = 1; return COLON; }
"?"/[ \t\n]      { CTX->expecting_value = 1; return QUESTION; }
"!"              { yylval->string = strdup("!"); return TAG; }
"!!"{NSCAL}+     { yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+"!"{NSCAL}* { yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+      { yylval->string = strdup(yytext); return TAG; }
"&"{NSCAL}+      { yylval->string = strdup(yytext); return ANCHOR; }
"*"{NSCAL}+      { yylval->string = strdup(yytext); CTX->expecting_value = 0; return ALIAS; }
"["              { CTX->flow_level++; CTX->expecting_value = 1; return LBRACK; }
"]"              { if (CTX->flow_level > 0) CTX->flow_level--; CTX->expecting_value = 0; return RBRACK; }
"{"              { CTX->flow_level++; CTX->expecting_value = 1; return LBRACE; }
"}"              { if (CTX->flow_level > 0) CTX->flow_level--; CTX->expecting_value = 0; return RBRACE; }
":"              { 
    if (CTX->expecting_value && CTX->flow_level > 0) {
         /* Colon starting a value in flow context = Scalar */
         init_scalar(CTX);
         append_scalar(CTX, ":", 1);
         CTX->expecting_value = 0;
         BEGIN(SIMPLE_SCALAR);
    } else if (CTX->expecting_value && CTX->flow_level == 0) {
         /* In block context, when expecting value, : not followed by space = scalar */
         init_scalar(CTX);
         append_scalar(CTX, ":", 1);
         BEGIN(SIMPLE_SCALAR);
    } else if (CTX->flow_level > 0) {
         CTX->expecting_value = 1;
         return COLON; 
    } else {
         return ':'; 
    }
}
","              { CTX->expecting_value = 1; return COMMA; }
\" {
    BEGIN(QUOTED);
    init_scalar(CTX);
}

<QUOTED>{
    \"/[ ]*":"[ \t\n] {
        BEGIN(INITIAL);
        yylval->string = strdup(CTX->scalar.content);
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        return QMAP_KEY;
    }

    \" {
        BEGIN(INITIAL);
        yylval->string = strdup(CTX->scalar.content);
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        return QSCALAR;
    }
    
    \\n { append_scalar(CTX, "\n", 1); }
    \\t { append_scalar(CTX, "\t", 1); }
    \\r { append_scalar(CTX, "\r", 1); }
    \\\\ { append_scalar(CTX, "\\", 1); }
    \\\" { append_scalar(CTX, "\"", 1); }
    \\\/ { append_scalar(CTX, "/", 1); }
    \\0 { append_scalar(CTX, "\0", 1); }
    
    \\[^ntr\\\"\/0] {
        parsing_yy_error(NULL, yyscanner, "syntax error, invalid escape sequence");
        /* Return something that triggers an error in parser */
        return SCALAR; 
    }
    
    [^\\\"\n]+ { append_scalar(CTX, yytext, yyleng); }
    \n { append_scalar(CTX, "\n", 1); }
    
    <<EOF>> {
        parsing_yy_error(NULL, yyscanner, "syntax error, unterminated quoted string");
        BEGIN(INITIAL);
        return SCALAR;
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
"|"[1-9]*[-+]*[ \t]*(\n|[ \t]+#.*)      { init_block_scalar(CTX, '|'); CTX->expecting_value = 0; CTX->last_was_value = 0; BEGIN(BLOCK_SCALAR); }
">"[1-9]*[-+]*[ \t]*(\n|[ \t]+#.*)      { init_block_scalar(CTX, '>'); CTX->expecting_value = 0; CTX->last_was_value = 0; BEGIN(BLOCK_SCALAR); }

<BLOCK_SCALAR>^[ \t]*\n {
    /* Empty line - keep it */
    append_block_line(CTX, "", 0);
}

<BLOCK_SCALAR>^[ \t]+ {
    int indent = yyleng;
    if (CTX->block_scalar.indent == -1) {
        CTX->block_scalar.indent = indent;
    }
    
    if (indent >= CTX->block_scalar.indent) {
        /* This is content */
        /* Read the rest of the line */
        int c;
        int line_len = 0;
        char line_buf[1024];
        /* Skip the indent */
        int skip = CTX->block_scalar.indent;
        /* We already matched 'yyleng' spaces. 
           We need to skip 'block_indent' spaces.
        */
        int consumed = yyleng;
        int i = 0;
        /* copy extra spaces if indent > block_indent */
        for (i = 0; i < (consumed - skip); i++) {
            line_buf[line_len++] = ' ';
        }
        
        while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0) {
            line_buf[line_len++] = c;
        }
        append_block_line(CTX, line_buf, line_len);
    } else {
        /* End of block scalar - line is less indented */
        /* We need to return this line to the lexer */
        yyless(0); 
        char *final = malloc(CTX->scalar.len + 2);
        final[0] = CTX->block_scalar.type;
        memcpy(final + 1, CTX->scalar.content, CTX->scalar.len);
        final[CTX->scalar.len+1] = '\0';
        yylval->string = final;
        BEGIN(INITIAL);
        return BSCALAR;
    }
}

<BLOCK_SCALAR>. {
    /* Non-indented line starts with a character */
    yyless(0);
    char *final = malloc(CTX->scalar.len + 2);
    final[0] = CTX->block_scalar.type;
    memcpy(final + 1, CTX->scalar.content, CTX->scalar.len);
    final[CTX->scalar.len+1] = '\0';
    yylval->string = final;
    BEGIN(INITIAL);
    return BSCALAR;
}

<BLOCK_SCALAR><<EOF>> {
    char *final = malloc(CTX->scalar.len + 2);
    final[0] = CTX->block_scalar.type;
    memcpy(final + 1, CTX->scalar.content, CTX->scalar.len);
    final[CTX->scalar.len+1] = '\0';
    yylval->string = final;
    BEGIN(INITIAL);
    return BSCALAR;
}




[^ \t\n\r\[\]{}!,&*%@|>\`'"]([^ \n\r:]|[ ]|:[^ \t\n\r])*/[ ]*":"[ \t\n] {
    yylval->string = strdup(yytext);
    /* Trim trailing spaces from key */
    char *end = yylval->string + strlen(yylval->string) - 1;
    while (end > yylval->string && *end == ' ') *end-- = '\0';
    CTX->expecting_value = 0;
    return MAP_KEY;
}

[^ \t\n\r\[\]{}!,&*%@|>\`'"] {
    /* Start simple scalar */
    init_scalar(CTX);
    append_scalar(CTX, yytext, yyleng);
    CTX->expecting_value = 0;
    CTX->scalar_base_indent = current_indent(CTX);
    CTX->scalar_type = ':';  /* Plain scalar */
    BEGIN(PLAIN_SCALAR_CONT);
}

":"[a-zA-Z0-9\-\._]+ {
    /* Colon followed by alphanumeric - treat as scalar */
    init_scalar(CTX);
    append_scalar(CTX, yytext, yyleng);
    CTX->expecting_value = 0;
    CTX->scalar_base_indent = current_indent(CTX);
    CTX->scalar_type = ':';
    BEGIN(PLAIN_SCALAR_CONT);
}

<SIMPLE_SCALAR>":"/[ \t\n\r] {
    char *s = strdup(CTX->scalar.content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    yyless(0);
    BEGIN(INITIAL);
    return SCALAR;
}

<SIMPLE_SCALAR>[ \t]*\n([ \t]*\n)+ {
    /* Multiple blank lines in scalar - continue parsing as multiline */
    append_scalar(CTX, " ", 1);
}
<SIMPLE_SCALAR>"\n" {
    char *s = strdup(CTX->scalar.content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    unput('\n');
    BEGIN(INITIAL);
    return SCALAR;
}
<SIMPLE_SCALAR>[ \t]+ { append_scalar(CTX, yytext, yyleng); }
<SIMPLE_SCALAR>[^:\n\r\t,\[\]{} ]+ { append_scalar(CTX, yytext, yyleng); }
<SIMPLE_SCALAR>":" { append_scalar(CTX, ":", 1); }
<SIMPLE_SCALAR>[\{\}\[\],] {
    if (CTX->flow_level > 0) {
        yyless(0);
        char *s = strdup(CTX->scalar.content);
        int len = strlen(s);
        while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
        yylval->string = s;
        BEGIN(INITIAL);
        return SCALAR;
    }
    append_scalar(CTX, yytext, yyleng);
}
<SIMPLE_SCALAR><<EOF>> {
    char *s = strdup(CTX->scalar.content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    BEGIN(INITIAL);
    return SCALAR;
}

<PLAIN_SCALAR_CONT>":"/[ \t\n\r] {
    /* Colon followed by space/tab/newline ends the scalar */
    char *s = strdup(CTX->scalar.content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    yyless(0);
    BEGIN(INITIAL);
    return SCALAR;
}

<PLAIN_SCALAR_CONT>[ \t]+ { append_scalar(CTX, yytext, yyleng); }
<PLAIN_SCALAR_CONT>[^:\n\r\t,\[\]{} ]+ { append_scalar(CTX, yytext, yyleng); }
<PLAIN_SCALAR_CONT>":" { append_scalar(CTX, ":", 1); }

<PLAIN_SCALAR_CONT>"\n" {
    /* For plain scalars, newline ends the scalar in block context */
    /* In flow context, we might continue */
    if (CTX->flow_level == 0) {
        /* Block context - end scalar */
        char *s = strdup(CTX->scalar.content);
        int len = strlen(s);
        while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
        yylval->string = s;
        unput('\n');
        BEGIN(INITIAL);
        return SCALAR;
    } else {
        /* Flow context - fold to space and continue */
        append_scalar(CTX, " ", 1);
    }
}

<PLAIN_SCALAR_CONT>[\{\}\[\],] {
    if (CTX->flow_level > 0) {
        yyless(0);
        char *s = strdup(CTX->scalar.content);
        int len = strlen(s);
        while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
        yylval->string = s;
        BEGIN(INITIAL);
        return SCALAR;
    }
    append_scalar(CTX, yytext, yyleng);
}

<PLAIN_SCALAR_CONT><<EOF>> {
    char *s = strdup(CTX->scalar.content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    BEGIN(INITIAL);
    return SCALAR;
}

<PLAIN_SCALAR_CONT>. {
    /* Unmatched character in plain scalar - end the scalar */
    char *s = strdup(CTX->scalar.content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    yyless(0);
    BEGIN(INITIAL);
    return SCALAR;
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
.                { return yytext[0]; }

<<EOF>> {
    if (CTX->indent_sp > 0) {
        CTX->indent_sp--;
        return DEDENT;
    }
    yyterminate();
}

%%
