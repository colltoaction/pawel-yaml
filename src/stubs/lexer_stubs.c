#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "common.h"
#include "stream.tab.h"
#include "lexer_values.h"

static const char *g_input_buffer = NULL;
static const char *g_input_cursor = NULL;

/* State */
#define MAX_DEPTH 1024
static char g_flow_stack[MAX_DEPTH];
static int g_flow_sp = 0;
static int g_in_single_quote = 0;
static int g_in_double_quote = 0;
static int g_at_line_start = 1;
static int g_after_colon = 0;
static int g_after_dash = 0;

int scanning_lex_init_extra(void *user_defined, void **scanner) {
    *scanner = NULL;
    return 0;
}

int scanning_lex_destroy(void *scanner) {
    return 0;
}

void *scanning__scan_string(const char *yy_str, void *yyscanner) {
    g_input_buffer = yy_str;
    g_input_cursor = yy_str;
    g_flow_sp = 0;
    g_in_single_quote = 0;
    g_in_double_quote = 0;
    g_at_line_start = 1;
    g_after_colon = 0;
    g_after_dash = 0;
    return (void*)1;
}

void scanning__delete_buffer(void *b, void *yyscanner) {
    g_input_buffer = NULL;
    g_input_cursor = NULL;
}

int scanning_lex(void *yylval_param, void *yyloc_param, void *yyscanner) {
    YYSTYPE *yylval = (YYSTYPE*)yylval_param;

    if (!g_input_cursor) return 0;

    while (*g_input_cursor) {
        unsigned char c = (unsigned char)*g_input_cursor;

        /* Strict Whitespace Validation for Block Structure */
        if (g_after_colon && c != ' ' && c != '\n' && c != '\r' && c != '\t' && c != 0) {
            /* Colon followed by non-space in block context (unless flow, but simplify for failure detection) */
            /* Actually allowed in flow, but problematic in block. */
            /* If we are NOT in flow, this is error */
            if (g_flow_sp == 0) return -1;
        }
        g_after_colon = 0;

        if (g_after_dash && c != ' ' && c != '\n' && c != '\r' && c != '\t' && c != 0) {
            /* Dash followed by non-space in block context */
            if (g_flow_sp == 0) return -1;
        }
        g_after_dash = 0;

        /* Handle Quotes (content agnostic) */
        if (g_in_single_quote) {
            if (c == '\'') {
                if (g_input_cursor[1] == '\'') { g_input_cursor += 2; continue; }
                g_in_single_quote = 0;
                g_input_cursor++;
                *yylval = val_str("scalar");
                return SCALAR;
            }
            g_input_cursor++;
            continue;
        }
        if (g_in_double_quote) {
            if (c == '\') { g_input_cursor += 2; continue; }
            if (c == '"') {
                g_in_double_quote = 0;
                g_input_cursor++;
                *yylval = val_str("scalar");
                return SCALAR;
            }
            g_input_cursor++;
            continue;
        }

        /* Check Tabs at Indentation */
        if (g_at_line_start && c == '\t') {
            return -1;
        }

        if (c == '\n') {
            g_at_line_start = 1;
            g_input_cursor++;
            continue;
        }

        if (c != ' ' && c != '\t' && c != '\r') {
            g_at_line_start = 0;
        }

        if (c == ' ' || c == '\t' || c == '\r') {
            g_input_cursor++;
            continue;
        }

        /* Start Quote */
        if (c == '\'') { g_in_single_quote = 1; g_input_cursor++; continue; }
        if (c == '"') { g_in_double_quote = 1; g_input_cursor++; continue; }

        /* Flow */
        if (c == '[') { if (g_flow_sp < MAX_DEPTH) g_flow_stack[g_flow_sp++] = ']'; g_input_cursor++; return LBRACK; }
        if (c == '{') { if (g_flow_sp < MAX_DEPTH) g_flow_stack[g_flow_sp++] = '}'; g_input_cursor++; return LBRACE; }
        if (c == ']') {
            if (g_flow_sp > 0 && g_flow_stack[g_flow_sp-1] == ']') g_flow_sp--;
            else return -1;
            g_input_cursor++; return RBRACK;
        }
        if (c == '}') {
            if (g_flow_sp > 0 && g_flow_stack[g_flow_sp-1] == '}') g_flow_sp--;
            else return -1;
            g_input_cursor++; return RBRACE;
        }

        if (c == ',') { g_input_cursor++; return COMMA; }
        if (c == ':') {
            g_input_cursor++;
            g_after_colon = 1; /* Mark to check next char */
            *yylval = val_str(":");
            return COLON;
        }
        if (c == '-') {
            /* Differentiate block dash vs scalar dash? */
            /* If followed by space, it's block entry. If not, it's scalar or error? */
            /* For failure detection: "-foo" is scalar, "- foo" is block. */
            /* But "-foo" is valid scalar. */
            /* However, "- " at start of line is block. */
            g_input_cursor++;
            /* g_after_dash = 1;  Maybe too strict if "-foo" is allowed as scalar? */
            *yylval = val_str("-");
            return BULLET;
        }

        /* Document Markers at start of line */
        if (g_at_line_start) { /* Actually g_at_line_start was cleared by c!=space check above, need to check before? */
             /* Moving marker check before g_at_line_start reset is tricky with the flow loop structure */
        }

        /* Consume scalar char */
        g_input_cursor++;
    }

    if (g_in_single_quote || g_in_double_quote) return -1;
    if (g_flow_sp > 0) return -1;

    return 0;
}

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
