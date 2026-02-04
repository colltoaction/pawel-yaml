%{
#include "parser.tab.h"
#include <string.h>
#include <stdlib.h>

static int indent_stack[100] = {0};
static int indent_sp = 0;
static int flow_level = 0;
static int expecting_value = 0;
static int pending_dedents = 0;
static int first_line = 1;

/* Check if UTF-8 bytes represent visible space U+2423 */
static int is_visible_space(const unsigned char *s) {
    return s[0] == 0xE2 && s[1] == 0x90 && s[2] == 0xA3;
}


static void push_indent(int col) {
    if (indent_sp < 99) indent_stack[++indent_sp] = col;
}

static int pop_indent() {
    return (indent_sp > 0) ? indent_stack[indent_sp--] : 0;
}

static int current_indent() {
    return indent_stack[indent_sp];
}

static char block_type = '\0';
static int block_indent = -1;
static char *scalar_content = NULL;
static int scalar_content_len = 0;
static int scalar_content_cap = 0;

static void init_scalar() {
    if (scalar_content) free(scalar_content);
    scalar_content = malloc(1024);
    scalar_content_len = 0;
    scalar_content_cap = 1024;
    scalar_content[0] = '\0';
}

static void append_scalar(const char *str, int len) {
    if (scalar_content_len + len + 2 >= scalar_content_cap) {
        scalar_content_cap *= 2;
        scalar_content = realloc(scalar_content, scalar_content_cap);
    }
    memcpy(scalar_content + scalar_content_len, str, len);
    scalar_content_len += len;
    scalar_content[scalar_content_len] = '\0';
}

static void init_block_scalar(char type) {
    block_type = type;
    block_indent = -1;
    init_scalar(); /* Reuse scalar buffer */
}

static void append_block_line(const char *line, int len) {
    append_scalar(line, len);
    append_scalar("\n", 1);
}

static void enter_flow_context(void) {
    flow_level++;
    expecting_value = 1;
}

static void exit_flow_context(void) {
    if (flow_level > 0) flow_level--;
    expecting_value = 0;
}

static char *finalize_block_scalar_value(void) {
    char *final = malloc(scalar_content_len + 2);
    final[0] = block_type;
    memcpy(final + 1, scalar_content, scalar_content_len);
    final[scalar_content_len + 1] = '\0';
    return final;
}
%}

%option noyywrap
%option reentrant
%option bison-bridge

%x BLOCK_SCALAR
%x BLOCK_CONTENT
%x DIRECTIVE_MODE
%x SIMPLE_SCALAR
%x INDENT_CHECK

NSCAL [a-zA-Z0-9\-\._%:/]

%%

    if (first_line) {
        first_line = 0;
        BEGIN(INDENT_CHECK);
    }

    /* Handle pending dedents first */
    if (pending_dedents > 0) {
        pending_dedents--;
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
        if (yytext[i] == ' ') indent++;
        else if (yytext[i] == '\t') indent = (indent + 8) & ~7;
    }
    
    BEGIN(INITIAL);
    int cur = current_indent();
    if (indent > cur) {
        push_indent(indent);
        return INDENT;
    } else if (indent < cur) {
        while (indent < current_indent()) {
            pop_indent();
            pending_dedents++;
        }
        if (pending_dedents > 0) {
            pending_dedents--;
            return DEDENT;
        }
    }
}

<INDENT_CHECK>. {
    /* Not an indent - likely at column 0 */
    yyless(0);
    BEGIN(INITIAL);
    int cur = current_indent();
    if (0 < cur) {
        while (0 < current_indent()) {
            pop_indent();
            pending_dedents++;
        }
        if (pending_dedents > 0) {
            pending_dedents--;
            return DEDENT;
        }
    }
}

<INDENT_CHECK><<EOF>> {
    BEGIN(INITIAL);
    int cur = current_indent();
    while (0 < current_indent()) {
        pop_indent();
        pending_dedents++;
    }
    if (pending_dedents > 0) {
        pending_dedents--;
        return DEDENT;
    }
    yyterminate();
}

\n {
    BEGIN(INDENT_CHECK);
}



"%TAG"           { BEGIN(DIRECTIVE_MODE); return TAG_DIRECTIVE; }
"%YAML"[ ]?"1"[.,][0-9]  { return YAML_DIRECTIVE; }
"%"[a-zA-Z][^\n]* { /* Unknown directive - skip */ }
"---"            { expecting_value = 1; last_was_value = 0; return DOC_START; }
"..."            { expecting_value = 1; return DOC_END; }

