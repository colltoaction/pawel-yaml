%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "mrl.h"
#include "yaml_parser.h"
#include "parser.tab.h"
#include "lexer_context.h"

#define CTX ((LexerContext*)yyextra)

/* Prototype helper functions */
/* 
 * Structural Handling Authority:
 * The Lexer is solely responsible for managing indentation state and emitting
 * INDENT/DEDENT tokens. The parser (yaml.y) consumes these tokens but does
 * not manipulate indentation state directly.
 */
static void push_indent(void* yyscanner, int column);
static int pop_indent(void* yyscanner);
static int current_indent(void* yyscanner);

static char* prefix_dup(char prefix, const char* s, int len) {
    char* buf = malloc(len + 2);
    if (!buf) return NULL;
    buf[0] = prefix;
    memcpy(buf + 1, s, len);
    buf[len + 1] = '\0';
    return buf;
}

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option never-interactive
%option extra-type="LexerContext*"

%x BLOCK_CONTENT
%x FLOW_CONTENT
%x BLOCK_SCALAR_START
%x BLOCK_SCALAR_LINE

%%

    if (CTX->indent_level == 0 && CTX->indent_stack[0] == 0) CTX->indent_stack[0] = 0;
    if (CTX->pending_dedents > 0) {
        CTX->pending_dedents--;
        return DEDENT;
    }

<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"---"/[ \t\n\r]   { BEGIN(BLOCK_CONTENT); return DOC_START; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"---"             { BEGIN(BLOCK_CONTENT); return DOC_START; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"..."/[ \t\n\r]   { BEGIN(INITIAL); return DOC_END; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"..."             { BEGIN(INITIAL); return DOC_END; }

<INITIAL>^"%"[^\n]*\n               { ; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^[ \t]*(\n|\r\n)   { ; }

<INITIAL>^[ \t]+                    {
    int column = yyleng;
    if (column > current_indent(yyscanner)) {
        push_indent(yyscanner, column);
        if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
        return INDENT;
    } else if (column < current_indent(yyscanner)) {
        while (column < current_indent(yyscanner)) {
            pop_indent(yyscanner);
            CTX->pending_dedents++;
        }
        if (CTX->pending_dedents > 0) {
            CTX->pending_dedents--;
            if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
            return DEDENT;
        }
    }
    if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
}
<INITIAL>^[^ \t\n\r%]               {
    yyless(0);
    int column = 0;
    if (column < current_indent(yyscanner)) {
        while (column < current_indent(yyscanner)) {
            pop_indent(yyscanner);
            CTX->pending_dedents++;
        }
        if (CTX->pending_dedents > 0) {
            CTX->pending_dedents--;
            if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
            return DEDENT;
        }
    }
    if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
}

<BLOCK_CONTENT,FLOW_CONTENT>#.*                        { ; }
<BLOCK_CONTENT>"- "/[ \t\n\r]             { return BLOCK_SEQ_START; }
<BLOCK_CONTENT>"- "                       { return BLOCK_SEQ_START; }
<BLOCK_CONTENT>"-"/(\n|\r\n|$)            { return BLOCK_SEQ_START; }
<BLOCK_CONTENT>"?"/[ \t\n\r]              { return BLOCK_KEY; }
<BLOCK_CONTENT,FLOW_CONTENT>":"                      { return COLON; }
<BLOCK_CONTENT,FLOW_CONTENT>"["           { 
    CTX->flow_level++; 
    BEGIN(FLOW_CONTENT);
    return FLOW_SEQ_START; 
}
<BLOCK_CONTENT,FLOW_CONTENT>"]"           { 
    if (CTX->flow_level > 0) CTX->flow_level--; 
    if (CTX->flow_level == 0) BEGIN(BLOCK_CONTENT);
    return FLOW_SEQ_END; 
}
<BLOCK_CONTENT,FLOW_CONTENT>"{"           { 
    CTX->flow_level++; 
    BEGIN(FLOW_CONTENT);
    return FLOW_MAP_START; 
}
<BLOCK_CONTENT,FLOW_CONTENT>"}"           { 
    if (CTX->flow_level > 0) CTX->flow_level--; 
    if (CTX->flow_level == 0) BEGIN(BLOCK_CONTENT);
    return FLOW_MAP_END; 
}
<BLOCK_CONTENT,FLOW_CONTENT>","                        { return COMMA; }
<BLOCK_CONTENT,FLOW_CONTENT>\n                         { BEGIN(INITIAL); }
<BLOCK_CONTENT,FLOW_CONTENT>([ \t]|\xe2\x80\xa3|\xe2\x90\xa3)+                     { ; }


<BLOCK_CONTENT,FLOW_CONTENT>!([!a-zA-Z0-9_.\-\/]*|"<"[^>]+">") {
    yylval->sval = strdup(yytext);
    return TAG;
}

<BLOCK_CONTENT>(([?:-]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}])+)|([a-zA-Z0-9_\/\\\$\(\)\+\=\<\^\~\;\.]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}])*))([ \t]+[\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}])*)* {
    yylval->sval = prefix_dup(':', yytext, yyleng);
    return SCALAR;
}

