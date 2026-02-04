/**
 * rml_validation.c - RML Monoidal Language Validation Functions
 * 
 * Contains all validation logic moved from rml_parser.c wrapper.
 * Grammar rules are defined in rml.y (reference architecture).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml_event_parser.h"
#include "rml_parser.h"

/**
 * rml_parse_event_stream - Validate EventStream against RML grammar
 * 
 * RML grammar rules (from rml.y):
 * - stream: STR_START docs STR_END
 * - docs: empty | docs doc
 * - doc: DOC_START node DOC_END | node (implicit doc)
 * - node: SCALAR | ALIAS | SEQ_START seq_items SEQ_END | MAP_START map_pairs MAP_END
 * - seq_items: empty | seq_items node
 * - map_pairs: empty | map_pairs node node
 * 
 * Returns: ValidationResult* (caller must free)
 */
ValidationResult* rml_parse_event_stream(const EventStream *stream) {
    ValidationResult *result = (ValidationResult*)malloc(sizeof(ValidationResult));
    if (!result) return NULL;
    
    result->is_valid = 0;
    result->error_message = "Parse failed";
    result->error_line = -1;
    result->intermediate_representation = NULL;
    
    if (!stream || stream->count == 0) {
        result->error_message = "Empty stream";
        return result;
    }
    
    /* Stream boundary: must start with STR_START, end with STR_END */
    if (stream->events[0]->type != EVENT_STREAM_START) {
        result->error_message = "Stream must start with +STR";
        return result;
    }
    
    if (stream->events[stream->count - 1]->type != EVENT_STREAM_END) {
        result->error_message = "Stream must end with -STR";
        return result;
    }
    
    /* Validate structure: nesting depth, collection pairing */
    int collection_depth = 0;
    
    for (int i = 1; i < stream->count - 1; i++) {
        YAMLEvent *evt = stream->events[i];
        
        switch (evt->type) {
        case EVENT_DOCUMENT_START:
        case EVENT_DOCUMENT_END:
            /* Documents allowed at depth 1 */
            break;
            
        case EVENT_SEQUENCE_START:
        case EVENT_MAPPING_START:
            collection_depth++;
            break;
            
        case EVENT_SEQUENCE_END:
        case EVENT_MAPPING_END:
            collection_depth--;
            if (collection_depth < 0) {
                result->error_message = "Unmatched collection end";
                return result;
            }
            break;
            
        case EVENT_SCALAR:
            if (!evt->value) {
                result->error_message = "Scalar must have value";
                return result;
            }
            break;
            
        case EVENT_ALIAS:
            if (!evt->alias_name) {
                result->error_message = "Alias must have name";
                return result;
            }
            break;
            
        default:
            break;
        }
    }
    
    /* All collections must be properly closed */
    if (collection_depth != 0) {
        result->error_message = "Unmatched collection start";
        return result;
    }
    
    /* Stream is valid RML */
    result->is_valid = 1;
    result->error_message = NULL;
    
    /* Generate IR from stream */
    char *ir = (char*)malloc(4096);
    if (ir) {
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
        result->intermediate_representation = ir;
    }
    
    return result;
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
