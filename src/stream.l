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
%%

<INDENT_CHECK>[ \t]*#[^\n]* {
    /* Line with only whitespace and comment - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>({VSPACE}|[ \t])*{VEND}[^\n]*\n {
    /* yaml-test-suite end marker line - skip it */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>({VSPACE}|[ \t])*\n {
    /* Blank line - skip it, stay in INDENT_CHECK */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>({VSPACE}|[ \t])*{VEND} {
    /* End marker without newline */
    BEGIN(INDENT_CHECK);
}

<INDENT_CHECK>[ \t]* {
    int indent = 0;
    int has_tab = 0;
    for (int i=0; i<yyleng; i++) {
        if (yytext[i] == ' ') {
            indent++;
        } else if (yytext[i] == '\t') {
            has_tab = 1;
            /* Tabs OK before flow indicators, error otherwise */
        }
    }

    if (has_tab) {
        /* Syntax stage: tokenize indentation without rejecting tabbed lines.
         * Semantic stage decides whether the line is policy-valid.
         */
        int c = input(yyscanner);
        int first_char = c;
        int look_buf[1024];
        int look_n = 0;
        int line_has_mapping_shape = 0;

        if (c != EOF && c != 0) {
            look_buf[look_n++] = c;

            while (look_n < 1023) {
                if (c == '\n' || c == '\r' || c == EOF || c == 0) break;
                c = input(yyscanner);
                if (c == EOF || c == 0) break;
                look_buf[look_n++] = c;
            }

            for (int i = 0; i < look_n; i++) {
                if (look_buf[i] == '#') break;
                if (look_buf[i] == ':' || look_buf[i] == '-') {
                    line_has_mapping_shape = 1;
                    break;
                }
            }
        }

        for (int i = look_n - 1; i >= 0; i--) {
            unput(look_buf[i]);
        }

        /* Policy: tabbed leading whitespace is rejected when line shape
         * indicates structural indentation (mapping/sequence), but allowed
         * for scalar-alignment continuation content.
         */
        if (line_has_mapping_shape && first_char != '[' && first_char != '{') {
            CTX->semantic_error_count++;
            CTX->semantic_indent_tab_count++;
        }
    }

    {
        int look_buf[3];
        int look_n = 0;
        int c = input(yyscanner);
        int is_doc_end_marker = 0;

        if (c != EOF && c != 0) {
            look_buf[look_n++] = c;
            for (int i = 0; i < 2; i++) {
                int d = input(yyscanner);
                if (d == EOF || d == 0) break;
                look_buf[look_n++] = d;
            }
        }

        for (int i = look_n - 1; i >= 0; i--) {
            unput(look_buf[i]);
        }

        if (look_n >= 3 &&
            look_buf[0] == '.' &&
            look_buf[1] == '.' &&
            look_buf[2] == '.') {
            is_doc_end_marker = 1;
        }

        if (look_n > 0) {
            if (look_buf[0] == '%') {
                /* keep current directive allowance */
            } else if (is_doc_end_marker) {
                CTX->open_document_started = 1;
            } else if (look_buf[0] != '#') {
                CTX->open_document_started = 0;
            }
        }
    }

    BEGIN(INITIAL);
    CTX->at_line_start = 1;
    int cur = CTX->indent_stack[CTX->indent_sp];
    if (indent > cur) {
        if (CTX->indent_sp < 99) {
            CTX->indent_stack[++CTX->indent_sp] = indent;
        }
        *yylval = val_int(indent);
return INDENT;
    } else if (indent < cur) {
        int dedent_count = 0;
        int target_sp = CTX->indent_sp;
        while (target_sp > 0 && CTX->indent_stack[target_sp] > indent) {
            target_sp--;
            dedent_count++;
        }

        if (indent != CTX->indent_stack[target_sp]) {
            CTX->semantic_error_count++;
            CTX->semantic_indent_mismatch_count++;
        }

        CTX->indent_sp = target_sp;
        if (dedent_count > 0) {
            *yylval = val_int(dedent_count);
            return return_dedent_count(CTX, dedent_count, yylval);
        }
    }
}

<INDENT_CHECK>. {
    /* Not an indent - likely at column 0 */
    int first_char = yytext[0];
    if (first_char != '%' && first_char != '#' && first_char != '.') {
        CTX->open_document_started = 0;
    }
    yyless(0);
    BEGIN(INITIAL);
    CTX->at_line_start = 1;
    int cur = CTX->indent_stack[CTX->indent_sp];
    if (0 < cur) {
        int dedent_count = 0;
        while (0 < CTX->indent_stack[CTX->indent_sp]) {
            if (CTX->indent_sp > 0) CTX->indent_sp--;
            dedent_count++;
        }
        if (dedent_count > 0) {
            return return_dedent_count(CTX, dedent_count, yylval);
        }
    }
}

<INDENT_CHECK><<EOF>> {
    BEGIN(INITIAL);
    {
        int dedent_count = 0;
        while (0 < CTX->indent_stack[CTX->indent_sp]) {
            if (CTX->indent_sp > 0) CTX->indent_sp--;
            dedent_count++;
        }
        if (dedent_count > 0) {
            return return_dedent_count(CTX, dedent_count, yylval);
        }
    }
    return YAML_GAMMA;
}

<INITIAL><<EOF>> {
    if (PENDING_DEDENT_COUNT > 0) {
        *yylval = val_int(PENDING_DEDENT_COUNT);
        PENDING_DEDENT_COUNT--;
return DEDENT;
    }
    return YAML_GAMMA;
}

\n {
    CTX->current_column = 0;
    CTX->quoted_value_closed_on_line = 0;
    /* In flow context, newlines are just whitespace, don't check indentation */
    if (FLOW_DELIM_SP == 0) {
        BEGIN(INDENT_CHECK);
    } else {
        int top = FLOW_DELIM_SP - 1;
        if (top >= 0 &&
            (FLOW_INDENT_REQUIRED_STACK[top] || flow_key_state_is(CTX, FLOW_KEY_CANDIDATE))) {
            int look_buf[4096];
            int look_n = 0;
            int indent = 0;
            int first_content = -1;
            int c;
            int close_ch = (FLOW_DELIM_STACK[top] == '{') ? '}' : ']';
            int baseline = FLOW_INDENT_REF_STACK[top];

            while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
                look_buf[look_n++] = c;

                if (c == ' ') {
                    indent++;
                    continue;
                }
                if (c == '\t') {
                    indent++;
                    continue;
                }
                if (c == '\r') {
                    continue;
                }
                if (c == '\n') {
                    indent = 0;
                    continue;
                }
                if (c == '#') {
                    while (look_n < 4095 && (c = input(yyscanner)) != EOF && c != 0) {
                        look_buf[look_n++] = c;
                        if (c == '\n') break;
                    }
                    indent = 0;
                    continue;
                }

                first_content = c;
                break;
            }

            for (int i = look_n - 1; i >= 0; i--) {
                unput(look_buf[i]);
            }

            if (flow_key_state_is(CTX, FLOW_KEY_CANDIDATE) &&
                first_content == ':' &&
                FLOW_DELIM_STACK[top] == '[') {
                yyerror(yylloc, yyscanner, "syntax error, implicit flow key followed by newline");
                CTX->semantic_error_count++;
                CTX->semantic_flow_key_newline_count++;
            }

            if (FLOW_INDENT_REQUIRED_STACK[top] &&
                first_content >= 0 &&
                first_content != close_ch &&
                indent <= baseline) {
                yyerror(yylloc, yyscanner, "syntax error, wrong indentation in flow sequence");
                CTX->semantic_error_count++;
                CTX->semantic_flow_indent_count++;
            }
        }
        flow_key_state_set(CTX, FLOW_KEY_NONE);
    }
    /* Otherwise skip the newline in flow context */
}



