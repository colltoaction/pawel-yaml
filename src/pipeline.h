#ifndef PIPELINE_H
#define PIPELINE_H

#include <stdio.h>

/**
 * Pawel-YAML 3-Stage Pipeline
 */
int yaml_pipeline_run(FILE *input, FILE *output);

/* Minimalist API */
void parse(FILE *in, FILE *out);
void lex(FILE *in, FILE *out);
void validate(FILE *in, FILE *out);

#endif
