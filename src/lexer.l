%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "mrl.h"
#include "yaml_parser.h"
#include "parser.tab.h"
#include "lexer_context.h"

#define CTX ((LexerContext*)yyextra)

/* Prototype helper functions */
/* 
 * Structural Handling Authority:
 * The Lexer is solely responsible for managing indentation state and emitting
 * INDENT/DEDENT tokens. The parser (yaml.y) consumes these tokens but does
 * not manipulate indentation state directly.
 */
static void push_indent(void* yyscanner, int column);
static int pop_indent(void* yyscanner);
static int current_indent(void* yyscanner);

static char* prefix_dup(char prefix, const char* s, int len) {
    char* buf = malloc(len + 2);
    if (!buf) return NULL;
    buf[0] = prefix;
    memcpy(buf + 1, s, len);
    buf[len + 1] = '\0';
    return buf;
}

%}

%option reentrant
%option bison-bridge
%option bison-locations
%option noyywrap
%option never-interactive
%option extra-type="LexerContext*"

%x BLOCK_CONTENT
%x FLOW_CONTENT
%x BLOCK_SCALAR_START
%x BLOCK_SCALAR_LINE

%%

    if (CTX->indent_level == 0 && CTX->indent_stack[0] == 0) CTX->indent_stack[0] = 0;
    if (CTX->pending_dedents > 0) {
        CTX->pending_dedents--;
        return DEDENT;
    }

<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"---"/[ \t\n\r]   { BEGIN(BLOCK_CONTENT); return DOC_START; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"---"             { BEGIN(BLOCK_CONTENT); return DOC_START; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"..."/[ \t\n\r]   { BEGIN(INITIAL); return DOC_END; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^"..."             { BEGIN(INITIAL); return DOC_END; }

<INITIAL>^"%"[^\n]*\n               { ; }
<INITIAL,BLOCK_CONTENT,FLOW_CONTENT>^[ \t]*(\n|\r\n)   { ; }
<INITIAL>^[ \t]*#.*(\n|\r\n)           { ; }

<INITIAL>^[ \t]+                    {
    int column = yyleng;
    if (column > current_indent(yyscanner)) {
        push_indent(yyscanner, column);
        if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
        return INDENT;
    } else if (column < current_indent(yyscanner)) {
        while (column < current_indent(yyscanner)) {
            pop_indent(yyscanner);
            CTX->pending_dedents++;
        }
        if (CTX->pending_dedents > 0) {
            CTX->pending_dedents--;
            if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
            return DEDENT;
        }
    }
    if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
}
<INITIAL>^[^ \t\n\r%]               {
    yyless(0);
    int column = 0;
    if (column < current_indent(yyscanner)) {
        while (column < current_indent(yyscanner)) {
            pop_indent(yyscanner);
            CTX->pending_dedents++;
        }
        if (CTX->pending_dedents > 0) {
            CTX->pending_dedents--;
            if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
            return DEDENT;
        }
    }
    if (CTX->flow_level > 0) BEGIN(FLOW_CONTENT); else BEGIN(BLOCK_CONTENT);
}

<BLOCK_CONTENT,FLOW_CONTENT>#.*                        { ; }
<BLOCK_CONTENT>"- "/[ \t\n\r]             { return BLOCK_SEQ_START; }
<BLOCK_CONTENT>"- "                       { return BLOCK_SEQ_START; }
<BLOCK_CONTENT>"-"/(\n|\r\n|$)            { return BLOCK_SEQ_START; }
<BLOCK_CONTENT>"?"/[ \t\n\r]              { return BLOCK_KEY; }
<BLOCK_CONTENT,FLOW_CONTENT>":"                      { return COLON; }
<BLOCK_CONTENT,FLOW_CONTENT>"["           { 
    CTX->flow_level++; 
    BEGIN(FLOW_CONTENT);
    return FLOW_SEQ_START; 
}
<BLOCK_CONTENT,FLOW_CONTENT>"]"           { 
    if (CTX->flow_level > 0) CTX->flow_level--; 
    if (CTX->flow_level == 0) BEGIN(BLOCK_CONTENT);
    return FLOW_SEQ_END; 
}
<BLOCK_CONTENT,FLOW_CONTENT>"{"           { 
    CTX->flow_level++; 
    BEGIN(FLOW_CONTENT);
    return FLOW_MAP_START; 
}
<BLOCK_CONTENT,FLOW_CONTENT>"}"           { 
    if (CTX->flow_level > 0) CTX->flow_level--; 
    if (CTX->flow_level == 0) BEGIN(BLOCK_CONTENT);
    return FLOW_MAP_END; 
}
<BLOCK_CONTENT,FLOW_CONTENT>","                        { return COMMA; }
<BLOCK_CONTENT,FLOW_CONTENT>\n                         { BEGIN(INITIAL); }
<BLOCK_CONTENT,FLOW_CONTENT>([ \t]|\xe2\x80\xa3|\xe2\x90\xa3)+                     { ; }


<BLOCK_CONTENT,FLOW_CONTENT>!([!a-zA-Z0-9_.\-\/]*|"<"[^>]+">") {
    yylval->sval = strdup(yytext);
    return TAG;
}

<BLOCK_CONTENT>(([?:-]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}])+)|([a-zA-Z0-9_\/\\\$\(\)\+\=\<\^\~\;\.]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}])*))([ \t]+[\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;\,\[\]\{\}])*)* {
    yylval->sval = prefix_dup(':', yytext, yyleng);
    return SCALAR;
}

