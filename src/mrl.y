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

    /* ==================== Alphabet ==================== */
    typedef enum {
        GEN_TYPE_SCALAR,
        GEN_TYPE_MERGE,
        GEN_TYPE_UNIT,
        GEN_TYPE_LBRACK,
        GEN_TYPE_RBRACK,
        GEN_TYPE_LBRACE,
        GEN_TYPE_RBRACE,
        GEN_TYPE_COMMA,
        GEN_TYPE_COLON,
        GEN_TYPE_SEQ_START,
        GEN_TYPE_SEQ_END,
        GEN_TYPE_MAP_START,
        GEN_TYPE_MAP_END,
        GEN_TYPE_FLOW_SEQ_START,
        GEN_TYPE_FLOW_SEQ_END,
        GEN_TYPE_FLOW_MAP_START,
        GEN_TYPE_FLOW_MAP_END,
        GEN_TYPE_DOC_START,
        GEN_TYPE_DOC_END,
        GEN_TYPE_QUESTION,
        GEN_TYPE_ALIAS,
        GEN_TYPE_ERROR = 256,
        GEN_TYPE_UNDEF = 257
    } GeneratorType;

    typedef struct {
        GeneratorType type;
        char *value;
        char *tag;
        char *anchor;
        char quote;
    } Generator;

    typedef struct {
        Generator **generators;
        size_t count;
        size_t capacity;
    } Alphabet;

    /* ==================== Grammar ==================== */
    typedef struct {
        int start_state;
        int end_state;
        Generator symbol;
    } Transition;

    typedef struct {
        Transition **transitions;
        size_t count;
        size_t capacity;
    } Grammar;

    /* ==================== String Diagram ==================== */
    typedef enum {
        SD_TYPE_GENERATOR,
        SD_TYPE_COMPOSITION,
        SD_TYPE_TENSOR
    } StringDiagramType;

    struct StringDiagram_s;
    typedef struct StringDiagram_s {
        StringDiagramType type;
        union {
            Generator *gen;
            struct {
                struct StringDiagram_s *first;
                struct StringDiagram_s *second;
            } binary;
        } data;
    } StringDiagram;

    /* ==================== Parser Context ==================== */
    typedef struct {
        Alphabet *alphabet;
        Grammar *grammar;
        StringDiagram *diagram;
        int has_directive;
        int has_marker;
    } ParserContext;

    /* ==================== API ==================== */
    Alphabet *alphabet_init(void);
    void alphabet_free(Alphabet *a);
    void alphabet_add_scalar(Alphabet *a, const char *value);
    void alphabet_add_quoted_scalar(Alphabet *a, const char *value, char quote);
    void alphabet_add_alias(Alphabet *a, const char *value);
    void alphabet_add_null(Alphabet *a);
    void alphabet_set_tag(Alphabet *a, const char *tag);
    void alphabet_set_anchor(Alphabet *a, const char *anchor);

    Grammar *grammar_init(void);
    void grammar_free(Grammar *g);

    StringDiagram *sd_generator(Generator *g);
    StringDiagram *sd_compose(StringDiagram *f, StringDiagram *g);
    StringDiagram *sd_tensor(StringDiagram *f, StringDiagram *g);
    void sd_free(StringDiagram *sd);
    void sd_set_tag(StringDiagram *sd, const char *tag);
    void sd_set_anchor(StringDiagram *sd, const char *anchor);

    int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram, int *has_directive, int *has_marker);
    void mrl_present(StringDiagram *sd, Alphabet *alphabet);
    void mrl_dump_tokens(void);
    void yyerror(ParserContext *ctx, void *scanner, const char *s);
    int mrl_entry(int argc, char **argv);
}

%define api.pure true
%define parse.error detailed
%parse-param {ParserContext *ctx}
%parse-param {void *scanner}
%lex-param {void *scanner}

