#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml_parser.h"
#include "mrl.h"
#include "parser.tab.h"  /* Get token IDs from Bison */

static int visual_depth = 0;

#define OUTPUT(...) printf(__VA_ARGS__)

static void print_indent(int depth) {
    for (int i = 0; i < depth; i++) printf(" ");
}

void rml_print_recursive(StringDiagram *sd, const char *inh_anchor, const char *inh_tag);

static char *expand_tag(const char *tag) {
    if (!tag) return NULL;
    if (strcmp(tag, YAML_TAG_SHORT) == 0) return YAML_TAG_SHORT;
    if (strncmp(tag, YAML_TAG_RESERVED, 2) == 0) {
        /* Expand !!prefix to tag:yaml.org,2002:prefix */
        static char buf[256]; /* Warning: not thread safe, static buffer */
        snprintf(buf, sizeof(buf), "%s%s", YAML_TAG_PREFIX, tag + 2);
        return buf;
    }
    return (char *)tag;
}

static void print_escaped(const char *s) {
    if (!s) return;
    for (int i = 0; s[i]; i++) {
        if (s[i] == '\n') printf("\\n");
        else if (s[i] == '\r') printf("\\r");
        else if (s[i] == '\t') printf("\\t");
        else if (s[i] == '\\') printf("\\\\");
        else putchar(s[i]);
    }
}

extern const char *rml_token_name(int tok);

/* Lookup table for escape sequence handling */
static const struct {
    char escape_char;
    char unescaped_char;
} escape_map[] = {
    {'0', '\0'}, {'a', '\a'}, {'b', '\b'}, {'t', '\t'},
    {'n', '\n'}, {'v', '\v'}, {'f', '\f'}, {'r', '\r'},
    {'e', ESC_CHAR}, {' ', ' '}, {'"', '"'}, {'/', '/'},
    {'\\', '\\'}, {0, 0}  /* Sentinel */
};

static char* unescape_double_quoted(const char* s) {
    char* res = malloc(strlen(s) + 1);
    int i = 0, j = 0;
    while (s[i]) {
        if (s[i] == '\\' && s[i+1]) {
            i++;
            char unescaped = s[i];
            /* Look up escape sequence in table */
            for (int k = 0; escape_map[k].escape_char != 0; k++) {
                if (escape_map[k].escape_char == s[i]) {
                    unescaped = escape_map[k].unescaped_char;
                    break;
                }
            }
            res[j++] = unescaped;
        } else {
            res[j++] = s[i];
        }
        i++;
    }
    res[j] = '\0';
    return res;
}

static char* unescape_single_quoted(const char* s) {
    char* res = malloc(strlen(s) + 1);
    int i = 0, j = 0;
    while (s[i]) {
        if (s[i] == '\'' && s[i+1] == '\'') {
            res[j++] = '\'';
            i += 2;
        } else {
            res[j++] = s[i];
            i++;
        }
    }
    res[j] = '\0';
    return res;
}

static void print_scalar(Generator *gen, const char *anchor, const char *tag) {
    if (!gen) return;
    const char *expanded_tag = expand_tag(tag);
    const char *alias_sym = rml_token_name(STYLE_ALIAS);
    
    if (gen->name && alias_sym && gen->name[0] == alias_sym[0]) {
        /* Preserve asterisk in alias output */
        print_indent(visual_depth);
        OUTPUT("=ALI %s\n", gen->name);
    } else {
        print_indent(visual_depth);
        printf("=VAL ");
        if (anchor) {
            const char *anchor_sym = rml_token_name(STYLE_ANCHOR);
            if (anchor_sym && anchor[0] != anchor_sym[0]) putchar(anchor_sym[0]);
            printf("%s ", anchor);
        }
        if (expanded_tag) {
             printf("<%s> ", expanded_tag);
        }
        
        if (gen->name) {
            char style = gen->name[0];
            const char* content = gen->name + 1;
            char* unescaped = NULL;
            
            const char *dq_sym = rml_token_name(STYLE_DQUOTE);
            if (dq_sym && style == dq_sym[0]) {
                unescaped = unescape_double_quoted(content);
                content = unescaped;
            } else {
                const char *sq_sym = rml_token_name(STYLE_SQUOTE);
                if (sq_sym && style == sq_sym[0]) {
                    unescaped = unescape_single_quoted(content);
                    content = unescaped;
                }
            }
            
            putchar(style);
            print_escaped(content);
            if (unescaped) free(unescaped);
        }
        printf("\n");
        fflush(stdout);
    }
}

static bool is_structural(Generator *g) {
    if (!g || !g->name) return false;
    const char *seq = rml_token_name(SEQ);
    if (seq && strcmp(g->name, seq) == 0) return true;
    const char *map = rml_token_name(MAP);
    if (map && strcmp(g->name, map) == 0) return true;
    /* INDENT/DEDENT treated as structural to avoid print_scalar */
    const char *indent = rml_token_name(INDENT);
    if (indent && strcmp(g->name, indent) == 0) return true;
    const char *dedent = rml_token_name(DEDENT);
    if (dedent && strcmp(g->name, dedent) == 0) return true;
    return false;
}

