%{
#include "rml.tab.h"
#include <string.h>
#include <stdlib.h>

#define YYSTYPE RML_STYPE

/* RML Lexer - tokenizes the intermediate Monoidal IR */
%}

%option noyywrap
%option prefix="rml_"
%option reentrant
%option bison-bridge

%%

[ \t\n\r]+    { /* skip whitespace */ }

"D+"          { return RML_DOC_START; }
"D-"          { return RML_DOC_END; }
"Q+"          { return RML_SEQ_START; }
"Q-"          { return RML_SEQ_END; }
"M+"          { return RML_MAP_START; }
"M-"          { return RML_MAP_END; }

"S"[^:\n]*":"[^\n]* {
    /* Scalar: S[quote]:[value] */
    char *s = strdup(yytext + 1);
    char *colon = strchr(s, ':');
    if (colon) {
        *colon = '\0';
        yylval->node.value = strdup(colon + 1);
        yylval->node.quote = s[0];
    } else {
        yylval->node.value = strdup("");
        yylval->node.quote = 0;
    }
    yylval->node.anchor = NULL;
    yylval->node.tag = NULL;
    free(s);
    return RML_VAL;
}

"A:"[^\n]* {
    /* Alias: A:[value] */
    yylval->node.value = strdup(yytext + 2);
    yylval->node.anchor = NULL;
    yylval->node.tag = NULL;
    yylval->node.quote = 0;
    return RML_ALIAS;
}

"P&"[^<]*"<"[^>]*">" {
    /* Props: P&anchor<tag> */
    char *s = strdup(yytext + 2);
    char *tag_start = strchr(s, '<');
    if (tag_start) {
        *tag_start = '\0';
        yylval->node.anchor = strdup(s);
        char *tag_end = strchr(tag_start + 1, '>');
        if (tag_end) *tag_end = '\0';
        yylval->node.tag = strdup(tag_start + 1);
    }
    yylval->node.value = NULL;
    yylval->node.quote = 0;
    free(s);
    return RML_PROP;
}

.             { return yytext[0]; }

%%
