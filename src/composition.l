%{
#include <string.h>
#include "composition.tab.h"
#define yylval composition_yy_lval
%}

%option noyywrap yylineno
%option prefix="composition_"

%x SCALAR_VAL

%%

"+STR"          return E_STR_START;
"-STR"          return E_STR_END;
"+DOC"          return E_DOC_START;
"-DOC"          return E_DOC_END;
"+SEQ"          return E_SEQ_START;
"-SEQ"          return E_SEQ_END;
"+MAP"          return E_MAP_START;
"-MAP"          return E_MAP_END;

"=VAL"          return E_SCALAR;
"=ALI"          return E_ALIAS;

"&"[a-zA-Z0-9_]+ {
    yylval.sval = strdup(yytext + 1);
    return E_ANCHOR;
}

"<"[^>]+">" {
    yylval.sval = strdup(yytext + 1);
    yylval.sval[strlen(yylval.sval)-1] = '\0';
    return E_TAG;
}

":" {
    BEGIN(SCALAR_VAL);
    return ':';
}

<SCALAR_VAL>[^\n\r]* {
    yylval.sval = strdup(yytext);
    BEGIN(0);
    return E_IDENTIFIER;
}

"\"" {
    yylval.cval = '"';
    return E_STYLE;
}

"\'" {
    yylval.cval = '\'';
    return E_STYLE;
}

"|" {
    yylval.cval = '|';
    return E_STYLE;
}

">" {
    yylval.cval = '>';
    return E_STYLE;
}

[a-zA-Z0-9_\-\.\/!]+ {
    yylval.sval = strdup(yytext);
    return E_IDENTIFIER;
}

[ \t]+ ;
\n ;
"#".* ;
. return yytext[0];

%%
