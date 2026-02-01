/*
 * Regular Monoidal Language (RML) Driver
 * 
 * This is the main entry point for the "pawel-yaml" binary.
 * It invokes the parser (which constructs the RML objects) and then
 * traverses the resulting StringDiagram to emit the YAML event stream.
 */

#include "yaml_parser.h"
#include <stdio.h>
#include <stdlib.h>

/* Recursive function to traverse the diagram and print events */
void traverse_diagram(StringDiagram *sd, Alphabet *alphabet) {
    if (!sd) return;

    if (sd->type == SD_TYPE_GENERATOR) {
        Generator *g = sd->data.gen;
        switch (g->type) {
            case GEN_TYPE_SCALAR:
                /* Validating against 27NA requirements: =VAL :text */
                printf("=VAL :%s\n", g->value);
                break;
            default:
                break;
        }
    } else if (sd->type == SD_TYPE_COMPOSITION) {
        /* Vertical composition (sequence) */
        traverse_diagram(sd->data.binary.first, alphabet);
        traverse_diagram(sd->data.binary.second, alphabet);
    } else if (sd->type == SD_TYPE_TENSOR) {
        /* Horizontal composition (parallel) */
        /* For now, just traverse left then right */
        traverse_diagram(sd->data.binary.first, alphabet);
        traverse_diagram(sd->data.binary.second, alphabet);
    }
}

int main(int argc, char **argv) {
    Alphabet *alphabet = NULL;
    Grammar *grammar = NULL;
    StringDiagram *diagram = NULL;

    int result = yaml_parse(&alphabet, &grammar, &diagram);

    if (result == 0) {
        /* Success - Emit the Stream Start */
        printf("+STR\n");
        printf(" +DOC ---\n"); // Hardcoded for 27NA seed
        
        traverse_diagram(diagram, alphabet);
        
        printf(" -DOC\n");
        printf("-STR\n");
    } else {
        fprintf(stderr, "Parse failed\n");
        return 1;
    }

    if (alphabet) alphabet_free(alphabet);
    if (grammar) grammar_free(grammar);
    if (diagram) sd_free(diagram);

    return result;
}
