#ifndef PIPELINE_H
#define PIPELINE_H

#include <stdio.h>

/**
 * Pawel-YAML 3-Stage Pipeline
 */
int yaml_pipeline_run(FILE *input, FILE *output);

/* Minimalist API */
int parse(FILE *in, FILE *out);
int lex(FILE *in, FILE *out);
int validate(FILE *in, FILE *out);

#endif
