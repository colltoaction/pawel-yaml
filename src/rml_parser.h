/**
 * rml_parser.h - RML Monoidal Language Parser (Stage 3)
 * 
 * Validates EventStream against RML grammar constraints.
 * Implementation moved to rml.y grammar file.
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

/* Stage 3 API */
ValidationResult* rml_parse_event_stream(const EventStream *stream);
void validation_result_free(ValidationResult *result);

#endif