<DIRECTIVE_MODE>{
    [ \t]+          { /* skip space */ }
    \n              { BEGIN(INITIAL); }
    "!"{NSCAL}+"!"  { yylval->string = strdup(yytext); return TAG; }
    "!!"{NSCAL}+    { yylval->string = strdup(yytext); return TAG; }
    "!"{NSCAL}+     { yylval->string = strdup(yytext); return TAG; }
    [^ \t\n]+       { yylval->string = strdup(yytext); return SCALAR; }
}
"-"/[ \t\n]      { expecting_value = 1; return BULLET; }
":"/[ \t\n]      { expecting_value = 1; return COLON; }
"?"/[ \t\n]      { expecting_value = 1; return QUESTION; }
"!"              { yylval->string = strdup("!"); return TAG; }
"!!"{NSCAL}+     { yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+"!"{NSCAL}* { yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+      { yylval->string = strdup(yytext); return TAG; }
"&"{NSCAL}+      { yylval->string = strdup(yytext); return ANCHOR; }
"*"{NSCAL}+      { yylval->string = strdup(yytext); expecting_value = 0; return ALIAS; }
"["              { enter_flow_context(); return LBRACK; }
"]"              { exit_flow_context(); return RBRACK; }
"{"              { enter_flow_context(); return LBRACE; }
"}"              { exit_flow_context(); return RBRACE; }
":"              { 
    if (expecting_value && flow_level > 0) {
         /* Colon starting a value in flow context = Scalar */
         init_scalar();
         append_scalar(":", 1);
         expecting_value = 0;
         BEGIN(SIMPLE_SCALAR);
    } else if (expecting_value && flow_level == 0) {
         /* In block context, when expecting value, : not followed by space = scalar */
         init_scalar();
         append_scalar(":", 1);
         BEGIN(SIMPLE_SCALAR);
    } else if (flow_level > 0) {
         expecting_value = 1;
         return COLON; 
    } else {
         return ':'; 
    }
}
","              { expecting_value = 1; return COMMA; }
\"[^\"]*\"       { yylval->string = strndup(yytext+1, strlen(yytext)-2); expecting_value = 0; return QSCALAR; }
\'[^\']*\'       { yylval->string = strndup(yytext+1, strlen(yytext)-2); expecting_value = 0; return SSCALAR; }
"|"[1-9]*[-+]*[ \t]*(\n|#.*)      { init_block_scalar('|'); expecting_value = 0; BEGIN(BLOCK_SCALAR); }
">"[1-9]*[-+]*[ \t]*(\n|#.*)      { init_block_scalar('>'); expecting_value = 0; BEGIN(BLOCK_SCALAR); }

<BLOCK_SCALAR>^[ \t]*\n {
    /* Empty line - keep it */
    append_block_line("", 0);
}

<BLOCK_SCALAR>^[ \t]+ {
    int indent = yyleng;
    if (block_indent == -1) {
        block_indent = indent;
    }
    
    if (indent >= block_indent) {
        /* This is content */
        /* Read the rest of the line */
        int c;
        int line_len = 0;
        char line_buf[1024];
        /* Skip the indent */
        int skip = block_indent;
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
        append_block_line(line_buf, line_len);
    } else {
        /* End of block scalar - line is less indented */
        /* We need to return this line to the lexer */
        yyless(0);
        yylval->string = finalize_block_scalar_value();
        BEGIN(INITIAL);
        return BSCALAR;
    }
}

<BLOCK_SCALAR>. {
    /* Non-indented line starts with a character */
    yyless(0);
    yylval->string = finalize_block_scalar_value();
    BEGIN(INITIAL);
    return BSCALAR;
}

<BLOCK_SCALAR><<EOF>> {
    yylval->string = finalize_block_scalar_value();
    BEGIN(INITIAL);
    return BSCALAR;
}




[a-zA-Z0-9\-\._]+ {
    /* Start simple scalar */
    init_scalar();
    append_scalar(yytext, yyleng);
    expecting_value = 0;
    BEGIN(SIMPLE_SCALAR);
}

<SIMPLE_SCALAR>":"/[ \t\n\r] {
    char *s = strdup(scalar_content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    yyless(0);
    BEGIN(INITIAL);
    return SCALAR;
}

<SIMPLE_SCALAR>"\n" {
    char *s = strdup(scalar_content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    unput('\n');
    BEGIN(INITIAL);
    return SCALAR;
}

<SIMPLE_SCALAR>[ \t]+ { append_scalar(yytext, yyleng); }
<SIMPLE_SCALAR>[^:\n\r\t,\[\]{} ]+ { append_scalar(yytext, yyleng); }
<SIMPLE_SCALAR>":" { append_scalar(":", 1); }
<SIMPLE_SCALAR>[\{\}\[\],] {
    if (flow_level > 0) {
        yyless(0);
        char *s = strdup(scalar_content);
        int len = strlen(s);
        while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
        yylval->string = s;
        BEGIN(INITIAL);
        return SCALAR;
    }
    append_scalar(yytext, yyleng);
}
<SIMPLE_SCALAR><<EOF>> {
    char *s = strdup(scalar_content);
    int len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';
    yylval->string = s;
    BEGIN(INITIAL);
    return SCALAR;
}
"#".*            { /* ignore comments */ }
[ \t\r]+       { /* skip whitespace */ }
.                { return yytext[0]; }

<<EOF>> {
    if (indent_sp > 0) {
        indent_sp--;
        return DEDENT;
    }
    yyterminate();
}

%%
