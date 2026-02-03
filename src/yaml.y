%code requires {
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;
}

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

int yaml_lex(void *yylval_param, void *yyloc_param, void *yyscanner);
void yaml_error(void *yylloc, void *scanner, const char *s);

/* Output buffer for RML IR */
extern char *rml_ir_buf;
extern size_t rml_ir_size;
static FILE *ir_out;

#define EMIT(...) fprintf(ir_out, __VA_ARGS__)

%}

%define api.pure true
%define api.prefix {yaml_}
%locations
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    NodeProps props;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET COLON QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%type <props> node_props

%glr-parser
%expect 28
%expect-rr 28

%%

stream:
    { ir_out = open_memstream(&rml_ir_buf, &rml_ir_size); }
    documents
    { fclose(ir_out); }
    ;

documents:
    implicit_document
    | explicit_documents
    | implicit_document explicit_documents
    | DOC_END
    ;

explicit_documents:
    explicit_document
    | explicit_documents explicit_document
    ;

explicit_document:
    DOC_START { EMIT("D+\n"); } document_body { EMIT("D-\n"); } optional_doc_end
    | DOC_START { EMIT("D+\nS::\n"); } optional_doc_end { EMIT("D-\n"); }
    | directives DOC_START { EMIT("D+\n"); } document_body { EMIT("D-\n"); } optional_doc_end
    | directives DOC_START { EMIT("D+\nS::\n"); } optional_doc_end { EMIT("D-\n"); }
    ;

directives: directive | directives directive ;
directive: YAML_DIRECTIVE | TAG_DIRECTIVE SCALAR SCALAR { free($2); free($3); } ;

optional_doc_end: /* empty */ | DOC_END ;

implicit_document:
    document_body { EMIT("D-\n"); } optional_doc_end
    ;

document_body:
    { EMIT("D+\n"); } node
    | { EMIT("D+\nM+\n"); } map_entries { EMIT("M-\n"); } %dprec 3
    | { EMIT("D+\nQ+\n"); } seq_entries { EMIT("Q-\n"); } %dprec 2
    | node_props[p] { EMIT("D+\nP&%s<%s>\nM+\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); } 
      map_entries { EMIT("M-\n"); free($p.anchor); free($p.tag); } %dprec 4
    | node_props[p] { EMIT("D+\nP&%s<%s>\nQ+\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); } 
      seq_entries { EMIT("Q-\n"); free($p.anchor); free($p.tag); } %dprec 3
    ;

node:
    node_body %dprec 2
    | node_props[p] { EMIT("P&%s<%s>\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); free($p.anchor); free($p.tag); } node_body %dprec 3
    | node_props[p] { EMIT("P&%s<%s>\nS::\n", $p.anchor?$p.anchor+1:"", $p.tag?$p.tag:""); free($p.anchor); free($p.tag); } %dprec 1
    ;

node_body:
    scalar
    | ALIAS[a] { EMIT("A:%s\n", $a+1); free($a); }
    | flow_seq
    | flow_map
    | collection
    ;

node_props:
    TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    | TAG[t] ANCHOR[a] { $$.anchor = $a; $$.tag = $t; }
    ;

scalar:
    SCALAR[s] { EMIT("S:%s\n", $s); free($s); }
    | QSCALAR[s] { EMIT("S\":%s\n", $s); free($s); }
    | SSCALAR[s] { EMIT("S\':%s\n", $s); free($s); }
    | BSCALAR[s] { EMIT("S%c:%s\n", $s[0], $s+1); free($s); }
    ;

collection: map | seq ;

seq:
    INDENT { EMIT("Q+\n"); } seq_entries DEDENT { EMIT("Q-\n"); }
    ;

seq_entries:
    seq_entry
    | seq_entries seq_entry
    ;

seq_entry:
    BULLET node %dprec 2
    | BULLET { EMIT("M+\n"); } map_entries { EMIT("M-\n"); } %dprec 3
    | BULLET { EMIT("S::\n"); } %dprec 1
    ;

map:
    INDENT { EMIT("M+\n"); } map_entries DEDENT { EMIT("M-\n"); }
    ;

map_entries:
    map_entry
    | map_entries map_entry
    ;

map_entry:
    entry_key COLON node %dprec 3
    | QUESTION node COLON node %dprec 5
    | entry_key COLON { EMIT("S::\n"); } %dprec 1
    | QUESTION node COLON { EMIT("S::\n"); } %dprec 1
    | QUESTION node { EMIT("S::\n"); } %dprec 2
    | COLON node %dprec 2 { EMIT("S::\n"); }
    ;

entry_key: scalar | ALIAS[a] { EMIT("A:%s\n", $a+1); free($a); } | flow_seq | flow_map ;

flow_seq:
    LBRACK { EMIT("Q+\n"); } flow_seq_entries RBRACK { EMIT("Q-\n"); }
    | LBRACK RBRACK { EMIT("Q+\nQ-\n"); }
    ;

flow_seq_entries:
    flow_node
    | flow_seq_entries COMMA flow_node
    | flow_seq_entries COMMA
    | flow_node COLON node { /* simplified */ }
    ;

flow_map:
    LBRACE { EMIT("M+\n"); } flow_map_entries RBRACE { EMIT("M-\n"); }
    | LBRACE RBRACE { EMIT("M+\nM-\n"); }
    ;

flow_map_entries:
    node COLON node
    | flow_map_entries COMMA node COLON node
    | flow_map_entries COMMA
    ;

flow_node: node ;

%%

void yaml_error(void *yylloc, void *scanner, const char *s) {
    fprintf(stderr, "YAML Error: %s\n", s);
}
