%define api.prefix {tokens_}

%{
/**
 * tokens.y - Unified Token Definitions for Pawel-YAML
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

%union {
    char *string;
    NodeProps props;
}

/* Standardized Event Tokens (alphabet for Stage 2 and 3) */
/* We use TOK_ prefix to avoid clashes with local parser definitions */
%token TOK_EVENT_STREAM_START   "+STR"
%token TOK_EVENT_STREAM_END     "-STR"
%token TOK_EVENT_DOCUMENT_START "+DOC"
%token TOK_EVENT_DOCUMENT_END   "-DOC"
%token TOK_EVENT_SEQUENCE_START "+SEQ"
%token TOK_EVENT_SEQUENCE_END   "-SEQ"
%token TOK_EVENT_MAPPING_START  "+MAP"
%token TOK_EVENT_MAPPING_END    "-MAP"
%token TOK_EVENT_SCALAR         "=VAL"
%token TOK_EVENT_ALIAS          "=ALI"

%%

dummy: /* empty */ ;

%%