"%"/[ \t:] {
    if (FLOW_DELIM_SP > 0) {
        *yylval = val_str(NULL); /* was strdup("%") */
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    return yytext[0];
}

"%TAG"           {
    if (!CTX->open_document_started) {
        yyerror(yylloc, yyscanner, "syntax error, missing document-end marker before directive");
        CTX->semantic_error_count++;
        CTX->semantic_directive_mid_doc_count++;
    }
    BEGIN(DIRECTIVE_MODE);
return TAG_DIRECTIVE;
}
"%YAML"[ ]?"1"[.,][0-9][ \t]+[^#\n][^\n]* {
    if (!CTX->open_document_started) {
        *yylval = val_str(NULL); /* was strdup(yytext) */
        CTX->at_line_start = 0;
        CTX->last_was_value = 1;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->yaml_directive_seen) {
        yyerror(yylloc, yyscanner, "syntax error, duplicate %YAML directive");
        CTX->semantic_error_count++;
    } else {
        CTX->yaml_directive_seen = 1;
    }
    yyerror(yylloc, yyscanner, "syntax error, extra content on %YAML directive");
    CTX->semantic_error_count++;
    if (!CTX->open_document_started) {
        CTX->semantic_directive_mid_doc_count++;
    }
return YAML_DIRECTIVE;
}
"%YAML"[ ]?"1"[.,][0-9]"#"[^\n]* {
    if (!CTX->open_document_started) {
        *yylval = val_str(NULL); /* was strdup(yytext) */
        CTX->at_line_start = 0;
        CTX->last_was_value = 1;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->yaml_directive_seen) {
        yyerror(yylloc, yyscanner, "syntax error, duplicate %YAML directive");
        CTX->semantic_error_count++;
    } else {
        CTX->yaml_directive_seen = 1;
    }
    yyerror(yylloc, yyscanner, "syntax error, missing whitespace before %YAML comment");
    CTX->semantic_error_count++;
    if (!CTX->open_document_started) {
        CTX->semantic_directive_mid_doc_count++;
    }
return YAML_DIRECTIVE;
}
"%YAML"[ ]?"1"[.,][0-9][ \t]*(#[^\n]*)?  {
    if (!CTX->open_document_started) {
        *yylval = val_str(NULL); /* was strdup(yytext) */
        CTX->at_line_start = 0;
        CTX->last_was_value = 1;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->yaml_directive_seen) {
        yyerror(yylloc, yyscanner, "syntax error, duplicate %YAML directive");
        CTX->semantic_error_count++;
    } else {
        CTX->yaml_directive_seen = 1;
    }
    if (!CTX->open_document_started) {
        yyerror(yylloc, yyscanner, "syntax error, missing document-end marker before directive");
        CTX->semantic_error_count++;
        CTX->semantic_directive_mid_doc_count++;
    }
return YAML_DIRECTIVE;
}
"%"[a-zA-Z][^\n]* {
    if (!CTX->open_document_started) {
        yyerror(yylloc, yyscanner, "syntax error, missing document-end marker before directive");
        CTX->semantic_error_count++;
        CTX->semantic_directive_mid_doc_count++;
    }
    /* Unknown directive - skip */
}
"---"[ \t]+{PROP_LEAD}[ ]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    yyerror(yylloc, yyscanner, "syntax error, anchored mapping key is not allowed on document-start line");
    CTX->semantic_error_count++;
    yyless(3);
    CTX->expecting_value = 1;
    CTX->last_was_value = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 0;
    CTX->yaml_directive_seen = 0;
return DOC_START;
}
"---" {
    CTX->expecting_value = 1;
    CTX->last_was_value = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 0;
    CTX->yaml_directive_seen = 0;
return DOC_START;
}
"..."[ \t]*[^ \t\n\r#] {
    yyerror(yylloc, yyscanner, "content after document-end marker");
    CTX->semantic_error_count++;
    yyless(3);
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 1;
    CTX->yaml_directive_seen = 0;
return DOC_END;
}
"..." {
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    CTX->open_document_started = 1;
    CTX->yaml_directive_seen = 0;
return DOC_END;
}
<DIRECTIVE_MODE>{
    [ \t]+          { /* skip space */ }
    \n              { BEGIN(INITIAL); }
}
"-"[ \t]*"#"[^\n]*\n {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP == 0) BEGIN(INDENT_CHECK);
return BULLET_EOL;
}
"-"[ \t]*\n {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP == 0) BEGIN(INDENT_CHECK);
return BULLET_EOL;
}
"-"/[ \t\n]      {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    colon_state_set(CTX, COLON_STATE_NONE);
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return BULLET;
}
"-"[ \t]*"," {
    if (FLOW_DELIM_SP > 0) {
        yyerror(yylloc, yyscanner, "syntax error, bare dash is not a valid flow scalar");
        CTX->semantic_error_count++;
    }
    yyless(1);
    *yylval = val_str(NULL); /* was strdup("-") */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}
