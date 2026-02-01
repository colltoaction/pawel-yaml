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
%token <string> BSCALAR
%token <string> QSCALAR
%token <string> SSCALAR
%token <string> TAG
%token <string> ANCHOR
%token <string> ALIAS
%token YAML_DIRECTIVE
%token DOC_START
%token BULLET
%token COLON
%token LBRACK RBRACK LBRACE RBRACE COMMA

%type <sd> document
%type <sd> nodes node node_body scalar
%type <sd> seq seq_entries seq_entry
%type <sd> map map_entries map_entry
%type <sd> flow_seq flow_map flow_seq_entries flow_map_entries flow_node

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
    node_body { $$ = $1; }
    | TAG node_body {
        sd_set_tag($2, $1);
        $$ = $2;
        free($1);
    }
    | ANCHOR node_body {
        sd_set_anchor($2, $1);
        $$ = $2;
        free($1);
    }
    | ANCHOR TAG node_body {
        sd_set_anchor($3, $1);
        sd_set_tag($3, $2);
        $$ = $3;
        free($1); free($2);
    }
    ;

node_body:
    scalar { $$ = $1; }
    | ALIAS {
        alphabet_add_alias(ctx->alphabet, $1);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($1);
    }
    | seq { $$ = $1; }
    | map { $$ = $1; }
    | flow_seq { $$ = $1; }
    | flow_map { $$ = $1; }
    ;

scalar:
    SCALAR {
        alphabet_add_scalar(ctx->alphabet, $1);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($1);
    }
    | QSCALAR {
        alphabet_add_quoted_scalar(ctx->alphabet, $1, '"');
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($1);
    }
    | SSCALAR {
        alphabet_add_quoted_scalar(ctx->alphabet, $1, '\'');
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($1);
    }
    | BSCALAR {
        /* BSCALAR value starts with indicator char | or > */
        char indicator = $1[0];
        alphabet_add_quoted_scalar(ctx->alphabet, $1 + 1, indicator);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($1);
    }
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

flow_seq:
    LBRACK RBRACK {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_FLOW_SEQ_START; gs->value = NULL; gs->tag = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_FLOW_SEQ_END; ge->value = NULL; ge->tag = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_generator(ge));
    }
    | LBRACK flow_seq_entries RBRACK {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_FLOW_SEQ_START; gs->value = NULL; gs->tag = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_FLOW_SEQ_END; ge->value = NULL; ge->tag = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($2, sd_generator(ge)));
    }
    ;

flow_seq_entries:
    flow_node { $$ = $1; }
    | flow_seq_entries COMMA flow_node { $$ = sd_compose($1, $3); }
    | flow_seq_entries COMMA { $$ = $1; }
    ;

flow_map:
    LBRACE flow_map_entries RBRACE {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_FLOW_MAP_START; gs->value = NULL; gs->tag = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_FLOW_MAP_END; ge->value = NULL; ge->tag = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($2, sd_generator(ge)));
    }
    ;

flow_map_entries:
    node COLON node { $$ = sd_compose($1, $3); }
    | flow_map_entries COMMA node COLON node { $$ = sd_compose($1, sd_compose($3, $5)); }
    ;

flow_node:
    node { $$ = $1; }
    ;

%%

void yyerror(ParserContext *ctx, void *scanner, const char *s) {
    fprintf(stderr, "Bison error: %s\n", s);
}