%union {
    char *string;
    StringDiagram *sd;
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

%type <sd> implicit_document explicit_document explicit_documents
%type <sd> nodes node node_body scalar
%type <sd> seq seq_entries seq_entry
%type <sd> map map_entries map_entry
%type <sd> flow_seq flow_map flow_seq_entries flow_map_entries flow_node

%destructor { if ($$) sd_free($$); } <sd>
%destructor { if ($$) free($$); } <string>

%%

stream:
    implicit_document[doc] {
        ctx->diagram = $doc;
    }
    | explicit_documents[docs] {
        ctx->diagram = $docs;
    }
    | implicit_document[doc] explicit_documents[docs] {
        ctx->diagram = sd_compose($doc, $docs);
    }
    ;

explicit_documents:
    explicit_document[doc] { $$ = $doc; }
    | explicit_documents[docs] explicit_document[doc] { $$ = sd_compose($docs, $doc); }
    ;

directives:
    directive
    | directives directive
    ;

directive:
    YAML_DIRECTIVE
    | TAG_DIRECTIVE SCALAR[s1] SCALAR[s2] {
        /* TODO: Implement tag handling logic */
        free($s1); free($s2);
    }
    | TAG_DIRECTIVE TAG[t] SCALAR[s] {
         /* Handle case where !e! is lexed as TAG */
         free($t); free($s);
    }
    ;

explicit_document:
    DOC_START nodes[n] {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_DOC_START; gs->value = strdup("---"); gs->tag = NULL; gs->anchor = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_DOC_END; ge->value = NULL; ge->tag = NULL; ge->anchor = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($n, sd_generator(ge)));
    }
    | directives DOC_START nodes[n] {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_DOC_START; gs->value = strdup("---"); gs->tag = NULL; gs->anchor = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_DOC_END; ge->value = NULL; ge->tag = NULL; ge->anchor = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($n, sd_generator(ge)));
    }
    ;

implicit_document:
    nodes[n] {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_DOC_START; gs->value = NULL; gs->tag = NULL; gs->anchor = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_DOC_END; ge->value = NULL; ge->tag = NULL; ge->anchor = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($n, sd_generator(ge)));
    }
    ;

nodes:
    node { $$ = $1; }
    ;

node:
    node_body[body] { $$ = $body; }
    | TAG[t] node_body[body] {
        sd_set_tag($body, $t);
        $$ = $body;
        free($t);
    }
    | ANCHOR[a] node_body[body] {
        sd_set_anchor($body, $a);
        $$ = $body;
        free($a);
    }
    | ANCHOR[a] TAG[t] node_body[body] {
        sd_set_anchor($body, $a);
        sd_set_tag($body, $t);
        $$ = $body;
        free($a); free($t);
    }
    | TAG[t] ANCHOR[a] node_body[body] {
        sd_set_tag($body, $t);
        sd_set_anchor($body, $a);
        $$ = $body;
        free($t); free($a);
    }
    ;

node_body:
    scalar { $$ = $1; }
    | ALIAS[a] {
        alphabet_add_alias(ctx->alphabet, $a);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($a);
    }
    | seq[s] { $$ = $s; }
    | map[m] { $$ = $m; }
    | flow_seq[fs] { $$ = $fs; }
    | flow_map[fm] { $$ = $fm; }
    ;

scalar:
    SCALAR[s] {
        alphabet_add_scalar(ctx->alphabet, $s);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($s);
    }
    | QSCALAR[qs] {
        alphabet_add_quoted_scalar(ctx->alphabet, $qs, '"');
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($qs);
    }
    | SSCALAR[ss] {
        alphabet_add_quoted_scalar(ctx->alphabet, $ss, '\'');
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($ss);
    }
    | BSCALAR[bs] {
        /* BSCALAR value starts with indicator char | or > */
        char indicator = $bs[0];
        alphabet_add_quoted_scalar(ctx->alphabet, $bs + 1, indicator);
        Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
        $$ = sd_generator(g);
        free($bs);
    }
    ;

seq:
    seq_entries[entries] {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_SEQ_START;
        gs->value = NULL;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_SEQ_END;
        ge->value = NULL;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        StringDiagram *start = sd_generator(gs);
        StringDiagram *end = sd_generator(ge);
        
        $$ = sd_compose(start, sd_compose($entries, end));
    }
    ;

