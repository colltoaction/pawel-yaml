%{
#include "yaml_event.tab.h"
#include <string.h>
%}

%option noyywrap yylineno

%%

\+STR           return STREAM_START;
\-STR           return STREAM_END;
\+DOC           return DOC_START;
\-DOC           return DOC_END;
\+SEQ           return SEQ_START;
\-SEQ           return SEQ_END;
\+MAP           return MAP_START;
\-MAP           return MAP_END;
=VAL            return SCALAR;
=ALI            return ALIAS;

"&"[a-zA-Z0-9_]+ {
    yylval.sval = strdup(yytext + 1);
    return ANCHOR;
}

\<[^\>]+\> {
    yylval.sval = strdup(yytext);
    return TAG;
}

: {
    yylval.cval = ':';
    return CHAR;
}

\" {
    yylval.cval = '"';
    return CHAR;
}

\' {
    yylval.cval = '\'';
    return CHAR;
}

[a-zA-Z0-9_]+ {
    yylval.sval = strdup(yytext);
    return IDENTIFIER;
}

[ \t]+ ;
\n yylineno++;
"#".* ;
. return yytext[0];

%%



