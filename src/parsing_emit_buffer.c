#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "parsing_emit_internal.h"

void parsing_ir_write(const char *format, ...) {
    va_list args;
    va_list args_copy;
    int needed;
    char *grown;

    if (!g_ir) return;
    va_start(args, format);
    if (g_ir->out) {
        vfprintf(g_ir->out, format, args);
        va_end(args);
        return;
    }
    if (!g_ir->buffer) {
        va_end(args);
        return;
    }

    va_copy(args_copy, args);
    needed = vsnprintf(NULL, 0, format, args_copy);
    va_end(args_copy);
    if (needed < 0) {
        va_end(args);
        return;
    }

    if (g_ir->buffer_size + (size_t)needed + 1 >= g_ir->buffer_cap) {
        size_t cap = g_ir->buffer_cap ? g_ir->buffer_cap : 4096;
        while (cap < g_ir->buffer_size + (size_t)needed + 1) cap *= 2;
        grown = (char*)realloc(g_ir->buffer, cap);
        if (!grown) {
            va_end(args);
            return;
        }
        g_ir->buffer = grown;
        g_ir->buffer_cap = cap;
    }

    vsnprintf(g_ir->buffer + g_ir->buffer_size, g_ir->buffer_cap - g_ir->buffer_size, format, args);
    g_ir->buffer_size += (size_t)needed;
    va_end(args);
}

IRBuilder *parsing_ir_builder_new_memory(void) {
    IRBuilder *builder = (IRBuilder*)malloc(sizeof(IRBuilder));
    if (!builder) return NULL;

    builder->out = NULL;
    builder->buffer_cap = 4096;
    builder->buffer = (char*)malloc(builder->buffer_cap);
    builder->buffer_size = 0;
    if (!builder->buffer) {
        free(builder);
        return NULL;
    }
    builder->buffer[0] = '\0';
    return builder;
}

void parsing_ir_builder_free(IRBuilder *builder) {
    if (!builder) return;
    free(builder->buffer);
    free(builder);
}

char *parsing_ir_builder_finalize(const IRBuilder *builder) {
    if (!builder || !builder->buffer) return strdup("");
    return strdup(builder->buffer);
}

char *parsing_ir_escape_scalar_value(const char *value) {
    const char *src = value ? value : "";
    size_t len = strlen(src);
    char *out = (char*)malloc(len * 2 + 1);
    size_t i;
    size_t j = 0;

    if (!out) return strdup("");
    for (i = 0; i < len; i++) {
        out[j++] = (src[i] == '\n' || src[i] == '\r') ? '\\' : src[i];
        if (src[i] == '\n') out[j++] = 'n';
        if (src[i] == '\r') out[j++] = 'r';
    }
    out[j] = '\0';
    return out;
}
