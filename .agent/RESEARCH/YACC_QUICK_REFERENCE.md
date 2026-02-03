# YACC Quick Reference & Decision Tree

**Quick Links**: [Full Guide](./YACC_COMPREHENSIVE_GUIDE.md) | [UNIX Context](../COMPUTING_INSPIRATION/03_UNIX_Operating_System.md)

---

## 1. Minimal YACC Template

```yacc
%{
#include <stdio.h>
%}

%token TOKEN1 TOKEN2

%%

start_rule : TOKEN1 TOKEN2 { printf("Matched!\n"); }
           ;

%%

int yylex() {
    int c = getchar();
    if (c == 'a') return TOKEN1;
    if (c == 'b') return TOKEN2;
    return c;
}

int main() { return yyparse(); }

void yyerror(const char *s) { fprintf(stderr, "Error: %s\n", s); }
```

---

## 2. Grammar Rule Syntax at a Glance

| Pattern | Meaning | Example |
|---------|---------|---------|
| `A : B C D ;` | Sequence | `expr : term '+' term` |
| `A : B \| C ;` | Alternatives | `stmt : if_stmt \| while_stmt` |
| `A : ;` | Empty rule | `list : \| list item` |
| `A : B { action }` | With action | `expr : NUMBER { $$ = $1 * 2 }` |
| `A : B %prec C` | Precedence override | `expr : '-' expr %prec '*'` |

---

## 3. Pseudo-Variables (Inside Actions)

```yacc
rule : component1 component2 component3
     {
         $1        /* Value from component1 */
         $2        /* Value from component2 */
         $3        /* Value from component3 */
         $$        /* Return value for this rule */
         $$ = $1;  /* Common: pass through first value */
     }
     ;
```

---

## 4. Declarations Quick Reference

```yacc
%token IDENTIFIER NUMBER STRING      /* Terminal symbols */
%type <int> expr statement            /* Nonterminal return types */
%start program                        /* Top-level rule */
%left '+' '-'                         /* Left-associative operators */
%right '='                            /* Right-associative operator */
%nonassoc '<' '>'                     /* Non-associative operators */

%union {                              /* Multiple return types */
    int ival;
    double dval;
    char *sval;
}

%left <int> '+' '-'                   /* Token with type */
%type <dval> expression               /* Nonterminal with type */
```

---

## 5. Operator Precedence Pattern

Lower precedence first, higher precedence last:

```yacc
%left OR                    /* || - lowest precedence */
%left AND                   /* && */
%left '=' NE                /* == != */
%left '<' '>' LE GE         /* < > <= >= */
%left '+' '-'               /* + - */
%left '*' '/' '%'           /* * / % - higher precedence */
%right '^'                  /* ^ - right-associative */
%right UMINUS               /* unary - highest precedence */

%%

expr : expr OR expr         { $$ = $1 || $3; }
     | expr AND expr        { $$ = $1 && $3; }
     | expr '=' expr        { $$ = ($1 == $3); }
     | expr '+' expr        { $$ = $1 + $3; }
     | expr '*' expr        { $$ = $1 * $3; }
     | '-' expr %prec UMINUS { $$ = -$2; }
     | NUMBER               { $$ = $1; }
     | '(' expr ')'         { $$ = $2; }
     ;
```

---

## 6. Error Recovery Patterns

**Skip to next semicolon**:
```yacc
statement : valid_statement
          | error ';' { yyerrok; }
          ;
```

**Skip entire line (interactive)**:
```yacc
input : /* empty */
      | input line
      ;

line : statement '\n'
     | error '\n' { yyerrok; printf("Enter next line: "); }
     ;
```

**Context-aware recovery**:
```yacc
element : value
        | error { resynch(); yyerrok; yyclearin; }
        ;
```

---

## 7. Value Types Pattern

```yacc
%union {
    int intval;
    double dblval;
    char *strval;
}

%token <intval> INTEGER
%token <strval> IDENTIFIER
%token <dblval> FLOAT

%type <intval> integer_expr
%type <dblval> float_expr

%%

integer_expr : INTEGER { $$ = $1; }
             | integer_expr '+' integer_expr { $$ = $1 + $3; }
             ;

float_expr : FLOAT { $$ = $1; }
           | float_expr '*' float_expr { $$ = $1 * $3; }
           ;
```

---

## 8. Parse Tree Construction Pattern

