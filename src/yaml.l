%{
#include "yaml.tab.h"
#include "lexer_context.h"
#include <string.h>
#include <stdlib.h>

#define YYSTYPE YAML_STYPE
#define YYLTYPE YAML_LTYPE

/* Forward declaration for error handling */
void yaml_error(void *yylloc, void *scanner, const char *msg);

/* Lexer context - replaces all global variables */
#define CTX yyextra

/* Check if UTF-8 bytes represent visible space U+2423 */
static int is_visible_space(const unsigned char *s) {
    return s[0] == 0xE2 && s[1] == 0x90 && s[2] == 0xA3;
}

/* Validate that a comment has proper spacing before it
 * Comments require whitespace (space/tab) before them (or start of line)
 * This prevents invalid YAML like: "value"# comment or ># comment
 */
static int validate_comment_context(LexerContext *ctx) {
    if (ctx->last_was_value) {
        fprintf(stderr, "syntax error, comment without preceding whitespace\n");
        return 0;
    }
    return 1;
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

/* Validate escape sequences in double-quoted strings. 
   Valid YAML escapes: \\ \" \/ \n \t \r \0 \a \b \f \v \e \N{...} \uXXXX \UXXXXXXXX \xXX
   Returns 1 if valid, 0 if invalid (error message printed to stderr) */
static int validate_dquote_escapes(const char *str, int len) {
    for (int i = 0; i < len; i++) {
        if (str[i] == '\\' && i + 1 < len) {
            char next = str[i+1];
            /* Check if escape sequence is valid */
            if (next != '\\' && next != '"' && next != '/' && next != 'n' && next != 't' && 
                next != 'r' && next != '0' && next != 'a' && next != 'b' && 
                next != 'f' && next != 'v' && next != 'e' &&
                next != 'N' && next != 'u' && next != 'U' && next != 'x') {
                fprintf(stderr, "syntax error, invalid escape sequence\n");
                return 0;
            }
            /* Skip the escape sequence (backslash + next char) */
            i += 1;
        }
    }
    return 1;
}
%}

%option noyywrap
%option reentrant
%option bison-bridge
%option bison-locations
%option prefix="yaml_"
%option extra-type="LexerContext *"

%x BLOCK_SCALAR
%x BLOCK_CONTENT
%x DIRECTIVE_MODE
%x SIMPLE_SCALAR
%x INDENT_CHECK
%x PLAIN_SCALAR_CONT
%x QUOTED_SCALAR_CONT
%x BLOCK_LITERAL_CONT
%x BLOCK_FOLDED_CONT

NSCAL [a-zA-Z0-9\-\._%:/]

%%

    fprintf(stderr, "lex called\n"); fflush(stderr);

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
        /* return INDENT; */
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
\"([^\"\\]|\\.|[\n])*\" {
    /* Double-quoted string - supports multiline and validates escape sequences */
    int len = strlen(yytext) - 2;
    char *content = strndup(yytext + 1, len);
    if (!validate_dquote_escapes(content, len)) {
        /* Invalid escape detected - error already printed by validate_dquote_escapes */
        free(content);
        /* In Bison GLR parser, we must exit cleanly to signal parse failure */
        exit(1);
    }
    yylval->string = content;
    CTX->expecting_value = 0;
    CTX->last_was_value = 1;  /* Mark that we just parsed a value */
    return QSCALAR;
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




[a-zA-Z0-9\-\._]+ {
    /* Start simple scalar */
    init_scalar(CTX);
    append_scalar(CTX, yytext, yyleng);
    CTX->expecting_value = 0;
    CTX->scalar_base_indent = current_indent(CTX);
    CTX->scalar_type = ':';  /* Plain scalar */
    BEGIN(PLAIN_SCALAR_CONT);
}

"?"[a-zA-Z0-9\-\._]+ {
    /* Question mark followed by alphanumeric - treat as scalar */
    init_scalar(CTX);
    append_scalar(CTX, yytext, yyleng);
    CTX->expecting_value = 0;
    CTX->scalar_base_indent = current_indent(CTX);
    CTX->scalar_type = ':';
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

"#".*            { 
    /* Validate comment has proper spacing */
    if (!validate_comment_context(CTX)) {
        exit(1);
    }
    /* Valid comment - ignore it */ 
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
