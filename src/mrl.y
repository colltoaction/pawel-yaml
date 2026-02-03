%{
#include <stdlib.h>
#include <string.h>
%}

%code {
    int yylex(YYSTYPE *yylval_param, void *yyscanner);
}

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

    typedef struct Event {
        EventType type;
        char *value;
        char *anchor;
        char *tag;
        char quote; /* 0=plain, '"', '\'' */
        struct Event *next;
    } Event;

    Event* mk_evt(EventType type, char *val, char quote);
    Event* append_evt(Event *head, Event *tail);
    void emit_events(Event *head);
}

%define api.pure true
%define parse.error detailed
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    struct Event *events;
}

%token <string> SCALAR
%token <string> BSCALAR
%token <string> QSCALAR
%token <string> SSCALAR
%token <string> TAG
%token <string> ANCHOR
%token <string> ALIAS
%token YAML_DIRECTIVE TAG_DIRECTIVE DOC_START DOC_END BULLET COLON QUESTION
%token INDENT DEDENT LBRACK RBRACK LBRACE RBRACE COMMA

%nonassoc QUESTION
%nonassoc COLON
%nonassoc SCALAR

%type <events> implicit_document explicit_document explicit_documents
%type <events> nodes node node_body scalar
%type <events> seq seq_entries seq_entry
%type <events> map map_entries map_entry
%type <events> flow_seq flow_map flow_seq_entries flow_map_entries flow_node
%type <events> optional_doc_end

%destructor { if ($$) free($$); } <string>

%%

stream:
    { fputs("+STR\n", stdout); }
    implicit_document[doc]
    { emit_events($doc); fputs("-STR\n", stdout); }
    | { fputs("+STR\n", stdout); }
    explicit_documents[docs]
    { emit_events($docs); fputs("-STR\n", stdout); }
    | { fputs("+STR\n", stdout); }
    implicit_document[doc] explicit_documents[docs]
    { emit_events($doc); emit_events($docs); fputs("-STR\n", stdout); }
    | { fputs("+STR\n-STR\n", stdout); }
    ;

explicit_documents:
    explicit_document[doc] { $$ = $doc; }
    | explicit_documents[docs] explicit_document[doc] { $$ = append_evt($docs, $doc); }
    ;

directives:
    directive
    | directives directive
    ;

directive:
    YAML_DIRECTIVE
    | TAG_DIRECTIVE SCALAR[s1] SCALAR[s2] { free($s1); free($s2); }
    | TAG_DIRECTIVE TAG[t] SCALAR[s] { free($t); free($s); }
    | TAG_DIRECTIVE TAG[t1] TAG[t2] { free($t1); free($t2); }
    ;

explicit_document:
    DOC_START nodes[n] optional_doc_end[end_evt] {
        Event *e = mk_evt(EVT_DOC_START, "---", 0);
        Event *end = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(e, append_evt($n, append_evt($end_evt, end)));
    }
    | directives DOC_START nodes[n] optional_doc_end[end_evt] {
        Event *e = mk_evt(EVT_DOC_START, "---", 0);
        Event *end = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(e, append_evt($n, append_evt($end_evt, end)));
    }
    ;

optional_doc_end:
    /* empty */ { $$ = NULL; }
    | DOC_END { $$ = NULL; }
    ;

implicit_document:
    nodes[n] {
        Event *e = mk_evt(EVT_DOC_START, NULL, 0);
        Event *end = mk_evt(EVT_DOC_END, NULL, 0);
        $$ = append_evt(e, append_evt($n, end));
    }
    ;

nodes:
    node[n] { $$ = $n; }
    ;

node:
    node_body[body] { $$ = $body; }
    | TAG[t] node_body[body] {
        if ($body) {
            $body->tag = $t;
        }
        $$ = $body;
    }
    | ANCHOR[a] node_body[body] {
        if ($body) {
            $body->anchor = $a;
        }
        $$ = $body;
    }
    | ANCHOR[a] TAG[t] node_body[body] {
        if ($body) {
            $body->anchor = $a;
            $body->tag = $t;
        }
        $$ = $body;
    }
    | TAG[t] ANCHOR[a] node_body[body] {
        if ($body) {
            $body->tag = $t;
            $body->anchor = $a;
        }
        $$ = $body;
    }
    ;

node_body:
    scalar[s] { $$ = $s; }
    | ALIAS[a] { $$ = mk_evt(EVT_ALIAS, $a, 0); free($a); }
    | seq[s] { $$ = $s; }
    | map[m] { $$ = $m; }
    | flow_seq[fs] { $$ = $fs; }
    | flow_map[fm] { $$ = $fm; }
    ;

scalar:
    SCALAR[s] { $$ = mk_evt(EVT_SCALAR, $s, 0); free($s); }
    | QSCALAR[qs] { $$ = mk_evt(EVT_SCALAR, $qs, '"'); free($qs); }
    | SSCALAR[ss] { $$ = mk_evt(EVT_SCALAR, $ss, '\''); free($ss); }
    | BSCALAR[bs] { $$ = mk_evt(EVT_SCALAR, $bs + 1, $bs[0]); free($bs); }
    ;

