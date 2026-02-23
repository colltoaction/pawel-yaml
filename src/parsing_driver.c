#include <stdlib.h>
#include <stdio.h>
#include "common.h"
#include "stream.tab.h"

typedef struct yy_buffer_state *YY_BUFFER_STATE;
typedef int (*YAMLParseFn)(void *scanner);
typedef int (*YAMLLexInitFn)(void *user_defined, void **scanner);
typedef int (*YAMLLexDestroyFn)(void *scanner);
typedef YY_BUFFER_STATE (*YAMLScanStringFn)(const char *yy_str, void *yyscanner);
typedef void (*YAMLDeleteBufferFn)(YY_BUFFER_STATE b, void *yyscanner);

/* Coproduct-style parser driver alternatives (failure + run path). */
typedef enum {
    PARSE_PATH_NO_CONTEXT = 0,
    PARSE_PATH_LEXER_INIT_FAIL,
    PARSE_PATH_INPUT_BUFFER_FAIL,
    PARSE_PATH_RUN
} ParsePath;

typedef struct {
    const char *input;
    void *scanner;
    LexerContext *ctx;
    YY_BUFFER_STATE buffer;
    YAMLParseFn parse_fn;
    YAMLLexInitFn lex_init_extra;
    YAMLLexDestroyFn lex_destroy;
    YAMLScanStringFn scan_string;
    YAMLDeleteBufferFn delete_buffer;
} ParseSession;

extern int scanning_lex_init_extra(void *user_defined, void **scanner);
extern int scanning_lex_destroy(void *scanner);
extern YY_BUFFER_STATE scanning__scan_string(const char *yy_str, void *yyscanner);
extern void scanning__delete_buffer(YY_BUFFER_STATE b, void *yyscanner);
extern int node_scan_lex_init_extra(void *user_defined, void **scanner);
extern int node_scan_lex_destroy(void *scanner);
extern YY_BUFFER_STATE node_scan__scan_string(const char *yy_str, void *yyscanner);
extern void node_scan__delete_buffer(YY_BUFFER_STATE b, void *yyscanner);

extern LexerContext *lexer_context_new(void);
extern void lexer_context_free(LexerContext *ctx);
extern void string_pool_reset(void);
extern int validate_lexical_semantics(const LexerContext *ctx, void *scanner);
extern int parse_error_count;
extern int parse_nonfatal_count;
extern int g_silent_parse_errors;
extern int stream_yy_drive_parse(void *scanner);
extern int node_yy_drive_parse(void *scanner);
void stream_yy_error(void *yylloc, void *scanner, const char *s);

static YAMLParseFn parser_entrypoint(int parse_only) {
    return parse_only ? node_yy_drive_parse : stream_yy_drive_parse;
}

static YAMLLexInitFn lexer_init_entrypoint(int parse_only) {
    return parse_only ? node_scan_lex_init_extra : scanning_lex_init_extra;
}

static YAMLLexDestroyFn lexer_destroy_entrypoint(int parse_only) {
    return parse_only ? node_scan_lex_destroy : scanning_lex_destroy;
}

static YAMLScanStringFn lexer_scan_string_entrypoint(int parse_only) {
    return parse_only ? node_scan__scan_string : scanning__scan_string;
}

static YAMLDeleteBufferFn lexer_delete_buffer_entrypoint(int parse_only) {
    return parse_only ? node_scan__delete_buffer : scanning__delete_buffer;
}

static int parse_alt_no_context(void) {
    stream_yy_error(NULL, NULL, "Failed to create lexer context");
    string_pool_reset();
    return 1;
}

static int parse_alt_lexer_init_fail(LexerContext *ctx) {
    stream_yy_error(NULL, NULL, "Failed to initialize lexer");
    lexer_context_free(ctx);
    string_pool_reset();
    return 1;
}

static int parse_alt_input_buffer_fail(ParseSession *session) {
    stream_yy_error(NULL, session->scanner, "Failed to initialize parser input buffer");
    session->lex_destroy(session->scanner);
    lexer_context_free(session->ctx);
    string_pool_reset();
    return 1;
}

static int parse_alt_run(ParseSession *session) {
    int result;

    parse_error_count = 0;
    parse_nonfatal_count = 0;
    result = session->parse_fn(session->scanner);
    result = (((result == 0) && (validate_lexical_semantics(session->ctx, session->scanner) != 0))
              || ((parse_error_count > 0) && (result == 0))) ? 1 : result;
    if (session->buffer) {
        session->delete_buffer(session->buffer, session->scanner);
    }
    session->lex_destroy(session->scanner);
    lexer_context_free(session->ctx);
    string_pool_reset();
    return result;
}

static ParsePath parse_path_select(ParseSession *session) {
    return !session->ctx
        ? PARSE_PATH_NO_CONTEXT
        : ((session->lex_init_extra(session->ctx, &session->scanner) != 0)
            ? PARSE_PATH_LEXER_INIT_FAIL
            : (((session->input != NULL)
                && ((session->buffer = session->scan_string(session->input, session->scanner)) == NULL))
                ? PARSE_PATH_INPUT_BUFFER_FAIL
                : PARSE_PATH_RUN));
}

static int parse_path_apply(ParsePath path, ParseSession *session) {
    return path == PARSE_PATH_NO_CONTEXT
        ? parse_alt_no_context()
        : (path == PARSE_PATH_LEXER_INIT_FAIL
            ? parse_alt_lexer_init_fail(session->ctx)
            : (path == PARSE_PATH_INPUT_BUFFER_FAIL
                ? parse_alt_input_buffer_fail(session)
                : parse_alt_run(session)));
}

int yaml_parse_internal(const char *input, int parse_only) {
    ParseSession session;

    session.input = input;
    session.scanner = NULL;
    session.ctx = lexer_context_new();
    session.buffer = NULL;
    session.parse_fn = parser_entrypoint(parse_only);
    session.lex_init_extra = lexer_init_entrypoint(parse_only);
    session.lex_destroy = lexer_destroy_entrypoint(parse_only);
    session.scan_string = lexer_scan_string_entrypoint(parse_only);
    session.delete_buffer = lexer_delete_buffer_entrypoint(parse_only);
    yaml_runtime_reset_artifacts();
    string_pool_reset();
    return parse_path_apply(parse_path_select(&session), &session);
}

int yaml_parse_buffer(const char *input) {
    return yaml_parse_internal(input ? input : "", 0);
}

int yaml_parse_buffer_probe(const char *input) {
    int prev = g_silent_parse_errors;
    int result;

    g_silent_parse_errors = 1;
    result = yaml_parse_internal(input ? input : "", 0);
    g_silent_parse_errors = prev;
    return result;
}