```yacc
%{
typedef struct node {
    char *label;
    struct node *left;
    struct node *right;
} Node;

Node *make_node(char *label, Node *left, Node *right) {
    Node *n = malloc(sizeof(Node));
    n->label = label;
    n->left = left;
    n->right = right;
    return n;
}
%}

%union { Node *nval; }
%type <nval> expr

%%

expr : expr '+' expr { $$ = make_node("+", $1, $3); }
     | expr '*' expr { $$ = make_node("*", $1, $3); }
     | NUMBER { $$ = make_node("num", NULL, NULL); }
     ;
```

---

## 9. Lexer Integration Checklist

**Lexer must provide** (`yylex()` function):
- ✓ Return token number for each input unit
- ✓ Set `yylval` if token has a value
- ✓ Return 0 (or negative) at end of input (endmarker)
- ✓ Handle comments, whitespace, special cases

**Example**:
```c
int yylex() {
    static int c;
    
    /* Skip whitespace */
    while ((c = getchar()) == ' ' || c == '\t' || c == '\n')
        ;
    
    /* End of input */
    if (c == EOF)
        return 0;
    
    /* Identifier */
    if (isalpha(c)) {
        char buf[128]; int i = 0;
        while (isalnum(c)) { buf[i++] = c; c = getchar(); }
        ungetc(c, stdin);
        buf[i] = 0;
        yylval.strval = strdup(buf);
        return IDENTIFIER;
    }
    
    /* Single character token */
    return c;
}
```

---

## 10. Debugging Workflow

**Generate verbose output**:
```bash
yacc -v -d -o parser.c grammar.y
# Creates parser.y, parser.tab.h, y.output
```

**Examine parser states in `y.output`**:
```
state 23
    stat : IF '(' cond ')' stat_        (18)
    stat : IF '(' cond ')' stat_ ELSE stat
    
    ELSE  shift 45
    .     reduce 18
```

**Enable debug tracing**:
```c
extern int yydebug;
yydebug = 1;  /* Before yyparse() */
yyparse();
```

**Interpret debug output**:
- `state N`: Entering parser state N
- `shift M`: Reading token, pushing state M
- `reduce R`: Applying rule R
- `goto S`: Moving to state S after reduce

---

## 11. Decision Tree: How to Design a Grammar

```
┌─ Problem: Parse structured input
│
├─ 1. What's the top-level structure?
│     └─ Define as start symbol
│
├─ 2. What are the major components?
│     └─ Define as nonterminals
│
├─ 3. What are the atomic tokens?
│     ├─ Keywords, identifiers, numbers
│     ├─ Declare with %token
│     └─ Handle in lexer (yylex)
│
├─ 4. What sequences/alternatives exist?
│     └─ Write grammar rules
│
├─ 5. Are there operator precedence issues?
│     ├─ Yes: Add %left, %right, %nonassoc
│     └─ No: Continue
│
├─ 6. What semantic value to compute?
│     ├─ Return values with $$
│     ├─ Access arguments with $1, $2, ...
│     └─ Handle in action code
│
├─ 7. Are there error cases to handle?
│     ├─ Yes: Add error recovery rules
│     └─ No: Rely on error reporting
│
└─ 8. Run YACC, check for conflicts
     ├─ Conflicts present: Debug with y.output
     └─ No conflicts: Good!
```

---

## 12. Common Patterns by Use Case

### Arithmetic Expression Parser
```yacc
%left '+' '-'
%left '*' '/'

expr : expr '+' expr { $$ = $1 + $3; }
     | expr '*' expr { $$ = $1 * $3; }
     | '(' expr ')' { $$ = $2; }
     | NUMBER { $$ = $1; }
     ;
```

### List Parser
```yacc
list : item
     | list ',' item
     ;

item : IDENTIFIER { process($1); }
```

### Nested Structure Parser
```yacc
stmt : '{'  stmts  '}' { $$ = $2; }
     | simple_stmt
     ;

stmts : /* empty */ { $$ = NULL; }
      | stmts stmt { $$ = append($1, $2); }
      ;
```

### Key-Value Parser
```yacc
mapping : /* empty */
        | mapping pair
        ;

pair : KEY ':' VALUE { insert($1, $3); }
```

---

## 13. Performance Tips

