#include <stdio.h>
#include <stdlib.h>
#include "mrl.h"
#include "yaml_parser.h"

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);

    Alphabet *a = NULL;
    Grammar *g = NULL;
    StringDiagram *sd = NULL;

    /* Use the standard entry point */
    int res = yaml_parse(&a, &g, &sd);
    
    if (sd) {
        ParseOutput output = {a, g, sd};
        rml_print_events(&output);
        
        free_stringdiagram(sd);
        free_grammar(g);
        free_alphabet(a);
    }
    
    if (res != 0) {
        if (!sd) {
            fprintf(stderr, "Parse failed with code %d\n", res);
        }
        return 1;
    }

    return 0;
}
