%{
#include "event.tab.h"
#define yylval event_yy_lval
%}

%option noyywrap yylineno
%option prefix="event_"

%x SCALAR_VAL

%%

"+"("STR"|"DOC"|"SEQ"|"MAP") {
    yyless(1);
    return '+';
}
"-"("STR"|"DOC"|"SEQ"|"MAP") {
    yyless(1);
    return '-';
}
"="("VAL"|"ALI") {
    yyless(1);
    return '=';
}
":"/[^\n\r] {
    BEGIN(SCALAR_VAL);
    return ':';
}
":"/\n {
    BEGIN(SCALAR_VAL);
    return ':';
}
":" {
    BEGIN(SCALAR_VAL);
    return ':';
}

"STR"           return STR;
"DOC"           return DOC;
"SEQ"           return SEQ;
"MAP"           return MAP;
"VAL"           return VAL;
"ALI"           return ALI;

"---"           return E_DOC_EXPLICIT;
"..."           return E_DOC_END_EXPLICIT;
"[]"            return FLOW_SEQ_MARKER;
"{}"            return FLOW_MAP_MARKER;

"&"[^ \t\n\r]+ {
    return E_ANCHOR;
}

"<"[^>]+">" {
    return E_TAG;
}

"!"[a-zA-Z0-9_:/\.\-!%]+ {
    return E_TAG;
}

"!" {
    return E_TAG;
}

<SCALAR_VAL>[^\n\r]+ {
    BEGIN(0);
    return E_IDENTIFIER;
}
<SCALAR_VAL>\r?\n {
    BEGIN(0);
}

"\"" {
    yylval = '"';
    BEGIN(SCALAR_VAL);
    return E_STYLE;
}

"\'" {
    yylval = '\'';
    BEGIN(SCALAR_VAL);
    return E_STYLE;
}

"|" {
    yylval = '|';
    BEGIN(SCALAR_VAL);
    return E_STYLE;
}

">" {
    yylval = '>';
    BEGIN(SCALAR_VAL);
    return E_STYLE;
}

"*"[^ \t\n\r]+ {
    return E_IDENTIFIER;
}

[a-zA-Z0-9_\.\/!][a-zA-Z0-9_\-\.\/!:]* {
    return E_IDENTIFIER;
}

[ \t]+ ;
\n ;
"#".* ;
. return yytext[0];

%%
