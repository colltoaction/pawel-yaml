%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mrl.h"
#include "yaml_parser.h"

extern int yylex();

/* Helper: Combine multi-line scalar parts with space separator
 * Used for plain scalars that continue across lines
 * Example: "line1" + "line2" = "line1 line2"
 */
static char *combine_scalar_parts(const char *part1, const char *part2) {
    if (!part1 || !part2) return part1 ? strdup(part1) : (part2 ? strdup(part2) : calloc(1, 1));
    
    size_t len1 = strlen(part1);
    size_t len2 = strlen(part2);
    char *combined = malloc(len1 + len2 + 2);
    if (!combined) return strdup(part1);
    
    strcpy(combined, part1);
    combined[len1] = ' ';
    strcpy(combined + len1 + 1, part2);
    return combined;
}

%}

%define api.pure full
%locations
%parse-param {void *yyscanner} {ParseOutput *output}
%token-table
%lex-param {void *yyscanner}
%define parse.trace
%define parse.error verbose
%define parse.lac full

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
%destructor { 
    if ($$ != output->diagram) {
       free_stringdiagram($$); 
    }
} <sd>

%printer { 
    if ($$) fprintf(yyo, "\"%s\"", $$);
    else fprintf(yyo, "<NULL>");
} <sval>

%printer { 
    if ($$) {
        fprintf(yyo, "<SD:%s>", 
                $$->anchor ? $$->anchor : 
                $$->tag ? $$->tag : "?");
    } else {
        fprintf(yyo, "<NULL>");
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
%type <sd> block_sequence mapping_entry
%type <sd> items flow_item_list flow_mapping_list
%type <sd> block_mapping_implicit block_mapping_explicit
%type <sd> mapping_items_implicit mapping_items_explicit
%type <sd> mapping_entry_implicit mapping_entry_explicit
%type <sval> scalar_continuation scalar_continuation_lines

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
    block_mapping_implicit { $$ = $1; } %prec COLON
    | block_mapping_explicit { $$ = $1; } %prec COLON
    | sub_node { $$ = $1; } %prec LOW
    /* Ambiguous rules removed to fix property attachment (26DV)
     * Properties should attach to the Key of implicit maps, not the map itself.
     * sub_node recursion handles properties on indented blocks.
     */
    /*
    | TAG block_mapping { ... }
    | TAG block_sequence { ... }
    | ANCHOR block_mapping { ... }
    | ANCHOR block_sequence { ... }
    | TAG ANCHOR block_mapping { ... }
    | TAG ANCHOR block_sequence { ... }
    | ANCHOR TAG block_mapping { ... }
    | ANCHOR TAG block_sequence { ... }
    */
    ;

simple_node:
    SCALAR {
        Generator *g = get_or_create_generator(&output->alphabet, $1, 0, 1);
        $$ = create_sd_gen(g);
        free($1);
    }
    | SCALAR "INDENT" scalar_continuation_lines "DEDENT" {
        /* Multi-line plain scalar: accumulate all lines */
        char *combined = combine_scalar_parts($1, $3);
        Generator *g = get_or_create_generator(&output->alphabet, combined, 0, 1);
        $$ = create_sd_gen(g);
        free(combined);
        free($1);
        free($3);
    }
    | ALIAS {
        Generator *g = get_or_create_generator(&output->alphabet, $1, 0, 1);
        $$ = create_sd_gen(g);
        free($1);
    }
    | flow_node { $$ = $1; }
    ;

scalar_continuation:
    SCALAR {
        $$ = $1;  /* Simple passthrough for now */
    }
    | SCALAR "INDENT" scalar_continuation_lines "DEDENT" {
        /* Nested multi-line (rare but possible) */
        char *combined = combine_scalar_parts($1, $3);
        $$ = combined;
        free($1);
        free($3);
    }
    ;

scalar_continuation_lines:
    SCALAR {
        $$ = $1;
    }
    | scalar_continuation_lines SCALAR {
        /* Accumulate multiple continuation lines */
        char *combined = combine_scalar_parts($1, $2);
        $$ = combined;
        free($1);
        free($2);
    }
    ;

complex_node:
    simple_node { $$ = $1; }
    | TAG complex_node {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | ANCHOR complex_node {
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

sub_node:
    complex_node { $$ = $1; }
    | block_sequence { $$ = $1; }
    | block_mapping_implicit { $$ = $1; }
    | block_mapping_explicit { $$ = $1; }
    | "INDENT" root_node "DEDENT" { 
        if (!output->alphabet) output->alphabet = create_alphabet();
        StringDiagram *inner_comp = create_sd_comp(create_sd_gen(output->alphabet->indent_gen), $2);
        $$ = create_sd_comp(inner_comp, create_sd_gen(output->alphabet->dedent_gen));
    }
    | TAG block_sequence {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | ANCHOR block_sequence {
        if ($2) {
            if ($2->anchor) free($2->anchor);
            $2->anchor = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | TAG block_mapping_explicit {
        if ($2) {
            if ($2->tag) free($2->tag);
            $2->tag = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | ANCHOR block_mapping_explicit {
        if ($2) {
            if ($2->anchor) free($2->anchor);
            $2->anchor = $1;
            $$ = $2;
        } else {
            free($1);
            $$ = NULL;
        }
    }
    | TAG ANCHOR block_sequence {
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
    | ANCHOR TAG block_sequence {
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
    | TAG "INDENT" root_node "DEDENT" {
         if (!output->alphabet) output->alphabet = create_alphabet();
         StringDiagram *inner_comp = create_sd_comp(create_sd_gen(output->alphabet->indent_gen), $3);
         StringDiagram *sub = create_sd_comp(inner_comp, create_sd_gen(output->alphabet->dedent_gen));
         if (sub) {
             sub->tag = $1;
             $$ = sub;
         } else {
             free($1);
             $$ = NULL;
         }
    }
    | ANCHOR "INDENT" root_node "DEDENT" {
        if (!output->alphabet) output->alphabet = create_alphabet();
        StringDiagram *inner_comp = create_sd_comp(create_sd_gen(output->alphabet->indent_gen), $3);
        StringDiagram *sub = create_sd_comp(inner_comp, create_sd_gen(output->alphabet->dedent_gen));
        if (sub) {
            sub->anchor = $1;
            $$ = sub;
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
    | items "INDENT" "-" root_node {
        /* Handle nested sequences with indentation
         * When a block sequence is nested with increased indentation,
         * the lexer emits INDENT. This rule allows parser to continue
         * recognizing items after that INDENT token.
         * Note: This is a pragmatic workaround for lexer limitation
         * where it cannot distinguish between "new indentation level"
         * and "natural indentation within nested sequence context"
         */
        if ($1 && $4) $$ = create_sd_prod($1, $4);
        else if ($1) $$ = $1;
        else $$ = $4;
    }
    ;

block_mapping_implicit:
    mapping_items_implicit {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
    }
    | mapping_items_implicit error {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = clone_stringdiagram($$);
    }
    ;

block_mapping_explicit:
    mapping_items_explicit {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
    }
    | mapping_items_explicit error {
        const char *name = rml_token_name(MAP);
        if (!name) name = "MAP";
        Generator *g = get_or_create_generator(&output->alphabet, name, $1->coarity, 1);
        $$ = create_sd_comp($1, create_sd_gen(g));
        if (output->diagram) free_stringdiagram(output->diagram);
        output->diagram = clone_stringdiagram($$);
    }
    ;

mapping_items_implicit:
    mapping_entry_implicit { $$ = $1; }
    | mapping_items_implicit mapping_entry {
        if ($1 && $2) $$ = create_sd_prod($1, $2);
        else if ($1) $$ = $1;
        else $$ = $2;
    }
    ;

mapping_items_explicit:
    mapping_entry_explicit { $$ = $1; }
    | mapping_items_explicit mapping_entry {
        if ($1 && $2) $$ = create_sd_prod($1, $2);
        else if ($1) $$ = $1;
        else $$ = $2;
    }
    ;

mapping_entry:
      mapping_entry_implicit { $$ = $1; }
    | mapping_entry_explicit { $$ = $1; }
    ;

mapping_entry_implicit:
    complex_node ":" sub_node {
        if ($1 && $3) $$ = create_sd_prod($1, $3);
        else if ($1) {
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
    | ":" sub_node {
        const char *name = rml_token_name(COLON);
        if (!name) name = ":";
        Generator *g = get_or_create_generator(&output->alphabet, name, 0, 1);
        if ($2) $$ = create_sd_prod(create_sd_gen(g), $2);
        else $$ = create_sd_gen(g);
    }
    ;

mapping_entry_explicit:
    "?" sub_node ":" sub_node {
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
    | block_mapping_implicit { 
        $$ = $1;
        if ($$) $$->flow_style = 1;
    }
    | block_mapping_explicit { 
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

void yyerror(YYLTYPE *yylloc, void *yyscanner, ParseOutput *output, const char *s) {
    (void)yyscanner;
    (void)output;
    if (yylloc) {
        fprintf(stderr, "%d.%d-%d.%d: %s\n",
                yylloc->first_line, yylloc->first_column,
                yylloc->last_line, yylloc->last_column,
                s);
    } else {
        fprintf(stderr, "Parse error: %s\n", s);
    }
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
