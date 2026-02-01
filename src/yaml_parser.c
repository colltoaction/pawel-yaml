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

/* ===== Output Formatting and Structure Detection =====
 * Helper functions for emitting RML events from string diagrams.
 * Structured for clarity and reduced duplication.
 */

/* Check if generator name matches a specific token type
 * Used by is_structural() to identify control-flow generators */
static bool gen_name_matches_token(Generator *g, int token) {
    if (!g || !g->name) return false;
    const char *token_name = rml_token_name(token);
    return (token_name && strcmp(g->name, token_name) == 0);
}

/* Lookup table for escape sequence handling - character based for O(1) lookup */
static const unsigned char escape_lut[256] = {
    ['0'] = '\0', ['a'] = '\a', ['b'] = '\b', ['t'] = '\t',
    ['n'] = '\n', ['v'] = '\v', ['f'] = '\f', ['r'] = '\r',
    ['e'] = ESC_CHAR, [' '] = ' ', ['"'] = '"', ['/'] = '/',
    ['\\'] = '\\',
    /* All other indices default to 0, which is handled specially */
};

static char* unescape_double_quoted(const char* s) {
    char* res = malloc(strlen(s) + 1);
    int i = 0, j = 0;
    while (s[i]) {
        if (s[i] == '\\' && s[i+1]) {
            i++;
            unsigned char esc_char = (unsigned char)s[i];
            /* Direct array lookup for escape sequences */
            if (esc_char < 256 && escape_lut[esc_char] != 0) {
                res[j++] = (char)escape_lut[esc_char];
            } else if (esc_char == '0') {
                /* Special case: '0' maps to null character */
                res[j++] = '\0';
            } else {
                /* Unknown escape: keep the character as-is */
                res[j++] = s[i];
            }
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
    
    /* Check if this is an alias (references saved anchor)
     * Aliases are preserved as-is from the input */
    if (gen->name && alias_sym && gen->name[0] == alias_sym[0]) {
        print_indent(visual_depth);
        OUTPUT("=ALI %s\n", gen->name);
    } else {
        print_indent(visual_depth);
        printf("=VAL ");
        
        /* Print anchor if present */
        if (anchor) {
            const char *anchor_sym = rml_token_name(STYLE_ANCHOR);
            if (anchor_sym && anchor[0] != anchor_sym[0]) putchar(anchor_sym[0]);
            printf("%s ", anchor);
        }
        
        /* Print tag if present */
        if (expanded_tag) {
             printf("<%s> ", expanded_tag);
        }
        
        /* Print scalar value with style indicator and unescaping
         * Style indicator (first char): ':' (plain), '"' (double), '\'' (single)
         * Content follows style indicator with escape sequences decoded */
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
    
    /* Identify generators that control flow but don't emit scalars
     * SEQ/MAP: collection markers (not emitted as values)
     * INDENT/DEDENT: indentation markers (not emitted as values) */
    if (gen_name_matches_token(g, SEQ)) return true;
    if (gen_name_matches_token(g, MAP)) return true;
    if (gen_name_matches_token(g, INDENT)) return true;
    if (gen_name_matches_token(g, DEDENT)) return true;
    return false;
}

/* ===== Collection Printing (Unified Pattern) =====
 * Uses a generic print_collection() function to reduce duplication.
 * Both sequences and maps follow the same structure:
 * 1. Print header (+SEQ or +MAP with tags/anchors)
 * 2. Recurse on children with adjusted indentation
 * 3. Print footer (-SEQ or -MAP)
 */

/* Print collection header and content with proper indentation */
static void print_collection_header(
    StringDiagram *sd,
    const char *marker,
    const char *flow_brackets) {
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

/* Generic collection printer to reduce duplication
 * Handles both +SEQ/-SEQ and +MAP/-MAP patterns uniformly
 * 
 * PARAMETERS:
 *   sd: StringDiagram node
 *   marker_prefix: "+SEQ" or "+MAP"
 *   flow_brackets: " []" or " {}" (for flow style)
 *   eff_tag: Effective tag (inherited if not on node)
 *   eff_anchor: Effective anchor (inherited if not on node)
 */
static void print_collection(
    StringDiagram *sd,
    const char *marker_prefix,
    const char *flow_brackets,
    const char *eff_tag,
    const char *eff_anchor) {
    char *orig_tag = sd->tag;
    char *orig_anchor = sd->anchor;
    if (!sd->tag) sd->tag = (char*)eff_tag;
    if (!sd->anchor) sd->anchor = (char*)eff_anchor;
    
    print_collection_header(sd, marker_prefix, flow_brackets);
    visual_depth++;
    rml_print_recursive(sd->data.op.left, NULL, NULL);
    visual_depth--;
    
    /* Convert +SEQ to -SEQ, +MAP to -MAP */
    char footer_marker[10];
    snprintf(footer_marker, sizeof(footer_marker), "-%s",
             marker_prefix[1] == 'S' ? "SEQ" : "MAP");
    print_collection_footer(footer_marker);
    
    sd->tag = orig_tag;
    sd->anchor = orig_anchor;
}

static void print_seq_collection(StringDiagram *sd, const char *eff_tag,
                                 const char *eff_anchor) {
    print_collection(sd, "+SEQ", " []", eff_tag, eff_anchor);
}

static void print_map_collection(StringDiagram *sd, const char *eff_tag,
                                 const char *eff_anchor) {
    print_collection(sd, "+MAP", " {}", eff_tag, eff_anchor);
}

void rml_print_recursive(StringDiagram *sd, const char *inh_anchor, const char *inh_tag) {
    if (!sd) return;
    
    const char *eff_anchor = sd->anchor ? sd->anchor : inh_anchor;
    const char *eff_tag = sd->tag ? sd->tag : inh_tag;
    
    switch (sd->type) {
        case SD_GENERATOR:
            /* Scalar generators are printed unless they're structural markers */
            if (!is_structural(sd->data.gen)) {
                print_scalar(sd->data.gen, eff_anchor, eff_tag);
            } else {
                /* INDENT/DEDENT are control flow only; don't emit output */
                Generator *g = sd->data.gen;
                if (g && g->name) {
                    /* Structural generators elided from output */
                }
            }
            break;
            
        case SD_COMPOSITION: {
            /* Check if right operand is a structural wrapper (SEQ/MAP)
             * If so, treat as collection; otherwise flatten composition */
            bool is_right_gen = (sd->data.op.right->type == SD_GENERATOR);
            bool is_right_structural = is_right_gen &&
                                       is_structural(sd->data.op.right->data.gen);
            if (is_right_structural) {
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
                /* Regular composition: print both operands */
                rml_print_recursive(sd->data.op.left, eff_anchor, eff_tag);
                rml_print_recursive(sd->data.op.right, eff_anchor, eff_tag);
            }
            break;
        }
            
        case SD_PRODUCT:
            /* Parallel product: print both operands in order */
            rml_print_recursive(sd->data.op.left, eff_anchor, eff_tag);
            rml_print_recursive(sd->data.op.right, eff_anchor, eff_tag);
            break;
            
        case SD_IDENTITY:
            /* Identity contributes no output */
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


int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram) {
    extern int yylex_init(void** scanner);
    extern int yylex_destroy(void* scanner);
    extern void yyset_in(FILE* in_str, void* yyscanner);
    extern int yyparse(void* scanner, ParseOutput *output);
    /* Note: reset_lexer_state() is defined in lex.yy.c, called indirectly */
    
    if (!out_alphabet || !out_grammar || !out_diagram) return EXIT_FAILURE;
    
    *out_alphabet = NULL;
    *out_grammar = NULL;
    *out_diagram = NULL;
    
    ParseOutput output = {0};
    
    void* scanner;
    if (yylex_init(&scanner)) return EXIT_FAILURE;
    
    /* State is auto-initialized by Flex, no explicit reset needed for first parse */
    /* reset_lexer_state() would be needed for multi-document parsing */
    
    yyset_in(stdin, scanner);
    
    int result = yyparse(scanner, &output);
    
    yylex_destroy(scanner);
    
    *out_alphabet = output.alphabet;
    *out_grammar = output.grammar;
    *out_diagram = output.diagram;
    
    /* Bison's yyparse returns 0 on success, non-zero on error */
    return (result == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