| Issue | Solution |
|-------|----------|
| Stack overflow on long lists | Use **left recursion** (not right) |
| Parser too large | Split into multiple YACC files |
| Slow parsing | Optimize lexer (don't tokenize char-by-char) |
| Ambiguous rules | Add `%left`/`%right` precedence |
| Memory leak | Free allocated values in error rules |

---

## 14. Troubleshooting Table

| Problem | Likely Cause | Solution |
|---------|--------------|----------|
| Shift/reduce conflicts | Ambiguous grammar | Add precedence or rewrite |
| "rule is useless" | Unreachable due to conflict | Review grammar design |
| Parser wrong on simple input | Action bug | Check `$1, $2, $$` usage |
| Unexpected parse results | Missing precedence | Add `%left` or `%right` |
| Lexer returns wrong tokens | yylex() bug | Trace token returns |
| Memory errors | Unfreed pointers | Call free() in error rules |
| Infinite loop | No end-of-input token | Lexer must return 0 |
| Multiple errors before stop | Error mode not exited | Add `yyerrok;` to recovery |

---

## 15. YACC Command-Line Options

```bash
yacc [options] grammar.y
```

| Option | Purpose |
|--------|---------|
| `-d` | Generate `parser.tab.h` with token definitions |
| `-o file` | Write parser to `file` instead of `y.tab.c` |
| `-v` | Generate `y.output` (verbose parser description) |
| `-b prefix` | Use prefix instead of `y` for generated names |
| `-t` | Include code for debugging |
| `-p symbol` | Change default start symbol |
| `-l` | Don't include `#line` directives |

**Modern Bison** (compatible, enhanced):
```bash
bison [-d] [-o file] [-v] grammar.y  # Same interface
bison --define api.pure=true grammar.y  # Reentrant parser
```

---

## 16. Key Insight: Reduce vs. Shift

When parser sees `a - b - c`:

**Shift (-reduce, left-associative)**:
- Parse `a - b` → `(a - b) - c` ✓

**Reduce (alternative)**:
- Parse `a - (b - c)` (right-associative)

YACC default: **Shift** on same-precedence operator
- Result: Left-associative (what we want for `-`)

Override with `%right` to get right-associativity:
```yacc
%right '-'   /* Now: a - b - c parses as a - (b - c) */
```

---

## 17. Critical Section: Token Coordination

**Lexer and parser MUST agree**:

YACC generates:
```c
#define TOKEN1 258
#define TOKEN2 259
#define IDENTIFIER 260
```

Lexer must use same values:
```c
yylex() {
    if (isalpha(c)) { return IDENTIFIER; }  /* Must return 260 */
    ...
}
```

Mismatch → Parser receives wrong token → Parse failure!

---

## 18. How to Read `y.output`

**Example state**:
```
state 15
    expr : expr '+' expr_       (1)
    expr : expr '*' expr_       (2)
    
    '+' shift 25
    '*' shift 30
    .   reduce 1
```

**Meaning**:
- Parser sees `expr '+' expr`, then another operator
- If next is `'+'`: Shift (defer reduction)
- If next is `'*'`: Shift (defer reduction)
- Otherwise: Reduce by rule 1 (expr : expr '+' expr)

This implements left-associativity and precedence!

---

## 19. Real-World YAML Parsing Challenge

**Why YAML is hard in YACC**:

1. **Implicit structure**: Indentation carries syntax
   - Solution: Flex lexer manages indent stack
   
2. **Anchors/aliases**: Forward references
   - Solution: Grammar rules for `&name` and `*name` tokens
   
3. **Block scalars**: Multi-line strings
   - Solution: Lexer accumulates lines, returns as single token
   
4. **Context sensitivity**: Same input parsed differently based on position
   - Solution: RML StringDiagram algebra (semantic layer)

**pawel-yaml approach**:
- Flex: Tokenization + indentation + block scalar handling
- Bison: Grammar rules + anchor/alias support
- RML: StringDiagram morphisms for semantic values

---

## 20. Connection to UNIX Philosophy

**YACC embodies**:
1. **Single responsibility**: Generate parsers from grammar
2. **Composable tools**: Works with Lex for complete pipeline
3. **Automation**: Don't hand-code what can be specified declaratively
4. **Mechanism visible**: `-v` flag shows parser internals
5. **Portable**: Generates C, runs everywhere

**Classic pipeline**:
```
lex source.l | yacc source.y | cc | ./a.out < input
```

Each tool:
- Does one thing excellently
- Outputs feeds next tool's input
- Solves a specific problem

**Result**: Complex language processors built from simple, reusable pieces.

---

**Quick Reference Version**: Use with [Full Guide](./YACC_COMPREHENSIVE_GUIDE.md) for details  
**Last Updated**: February 2, 2026
