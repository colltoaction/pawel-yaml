#include "mrl.h"
#include <assert.h>

Generator *create_generator(const char *name, int arity, int coarity) {
    Generator *g = malloc(sizeof(Generator));
    g->token_id = NO_TOKEN_ID;
    g->name = strdup(name);
    g->arity = arity;
    g->coarity = coarity;
    return g;
}

Generator *create_generator_from_token(int token_id, int arity, int coarity) {
    Generator *g = malloc(sizeof(Generator));
    g->token_id = token_id;
    g->name = NULL;
    g->arity = arity;
    g->coarity = coarity;
    return g;
}

Alphabet *create_alphabet() {
    Alphabet *a = malloc(sizeof(Alphabet));
    a->generators = NULL;
    a->count = 0;
    /* Pre-create INDENT (0→1) and DEDENT (1→0) generators */
    a->indent_gen = create_generator(INDENT_NAME, 0, 0);
    a->dedent_gen = create_generator(DEDENT_NAME, 1, 1);
    alphabet_add(a, a->indent_gen);
    alphabet_add(a, a->dedent_gen);
    return a;
}

void alphabet_add(Alphabet *alphabet, Generator *gen) {
    if (!alphabet) return;
    size_t new_size = sizeof(Generator *) * (alphabet->count + 1);
    alphabet->generators = realloc(alphabet->generators, new_size);
    alphabet->generators[alphabet->count++] = gen;
}

Generator *alphabet_find_full(Alphabet *alphabet, const char *name, int arity, int coarity) {
    if (!alphabet || !name) return NULL;
    for (int i = 0; i < alphabet->count; i++) {
        if (strcmp(alphabet->generators[i]->name, name) == 0) {
            bool arity_matches = (arity == -1 || alphabet->generators[i]->arity == arity);
            bool coarity_matches = (coarity == -1 || alphabet->generators[i]->coarity == coarity);
            if (arity_matches && coarity_matches) {
                return alphabet->generators[i];
            }
        }
    }
    return NULL;
}

Generator *get_or_create_generator(Alphabet **alphabet, const char *name, int arity, int coarity) {
    if (!alphabet) return NULL;
    
    Generator *g = alphabet_find_full(*alphabet, name, arity, coarity);
    if (!g) {
        if (!*alphabet) *alphabet = create_alphabet();
        g = create_generator(name, arity, coarity);
        alphabet_add(*alphabet, g);
    }
    return g;
}

StateList *create_statelist() {
    StateList *sl = malloc(sizeof(StateList));
    sl->names = NULL;
    sl->count = 0;
    return sl;
}

void statelist_add(StateList *sl, const char *state) {
    sl->names = realloc(sl->names, sizeof(char *) * (sl->count + 1));
    sl->names[sl->count++] = strdup(state);
}

Grammar *create_grammar(Alphabet *alphabet) {
    Grammar *g = malloc(sizeof(Grammar));
    g->alphabet = alphabet;
    g->transitions = NULL;
    g->transition_count = 0;
    return g;
}

void grammar_add_transition(Grammar *g, Generator *gen, StateList *dom, StateList *cod) {
    assert(dom->count == gen->arity);
    assert(cod->count == gen->coarity);
    Transition *t = malloc(sizeof(Transition));
    t->gen = gen;
    t->dom = dom;
    t->cod = cod;
    g->transitions = realloc(g->transitions, sizeof(Transition *) * (g->transition_count + 1));
    g->transitions[g->transition_count++] = t;
}

StringDiagram *create_sd_gen(Generator *gen) {
    if (!gen) return NULL;
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    init_string_diagram(sd, SD_GENERATOR, gen->arity, gen->coarity);
    sd->data.gen = gen;
    return sd;
}

StringDiagram *create_sd_comp(StringDiagram *left, StringDiagram *right) {
    if (!left || !right) return NULL;
    assert(left->coarity == right->arity);
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    init_string_diagram(sd, SD_COMPOSITION, left->arity, right->coarity);
    sd->data.op.left = left;
    sd->data.op.right = right;
    return sd;
}

StringDiagram *create_sd_prod(StringDiagram *left, StringDiagram *right) {
    if (!left || !right) return NULL;
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    init_string_diagram(sd, SD_PRODUCT, left->arity + right->arity, left->coarity + right->coarity);
    sd->data.op.left = left;
    sd->data.op.right = right;
    return sd;
}

StringDiagram *create_sd_id(int n) {
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    init_string_diagram(sd, SD_IDENTITY, n, n);
    sd->data.n = n;
    return sd;
}

// Cleanup Functions for RML Structures

void free_generator(Generator *gen) {
    if (!gen) return;
    if (gen->name) free(gen->name);
    free(gen);
}

void free_statelist(StateList *sl) {
    if (!sl) return;
    for (int i = 0; i < sl->count; i++) {
        free(sl->names[i]);
    }
    free(sl->names);
    free(sl);
}

void free_alphabet(Alphabet *alphabet) {
    if (!alphabet) return;
    for (int i = 0; i < alphabet->count; i++) {
        free_generator(alphabet->generators[i]);
    }
    free(alphabet->generators);
    free(alphabet);
}

void free_grammar(Grammar *g) {
    if (!g) return;
    for (int i = 0; i < g->transition_count; i++) {
        Transition *t = g->transitions[i];
        if (t) {
            free_statelist(t->dom);
            free_statelist(t->cod);
            free(t);
        }
    }
    free(g->transitions);
    free(g);
}

void free_stringdiagram(StringDiagram *sd) {
    if (!sd) return;
    if (sd->anchor) free(sd->anchor);
    if (sd->tag) free(sd->tag);
    switch (sd->type) {
        case SD_GENERATOR:
            break;
        case SD_COMPOSITION:
            free_stringdiagram(sd->data.op.left);
            free_stringdiagram(sd->data.op.right);
            break;
        case SD_PRODUCT:
            free_stringdiagram(sd->data.op.left);
            free_stringdiagram(sd->data.op.right);
            break;
        case SD_IDENTITY:
            break;
    }
    free(sd);
}

Relation *create_relation(int arity, int coarity, int num_states) {
    Relation *r = malloc(sizeof(Relation));
    r->q_n = arity;
    r->q_m = coarity;
    long size = 1;
    for (int i=0; i<arity; i++) size *= num_states;
    for (int i=0; i<coarity; i++) size *= num_states;
    r->matrix = calloc(size, sizeof(bool));
    return r;
}

bool mrl_accepts(Grammar *g, StringDiagram *sd) {
    return false; // Stub
}
