#include "mrl.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ==================== Alphabet Implementation ==================== */

Alphabet *alphabet_init(void) {
    Alphabet *a = malloc(sizeof(Alphabet));
    if (!a) return NULL;
    a->count = 0;
    a->capacity = 16;
    a->generators = malloc(sizeof(Generator*) * a->capacity);
    if (!a->generators) {
        free(a);
        return NULL;
    }
    return a;
}

void alphabet_free(Alphabet *a) {
    if (!a) return;
    for (size_t i = 0; i < a->count; i++) {
        if (a->generators[i]->value) {
            free(a->generators[i]->value);
        }
        if (a->generators[i]->tag) {
            free(a->generators[i]->tag);
        }
        if (a->generators[i]->anchor) {
            free(a->generators[i]->anchor);
        }
        free(a->generators[i]);
    }
    free(a->generators);
    free(a);
}

void alphabet_add_scalar(Alphabet *a, const char *value) {
    if (a->count >= a->capacity) {
        a->capacity *= 2;
        a->generators = realloc(a->generators, sizeof(Generator*) * a->capacity);
    }
    Generator *g = malloc(sizeof(Generator));
    g->type = GEN_TYPE_SCALAR;
    g->value = strdup(value);
    g->tag = NULL;
    g->anchor = NULL;
    g->quote = 0;
    a->generators[a->count++] = g;
}

void alphabet_add_quoted_scalar(Alphabet *a, const char *value, char quote) {
    if (a->count >= a->capacity) {
        a->capacity *= 2;
        a->generators = realloc(a->generators, sizeof(Generator*) * a->capacity);
    }
    Generator *g = malloc(sizeof(Generator));
    g->type = GEN_TYPE_SCALAR;
    g->value = strdup(value);
    g->tag = NULL;
    g->anchor = NULL;
    g->quote = quote;
    a->generators[a->count++] = g;
}

void alphabet_add_alias(Alphabet *a, const char *value) {
    if (a->count >= a->capacity) {
        a->capacity *= 2;
        a->generators = realloc(a->generators, sizeof(Generator*) * a->capacity);
    }
    Generator *g = malloc(sizeof(Generator));
    g->type = GEN_TYPE_ALIAS;
    g->value = strdup(value);
    g->tag = NULL;
    g->anchor = NULL;
    g->quote = 0;
    a->generators[a->count++] = g;
}

void alphabet_set_tag(Alphabet *a, const char *tag) {
    if (a->count > 0) {
        a->generators[a->count - 1]->tag = strdup(tag);
    }
}

void alphabet_set_anchor(Alphabet *a, const char *anchor) {
    if (a->count > 0) {
        a->generators[a->count - 1]->anchor = strdup(anchor);
    }
}

/* ==================== Grammar Implementation ==================== */

Grammar *grammar_init(void) {
    Grammar *g = malloc(sizeof(Grammar));
    if (!g) return NULL;
    g->count = 0;
    g->capacity = 16;
    g->transitions = malloc(sizeof(Transition*) * g->capacity);
    return g;
}

void grammar_free(Grammar *g) {
    if (!g) return;
    for (size_t i = 0; i < g->count; i++) {
        /* Value is owned by Alphabet generators usually, but if independent copy needed handle here */
        /* For now assuming Grammar references Alphabet or static Generators */
        free(g->transitions[i]);
    }
    free(g->transitions);
    free(g);
}

/* ==================== StringDiagram Implementation ==================== */

StringDiagram *sd_generator(Generator *g) {
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    if (!sd) return NULL;
    sd->type = SD_TYPE_GENERATOR;
    sd->data.gen = g;
    return sd;
}

StringDiagram *sd_compose(StringDiagram *f, StringDiagram *g) {
    if (!f) return g;
    if (!g) return f;
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    if (!sd) return NULL;
    sd->type = SD_TYPE_COMPOSITION;
    sd->data.binary.first = f;
    sd->data.binary.second = g;
    return sd;
}

StringDiagram *sd_tensor(StringDiagram *f, StringDiagram *g) {
    if (!f) return g;
    if (!g) return f;
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    if (!sd) return NULL;
    sd->type = SD_TYPE_TENSOR;
    sd->data.binary.first = f;
    sd->data.binary.second = g;
    return sd;
}

void sd_free(StringDiagram *sd) {
    if (!sd) return;
    if (sd->type == SD_TYPE_COMPOSITION || sd->type == SD_TYPE_TENSOR) {
        sd_free(sd->data.binary.first);
        sd_free(sd->data.binary.second);
    }
    /* Generators are owned by Alphabet, do not free sd->data.gen here */
    free(sd);
}
