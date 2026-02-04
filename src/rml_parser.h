/**
 * rml_parser.h - RML Parser API
 * 
 * Public interface for RML validation via Bison grammar.
 */

#ifndef RML_PARSER_H
#define RML_PARSER_H

#include "yaml_event_parser.h"

typedef struct {
    int is_valid;
    char *error_message;
    int error_line;
    char *intermediate_representation;
} ValidationResult;

/**
 * rml_parse_event_stream - Validate EventStream against RML grammar
 * Returns: ValidationResult* (caller must free)
 */
ValidationResult* rml_parse_event_stream(const EventStream *stream);

/**
 * validation_result_free - Free ValidationResult
 */
void validation_result_free(ValidationResult *result);

#endif /* RML_PARSER_H */
