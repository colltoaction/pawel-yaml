%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Forward declarations */
typedef struct Event Event;
void attach_props(Event *e, char *anchor, char *tag);
int yyget_lineno(void *scanner);
%}

%code requires {
    #include <stddef.h>
    #include <stdint.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    /* ==================== Minimal AST (Event List) ==================== */
    typedef enum {
        EVT_SCALAR, EVT_SEQ_START, EVT_SEQ_END, EVT_MAP_START, EVT_MAP_END,
        EVT_DOC_START, EVT_DOC_END, EVT_ALIAS
    } EventType;

    struct Event {
        EventType type;
        char *value;
        char *anchor;
        char *tag;
        char quote; /* 0=plain, '"', '\'' */
        char style; /* 0=block, '[' or '{' for flow */
        struct Event *next;
    };

    typedef struct {
        char *anchor;
        char *tag;
    } NodeProps;
}

%code {
    int yylex(void *yylval_param, void *yyscanner);
    void yyerror(void *scanner, const char *s);
    
    struct Event* mk_evt(EventType type, char *val, char quote);
    struct Event* append_evt(struct Event *head, struct Event *tail);
    void emit_events(struct Event *head);
}

%glr-parser
%expect 31
%expect-rr 0
%define api.pure true
%define parse.error detailed
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    struct Event *events;
    NodeProps props;
}

%token <string> SCALAR BSCALAR QSCALAR SSCALAR TAG ANCHOR ALIAS
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET COLON QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%nonassoc QUESTION
%nonassoc COLON
%nonassoc SCALAR

%type <events> documents document_body implicit_document explicit_document
%type <events> explicit_documents
%type <events> node node_body scalar
%type <events> seq seq_entries seq_entry
%type <events> map map_entries map_entry
%type <events> flow_seq flow_map flow_seq_entries flow_map_entries flow_node
%type <events> optional_doc_end
%type <props> node_props
%type <events> collection entry_key

%destructor { free($$); } <string>

%%

stream:
    { fputs("+STR\n", stdout); }
    documents
    { fputs("-STR\n", stdout); }
    | { fputs("+STR\n-STR\n", stdout); } /* Empty stream */
    ;

documents:
    implicit_document[doc] { emit_events($doc); }
    | explicit_documents
    | implicit_document[doc] explicit_documents
    | DOC_END { 
        /* Bare document end marker - no output */
    }
    ;

explicit_documents:
    explicit_document[doc] { emit_events($doc); }
    | explicit_documents explicit_document[doc] { emit_events($doc); }
    ;

explicit_document:
    DOC_START document_body[body] optional_doc_end {
        struct Event *ds = mk_evt(EVT_DOC_START, "---", 0);
        struct Event *de = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(ds, append_evt($body, de));
    }
    | DOC_START optional_doc_end {
        struct Event *ds = mk_evt(EVT_DOC_START, "---", 0);
        struct Event *sc = mk_evt(EVT_SCALAR, "", 0);
        struct Event *de = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(ds, append_evt(sc, de));
    }
    | directives DOC_START document_body[body] optional_doc_end {
        struct Event *ds = mk_evt(EVT_DOC_START, "---", 0);
        struct Event *de = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(ds, append_evt($body, de));
    }
    | directives DOC_START optional_doc_end {
        struct Event *ds = mk_evt(EVT_DOC_START, "---", 0);
        struct Event *sc = mk_evt(EVT_SCALAR, "", 0);
        struct Event *de = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(ds, append_evt(sc, de));
    }
    ;

directives:
    directive
    | directives directive
    ;

directive:
    YAML_DIRECTIVE
    | TAG_DIRECTIVE SCALAR SCALAR { free($2); free($3); }
    | TAG_DIRECTIVE TAG SCALAR { free($2); free($3); }
    | TAG_DIRECTIVE TAG TAG { free($2); free($3); }
    ;

optional_doc_end:
    /* empty */ { $$ = NULL; }
    | DOC_END { $$ = NULL; }
    ;

implicit_document:
    document_body[body] {
        struct Event *ds = mk_evt(EVT_DOC_START, NULL, 0);
        struct Event *de = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(ds, append_evt($body, de));
    }
    ;