"-"[ \t]*"]" {
    if (FLOW_DELIM_SP > 0) {
        yyerror(yylloc, yyscanner, "syntax error, bare dash is not a valid flow scalar");
        CTX->semantic_error_count++;
    }
    yyless(1);
    *yylval = val_str(NULL); /* was strdup("-") */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}
":"/[ \t\n] {
    if (CTX->complex_key_pending) {
        CTX->complex_key_pending = 0;
        CTX->at_line_start = 0;
        CTX->expecting_value = 1;
        colon_state_set(CTX, COLON_STATE_NONE);
        flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
    }
    if (FLOW_DELIM_SP == 0 && (CTX->at_line_start || CTX->expecting_value)) {
        /* Missing block mapping key, e.g. ": value" */
        *yylval = val_str(NULL); /* was strdup("") */
        CTX->at_line_start = 0;
        CTX->expecting_value = 0;
        yyless(0); /* Rescan ':' as the actual separator token */
return MAP_KEY;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
}
":"/[ \t]*[,}]   {
    CTX->at_line_start = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP > 0) {
        CTX->expecting_value = 1;
return COLON_EMPTY;
    }
    if (CTX->expecting_value) {
        *yylval = val_str(NULL); /* was strdup(":") */
        CTX->expecting_value = 0;
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    CTX->expecting_value = 1;
return COLON;
}
{PROP_LEAD}[ \t]+{PKEY_HEAD}{PKEY_BODY}/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Prop-prefixed key: &a key, !!t key, &a !!t key, !!t &a key */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    *yylval = val_str(NULL);
    /* Check if anchor is present to decide token type */
    if (strchr(yytext, '&')) {
        return ANCHOR_MAP_KEY;
    }
    /* If only tag is present, it's just a MAP_KEY (tag discarded in this lexer) */
    return MAP_KEY;
}
{PROP_LEAD}[ \t]+\"{DQUOTED_CONTENT}\"[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Prop-prefixed double-quoted key */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    *yylval = val_str(NULL);
    if (strchr(yytext, '&')) {
        return ANCHOR_MAP_KEY;
    }
    return MAP_KEY;
}
{PROP_LEAD}[ \t]+\'{SQUOTED_CONTENT}\'[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Prop-prefixed single-quoted key */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    *yylval = val_str(NULL);
    if (strchr(yytext, '&')) {
        return ANCHOR_MAP_KEY;
    }
    return MAP_KEY;
}
{PROP_LEAD}[ \t]+\[[^\]\n\r]*\][ ]*/":"([ \t\n]|{VSPACE}) {
    /* Prop-prefixed flow-sequence key: &a [], !!t [], &a !!t [] */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    *yylval = val_str(NULL);
    if (strchr(yytext, '&')) {
        return ANCHOR_MAP_KEY;
    }
    return MAP_KEY;
}
{PROP_LEAD}[ \t]+\{[^\}\n\r]*\}[ ]*/":"([ \t\n]|{VSPACE}) {
    /* Prop-prefixed flow-mapping key */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    *yylval = val_str(NULL);
    if (strchr(yytext, '&')) {
        return ANCHOR_MAP_KEY;
    }
    return MAP_KEY;
}
"&"{ANCHOR_CHAR}+[ \t]+"-"/[ \t\n] {
    int anchor_len = 0;
    yyerror(yylloc, yyscanner, "syntax error, anchor cannot prefix a sequence indicator on the same line");
    CTX->semantic_error_count++;

    while (anchor_len < yyleng &&
           yytext[anchor_len] != ' ' &&
           yytext[anchor_len] != '\t') {
        anchor_len++;
    }

    *yylval = val_str(NULL);

    yyless(anchor_len);
    CTX->at_line_start = 0;
return ANCHOR;
}
"*"{ALIAS_CHAR}+[ ]+/":"([ \t\n]|{VSPACE}) {
    /* Alias map key with explicit separating whitespace before ':' */
    CTX->at_line_start = 0;
    *yylval = val_str(NULL);
    CTX->expecting_value = 0;
return MAP_KEY;
}
"*"{ALIAS_CHAR}+":"/([ \t\n]|{VSPACE}) {
    CTX->at_line_start = 0;

    if (CTX->expecting_value) {
        /* Value-position alias ending with ':' keeps the ':' in the alias name. */
        *yylval = val_str(NULL);
        CTX->expecting_value = 0;
        if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return ALIAS;
    }

    /* Key-position alias: split before ':' and let parser consume ':' token. */
    yyless(yyleng - 1);
    *yylval = val_str(NULL);
    CTX->expecting_value = 0;
return MAP_KEY;
}
"["              {
    int require_flow_indent = (FLOW_DELIM_SP == 0 && !CTX->at_line_start);
    int flow_ref_indent = CTX->indent_stack[CTX->indent_sp];
    CTX->at_line_start = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP < 100) {
        FLOW_DELIM_STACK[FLOW_DELIM_SP] = '[';
        FLOW_INDENT_REF_STACK[FLOW_DELIM_SP] = flow_ref_indent;
        FLOW_INDENT_REQUIRED_STACK[FLOW_DELIM_SP] = require_flow_indent;
        FLOW_DELIM_SP++;
    }
    CTX->expecting_value = 1;
