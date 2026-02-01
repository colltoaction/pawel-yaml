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
":"([ ]+|\n)     { return COLON; }
"!!"[a-z]+       { yylval->string = strdup(yytext); return TAG; }
"&"[a-zA-Z0-9_:]+ { yylval->string = strdup(yytext); return ANCHOR; }
"*"[a-zA-Z0-9_:]+ { yylval->string = strdup(yytext); return ALIAS; }
"["              { return LBRACK; }
"]"              { return RBRACK; }
"{"              { return LBRACE; }
"}"              { return RBRACE; }
","              { return COMMA; }
\"[^\"]*\"       { yylval->string = strndup(yytext+1, strlen(yytext)-2); return QSCALAR; }
\'[^\']*\'       { yylval->string = strndup(yytext+1, strlen(yytext)-2); return SSCALAR; }
[a-zA-Z0-9]+     { yylval->string = strdup(yytext); return SCALAR; }
[ \t\n\r]+       { /* skip whitespace */ }
.                { /* ignore other characters for now */ }

%%
