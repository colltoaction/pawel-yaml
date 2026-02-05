#ifndef PIPELINE_H
#define PIPELINE_H

#include <stdio.h>

/**
 * Bison-style return codes for pipeline stages
 * Matches standard Bison parser return conventions
 */
typedef enum {
    PARSER_SUCCESS = 0,        /* Parse succeeded (YYACCEPT) */
    PARSER_ERROR = 1,          /* Parse failed (YYABORT) */
    PARSER_MEMORY_ERROR = 2    /* Memory exhaustion */
} parser_status_code_t;

/**
 * Pawel-YAML 3-Stage Pipeline
 */
int yaml_pipeline_run(FILE *input, FILE *output);

/* Minimalist API */
int parse(FILE *in, FILE *out);
int lex(FILE *in, FILE *out);
int validate(FILE *in, FILE *out);

#endif