document_body:
    node[n] { $$ = $n; }
    | map_entries[entries] %dprec 3 {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        struct Event *me = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(ms, append_evt($entries, me));
    }
    | seq_entries[entries] %dprec 2 {
        struct Event *ss = mk_evt(EVT_SEQ_START, NULL, 0);
        struct Event *se = mk_evt(EVT_SEQ_END, NULL, 0);
        $$ = append_evt(ss, append_evt($entries, se));
    }
    | node_props[props] map_entries[entries] %dprec 4 {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        struct Event *me = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(ms, append_evt($entries, me));
        attach_props($$, $props.anchor, $props.tag);
    }
    | node_props[props] seq_entries[entries] %dprec 3 {
        struct Event *ss = mk_evt(EVT_SEQ_START, NULL, 0);
        struct Event *se = mk_evt(EVT_SEQ_END, NULL, 0);
        $$ = append_evt(ss, append_evt($entries, se));
        attach_props($$, $props.anchor, $props.tag);
    }
    ;

node:
    node_body[body] %dprec 2 { $$ = $body; }
    | node_props[props] node_body[body] %dprec 3 { $$ = $body; attach_props($$, $props.anchor, $props.tag); }
    | node_props[props] %dprec 1 { $$ = mk_evt(EVT_SCALAR, "", 0); attach_props($$, $props.anchor, $props.tag); }
    ;

node_body:
    scalar[s] { $$ = $s; }
    | ALIAS[a] { $$ = mk_evt(EVT_ALIAS, $a, 0); free($a); }
    | flow_seq[fs] { $$ = $fs; }
    | flow_map[fm] { $$ = $fm; }
    | collection[coll] { $$ = $coll; }
    ;

node_props:
    TAG[t] { $$.anchor = NULL; $$.tag = $t; }
    | ANCHOR[a] { $$.anchor = $a; $$.tag = NULL; }
    | ANCHOR[a] TAG[t] { $$.anchor = $a; $$.tag = $t; }
    | TAG[t] ANCHOR[a] { $$.anchor = $a; $$.tag = $t; }
    ;

scalar:
    SCALAR[s] { $$ = mk_evt(EVT_SCALAR, $s, 0); free($s); }
    | QSCALAR[s] { $$ = mk_evt(EVT_SCALAR, $s, '"'); free($s); }
    | SSCALAR[s] { $$ = mk_evt(EVT_SCALAR, $s, '\''); free($s); }
    | BSCALAR[s] { $$ = mk_evt(EVT_SCALAR, $s + 1, $s[0]); free($s); }
    ;

collection:
    map[m] { $$ = $m; }
    | seq[s] { $$ = $s; }
    ;

seq:
    INDENT seq_entries[entries] DEDENT {
        struct Event *s = mk_evt(EVT_SEQ_START, NULL, 0);
        struct Event *e = mk_evt(EVT_SEQ_END, NULL, 0);
        $$ = append_evt(s, append_evt($entries, e));
    }
    ;

seq_entries:
    seq_entry[entry] { $$ = $entry; }
    | seq_entries[entries] seq_entry[entry] { $$ = append_evt($entries, $entry); }
    ;

seq_entry:
    BULLET node[n] %dprec 2 { $$ = $n; }
    | BULLET map_entries[entries] %dprec 3 {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        struct Event *me = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(ms, append_evt($entries, me));
    }
    | BULLET %dprec 1 { $$ = mk_evt(EVT_SCALAR, "", 0); }
    ;

map:
    INDENT map_entries[entries] DEDENT {
        struct Event *s = mk_evt(EVT_MAP_START, NULL, 0);
        struct Event *e = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(s, append_evt($entries, e));
    }
    ;

map_entries:
    map_entry[entry] { $$ = $entry; }
    | map_entries[entries] map_entry[entry] { $$ = append_evt($entries, $entry); }
    ;

map_entry:
    /* Explicit key with explicit value */
    entry_key[key] COLON node[val] %dprec 3 { $$ = append_evt($key, $val); }
    | QUESTION node[key] COLON node[val] %dprec 5 { $$ = append_evt($key, $val); }
    
    /* Explicit key with implicit nil value (YAML spec: value defaults to null) */
    | entry_key[key] COLON %dprec 1 { $$ = append_evt($key, mk_evt(EVT_SCALAR, "", 0)); }
    | QUESTION node[key] COLON %dprec 1 { $$ = append_evt($key, mk_evt(EVT_SCALAR, "", 0)); }
    | QUESTION node[key] %dprec 2 { $$ = append_evt($key, mk_evt(EVT_SCALAR, "", 0)); }
    
    /* Implicit key with explicit value (key defaults to null) */
    | COLON node[val] %dprec 2 { $$ = append_evt(mk_evt(EVT_SCALAR, "", 0), $val); }
    | QUESTION COLON node[val] %dprec 2 { $$ = append_evt(mk_evt(EVT_SCALAR, "", 0), $val); }
    
    /* Both key and value implicit nil */
    | COLON %dprec 1 { $$ = append_evt(mk_evt(EVT_SCALAR, "", 0), mk_evt(EVT_SCALAR, "", 0)); }
    | QUESTION COLON %dprec 1 { $$ = append_evt(mk_evt(EVT_SCALAR, "", 0), mk_evt(EVT_SCALAR, "", 0)); }
    ;

