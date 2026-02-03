# YACC Applied to YAML Parsing: pawel-yaml Case Study

**Links**: [YACC Full Guide](./YACC_COMPREHENSIVE_GUIDE.md) | [Quick Reference](./YACC_QUICK_REFERENCE.md) | [UNIX Philosophy](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md)

---

## 1. Why YAML Requires YACC (+ Flex)

### 1.1 YAML Grammar Complexity

YAML has multiple syntactic forms for the same data:

```yaml
# Block style (indentation-based)
person:
  name: Alice
  age: 30

# Flow style (curly braces)
person: { name: Alice, age: 30 }

# Inline style
person: {name: Alice, age: 30}

# Anchors and aliases
defaults: &defaults
  timeout: 30
  retries: 3

api:
  <<: *defaults     # Merge anchor
  endpoint: /api/v1
```

**Challenge**: A single lexer token or grammar rule can't capture all variations.

**Solution**: 
- **Flex** handles:
  - Indentation tracking (significant whitespace)
  - Block scalar accumulation (`|`, `>`)
  - Anchor/alias token generation
  
- **YACC** handles:
  - Grammar structure (maps, sequences, scalars)
  - Operator precedence (implicit ordering)
  - Semantic composition (StringDiagram morphisms)

### 1.2 The Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│  Application Layer (pawel-yaml binary)  │
│  - Validates YAML compliance            │
│  - Outputs parse tree                   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  Semantic Layer (RML StringDiagram)     │
│  - Morphism composition                 │
│  - Type/anchor/alias binding            │
│  - Alphabet/Generator management        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  Parser Layer (YACC/Bison)              │
│  - Grammar rules (maps, sequences, etc) │
│  - Semantic actions (RML construction)  │
│  - Error recovery                       │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  Lexer Layer (Flex)                     │
│  - Tokenization                         │
│  - Indentation stack management         │
│  - Block scalar accumulation            │
│  - Anchor/alias recognition             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  Input Stream (YAML text)               │
└─────────────────────────────────────────┘
```

---

## 2. pawel-yaml Grammar Structure

### 2.1 Top-Level Document Rules

**File**: `src/mrl.y` (BNF grammar)

```yacc
document_list : /* empty */
              | document_list document
              ;

document : nodes
         | YAML_DIRECTIVE DOC_START nodes
         ;

nodes : node { $$ = $1; }
      ;

node : node_body
     | TAG node_body
     | ANCHOR node_body
     | ANCHOR TAG node_body
     | TAG ANCHOR node_body
     ;
```

**Pattern**: YACC allows flexible combination of:
- Plain node: `key: value`
- Tagged node: `!!type key: value`
- Anchored node: `&anchor key: value`
- Combined: `&anchor !!type key: value`

### 2.2 Handling YAML's Complex Syntax

**Challenge**: YAML allows anchors before map keys without explicit values:
```yaml
&a: key: &a value
foo:
  *a:
```

**YACC Solution** (as attempted in pawel-yaml):
1. Recognize `ANCHOR COLON` at `map_entry` level
2. Create implicit null node
3. Apply anchor to that null

```yacc
map_entry : node COLON node { $$ = sd_compose($1, $3); }
          | ANCHOR COLON node { 
              /* &x: value - implicit empty key */
              alphabet_add_null(ctx->alphabet);
              Generator *g = ctx->alphabet->generators[ctx->alphabet->count - 1];
              g->anchor = strdup($1);
              $$ = sd_compose(sd_generator(g), $3);
          }
          ;
```

### 2.3 Scalar Values with Context

```yacc
scalar : SCALAR { /* quoted string */ }
       | QSCALAR { /* double-quoted */ }
       | SSCALAR { /* single-quoted */ }
       | BSCALAR { /* block scalar (| or >) */ }
       ;
```

**Bison Role**: Flex accumulates block scalar lines; Bison applies tag/anchor to completed scalar.

### 2.4 Maps and Sequences

```yacc
map : map_entries {
    Generator *gs = malloc(sizeof(Generator));
    gs->type = GEN_TYPE_MAP_START;
    /* ... set up start/end markers ... */
    $$ = sd_compose(start, sd_compose($1, end));
}

map_entries : map_entry
            | map_entries map_entry { $$ = sd_compose($1, $2); }
            ;

seq : seq_entries {
    Generator *gs = malloc(sizeof(Generator));
    gs->type = GEN_TYPE_SEQ_START;
    /* ... similar setup ... */
    $$ = sd_compose(start, sd_compose($1, end));
}
```

**StringDiagram Pattern**: `sd_compose(start, sd_compose(entries, end))`
- Represents sequential morphism composition
- Maps are `MAP_START ⊕ entries ⊕ MAP_END`
- Sequences are `SEQ_START ⊕ entries ⊕ SEQ_END`

### 2.5 Flow Sequences and Maps

```yacc
flow_seq : LBRACK RBRACK
         | LBRACK flow_seq_entries RBRACK
         ;

