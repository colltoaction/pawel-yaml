#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "yaml_parser.h"
#include "mrl.h"
#include "parser.tab.h"

#define INDENT_SPACES 1

static void print_indent(int depth) {
    if (depth > 0) {
        printf("%*s", depth * INDENT_SPACES, "");
    }
}

int visual_depth = 0;

#define OUTPUT(fmt, ...) do { \
    print_indent(visual_depth); \
    printf(fmt, ##__VA_ARGS__); \
} while (0)



static const char* expand_tag(const char* tag) {
    static char tag_buffer[1024];
    
    if (!tag) return NULL;
    if (tag[0] == '\0') return "<>";  /* Empty tag - just angle brackets */
    if (strcmp(tag, "!!str") == 0) return "<tag:yaml.org,2002:str>";
    if (strcmp(tag, "!!int") == 0) return "<tag:yaml.org,2002:int>";
    if (strcmp(tag, "!!float") == 0) return "<tag:yaml.org,2002:float>";
    if (strcmp(tag, "!!bool") == 0) return "<tag:yaml.org,2002:bool>";
    if (strcmp(tag, "!!null") == 0) return "<tag:yaml.org,2002:null>";
    if (strcmp(tag, "!!map") == 0) return "<tag:yaml.org,2002:map>";
    if (strcmp(tag, "!!seq") == 0) return "<tag:yaml.org,2002:seq>";
    
    // For custom tags, wrap in < >
    snprintf(tag_buffer, sizeof(tag_buffer), "<%s>", tag);
    return tag_buffer;
}

void print_escaped(const char *s) {
    if (!s) return;
    for (int i = 0; s[i]; i++) {
        if (s[i] == '\n') printf("\\n");
        else if (s[i] == '\r') printf("\\r");
        else if (s[i] == '\t') printf("\\t");
        else if (s[i] == '\\') printf("\\\\");
        else putchar(s[i]);
    }
}

static char* unescape_double_quoted(const char* s) {
    char* res = malloc(strlen(s) + 1);
    int i = 0, j = 0;
    while (s[i]) {
        if (s[i] == '\\' && s[i+1]) {
            i++;
            switch (s[i]) {
                case '0': res[j++] = '\0'; break;
                case 'a': res[j++] = '\a'; break;
                case 'b': res[j++] = '\b'; break;
                case 't': res[j++] = '\t'; break;
                case 'n': res[j++] = '\n'; break;
                case 'v': res[j++] = '\v'; break;
                case 'f': res[j++] = '\f'; break;
                case 'r': res[j++] = '\r'; break;
                case 'e': res[j++] = 27; break;
                case ' ': res[j++] = ' '; break;
                case '"': res[j++] = '"'; break;
                case '/': res[j++] = '/'; break;
                case '\\': res[j++] = '\\'; break;
                case '\n': /* Escaped newline - ignore */ break;
                default: res[j++] = s[i]; break;
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


void print_scalar(Generator *gen, const char *anchor, const char *tag) {
    if (!gen) return;
    const char *expanded_tag = expand_tag(tag);
    const char *alias_sym = rml_token_name(STYLE_ALIAS);

    if (gen->name && alias_sym && gen->name[0] == alias_sym[0]) {
        OUTPUT("=ALI %s\n", gen->name);
    } else {
        print_indent(visual_depth);
        printf("=VAL ");
        if (anchor) {
            const char *anchor_sym = rml_token_name(STYLE_ANCHOR);
            if (anchor[0] != anchor_sym[0]) putchar(anchor_sym[0]);
            printf("%s ", anchor);
        }
        if (expanded_tag) printf("%s ", expanded_tag);
        
        if (gen->name) {
            char style = gen->name[0];
            const char* content = gen->name + 1;
            char* unescaped = NULL;
            
            // Check double quote style
            const char *dq_sym = rml_token_name(STYLE_DQUOTE);
            if (dq_sym && style == dq_sym[0]) {
                unescaped = unescape_double_quoted(content);
                content = unescaped;
            } else {
                // Check single quote style only if double quote didn't match
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
    return false;
}





void rml_print_recursive(StringDiagram *sd) {
    if (!sd) return;
    
    switch (sd->type) {
        case SD_GENERATOR:
            if (!is_structural(sd->data.gen)) {
                print_scalar(sd->data.gen, sd->anchor, sd->tag);
            }
            break;
            
        case SD_COMPOSITION:
            if (sd->data.op.right->type == SD_GENERATOR && is_structural(sd->data.op.right->data.gen)) {
                Generator *wrapper = sd->data.op.right->data.gen;
                
                if (wrapper->name && strcmp(wrapper->name, rml_token_name(SEQ)) == 0) {
                    const char *t = expand_tag(sd->tag);
                    const char *flow = sd->flow_style ? " []" : "";
                    print_indent(visual_depth);
                    printf("+SEQ");
                    if (sd->anchor) {
                        const char *anchor_char = rml_token_name(STYLE_ANCHOR);
                        printf(" ");
                        if (sd->anchor[0] != anchor_char[0]) putchar(anchor_char[0]);
                        printf("%s", sd->anchor);
                    }
                    if (t) printf(" %s", t);
                    printf("%s\n", flow);
                    fflush(stdout);
                    
                    visual_depth++;
                    rml_print_recursive(sd->data.op.left);
                    visual_depth--;
                    OUTPUT("-SEQ\n");
                    fflush(stdout);
                } else if (wrapper->name && strcmp(wrapper->name, rml_token_name(MAP)) == 0) {
                    const char *t = expand_tag(sd->tag);
                    const char *flow = sd->flow_style ? " {}" : "";
                    print_indent(visual_depth);
                    printf("+MAP");
                    if (sd->anchor) {
                        const char *anchor_char = rml_token_name(STYLE_ANCHOR);
                        printf(" ");
                        if (sd->anchor[0] != anchor_char[0]) putchar(anchor_char[0]);
                        printf("%s", sd->anchor);
                    }
                    if (t) printf(" %s", t);
                    printf("%s\n", flow);
                    fflush(stdout);
                    
                    visual_depth++;
                    rml_print_recursive(sd->data.op.left);
                    visual_depth--;
                    OUTPUT("-MAP\n");
                    fflush(stdout);
                } else {
                    rml_print_recursive(sd->data.op.left);
                    rml_print_recursive(sd->data.op.right);
                }
            } else {
                rml_print_recursive(sd->data.op.left);
                rml_print_recursive(sd->data.op.right);
            }
            break;
            
        case SD_PRODUCT:
            rml_print_recursive(sd->data.op.left);
            rml_print_recursive(sd->data.op.right);
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
        visual_depth = 2;
        rml_print_recursive(sd);
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

