%{
#include <string.h>
#include "yaml_event.tab.h"
#define yylval yaml_event_lval
%}

%option noyywrap yylineno
%option prefix="yaml_event_"

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
    yylval.cval = ':';
    return E_CHAR;
}

"\"" {
    yylval.cval = '"';
    return E_CHAR;
}

"\'" {
    yylval.cval = '\'';
    return E_CHAR;
}

"|" {
    yylval.cval = '|';
    return E_CHAR;
}

">" {
    yylval.cval = '>';
    return E_CHAR;
}

[a-zA-Z0-9_.\-\/]+ {
    yylval.sval = strdup(yytext);
    return E_IDENTIFIER;
}

\"[^\"]*\" {
    yylval.sval = strdup(yytext + 1);
    yylval.sval[strlen(yylval.sval) - 1] = '\0';  // Remove closing quote
    return E_QUOTED_STRING;
}

[ \t]+ ;
\n ;
"#".* ;
. return yytext[0];

%%
