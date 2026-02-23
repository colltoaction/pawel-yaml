%code top {
/* Forward declare yyscan_t for reentrant scanner type safety */
typedef void* yyscan_t;
}

%code requires {
#include "common.h"
#include "lexer_context.h"
}

%glr-parser
%expect 162
%expect-rr 75

%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "node.tab.h"  /* Include generated header for type definitions */

/* Types are declared in %code requires and included via node.tab.h */

/* === EXTERNAL DECLARATIONS FROM scanning.l === */
/* These are defined in scanning.l as non-static functions */
extern LexerContext *lexer_context_new(void);
extern void lexer_context_free(LexerContext *ctx);
int has_arg(const char *flag);
int parser_is_nonfatal_message(const char *msg);
int validate_lexical_semantics(const LexerContext *ctx, void *scanner);
int gamma_from_token(YAMLBisonToken token);
Indented indented_from_level(int level);
Indented indented_dedent(Indented indented);
char *string_unit(void);
char *string_intern_slice(const char *start, size_t len);
char *string_concat(const char *left, const char *right);
void string_pool_reset(void);
void monoid_stream_open(void);
void monoid_stream_close(void);
void monoid_doc_open(int explicit_start);
void monoid_doc_close(int explicit_end);
void add_event(YAMLEventType type);
void add_scalar_event(const char *value, char quote_style);
void add_alias_event(const char *name);
void ir_seq_start(const char *anchor, const char *tag, const char *marker);
void ir_seq_end(void);
void ir_map_start(const char *anchor, const char *tag, const char *marker);
void ir_map_end(void);
void ir_scalar(const char *value, char style, const char *anchor, const char *tag);
void ir_scalar_empty(void);
void ir_alias(const char *name);
void emit_map_key(const ScalarValue *k);
ScalarValue parse_plain_map_key(char *value);
ScalarValue parse_anchored_map_key(char *delimited_string);
extern int parse_error_count;
extern int parse_nonfatal_count;
extern int g_silent_parse_errors;
extern FILE *yyout;

int node_scan_lex(void *yylval_param, void *yyloc_param, void *yyscanner);
int node_yy_parse(void *scanner);
int node_yy_drive_lex(void *yylval_param, void *yyloc_param, void *scanner);
int node_yy_drive_parse(void *scanner);
void stream_yy_error(void *yylloc, void *scanner, const char *s);
void node_yy_error(void *yylloc, void *scanner, const char *s) { stream_yy_error(yylloc, scanner, s); }

#define node_yy_lex node_yy_drive_lex

int node_yy_drive_lex(void *yylval_param, void *yyloc_param, void *scanner) {
    return yaml_processor_drive_lex(node_scan_lex, yylval_param, yyloc_param, scanner);
}

int node_yy_drive_parse(void *scanner) {
    return yaml_processor_drive_parse(node_yy_parse, scanner);
}

static void node_yy_recover_error(void *scanner, const char *msg) {
    yaml_processor_raise_error(stream_yy_error, scanner, msg);
}

#define RECOVER(msg) do { node_yy_recover_error(scanner, (msg)); } while (0)
#define RECOVER_SYNC(msg) do { node_yy_recover_error(scanner, (msg)); yyerrok; } while (0)
%}

%define api.pure true
%define api.prefix {node_yy_}
%define parse.error verbose
%start node_with_indent
%locations
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    int ival;
    NodeProps props;
    ScalarValue scalar;
}

/* Indentation Tokens (Shared with Stream) */
%token <ival> INDENT DEDENT

/* Block Structure Tokens */
%token BULLET BULLET_EOL
%token COLON COLON_EMPTY COLON_IMPLICIT QUESTION

/* Flow Structure Tokens */
%token LBRACK RBRACK LBRACE RBRACE COMMA

/* Data Tokens */
%token <string> SCALAR BSCALAR QSCALAR SSCALAR
%token TAG ANCHOR ALIAS
%token MAP_KEY ANCHOR_MAP_KEY
%token BAD_TAG

