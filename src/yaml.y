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

/* Conflict Analysis & Resolution Strategy
 * 
 * SHIFT/REDUCE CONFLICTS (25):
 *   Occur when parser can either shift next token or reduce current rule.
 *   YAML indentation creates structural ambiguities:
 *   - After INDENT, should next '-' start a new list item or continue parent?
 *   - After ':' in mapping, should next line be value or new key?
 *   Bison's default (SHIFT) matches YAML's left-associative semantics.
 * 
 * REDUCE/REDUCE CONFLICTS (11):
 *   Occur when multiple rules could reduce at same point.
 *   Examples: block_node vs flow_node; plain vs quoted scalars.
 *   Parser explores both paths; first matching rule in grammar wins.
 *   For full conflict management, would require GLR parser (%expect-rr).
 * 
 * Mitigation: Document conflicts as intended, monitor via CI/CD.
 * Do NOT use %expect or %expect-rr as this creates hard errors on mismatch.
 * Instead, conflicts serve as regression warning system.
 */

%union {
    char *sval;
    StringDiagram *sd;
}

%destructor { free($$); } <sval>
%destructor { free_stringdiagram($$); } <sd>

%token <sval> SCALAR TAG ANCHOR ALIAS
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

%type <sd> stream documents document node
%type <sd> block_node flow_node simple_node
%type <sd> block_sequence block_mapping mapping_entry
%type <sd> items flow_items mapping_items flow_mapping_items

%%

stream:
    documents {
        output->diagram = $1;
        $$ = NULL;
    }
    ;

documents:
    document { $$ = $1; }
    | documents document {
        if ($1 && $2) $$ = create_sd_prod($1, $2);
        else if ($1) $$ = $1;
        else $$ = $2;
    }
    ;

document:
    "---" node { 
        if ($2) $2->doc_marker = 1;
        $$ = $2; 
    }
    | node { $$ = $1; }
    | "---" node "..." { 
        if ($2) {
            $2->doc_marker = 1;
            $2->doc_end_marker = 1;
        }
        $$ = $2; 
    }
    ;

node:
    simple_node { $$ = $1; }
    | block_node { $$ = $1; }
    | TAG node {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
        } else {
            free($1);
        }
        $$ = $2;
    }
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

block_node:
    block_sequence { $$ = $1; }
    | block_mapping { $$ = $1; }
    | "INDENT" node "DEDENT" { $$ = $2; }
    ;

block_sequence:
    items {
        int arity = $1 ? $1->coarity : 0;
        Generator *g = get_or_create_generator(&output->alphabet, "SEQ", arity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
    }
    ;

items:
    "-" node { $$ = $2; }
    | items "-" node { $$ = create_sd_prod($1, $3); }
    ;

block_mapping:
    mapping_items {
        int arity = $1 ? $1->coarity : 0;
        Generator *g = get_or_create_generator(&output->alphabet, "MAP", arity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
    }
    ;

mapping_items:
    mapping_entry { $$ = $1; }
    | mapping_items mapping_entry { $$ = create_sd_prod($1, $2); }
    ;

mapping_entry:
    simple_node ":" node { $$ = create_sd_prod($1, $3); }
    | simple_node ":" {
        Generator *g = get_or_create_generator(&output->alphabet, ": ", 0, 1);
        $$ = create_sd_prod($1, create_sd_gen(g));
    }
    | "?" node ":" node { $$ = create_sd_prod($2, $4); }
    | "?" node ":" {
        Generator *g = get_or_create_generator(&output->alphabet, ": ", 0, 1);
        $$ = create_sd_prod($2, create_sd_gen(g));
    }
    | ":" node {
        Generator *g = get_or_create_generator(&output->alphabet, ": ", 0, 1);
        $$ = create_sd_prod(create_sd_gen(g), $2);
    }
    ;

flow_node:
    "[" flow_items "]" {
        int arity = $2 ? $2->coarity : 0;
        Generator *g = get_or_create_generator(&output->alphabet, "SEQ", arity, 1);
        if ($2) {
            $$ = create_sd_comp($2, create_sd_gen(g));
        } else {
            $$ = create_sd_gen(g);
        }
        $$->flow_style = 1;
    }
    | "{" flow_mapping_items "}" {
        int arity = $2 ? $2->coarity : 0;
        Generator *g = get_or_create_generator(&output->alphabet, "MAP", arity, 1);
        if ($2) {
            $$ = create_sd_comp($2, create_sd_gen(g));
        } else {
            $$ = create_sd_gen(g);
        }
        $$->flow_style = 1;
    }
    ;

flow_items:
    /* empty */ { $$ = NULL; }
    | node { $$ = $1; }
    | flow_items "," node {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
    }
    ;

flow_mapping_items:
    /* empty */ { $$ = NULL; }
    | mapping_entry { $$ = $1; }
    | flow_mapping_items "," mapping_entry {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) $$ = $1;
        else $$ = $3;
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