flow_seq_entries : flow_node
                 | flow_seq_entries COMMA flow_node
                 ;

flow_node : node
          | flow_seq
          | flow_map
          ;
```

**Challenge**: Disambiguating flow syntax from block syntax
- **Flex**: Track bracket nesting, emit different tokens in flow context
- **YACC**: Separate rules for `flow_node` vs `node`

---

## 3. Flex Lexer Coordination

### 3.1 Indentation Tracking (Critical for YAML)

**File**: `src/mrl.l` (Flex lexer)

```c
#define INDENT_STACK_SIZE 100
static int indent_stack[INDENT_STACK_SIZE];
static int indent_depth = 0;

void push_indent(int level) {
    if (indent_depth >= INDENT_STACK_SIZE) {
        fprintf(stderr, "Indentation stack overflow\n");
        exit(1);
    }
    indent_stack[indent_depth++] = level;
}

int pop_indent() {
    if (indent_depth > 0) return indent_stack[--indent_depth];
    return 0;
}

int current_indent() {
    if (indent_depth > 0) return indent_stack[indent_depth - 1];
    return 0;
}
```

**How it works**:
- Track significant whitespace at line start
- Use stack to handle nested structures
- Emit indent/dedent tokens to YACC when level changes

### 3.2 Block Scalar Handling

YAML block scalars (`|` and `>`) span multiple lines:

```yaml
description: |
  This is a long
  multi-line description
  that preserves newlines
folded: >
  This is folded text that
  will have newlines replaced
  with spaces when folded
```

**Flex Strategy**:
1. Recognize `|` or `>` indicator
2. Enter `BLOCK_SCALAR` state
3. Accumulate lines with indentation tracking
4. Return complete scalar as single `BSCALAR` token

```c
%x BLOCK_SCALAR

