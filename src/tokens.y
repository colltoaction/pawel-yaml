%{
/**
 * tokens.y - Unified Token Definitions for Pawel-YAML
 * 
 * This Bison grammar file defines shared token types and semantic values
 * used across YAML and RML parsers. Bison generates tokens.tab.h which
 * is included by all parser and lexer files.
 * 
 * Benefits:
 * - Single source of truth for token definitions
 * - Automatic header generation via Bison
 * - Type safety across lexer/parser boundaries
 * - Consistent token numbering
 */
%}

%code requires {
/**
 * Node properties structure for anchor/tag pairs
 */
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;
}

/* Define the semantic value union used by all parsers */
%union {
    char *string;           /* YAML tokens: SCALAR, TAG, ANCHOR, ALIAS */
    NodeProps props;        /* Node properties: anchor/tag pairs */
    
    /* RML tokens - structured node information */
    struct {
        char *value;        /* Scalar value */
        char *anchor;       /* Anchor name (&name) */
        char *tag;          /* Tag (!tag) */
        char quote;         /* Quote style: 0=plain, '"'=double, '\''=single, '|'=literal, '>'=folded */
    } node;
}

/* YAML Presentation Layer Tokens */
%token <string> YAML_SCALAR        "scalar value"
%token <string> YAML_QSCALAR       "double-quoted scalar"
%token <string> YAML_SSCALAR       "single-quoted scalar"
%token <string> YAML_BSCALAR       "block scalar"
%token <string> YAML_TAG           "tag"
%token <string> YAML_ANCHOR        "anchor"
%token <string> YAML_ALIAS         "alias"
%token YAML_COLON                  "colon"
%token YAML_BULLET                 "bullet"
%token YAML_INDENT                 "indent"
%token YAML_DEDENT                 "dedent"
%token YAML_QUESTION               "question mark"
%token YAML_DOC_START              "document start"
%token YAML_DOC_END                "document end"
%token YAML_LBRACK                 "left bracket"
%token YAML_RBRACK                 "right bracket"
%token YAML_LBRACE                 "left brace"
%token YAML_RBRACE                 "right brace"
%token YAML_COMMA                  "comma"
%token YAML_DIRECTIVE              "directive"
%token YAML_TAG_DIRECTIVE          "tag directive"

/* RML Intermediate Representation Tokens */
%token <node> RML_VAL              "rml scalar"
%token <string> RML_ALIAS          "rml alias"
%token <string> RML_PROP           "rml property"
%token RML_SEQ_START               "rml sequence start"
%token RML_SEQ_END                 "rml sequence end"
%token RML_MAP_START               "rml mapping start"
%token RML_MAP_END                 "rml mapping end"
%token RML_DOC_START               "rml document start"
%token RML_DOC_END                 "rml document end"

%%

/* Empty grammar - this file only defines tokens */
dummy: /* empty */ ;

%%
