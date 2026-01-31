#include "mrl.h"

Grammar* setup_mrl(Alphabet** out_alphabet, StringDiagram** out_sd) {
    Alphabet* a = create_alphabet();
    Generator* g_epsilon = create_generator("epsilon", 0, 0);
    alphabet_add(a, g_epsilon);
    Grammar* g = create_grammar(a);
    {
        StateList* dom = create_statelist();
        StateList* cod = create_statelist();
        grammar_add_transition(g, g_epsilon, dom, cod);
    }
    *out_sd = create_sd_gen(alphabet_find(a, "epsilon"));
    *out_alphabet = a;
    return g;
}