return LBRACK;
}
"]"              {
    if (FLOW_DELIM_SP > 0) {
        FLOW_DELIM_SP--;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    flow_key_state_set(CTX, FLOW_DELIM_SP > 0 ? FLOW_KEY_CANDIDATE : FLOW_KEY_NONE);
return RBRACK;
}
"{"              {
    int require_flow_indent = (FLOW_DELIM_SP == 0 && !CTX->at_line_start);
    int flow_ref_indent = CTX->indent_stack[CTX->indent_sp];
    CTX->at_line_start = 0;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
    if (FLOW_DELIM_SP < 100) {
        FLOW_DELIM_STACK[FLOW_DELIM_SP] = '{';
        FLOW_INDENT_REF_STACK[FLOW_DELIM_SP] = flow_ref_indent;
        FLOW_INDENT_REQUIRED_STACK[FLOW_DELIM_SP] = require_flow_indent;
        FLOW_DELIM_SP++;
    }
    CTX->expecting_value = 1;
return LBRACE;
}
"}"              {
    if (FLOW_DELIM_SP > 0) {
        FLOW_DELIM_SP--;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    flow_key_state_set(CTX, FLOW_DELIM_SP > 0 ? FLOW_KEY_CANDIDATE : FLOW_KEY_NONE);
return RBRACE;
}
":"              {
    if (CTX->expecting_value && FLOW_DELIM_SP > 0) {
         *yylval = val_str(NULL); /* was strdup(":") */
         CTX->expecting_value = 0;
         flow_key_state_set(CTX, FLOW_KEY_NONE);
         BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    } else if (CTX->expecting_value && FLOW_DELIM_SP == 0) {
         *yylval = val_str(NULL); /* was strdup(":") */
         flow_key_state_set(CTX, FLOW_KEY_NONE);
         BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    } else if (FLOW_DELIM_SP > 0) {
         CTX->expecting_value = 1;
         flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
    } else {
         return ':';
    }
}
","/"#" {
    if (FLOW_DELIM_SP > 0) {
        CTX->semantic_error_count++;
        CTX->semantic_flow_comment_comma_count++;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COMMA;
}
","/[ \t]*"," {
    if (FLOW_DELIM_SP > 0) {
        CTX->semantic_error_count++;
        CTX->semantic_flow_comma_count++;
    }
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COMMA;
}
"," {
    CTX->at_line_start = 0;
    CTX->expecting_value = 1;
    flow_key_state_set(CTX, FLOW_KEY_NONE);
return COMMA;
}
\" {
    BEGIN(QUOTED);
}

<QUOTED>{
    \" {
        BEGIN(INITIAL);
        CTX->expecting_value = 0;
        CTX->last_was_value = 1;
        CTX->quoted_value_closed_on_line = 1;
        if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return QSCALAR;
    }

    \\n {
        *yylval = val_str(NULL); /* was strdup("\\n") */
return CH_ESC_N;
    }
    \\t {
        *yylval = val_str(NULL); /* was strdup("\\t") */
return CH_ESC_T;
    }
    \\r {
        *yylval = val_str(NULL); /* was strdup("\\r") */
return CH_ESC_R;
    }
    \\\\ {
        *yylval = val_str(NULL); /* was strdup("\\\\") */
return CH_ESC_BS;
    }
    \\\" {
        *yylval = val_str(NULL); /* was strdup("\\\"") */
return CH_ESC_QU;
    }
    \\\' {
        yyerror(yylloc, yyscanner, "syntax error, invalid escape in quoted string");
        BEGIN(INITIAL);
        return 0;
    }
    \\\/ {
        *yylval = val_str(NULL); /* was strdup("\\/") */
return CH_ESC_SL;
    }
    \\. {
        if (yytext[1] == '.') {
            yyerror(yylloc, yyscanner, "syntax error, invalid escape in quoted string");
            BEGIN(INITIAL);
            return 0;
        }
        *yylval = val_str(NULL); /* was strdup(yytext) */
return CH_RAW;
    }
    \\0 {
        *yylval = val_str(NULL); /* was strdup("\\0") */
return CH_ESC_0;
    }
    [^\\\"\n]+ {
        *yylval = val_str(NULL); /* was strdup(yytext) */
return CH_RAW;
    }
    \n("---"|"...")([ \t]|#|\r?\n) {
        yyerror(yylloc, yyscanner, "syntax error, document marker inside quoted string");
        BEGIN(INITIAL);
        return 0;
    }
    \n {
        *yylval = val_str(NULL); /* was strdup("\n") */
return CH_RAW;
    }

    <<EOF>> {
        yyerror(yylloc, yyscanner, "syntax error, unterminated quoted string");
        BEGIN(INITIAL);
        return 0;
    }
}
\'{SQUOTED_CONTENT}\n("---"|"...")([ \t]|#|\r?\n){SQUOTED_CONTENT}\'  {
    yyerror(yylloc, yyscanner, "syntax error, document marker inside single-quoted string");
    CTX->semantic_error_count++;

    *yylval = val_str(NULL);
    CTX->expecting_value = 0;
    CTX->last_was_value = 1;
    CTX->quoted_value_closed_on_line = 1;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return SSCALAR;
}
\'{SQUOTED_CONTENT}\'  {
    /* Single-quoted string */
    *yylval = val_str(NULL);
    CTX->expecting_value = 0;
    CTX->last_was_value = 1;
    CTX->quoted_value_closed_on_line = 1;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
