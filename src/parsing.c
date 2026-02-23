#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "lexer_context.h"

extern int yaml_parse_internal(const char *input, int parse_only);

LexerContext *lexer_context_new(void) {
    LexerContext *ctx = (LexerContext*)malloc(sizeof(LexerContext));
    if (!ctx) return NULL;

    memset(ctx, 0, sizeof(*ctx));
    ctx->indent_stack[0] = 0;
    ctx->indent_sp = 0;
    ctx->expecting_value = 0;
    ctx->yaml_directive_seen = 0;
    ctx->current_column = 0;
    ctx->first_line = 1;
    ctx->last_was_value = 0;
    ctx->at_line_start = 1;
    ctx->complex_key_pending = 0;
    ctx->pending_colon = 0;
    ctx->block_scalar.type = '\0';
    ctx->block_scalar.indent = -1;
    ctx->block_scalar.leading_empty_max_indent = 0;
    ctx->block_scalar.first_content_seen = 0;
    ctx->scalar.content = (char*)malloc(1024);
    ctx->scalar.len = 0;
    ctx->scalar.cap = 1024;
    if (ctx->scalar.content) ctx->scalar.content[0] = '\0';
    ctx->indent_context_sp = 0;
    ctx->scalar_base_indent = 0;
    ctx->scalar_type = '\0';
    ctx->quoted_value_closed_on_line = 0;
    ctx->flow.implicit_key_candidate = 0;
    ctx->flow.delim_sp = 0;
    ctx->flow.pending_dedent_count = 0;
    memset(ctx->flow.delim_stack, 0, sizeof(ctx->flow.delim_stack));
    memset(ctx->flow.indent_ref_stack, 0, sizeof(ctx->flow.indent_ref_stack));
    memset(ctx->flow.indent_required_stack, 0, sizeof(ctx->flow.indent_required_stack));
    ctx->open_document_started = 1;

    return ctx;
}

void lexer_context_free(LexerContext *ctx) {
    if (!ctx) return;
    free(ctx->scalar.content);
    free(ctx);
}

/*
 * Stage 1: Parse - Presentation -> Events
 */
int yaml_parse(const YAMLProcessorOptions *options) {
    int dump_tokens = options ? options->dump_tokens : 0;
    int parse_only = options ? options->parse_node : 0;
    int result = yaml_parse_internal(NULL, parse_only);
    const char *serialization_tree = yaml_runtime_serialization_tree();

    (void)((dump_tokens && serialization_tree) ? (printf("%s", serialization_tree), 0) : 0);
    return (dump_tokens || parse_only) ? (exit(result), result) : result;
}
