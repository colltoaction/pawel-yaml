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
%token BULLET

%type <sd> document
%type <sd> nodes node
%type <sd> seq seq_entries seq_entry

%%

stream:
    document {
        ctx->diagram = $1;
    }
    | YAML_DIRECTIVE document {
        ctx->has_directive = 1;
        ctx->diagram = $2;
    }
    ;

document:
    nodes { $$ = $1; }
    | DOC_START nodes {
        ctx->has_marker = 1;
        $$ = $2;
    }
    ;

nodes:
    node { $$ = $1; }
    ;

node:
    SCALAR {
        alphabet_add_scalar(ctx->alphabet, $1);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($1);
    }
    | seq { $$ = $1; }
    ;

seq:
    seq_entries {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_SEQ_START;
        gs->value = NULL;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_SEQ_END;
        ge->value = NULL;
        
        /* Note: Alphabet should own these, but for Green phase let's just use them */
        /* Actually, let's add them to alphabet properly */
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        StringDiagram *start = sd_generator(gs);
        StringDiagram *end = sd_generator(ge);
        
        /* Diagram: [Start] ; [Entries] ; [End] */
        $$ = sd_compose(start, sd_compose($1, end));
    }
    ;

seq_entries:
    seq_entry { $$ = $1; }
    ;

seq_entry:
    BULLET node { $$ = $2; }
    ;

%%

void yyerror(ParserContext *ctx, void *scanner, const char *s) {
    fprintf(stderr, "Bison error: %s\n", s);
}