return SSCALAR;
}
"|"([1-9][-+]?|[-+][1-9]?|[-+]|[1-9])?[ \t]*(\n|[ \t]+#.*)      {
    int explicit_indent = parse_block_indent_indicator(yytext);
    CTX->expecting_value = 0;
    CTX->last_was_value = 0;
    CTX->block_scalar.type = '|';
    CTX->block_scalar.indent = explicit_indent > 0
        ? CTX->indent_stack[CTX->indent_sp] + explicit_indent
        : -1;
    CTX->block_scalar.leading_empty_max_indent = 0;
    CTX->block_scalar.first_content_seen = 0;
    BEGIN(BLOCK_SCALAR);
}
">"([1-9][-+]?|[-+][1-9]?|[-+]|[1-9])?[ \t]*(\n|[ \t]+#.*)      {
    int explicit_indent = parse_block_indent_indicator(yytext);
    CTX->expecting_value = 0;
    CTX->last_was_value = 0;
    CTX->block_scalar.type = '>';
    CTX->block_scalar.indent = explicit_indent > 0
        ? CTX->indent_stack[CTX->indent_sp] + explicit_indent
        : -1;
    CTX->block_scalar.leading_empty_max_indent = 0;
    CTX->block_scalar.first_content_seen = 0;
    BEGIN(BLOCK_SCALAR);
}

