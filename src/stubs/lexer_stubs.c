#include <stddef.h>

/* Node lexer compatibility stubs */
int node_scan_lex_init_extra(void *user_defined, void **scanner) {
    (void)user_defined;
    if (scanner) *scanner = NULL;
    return 0;
}

int node_scan_lex_destroy(void *scanner) {
    (void)scanner;
    return 0;
}

void *node_scan__scan_string(const char *yy_str, void *yyscanner) {
    (void)yy_str;
    (void)yyscanner;
    return (void*)1;
}

void node_scan__delete_buffer(void *b, void *yyscanner) {
    (void)b;
    (void)yyscanner;
}

int node_scan_lex(void *yylval_param, void *yyloc_param, void *yyscanner) {
    (void)yylval_param;
    (void)yyloc_param;
    (void)yyscanner;
    return 0;
}

/* Event lexer compatibility stubs */
int event_lex(void) { return 0; }

void *event__scan_string(const char *s) {
    (void)s;
    return (void*)1;
}

void event__delete_buffer(void *b) {
    (void)b;
}
