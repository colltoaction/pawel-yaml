/**
 * rml_validator.c - RML Monoidal Layer (Stage 3)
 * 
 * Validates YAML event streams against RML semantic constraints.
 * RML (Rational Monoidal Language) enforces:
 * - Proper nesting of structures (sequences, mappings)
 * - Valid scalar encoding (quote styles)
 * - Anchor/alias consistency
 * - Document boundaries
 */

#include <stdlib.h>
#include <string.h>
#include "rml_validator.h"

/* Validator state */
static struct {
    int initialized;
    int depth;  /* Track nesting depth */
} validator_state = {0, 0};

/**
 * rml_validator_init - Initialize validator
 * Returns: 0 on success, -1 on error
 */
int rml_validator_init(void) {
    validator_state.initialized = 1;
    validator_state.depth = 0;
    return 0;
}

/**
 * rml_validator_cleanup - Cleanup validator
 */
void rml_validator_cleanup(void) {
    validator_state.initialized = 0;
    validator_state.depth = 0;
}

/**
 * validation_result_free - Free validation result
 */
void validation_result_free(ValidationResult *result) {
    if (!result) return;
    if (result->intermediate_representation) {
        free(result->intermediate_representation);
    }
    free(result);
}

/**
 * Helper: Validate event type sequence
 * Allows implicit documents (scalars without explicit +DOC/-DOC)
 * Returns: 0 if valid, -1 if invalid
 */
static int validate_nesting(const EventStream *stream) {
    int depth = 0;  /* Stream nesting depth */
    int collection_depth = 0;  /* Sequences/mappings depth */
    
    for (int i = 0; i < stream->count; i++) {
        YAMLEvent *evt = stream->events[i];
        
        switch (evt->type) {
        case EVENT_STREAM_START:
            if (i != 0) return -1;  /* Must be first */
            depth++;
            break;
            
        case EVENT_STREAM_END:
            if (depth != 1 || collection_depth != 0) return -1;
            depth--;
            break;
            
        case EVENT_DOCUMENT_START:
            depth++;
            break;
            
        case EVENT_DOCUMENT_END:
            depth--;
            if (depth < 1) return -1;
            break;
            
        case EVENT_SEQUENCE_START:
            collection_depth++;
            break;
            
        case EVENT_SEQUENCE_END:
            collection_depth--;
            if (collection_depth < 0) return -1;
            break;
            
        case EVENT_MAPPING_START:
            collection_depth++;
            break;
            
        case EVENT_MAPPING_END:
            collection_depth--;
            if (collection_depth < 0) return -1;
            break;
            
        case EVENT_SCALAR:
            /* Scalars valid at stream level (implicit doc) or inside collections */
            break;
            
        case EVENT_ALIAS:
            break;
            
        default:
            return -1;
        }
    }
    
    /* Valid end state: stream closed (0), no open collections */
    return (depth == 0 && collection_depth == 0) ? 0 : -1;
}

/**
 * Helper: Validate scalar encodings
 * Returns: 0 if valid, -1 if invalid
 */
static int validate_scalars(const EventStream *stream) {
    for (int i = 0; i < stream->count; i++) {
        YAMLEvent *evt = stream->events[i];
        
        if (evt->type != EVENT_SCALAR) continue;
        
        if (!evt->value) return -1;  /* Scalar must have value */
        
        /* Validate quote style */
        if (evt->quote_style != ':' && evt->quote_style != '"' && 
            evt->quote_style != '\'' && evt->quote_style != '|' && 
            evt->quote_style != '>') {
            return -1;
        }
    }
    
    return 0;
}

/**
 * Helper: Generate intermediate representation from event stream
 * Allocates string, caller must free
 */
static char* generate_ir(const EventStream *stream) {
    char *ir = (char*)malloc(4096);
    if (!ir) return NULL;
    
    ir[0] = '\0';
    int pos = 0;
    
    for (int i = 0; i < stream->count && pos < 4090; i++) {
        YAMLEvent *evt = stream->events[i];
        int written = 0;
        
        switch (evt->type) {
        case EVENT_STREAM_START:
            written = snprintf(ir + pos, 4090 - pos, "+STR\n");
            break;
        case EVENT_STREAM_END:
            written = snprintf(ir + pos, 4090 - pos, "-STR\n");
            break;
        case EVENT_DOCUMENT_START:
            written = snprintf(ir + pos, 4090 - pos, "+DOC\n");
            break;
        case EVENT_DOCUMENT_END:
            written = snprintf(ir + pos, 4090 - pos, "-DOC\n");
            break;
        case EVENT_SEQUENCE_START:
            written = snprintf(ir + pos, 4090 - pos, "+SEQ\n");
            break;
        case EVENT_SEQUENCE_END:
            written = snprintf(ir + pos, 4090 - pos, "-SEQ\n");
            break;
        case EVENT_MAPPING_START:
            written = snprintf(ir + pos, 4090 - pos, "+MAP\n");
            break;
        case EVENT_MAPPING_END:
            written = snprintf(ir + pos, 4090 - pos, "-MAP\n");
            break;
        case EVENT_SCALAR:
            if (evt->value) {
                written = snprintf(ir + pos, 4090 - pos, "=VAL %c:%s\n", 
                                 evt->quote_style, evt->value);
            }
            break;
        case EVENT_ALIAS:
            if (evt->alias_name) {
                written = snprintf(ir + pos, 4090 - pos, "=ALI *%s\n", 
                                 evt->alias_name);
            }
            break;
        }
        
        if (written > 0) pos += written;
    }
    
    return ir;
}

/**
 * rml_validate_events - Validate event stream
 * 
 * Returns: Pointer to ValidationResult (caller must free)
 * Sets is_valid=1 if stream is valid, error_message if invalid
 */
ValidationResult* rml_validate_events(const EventStream *stream) {
    ValidationResult *result = (ValidationResult*)malloc(sizeof(ValidationResult));
    if (!result) return NULL;
    
    result->is_valid = 1;
    result->error_message = NULL;
    result->error_line = -1;
    result->intermediate_representation = NULL;
    
    if (!stream || stream->count == 0) {
        result->is_valid = 0;
        result->error_message = "Empty event stream";
        return result;
    }
    
    /* Check stream boundaries */
    if (stream->events[0]->type != EVENT_STREAM_START) {
        result->is_valid = 0;
        result->error_message = "Stream must start with +STR";
        return result;
    }
    
    if (stream->events[stream->count - 1]->type != EVENT_STREAM_END) {
        result->is_valid = 0;
        result->error_message = "Stream must end with -STR";
        return result;
    }
    
    /* Allow implicit documents (scalars without explicit +DOC) */
    /* Validate nesting */
    if (validate_nesting(stream) != 0) {
        result->is_valid = 0;
        result->error_message = "Invalid nesting structure";
        return result;
    }
    
    /* Validate scalars */
    if (validate_scalars(stream) != 0) {
        result->is_valid = 0;
        result->error_message = "Invalid scalar encoding";
        return result;
    }
    
    /* Generate IR */
    result->intermediate_representation = generate_ir(stream);
    
    return result;
}
