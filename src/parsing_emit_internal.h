#ifndef PARSING_EMIT_INTERNAL_H
#define PARSING_EMIT_INTERNAL_H

#include <stdio.h>
#include "stream.tab.h"

typedef struct {
    FILE *out;
    char *buffer;
    size_t buffer_size;
    size_t buffer_cap;
} IRBuilder;

extern FILE *yyout;

extern IRBuilder *g_ir;
extern EventStream g_stream_store;
extern EventStream *g_current_event_stream;

void parsing_emit_free_event(YAMLEvent *evt);
void parsing_emit_stream_release(EventStream *stream);
void parsing_emit_append_event(YAMLEvent *evt);

void add_event(YAMLEventType type);
void add_scalar_event(const char *value, char quote_style);
void add_alias_event(const char *name);

void parsing_ir_write(const char *format, ...);
IRBuilder *parsing_ir_builder_new_memory(void);
void parsing_ir_builder_free(IRBuilder *builder);
char *parsing_ir_builder_finalize(const IRBuilder *builder);
char *parsing_ir_escape_scalar_value(const char *value);
void parsing_ir_write_tag(const char *tag);

void ir_scalar(const char *value, char style, const char *anchor, const char *tag);
void ir_alias(const char *name);
ScalarValue parse_plain_map_key(char *value);

void monoid_ir_stream_open(void);
void monoid_ir_stream_close(void);
void monoid_ir_doc_open(int explicit_start);
void monoid_ir_doc_close(int explicit_end);

void monoid_ct_stream_open(void);
void monoid_ct_stream_close(void);
void monoid_ct_doc_open(int explicit_start);
void monoid_ct_doc_close(int explicit_end);

void monoid_stream_open(void);
void monoid_stream_close(void);
void monoid_doc_open(int explicit_start);
void monoid_doc_close(int explicit_end);
void monoid_doc_open_implicit(void);
void monoid_doc_open_explicit(void);
void monoid_doc_close_implicit(void);
void monoid_doc_close_explicit(void);

#endif