seq_entries:
    seq_entry[entry] { $$ = $entry; }
    | seq_entries[entries] seq_entry[entry] { $$ = sd_compose($entries, $entry); }
    ;

seq_entry:
    BULLET node[n] { $$ = $n; }
    ;

map:
    map_entries[entries] {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_MAP_START;
        gs->value = NULL;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_MAP_END;
        ge->value = NULL;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        StringDiagram *start = sd_generator(gs);
        StringDiagram *end = sd_generator(ge);
        
        $$ = sd_compose(start, sd_compose($entries, end));
    }
    ;

map_entries:
    map_entry[entry] { $$ = $entry; }
    | map_entry[entry] map_entries[entries] { $$ = sd_compose($entry, $entries); }
    ;

map_entry:
    node[key] COLON node[val] { $$ = sd_compose($key, $val); }
    | QUESTION node[key] COLON node[val] { $$ = sd_compose($key, $val); }
    ;

flow_seq:
    LBRACK RBRACK {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_FLOW_SEQ_START; gs->value = NULL; gs->tag = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_FLOW_SEQ_END; ge->value = NULL; ge->tag = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_generator(ge));
    }
    | LBRACK flow_seq_entries[entries] RBRACK {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_FLOW_SEQ_START; gs->value = NULL; gs->tag = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_FLOW_SEQ_END; ge->value = NULL; ge->tag = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($entries, sd_generator(ge)));
    }
    ;

flow_seq_entries:
    flow_node[n] { $$ = $n; }
    | flow_seq_entries[entries] COMMA flow_node[n] { $$ = sd_compose($entries, $n); }
    | flow_seq_entries[entries] COMMA { $$ = $entries; }
    ;

flow_map:
    LBRACE flow_map_entries[entries] RBRACE {
        Generator *gs = malloc(sizeof(Generator));
        gs->type = GEN_TYPE_FLOW_MAP_START; gs->value = NULL; gs->tag = NULL; gs->quote = 0;
        Generator *ge = malloc(sizeof(Generator));
        ge->type = GEN_TYPE_FLOW_MAP_END; ge->value = NULL; ge->tag = NULL; ge->quote = 0;
        
        if (ctx->alphabet->count + 2 >= ctx->alphabet->capacity) {
            ctx->alphabet->capacity *= 2;
            ctx->alphabet->generators = realloc(ctx->alphabet->generators, sizeof(Generator*) * ctx->alphabet->capacity);
        }
        ctx->alphabet->generators[ctx->alphabet->count++] = gs;
        ctx->alphabet->generators[ctx->alphabet->count++] = ge;

        $$ = sd_compose(sd_generator(gs), sd_compose($entries, sd_generator(ge)));
    }
    ;

flow_map_entries:
    node[key] COLON node[val] { $$ = sd_compose($key, $val); }
    | flow_map_entries[entries] COMMA node[key] COLON node[val] { $$ = sd_compose($entries, sd_compose($key, $val)); }
    ;

flow_node:
    node[n] { $$ = $n; }
    ;

%%


void yyerror(ParserContext *ctx, void *scanner, const char *s) {
    fputs("Bison error: ", stderr);
    fputs(s, stderr);
    fputc('\n', stderr);
}

