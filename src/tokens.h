#ifndef TOKENS_H
#define TOKENS_H

/**
 * tokens.h - Unified Token Definitions for Pawel-YAML
 * 
 * This header provides a centralized type system for semantic values
 * shared across YAML and RML parsers, implementing the consolidation
 * strategy from FLEX_BISON_REFACTOR.md Phase 1.
 * 
 * Benefits:
 * - Single source of truth for semantic types
 * - Type safety across lexer/parser boundaries
 * - Easier maintenance and extension
 */

/**
 * Semantic value union: Shared across YAML and RML parsers
 * Each token type maps to one field in this union
 */
typedef union {
    /* YAML tokens - simple string values */
    char *string;           /* SCALAR, TAG, ANCHOR, ALIAS, etc. */
    
    /* RML tokens - structured node information */
    struct {
        char *value;        /* Scalar value */
        char *anchor;       /* Anchor name (&name) */
        char *tag;          /* Tag (!tag) */
        char quote;         /* Quote style: 0=plain, '"'=double, '\''=single, '|'=literal, '>'=folded */
    } node;
    
    /* Node properties - anchor/tag pairs */
    struct {
        char *anchor;
        char *tag;
    } props;
} ParserValue;

/**
 * Token ID Constants
 * 
 * YAML tokens (100-199): Presentation layer tokens
 * RML tokens (200-299): Intermediate representation tokens
 */

/* YAML Presentation Tokens */
#define TOKEN_YAML_SCALAR       100
#define TOKEN_YAML_QSCALAR      101  /* Quoted scalar */
#define TOKEN_YAML_SSCALAR      102  /* Single-quoted scalar */
#define TOKEN_YAML_BSCALAR      103  /* Block scalar (| or >) */
#define TOKEN_YAML_TAG          104
#define TOKEN_YAML_ANCHOR       105
#define TOKEN_YAML_ALIAS        106
#define TOKEN_YAML_COLON        107
#define TOKEN_YAML_BULLET       108
#define TOKEN_YAML_INDENT       109
#define TOKEN_YAML_DEDENT       110
#define TOKEN_YAML_BLOCK_KEY    111  /* ? explicit key */
#define TOKEN_YAML_DOC_START    112  /* --- */
#define TOKEN_YAML_DOC_END      113  /* ... */
#define TOKEN_YAML_LBRACKET     114  /* [ */
#define TOKEN_YAML_RBRACKET     115  /* ] */
#define TOKEN_YAML_LBRACE       116  /* { */
#define TOKEN_YAML_RBRACE       117  /* } */
#define TOKEN_YAML_COMMA        118

/* RML Intermediate Representation Tokens */
#define TOKEN_RML_VAL           200  /* Scalar value */
#define TOKEN_RML_ALIAS         201  /* Alias reference */
#define TOKEN_RML_PROP          202  /* Node property (anchor/tag) */
#define TOKEN_RML_SEQ_START     203  /* Sequence start */
#define TOKEN_RML_SEQ_END       204  /* Sequence end */
#define TOKEN_RML_MAP_START     205  /* Mapping start */
#define TOKEN_RML_MAP_END       206  /* Mapping end */
#define TOKEN_RML_DOC_START     207  /* Document start */
#define TOKEN_RML_DOC_END       208  /* Document end */

#endif /* TOKENS_H */
