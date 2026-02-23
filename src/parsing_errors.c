#include <stdio.h>
#include <string.h>
#include "stream.tab.h"

void stream_yy_error(void *yylloc, void *scanner, const char *s);

int parse_error_count = 0;
int parse_nonfatal_count = 0;
int g_silent_parse_errors = 0;

int parser_is_nonfatal_message(const char *msg) {
    return msg ? (strstr(msg, "syntax is ambiguous") != NULL) : 0;
}

int validate_lexical_semantics(const LexerContext *ctx, void *scanner) {
    char errbuf[512];
    int violations = (ctx != NULL) && (ctx->semantic_error_count > 0);

    return violations
        ? (snprintf(errbuf, sizeof(errbuf),
                    "semantic policy violations: %d (tab-leading lines: %d, indent-mismatch lines: %d, directive-mid-doc lines: %d, flow-glue lines: %d, flow-comma lines: %d, flow-leading-comma lines: %d, flow-comma-comment lines: %d, flow-key-newline lines: %d, flow-indent lines: %d, multiline-qkey lines: %d, inline-keys: %d, doc-end-inline lines: %d)",
                    ctx->semantic_error_count,
                    ctx->semantic_indent_tab_count,
                    ctx->semantic_indent_mismatch_count,
                    ctx->semantic_directive_mid_doc_count,
                    ctx->semantic_flow_glue_count,
                    ctx->semantic_flow_comma_count,
                    ctx->semantic_flow_leading_comma_count,
                    ctx->semantic_flow_comment_comma_count,
                    ctx->semantic_flow_key_newline_count,
                    ctx->semantic_flow_indent_count,
                    ctx->semantic_multiline_qkey_count,
                    ctx->semantic_inline_key_count,
                    ctx->semantic_doc_end_inline_count),
           stream_yy_error(NULL, scanner, errbuf),
           1)
        : 0;
}

int gamma_from_token(YAMLBisonToken token) {
    YAMLAlphabetSymbol symbol = yaml_gamma_token(token);
    return symbol.token.token;
}

Indented indented_from_level(int level) {
    Indented indented;
    indented.level = level;
    return indented;
}

Indented indented_dedent(Indented indented) {
    indented.level = 0;
    return indented;
}

void stream_yy_error(void *yylloc, void *scanner, const char *s) {
    STREAM_YY_LTYPE *loc = (STREAM_YY_LTYPE*)yylloc;
    const char *msg = s ? s : "syntax error";
    int nonfatal = parser_is_nonfatal_message(s);
    int has_line = (loc != NULL) && (loc->first_line > 0);

    (void)scanner;
    parse_nonfatal_count += nonfatal;
    parse_error_count += !nonfatal;
    (void)(g_silent_parse_errors ? 0 : (has_line
        ? (fprintf(stderr, "[PARSE] %d:%d: %s\n", loc->first_line, loc->first_column, msg), 0)
        : (fprintf(stderr, "[PARSE] %s\n", msg), 0)));
}