seq:
    seq_entries[entries] {
        Event *s = mk_evt(EVT_SEQ_START, NULL, 0);
        Event *e = mk_evt(EVT_SEQ_END, NULL, 0);
        $$ = append_evt(s, append_evt($entries, e));
    }
    ;

seq_entries:
    seq_entry[entry] { $$ = $entry; }
    | seq_entries[entries] seq_entry[entry] { $$ = append_evt($entries, $entry); }
    ;

seq_entry:
    BULLET node[n] { $$ = $n; }
    ;

map:
    map_entries[entries] {
        Event *s = mk_evt(EVT_MAP_START, NULL, 0);
        Event *e = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(s, append_evt($entries, e));
    }
    ;

map_entries:
    map_entry[entry] { $$ = $entry; }
    | map_entry[entry] map_entries[entries] { $$ = append_evt($entry, $entries); }
    ;

map_entry:
    node[key] COLON node[val] { $$ = append_evt($key, $val); }
    | QUESTION node[key] COLON node[val] { $$ = append_evt($key, $val); }
    ;

flow_seq:
    LBRACK RBRACK {
        Event *s = mk_evt(EVT_SEQ_START, NULL, 0);
        Event *e = mk_evt(EVT_SEQ_END, NULL, 0);
        $$ = append_evt(s, e);
    }
    | LBRACK flow_seq_entries[entries] RBRACK {
        Event *s = mk_evt(EVT_SEQ_START, NULL, 0);
        Event *e = mk_evt(EVT_SEQ_END, NULL, 0);
        $$ = append_evt(s, append_evt($entries, e));
    }
    ;

flow_seq_entries:
    flow_node[n] { $$ = $n; }
    | flow_seq_entries[entries] COMMA flow_node[n] { $$ = append_evt($entries, $n); }
    | flow_seq_entries[entries] COMMA { $$ = $entries; }
    ;

flow_map:
    LBRACE RBRACE {
        Event *s = mk_evt(EVT_MAP_START, NULL, 0);
        Event *e = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(s, e);
    }
    | LBRACE flow_map_entries[entries] RBRACE {
        Event *s = mk_evt(EVT_MAP_START, NULL, 0);
        Event *e = mk_evt(EVT_MAP_END, NULL, 0);
        $$ = append_evt(s, append_evt($entries, e));
    }
    ;

flow_map_entries:
    node[key] COLON node[val] { $$ = append_evt($key, $val); }
    | flow_map_entries[entries] COMMA node[key] COLON node[val] { $$ = append_evt($entries, append_evt($key, $val)); }
    ;

flow_node:
    node[n] { $$ = $n; }
    ;

%%

Event* mk_evt(EventType type, char *val, char quote) {
    Event *e = malloc(sizeof(Event));
    e->type = type;
    e->value = val ? strdup(val) : NULL;
    e->anchor = NULL;
    e->tag = NULL;
    e->quote = quote;
    e->next = NULL;
    return e;
}

Event* append_evt(Event *head, Event *tail) {
    if (!head) return tail;
    if (!tail) return head;
    Event *curr = head;
    while (curr->next) curr = curr->next;
    curr->next = tail;
    return head;
}

void emit_events(Event *e) {
    while (e) {
        switch (e->type) {
            case EVT_DOC_START:
                if (e->value) printf("+DOC %s\n", e->value);
                else printf("+DOC\n");
                break;
            case EVT_DOC_END:
                printf("-DOC\n");
                break;
            case EVT_SCALAR:
                printf("  =VAL ");
                if (e->anchor) printf("&%s ", e->anchor);
                if (e->tag) printf("<%s> ", e->tag);
                printf("%c%s\n", e->quote ? e->quote : ':', e->value);
                break;
            case EVT_SEQ_START:
                printf("  +SEQ");
                if (e->anchor) printf(" &%s", e->anchor);
                if (e->tag) printf(" <%s>", e->tag);
                printf("\n");
                break;
            case EVT_SEQ_END:
                printf("  -SEQ\n");
                break;
            case EVT_MAP_START:
                printf("  +MAP");
                if (e->anchor) printf(" &%s", e->anchor);
                if (e->tag) printf(" <%s>", e->tag);
                printf("\n");
                break;
            case EVT_MAP_END:
                printf("  -MAP\n");
                break;
            case EVT_ALIAS:
                printf("  =ALI *%s\n", e->value);
                break;
        }
        e = e->next;
    }
}

void yyerror(void *scanner, const char *s) {
    fprintf(stderr, "Bison error: %s\n", s);
}

int yaml_parse(void *scanner) {
    return yyparse(scanner);
}

int main(int argc, char **argv) {
    void *scanner;
    yylex_init(&scanner);
    yyset_in(stdin, scanner);
    int res = yaml_parse(scanner);
    yylex_destroy(scanner);
    return res;
}
