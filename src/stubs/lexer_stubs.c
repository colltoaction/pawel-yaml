#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "common.h"
#include "stream.tab.h"
#include "lexer_values.h"

#define YYSTYPE STREAM_YY_STYPE
#define YYLTYPE STREAM_YY_LTYPE
/* Node lexer stubs */
int node_scan_lex_init_extra(void *user_defined, void **scanner) { *scanner = NULL; return 0; }
int node_scan_lex_destroy(void *scanner) { return 0; }
void *node_scan__scan_string(const char *yy_str, void *yyscanner) { return (void*)1; }
void node_scan__delete_buffer(void *b, void *yyscanner) {}
int node_scan_lex(void *yylval_param, void *yyloc_param, void *yyscanner) { return 0; }

/* Event lexer stubs */
int event_lex(void) { return 0; }
void *event__scan_string(const char *s) { (void)s; return (void*)1; }
void event__delete_buffer(void *b) { (void)b; }
