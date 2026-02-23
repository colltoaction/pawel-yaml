#include <stdio.h>
#include "common.h"
#include "stream.tab.h"

int scanning_lex_init_extra(void *user_defined, void **scanner) { *scanner = NULL; return 0; }
int scanning_lex_destroy(void *scanner) { return 0; }
void *scanning__scan_string(const char *yy_str, void *yyscanner) { return (void*)1; }
void scanning__delete_buffer(void *b, void *yyscanner) {}
int scanning_lex(void *yylval_param, void *yyloc_param, void *yyscanner) { return 0; }

int node_scan_lex_init_extra(void *user_defined, void **scanner) { *scanner = NULL; return 0; }
int node_scan_lex_destroy(void *scanner) { return 0; }
void *node_scan__scan_string(const char *yy_str, void *yyscanner) { return (void*)1; }
void node_scan__delete_buffer(void *b, void *yyscanner) {}
int node_scan_lex(void *yylval_param, void *yyloc_param, void *yyscanner) { return 0; }

int event_lex(void) { return 0; }
void *event__scan_string(const char *s) { (void)s; return (void*)1; }
void event__delete_buffer(void *b) { (void)b; }