/* Scalar Parts (Low Level) */
%token <string> CH_RAW CH_ESC_N CH_ESC_T CH_ESC_R CH_ESC_0 CH_ESC_BS CH_ESC_QU CH_ESC_SL
%token QPART BPART

/* Note: DOC_START, DOC_END, and DIRECTIVE tokens are removed as they are stream-level only */

%type <props> node_props
%type <props> empty_props
%type <scalar> scalar_item scalar_payload block_content block
%type <scalar> map_key
%type <string> scalar_parts qscalar qparts qpart bscalar

/* TODO Fix destructor double free in GLR mode + manual free in actions */
/* Destructors handle cleanup when symbols are discarded by the parser. */
%destructor { $$ = NULL; } <string>
%destructor { $$.anchor = NULL; $$.tag = NULL; } <props>
%destructor { $$.value = NULL; $$.anchor = NULL; $$.tag = NULL; } <scalar>

%locations

/* Precedence declarations for disambiguation */
%left COMMA RBRACE RBRACK
%precedence COLON
%precedence SCALAR QSCALAR SSCALAR BSCALAR

%%

/* Node grammar layer (parser/closure lives in yaml.y). */

node_with_indent:
    node
    ;

block:
    INDENT block_content DEDENT { $$ = $2; }
    ;

block_content:
    scalar_item { $$ = $1; }
    | collection_value_entries {
        $$.type = ':'; $$.value = NULL; $$.anchor = NULL; $$.tag = NULL;
    }
    | collection_pair_entries {
        $$.type = ':'; $$.value = NULL; $$.anchor = NULL; $$.tag = NULL;
    }
    | alias_node {
        $$.type = '*'; $$.value = NULL; $$.anchor = NULL; $$.tag = NULL;
    }
    ;

node:
    collection_with_props
    | collection_no_props
    | scalar_node
    | alias_node
    | error { RECOVER("Recovering at node boundary"); }
    ;

/* Value-position node (after COLON): avoid non-indented block collections
 * after bare node properties to reduce spurious ambiguities.
 */
value_node:
    value_collection_with_props
    | collection_no_props
    | scalar_node
    | alias_node
    | ANCHOR[a] TAG[t] { ir_map_start($a, $t, NULL); add_event(EVENT_MAPPING_START); }
      block
      map_end
    | TAG[t] ANCHOR[a] { ir_map_start($a, $t, NULL); add_event(EVENT_MAPPING_START); }
      block
      map_end
    | error { RECOVER("Recovering at value node boundary"); }
    ;

scalar_node:
    empty_props[props] scalar_payload[s] { if ($s.value) { ir_scalar($s.value, $s.type, $props.anchor, $props.tag); add_scalar_event($s.value, $s.type); } }
    | node_props[props] scalar_payload[s] { if ($s.value) { ir_scalar($s.value, $s.type, $props.anchor, $props.tag); add_scalar_event($s.value, $s.type); } }
    | node_props[props] { ir_scalar("", ':', $props.anchor, $props.tag); add_scalar_event("", ':'); }
    ;

alias_node:
    ALIAS[a] { ir_alias($a); add_alias_event($a); }
    ;

scalar_item:
    scalar_parts { $$.type = ':'; $$.value = $1; }
    | qscalar { $$.type = '"'; $$.value = $1; }
    | SSCALAR[val] { $$.type = '\''; $$.value = $val; }
    | bscalar { $$.type = '|'; /* Placeholder type, fix later */ $$.value = $1; }
    ;

scalar_payload:
    scalar_item[s] { $$ = $s; }
    ;

qscalar:
    qparts QSCALAR { $$ = $1; }
    ;

scalar_parts:
    CH_RAW { $$ = $1; }
    | scalar_parts CH_RAW { $$ = string_concat($1, $2); }
    ;

qparts:
    %empty { $$ = string_unit(); }
    | qparts qpart { $$ = string_concat($1, $2); }
    ;

qpart:
    CH_RAW { $$ = $1; }
    | CH_ESC_N { $$ = strdup("\n"); }
    | CH_ESC_T { $$ = strdup("\t"); }
    | CH_ESC_R { $$ = strdup("\r"); }
    | CH_ESC_BS { $$ = strdup("\\"); }
    | CH_ESC_QU { $$ = strdup("\""); }
    | CH_ESC_SL { $$ = strdup("/"); }
    | CH_ESC_0 { $$ = string_unit(); }
    ;

