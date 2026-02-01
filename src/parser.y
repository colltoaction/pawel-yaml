%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mrl.h"
#include "yaml_parser.h"

extern int yylex();
extern void yyerror(void *yyscanner, ParseOutput *output, const char *s);

%}

%define api.pure full
%parse-param {void *yyscanner} {ParseOutput *output}
%lex-param {void *yyscanner}

%union {
    char *sval;
    StringDiagram *sd;
}

%destructor { free($$); } <sval>
%destructor { free_stringdiagram($$); } <sd>

%token <sval> SCALAR
%token <sval> ANCHOR ALIAS
%token BLOCK_SEQ_START BLOCK_KEY BLOCK_END
%token FLOW_SEQ_START FLOW_SEQ_END
%token FLOW_MAP_START FLOW_MAP_END
%token COMMA COLON
%token DOC_START DOC_END
%token INDENT DEDENT

%type <sd> stream document node block_node flow_node
%type <sd> block_sequence block_mapping flow_sequence
%type <sd> block_sequence_items block_mapping_items flow_sequence_items
%type <sd> simple_node
%type <sd> block_mapping_entry

%%

stream:
    document {
        output->diagram = $1;
        $$ = NULL;
    }
    | stream document {
        if ($1) free_stringdiagram($1);
        output->diagram = $2;
        $$ = NULL;
    }
    ;

document:
    DOC_START node { $$ = $2; }
    | node { $$ = $1; }
    ;

node:
    simple_node
    | block_node
    | ANCHOR node {
        if ($2) {
            if ($2->anchor) free($2->anchor);
            $2->anchor = $1;
        } else {
            free($1);
        }
        $$ = $2;
    }
    ;

simple_node:
    SCALAR {
        Generator *g = create_generator($1, 0, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        $$ = create_sd_gen(g);
        free($1);
    }
    | ALIAS {
        Generator *gen = create_generator($1, 0, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, gen);
        $$ = create_sd_gen(gen);
        free($1);
    }
    | flow_node
    | ANCHOR {
        free($1);
        $$ = NULL;
    }
    | ANCHOR simple_node {
        if ($2->anchor) free($2->anchor);
        $2->anchor = $1;
        $$ = $2;
    }
    ;

block_node:
    block_sequence
    | block_mapping
    | INDENT node DEDENT {
        /* Compose: INDENT ; node ; DEDENT */
        if (!output->alphabet) output->alphabet = create_alphabet();
        StringDiagram *inner_comp = create_sd_comp(output->alphabet->indent_gen ? 
                                                    create_sd_gen(output->alphabet->indent_gen) : 
                                                    $2, 
                                                    $2);
        $$ = create_sd_comp(inner_comp, 
                           output->alphabet->dedent_gen ? 
                           create_sd_gen(output->alphabet->dedent_gen) : 
                           NULL);
    }
    ;

block_sequence:
    block_sequence_items {
        int arity = $1 ? $1->coarity : 0;
        Generator *g = create_generator("SEQ", arity, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *wrapper = create_sd_gen(g);
        $$ = create_sd_comp($1, wrapper);
    }
    ;

block_sequence_items:
    BLOCK_SEQ_START node {
        $$ = $2;
    }
    | block_sequence_items BLOCK_SEQ_START node {
        $$ = create_sd_prod($1, $3);
    }
    ;

block_mapping:
    block_mapping_items {
        int arity = $1 ? $1->coarity : 0;
        Generator *g = create_generator("MAP", arity, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *wrapper = create_sd_gen(g);
        $$ = create_sd_comp($1, wrapper);
    }
    ;

block_mapping_items:
    block_mapping_entry { $$ = $1; }
    | block_mapping_items block_mapping_entry {
        $$ = create_sd_prod($1, $2);
    }
    ;

block_mapping_entry:
    simple_node COLON node {
        $$ = create_sd_prod($1, $3);
    }
    | simple_node COLON {
        Generator *g = create_generator(": ", 0, 1); // Empty value with colon suffix format
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *val = create_sd_gen(g);
        $$ = create_sd_prod($1, val);
    }
    | BLOCK_KEY node COLON node {
        $$ = create_sd_prod($2, $4);
    }
    | BLOCK_KEY node {
        Generator *g = create_generator(": ", 0, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *val = create_sd_gen(g);
        $$ = create_sd_prod($2, val);
    }
    | BLOCK_KEY COLON node {
        Generator *g = create_generator(": ", 0, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *key = create_sd_gen(g);
        $$ = create_sd_prod(key, $3);
    }
    | COLON node {
        Generator *g = create_generator(": ", 0, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *key = create_sd_gen(g);
        $$ = create_sd_prod(key, $2);
    }
    ;

flow_node:
    flow_sequence
    ;

flow_sequence:
    FLOW_SEQ_START flow_sequence_items FLOW_SEQ_END {
        int arity = $2 ? $2->coarity : 0;
        Generator *g = create_generator("SEQ", arity, 1);
        if (!output->alphabet) output->alphabet = create_alphabet();
        alphabet_add(output->alphabet, g);
        StringDiagram *wrapper = create_sd_gen(g);
        $$ = create_sd_comp($2, wrapper);
    }
    ;

flow_sequence_items:
    node { $$ = $1; }
    | flow_sequence_items COMMA node {
        $$ = create_sd_prod($1, $3);
    }
    ;

%%

void yyerror(void *yyscanner, ParseOutput *output, const char *s) {
    (void)yyscanner;
    (void)output;
    fprintf(stderr, "Parse error: %s\n", s);
}
