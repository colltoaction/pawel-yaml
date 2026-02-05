%{
#include "yaml_event.tab.h"
#include "tokens.tab.h"
#include <string.h>
%}

%option noyywrap yylineno

%%

"+STR"          return TOK_EVENT_STREAM_START;
"-STR"          return TOK_EVENT_STREAM_END;
"+DOC"          return TOK_EVENT_DOCUMENT_START;
"-DOC"          return TOK_EVENT_DOCUMENT_END;
"+SEQ"          return TOK_EVENT_SEQUENCE_START;
"-SEQ"          return TOK_EVENT_SEQUENCE_END;
"+MAP"          return TOK_EVENT_MAPPING_START;
"-MAP"          return TOK_EVENT_MAPPING_END;
"=VAL"          return TOK_EVENT_SCALAR;
"=ALI"          return TOK_EVENT_ALIAS;

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



