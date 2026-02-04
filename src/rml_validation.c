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

/* Event validation state machine */
typedef enum {
    STATE_START,           /* Expecting +STR */
    STATE_IN_STREAM,       /* After +STR, before -STR */
    STATE_IN_DOCUMENT,     /* After +DOC, before -DOC */
    STATE_IN_COLLECTION,   /* Inside SEQ or MAP */
    STATE_END,             /* After -STR */
    STATE_ERROR            /* Invalid state */
} EventState;

/* Get event type name for error messages */
static const char* event_type_name(YAMLEventType type) {
    switch (type) {
        case EVENT_STREAM_START: return "+STR";
        case EVENT_STREAM_END: return "-STR";
        case EVENT_DOCUMENT_START: return "+DOC";
        case EVENT_DOCUMENT_END: return "-DOC";
        case EVENT_SEQUENCE_START: return "+SEQ";
        case EVENT_SEQUENCE_END: return "-SEQ";
        case EVENT_MAPPING_START: return "+MAP";
        case EVENT_MAPPING_END: return "-MAP";
        case EVENT_SCALAR: return "=VAL";
        case EVENT_ALIAS: return "=ALI";
        default: return "UNKNOWN";
    }
}

/* Generate helpful error hint based on context */
static const char* suggest_fix(YAMLEvent *evt, EventState state, int depth) {
    if (!evt) return "";
    
    switch (evt->type) {
        case EVENT_SCALAR:
            if (evt->value && strlen(evt->value) > 80) {
                return "Hint: Try using | for multiline scalars";
            }
            break;
        case EVENT_MAPPING_END:
        case EVENT_SEQUENCE_END:
            if (depth < 0) {
                return "Hint: Check for missing collection start marker";
            }
            break;
        case EVENT_STREAM_END:
            if (depth != 0) {
                return "Hint: Missing collection end markers before stream end";
            }
            break;
        default:
            break;
    }
    return "";
}

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
    result->error_message = malloc(512);
    result->error_line = -1;
    result->intermediate_representation = NULL;
    
    if (!stream || stream->count == 0) {
        snprintf(result->error_message, 512, "Validation error: Empty event stream");
        return result;
    }
    
    /* Stream boundary: must start with STR_START, end with STR_END */
    if (stream->events[0]->type != EVENT_STREAM_START) {
        snprintf(result->error_message, 512, 
                "Validation error: Expected +STR at start, got %s\nHint: Stream must begin with stream start marker",
                event_type_name(stream->events[0]->type));
        return result;
    }
    
    if (stream->events[stream->count - 1]->type != EVENT_STREAM_END) {
        snprintf(result->error_message, 512,
                "Validation error: Expected -STR at end, got %s\nHint: Stream must end with stream end marker",
                event_type_name(stream->events[stream->count - 1]->type));
        return result;
    }
    
    /* Validate structure with state machine */
    EventState state = STATE_IN_STREAM;
    int collection_depth = 0;
    int document_depth = 0;
    
    for (int i = 1; i < stream->count - 1; i++) {
        YAMLEvent *evt = stream->events[i];
        const char *hint = "";
        
        switch (evt->type) {
        case EVENT_DOCUMENT_START:
            document_depth++;
            state = STATE_IN_DOCUMENT;
            break;
            
        case EVENT_DOCUMENT_END:
            document_depth--;
            if (document_depth < 0) {
                snprintf(result->error_message, 512,
                        "Validation error: Unmatched document end at position %d\nHint: Missing +DOC before -DOC", i);
                return result;
            }
            state = STATE_IN_STREAM;
            break;
            
        case EVENT_SEQUENCE_START:
        case EVENT_MAPPING_START:
            collection_depth++;
            state = STATE_IN_COLLECTION;
            break;
            
        case EVENT_SEQUENCE_END:
        case EVENT_MAPPING_END:
            collection_depth--;
            if (collection_depth < 0) {
                hint = suggest_fix(evt, state, collection_depth);
                snprintf(result->error_message, 512,
                        "Validation error: Unmatched %s at position %d\n%s",
                        event_type_name(evt->type), i, hint);
                return result;
            }
            if (collection_depth == 0) {
                state = document_depth > 0 ? STATE_IN_DOCUMENT : STATE_IN_STREAM;
            }
            break;
            
        case EVENT_SCALAR:
            if (!evt->value) {
                snprintf(result->error_message, 512,
                        "Validation error: Scalar at position %d must have value", i);
                return result;
            }
            break;
            
        case EVENT_ALIAS:
            if (!evt->alias_name) {
                snprintf(result->error_message, 512,
                        "Validation error: Alias at position %d must have name", i);
                return result;
            }
            break;
            
        default:
            break;
        }
    }
    
    /* All collections must be properly closed */
    if (collection_depth != 0) {
        const char *hint = suggest_fix(NULL, state, collection_depth);
        snprintf(result->error_message, 512,
                "Validation error: %d unclosed collection(s) at stream end\n%s",
                collection_depth, hint);
        return result;
    }
    
    if (document_depth != 0) {
        snprintf(result->error_message, 512,
                "Validation error: %d unclosed document(s) at stream end", document_depth);
        return result;
    }
    
    /* Stream is valid RML */
    result->is_valid = 1;
    if (result->error_message) {
        free(result->error_message);
    }
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
    if (result->error_message && result->error_message != (char*)"Parse failed") {
        free((void*)result->error_message);
    }
    free(result);
}