entry_key:
    scalar[s] { $$ = $s; }
    | ALIAS[a] { $$ = mk_evt(EVT_ALIAS, $a, 0); free($a); }
    | flow_seq[fs] { $$ = $fs; }
    | flow_map[fm] { $$ = $fm; }
    ;

flow_seq:
    LBRACK flow_seq_entries[entries] RBRACK {
        struct Event *s = mk_evt(EVT_SEQ_START, NULL, 0);
        s->style = '[';
        $$ = append_evt(s, append_evt($entries, mk_evt(EVT_SEQ_END, NULL, 0)));
    }
    | LBRACK RBRACK {
        struct Event *s = mk_evt(EVT_SEQ_START, NULL, 0);
        s->style = '[';
        $$ = append_evt(s, mk_evt(EVT_SEQ_END, NULL, 0));
    }
    ;

flow_seq_entries:
    flow_node[n] { $$ = $n; }
    | flow_seq_entries[entries] COMMA flow_node[n] { $$ = append_evt($entries, $n); }
    | flow_seq_entries[entries] COMMA { $$ = $entries; }
    | COLON flow_node[val] {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        ms->style = '{';
        struct Event *key = mk_evt(EVT_SCALAR, "", 0);
        struct Event *me = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(ms, append_evt(key, append_evt($val, me)));
    }
    | COLON {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        ms->style = '{';
        struct Event *key = mk_evt(EVT_SCALAR, "", 0);
        struct Event *val = mk_evt(EVT_SCALAR, "", 0);
        struct Event *me = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(ms, append_evt(key, append_evt(val, me)));
    }
    ;

flow_map:
    LBRACE flow_map_entries[entries] RBRACE {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        ms->style = '{';
        struct Event *me = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(ms, append_evt($entries, me));
    }
    | LBRACE RBRACE {
        struct Event *ms = mk_evt(EVT_MAP_START, NULL, 0);
        ms->style = '{';
        $$ = append_evt(ms, mk_evt(EVT_MAP_END, NULL, 0));
    }
    ;

flow_map_entries:
    node[key] COLON node[val] { $$ = append_evt($key, $val); }
    | COLON node[val] %dprec 1 { $$ = append_evt(mk_evt(EVT_SCALAR, "", 0), $val); }
    | node[key] COLON %dprec 1 { $$ = append_evt($key, mk_evt(EVT_SCALAR, "", 0)); }
    | flow_map_entries[entries] COMMA node[key] COLON node[val] { $$ = append_evt($entries, append_evt($key, $val)); }
    | flow_map_entries[entries] COMMA COLON node[val] { $$ = append_evt($entries, append_evt(mk_evt(EVT_SCALAR, "", 0), $val)); }
    | flow_map_entries[entries] COMMA node[key] COLON { $$ = append_evt($entries, append_evt($key, mk_evt(EVT_SCALAR, "", 0))); }
    | flow_map_entries[entries] COMMA { $$ = $entries; }
    ;

flow_node: node[n] { $$ = $n; } ;

%%

void yyerror(void *scanner, const char *s) {
    fprintf(stderr, "%s\n", s);
}

struct Event* mk_evt(EventType type, char *val, char quote) {
    struct Event *e = calloc(1, sizeof(struct Event));
    e->type = type;
    if (val) e->value = strdup(val);
    e->quote = quote;
    return e;
}

void attach_props(struct Event *e, char *anchor, char *tag) {
    if (!e) return;
    if (anchor) {
        if (e->anchor) free(e->anchor);
        e->anchor = anchor;
    }
    if (tag) {
        if (e->tag) free(e->tag);
        e->tag = tag;
    }
}

struct Event* append_evt(struct Event *head, struct Event *tail) {
    if (!head) return tail;
    struct Event *curr = head;
    while (curr->next) curr = curr->next;
    curr->next = tail;
    return head;
}

static void print_indent(int depth) {
    for (int i = 0; i < depth; i++) fputc(' ', stdout);
}

