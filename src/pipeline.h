#ifndef PIPELINE_H
#define PIPELINE_H

#include <stdio.h>

/**
 * Pawel-YAML 3-Stage Pipeline
 * Uses standard Bison return codes: YYACCEPT (0) for success, YYABORT (1) for error
 */
int yaml_pipeline_run(FILE *input, FILE *output);

/* Minimalist API */
int parse(FILE *in, FILE *out);
int lex(FILE *in, FILE *out);
int validate(FILE *in, FILE *out);

#endif
