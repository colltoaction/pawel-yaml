#include "yaml_parser.h"
#include "parser.tab.h"
#include <stdio.h>

int yylex_init(void **scanner);
int yylex_destroy(void *scanner);
void yyset_in(FILE *in, void *scanner);
int yyparse(ParserContext *ctx, void *scanner);

int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram) {
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

    void *scanner;
    yylex_init(&scanner);
    yyset_in(stdin, scanner);

    int result = yyparse(&ctx, scanner);
    
    yylex_destroy(scanner);
    
    *out_diagram = ctx.diagram;
    
    return result;
}