"|"[0-9]*[-+]*[ \t]*(\n|#.*)  { init_block_scalar('|'); BEGIN(BLOCK_SCALAR); }
">"[0-9]*[-+]*[ \t]*(\n|#.*)  { init_block_scalar('>'); BEGIN(BLOCK_SCALAR); }

<BLOCK_SCALAR>^[ \t]+ {
    int indent = yyleng;
    if (block_indent == -1) {
        block_indent = indent;
    }
    if (indent >= block_indent) {
        /* Accumulate line */
        append_block_line(yytext, yyleng);
    } else {
        /* Block ended, emit BSCALAR token */
        BEGIN(INITIAL);
        yyless(0);  /* Reprocess line */
    }
}
```

**YACC Integration**: Receives complete block as `BSCALAR` token, treats like regular scalar.

### 3.3 Anchor and Alias Recognition

```c
"&"{NSCAL}+      { yylval->string = strdup(yytext); return ANCHOR; }
"*"{NSCAL}+      { yylval->string = strdup(yytext); return ALIAS; }
```

**Simple in Flex**: Just pattern matching!

**YACC's Job**: Decide where anchors apply:
- Anchor before scalar → applies to scalar
- Anchor before map → applies to entire map
- Anchor before sequence → applies to entire sequence

---

## 4. Semantic Actions Using RML

### 4.1 StringDiagram Morphisms

**Core Idea**: Parse tree nodes are composed functions (morphisms).

```c
typedef struct StringDiagram {
    int type;
    union {
        Generator *gen;           /* Atomic generator */
        struct {
            StringDiagram *first;
            StringDiagram *second;
        } binary;                 /* Composition or tensor */
    } data;
} StringDiagram;

StringDiagram *sd_compose(StringDiagram *f, StringDiagram *g) {
    StringDiagram *result = malloc(sizeof(StringDiagram));
    result->type = SD_TYPE_COMPOSITION;
    result->data.binary.first = f;
    result->data.binary.second = g;
    return result;
}
```

**Why this matters**:
- Composable: `A ⊕ B ⊕ C` builds tree naturally
- Functional: No mutation, pure data structures
- Extensible: Add new morphism types for new YAML features

### 4.2 Semantic Actions in YACC

```yacc
%code {
    int yylex(YYSTYPE *yylval_param, void *yyscanner);
}

%%

map : map_entries {
    Generator *gs = malloc(sizeof(Generator));
    gs->type = GEN_TYPE_MAP_START;
    gs->value = NULL;
    
    /* Add to alphabet (YAML value universe) */
    if (ctx->alphabet->count >= ctx->alphabet->capacity) {
        ctx->alphabet->capacity *= 2;
        ctx->alphabet->generators = realloc(...);
    }
    ctx->alphabet->generators[ctx->alphabet->count++] = gs;
    
    /* Similar for end marker */
    
    /* Compose: MAP_START ⊕ entries ⊕ MAP_END */
    $$ = sd_compose(sd_generator(gs), 
           sd_compose($1, sd_generator(ge)));
}
```

**Pattern**: Each semantic action:
1. Allocates Generator (represents value)
2. Adds to Alphabet (global value registry)
3. Wraps in StringDiagram
4. Composes with surrounding structures

### 4.3 Anchor/Tag Application

```yacc
node : ANCHOR node_body {
    sd_set_anchor($2, $1);
    $$ = $2;
    free($1);
}
```

**Implementation**:
```c
void sd_set_anchor(StringDiagram *sd, const char *anchor) {
    if (!sd) return;
    if (sd->type == SD_TYPE_GENERATOR) {
        /* Apply directly to generator */
        if (sd->data.gen->anchor) free(sd->data.gen->anchor);
        sd->data.gen->anchor = strdup(anchor);
    } else {
        /* Propagate to leftmost generator (first component) */
        sd_set_anchor(sd->data.binary.first, anchor);
    }
}
```

**Why**: Anchor semantically applies to entire structure, but stored on leftmost generator.

---

## 5. Conflicts in YAML Parsing

### 5.1 Known Grammar Conflicts (pawel-yaml)

**Current state**: 35 conflicts (16 shift/reduce + 19 reduce/reduce)

**Common sources**:

1. **Tag before colon ambiguity**:
   ```yaml
   !!string: value     # Tag on key
   : !!string value    # Tag on value?
   ```

2. **Anchor scope ambiguity**:
   ```yaml
   &anchor key: value  # Anchor on key or entire pair?
   ```

3. **Flow vs block distinction**:
   ```yaml
   [ item1, item2 ]    # Flow sequence
   - item1             # Block sequence (different syntax)
   ```

### 5.2 Resolution Strategy (YACC Default)

**For shift/reduce**: Default to shift
```yaml
IF (C1) IF (C2) S1 ELSE S2
```
Shift on ELSE → Associates with inner IF ✓

**For YAML**:
- Shift often correct for flow context
- Reduce often correct for block context
- Lexer can help: Track flow depth to emit context-specific tokens

---

## 6. Error Recovery in pawel-yaml

### 6.1 Error Rules

```yacc
/* Attempt to recover from error */
nodes : node
      | nodes node
      | error { yyerror("Syntax error in YAML"); }
      ;
```

### 6.2 Recovery Points

```yacc
map_entries : map_entry
            | map_entries error '\n' { yyerrok; }
            | map_entries map_entry
            ;
```

**Strategy**: 
- Skip to newline or next valid structure
- Reset error state with `yyerrok`
- Continue parsing remainder

### 6.3 Semantic Recovery

Clean up partial parse tree:
```yacc
node : error {
    if (ctx->alphabet->count > 0) {
        free(ctx->alphabet->generators[--ctx->alphabet->count]);
    }
}
```

---

## 7. Performance Characteristics

### 7.1 Parser Speed

**LR(1) parsing** is optimal:
- Single pass left-to-right ✓
- One token lookahead ✓
- Linear time O(n) ✓
- Deterministic (no backtracking) ✓

**Comparison**:
- Hand-written recursive descent: Harder to maintain, bug-prone
- PEG parsers: Can backtrack exponentially in worst case
- Regex-based: Can't handle nested structures

### 7.2 Memory Usage

**Stack-based parser**:
- Proportional to nesting depth (not total input)
- Typical YAML files: 10-50 levels deep
- Huge YAML files: Bounded by structure, not file size

**Alphabet/Generator**:
- One entry per unique value
- Reused across structures
- Memory proportional to unique values, not total occurrences

---

## 8. Design Lessons: YACC for YAML

### 8.1 When YACC Succeeds

✓ Structured input with clear grammar  
✓ Need deterministic parsing  
✓ Multiple syntax forms for same semantics  
✓ Want parser generated, not hand-written  
✓ Error recovery is important  

### 8.2 When YACC Struggles

✗ Significant whitespace (partially solved by Flex)  
✗ Operator precedence explosion  
✗ Ambiguous spec (YAML 1.2 is complex!)  
✗ Need unlimited lookahead  

### 8.3 pawel-yaml's Approach

**Hybrid architecture**:
1. **Flex** handles tricky lexical issues (indentation, blocks)
2. **YACC** handles grammar and semantic composition
3. **RML** handles value representation (StringDiagram)
4. **Pragmatic**: Accept some conflicts, resolve with rules

**Result**: 
- Clean grammar specification (200+ lines)
- Robust parsing despite complexity
- Composable semantic actions
- Extensible for YAML features

---

## 9. YACC vs. Modern Alternatives

### 9.1 Why Still Use YACC in 2025?

**Advantages**:
- Mature technology (50 years!)
- Simple declarative syntax
- Fast parser generation
- Works offline (no internet needed)
- Portable C output
- Great error recovery

**Disadvantages**:
- Steep learning curve for beginners
- Less intuitive than combinator parsers
- Limited lookahead (1 token only)
- No built-in AST generation

### 9.2 Alternatives

| Tool | Approach | Best For |
|------|----------|----------|
| ANTLR | LL parsing + tree construction | Multiple languages, IDE integration |
| Nom (Rust) | Combinator parser | Type-safe, composable |
| Tree-sitter | Incremental parsing | Editor integration, live parsing |
| Happy (Haskell) | Lazy evaluation | Academic, functional approach |
| Menhir (OCaml) | Modular parser generation | Clean semantics, multiple backends |

**pawel-yaml choice**: YACC (Bison)
- Fits UNIX philosophy
- Simple, proven approach
- Minimal dependencies
- Educational value

---

## 10. Extending pawel-yaml with YACC

### 10.1 Adding New Features

**Example**: Support YAML 1.3 (hypothetical)

```yacc
/* Add new token */
%token NEW_FEATURE

/* Add to grammar */
node : new_feature_node
     | /* existing rules */
     ;

new_feature_node : NEW_FEATURE value { /* handle it */ }
                 ;
```

**Flex**: Update lexer to emit `NEW_FEATURE` token

**Semantic**: Add action to build appropriate StringDiagram

### 10.2 Fixing Current Grammar Conflicts

**Approach**:
1. Review grammar specification
2. Use `-Wcounterexamples` flag (Bison)
3. Identify ambiguous constructs
4. Rewrite rules to eliminate ambiguity
5. OR add explicit precedence declarations

**Example**:
```yacc
/* Avoid conflict by separating block and flow syntax */
node : block_node
     | flow_node
     ;

block_node : scalar | map | seq ;
flow_node : flow_map | flow_seq ;
```

---

## 11. Connection to UNIX Philosophy

### 11.1 The "Tool for Building Tools" Principle

From [03_UNIX_Operating_System.md](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md):

> "Tools for Building Tools (22:20-22:42): UNIX includes tools like parser generators (e.g., Yacc) that help in the development of other software tools."

**How pawel-yaml uses YACC**:

1. **Specialization**: 
   - Flex: Lexical analysis (tokenization)
   - YACC: Syntax analysis (parsing)
   - RML: Semantic analysis (representation)

2. **Composability**:
   - Each tool focuses on one aspect
   - Combined into complete system
   - Can replace any layer independently

3. **Automation**:
   - Grammar specified once
   - Parser generated automatically
   - Changes don't require hand-rewriting parser logic

4. **Portability**:
   - Standard C output
   - Runs on any UNIX-like system
   - No heavy runtime dependencies

### 11.2 Pipeline Example

```bash
# Traditional pipeline
$ lex pawel-yaml.l
$ yacc pawel-yaml.y
$ cc lex.yy.c parser.tab.c main.c -o pawel-yaml

# Modern Makefile approach
$ make all

# Use YAML parser on input
$ ./pawel-yaml < input.yaml > output.tree
```

Each stage:
- Transforms input to output
- Feeds next stage
- Solves specific problem
- Can be replaced/improved independently

---

## 12. Summary: YACC as Foundation for pawel-yaml

| Aspect | Role | Benefit |
|--------|------|---------|
| **Grammar** | Declarative specification | Easy to understand, modify, verify |
| **Parser** | Automatic generation | Correct LR(1) algorithm, optimized |
| **Semantic** | Action-driven | Flexible value computation |
| **Error Recovery** | Configurable rules | Robust handling of malformed input |
| **Integration** | Flex + RML | Complete language processing pipeline |
| **Maintenance** | Grammar-centric | Future changes localized to grammar |

**pawel-yaml demonstrates** how YACC remains a powerful, practical tool for parsing complex languages like YAML, when combined with:
- Modern lexer (Flex)
- Strong semantic framework (RML)
- Pragmatic grammar design
- Robust error handling

---

## References

- [YACC Comprehensive Guide](./YACC_COMPREHENSIVE_GUIDE.md)
- [YACC Quick Reference](./YACC_QUICK_REFERENCE.md)
- [Original YACC Paper](https://www.cs.utexas.edu/~novak/yaccpaper.htm)
- [UNIX Operating System](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md)
- [pawel-yaml Source](../../src/mrl.y)

---

**Document created**: February 2, 2026  
**Context**: Learning YACC and Flex for YAML parsing  
**Application**: pawel-yaml - YAML 1.2 parser using RML theory