bscalar:
    BPART { $$ = $1; }
    | bscalar BPART { $$ = string_concat($1, $2); }
    ;

empty_props:
    %empty { $$.anchor = NULL; $$.tag = NULL; }
    ;

node_props:
    ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    | TAG[t] ANCHOR[a] { $$.anchor = $a; $$.tag = $t; }
    | BAD_TAG { RECOVER_SYNC("Malformed tag syntax"); $$.anchor = NULL; $$.tag = NULL; }
    ;

/* Explicit collection abstraction: values (SEQ) vs key-values (MAP). */
collection_no_props:
    sequence_no_props %dprec 1
    | mapping_no_props %dprec 2
    ;

collection_with_props:
    sequence_with_props
    | mapping_with_props
    ;

value_collection_with_props:
    collection_with_props
    ;

sequence_no_props:
    seq_start collection_value_entries seq_end %dprec 3
    | flow_sequence_no_props
    ;

flow_sequence_no_props:
    flow_lbrack flow_seq_init collection_flow_value_entries flow_rbrack seq_end flow_lvl_dec
    ;

flow_lvl_dec:
    %empty
    ;

seq_start:
    seq_start_ir seq_open_event
    ;

seq_start_ir:
    %empty { ir_seq_start(NULL, NULL, NULL); }
    ;

seq_open_event:
    %empty { add_event(EVENT_SEQUENCE_START); }
    ;

seq_end:
    seq_end_ir seq_end_event
    ;

seq_end_ir:
    %empty { ir_seq_end(); }
    ;

seq_end_event:
    %empty { add_event(EVENT_SEQUENCE_END); }
    ;

flow_seq_init:
    flow_seq_init_ir seq_open_event
    ;

flow_seq_init_ir:
    %empty { ir_seq_start(NULL, NULL, "[]"); }
    ;

flow_lbrack:
    LBRACK
    ;

flow_rbrack:
    RBRACK
    ;

sequence_with_props:
    node_props[props]
      { ir_seq_start($props.anchor, $props.tag, NULL); }
      seq_open_event
      collection_value_entries
      seq_end
      %dprec 3
    | value_sequence_with_props
    ;

value_sequence_with_props:
    node_props[props]
      { ir_seq_start($props.anchor, $props.tag, NULL); }
      seq_open_event
      block
      seq_end
    | node_props[props]
      flow_lbrack
      { ir_seq_start($props.anchor, $props.tag, "[]"); }
      seq_open_event
      collection_flow_value_entries
      flow_rbrack
      seq_end
      flow_lvl_dec
    ;

collection_value_entries:
    seq_entry
    | collection_value_entries seq_entry
    ;

/* indented_seq_entries replaced by block */

seq_entry:
    BULLET node %dprec 5
    | BULLET node block %dprec 6
    | BULLET map_init map_key[k] { emit_map_key(&$k); } COLON node block map_end %dprec 6
    | BULLET_EOL seq_entry_empty_scalar %dprec 2
    | BULLET_EOL block %dprec 4
    | BULLET error { RECOVER("Malformed sequence item"); } %dprec 2
    | BULLET_EOL error { RECOVER("Malformed sequence item"); } %dprec 2
    ;

seq_entry_empty_scalar:
    seq_entry_empty_scalar_ir seq_entry_empty_scalar_event
    ;

seq_entry_empty_scalar_ir:
    %empty { ir_scalar_empty(); }
    ;

seq_entry_empty_scalar_event:
    %empty { add_scalar_event("", ':'); }
    ;

collection_flow_value_entries:
    %empty
    | flow_seq_entry
    | collection_flow_value_entries COMMA flow_seq_entry
    | collection_flow_value_entries COMMA
    ;

flow_seq_entry:
    node %dprec 1
    | flow_map_entry_pair %dprec 2
    | error { RECOVER("Malformed flow sequence entry"); }
    ;

