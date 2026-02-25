#include <stdlib.h>
#include <string.h>
#include "parsing_emit_internal.h"

FILE *yyout = NULL;

IRBuilder *g_ir = NULL;
EventStream g_stream_store;
EventStream *g_current_event_stream = NULL;

static YAMLEvent *new_event(YAMLEventType type) {
    YAMLEvent *evt = (YAMLEvent*)malloc(sizeof(YAMLEvent));
    if (!evt) return NULL;
    memset(evt, 0, sizeof(YAMLEvent));
    evt->type = type;
    return evt;
}

void parsing_emit_free_event(YAMLEvent *evt) {
    if (!evt) return;
    free(evt->value);
    free(evt->anchor);
    free(evt->tag);
    free(evt->alias_name);
    free(evt);
}

void parsing_emit_stream_release(EventStream *stream) {
    int i;

    if (!stream) return;
    for (i = 0; i < stream->count; i++) {
        parsing_emit_free_event(stream->events[i]);
    }
    free(stream->events);
    stream->events = NULL;
    stream->count = 0;
    stream->capacity = 0;
}

static int ensure_event_capacity(EventStream *stream) {
    YAMLEvent **grown;
    int new_capacity;

    if (!stream) return 0;
    if (stream->count < stream->capacity) return 1;

    new_capacity = stream->capacity > 0 ? stream->capacity * 2 : 64;
    grown = (YAMLEvent**)realloc(stream->events, (size_t)new_capacity * sizeof(YAMLEvent*));
    if (!grown) return 0;

    stream->events = grown;
    stream->capacity = new_capacity;
    return 1;
}

void parsing_emit_append_event(YAMLEvent *evt) {
    if (!evt) return;
    if (!g_current_event_stream) {
        parsing_emit_free_event(evt);
        return;
    }
    if (!ensure_event_capacity(g_current_event_stream)) {
        parsing_emit_free_event(evt);
        return;
    }
    g_current_event_stream->events[g_current_event_stream->count++] = evt;
}

void add_event(YAMLEventType type, const char *anchor, const char *tag) {
    YAMLEvent *evt = new_event(type);
    if (!evt) return;
    if (anchor) evt->anchor = strdup(anchor);
    if (tag) evt->tag = strdup(tag);
    parsing_emit_append_event(evt);
}

void add_scalar_event(const char *value, char quote_style, const char *anchor, const char *tag) {
    YAMLEvent *evt;

    if (!value) return;
    evt = new_event(EVENT_SCALAR);
    if (!evt) return;
    evt->quote_style = quote_style;
    evt->value = strdup(value);
    if (anchor) evt->anchor = strdup(anchor);
    if (tag) evt->tag = strdup(tag);
    parsing_emit_append_event(evt);
}

void add_alias_event(const char *name) {
    YAMLEvent *evt;

    if (!name) return;
    evt = new_event(EVENT_ALIAS);
    if (!evt) return;
    evt->alias_name = strdup(name);
    parsing_emit_append_event(evt);
}
