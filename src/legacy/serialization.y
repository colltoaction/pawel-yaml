%code requires {
/* === TYPE DEFINITIONS (from common.h) === */
/**
 * Node properties structure for anchor/tag pairs
 */
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;

/**
 * Stable Event Types (Alphabet for all stages)
 */
typedef enum {
    EVENT_STREAM_START = 300,
    EVENT_STREAM_END,
    EVENT_DOCUMENT_START,
    EVENT_DOCUMENT_END,
    EVENT_SEQUENCE_START,
    EVENT_SEQUENCE_END,
    EVENT_MAPPING_START,
    EVENT_MAPPING_END,
    EVENT_SCALAR,
    EVENT_ALIAS,
} YAMLEventType;
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* === TYPE DEFINITIONS (from ir_builder.h) === */
/**
 * IRBuilder: Encapsulates output destination for RML IR
 */
typedef struct {
    FILE *out;              /* Output stream for IR (file mode) */
    char *buffer;           /* Internal buffer (memory mode) */
    size_t buffer_size;     /* Current buffer size */
    size_t buffer_cap;      /* Buffer capacity */
} IRBuilder;

/* Forward declarations */
void serialization_yy_error(const char *msg);

/* Placeholder for IR traversal and event generation */
typedef struct {
    IRBuilder *ir;
    int event_count;
} SerializationContext;

%}

%define api.prefix {serialization_yy_}

%union {
    char *string;
    int integer;
}

%%

/* 
 * DUMP Serialization Stage (IR -> Events)
 * 
 * This stage traverses the internal representation (IR) 
 * and generates a stream of YAML events that can be 
 * serialized back to text by the presentation stage.
 * 
 * Current status: Stub implementation
 * TODO: Implement IR traversal and event generation
 */

start: /* empty */ { 
    /* Placeholder for IR to events serialization */ 
}
;

%%

/**
 * Initialize serialization stage
 * 
 * @param ir The internal representation (IR) to serialize
 * @return 0 on success, non-zero on failure
 */
int yaml_serialize(void *ir) {
    /* Placeholder: convert IR to event stream */
    fprintf(stderr, "Serialization stage placeholder\n");
    return 0;
}

/* Error handler for serialization stage */
void serialization_yy_error(const char *msg) {
    fprintf(stderr, "Serialization error: %s\n", msg);
}
