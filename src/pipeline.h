/**
 * pipeline.h - Three-Stage Parser Pipeline Orchestrator
 * 
 * Coordinates the flow of data through all three parsing stages:
 * 1. YAML Presentation (yaml_parser.h)
 * 2. YAML Events (yaml_event_parser.h)
 * 3. RML Validation (rml_validator.h)
 */

#ifndef PIPELINE_H
#define PIPELINE_H

#include <stdio.h>
#include "yaml_event_parser.h"
#include "rml_validator.h"

typedef struct {
    EventStream *events;           /* Output from Stage 2 */
    ValidationResult *validation;  /* Output from Stage 3 */
    int exit_code;                 /* Final pipeline result */
} PipelineOutput;

/* Execute full three-stage pipeline on file descriptor */
PipelineOutput* pipeline_process_file(FILE *input);

/* Cleanup pipeline output */
void pipeline_output_free(PipelineOutput *output);

#endif