<FLOW_CONTENT>(([?:-]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;])+)|([a-zA-Z0-9_\/\\\$\(\)\+\=\<\^\~\;\.]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;])*))([ \t]+[\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;])*)* {
    yylval->sval = prefix_dup(':', yytext, yyleng);
    return SCALAR;
}


<BLOCK_CONTENT,FLOW_CONTENT>\"([^"\\]|\\.)*\" {
    yylval->sval = prefix_dup('"', yytext + 1, yyleng - 2);
    return SCALAR;
}

<BLOCK_CONTENT,FLOW_CONTENT>'([^']|'')*' {
    yylval->sval = prefix_dup('\'', yytext + 1, yyleng - 2);
    return SCALAR;
}

<BLOCK_CONTENT>[|>][\-+]?                 {
    CTX->block_type = yytext[0];
    CTX->block_indent = -1;
    CTX->block_content = malloc(1024);
    if (!CTX->block_content) { return 0; } // out of mem
    CTX->block_content[0] = '\0';
    CTX->block_content_len = 0;
    CTX->block_content_cap = 1024;
    BEGIN(BLOCK_SCALAR_START);
}

<BLOCK_SCALAR_START>\n[ \t]* {
    int indent = yyleng - 1;
    if (indent <= current_indent(yyscanner)) {
        // End of block
        yyless(0); 
        yylval->sval = prefix_dup(CTX->block_type, CTX->block_content, CTX->block_content_len);
        free(CTX->block_content);
        CTX->block_content = NULL;
        BEGIN(INITIAL);
        return SCALAR;
    }
    CTX->block_indent = indent;
    BEGIN(BLOCK_SCALAR_LINE);
    yyless(1); // Keep the newline for now or handle it
}

<BLOCK_SCALAR_LINE>.* {
    // Strip block_indent spaces if possible
    int strip = CTX->block_indent;
    int len = yyleng;
    char *ptr = yytext;
    while (strip > 0 && len > 0 && (*ptr == ' ' || *ptr == '\t')) {
        ptr++;
        len--;
        strip--;
    }
    
    if (CTX->block_content_len + len + 2 > CTX->block_content_cap) {
        CTX->block_content_cap *= 2;
        CTX->block_content = realloc(CTX->block_content, CTX->block_content_cap);
    }
    memcpy(CTX->block_content + CTX->block_content_len, ptr, len);
    CTX->block_content_len += len;
    CTX->block_content[CTX->block_content_len++] = '\n';
    CTX->block_content[CTX->block_content_len] = '\0';
    BEGIN(BLOCK_SCALAR_START);
}


<BLOCK_CONTENT,FLOW_CONTENT>\&[a-zA-Z0-9_.\-]+ {
    yylval->sval = strdup(yytext);
    return ANCHOR;
}

<BLOCK_CONTENT,FLOW_CONTENT>\*[a-zA-Z0-9_.\-]+ {
    yylval->sval = strdup(yytext);
    return ALIAS;
}

<BLOCK_CONTENT,FLOW_CONTENT>.                           { 
    fprintf(stderr, "Unexpected char in CONTENT: '%c' (0x%02x)\n", yytext[0], (unsigned char)yytext[0]); 
}

<*><<EOF>> {
    if (CTX->indent_level > 0) {
        CTX->indent_level--;
        return DEDENT;
    }
    yyterminate();
}
%%

static void push_indent(void* yyscanner, int column) {
    LexerContext* ctx = (LexerContext*)yyget_extra(yyscanner);
    if (ctx->indent_level < 99) ctx->indent_stack[++ctx->indent_level] = column;
}

static int pop_indent(void* yyscanner) {
    LexerContext* ctx = (LexerContext*)yyget_extra(yyscanner);
    return (ctx->indent_level > 0) ? ctx->indent_stack[ctx->indent_level--] : 0;
}

static int current_indent(void* yyscanner) {
    LexerContext* ctx = (LexerContext*)yyget_extra(yyscanner);
    return ctx->indent_stack[ctx->indent_level];
}

