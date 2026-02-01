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
%token COLON

%type <sd> document
%type <sd> nodes node
%type <sd> seq seq_entries seq_entry
%type <sd> map map_entries map_entry

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
    | DOC_START {
        ctx->has_marker = 1;
        $$ = NULL;
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
    | map { $$ = $1; }
    ;

seq:
    seq_entries {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_SEQ_START;
        gs->value = NULL;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_SEQ_END;
        ge->value = NULL;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        StringDiagram *start = sd_generator(gs);
        StringDiagram *end = sd_generator(ge);
        
        $$ = sd_compose(start, sd_compose($1, end));
    }
    ;

seq_entries:
    seq_entry { $$ = $1; }
    | seq_entries seq_entry { $$ = sd_compose($1, $2); }
    ;

seq_entry:
    BULLET node { $$ = $2; }
    ;

map:
    map_entries {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_MAP_START;
        gs->value = NULL;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_MAP_END;
        ge->value = NULL;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        StringDiagram *start = sd_generator(gs);
        StringDiagram *end = sd_generator(ge);
        
        $$ = sd_compose(start, sd_compose($1, end));
    }
    ;

map_entries:
    map_entry { $$ = $1; }
    | map_entries map_entry { $$ = sd_compose($1, $2); }
    ;

map_entry:
    node COLON node { $$ = sd_compose($1, $3); }
    ;

%%

void yyerror(ParserContext *ctx, void *scanner, const char *s) {
    fprintf(stderr, "Bison error: %s\n", s);
}