<BLOCK_SCALAR>^([ \t]|{VSPACE})*\n {
    int indent = 0;
    int i = 0;
    int had_tab_in_prefix = 0;
    while (i < yyleng && yytext[i] != '\n') {
        unsigned char ch = (unsigned char)yytext[i];
        if (ch == ' ' || ch == '\t') {
            if (ch == '\t') had_tab_in_prefix = 1;
            indent++;
            i++;
        } else if (ch == 0xE2 && (i + 2) < yyleng &&
                   (unsigned char)yytext[i + 1] == 0x90 &&
                   (unsigned char)yytext[i + 2] == 0xA3) {
            indent++;
            i += 3;
        } else {
            i++;
        }
    }
    if (!CTX->block_scalar.first_content_seen &&
        !had_tab_in_prefix &&
        indent > CTX->block_scalar.leading_empty_max_indent) {
        CTX->block_scalar.leading_empty_max_indent = indent;
    }
    *yylval = val_str(NULL); /* was strdup("\n") */
return BPART;
}

<BLOCK_SCALAR>^([ \t]|{VSPACE})+ {
    int indent = 0;
    int effective_indent = 0;
    int i = 0;
    int had_tab_in_prefix = 0;
    int first_tab_col = -1;
    char line_buf[4096];
    int line_len = 0;
    int c;
    int is_blank_line = 1;

    while (i < yyleng) {
        unsigned char ch = (unsigned char)yytext[i];
        if (ch == ' ' || ch == '\t') {
            if (ch == '\t') {
                had_tab_in_prefix = 1;
                if (first_tab_col < 0) {
                    first_tab_col = indent;
                }
            }
            indent++;
            i++;
        } else if (ch == 0xE2 && (i + 2) < yyleng &&
                   (unsigned char)yytext[i + 1] == 0x90 &&
                   (unsigned char)yytext[i + 2] == 0xA3) {
            indent++;
            i += 3;
        } else {
            i++;
        }
    }

    effective_indent = indent;
    if (CTX->block_scalar.indent == -1 && first_tab_col >= 0) {
        /* For implicit indentation, treat first tab as content boundary.
         * Tabs before that boundary are still indentation and rejected.
         */
        effective_indent = first_tab_col;
    }

    if (had_tab_in_prefix) {
        int required_indent = CTX->block_scalar.indent;
        if (required_indent == -1) {
            required_indent = effective_indent;
        }
        if (first_tab_col >= 0 && first_tab_col < required_indent) {
        yyerror(yylloc, yyscanner, "syntax error, tab indentation is not allowed in block scalars");
        CTX->semantic_error_count++;
        CTX->semantic_indent_tab_count++;
        }
    }

    while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0) {
        if (line_len < 4095) line_buf[line_len++] = c;
        if (c != ' ' && c != '\t') {
            is_blank_line = 0;
        }
    }
    if (c == '\n') line_buf[line_len++] = '\n';
    line_buf[line_len] = '\0';

    if (!CTX->block_scalar.first_content_seen) {
        if (is_blank_line && !had_tab_in_prefix) {
            if (indent > CTX->block_scalar.leading_empty_max_indent) {
                CTX->block_scalar.leading_empty_max_indent = indent;
            }
        } else {
            CTX->block_scalar.first_content_seen = 1;
            if (indent < CTX->block_scalar.leading_empty_max_indent) {
                yyerror(yylloc, yyscanner, "syntax error, wrong indentation after leading empty block-scalar lines");
                CTX->semantic_error_count++;
            }
        }
    }

    if (CTX->block_scalar.indent == -1) {
        CTX->block_scalar.indent = effective_indent;
    }

    if (effective_indent >= CTX->block_scalar.indent) {
        /* This is content line */
        *yylval = val_str(NULL); /* was strdup */
return BPART;
    } else {
        /* End of block scalar - line is less indented */
        int push_start = line_len - 1;
        if (line_len > 0 && line_buf[line_len - 1] == '\n') {
            push_start = line_len - 2;
            unput('\n');
        }
        for (int k = push_start; k >= 0; k--) {
            unput(line_buf[k]);
        }
        yyless(0);
        BEGIN(INDENT_CHECK);
        CTX->at_line_start = 1;
        /* No token, grammar will reduce bscalar */
    }
}

