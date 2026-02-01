# YACC: Yet Another Compiler-Compiler - Comprehensive Guide



---

**Source**: [Johnson, Stephen C. "Yacc: Yet Another Compiler-Compiler"](https://www.cs.utexas.edu/~novak/yaccpaper.htm)

**Context**: This document complements the [UNIX Operating System philosophy](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md) which emphasizes:
> "Tools for Building Tools (22:20-22:42): UNIX includes tools like parser generators (e.g., Yacc) that help in the development of other software tools."

---

## Executive Summary

**YACC** is a parser generator that automates the construction of parsers from formal grammar specifications. It represents the UNIX philosophy of:
- **Modularity**: Breaking complex parsing into manageable rules
- **Composability**: Combining tools (YACC + Lex/Flex) for complete language processing
- **Abstraction**: Hiding complexity of LR parsing behind simple grammar notation

YACC transforms a specification of grammar rules and semantic actions into a C function (`yyparse`) that parses input according to that specification.

---

## 1. Core Concepts

### 1.1 What YACC Solves

**Problem**: Writing parsers for structured input is tedious, error-prone, and difficult to modify.

**Solution**: Specify the structure once in BNF-like notation; YACC generates the parser automatically.

**Applications**:
- Programming language compilers (C, Pascal, APL)
- Domain-specific languages (photo-typesetter language, calculator languages)
- System tools (lint, document retrieval, Fortran debugger)
- YAML parsers (like pawel-yaml)

### 1.2 Key Components

YACC input consists of **three sections** separated by `%%`:

```yacc
%{
    /* C declarations and includes */
%}

%token TERMINAL_NAMES
%type <type> nonterminal_names

%%

/* Grammar rules and actions */
rule1 : body { action }
      | body2 { action2 }
      ;

%%

/* Supporting C code (lexical analyzer, main, etc.) */
int yylex() { ... }
```

### 1.3 Grammar Rules

A **grammar rule** specifies a valid structure:

```yacc
A : B C D ;
```

This says: "A structure can be formed from B, C, and D in sequence."

**Syntax**:
- Left side: nonterminal name (structure being defined)
- Colon: separator
- Right side: sequence of tokens and nonterminals
- Semicolon: terminator
- **Vertical bar** (`|`): alternative rules for same left side

Example with alternatives:
```yacc
date : month_name day ',' year
     | month '/' day '/' year
     ;
```

---

## 2. Terminal Symbols vs. Nonterminals

### 2.1 Terminals (Tokens)

**Definition**: Basic input units recognized by the lexical analyzer.

- Declared with `%token` keyword
- Represent actual input characters or multi-character tokens (e.g., IDENTIFIER, NUMBER, KEYWORD)
- Literals enclosed in single quotes: `'+'`, `','`, `'\n'`
- Cannot appear on left side of grammar rule

**Example**:
```yacc
%token MONTH NUMBER COMMA
```

### 2.2 Nonterminals

**Definition**: Structures composed from terminals and other nonterminals.

- Appear on left side of grammar rules
- Can appear on right side of rules
- Represent intermediate parse constructs
- Every nonterminal must be defined (appear on left of at least one rule)

**Design decision**: Whether to handle structure in lexer or grammar?
- **Low-level**: Lexer recognizes individual letters, grammar builds month names → more rules, slower
- **High-level**: Lexer recognizes complete month names → simpler grammar, faster

YACC doesn't force the choice; designers decide based on efficiency and clarity.

---

## 3. Actions and Semantic Computation

### 3.1 Basic Actions

Each grammar rule can have an associated **action** (C code):

```yacc
rule : body { /* C code here */ }
```

The action executes when the rule is recognized during parsing.

**Examples**:
```yacc
A : '(' B ')' { hello(1, "abc"); }

expr : expr '+' expr { printf("Addition\n"); }
```

### 3.2 Return Values and Communication

**How to return a value from an action**:
```yacc
{ $$ = value; }
```

**How to access values from matched components** (using pseudo-variables):
```yacc
expr : '(' expr ')' { $$ = $2; }  /* Return the inner expression */
```

**Indexing**:
- `$1` = value from first component
- `$2` = value from second component
- `$n` = value from nth component
- `$$` = value to return from this rule

**Example**: Arithmetic expression
```yacc
expr : expr '+' expr { $$ = $1 + $3; }
     | expr '*' expr { $$ = $1 * $3; }
     | NUMBER { $$ = $1; }
     ;
```

### 3.3 Default Behavior

If no explicit action is given:
```yacc
A : B ;    /* Equivalent to: { $$ = $1; } */
```

First component's value is automatically returned.

### 3.4 Parse Tree Construction

Instead of immediate output, build an in-memory tree:

```yacc
expr : expr '+' expr { $$ = node('+', $1, $3); }
     | NUMBER { $$ = node_leaf($1); }
     ;
```

Then apply transformations before output (more flexible than direct output).

### 3.5 Actions Within Rules

Actions can appear in the middle of a rule:

```yacc
A : B { $$ = 1; } C { x = $2; y = $3; }
```

Internally, YACC creates a hidden nonterminal for the interior action:
```yacc
$ACT : /* empty */ { $$ = 1; }

A : B $ACT C { x = $2; y = $3; }
```

---

## 4. Lexical Analysis Integration

### 4.1 Lexical Analyzer Requirements

The user must supply `yylex()` function:

```c
int yylex() {
    /* Read from input */
    /* Return token number */
    /* Set yylval to token value (if any) */
}
```

**Key responsibilities**:
- Recognize basic tokens
- Return token numbers to parser
- Set `yylval` external variable with token's value
- Handle low-level issues (comments, continuation lines, etc.)

### 4.2 Token Number Coordination

Parser and lexer must agree on token numbers:

```yacc
%token DIGIT MONTH YEAR
```

YACC generates `#define` statements accessible to lexer:
```c
#define DIGIT 258
#define MONTH 259
#define YEAR 260
```

The lexer uses these in switch statements:
```c
int c = getchar();
if (isdigit(c)) {
    yylval = c - '0';
    return DIGIT;
}
```

### 4.3 Lex/Flex Integration

YACC works naturally with **Lex** (Mike Lesk's lexical analyzer):
- Lex uses regular expressions to specify token patterns
- Lex output is a lexer that works directly with YACC parsers
- Together: regular expressions (Lex) + grammar rules (YACC) = complete language processor

### 4.4 Special Endmarker Token

- **Endmarker**: Special token signaling end of input
- Token number: 0 or negative
- Parser uses endmarker to know when to stop
- Lexer returns endmarker when EOF reached

---

## 5. How YACC Parser Works

### 5.1 Parser Algorithm: Finite State Machine + Stack

YACC generates an **LR(1) parser** with:
- **Finite state machine**: States labeled with integers
- **Stack**: Holds parser states
- **Lookahead token**: Current token being considered

**Initial state**:
- Stack contains only state 0
- No lookahead token yet

### 5.2 Four Parser Actions

#### **Shift**
Move to next state, push current state onto stack:
```
In state 56, on token IF: shift 34
→ Push state 56 onto stack
→ Enter state 34
→ Clear lookahead token
```

#### **Reduce**
Apply a grammar rule backwards (RHS → LHS):

```yacc
A : x y z ;  /* Rule 18 */
```

To reduce:
1. Pop 3 states from stack (one for each RHS symbol x, y, z)
2. Uncover the previous state
3. Perform **goto** action based on LHS nonterminal (A)
4. Execute the action code associated with this rule
5. Keep lookahead token unchanged

#### **Goto**
Internal action (not directly visible):
- Performed after reduce when processing LHS nonterminal
- Uses table entry for (state, nonterminal) pair

#### **Accept**
Input successfully parsed:
- Lookahead is endmarker
- Parse tree matches start symbol
- Parser returns 0 (success)

#### **Error**
Syntax error detected:
- Input sequence cannot be followed by valid parse
- Error recovery attempted (see Section 7)
- Parser reports error

### 5.3 Value Stack

Parallel to state stack, a **value stack** holds:
- Token values (from `yylval`)
- Action return values (from `$$`)

**Pseudo-variable mapping**:
- `$1, $2, ...` refer to value stack
- `$$` refers to value being returned

### 5.4 Complete Example Trace

**Grammar**:
```yacc
%token DING DONG DELL
%%
rhyme : sound place ;
sound : DING DONG ;
place : DELL ;
```

**Input**: `DING DONG DELL`

**Trace**:
1. State 0, read DING
   - Action: shift 3 → State 3 pushed
   
2. State 3, read DONG
   - Action: shift 6 → State 6 pushed
   - Stack: [0, 3, 6]
   
3. State 6, no lookahead needed
   - Action: reduce by `sound : DING DONG`
   - Pop 2 states → uncover state 0
   - Goto on `sound` → state 2
   - Stack: [0, 2]
   
4. State 2, read DELL
   - Action: shift 5 → State 5 pushed
   - Stack: [0, 2, 5]
   
5. State 5, no lookahead needed
   - Action: reduce by `place : DELL`
   - Pop 1 state → uncover state 2
   - Goto on `place` → state 4
   - Stack: [0, 2, 4]
   
6. State 4, no lookahead needed
   - Action: reduce by `rhyme : sound place`
   - Pop 2 states → uncover state 0
   - Goto on `rhyme` → state 1
   - Stack: [0, 1]
   
7. State 1, read endmarker (`$end`)
   - Action: **accept**
   - Parse complete!

---

## 6. Ambiguity and Conflicts

### 6.1 Shift/Reduce Conflicts

**Definition**: Parser has choice between shifting next token or reducing current rule.

**Example**:
```yacc
expr : expr '-' expr
```

Input: `expr - expr - expr`

When parser sees second `-`:
- **Option 1 (shift)**: Continue reading → right-associative
- **Option 2 (reduce)**: Apply rule immediately → left-associative

**YACC's default**: Shift (leads to right-associativity)

### 6.2 Reduce/Reduce Conflicts

**Definition**: Parser has choice between two different reduction rules.

**YACC's default**: Reduce by earlier rule (in input order)

### 6.3 Why Conflicts Happen

1. **Ambiguous grammar**: Same input can parse multiple ways
2. **Insufficient lookahead**: More than 1 token needed to decide
3. **Design issues**: Grammar doesn't fully specify parse

### 6.4 YACC's Response

Despite conflicts, YACC still produces a parser using **disambiguating rules**:

1. **Shift/reduce conflict**: Default to **shift**
2. **Reduce/reduce conflict**: Default to **reduce by earlier rule**

**YACC reports**: Number of conflicts resolved

**Note**: Conflicts aren't errors! They're resolved systematically.

### 6.5 Classic Example: If-Then-Else

```yacc
stat : IF '(' cond ')' stat
     | IF '(' cond ')' stat ELSE stat
     ;
```

**Ambiguous input**: `IF (C1) IF (C2) S1 ELSE S2`

**Parse 1**: `IF (C1) { IF (C2) S1 } ELSE S2` (ELSE binds to outer IF)

**Parse 2**: `IF (C1) { IF (C2) S1 ELSE S2 }` (ELSE binds to inner IF - usual choice)

When parser sees ELSE after inner IF:
- **Shift**: Read ELSE, associate with inner IF ✓
- **Reduce**: Reduce inner IF immediately, associate with outer IF

YACC defaults to **shift**, giving correct interpretation!

---

## 7. Operator Precedence and Associativity

### 7.1 The Precedence Problem

Ambiguous grammar for expressions:
```yacc
expr : expr '+' expr
     | expr '-' expr
     | expr '*' expr
     | expr '/' expr
     | NUMBER
     ;
```

Questions:
- Is `a - b - c` interpreted as `(a-b)-c` or `a-(b-c)`? (associativity)
- Is `a + b * c` interpreted as `(a+b)*c` or `a+(b*c)`? (precedence)

### 7.2 Precedence Declarations

Instead of rewriting grammar, specify **precedence and associativity**:

```yacc
%left '+' '-'          /* Lower precedence, left-associative */
%left '*' '/'          /* Higher precedence, left-associative */
%right '='             /* Right-associative */
%nonassoc '<' '>' '==' /* No associativity (error on repeated use) */
```

**Rules**:
- Lines ordered by **increasing precedence**
- All tokens on same line have same precedence
- `%left`: Reduce on same-precedence operator (left-associative)
- `%right`: Shift on same-precedence operator (right-associative)
- `%nonassoc`: Error on same-precedence repetition

### 7.3 Effect on Expression Parsing

```yacc
%left '+' '-'
%left '*' '/'

expr : expr '+' expr { $$ = $1 + $3; }
     | expr '-' expr { $$ = $1 - $3; }
     | expr '*' expr { $$ = $1 * $3; }
     | expr '/' expr { $$ = $1 / $3; }
     | NUMBER { $$ = $1; }
     ;
```

**Input**: `a + b * c - d`

**Result**: `a + (b * c) - d` (correct precedence and left-associativity)

### 7.4 Unary Operators

Unary `-` has different precedence than binary `-`:

```yacc
%left '+' '-'
%left '*' '/'

expr : expr '+' expr { $$ = $1 + $3; }
     | expr '-' expr { $$ = $1 - $3; }
     | expr '*' expr { $$ = $1 * $3; }
     | expr '/' expr { $$ = $1 / $3; }
     | '-' expr %prec '*'  { $$ = -$2; }  /* Unary minus = mult precedence */
     | NUMBER { $$ = $1; }
     ;
```

**`%prec` keyword**: Override default precedence (normally = last token on RHS)

---

## 8. Error Handling and Recovery

### 8.1 Error Detection

**When detected**: As early as theoretically possible (left-to-right scan)

**Default behavior**: Without error recovery, parser stops and returns 1 (failure)

### 8.2 Error Recovery Rules

Use special `error` token to specify recovery points:

```yacc
/* Skip entire statement on error */
stat : error { /* recovery action */ }

/* Skip to next semicolon */
stat : error ';' { /* recovery action */ }

/* Interactive re-entry */
input : error '\n' { yyerrok; printf("Reenter: "); } input { $$ = $4; }
```

### 8.3 Error State Management

**After error detection**, parser:

1. Pops stack until state can accept `error` token
2. Treats `error` as if it were the lookahead token
3. Performs action for error rule
4. Enters **error mode** (suppress further error messages)
5. Continues until 3 tokens shifted successfully
6. Returns to normal mode

**Purpose**: Prevent cascading error messages from single mistake.

### 8.4 Error Recovery Macros

```c
yyerrok;      /* Force parser to believe error is fully recovered */
yyclearin;    /* Clear old lookahead token, read next one */
```

**Example**: Sophisticated resynchronization
```yacc
stat : error { 
    resynch();    /* Custom routine to find next valid statement */
    yyerrok;      /* Signal recovery complete */
    yyclearin;    /* Clear stale token */
}
```

---

## 9. YACC File Format and Structure

### 9.1 Specification File Sections

```yacc
%{
    /* C declarations section */
    #include <stdio.h>
    int variable = 0;
%}

%token TERMINAL1 TERMINAL2
%type <int> nonterminal1

%%

/* Grammar rules */
rule1 : body1 { action }
      | body2 { action }
      ;

%%

/* Supporting C code */
int yylex() { ... }
```

### 9.2 Declaration Section

**Allowed declarations**:
- `%token` - declare terminal symbols
- `%type <type>` - declare nonterminal return types
- `%union { ... }` - declare value stack union (for multiple types)
- `%start symbol` - specify start symbol (default: first rule's LHS)
- `%left`, `%right`, `%nonassoc` - operator precedence
- `%{ ... %}` - embedded C code (included in generated parser)

### 9.3 Rules Section

**Format**:
```yacc
name : body ;
     | body2 ;
     | body3 ;
     ;
```

**Body elements**:
- Nonterminal names
- Terminal token names (defined in %token)
- Literals (single-quoted characters): `','`, `'+'`, etc.
- Actions in `{ }` braces

### 9.4 Programs Section

**Contains**:
- Lexical analyzer (`yylex()`)
- Main program (calls `yyparse()`)
- Error handler (`yyerror()`)
- Helper functions
- Any other C code

---

## 10. Type Support

### 10.1 The Problem

By default, all values are integers. For richer values (structs, doubles), need type system.

### 10.2 Union Declaration

```yacc
%union {
    int ival;
    double dval;
    struct interval { double lo, hi; } vval;
}
```

### 10.3 Type Association

```yacc
%token <ival> DIGIT LETTER
%token <dval> CONST
%type <dval> dexp
%type <vval> vexp
```

### 10.4 Automatic Type Checking

When you use `$1`, `$2`, `$$`:
- YACC inserts appropriate union member access
- C compiler type-checks the result
- No unwanted conversions

**Example**:
```yacc
%type <dval> dexp
dexp : CONST { $$ = $1; }      /* Inserts: .dval automatically */
     | dexp '+' dexp { $$ = $1 + $3; }
```

---

## 11. Style Guidelines for YACC Specifications

### 11.1 Naming Conventions

```yacc
%token KEYWORD IDENTIFIER NUMBER  /* UPPERCASE for tokens */
%type <int> statement expression   /* lowercase for nonterminals */
```

### 11.2 Formatting

```yacc
rule : component1 component2
     | component3 component4
     | component5
     ;
```

Benefits:
- Rules and actions clearly separated
- Easy to modify individual alternatives
- Semantic structure visible through action code

### 11.3 Left Recursion Encouraged

```yacc
/* Good: left-recursive (efficient, bounded stack) */
list : item
     | list ',' item
     ;

/* Bad: right-recursive (inefficient, unbounded stack) */
list : item
     | item ',' list
     ;
```

Left recursion processes items as they arrive; right recursion defers until all consumed.

### 11.4 Empty Rules

```yacc
optional_items : /* empty */
               | optional_items item
               ;
```

First alternative reduces immediately for empty sequence. Permits great generality.

### 11.5 Lexical Tie-ins

Global flags communicate between lexer and parser:

```yacc
%{ int in_declaration; %}

prog : decls { in_declaration = 0; } stats ;

decls : /* empty */ { in_declaration = 1; }
```

Allows context-dependent lexical decisions (e.g., whitespace handling).

---

## 12. Advanced Features

### 12.1 Accessing Values Outside Immediate Rule

Can reference values from surrounding context:

```yacc
sent : adj noun verb adj noun { /* can reference all 5 values */ }
```

In middle of noun recognition:
```yacc
noun : CRONE { if ($0 == YOUNG) { printf("what?\n"); } $$ = CRONE; }
```

`$0` refers to value of previous `adj`.

### 12.2 Multiple Endmarkers

Using `YYACCEPT` macro:
```yacc
statement : expr { YYACCEPT; }  /* End parsing after expr */
```

### 12.3 Context-Sensitive Checking

Using `YYERROR` macro:
```yacc
vexp : '(' dexp ',' dexp ')' {
    $$.lo = $2;
    $$.hi = $4;
    if ($$.lo > $$.hi) {
        printf("interval out of order\n");
        YYERROR;  /* Force error recovery */
    }
}
```

---

## 13. Practical Design Patterns

### 13.1 Calculator Grammar

```yacc
%{
#include <stdio.h>
int regs[26];
%}

%token DIGIT LETTER
%left '+' '-'
%left '*' '/' '%'
%left UMINUS

%%

list : /* empty */
     | list stat '\n'
     | list error '\n' { yyerrok; }
     ;

stat : expr { printf("%d\n", $1); }
     | LETTER '=' expr { regs[$1] = $3; }
     ;

expr : '(' expr ')' { $$ = $2; }
     | expr '+' expr { $$ = $1 + $3; }
     | expr '-' expr { $$ = $1 - $3; }
     | expr '*' expr { $$ = $1 * $3; }
     | expr '/' expr { $$ = $1 / $3; }
     | '-' expr %prec UMINUS { $$ = -$2; }
     | LETTER { $$ = regs[$1]; }
     | DIGIT { $$ = $1; }
     ;

%%

yylex() {
    int c = getchar();
    if (islower(c)) { yylval = c - 'a'; return LETTER; }
    if (isdigit(c)) { yylval = c - '0'; return DIGIT; }
    return c;
}

main() { return yyparse(); }

yyerror(char *s) { fprintf(stderr, "%s\n", s); }
```

### 13.2 Date Parser

```yacc
date : month_name day ',' year { format_date($1, $2, $4); }
     | month '/' day '/' year { format_date($1, $2, $5); }
     ;

month_name : JANUARY | FEBRUARY | ... | DECEMBER ;

year : NUMBER { if ($1 < 1900) error("year too early"); $$ = $1; }

day : NUMBER { if ($1 < 1 || $1 > 31) error("bad day"); $$ = $1; }
```

---

## 14. Troubleshooting Common Issues

### 14.1 Conflicts in Output

```
src/grammar.y: warning: 5 shift/reduce conflicts [-Wconflicts-sr]
src/grammar.y: warning: 2 reduce/reduce conflicts [-Wconflicts-rr]
```

**Diagnosis**: Review grammar, check for ambiguities

**Solutions**:
1. Add precedence declarations (`%left`, `%right`)
2. Rewrite grammar to eliminate ambiguity
3. Accept conflicts if behavior is desired (document why!)

### 14.2 Rules "Useless in Parser"

Warning: Rule never reached due to conflicts

**Cause**: Conflict resolution makes rule unreachable

**Fix**: Rewrite grammar or adjust precedence

### 14.3 Infinite Loops

Parser gets stuck:
- Check for `error` token handling
- Verify lexer returns endmarker
- Ensure grammar has no infinite recursion

### 14.4 Wrong Parse Results

**Debugging**:
1. Use `yydebug = 1;` to enable verbose tracing
2. Check `y.output` file (generated with `-v` option)
3. Review action code for bugs
4. Test with simple inputs first

---

## 15. Relationship to UNIX Philosophy

### 15.1 UNIX's "Tools for Building Tools"

From [03_UNIX_Operating_System.md](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md):
> "Tools for Building Tools (22:20-22:42): UNIX includes tools like parser generators (e.g., Yacc) that help in the development of other software tools."

YACC exemplifies this by:
- **Specialization**: Single well-defined task (generate parsers from grammars)
- **Composability**: Works with Lex to form complete language pipeline
- **Abstraction**: Users specify structure; YACC handles implementation
- **Portability**: Written in C, generates C code

### 15.2 Pipeline Composition

```bash
# UNIX pipeline for parsing
cat input | lex input.l | yacc input.y | gcc | ./a.out
```

- **Lex**: Tokenization (regex → tokens)
- **YACC**: Parsing (tokens → parse tree)
- **Compiler**: Code generation
- **Execute**: Result

### 15.3 Design Philosophy

**From UNIX principles applied to YACC**:

1. **Do one thing well**: YACC handles grammar, not semantics
2. **Expect output to become input**: YACC → C compiler → executable
3. **Modular composition**: Lexer + Parser + Semantic analyzer
4. **Make mechanism visible**: Verbose output (`-v` flag) shows parser states
5. **Small, sharp tools**: Focused specification language with clear semantics

---

## 16. Real-World Applications

### 16.1 Original Uses

- **Compilers**: C compiler, Pascal compiler, APL
- **Domain languages**: Photo-typesetter control, calculator languages
- **System tools**: `lint` (C static analyzer), document retrieval
- **Debugging**: Fortran debugging system

### 16.2 Modern Applications

- **Language implementations**: Any new language needs a parser
- **Configuration languages**: XML, JSON parsers often start with YACC-like tools (Bison)
- **Protocol parsers**: Network protocol specifications
- **YAML parsers**: Like pawel-yaml (subject of this project)

### 16.3 YAML Parsing Challenges

YAML is complex for YACC because:
- **Implicit syntax**: Indentation carries meaning (significant whitespace)
- **Anchor/alias system**: Forward references via tags
- **Multiple representations**: Same data in different formats
- **Context sensitivity**: Behavior depends on parsing state

**Solution**: Combine:
- **Flex lexer**: Handle indentation and block scalars
- **YACC parser**: Handle document structure with anchors/aliases
- **Semantic actions**: Build parse trees with StringDiagram morphisms (RML theory)

---

## 17. Summary: YACC as a "Tool for Building Tools"

| Aspect | How YACC Exemplifies UNIX Philosophy |
|--------|----------------------------------------|
| **Abstraction** | Hide parsing complexity behind simple grammar notation |
| **Composition** | Combine with Lex for complete language processing |
| **Specialization** | Focus on grammar → parser transformation |
| **Modularity** | Separate tokenization, parsing, semantics |
| **Automation** | Generate code automatically from specifications |
| **Correctness** | LR(1) parsing proven mathematically sound |
| **Observability** | Verbose output reveals parser mechanics |
| **Portability** | C source ensures runs everywhere C runs |

**YACC is the quintessential "tool for building tools"** because it doesn't just solve parsing—it provides a framework for creating new parsers without starting from scratch.

---

## 18. References and Further Learning

**Primary Source**: [Johnson, Stephen C. "Yacc: Yet Another Compiler-Compiler"](https://www.cs.utexas.edu/~novak/yaccpaper.htm)

**UNIX Context**: [03_UNIX_Operating_System.md](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md#tools-for-building-tools)

**Related Tools**:
- **Lex**: For lexical analysis (tokenization)
- **Bison**: GNU version of YACC (backward compatible, enhanced)
- **Modern alternatives**: ANTLR, Yacc.js (JavaScript), tree-sitter

**Learning Path**:
1. Understand UNIX philosophy and tool composition
2. Learn regular expressions (foundation for Lex)
3. Study formal grammars (BNF notation)
4. Master YACC through simple examples
5. Advance to complex specifications (multiple types, error recovery)
6. Integrate with Lex for complete language processing

---

## Appendix: Key Terms Glossary

| Term | Definition |
|------|-----------|
| **Action** | C code executed when grammar rule is recognized |
| **Ambiguity** | Multiple valid parses for same input |
| **Conflict** | Shift/reduce or reduce/reduce choice point |
| **Endmarker** | Special token signaling end of input |
| **Grammar rule** | Statement defining valid input structure |
| **LR(1) parser** | Left-to-right, rightmost derivation, 1-token lookahead |
| **Lookahead token** | Current token being examined by parser |
| **Nonterminal** | Intermediate structure in grammar |
| **Precedence** | Binding strength of operators |
| **Reduce** | Apply grammar rule backward (RHS → LHS) |
| **Shift** | Move to next state, consume lookahead token |
| **Start symbol** | Top-level nonterminal representing complete input |
| **Terminal (Token)** | Basic input unit recognized by lexer |
| **Value stack** | Parallel stack holding semantic values |
| **Yacc** | Yet Another Compiler-Compiler |

---

**Document created**: February 2, 2026  
**Based on**: Johnson's original YACC paper (1975)  
**Context**: Learning YACC for pawel-yaml YAML parser development
