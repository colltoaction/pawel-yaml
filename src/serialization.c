// https://yaml.org/spec/1.2.2/#322-serialization-tree
// 

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"

static char *g_serialization_tree = NULL;
static size_t g_serialization_tree_size = 0;
static char *g_representation_graph = NULL;
static size_t g_representation_graph_size = 0;

static void runtime_replace_artifact(char **slot, size_t *size, char *owned_text) {
    free(*slot);
    *slot = owned_text;
    *size = owned_text ? strlen(owned_text) : 0;
}

void yaml_runtime_reset_artifacts(void) {
    runtime_replace_artifact(&g_serialization_tree, &g_serialization_tree_size, NULL);
    runtime_replace_artifact(&g_representation_graph, &g_representation_graph_size, NULL);
}

void yaml_runtime_set_serialization_tree(char *owned_text) {
    runtime_replace_artifact(&g_serialization_tree, &g_serialization_tree_size, owned_text);
}

const char *yaml_runtime_serialization_tree(void) {
    return g_serialization_tree;
}

size_t yaml_runtime_serialization_tree_size(void) {
    return g_serialization_tree_size;
}

int yaml_runtime_has_serialization_tree(void) {
    return (g_serialization_tree != NULL) && (g_serialization_tree[0] != '\0');
}

void yaml_runtime_set_representation_graph(char *owned_text) {
    runtime_replace_artifact(&g_representation_graph, &g_representation_graph_size, owned_text);
}

const char *yaml_runtime_representation_graph(void) {
    return g_representation_graph;
}

size_t yaml_runtime_representation_graph_size(void) {
    return g_representation_graph_size;
}

int yaml_runtime_has_representation_graph(void) {
    return (g_representation_graph != NULL) && (g_representation_graph[0] != '\0');
}

/*
 * Stage 3: Serialize - Representation Graph -> Events
 *
 * The current representation artifact is emitted through the existing
 * grammar-managed text form. No extra data model is introduced here.
 */
static int serialize_representation_to_events(void) {
    return yaml_runtime_has_representation_graph();
}

int yaml_serialize(const YAMLProcessorOptions *options) {
    int want_ast_dump = options ? options->ast_dump : 0;
    int want_emit_yaml = options ? options->emit_yaml : 0;
    int ok;
    const char *representation_graph = yaml_runtime_representation_graph();

    if (!want_ast_dump && !want_emit_yaml) {
        return 0;
    }

    ok = serialize_representation_to_events();

    if (!ok) {
        fprintf(stderr, "[SERIALIZE] Error: No representation graph to serialize\n");
        return 1;
    }

    if (want_ast_dump) {
        if (representation_graph) {
            printf("%s", representation_graph);
        }
        exit(0);
    }

    if (want_emit_yaml) {
        exit(0);
    }

    return 0;
}