<FLOW_CONTENT>(([?:-]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;])+)|([a-zA-Z0-9_\/\\\$\(\)\+\=\<\^\~\;\.]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;])*))([ \t]+[\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]([\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;]|[:#][\%a-zA-Z0-9_.\/\\\$\@\(\)\!\+\-\!\?\"\'\=\<\>\*\&\^\|\~\`\;])*)* {
    yylval->sval = prefix_dup(':', yytext, yyleng);
    return SCALAR;
}


<BLOCK_CONTENT,FLOW_CONTENT>\"([^"\\]|\\.)*\" {
    yylval->sval = prefix_dup('"', yytext + 1, yyleng - 2);
    return SCALAR;
}

<BLOCK_CONTENT,FLOW_CONTENT>'([^']|'')*' {
    yylval->sval = prefix_dup('\'', yytext + 1, yyleng - 2);
    return SCALAR;
}

<BLOCK_CONTENT>[|>][\-+]?                 {
    CTX->block_type = yytext[0];
    CTX->block_indent = -1;
    CTX->block_content = malloc(1024);
    if (!CTX->block_content) { return 0; } // out of mem
    CTX->block_content[0] = '\0';
    CTX->block_content_len = 0;
    CTX->block_content_cap = 1024;
    BEGIN(BLOCK_SCALAR_START);
}

<BLOCK_SCALAR_START>\n[ \t]* {
    int indent = yyleng - 1;
    if (indent <= current_indent(yyscanner)) {
        // End of block
        yyless(0); 
        yylval->sval = prefix_dup(CTX->block_type, CTX->block_content, CTX->block_content_len);
        free(CTX->block_content);
        CTX->block_content = NULL;
        BEGIN(INITIAL);
        return SCALAR;
    }
    CTX->block_indent = indent;
    BEGIN(BLOCK_SCALAR_LINE);
    yyless(1); 
}

<BLOCK_SCALAR_LINE>.* {
    // Strip block_indent spaces if possible
    int strip = CTX->block_indent;
    int len = yyleng;
    char *ptr = yytext;
    while (strip > 0 && len > 0 && (*ptr == ' ' || *ptr == '\t')) {
        ptr++;
        len--;
        strip--;
    }
    
    if (CTX->block_content_len + len + 2 > CTX->block_content_cap) {
        CTX->block_content_cap *= 2;
        CTX->block_content = realloc(CTX->block_content, CTX->block_content_cap);
    }
    memcpy(CTX->block_content + CTX->block_content_len, ptr, len);
    CTX->block_content_len += len;
    CTX->block_content[CTX->block_content_len++] = '\n';
    CTX->block_content[CTX->block_content_len] = '\0';
    BEGIN(BLOCK_SCALAR_START);
}


<BLOCK_CONTENT,FLOW_CONTENT>\&[a-zA-Z0-9_.\-:]+ {
    yylval->sval = strdup(yytext);
    return ANCHOR;
}

<BLOCK_CONTENT,FLOW_CONTENT>\*[a-zA-Z0-9_.\-:]+ {
    yylval->sval = strdup(yytext);
    return ALIAS;
}

<BLOCK_CONTENT,FLOW_CONTENT>.                           { 
    fprintf(stderr, "Unexpected char in CONTENT: '%c' (0x%02x)\n", yytext[0], (unsigned char)yytext[0]); 
}

