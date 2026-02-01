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
%token-table
%lex-param {void *yyscanner}

%union {
    char *sval;
    StringDiagram *sd;
}

%destructor { free($$); } <sval>
%destructor { 
    if ($$ != output->diagram) {
       free_stringdiagram($$); 
    }
} <sd>


%token <sval> SCALAR
%token <sval> ANCHOR ALIAS TAG
%token BLOCK_SEQ_START "-"
%token BLOCK_KEY "?"
%token FLOW_SEQ_START "["
%token FLOW_SEQ_END "]"
%token FLOW_MAP_START "{"
%token FLOW_MAP_END "}"
%token COMMA ","
%token COLON ":"
%token DOC_START "---"
%token DOC_END "..."
%token INDENT "INDENT"
%token DEDENT "DEDENT"
%token SEQ "SEQ"
%token MAP "MAP"
%token STYLE_PLAIN "PLAIN"
%token STYLE_DQUOTE "\""
%token STYLE_SQUOTE "'"
%token STYLE_LITERAL "|"
%token STYLE_FOLDED ">"
%token STYLE_ALIAS "*"
%token STYLE_ANCHOR "&"

%precedence LOW
%precedence COLON

%type <sd> stream documents document root_node sub_node flow_item
%type <sd> block_node flow_node simple_node complex_node
%type <sd> block_sequence block_mapping mapping_entry
%type <sd> items flow_item_list mapping_items flow_mapping_list

%%

stream:
    documents {
        /* Finalize: replace the clone with the actual tree */
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = $1;
        $$ = NULL;
    }
    ;

documents:
    document { 
        $$ = $1; 
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = clone_stringdiagram($$);
    }
    | documents "---" root_node {
        if ($3) $3->doc_marker = 1;
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
        
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = clone_stringdiagram($$);
    }
    | documents "---" root_node "..." {
        if ($3) {
            $3->doc_marker = 1;
            $3->doc_end_marker = 1;
        }
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
        
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = clone_stringdiagram($$);
    }
    ;

document:
    root_node { $$ = $1; }
    | "---" root_node { 
        if ($2) $2->doc_marker = 1;
        $$ = $2; 
    }
    | "---" root_node "..." { 
        if ($2) {
            $2->doc_marker = 1;
            $2->doc_end_marker = 1;
        }
        $$ = $2; 
    }
    ;

root_node:
    block_mapping { $$ = $1; } %prec COLON
    | sub_node { $$ = $1; } %prec LOW
    ;

simple_node:
    SCALAR {
        Generator *g = get_or_create_generator(&output->alphabet, $1, 0, 1);
        $$ = create_sd_gen(g);
        free($1);
    }
    | ALIAS {
        Generator *g = get_or_create_generator(&output->alphabet, $1, 0, 1);
        $$ = create_sd_gen(g);
        free($1);
    }
    | flow_node { $$ = $1; }
    ;

