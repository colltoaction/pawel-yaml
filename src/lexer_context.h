#ifndef YAML_LEXER_CONTEXT_H
#define YAML_LEXER_CONTEXT_H

/**
 * LexerContext: Reentrant state for Flex/Bison
 */
typedef struct {
    int indent_stack[100];
    int indent_sp;
    int expecting_value;
    int first_line;
    int last_was_value;
    int at_line_start;
    int complex_key_pending;
    int pending_colon;
    struct {
        char type;
        int indent;
        int leading_empty_max_indent;
        int first_content_seen;
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
    int quoted_value_closed_on_line;
    int semantic_error_count;
    int semantic_indent_tab_count;
    int semantic_indent_mismatch_count;
    int semantic_directive_mid_doc_count;
    int semantic_flow_glue_count;
    int semantic_flow_comma_count;
    int semantic_flow_leading_comma_count;
    int semantic_flow_comment_comma_count;
    int semantic_flow_key_newline_count;
    int semantic_multiline_qkey_count;
    int semantic_inline_key_count;
    int semantic_doc_end_inline_count;
    int semantic_flow_indent_count;
    int open_document_started;
    int yaml_directive_seen;
    /* Categorical Flow State (formerly scanner-local) */
    struct {
        int implicit_key_candidate;
        int delim_stack[100];
        int indent_ref_stack[100];
        int indent_required_stack[100];
        int delim_sp;
        int pending_dedent_count;
    } flow;

    int current_column;
    int argc;
    char **argv;
} LexerContext;

typedef struct {
    int level;
} Indented;

LexerContext *lexer_context_new(void);
void lexer_context_free(LexerContext *ctx);

#endif /* YAML_LEXER_CONTEXT_H */