/* Expand YAML shorthand tags to full canonical form */
const char* expand_tag(const char *tag) {
    if (!tag) return NULL;
    
    /* Standard shorthand tags */
    if (strcmp(tag, "!!str") == 0) return "tag:yaml.org,2002:str";
    if (strcmp(tag, "!!int") == 0) return "tag:yaml.org,2002:int";
    if (strcmp(tag, "!!float") == 0) return "tag:yaml.org,2002:float";
    if (strcmp(tag, "!!bool") == 0) return "tag:yaml.org,2002:bool";
    if (strcmp(tag, "!!null") == 0) return "tag:yaml.org,2002:null";
    if (strcmp(tag, "!!seq") == 0) return "tag:yaml.org,2002:seq";
    if (strcmp(tag, "!!map") == 0) return "tag:yaml.org,2002:map";
    
    /* Already expanded or custom tag - return as-is */
    return tag;
}

/* Apply line folding to double-quoted string values
 * YAML spec: newline + leading spaces -> single space
 * This matches the expected folding behavior for double-quoted strings
 */
static char* apply_line_folding(const char *value) {
    if (!value) return NULL;
    
    /* Count space needed for folded string */
    int result_len = 0;
    for (int i = 0; value[i]; i++) {
        if (value[i] == '\n') {
            /* Replace newline + spaces with single space */
            int j = i + 1;
            while (value[j] && (value[j] == ' ' || value[j] == '\t')) j++;
            result_len += 1;  /* Single space replaces newline + spaces */
            i = j - 1;        /* Continue from after spaces */
        } else {
            result_len++;
        }
    }
    
    /* Build folded string */
    char *folded = malloc(result_len + 1);
    int out_idx = 0;
    
    for (int i = 0; value[i]; i++) {
        if (value[i] == '\n') {
            /* Replace newline + spaces with single space */
            int j = i + 1;
            while (value[j] && (value[j] == ' ' || value[j] == '\t')) j++;
            folded[out_idx++] = ' ';
            i = j - 1;  /* Continue from after spaces */
        } else {
            folded[out_idx++] = value[i];
        }
    }
    folded[out_idx] = '\0';
    
    return folded;
}

void emit_events(struct Event *head) {
    static int depth = 1;
    while (head) {
        if (head->type == EVT_DOC_END || head->type == EVT_MAP_END || head->type == EVT_SEQ_END) depth--;
        print_indent(depth);
        switch (head->type) {
            case EVT_SCALAR:
                fputs("=VAL ", stdout);
                if (head->anchor) printf("&%s ", head->anchor + 1);
                if (head->tag) printf("<%s> ", expand_tag(head->tag));
                fputc(head->quote ? head->quote : ':', stdout);
                if (head->value) {
                    /* For double-quoted strings, apply line folding per YAML spec */
                    if (head->quote == '"') {
                        char *folded = apply_line_folding(head->value);
                        if (folded) {
                            fputs(folded, stdout);
                            free(folded);
                        }
                    } else {
                        fputs(head->value, stdout);
                    }
                }
                fputc('\n', stdout);
                break;
            case EVT_ALIAS:
                fputs("=ALI *", stdout); fputs(head->value + 1, stdout); fputc('\n', stdout);
                break;
            case EVT_SEQ_START:
                fputs("+SEQ", stdout);
                if (head->style == '[') fputs(" []", stdout);
                if (head->anchor) printf(" &%s", head->anchor + 1);
                if (head->tag) printf(" <%s>", expand_tag(head->tag));
                fputc('\n', stdout);
                break;
            case EVT_SEQ_END:   fputs("-SEQ\n", stdout); break;
            case EVT_MAP_START:
                fputs("+MAP", stdout);
                if (head->style == '{') fputs(" {}", stdout);
                if (head->anchor) printf(" &%s", head->anchor + 1);
                if (head->tag) printf(" <%s>", expand_tag(head->tag));
                fputc('\n', stdout);
                break;
            case EVT_MAP_END:   fputs("-MAP\n", stdout); break;
            case EVT_DOC_START: 
                if (head->value) printf("+DOC %s\n", head->value);
                else fputs("+DOC\n", stdout);
                break;
            case EVT_DOC_END:   fputs("-DOC\n", stdout); break;
            default: break;
        }
        if (head->type == EVT_DOC_START || head->type == EVT_MAP_START || head->type == EVT_SEQ_START) depth++;
        struct Event *temp = head;
        head = head->next;
        if (temp->value) free(temp->value);
        if (temp->anchor) free(temp->anchor);
        if (temp->tag) free(temp->tag);
        free(temp);
    }
}

int yylex_init(void **scanner);
int yylex_destroy(void *scanner);
void yyset_in(FILE *in, void *scanner);

int mrl_entry(int argc, char **argv) {
    (void)argc; (void)argv;
    void *scanner; yylex_init(&scanner); yyset_in(stdin, scanner);
    int result = yyparse(scanner);
    yylex_destroy(scanner);
    return result;
}

int main(int argc, char **argv) {
    return mrl_entry(argc, argv);
}
