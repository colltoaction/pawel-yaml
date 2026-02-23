#include "event.tab.h"

static EventStream stream_store;

extern void *event__scan_string(const char *);
extern void event__delete_buffer(void *);

static int event_parse_accepts(const char *input) {
    int res;
    void *buf = input ? event__scan_string(input) : NULL;

    res = buf ? event_yy_parse() : 1;
    (void)(buf ? (event__delete_buffer(buf), 0) : 0);
    return buf ? (res == 0) : 0;
}

EventStream* event_parse_string(const char *input) {
    return event_parse_accepts(input) ? &stream_store : NULL;
}

void event_stream_free(EventStream *stream) {
    (void)stream;
}