/* Print collection header and content with proper indentation */
static void print_collection_header(StringDiagram *sd, const char *marker, const char *flow_brackets) {
    const char *t = expand_tag(sd->tag);
    const char *flow = sd->flow_style ? flow_brackets : "";
    print_indent(visual_depth);
    printf("%s", marker);
    if (sd->anchor) {
        const char *anchor_char = rml_token_name(STYLE_ANCHOR);
        printf(" ");
        if (anchor_char && sd->anchor[0] != anchor_char[0]) putchar(anchor_char[0]);
        printf("%s", sd->anchor);
    }
    if (t) {
        printf(" <%s>", t);
    }
    printf("%s\n", flow);
    fflush(stdout);
}

static void print_collection_footer(const char *marker) {
    print_indent(visual_depth);
    OUTPUT("%s\n", marker);
    fflush(stdout);
}

static void print_seq_collection(StringDiagram *sd, const char *eff_tag, const char *eff_anchor) {
    char *orig_tag = sd->tag;
    char *orig_anchor = sd->anchor;
    if (!sd->tag) sd->tag = (char*)eff_tag; 
    if (!sd->anchor) sd->anchor = (char*)eff_anchor;
    
    print_collection_header(sd, "+SEQ", " []");
    visual_depth++;
    rml_print_recursive(sd->data.op.left, NULL, NULL);
    visual_depth--;
    print_collection_footer("-SEQ");
    
    sd->tag = orig_tag;
    sd->anchor = orig_anchor;
}

static void print_map_collection(StringDiagram *sd, const char *eff_tag, const char *eff_anchor) {
    char *orig_tag = sd->tag;
    char *orig_anchor = sd->anchor;
    if (!sd->tag) sd->tag = (char*)eff_tag;
    if (!sd->anchor) sd->anchor = (char*)eff_anchor;

    print_collection_header(sd, "+MAP", " {}");
    visual_depth++;
    rml_print_recursive(sd->data.op.left, NULL, NULL);
    visual_depth--;
    print_collection_footer("-MAP");

    sd->tag = orig_tag;
    sd->anchor = orig_anchor;
}

void rml_print_recursive(StringDiagram *sd, const char *inh_anchor, const char *inh_tag) {
    if (!sd) return;
    
    const char *eff_anchor = sd->anchor ? sd->anchor : inh_anchor;
    const char *eff_tag = sd->tag ? sd->tag : inh_tag;
    
    switch (sd->type) {
        case SD_GENERATOR:
            if (!is_structural(sd->data.gen)) {
                print_scalar(sd->data.gen, eff_anchor, eff_tag);
            } else {
                Generator *g = sd->data.gen;
                if (g && g->name) {
                    /* INDENT/DEDENT are no-ops */
                }
            }
            break;
            
        case SD_COMPOSITION:
            if (sd->data.op.right->type == SD_GENERATOR && is_structural(sd->data.op.right->data.gen)) {
                Generator *wrapper = sd->data.op.right->data.gen;
                
                if (wrapper->name && strcmp(wrapper->name, rml_token_name(SEQ)) == 0) {
                    print_seq_collection(sd, eff_tag, eff_anchor);
                } else if (wrapper->name && strcmp(wrapper->name, rml_token_name(MAP)) == 0) {
                    print_map_collection(sd, eff_tag, eff_anchor);
                } else {
                    rml_print_recursive(sd->data.op.left, eff_anchor, eff_tag);
                    rml_print_recursive(sd->data.op.right, eff_anchor, eff_tag);
                }
            } else {
                rml_print_recursive(sd->data.op.left, eff_anchor, eff_tag);
                rml_print_recursive(sd->data.op.right, eff_anchor, eff_tag);
            }
            break;
            
        case SD_PRODUCT:
            rml_print_recursive(sd->data.op.left, eff_anchor, eff_tag);
            rml_print_recursive(sd->data.op.right, eff_anchor, eff_tag);
            break;
            
        case SD_IDENTITY:
            break;
    }
}

void rml_print_events(ParseOutput *output) {
    if (!output) return;
    StringDiagram *sd = output->diagram;
    visual_depth = 0;
    OUTPUT("+STR\n");
    if (sd) {
        if (sd->doc_marker) {
            OUTPUT(" +DOC ---\n");
        } else {
            OUTPUT(" +DOC\n");
        }
        visual_depth = DOCUMENT_INDENT_LEVEL;
        rml_print_recursive(sd, NULL, NULL);
        visual_depth = 0;
        if (sd->doc_end_marker) {
            OUTPUT(" -DOC ...\n");
        } else {
            OUTPUT(" -DOC\n");
        }
    }
    OUTPUT("-STR\n");
    fflush(stdout);
}

#include "lexer_context.h"

int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram) {
    extern int yylex_init_extra(LexerContext* user_defined, void** scanner);
    extern int yylex_destroy(void* scanner);
    extern void yyset_in(FILE* in_str, void* yyscanner);
    extern int yyparse(void* scanner, ParseOutput *output);
    
    if (!out_alphabet || !out_grammar || !out_diagram) return 1;
    
    *out_alphabet = NULL;
    *out_grammar = NULL;
    *out_diagram = NULL;
    
    ParseOutput output = {0};
    LexerContext ctx = {0};
    ctx.indent_stack[0] = 0;
    ctx.indent_level = 0;
    ctx.pending_dedents = 0;
    
    void* scanner;
    if (yylex_init_extra(&ctx, &scanner)) return 2;
    
    yyset_in(stdin, scanner);
    
    int result = yyparse(scanner, &output);
    
    yylex_destroy(scanner);
    
    *out_alphabet = output.alphabet;
    *out_grammar = output.grammar;
    *out_diagram = output.diagram;
    
    return result;
}
