#include <stdlib.h>
#include "parsing_emit_internal.h"

void monoid_stream_open(void) {
    /* CT logic */
    parsing_emit_stream_release(&g_stream_store);
    g_current_event_stream = &g_stream_store;
    add_event(EVENT_STREAM_START, NULL, NULL);

    yaml_runtime_reset_artifacts();

    parsing_ir_builder_free(g_ir);
    g_ir = parsing_ir_builder_new_memory();
    parsing_ir_write("+STR\n");
}

void monoid_stream_close(void) {
    char *serialization_tree;

    /* IR logic */
    parsing_ir_write("-STR\n");
    serialization_tree = parsing_ir_builder_finalize(g_ir);
    parsing_ir_builder_free(g_ir);
    g_ir = NULL;
    yaml_runtime_set_serialization_tree(serialization_tree);

    /* CT logic */
    add_event(EVENT_STREAM_END, NULL, NULL);
}

void monoid_doc_open(int explicit_start) {
    /* IR logic */
    parsing_ir_write(explicit_start ? "+DOC ---\n" : "+DOC\n");

    /* CT logic */
    add_event(EVENT_DOCUMENT_START, NULL, NULL);
}

void monoid_doc_close(int explicit_end) {
    /* IR logic */
    parsing_ir_write(explicit_end ? "-DOC ...\n" : "-DOC\n");

    /* CT logic */
    add_event(EVENT_DOCUMENT_END, NULL, NULL);
}

void monoid_doc_open_implicit(void) {
    monoid_doc_open(0);
}

void monoid_doc_open_explicit(void) {
    monoid_doc_open(1);
}

void monoid_doc_close_implicit(void) {
    monoid_doc_close(0);
}

void monoid_doc_close_explicit(void) {
    monoid_doc_close(1);
}
