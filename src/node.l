%{
#include "node.tab.h"
#include "lexer_values.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* LexerContext type is provided by lexer_context.h via node.tab.h */

#define YYSTYPE NODE_YY_STYPE
#define YYLTYPE NODE_YY_LTYPE

/* Forward declaration for error handling */
void node_yy_error(void *yylloc, yyscan_t scanner, const char *msg);
#define yyerror node_yy_error

/* Include core helpers and definitions */
%}

%option noyywrap
%option reentrant
%option bison-bridge
%option bison-locations
%option prefix="node_scan_"
%option extra-type="LexerContext *"

%x BLOCK_SCALAR
%x BLOCK_CONTENT
%x DIRECTIVE_MODE
%x INDENT_CHECK
%x PLAIN_SCALAR_CONT
%x QUOTED

NSCAL [a-zA-Z0-9\-\._%:/]
ANCHOR_CHAR [^ \t\n\r\[\]{},]
ALIAS_CHAR [^ \t\n\r\[\]{},]
VSPACE \xE2\x90\xA3
VEND \xE2\x88\x8E
TAG_TOKEN ("!<"[^>\n\r]+">"|"!!"{NSCAL}+|"!"{NSCAL}+"!"{NSCAL}*|"!"{NSCAL}+)
PKEY_HEAD [^ \t\n\r\[\]{}!,&*%@|>\`'"]
PKEY_BODY [^:\n\r]*

%include "lexer_core.l.inc"
