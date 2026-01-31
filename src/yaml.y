%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mrl.h"
#include "yaml_parser.h"

extern int yylex();
void yyerror(void *yyscanner, ParseOutput *output, const char *s) {
    (void)yyscanner; (void)output;
    fprintf(stderr, "Parse error: %s\n", s);
}
%}

%token-table
%define api.pure full
%parse-param {void *yyscanner} {ParseOutput *output}

%union {
    char *sval;
    StringDiagram *sd;
}

%token <sval> SCALAR TAG ANCHOR ALIAS
%token DOC_START DOC_END INDENT DEDENT 
%token BLOCK_SEQ_START BLOCK_KEY COLON
%token FLOW_SEQ_START FLOW_SEQ_END FLOW_MAP_START FLOW_MAP_END COMMA
%token SEQ MAP
%token STYLE_PLAIN STYLE_DQUOTE STYLE_SQUOTE STYLE_LITERAL STYLE_FOLDED STYLE_ALIAS STYLE_ANCHOR

%%
start: /* empty */ ;
%%

const char *rml_token_name(int tok) {
    int sym = YYTRANSLATE(tok);
    if (sym < 0 || sym >= YYNTOKENS) return NULL;
    const char *name = yytname[sym];
    if (name && name[0] == '"') {
        static char buf[256];
        size_t len = strlen(name);
        if (len > 255) len = 255;
        int j = 0;
        for (int i = 1; i < (int)len - 1; i++) {
            if (name[i] == '\\' && name[i+1] == '"') {
                buf[j++] = '"';
                i++;
            } else if (name[i] == '\\' && name[i+1] == '\\') {
                buf[j++] = '\\';
                i++;
            } else {
                buf[j++] = name[i];
            }
        }
        buf[j] = '\0';
        return buf;
    }
    return name;
}