/* Recursive function to traverse the diagram and print events - No printf! */
static void traverse_diagram(StringDiagram *sd, Alphabet *alphabet) {
    if (!sd) return;

    if (sd->type == SD_TYPE_GENERATOR) {
        Generator *g = sd->data.gen;
        switch (g->type) {
            case GEN_TYPE_SCALAR: {
                fputs("  =VAL ", stdout);
                if (g->anchor) { fputs(g->anchor, stdout); fputc(' ', stdout); }
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!str") == 0) tag_val = "tag:yaml.org,2002:str";
                    else if (strcmp(tag_val, "!!int") == 0) tag_val = "tag:yaml.org,2002:int";
                    fputc('<', stdout); fputs(tag_val, stdout); fputs("> ", stdout);
                }
                fputc(g->quote ? g->quote : ':', stdout);
                fputs(g->value, stdout);
                fputc('\n', stdout);
            }
            break;
            case GEN_TYPE_ALIAS:
                fputs("  =ALI ", stdout); fputs(g->value, stdout); fputc('\n', stdout);
                break;
            case GEN_TYPE_SEQ_START:
                fputs("  +SEQ", stdout);
                if (g->anchor) { fputc(' ', stdout); fputs(g->anchor, stdout); }
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!seq") == 0) tag_val = "tag:yaml.org,2002:seq";
                    fputs(" <", stdout); fputs(tag_val, stdout); fputc('>', stdout);
                }
                fputc('\n', stdout);
                break;
            case GEN_TYPE_SEQ_END:
                fputs("  -SEQ\n", stdout);
                break;
            case GEN_TYPE_MAP_START:
                fputs("  +MAP", stdout);
                if (g->anchor) { fputc(' ', stdout); fputs(g->anchor, stdout); }
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!map") == 0) tag_val = "tag:yaml.org,2002:map";
                    fputs(" <", stdout); fputs(tag_val, stdout); fputc('>', stdout);
                }
                fputc('\n', stdout);
                break;
            case GEN_TYPE_MAP_END:
                fputs("  -MAP\n", stdout);
                break;
            case GEN_TYPE_FLOW_SEQ_START:
                fputs("  +SEQ []", stdout);
                if (g->anchor) { fputc(' ', stdout); fputs(g->anchor, stdout); }
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!seq") == 0) tag_val = "tag:yaml.org,2002:seq";
                    fputs(" <", stdout); fputs(tag_val, stdout); fputc('>', stdout);
                }
                fputc('\n', stdout);
                break;
            case GEN_TYPE_FLOW_SEQ_END:
                fputs("  -SEQ\n", stdout);
                break;
            case GEN_TYPE_FLOW_MAP_START:
                fputs("  +MAP {}", stdout);
                if (g->anchor) { fputc(' ', stdout); fputs(g->anchor, stdout); }
                if (g->tag) {
                    const char *tag_val = g->tag;
                    if (strcmp(tag_val, "!!map") == 0) tag_val = "tag:yaml.org,2002:map";
                    fputs(" <", stdout); fputs(tag_val, stdout); fputc('>', stdout);
                }
                fputc('\n', stdout);
                break;
            case GEN_TYPE_FLOW_MAP_END:
                fputs("  -MAP\n", stdout);
                break;
            case GEN_TYPE_DOC_START:
                if (g->value && strcmp(g->value, "---") == 0) fputs(" +DOC ---\n", stdout);
                else fputs(" +DOC\n", stdout);
                break;
            case GEN_TYPE_DOC_END:
                fputs(" -DOC\n", stdout);
                break;
            default:
                break;
        }
    } else if (sd->type == SD_TYPE_COMPOSITION || sd->type == SD_TYPE_TENSOR) {
        /* Traverse children */
        traverse_diagram(sd->data.binary.first, alphabet);
        traverse_diagram(sd->data.binary.second, alphabet);
    }
}

/* ==================== Alphabet Implementation ==================== */

Alphabet *alphabet_init(void) {
    Alphabet *a = malloc(sizeof(Alphabet));
    if (!a) return NULL;
    a->count = 0;
    a->capacity = 16;
    a->generators = malloc(sizeof(Generator*) * a->capacity);
    if (!a->generators) {
        free(a);
        return NULL;
    }
    return a;
}

void alphabet_free(Alphabet *a) {
    if (!a) return;
    for (size_t i = 0; i < a->count; i++) {
        if (a->generators[i]->value) {
            free(a->generators[i]->value);
        }
        if (a->generators[i]->tag) {
            free(a->generators[i]->tag);
        }
        if (a->generators[i]->anchor) {
            free(a->generators[i]->anchor);
        }
        free(a->generators[i]);
    }
    free(a->generators);
    free(a);
}

static int alphabet_ensure_capacity(Alphabet *a) {
    if (a->count < a->capacity) return 1;
    a->capacity *= 2;
    a->generators = realloc(a->generators, sizeof(Generator*) * a->capacity);
    return a->generators != NULL;
}

