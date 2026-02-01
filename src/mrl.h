#ifndef MRL_H
#define MRL_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

/* =====================================================
   Regular Monoidal Language (RML) Core Structures
   
   Reference: main.tex (RML Textbook)
   
   Implementation of the three fundamental objects of RML:
   1. Monoidal Alphabet Gamma (Definition 2.1)
   2. Regular Monoidal Grammar Psi : M -> Gamma (Definition 2.2)
   3. Non-deterministic Monoidal Automaton (Definition 2.3)
   ===================================================== */

#define GEN_SEQ    "SEQ"
#define GEN_MAP    "MAP"
#define GEN_COLON  ":"

#define STYLE_CHAR_PLAIN   ':'
#define STYLE_CHAR_DQUOTE  '"'
#define STYLE_CHAR_SQUOTE  '\''
#define STYLE_CHAR_LITERAL '|'
#define STYLE_CHAR_FOLDED  '>'
#define STYLE_CHAR_ALIAS   '*'
#define STYLE_CHAR_ANCHOR  '&'

/* Magic constants for RML and YAML processing */
#define NO_TOKEN_ID        (-1)
#define ESC_CHAR           27
#define YAML_TAG_SHORT     "!"
#define YAML_TAG_RESERVED  "!!"
#define YAML_TAG_PREFIX    "tag:yaml.org,2002:"
#define DOCUMENT_INDENT_LEVEL 2
#define INDENT_NAME        "INDENT"
#define DEDENT_NAME        "DEDENT"


/* Monoidal Alphabet Gamma - Definition 2.1
   Finite monoidal graph with singleton vertex set.
   Generators gamma in E_Gamma have arity and coarity. */
typedef struct {
    int token_id;           /* Token ID (if > 0) or -1 for named generators */
    char *name;             /* Generator label (for non-token generators) */
    int arity;              /* Domain dimension (ar(gamma)) */
    int coarity;            /* Codomain dimension (coar(gamma)) */
} Generator;

typedef struct {
    Generator **generators;  /* Generators gamma in E_Gamma */
    int count;               /* Number of generators */
    Generator *indent_gen;   /* Cached INDENT generator (0→1) */
    Generator *dedent_gen;   /* Cached DEDENT generator (1→0) */
} Alphabet;

/* StateList - Definition 2.3 support structure
   States Q as strings, mapped to integers internally for evaluation.
   Used in transitions of the Monoidal Automaton. */
typedef struct {
    char **names;            /* State labels */
    int count;               /* Number of states */
} StateList;

/* Transition - Definition 2.3 Monoidal Automaton transition
   Transition labeled by generator gamma from state vector w to w'.
   dom: domain states (length = gen->arity)
   cod: codomain states (length = gen->coarity) */
typedef struct {
    Generator *gen;          /* Generator label */
    StateList *dom;          /* Domain state vector (ar(gamma) states) */
    StateList *cod;          /* Codomain state vector (coar(gamma) states) */
} Transition;

/* Regular Monoidal Grammar Psi : M -> Gamma - Definition 2.2
   Morphism of monoidal graphs from M (state space automaton)
   to Gamma (generator alphabet). Specifies all transitions. */
typedef struct {
    Alphabet *alphabet;      /* Target alphabet Gamma */
    Transition **transitions;/* Transition rules Delta_gamma */
    int transition_count;    /* Number of transition rules */
} Grammar;

/* String Diagram - morphism in free pro F(Gamma)
   Recursively defined composition/product of generators.
   Input to be recognized by the Monoidal Automaton. */
typedef enum {
    SD_GENERATOR,     /* Single generator gamma */
    SD_COMPOSITION,   /* Sequential composition (;) */
    SD_PRODUCT,       /* Parallel product (tensor) */
    SD_IDENTITY       /* Identity morphism id_n */
} SDType;

typedef struct StringDiagram {
    SDType type;      /* Diagram type */
    int arity;        /* Input dimension (ar(d)) */
    int coarity;      /* Output dimension (coar(d)) */
    union {
        Generator *gen;  /* For SD_GENERATOR: generator gamma */
        struct {
            struct StringDiagram *left;   /* Left operand */
            struct StringDiagram *right;  /* Right operand */
        } op;            /* For SD_COMPOSITION, SD_PRODUCT */
        int n;           /* For SD_IDENTITY: dimension */
    } data;
    char *anchor; /* YAML anchor or alias name */
    char *tag;    /* YAML tag */
    int doc_marker; /* Non-zero if document has explicit --- marker */
    int doc_end_marker; /* Non-zero if document has explicit ... marker */
    int flow_style; /* Non-zero if this is a flow-style collection ({} or []) */
} StringDiagram;

/* ===== Creation Functions ===== */

Generator *create_generator(const char *name, int arity, int coarity);
Generator *create_generator_from_token(int token_id, int arity, int coarity);
Alphabet *create_alphabet();
void alphabet_add(Alphabet *alphabet, Generator *gen);
Generator *alphabet_find_full(Alphabet *alphabet, const char *name, int arity, int coarity);
Generator *get_or_create_generator(Alphabet **alphabet, const char *name, int arity, int coarity);

StateList *create_statelist();
void statelist_add(StateList *sl, const char *state);

Grammar *create_grammar(Alphabet *alphabet);
void grammar_add_transition(Grammar *g, Generator *gen, StateList *dom, StateList *cod);

/* StringDiagram helper for common initialization */
static inline void init_string_diagram(StringDiagram *sd, SDType type, int arity, int coarity) {
    sd->type = type;
    sd->arity = arity;
    sd->coarity = coarity;
    sd->anchor = NULL;
    sd->tag = NULL;
    sd->doc_marker = 0;
    sd->doc_end_marker = 0;
    sd->flow_style = 0;
}

StringDiagram *create_sd_gen(Generator *gen);
StringDiagram *create_sd_comp(StringDiagram *left, StringDiagram *right);
StringDiagram *create_sd_prod(StringDiagram *left, StringDiagram *right);
StringDiagram *create_sd_id(int n);
StringDiagram *clone_stringdiagram(StringDiagram *sd);

/* ===== Acceptance Test ===== */

/* Grammar-based acceptance test via string diagram simulation
 * Validates that a string diagram is accepted by the regular monoidal
 * grammar using deterministic state transitions.
 * 
 * PHASE 1: Extract generator sequence from diagram tree
 * PHASE 2: Match generators to grammar transitions
 * PHASE 3: Simulate state machine transitions
 * 
 * Returns true if diagram is accepted by the grammar, false otherwise.
 * 
 * Reference: FLEX_PATTERNS_ANALYSIS.md § Recommended Refactoring Strategy
 */
bool mrl_accepts(Grammar *g, StringDiagram *sd);

void free_generator(Generator *gen);
void free_statelist(StateList *sl);
void free_alphabet(Alphabet *alphabet);
void free_grammar(Grammar *g);
void free_stringdiagram(StringDiagram *sd);

/* Recognition logic */
typedef struct {
    int q_n; /* arity */
    int q_m; /* coarity */
    bool *matrix; /* (Q^arity) x (Q^coarity) boolean matrix */
} Relation;

Relation *mrl_evaluate_relation(Grammar *g, StringDiagram *sd, int num_states);

#endif