complex_node:
    simple_node { $$ = $1; }
    | TAG simple_node {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | ANCHOR simple_node {
        if ($2) {
            if ($2->anchor) free($2->anchor);
            $2->anchor = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | TAG ANCHOR simple_node {
        if ($3) {
            if ($3->tag) free($3->tag);
            if ($3->anchor) free($3->anchor);
            $3->tag = $1;
            $3->anchor = $2;
            $$ = $3;
        } else {
            free($1); free($2); $$ = NULL;
        }
    }
    | ANCHOR TAG simple_node {
        if ($3) {
            if ($3->tag) free($3->tag);
            if ($3->anchor) free($3->anchor);
            $3->anchor = $1;
            $3->tag = $2;
            $$ = $3;
        } else {
            free($1); free($2); $$ = NULL;
        }
    }
    ;

sub_node:
    simple_node { $$ = $1; }
    | block_sequence { $$ = $1; }
    | "INDENT" root_node "DEDENT" { 
        /* Compose: INDENT ; root_node ; DEDENT */
        if (!output->alphabet) output->alphabet = create_alphabet();
        StringDiagram *inner_comp = create_sd_comp(create_sd_gen(output->alphabet->indent_gen), $2);
        $$ = create_sd_comp(inner_comp, create_sd_gen(output->alphabet->dedent_gen));
    }
    | TAG sub_node {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | ANCHOR sub_node {
        if ($2) {
            if ($2->anchor) free($2->anchor);
            $2->anchor = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    ;

block_sequence:
    items {
        const char *name = rml_token_name(SEQ);
        if (!name) name = "SEQ";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
    }
    ;

items:
    "-" root_node { $$ = $2; }
    | items "-" root_node {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
    }
    ;

block_mapping:
    mapping_items {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
    }
    | mapping_items error {
        /* Partial mapping on error */
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = clone_stringdiagram($$);
    }
    ;

mapping_items:
    mapping_entry { $$ = $1; }
    | mapping_items mapping_entry {
        if ($1 && $2) $$ = create_sd_prod($1, $2);
        else if ($1) $$ = $1;
        else $$ = $2;
    }
    ;

mapping_entry:
    complex_node ":" sub_node {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) {
            /* Case with colon but empty value */
            const char *name = rml_token_name(COLON);
            if (!name) name = ":";
            Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
            $$ = create_sd_prod($1, create_sd_gen(g));
        } else {
            $$ = $3;
        }
    }
    | complex_node ":" {
        const char *name = rml_token_name(COLON);
        if (!name) name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        $$ = create_sd_prod($1, create_sd_gen(g));
    }
    | "?" sub_node ":" sub_node {
        if ($2 && $4) $$ = create_sd_prod($2, $4);
        else if ($2) {
            const char *name = rml_token_name(COLON);
            if (!name) name = ":";
            Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
            $$ = create_sd_prod($2, create_sd_gen(g));
        } else {
            $$ = $4;
        }
    }
    | "?" sub_node ":" {
        const char *name = rml_token_name(COLON);
        if (!name) name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        $$ = create_sd_prod($2, create_sd_gen(g));
    }
    | "?" sub_node {
        const char *name = rml_token_name(COLON);
        if (!name) name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        if ($2) $$ = create_sd_prod($2, create_sd_gen(g));
        else $$ = create_sd_gen(g);
    }
    | ":" sub_node {
        const char *name = rml_token_name(COLON);
        if (!name) name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        if ($2) $$ = create_sd_prod(create_sd_gen(g), $2);
        else $$ = create_sd_gen(g);
    }
    ;

flow_node:
    "[" "]" {
        const char *name = rml_token_name(SEQ);
        if (!name) name = "SEQ";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        $$ = create_sd_gen(g);
        $$->flow_style = 1;
    }
    | "[" flow_item_list "]" {
        const char *name = rml_token_name(SEQ);
        if (!name) name = "SEQ";
        Generator *g = get_or_create_generator(&output->alphabet, name, $2->coarity, 1);
        $$ = create_sd_comp($2, create_sd_gen(g));
        $$->flow_style = 1;
    }
    | "{" "}" {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        $$ = create_sd_gen(g);
        $$->flow_style = 1;
    }
    | "{" flow_mapping_list "}" {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $2->coarity, 1);
        $$ = create_sd_comp($2, create_sd_gen(g));
        $$->flow_style = 1;
    }
    ;

flow_item_list:
    flow_item { $$ = $1; }
    | flow_item_list "," flow_item {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
    }
    ;

flow_item:
    simple_node { $$ = $1; }
    | block_sequence { $$ = $1; }
    | block_mapping { 
        $$ = $1;
        if ($$) $$->flow_style = 1;
    }
    | "INDENT" root_node "DEDENT" { $$ = $2; }
    | TAG flow_item {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | ANCHOR flow_item {
        if ($2) {
            if ($2->anchor) free($2->anchor);
            $2->anchor = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    ;

flow_mapping_list:
    mapping_entry { $$ = $1; }
    | simple_node {
        const char *colon_name = rml_token_name(COLON);
        if (!colon_name) colon_name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, colon_name, 0, 1);
        $$ = create_sd_prod($1, create_sd_gen(g));
    }
    | flow_mapping_list "," mapping_entry {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
    }
    | flow_mapping_list "," simple_node {
        const char *colon_name = rml_token_name(COLON);
        if (!colon_name) colon_name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, colon_name, 0, 1);
        StringDiagram *entry = create_sd_prod($3, create_sd_gen(g));
        if ($1 && entry) $$ = create_sd_prod($1, entry);
        else if ($1) $$ = $1;
        else $$ = entry;
    }
    | flow_mapping_list "," {
        $$ = $1;
    }
    ;

%%

void yyerror(void *yyscanner, ParseOutput *output, const char *s) {
    (void)yyscanner;
    (void)output;
    fprintf(stderr, "Parse error: %s\n", s);
}

const char *rml_token_name(int tok) {
    int sym = YYTRANSLATE(tok);
    if (sym < 0 || sym >= YYNTOKENS) return NULL;
    const char *name = yytname[sym];
    if (name && name[0] == '"') {
        static char buf[256];
        size_t len = strlen(name);
        if (len > 255) len = 255;
        int j = 0;
        for (int i = 1; i < len - 1; i++) {
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
