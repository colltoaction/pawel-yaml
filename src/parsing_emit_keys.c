#include <string.h>
#include "parsing_emit_internal.h"

extern char *string_intern(const char *input);
extern char *string_unit(void);
extern char *string_intern_slice(const char *start, size_t len);

ScalarValue parse_plain_map_key(char *value) {
    ScalarValue result;

    result.type = ':';
    result.anchor = NULL;
    result.tag = NULL;
    result.value = value ? string_intern(value) : string_unit();
    if (!result.value) result.value = string_unit();
    return result;
}

void emit_map_key(const ScalarValue *k) {
    const char *key;
    const char *anchor;

    if (!k || !k->value) return;
    key = string_intern(k->value);
    anchor = k->anchor ? string_intern(k->anchor) : NULL;
    if (!key) key = "";

    if (k->type == '*') {
        ir_alias(key);
        add_alias_event(key);
    } else {
        ir_scalar(key, k->type, anchor, k->tag);
        add_scalar_event(key, k->type);
    }
}

ScalarValue parse_anchored_map_key(char *delimited_string) {
    ScalarValue result;
    const char *anchor_start;
    const char *tab;

    result.type = ':';
    result.anchor = NULL;
    result.value = NULL;
    result.tag = NULL;

    if (!delimited_string) {
        result.value = string_unit();
        return result;
    }

    tab = strchr(delimited_string, '\t');
    if (tab) {
        anchor_start = delimited_string;
        if (anchor_start[0] == '&') anchor_start++;
        result.anchor = string_intern_slice(anchor_start, (size_t)(tab - anchor_start));
        result.value = string_intern(tab + 1);
    } else {
        result.value = string_intern(delimited_string);
    }

    if (!result.value) result.value = string_unit();
    return result;
}
