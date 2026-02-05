#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pipeline.h"
#include "yaml_event_parser.h"

/* Standard Bison parser return codes */
#define YYACCEPT 0
#define YYABORT 1

/* Externs from parsers */
int yaml_stage_parse(FILE *input_stream, char **ir_buf, size_t *ir_size);
extern char *rml_ir_buf;
extern size_t rml_ir_size;

/* Global state for the 3-stage pipeline */
static char *stage1_ir = NULL;
static EventStream *stage2_events = NULL;
static ValidationResult *stage3_result = NULL;

/**
 * Stage 1: YAML Presentation -> RML IR
 */
int parse(FILE *in, FILE *out) {
    if (stage1_ir) return YYACCEPT; /* Already done */

    fprintf(stderr, "Starting parse\n"); fflush(stderr);

    int ret = yaml_stage_parse(in, &rml_ir_buf, &rml_ir_size);
    if (ret != YYACCEPT) {
        return YYABORT;  /* Return error code instead of exiting */
    }
    stage1_ir = rml_ir_buf;
    rml_ir_buf = NULL; /* Move ownership */
    return YYACCEPT;  /* Return success code */
}

/**
 * Stage 2: RML IR -> Event Stream
 */
int lex(FILE *in, FILE *out) {
    if (stage2_events) return YYACCEPT; /* Already done */
    if (!stage1_ir) {
        int ret = parse(in, out);
        if (ret == YYABORT) return YYABORT; /* Depend on parse success */
    }

    fprintf(stderr, "lex called\n");

    yaml_event_parser_init();
    stage2_events = yaml_event_parse_string(stage1_ir);
    yaml_event_parser_cleanup();

    if (!stage2_events) {
        return YYABORT;  /* Return error code instead of exiting */
    }
    return YYACCEPT;  /* Return success code */
}

/**
 * Stage 3: Event Stream -> Validation & Canonical Output
 */
int validate(FILE *in, FILE *out) {
    if (stage3_result) return YYACCEPT; /* Already done */
    if (!stage2_events) {
        int ret = lex(in, out);
        if (ret == YYABORT) return YYABORT;  /* Depend on lex success */
    }

    stage3_result = rml_parse_event_stream(stage2_events);
    
    if (stage3_result && stage3_result->is_valid) {
        if (stage3_result->intermediate_representation) {
            fprintf(out, "%s", stage3_result->intermediate_representation);
        }
        return YYACCEPT;  /* Return success code */
    } else {
        if (stage3_result && stage3_result->error_message) {
            fprintf(stderr, "Validation error: %s\n", stage3_result->error_message);
        }
        return YYABORT;  /* Return error code instead of exiting */
    }
}

/* Pipeline runner helper */
int yaml_pipeline_run(FILE *input, FILE *output) {
    validate(input, output);
    return 0;
}
