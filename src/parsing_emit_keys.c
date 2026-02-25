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
    const char *tag;

    if (!k || !k->value) return;
    key = string_intern(k->value);
    anchor = k->anchor ? string_intern(k->anchor) : NULL;
    tag = k->tag ? string_intern(k->tag) : NULL;
    if (!key) key = "";

    if (k->type == '*') {
        ir_alias(key);
        add_alias_event(key);
    } else {
        ir_scalar(key, k->type, anchor, tag);
        add_scalar_event(key, k->type, anchor, tag);
    }
}

ScalarValue parse_anchored_map_key(char *delimited_string) {
    ScalarValue result;
    char *anchor_part = NULL;
    char *tag_part = NULL;
    char *key_part = NULL;
    char *p;

    result.type = ':';
    result.anchor = NULL;
    result.value = NULL;
    result.tag = NULL;

    if (!delimited_string) {
        result.value = string_unit();
        return result;
    }

    /* Expecting formats:
     *   "&anchor\tkey"
     *   "&anchor\ttag\tkey"
     *   "tag\tkey"
     *   "tag\t&anchor\tkey"
     */
    p = strtok(delimited_string, "\t");
    while (p) {
        if (p[0] == '&') {
            anchor_part = p + 1;
        } else if (p[0] == '!') {
            tag_part = p;
        } else {
            key_part = p;
        }
        p = strtok(NULL, "\t");
    }

    if (anchor_part) result.anchor = string_intern(anchor_part);
    if (tag_part) result.tag = string_intern(tag_part);
    if (key_part) result.value = string_intern(key_part);
    
    if (!result.value) result.value = string_unit();
    return result;
}
