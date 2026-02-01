%{
#include "yaml_parser.h"
#include <stdio.h>
#include <stdlib.h>

void yyerror(ParserContext *ctx, void *scanner, const char *s);
%}

%code requires {
    #include "yaml_parser.h"
    #include "mrl.h"
}

%define api.pure full
%parse-param {ParserContext *ctx}
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    StringDiagram *sd;
}

%token <string> SCALAR
%token YAML_DIRECTIVE
%token DOC_START

%type <sd> document

%%

stream:
    YAML_DIRECTIVE document {
        ctx->diagram = $2;
    }
    ;

document:
    DOC_START SCALAR {
        alphabet_add_scalar(ctx->alphabet, $2);
        /* Use the last added generator */
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($2);
    }
    ;

%%

void yyerror(ParserContext *ctx, void *scanner, const char *s) {
    fprintf(stderr, "Bison error: %s\n", s);
}