static Generator *generator_new(GeneratorType type, const char *value, char quote) {
    Generator *g = malloc(sizeof(Generator));
    if (!g) return NULL;
    g->type = type;
    g->value = value ? strdup(value) : NULL;
    g->tag = NULL;
    g->anchor = NULL;
    g->quote = quote;
    return g;
}

static void alphabet_append_generator(Alphabet *a, Generator *g) {
    if (!a || !g) return;
    if (!alphabet_ensure_capacity(a)) {
        if (g->value) free(g->value);
        free(g);
        return;
    }
    a->generators[a->count++] = g;
}

void alphabet_add_scalar(Alphabet *a, const char *value) {
    alphabet_append_generator(a, generator_new(GEN_TYPE_SCALAR, value, 0));
}

void alphabet_add_quoted_scalar(Alphabet *a, const char *value, char quote) {
    alphabet_append_generator(a, generator_new(GEN_TYPE_SCALAR, value, quote));
}

void alphabet_add_alias(Alphabet *a, const char *value) {
    alphabet_append_generator(a, generator_new(GEN_TYPE_ALIAS, value, 0));
}

void alphabet_add_null(Alphabet *a) {
    if (a->count >= a->capacity) {
        a->capacity *= 2;
        a->generators = realloc(a->generators, sizeof(Generator*) * a->capacity);
    }
    Generator *g = malloc(sizeof(Generator));
    g->type = GEN_TYPE_UNIT;
    g->value = NULL;
    g->tag = NULL;
    g->anchor = NULL;
    g->quote = 0;
    a->generators[a->count++] = g;
}

void alphabet_set_tag(Alphabet *a, const char *tag) {
    if (a->count > 0) {
        a->generators[a->count - 1]->tag = strdup(tag);
    }
}

void alphabet_set_anchor(Alphabet *a, const char *anchor) {
    if (a->count > 0) {
        a->generators[a->count - 1]->anchor = strdup(anchor);
    }
}

/* ==================== Grammar Implementation ==================== */

Grammar *grammar_init(void) {
    Grammar *g = malloc(sizeof(Grammar));
    if (!g) return NULL;
    g->count = 0;
    g->capacity = 16;
    g->transitions = malloc(sizeof(Transition*) * g->capacity);
    return g;
}

void grammar_free(Grammar *g) {
    if (!g) return;
    for (size_t i = 0; i < g->count; i++) {
        free(g->transitions[i]);
    }
    free(g->transitions);
    free(g);
}

/* ==================== StringDiagram Implementation ==================== */

StringDiagram *sd_generator(Generator *g) {
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    if (!sd) return NULL;
    sd->type = SD_TYPE_GENERATOR;
    sd->data.gen = g;
    return sd;
}

StringDiagram *sd_compose(StringDiagram *f, StringDiagram *g) {
    if (!f) return g;
    if (!g) return f;
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    if (!sd) return NULL;
    sd->type = SD_TYPE_COMPOSITION;
    sd->data.binary.first = f;
    sd->data.binary.second = g;
    return sd;
}

StringDiagram *sd_tensor(StringDiagram *f, StringDiagram *g) {
    if (!f) return g;
    if (!g) return f;
    StringDiagram *sd = malloc(sizeof(StringDiagram));
    if (!sd) return NULL;
    sd->type = SD_TYPE_TENSOR;
    sd->data.binary.first = f;
    sd->data.binary.second = g;
    return sd;
}

void sd_free(StringDiagram *sd) {
    if (!sd) return;
    if (sd->type == SD_TYPE_COMPOSITION || sd->type == SD_TYPE_TENSOR) {
        sd_free(sd->data.binary.first);
        sd_free(sd->data.binary.second);
    }
    free(sd);
}

void sd_set_tag(StringDiagram *sd, const char *tag) {
    if (!sd) return;
    if (sd->type == SD_TYPE_GENERATOR) {
        if (sd->data.gen->tag) free(sd->data.gen->tag);
        sd->data.gen->tag = strdup(tag);
    } else {
        sd_set_tag(sd->data.binary.first, tag);
    }
}

