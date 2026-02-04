%{
#include "rml.tab.h"
%}

%option noyywrap

%%

[ \t\n\r]+    { /* skip whitespace */ }

"\+STR"       { return RML_STR_START; }
"\-STR"       { return RML_STR_END; }
"\+DOC"       { return RML_DOC_START; }
"\-DOC"       { return RML_DOC_END; }
"\+SEQ"       { return RML_SEQ_START; }
"\-SEQ"       { return RML_SEQ_END; }
"\+MAP"       { return RML_MAP_START; }
"\-MAP"       { return RML_MAP_END; }

"=VAL"[^\n]* { return RML_SCALAR; }
"=ALI"[^\n]* { return RML_ALIAS; }

.             { /* ignore other chars */ }

%%
