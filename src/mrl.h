#ifndef MRL_H
#define MRL_H

#include <stddef.h>
#include <stdint.h>

/*
 * ============================================================================
 * Regular Monoidal Language (RML) Definitions
 * ============================================================================
 * 
 * Maps directly to the definitions in the RML textbook (main.tex).
 * 
 * Definition 2.1: Monoidal Alphabet (Gamma)
 * Definition 2.2: Regular Monoidal Grammar (Psi)
 * Definition 2.3: String Diagram (Morphism)
 */

/* ==================== Definition 2.1: Alphabet ==================== */

typedef enum {
    GEN_TYPE_SCALAR,  /* s: I -> I (Atomic generator) */
    GEN_TYPE_MERGE,   /* mu: I x I -> I (Monoid multiplication) */
    GEN_TYPE_UNIT,    /* eta: 1 -> I (Monoid unit) */
    GEN_TYPE_LBRACK,  /* [: 1 -> I (Sequence start) */
    GEN_TYPE_RBRACK,  /* ]: I -> 1 (Sequence end) */
    GEN_TYPE_LBRACE,  /* {: 1 -> I (Map start) */
    GEN_TYPE_RBRACE,  /* }: I -> 1 (Map end) */
    GEN_TYPE_COMMA,   /* ,: I -> I (Separator) */
    GEN_TYPE_COLON,   /* :: I -> I (Key-Value separator) */
    GEN_TYPE_SEQ_START,
    GEN_TYPE_SEQ_END,
    GEN_TYPE_MAP_START,
    GEN_TYPE_MAP_END,
    GEN_TYPE_FLOW_SEQ_START,
    GEN_TYPE_FLOW_SEQ_END,
    GEN_TYPE_FLOW_MAP_START,
    GEN_TYPE_FLOW_MAP_END,
    GEN_TYPE_ALIAS,         /* *alias: I -> I (Alias reference) */
    GEN_TYPE_ERROR = 256,   /* Bison standard: YYerror */
    GEN_TYPE_UNDEF = 257    /* Bison standard: YYUNDEF */
} GeneratorType;

typedef struct {
    GeneratorType type;
    char *value;      /* For SCALAR type, holds the string content */
    char *tag;        /* Optional tag: e.g., !!str */
    char *anchor;     /* Optional anchor: e.g., &anchor */
    char quote;       /* '"', '\'', or 0 */
} Generator;

typedef struct {
    Generator **generators;
    size_t count;
    size_t capacity;
} Alphabet;

/* ==================== Definition 2.2: Grammar ==================== */

typedef struct {
    int start_state;
    int end_state;
    Generator symbol;
} Transition;

typedef struct {
    Transition **transitions;
    size_t count;
    size_t capacity;
} Grammar;

/* ==================== Definition 2.3: String Diagram ==================== */

/* 
 * A String Diagram represents a morphism in the free monoidal category.
 * In our implementation, it is a tree where leaves are Generators.
 */

typedef enum {
    SD_TYPE_GENERATOR,
    SD_TYPE_COMPOSITION, /* f ; g (Vertical composition) */
    SD_TYPE_TENSOR       /* f (x) g (Horizontal composition) */
} StringDiagramType;

struct StringDiagram_s;

typedef struct StringDiagram_s {
    StringDiagramType type;
    union {
        Generator *gen; /* For SD_TYPE_GENERATOR */
        struct {
            struct StringDiagram_s *first;
            struct StringDiagram_s *second;
        } binary; /* For COMPOSITION and TENSOR */
    } data;
} StringDiagram;

/* ==================== API ==================== */

/* Alphabet */
Alphabet *alphabet_init(void);
void alphabet_free(Alphabet *a);
void alphabet_add_scalar(Alphabet *a, const char *value);
void alphabet_add_quoted_scalar(Alphabet *a, const char *value, char quote);
void alphabet_add_alias(Alphabet *a, const char *value);
void alphabet_set_tag(Alphabet *a, const char *tag);
void alphabet_set_anchor(Alphabet *a, const char *anchor);

/* Grammar */
Grammar *grammar_init(void);
void grammar_free(Grammar *g);

/* StringDiagram */
StringDiagram *sd_generator(Generator *g);
StringDiagram *sd_compose(StringDiagram *f, StringDiagram *g);
StringDiagram *sd_tensor(StringDiagram *f, StringDiagram *g);
void sd_free(StringDiagram *sd);
void sd_set_tag(StringDiagram *sd, const char *tag);
void sd_set_anchor(StringDiagram *sd, const char *anchor);

#endif /* MRL_H */
