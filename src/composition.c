#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "event.tab.h"

/**
 * Stage 2: Compose - Serialization Tree -> Representation Graph
 *
 * The serialization tree is parsed by the event grammar (which includes
 * node productions), then validated for composition.
 */

extern EventStream* event_parse_string(const char *input);
extern void event_stream_free(EventStream *stream);

ValidationResult* rml_parse_event_stream(const EventStream *stream) {
    static ValidationResult result;
    static char error_message[] = "Invalid event stream structure";
    const char *serialization_tree = yaml_runtime_serialization_tree();

    result.is_valid = (stream != NULL) && yaml_runtime_has_serialization_tree();
    result.error_message = result.is_valid ? NULL : error_message;
    result.error_line = -1;
    result.intermediate_representation = result.is_valid ? (char*)serialization_tree : NULL;
    return &result;
}

static int compose_validate_serialization_tree(const char *serialization_tree) {
    EventStream *stream;
    ValidationResult *validation;

    stream = event_parse_string(serialization_tree);
    if (!stream) {
        fprintf(stderr, "[COMPOSITION] Error: event grammar rejected serialization tree\n");
        return 1;
    }

    validation = rml_parse_event_stream(stream);
    if (!validation || !validation->is_valid) {
        fprintf(stderr, "[COMPOSITION] Error: %s\n",
                (validation && validation->error_message) ? validation->error_message : "validation failed");
        event_stream_free(stream);
        return 1;
    }

    event_stream_free(stream);
    return 0;
}

int yaml_compose(void) {
    const char *serialization_tree = yaml_runtime_serialization_tree();
    char *representation_graph;

    yaml_runtime_set_representation_graph(NULL);

    if (!serialization_tree || !serialization_tree[0]) {
        /* Allow empty tree for lexer testing phase */
        return 0;
    }

    if (getenv("DEBUG_IR")) {
        printf("[DEBUG_IR]\n%s", serialization_tree);
    }

    if (compose_validate_serialization_tree(serialization_tree) != 0) {
        return 1;
    }

    representation_graph = strdup(serialization_tree);
    if (!representation_graph) {
        fprintf(stderr, "[COMPOSITION] Error: out of memory\n");
        return 1;
    }

    yaml_runtime_set_representation_graph(representation_graph);
    return 0;
}
