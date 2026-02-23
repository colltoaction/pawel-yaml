#include <stdlib.h>
#include "parsing_emit_internal.h"

void parsing_ir_write_tag(const char *tag) {
    if (!tag || !*tag) return;
    parsing_ir_write((tag[0] == '!' || tag[0] == '<') ? " %s" : " !%s", tag);
}

void ir_seq_start(const char *anchor, const char *tag, const char *marker) {
    parsing_ir_write("+SEQ");
    if (marker) parsing_ir_write(" %s", marker);
    if (anchor) parsing_ir_write(" &%s", anchor[0] == '&' ? anchor + 1 : anchor);
    parsing_ir_write_tag(tag);
    parsing_ir_write("\n");
}

void ir_seq_end(void) {
    parsing_ir_write("-SEQ\n");
}

void ir_map_start(const char *anchor, const char *tag, const char *marker) {
    parsing_ir_write("+MAP");
    if (marker) parsing_ir_write(" %s", marker);
    if (anchor) parsing_ir_write(" &%s", anchor[0] == '&' ? anchor + 1 : anchor);
    parsing_ir_write_tag(tag);
    parsing_ir_write("\n");
}

void ir_map_end(void) {
    parsing_ir_write("-MAP\n");
}

void ir_scalar(const char *value, char style, const char *anchor, const char *tag) {
    char *escaped = parsing_ir_escape_scalar_value(value);

    parsing_ir_write("=VAL");
    if (anchor) parsing_ir_write(" &%s", anchor[0] == '&' ? anchor + 1 : anchor);
    parsing_ir_write_tag(tag);
    if (style == ':') parsing_ir_write(" :%s\n", escaped);
    if (style != ':') parsing_ir_write(" %c%s\n", style, escaped);
    free(escaped);
}

void ir_scalar_empty(void) {
    parsing_ir_write("=VAL :\n");
}

void ir_alias(const char *name) {
    const char *alias = name ? name : "";
    parsing_ir_write("=ALI *%s\n", alias[0] == '*' ? alias + 1 : alias);
}
