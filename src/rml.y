%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void rml_error(void *scanner, const char *s);
int rml_lex(void *yylval_param, void *yyscanner);

/* Presentation helpers */
static int depth = 1;
static void print_indent() { for(int i=0; i<depth; i++) fputc(' ', stdout); }
static const char* expand_tag(const char *tag) {
    if (!tag || !tag[0]) return NULL;
    if (strcmp(tag, "!!str") == 0) return "tag:yaml.org,2002:str";
    if (strcmp(tag, "!!int") == 0) return "tag:yaml.org,2002:int";
    if (strcmp(tag, "!!map") == 0) return "tag:yaml.org,2002:map";
    if (strcmp(tag, "!!seq") == 0) return "tag:yaml.org,2002:seq";
    return tag;
}

%}

%code requires {
    typedef struct {
        char *value;
        char *anchor;
        char *tag;
        char quote;
    } RMLNode;
}

%define api.pure true
%define api.prefix {rml_}
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    RMLNode node;
}

%token <node> RML_VAL RML_ALIAS RML_PROP
%token RML_DOC_START RML_DOC_END RML_SEQ_START RML_SEQ_END RML_MAP_START RML_MAP_END

%type <node> maybe_prop

%%

stream: 
    { printf("+STR\n"); }
    docs 
    { printf("-STR\n"); }
    ;

docs: /* empty */ | docs doc ;

doc: RML_DOC_START 
    { printf(" +DOC\n"); depth = 2; }
    node 
    RML_DOC_END 
    { printf(" -DOC\n"); }
    ;

node: 
    maybe_prop RML_VAL {
        print_indent(); printf("=VAL ");
        if ($1.anchor) printf("&%s ", $1.anchor);
        const char *t = expand_tag($1.tag);
        if (t) printf("<%s> ", t);
        printf("%c%s\n", $2.quote ? $2.quote : ':', $2.value);
        free($2.value); free($1.anchor); free($1.tag);
    }
    | maybe_prop RML_ALIAS {
        print_indent(); printf("=ALI *%s\n", $2.value);
        free($2.value); free($1.anchor); free($1.tag);
    }
    | maybe_prop RML_SEQ_START {
        print_indent(); printf("+SEQ");
        if ($1.anchor) printf(" &%s", $1.anchor);
        const char *t = expand_tag($1.tag);
        if (t) printf(" <%s>", t);
        printf("\n");
        depth++;
    }
    seq_entries RML_SEQ_END {
        depth--; print_indent(); printf("-SEQ\n");
        free($1.anchor); free($1.tag);
    }
    | maybe_prop RML_MAP_START {
        print_indent(); printf("+MAP");
        if ($1.anchor) printf(" &%s", $1.anchor);
        const char *t = expand_tag($1.tag);
        if (t) printf(" <%s>", t);
        printf("\n");
        depth++;
    }
    map_entries RML_MAP_END {
        depth--; print_indent(); printf("-MAP\n");
        free($1.anchor); free($1.tag);
    }
    ;

maybe_prop:
    /* empty */ { $$.anchor = NULL; $$.tag = NULL; $$.value = NULL; $$.quote = 0; }
    | RML_PROP { $$ = $1; }
    ;

seq_entries: /* empty */ | seq_entries node ;

map_entries: /* empty */ | map_entries node node ;

%%

void rml_error(void *scanner, const char *s) {
    fprintf(stderr, "RML Error: %s\n", s);
}
