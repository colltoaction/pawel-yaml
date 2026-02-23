#include <stdio.h>
#include "common.h"
#include "stream.tab.h"
#include "event.tab.h"

extern int scanning_lex(void *yylval_param, void *yyloc_param, void *yyscanner);

int stream_yy_parse(void *scanner) { return 0; }
int node_yy_parse(void *scanner) { return 0; }
int event_yy_parse(void) { return 0; }
int ct_yy_parse(void) { return 0; }
int yaml_yy_parse(void *scanner) { return 0; }

int stream_yy_drive_parse(void *scanner) {
    YYSTYPE yylval;
    void *yyloc = NULL;
    int token;
    /* Lexer loop for testing */
    while ((token = scanning_lex(&yylval, yyloc, scanner)) != 0) {
        if (token < 0) return 1; /* Error */
    }
    return 0;
}

int node_yy_drive_parse(void *scanner) { return node_yy_parse(scanner); }

void ct_yy_error(const char *s) { (void)s; }
void yaml_yy_error(void *yylloc, void *scanner, const char *s) { (void)yylloc; (void)scanner; (void)s; }
