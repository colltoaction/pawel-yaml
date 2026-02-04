/**
 * rml_validator.h - RML Monoidal Layer (Stage 3)
 * 
 * Validates event stream against RML semantic constraints
 * Input: Event stream from Stage 2
 * Output: Validation result (pass/fail) + IR
 */

#ifndef RML_VALIDATOR_H
#define RML_VALIDATOR_H

#include "yaml_event_parser.h"

typedef struct {
    int is_valid;
    const char *error_message;
    int error_line;
    char *intermediate_representation;
} ValidationResult;

/* Initialize RML validator */
int rml_validator_init(void);

/* Validate event stream */
ValidationResult* rml_validate_events(const EventStream *stream);

/* Cleanup */
void rml_validator_cleanup(void);
void validation_result_free(ValidationResult *result);

#endif