void sd_set_anchor(StringDiagram *sd, const char *anchor) {
    if (!sd) return;
    if (sd->type == SD_TYPE_GENERATOR) {
        if (sd->data.gen->anchor) free(sd->data.gen->anchor);
        sd->data.gen->anchor = strdup(anchor);
    } else {
        sd_set_anchor(sd->data.binary.first, anchor);
    }
}

/* ==================== Library Entry Point ==================== */

int yylex_init(void **scanner);
int yylex_destroy(void *scanner);
void yyset_in(FILE *in, void *scanner);
int yyparse(ParserContext *ctx, void *scanner);

int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram, int *has_directive, int *has_marker) {
    *out_alphabet = alphabet_init();
    *out_grammar = grammar_init();
    *out_diagram = NULL;

    if (!*out_alphabet || !*out_grammar) {
        return 1;
    }

    ParserContext ctx;
    ctx.alphabet = *out_alphabet;
    ctx.grammar = *out_grammar;
    ctx.diagram = NULL;
    ctx.has_directive = 0;
    ctx.has_marker = 0;

    void *scanner;
    yylex_init(&scanner);
    yyset_in(stdin, scanner);

    int result = yyparse(&ctx, scanner);
    
    yylex_destroy(scanner);
    
    *out_diagram = ctx.diagram;
    *has_directive = ctx.has_directive;
    *has_marker = ctx.has_marker;
    
    return result;
}

const char* mrl_get_token_name(int token) {
    switch (token) {
        case SCALAR: return "SCALAR";
        case BSCALAR: return "BSCALAR";
        case QSCALAR: return "QSCALAR";
        case SSCALAR: return "SSCALAR";
        case TAG: return "TAG";
        case ANCHOR: return "ANCHOR";
        case ALIAS: return "ALIAS";
        case YAML_DIRECTIVE: return "YAML_DIRECTIVE";
        case DOC_START: return "DOC_START";
        case BULLET: return "BULLET";
        case COLON: return "COLON";
        case QUESTION: return "QUESTION";
        case LBRACK: return "LBRACK";
        case RBRACK: return "RBRACK";
        case LBRACE: return "LBRACE";
        case RBRACE: return "RBRACE";
        case COMMA: return "COMMA";
        default: return "UNKNOWN";
    }
}

void mrl_dump_tokens() {
    void *scanner;
    yylex_init(&scanner);
    yyset_in(stdin, scanner);
    YYSTYPE lval;
    int token;
    while ((token = yylex(&lval, scanner)) != 0) {
        fputs("TOKEN: ", stdout);
        fputs(mrl_get_token_name(token), stdout);
        if (token == SCALAR || token == BSCALAR || token == QSCALAR || 
            token == SSCALAR || token == TAG || token == ANCHOR || token == ALIAS) {
            fputs(" VALUE: [", stdout);
            fputs(lval.string, stdout);
            fputc(']', stdout);
            free(lval.string);
        }
        fputc('\n', stdout);
    }
    yylex_destroy(scanner);
}

void mrl_present(StringDiagram *sd, Alphabet *alphabet) {
    if (!sd) return;
    fputs("+STR\n", stdout);
    traverse_diagram(sd, alphabet);
    fputs("-STR\n", stdout);
}

int mrl_entry(int argc, char **argv) {
    int mode_dump_tokens = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-dump-tokens") == 0) mode_dump_tokens = 1;
    }

    if (mode_dump_tokens) {
        mrl_dump_tokens();
        return 0;
    }

    Alphabet *alphabet = NULL;
    Grammar *grammar = NULL;
    StringDiagram *diagram = NULL;
    int has_directive = 0;
    int has_marker = 0;

    int result = yaml_parse(&alphabet, &grammar, &diagram, &has_directive, &has_marker);

    if (result == 0) {
        mrl_present(diagram, alphabet);
    } else {
        fputs("Parse failed\n", stderr);
    }

    if (alphabet) alphabet_free(alphabet);
    if (grammar) grammar_free(grammar);
    if (diagram) sd_free(diagram);

    return result;
}

int main(int argc, char **argv) {
    return mrl_entry(argc, argv);
}
