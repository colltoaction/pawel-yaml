%{
#include "parser.tab.h"
#include <string.h>
#include <stdlib.h>

static int indent_stack[100] = {0};
static int indent_level = 0;

static void push_indent(int col) {
    if (indent_level < 99) indent_stack[++indent_level] = col;
}

static int pop_indent() {
    return (indent_level > 0) ? indent_stack[indent_level--] : 0;
}

static int current_indent() {
    return indent_stack[indent_level];
}

static char block_type = '\0';
static int block_indent = -1;
static char *block_content = NULL;
static int block_content_len = 0;
static int block_content_cap = 0;

static void init_block_scalar(char type) {
    block_type = type;
    block_indent = -1;
    if (block_content) free(block_content);
    block_content = malloc(1024);
    block_content_len = 0;
    block_content_cap = 1024;
    block_content[0] = '\0';
}

static void append_block_line(const char *line, int len) {
    if (block_content_len + len + 2 >= block_content_cap) {
        block_content_cap *= 2;
        block_content = realloc(block_content, block_content_cap);
    }
    memcpy(block_content + block_content_len, line, len);
    block_content_len += len;
    block_content[block_content_len++] = '\n';
    block_content[block_content_len] = '\0';
}
%}

%option noyywrap
%option reentrant
%option bison-bridge

%x BLOCK_SCALAR
%x BLOCK_CONTENT

NSCAL [a-zA-Z0-9]

%%

"%YAML 1.2"      { return YAML_DIRECTIVE; }
"---"            { return DOC_START; }
"-"/[ \t\n]      { return BULLET; }
":"/[ \t\n]      { return COLON; }
"?"/[ \t\n]      { return QUESTION; }
"!!"{NSCAL}+     { yylval->string = strdup(yytext); return TAG; }
"!"{NSCAL}+      { yylval->string = strdup(yytext); return TAG; }
"&"{NSCAL}+      { yylval->string = strdup(yytext); return ANCHOR; }
"*"{NSCAL}+      { yylval->string = strdup(yytext); return ALIAS; }
"["              { return LBRACK; }
"]"              { return RBRACK; }
"{"              { return LBRACE; }
"}"              { return RBRACE; }
","              { return COMMA; }
\"[^\"]*\"       { yylval->string = strndup(yytext+1, strlen(yytext)-2); return QSCALAR; }
\'[^\']*\'       { yylval->string = strndup(yytext+1, strlen(yytext)-2); return SSCALAR; }
"|"[0-9]*[-+]*[ \t]*(\n|#.*)      { init_block_scalar('|'); BEGIN(BLOCK_SCALAR); }
">"[0-9]*[-+]*[ \t]*(\n|#.*)      { init_block_scalar('>'); BEGIN(BLOCK_SCALAR); }

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
        char *final = malloc(block_content_len + 2);
        final[0] = block_type;
        memcpy(final + 1, block_content, block_content_len);
        final[block_content_len+1] = '\0';
        yylval->string = final;
        BEGIN(INITIAL);
        return BSCALAR;
    }
}

<BLOCK_SCALAR>. {
    /* Non-indented line starts with a character */
    yyless(0);
    char *final = malloc(block_content_len + 2);
    final[0] = block_type;
    memcpy(final + 1, block_content, block_content_len);
    final[block_content_len+1] = '\0';
    yylval->string = final;
    BEGIN(INITIAL);
    return BSCALAR;
}

<BLOCK_SCALAR><<EOF>> {
    char *final = malloc(block_content_len + 2);
    final[0] = block_type;
    memcpy(final + 1, block_content, block_content_len);
    final[block_content_len+1] = '\0';
    yylval->string = final;
    BEGIN(INITIAL);
    return BSCALAR;
}

"#".*            { /* ignore comments */ }
[a-zA-Z0-9][a-zA-Z0-9 ]* {
    /* Trim trailing spaces from plain scalar */
    char *end = yytext + yyleng - 1;
    while (end > yytext && (*end == ' ' || *end == '\t')) *end-- = '\0';
    yylval->string = strdup(yytext);
    return SCALAR;
}
[ \t\n\r]+       { /* skip whitespace */ }
.                { /* ignore other characters for now */ }

%%
