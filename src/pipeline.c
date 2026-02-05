#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pipeline.h"
#include "yaml_event_parser.h"
#include "rml_parser.h"

/* Stage 1 API (defined in yaml.y) */
int yaml_stage_parse(FILE *input_stream, char **ir_buf, size_t *ir_size);
extern char *rml_ir_buf;
extern size_t rml_ir_size;

/**
 * 3-Stage Pipeline implementation
 */
int yaml_pipeline_run(FILE *input, FILE *output) {
    int ret = yaml_stage_parse(input, &rml_ir_buf, &rml_ir_size);
    if (ret != 0) return 1;
    if (!rml_ir_buf || strlen(rml_ir_buf) == 0) return 0;

    yaml_event_parser_init();
    EventStream *events = yaml_event_parse_string(rml_ir_buf);
    yaml_event_parser_cleanup();
    
    if (!events) {
        if (rml_ir_buf) { free(rml_ir_buf); rml_ir_buf = NULL; }
        return 1;
    }

    ValidationResult *result = rml_parse_event_stream(events);
    int exit_code = 0;
    
    if (result && result->is_valid) {
        if (result->intermediate_representation) {
            fprintf(output, "%s", result->intermediate_representation);
        }
    } else {
        if (result && result->error_message) {
            fprintf(stderr, "Validation error: %s\n", result->error_message);
        }
        exit_code = 1;
    }
    
    event_stream_free(events);
    validation_result_free(result);
    free(rml_ir_buf);
    rml_ir_buf = NULL;
    
    return exit_code;
}

/* User-requested minimal style functions */
void parse(FILE *in, FILE *out) {
    yaml_pipeline_run(in, out);
}

void lex(FILE *in, FILE *out) {
    /* Presentation layer IR only */
    if (yaml_stage_parse(in, &rml_ir_buf, &rml_ir_size) == 0) {
        if (rml_ir_buf) {
            fprintf(out, "%s", rml_ir_buf);
            free(rml_ir_buf);
            rml_ir_buf = NULL;
        }
    }
}

void validate(FILE *in, FILE *out) {
    /* Stage 3 only (simulated by full pipeline for now) */
    parse(in, out);
}