<*><<EOF>> {
    if (CTX->indent_level > 0) {
        CTX->indent_level--;
        return DEDENT;
    }
    yyterminate();
}
%%

static void push_indent(void* yyscanner, int column) {
    LexerContext* ctx = (LexerContext*)yyget_extra(yyscanner);
    if (ctx->indent_level < 99) ctx->indent_stack[++ctx->indent_level] = column;
}

static int pop_indent(void* yyscanner) {
    LexerContext* ctx = (LexerContext*)yyget_extra(yyscanner);
    return (ctx->indent_level > 0) ? ctx->indent_stack[ctx->indent_level--] : 0;
}

static int current_indent(void* yyscanner) {
    LexerContext* ctx = (LexerContext*)yyget_extra(yyscanner);
    return ctx->indent_stack[ctx->indent_level];
}

/* ===== Grammar-Based String Diagram Acceptance Test =====
 * 
 * PHASE 1: Extract Generator Sequences
 * ====================================
 * Recognizes string diagrams against regular monoidal grammar by:
 * 1. Extracting generator sequence from diagram tree (diagram_to_generators)
 * 2. Matching generators to grammar transitions (grammar_transition_match)
 * 3. Simulating state machine to determine acceptance (mrl_accepts)
 * 
 * Conceptually this is a state machine that Flex could optimize, but we keep
 * it in C for direct struct field access which Flex patterns lack.
 * 
 * Reference: FLEX_PATTERNS_ANALYSIS.md § Recommended Refactoring Strategy
 *
 * ===== Phase 1 Implementation Notes =====
 * This implementation favors clarity and maintainability while keeping the
 * performance-critical path in C. Future optimization may involve:
 * - Flex rules for input normalization
 * - C helpers for acceptance verdicts
 * - Start condition stack for nested generators (yy_push/pop_state)
 */

/* PHASE 1.1: Extract Generator Sequence
 * 
 * PURPOSE:
 *   Flatten recursive string diagram tree into linear generator sequence.
 *   Handles composition (sequential) and product (parallel) operations.
 * 
 * INPUT:
 *   sd - StringDiagram to flatten (tree structure)
 * OUTPUT:
 *   gens - Array to populate with extracted generators
 *   count - Running count (incremented for each generator found)
 * 
 * PATTERN EQUIVALENCE:
 *   This implements what Flex start conditions could orchestrate:
 *   - Each switch case corresponds to a potential Flex rule
 *   - Recursion simulates depth-first traversal (could use stack/conditions)
 * 
 * COMPLEXITY: O(n) where n = number of nodes in diagram tree
 */
static void diagram_to_generators(StringDiagram *sd, Generator **gens, int *count) {
    if (!sd || *count >= 256) return;
    
    switch (sd->type) {
        case SD_GENERATOR:
            /* Leaf: emit generator if non-null */
            if (sd->data.gen) {
                gens[*count] = sd->data.gen;
                (*count)++;
            }
            break;
            
        case SD_COMPOSITION:
            /* Sequential: left then right */
            diagram_to_generators(sd->data.op.left, gens, count);
            diagram_to_generators(sd->data.op.right, gens, count);
            break;
            
        case SD_PRODUCT:
            /* Parallel: left then right (flattened order) */
            diagram_to_generators(sd->data.op.left, gens, count);
            diagram_to_generators(sd->data.op.right, gens, count);
            break;
            
        case SD_IDENTITY:
            /* Identity: contributes no generators */
            break;
    }
}

/* PHASE 1.2: State Vector Cloning Helper
 * 
 * PURPOSE:
 *   Create independent copy of state list for transition codomain.
 *   Avoids mutation of shared grammar transition structures.
 * 
 * SAFETY:
 *   Caller owns returned StateList and must call free_statelist()
 * 
 * NOTE:
 *   Flex wouldn't need this (no shared state mutation), but C requires
 *   careful memory management for the state vector.
 */
static StateList* clone_state_vector(StateList *src) {
    if (!src) return NULL;
    
    StateList *clone = create_statelist();
    if (!clone) return NULL;
    
    for (int i = 0; i < src->count; i++) {
        if (src->names[i]) {
            statelist_add(clone, src->names[i]);
        }
    }
    return clone;
}

