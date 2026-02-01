#include "yaml_parser.h"
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex_init(void **scanner);
int yylex_destroy(void *scanner);
void yyset_in(FILE *in, void *scanner);
int yyparse(ParserContext *ctx, void *scanner);

int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram, int *has_directive, int *has_marker) {
    /* Initialize RML structures */
    *out_alphabet = alphabet_init();
    *out_grammar = grammar_init();
    *out_diagram = NULL;

    if (!*out_alphabet || !*out_grammar) {
        return 2; /* Memory error */
    }

    ParserContext ctx;
    ctx.alphabet = *out_alphabet;
    ctx.grammar = *out_grammar;
    ctx.diagram = NULL;
    ctx.has_directive = 0;
    ctx.has_marker = 0;

    void *scanner;
    yylex_init(&scanner);
    yyset_in(stdin, scanner);

    int result = yyparse(&ctx, scanner);
    
    yylex_destroy(scanner);
    
    *out_diagram = ctx.diagram;
    *has_directive = ctx.has_directive;
    *has_marker = ctx.has_marker;
    
    return result;
}

/* Recursive function to traverse the diagram and print events */
void traverse_diagram(StringDiagram *sd, Alphabet *alphabet) {
    if (!sd) return;

    if (sd->type == SD_TYPE_GENERATOR) {
        Generator *g = sd->data.gen;
        switch (g->type) {
            case GEN_TYPE_SCALAR: {
                const char *prefix = "";
                if (g->anchor) {
                    prefix = g->anchor;
                }
                
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!str") == 0) tag_val = "tag:yaml.org,2002:str";
                    else if (strcmp(tag_val, "!!int") == 0) tag_val = "tag:yaml.org,2002:int";
                    
                    if (g->anchor) {
                        printf("  =VAL %s <%s> %c%s\n", prefix, tag_val, g->quote ? g->quote : ':', g->value);
                    } else {
                        printf("  =VAL <%s> %c%s\n", tag_val, g->quote ? g->quote : ':', g->value);
                    }
                } else {
                    if (g->anchor) {
                        printf("  =VAL %s %c%s\n", prefix, g->quote ? g->quote : ':', g->value);
                    } else {
                        printf("  =VAL %c%s\n", g->quote ? g->quote : ':', g->value);
                    }
                }
            }
            break;
            case GEN_TYPE_ALIAS:
                printf("  =ALI %s\n", g->value);
                break;
            case GEN_TYPE_SEQ_START:
                if (g->anchor || g->tag) {
                    printf("  +SEQ");
                    if (g->anchor) printf(" %s", g->anchor);
                    if (g->tag) {
                        const char *tag_val = g->tag;
                        if (strcmp(tag_val, "!!seq") == 0) tag_val = "tag:yaml.org,2002:seq";
                        printf(" <%s>", tag_val);
                    }
                    printf("\n");
                } else {
                    printf("  +SEQ\n");
                }
                break;
            case GEN_TYPE_SEQ_END:
                printf("  -SEQ\n");
                break;
            case GEN_TYPE_MAP_START:
                if (g->anchor || g->tag) {
                    printf("  +MAP");
                    if (g->anchor) printf(" %s", g->anchor);
                    if (g->tag) {
                        const char *tag_val = g->tag;
                        if (strcmp(tag_val, "!!map") == 0) tag_val = "tag:yaml.org,2002:map";
                        printf(" <%s>", tag_val);
                    }
                    printf("\n");
                } else {
                    printf("  +MAP\n");
                }
                break;
            case GEN_TYPE_MAP_END:
                printf("  -MAP\n");
                break;
            case GEN_TYPE_FLOW_SEQ_START:
                if (g->anchor || g->tag) {
                    printf("  +SEQ []");
                    if (g->anchor) printf(" %s", g->anchor);
                    if (g->tag) {
                        const char *tag_val = g->tag;
                        if (strcmp(tag_val, "!!seq") == 0) tag_val = "tag:yaml.org,2002:seq";
                        printf(" <%s>", tag_val);
                    }
                    printf("\n");
                } else {
                    printf("  +SEQ []\n");
                }
                break;
            case GEN_TYPE_FLOW_SEQ_END:
                printf("  -SEQ\n");
                break;
            case GEN_TYPE_FLOW_MAP_START:
                if (g->anchor || g->tag) {
                    printf("  +MAP {}");
                    if (g->anchor) printf(" %s", g->anchor);
                    if (g->tag) {
                        const char *tag_val = g->tag;
                        if (strcmp(tag_val, "!!map") == 0) tag_val = "tag:yaml.org,2002:map";
                        printf(" <%s>", tag_val);
                    }
                    printf("\n");
                } else {
                    printf("  +MAP {}\n");
                }
                break;
            case GEN_TYPE_FLOW_MAP_END:
                printf("  -MAP\n");
                break;
            case GEN_TYPE_DOC_START:
                if (g->value && strcmp(g->value, "---") == 0) {
                    printf(" +DOC ---\n");
                } else {
                    printf(" +DOC\n");
                }
                break;
            case GEN_TYPE_DOC_END:
                printf(" -DOC\n");
                break;
            case GEN_TYPE_QUESTION:
                /* Explicit key marker - usually ignored in event stream output 
                   but we might need it for some tests if they expect something specific.
                   Actually, YAML event stream doesn't have a QUESTION event.
                   It just has VAL with or without markers.
                */
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

    if (result == 0) {
        printf("+STR\n");
        traverse_diagram(diagram, alphabet);
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
