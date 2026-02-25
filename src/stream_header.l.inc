%{
#include "stream.tab.h"
#include "lexer_values.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

#define YYSTYPE STREAM_YY_STYPE
#define YYLTYPE STREAM_YY_LTYPE

void stream_yy_error(YYLTYPE *yylloc, yyscan_t scanner, const char *msg);
#define yyerror stream_yy_error

static int return_dedent_count(LexerContext *ctx, int dedent_count, YYSTYPE *yylval);

/* Support Macros & Functions */
#define CTX ((LexerContext *)yyextra)

/* Flow Context Accessors */
#define PENDING_DEDENT_COUNT (CTX->flow.pending_dedent_count)
#define FLOW_DELIM_SP (CTX->flow.delim_sp)
#define FLOW_DELIM_STACK (CTX->flow.delim_stack)
#define FLOW_INDENT_REF_STACK (CTX->flow.indent_ref_stack)
#define FLOW_INDENT_REQUIRED_STACK (CTX->flow.indent_required_stack)

/* Constants for Flow Key State */
#define FLOW_KEY_NONE 0
#define FLOW_KEY_CANDIDATE 1

static void flow_key_state_set(LexerContext *ctx, int state) {
    ctx->flow.implicit_key_candidate = state;
}

static int flow_key_state_is(LexerContext *ctx, int state) {
    return ctx->flow.implicit_key_candidate == state;
}

/* Constants for Colon State */
#define COLON_STATE_NONE 0
#define COLON_STATE_PENDING 1

static void colon_state_set(LexerContext *ctx, int state) {
    ctx->pending_colon = state;
}

/* Helper for block indent indicator parsing */
static int parse_block_indent_indicator(const char *text) {
    /* Skip '>' or '|' */
    const char *p = text + 1;
    if (*p >= '1' && *p <= '9') return *p - '0';
    return 0;
}

/* Fix for input() macro if needed, though reentrant flex usually handles it */
/* #define input(s) yyinput(s) */

%}

%option noyywrap
%option reentrant
%option bison-bridge
%option bison-locations
%option prefix="scanning_"
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
DQUOTED_CONTENT ([^\\\"\n\r]|\\.)*
SQUOTED_CONTENT (\'\'|\\'|[^'\n\r])*
PROP_PART ({TAG_TOKEN}|[&]{ANCHOR_CHAR}+)
PROP_LEAD {PROP_PART}([ \t]+{PROP_PART})?