/* PHASE 2: Match Generator to Grammar Transitions
 * 
 * PURPOSE:
 *   Find grammar transition matching (generator, current_state_vector).
 *   Returns transition with updated state vector if match found.
 * 
 * ALGORITHM:
 *   1. Linear search through all grammar transitions
 *   2. Check generator match
 *   3. Check arity match (domain state count = current_states count)
 *   4. Check state vector pairwise equality
 * 
 * RETURN:
 *   Pointer to matching Transition, or NULL if no match
 * 
 * COMPLEXITY: O(m*n) where m=transitions, n=state_count
 *             (could optimize to hash lookup with state composition)
 * 
 * PATTERN EQUIVALENCE:
 *   This corresponds to Flex REJECT action:
 *   ```flex
 *   <MATCH_TRANS>GRAM[A-Z_]+/VALID_TARGET { advance_state(); }
 *   <MATCH_TRANS>GRAM[A-Z_]+/INVALID_TARGET { REJECT; }
 *   ```
 *   We inline the search loop for direct struct access.
 */
static Transition* grammar_transition_match(Grammar *g, Generator *gen,
                                            StateList *current_states) {
    if (!g || !gen || !current_states) return NULL;
    
    for (int i = 0; i < g->transition_count; i++) {
        Transition *t = g->transitions[i];
        if (!t) continue;
        
        /* Check: generator matches */
        if (t->gen != gen) continue;
        
        /* Check: arity matches (state vector length = domain length) */
        if (t->dom->count != current_states->count) continue;
        
        /* Check: state vector pairwise equality */
        bool state_match = true;
        for (int j = 0; j < current_states->count; j++) {
            if (!current_states->names[j] || !t->dom->names[j] ||
                strcmp(current_states->names[j], t->dom->names[j]) != 0) {
                state_match = false;
                break;
            }
        }
        
        if (state_match) return t;
    }
    return NULL;
}

/* PHASE 3: Unified State Machine Acceptance Test
 * 
 * PURPOSE:
 *   Determine if string diagram is accepted by regular monoidal grammar.
 *   Simulates the NMA (Non-deterministic Monoidal Automaton) on the diagram.
 * 
 * ALGORITHM:
 *   1. Extract generator sequence from diagram
 *   2. Initialize empty state vector (base case)
 *   3. For each generator:
 *      - Find matching grammar transition
 *      - Update state vector to transition codomain
 *   4. Accept iff final state vector arity/coarity match
 * 
 * ACCEPTANCE CRITERIA:
 *   - All generators matched to transitions
 *   - Final state vector coarity == input diagram coarity
 * 
 * RETURN:
 *   true if accepted, false if rejected
 * 
 * PATTERN EQUIVALENCE:
 *   This is the core DFA loop that Flex would orchestrate via states:
 *   ```flex
 *   <INITIAL>BEGIN_TEST { BEGIN(GENERATOR_EXTRACT); }
 *   <GENERATOR_EXTRACT>...
 *   <TRANSITION_MATCH>...
 *   <ACCEPT_STATE><<EOF>> { return accepted_state; }
 *   ```
 *   
 *   Reference: FLEX_PATTERNS_ANALYSIS.md § Recommended Refactoring Strategy
 *   Keeping in C for now due to struct field access limitations in Flex.
 */
bool mrl_accepts(Grammar *g, StringDiagram *sd) {
    if (!g || !sd) return false;
    if (!g->alphabet) return false;
    
    /* PHASE 3.1: Extract generator sequence */
    Generator *gens[256];
    int gen_count = 0;
    diagram_to_generators(sd, gens, &gen_count);
    
    /* PHASE 3.2: Initialize state machine */
    StateList *current_states = create_statelist();
    if (!current_states) return false;
    
    /* Edge case: empty generator sequence */
    if (gen_count == 0) {
        bool result = (sd->arity == 0 && sd->coarity == 0);
        free_statelist(current_states);
        return result;
    }
    
    /* PHASE 3.3: Simulate transitions for each generator */
    for (int i = 0; i < gen_count; i++) {
        Generator *current_gen = gens[i];
        if (!current_gen) {
            free_statelist(current_states);
            return false;
        }
        
        /* Find matching grammar transition */
        Transition *trans = grammar_transition_match(g, current_gen, current_states);
        if (!trans) {
            free_statelist(current_states);
            return false;
        }
        
        /* Update state vector to transition codomain */
        free_statelist(current_states);
        current_states = clone_state_vector(trans->cod);
        if (!current_states) return false;
    }
    
    /* PHASE 3.4: Check acceptance criteria */
    bool accepted = (sd->arity == gen_count &&
                     sd->coarity == current_states->count);
    
    free_statelist(current_states);
    return accepted;
}
