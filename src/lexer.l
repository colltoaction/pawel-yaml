%{
#include "parser.tab.h"
#include <string.h>

/* Define YY_DECL to match our reentrant requirements if needed, 
   but for now keep it simple. */
%}

%option noyywrap
%option reentrant
%option bison-bridge

%%

"%YAML 1.2"      { return YAML_DIRECTIVE; }
"---"            { return DOC_START; }
"-"[ ]+          { return BULLET; }
[a-zA-Z0-9]+     { yylval->string = strdup(yytext); return SCALAR; }
[ \t\n\r]+       { /* skip whitespace */ }
.                { /* ignore other characters for now */ }

%%
