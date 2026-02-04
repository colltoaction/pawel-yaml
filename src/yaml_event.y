%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/**
 * YAML Event Stream (Test-Suite Canonical Format)
 * 
 * RED Phase: Hardcoded C logic (no grammar yet)
 * 
 * Represents canonical event stream from YAML test suite:
 * - Stream: +STR, -STR
 * - Documents: +DOC, -DOC
 * - Collections: +SEQ, -SEQ, +MAP, -MAP
 * - Scalars: =VAL [quote]:[content]
 * - Aliases: =ALI *name
 */

typedef enum {
    EVENT_STREAM_START,
    EVENT_STREAM_END,
    EVENT_DOCUMENT_START,
    EVENT_DOCUMENT_END,
    EVENT_SEQUENCE_START,
    EVENT_SEQUENCE_END,
    EVENT_MAPPING_START,
    EVENT_MAPPING_END,
    EVENT_SCALAR,
    EVENT_ALIAS,
} EventType;

typedef struct {
    EventType type;
    char quote_style;        /* ':' plain, '"' double, '\'' single, '|' literal, '>' folded */
    char *value;
    char *anchor;
    char *tag;
    int explicit_start;
    char *alias_name;
} YAMLEvent;

/* Constructor helpers */
YAMLEvent *event_create(EventType type) {
    YAMLEvent *e = (YAMLEvent *)malloc(sizeof(YAMLEvent));
    if (!e) return NULL;
    e->type = type;
    e->quote_style = '\0';
    e->value = NULL;
    e->anchor = NULL;
    e->tag = NULL;
    e->explicit_start = 0;
    e->alias_name = NULL;
    return e;
}

YAMLEvent *event_scalar_new(char quote, const char *value) {
    YAMLEvent *e = event_create(EVENT_SCALAR);
    if (!e) return NULL;
    e->quote_style = quote;
    e->value = value ? strdup(value) : NULL;
    return e;
}

YAMLEvent *event_collection_new(EventType type, const char *anchor, const char *tag) {
    YAMLEvent *e = event_create(type);
    if (!e) return NULL;
    e->anchor = anchor ? strdup(anchor) : NULL;
    e->tag = tag ? strdup(tag) : NULL;
    return e;
}

YAMLEvent *event_doc_new(int explicit) {
    YAMLEvent *e = event_create(EVENT_DOCUMENT_START);
    if (!e) return NULL;
    e->explicit_start = explicit;
    return e;
}

YAMLEvent *event_alias_new(const char *name) {
    YAMLEvent *e = event_create(EVENT_ALIAS);
    if (!e) return NULL;
    e->alias_name = name ? strdup(name) : NULL;
    return e;
}

void event_free(YAMLEvent *e) {
    if (!e) return;
    free(e->value);
    free(e->anchor);
    free(e->tag);
    free(e->alias_name);
    free(e);
}

void event_print(FILE *out, const YAMLEvent *e) {
    if (!e) return;
    
    switch (e->type) {
        case EVENT_STREAM_START:
            fprintf(out, "+STR\n");
            break;
        case EVENT_STREAM_END:
            fprintf(out, "-STR\n");
            break;
        case EVENT_DOCUMENT_START:
            if (e->explicit_start)
                fprintf(out, "+DOC ---\n");
            else
                fprintf(out, "+DOC\n");
            break;
        case EVENT_DOCUMENT_END:
            fprintf(out, "-DOC\n");
            break;
        case EVENT_SEQUENCE_START:
            fprintf(out, "+SEQ");
            if (e->anchor) fprintf(out, " &%s", e->anchor);
            if (e->tag) fprintf(out, " <%s>", e->tag);
            fprintf(out, "\n");
            break;
        case EVENT_SEQUENCE_END:
            fprintf(out, "-SEQ\n");
            break;
        case EVENT_MAPPING_START:
            fprintf(out, "+MAP");
            if (e->anchor) fprintf(out, " &%s", e->anchor);
            if (e->tag) fprintf(out, " <%s>", e->tag);
            fprintf(out, "\n");
            break;
        case EVENT_MAPPING_END:
            fprintf(out, "-MAP\n");
            break;
        case EVENT_SCALAR:
            fprintf(out, "=VAL %c:%s\n", e->quote_style, e->value ? e->value : "");
            break;
        case EVENT_ALIAS:
            fprintf(out, "=ALI *%s\n", e->alias_name ? e->alias_name : "");
            break;
    }
}
%}

%%
/* Placeholder for grammar - to be added in GREEN phase */
start : { }
      ;
%%
