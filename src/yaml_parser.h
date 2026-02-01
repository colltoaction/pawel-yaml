#ifndef YAML_PARSER_H
#define YAML_PARSER_H

#include "mrl.h"

/*
 * YAML Parser Context
 * Carries state through the parsing process.
 */
typedef struct {
    Alphabet *alphabet;
    Grammar *grammar;
    StringDiagram *diagram;
} ParserContext;

/*
 * Main parser entry point.
 * Parses YAML from stdin and constructs RML structures.
 * 
 * Returns:
 *   0 on success
 *   1 on parse error
 *   2 on memory error
 */
int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram);

#endif /* YAML_PARSER_H */