<BLOCK_SCALAR>. {
    /* Root-level block scalars may legitimately use zero-indented content. */
    if (CTX->block_scalar.indent <= 0 &&
        yytext[0] != '\n' &&
        yytext[0] != '\r') {
        char line_buf[4096];
        int line_len = 0;
        int c = yytext[0];

        line_buf[line_len++] = (char)c;
        while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0) {
            if (line_len < 4095) {
                line_buf[line_len++] = (char)c;
            }
        }
        if (c == '\n' && line_len < 4095) {
            line_buf[line_len++] = '\n';
        }
        line_buf[line_len] = '\0';

        if (CTX->block_scalar.indent == -1) {
            CTX->block_scalar.indent = 0;
        }
        CTX->block_scalar.first_content_seen = 1;
        *yylval = val_str(NULL); /* was strdup */
return BPART;
    }

    /* Non-indented line starts a new construct once block scalar is closed. */
    yyless(0);
    BEGIN(INDENT_CHECK);
}

<BLOCK_SCALAR><<EOF>> {
    BEGIN(INITIAL);
}




[^ \t\n\r\[\]{}!,&*%@|>\`'":]([^ \n\r:]|[ ]|:[^ \t\n\r\xE2])*/[ ]*":"([ \t\n]|{VSPACE}) {
    /* Plain map key: key: value (complex pattern allows colons inside key text) */
    if (FLOW_DELIM_SP == 0 && !CTX->at_line_start && !CTX->expecting_value && CTX->quoted_value_closed_on_line) {
        CTX->semantic_error_count++;
        CTX->semantic_inline_key_count++;
    }
    if (FLOW_DELIM_SP > 0) {
        /* In flow context, parse key text incrementally; avoid swallowing commas/brackets. */
        yyless(1);
        if (yytext[0] == ':') {
            CTX->expecting_value = 1;
            flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
        }
        *yylval = val_str(NULL); /* was strdup(yytext) */
        CTX->expecting_value = 0;
        flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
        BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
    }
    if (CTX->at_line_start && yytext[0] == '-' && yyleng > 1 &&
        (yytext[1] == ' ' || yytext[1] == '\t')) {
        /* Reuse BULLET tokenization for sequence indicators at line start. */
        yyless(1);
        CTX->at_line_start = 0;
        CTX->expecting_value = 1;
return BULLET;
    }
    *yylval = val_str(NULL); /* was strdup(yytext) */
    /* trim_trailing_spaces(yylval->string); */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    CTX->quoted_value_closed_on_line = 0;
return MAP_KEY;
}

[^ \t\n\r\[\]{}!,&*%@|>\`'"] {
    *yylval = val_str(NULL); /* was strdup(yytext) */
    CTX->at_line_start = 0;
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}

":"[a-zA-Z0-9\-\._]+ {
    if (FLOW_DELIM_SP > 0 && !CTX->expecting_value) {
        yyless(1);
        CTX->expecting_value = 1;
        flow_key_state_set(CTX, FLOW_KEY_NONE);
return COLON;
    }
    *yylval = val_str(NULL); /* was strdup(yytext) */
    CTX->expecting_value = 0;
    if (FLOW_DELIM_SP > 0) flow_key_state_set(CTX, FLOW_KEY_CANDIDATE);
    BEGIN(PLAIN_SCALAR_CONT);
return CH_RAW;
}

<PLAIN_SCALAR_CONT>":"/[ \t\n\r] {
    /* Colon followed by space/tab/newline ends the scalar */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>":"/[ \t]*[,}] {
    /* In explicit-key contexts, ':' before ','/'}' is a key/value separator. */
    if (CTX->complex_key_pending) {
        yyless(0);
        BEGIN(INITIAL);
    } else {
        *yylval = val_str(NULL); /* was strdup(":") */
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT>\n[ ]*-[ \t][^\n\r]*/\n {
    /* A nested/sibling block sequence indicator terminates plain continuation. */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>\n[ ]*-[ \t]*\n {
    /* Also terminate on bare dash items ("-" with optional trailing spaces). */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>\n[ ]*\n[ ]+([^:\n\r]|:[^ \t\n\r])*/\n {
    /* Blank line + indented continuation => preserve one logical newline. */
    const char *p = yytext + 1; /* skip first newline */
    while (*p == ' ') p++;
    if (*p == '\n') p++;
    while (*p == ' ') p++;
    if (FLOW_DELIM_SP > 0 && (*p == ']' || *p == '}' || *p == ',')) {
        yyless(0);
        BEGIN(INITIAL);
    } else {
    *yylval = val_str(NULL); /* was allocated newline + content */
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT>\n[ ]+([^:\n\r]|:[^ \t\n\r])*/\n {
    /* Indented continuation line => fold to space. */
    const char *p = yytext + 1; /* skip newline */
    while (*p == ' ') p++;
    if (FLOW_DELIM_SP > 0 && (*p == ']' || *p == '}' || *p == ',')) {
        yyless(0);
        BEGIN(INITIAL);
    } else {
    *yylval = val_str(NULL); /* was allocated space + content */
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT>[ \t]+/#[^\n\r]* {
    /* Comment starts after whitespace; terminate scalar before comment. */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>[ \t]+ {
    *yylval = val_str(NULL); /* was strdup(yytext) */
return CH_RAW;
}

<PLAIN_SCALAR_CONT>[^:\n\r\t,\[\]{} ]+ {
    *yylval = val_str(NULL); /* was strdup(yytext) */
return CH_RAW;
}

<PLAIN_SCALAR_CONT>":" {
    *yylval = val_str(NULL); /* was strdup(":") */
return CH_RAW;
}

<PLAIN_SCALAR_CONT>"\n" {
    /* Terminator for plain scalar */
    yyless(0);
    BEGIN(INITIAL);
}

<PLAIN_SCALAR_CONT>[\{\}\[\],] {
    if (FLOW_DELIM_SP > 0) {
        /* Flow indicators terminate plain scalars in flow context. */
        yyless(0);
        BEGIN(INITIAL);
    } else {
        *yylval = val_str(NULL); /* was strdup(yytext) */
return CH_RAW;
    }
}

<PLAIN_SCALAR_CONT><<EOF>> {
    BEGIN(INITIAL);
}

[ \t]+"#" {
    /* Skip rest of line */
    int c;
    while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0);
    if (c == '\n') unput('\n');
}

^"#" {
    /* Skip rest of line */
    int c;
    while ((c = input(yyscanner)) != '\n' && c != EOF && c != 0);
    if (c == '\n') unput('\n');
}
[ \t\r]+       { CTX->last_was_value = 0; /* skip whitespace */ }
{VSPACE}+      { CTX->last_was_value = 0; /* yaml-test-suite visible space marker */ }
{VEND}         { CTX->last_was_value = 0; /* yaml-test-suite end marker */ }
.                { return yytext[0]; }

<<EOF>> {
    if (PENDING_DEDENT_COUNT > 0) {
        *yylval = val_int(PENDING_DEDENT_COUNT);
        PENDING_DEDENT_COUNT--;
return DEDENT;
    }
    if (CTX->indent_sp > 0) {
        int dedent_count = CTX->indent_sp;
        CTX->indent_sp = 0;
        return return_dedent_count(CTX, dedent_count, yylval);
    }
    return YAML_GAMMA;
}

%%