mapping_no_props:
    map_init collection_pair_entries map_end
    | flow_mapping_no_props
    ;

flow_mapping_no_props:
    flow_lbrace flow_map_init collection_flow_pair_entries flow_rbrace map_end flow_lvl_dec
    ;

map_init:
    map_init_ir map_open_event
    ;

map_init_ir:
     %empty { ir_map_start(NULL, NULL, NULL); }
    ;

map_open_event:
    %empty { add_event(EVENT_MAPPING_START); }
    ;

map_end:
    map_end_ir map_end_event
    ;

map_end_ir:
    %empty { ir_map_end(); }
    ;

map_end_event:
    %empty { add_event(EVENT_MAPPING_END); }
    ;

flow_map_init:
    flow_map_init_ir map_open_event
    ;

flow_map_init_ir:
    %empty { ir_map_start(NULL, NULL, "{}"); }
    ;

flow_lbrace:
    LBRACE
    ;

flow_rbrace:
    RBRACE
    ;

mapping_with_props:
    value_mapping_with_props
    | node_props[props]
      { ir_map_start($props.anchor, $props.tag, NULL); }
      map_open_event
      collection_pair_entries
      map_end
    ;

value_mapping_with_props:
    node_props[props]
      { ir_map_start($props.anchor, $props.tag, NULL); }
      map_open_event
      block
      map_end
    | node_props[props]
      flow_lbrace
      { ir_map_start($props.anchor, $props.tag, "{}"); }
      map_open_event
      collection_flow_pair_entries
      flow_rbrace
      map_end
      flow_lvl_dec
    ;

collection_pair_entries:
    map_entry
    | collection_pair_entries map_entry
    ;

/* indented_map_entries replaced by block */

/* indented_value_node replaced by block */

map_key:
    MAP_KEY[val] { $$ = parse_plain_map_key($val); }
    | ANCHOR_MAP_KEY[val] { $$ = parse_anchored_map_key($val); }
    ;

flow_collection:
    flow_sequence_no_props
    | flow_mapping_no_props
    ;

complex_key_node:
    flow_collection
    | node_props flow_collection
    | alias_node
    ;

map_entry:
    map_key[k] { emit_map_key(&$k); } COLON value_node %dprec 5
    | map_key[k] { emit_map_key(&$k); } COLON seq_entry_empty_scalar %dprec 5
    | map_key[k] { emit_map_key(&$k); } COLON_IMPLICIT seq_entry_empty_scalar %dprec 5
    | complex_key_node COLON value_node %dprec 50
    | complex_key_node COLON seq_entry_empty_scalar %dprec 50
    | complex_key_node COLON_IMPLICIT seq_entry_empty_scalar %dprec 50
    | QUESTION node COLON value_node %dprec 4
    | QUESTION node seq_entry_empty_scalar %dprec 3
    | MAP_KEY error { RECOVER("Malformed mapping entry"); }
    | QUESTION error { RECOVER("Malformed complex mapping entry"); }
    | error { RECOVER("Invalid mapping structure"); }
    ;

collection_flow_pair_entries:
    %empty
    | flow_map_entry
    | collection_flow_pair_entries COMMA flow_map_entry
    | collection_flow_pair_entries COMMA
    ;

flow_map_entry:
    node seq_entry_empty_scalar %dprec 1
    | flow_map_entry_pair %dprec 2
    | error { RECOVER("Malformed flow mapping entry"); }
    ;

flow_map_entry_pair:
    node COLON node %dprec 3
    | node COLON_EMPTY seq_entry_empty_scalar %dprec 2
    | node COLON seq_entry_empty_scalar %dprec 1
    | COLON seq_entry_empty_scalar node %dprec 3
    | COLON_EMPTY seq_entry_empty_scalar seq_entry_empty_scalar %dprec 1
    | QUESTION node COLON node %dprec 4
    | QUESTION node COLON_EMPTY seq_entry_empty_scalar %dprec 2
    | QUESTION node COLON seq_entry_empty_scalar %dprec 1
    | QUESTION seq_entry_empty_scalar seq_entry_empty_scalar %dprec 1
    ;

%%
