#ifndef YAML_LEXER_CONTEXT_H
#define YAML_LEXER_CONTEXT_H

/**
 * LexerContext: Reentrant state for Flex/Bison
 */
typedef struct {
    int indent_stack[100];
    int indent_sp;
    int expecting_value;
    int pending_dedents;
    int first_line;
    int last_was_value;
    int at_line_start;
    int complex_key_pending;
    int pending_colon;
    struct {
        char type;
        int indent;
    } block_scalar;
    struct {
        char *content;
        int len;
        int cap;
    } scalar;
    struct {
        int level;
        int is_flow;
        char context_type;
    } indent_context_stack[100];
    int indent_context_sp;
    int scalar_base_indent;
    char scalar_type;
    int argc;
    char **argv;
} LexerContext;

#endif /* YAML_LEXER_CONTEXT_H */
