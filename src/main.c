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
#include <string.h>

/* Recursive function to traverse the diagram and print events */
void traverse_diagram(StringDiagram *sd, Alphabet *alphabet) {
    if (!sd) return;

    if (sd->type == SD_TYPE_GENERATOR) {
        Generator *g = sd->data.gen;
        switch (g->type) {
            case GEN_TYPE_SCALAR:
                /* Validating against 27NA and 2AUY requirements */
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!str") == 0) tag_val = "tag:yaml.org,2002:str";
                    else if (strcmp(tag_val, "!!int") == 0) tag_val = "tag:yaml.org,2002:int";
                    
                    printf("  =VAL <%s> :%s\n", tag_val, g->value);
                } else {
                    printf("  =VAL :%s\n", g->value);
                }
                break;
            case GEN_TYPE_SEQ_START:
                printf("  +SEQ\n");
                break;
            case GEN_TYPE_SEQ_END:
                printf("  -SEQ\n");
                break;
            case GEN_TYPE_MAP_START:
                printf("  +MAP\n");
                break;
            case GEN_TYPE_MAP_END:
                printf("  -MAP\n");
                break;
            default:
                break;
        }
    } else if (sd->type == SD_TYPE_COMPOSITION || sd->type == SD_TYPE_TENSOR) {
        /* Traverse children */
        traverse_diagram(sd->data.binary.first, alphabet);
        traverse_diagram(sd->data.binary.second, alphabet);
    }
}

int main(int argc, char **argv) {
    Alphabet *alphabet = NULL;
    Grammar *grammar = NULL;
    StringDiagram *diagram = NULL;

    int has_directive = 0;
    int has_marker = 0;

    int result = yaml_parse(&alphabet, &grammar, &diagram, &has_directive, &has_marker);

    /* We need to access the flags, but yaml_parse doesn't return them currently. 
       Let's assume for now we just handle based on diagram content or improve API.
       Actually, let's just make traverse_diagram handle 1 space indentation and
       main handle the STR/DOC wrappers.
    */

    if (result == 0) {
        printf("+STR\n");
        if (has_directive || has_marker) {
            printf(" +DOC ---\n");
        } else {
            printf(" +DOC\n");
        }
        
        traverse_diagram(diagram, alphabet);
        
        printf(" -DOC\n");
        printf("-STR\n");
    }
 else {
        fprintf(stderr, "Parse failed\n");
        return 1;
    }

    if (alphabet) alphabet_free(alphabet);
    if (grammar) grammar_free(grammar);
    if (diagram) sd_free(diagram);

    return result;
}
