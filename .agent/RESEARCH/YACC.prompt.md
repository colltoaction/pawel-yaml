## 📚 YACC: Comprehensive Guide
**Source**: [Johnson, Stephen C. "Yacc: Yet Another Compiler-Compiler"](https://www.cs.utexas.edu/~novak/yaccpaper.htm)

### 1. Core Concepts
**YACC** is a parser generator that automates the construction of parsers from formal grammar specifications. It transforms a specification of grammar rules and semantic actions into a C function (`yyparse`).

**Input Structure**:
- **C Declarations**: Includes and global variables.
- **Declarations**: Tokens and nonterminal types.
- **Grammar Rules**: BNF-like rules with associated C actions.
- **Programs**: Supporting C code (e.g., `yylex`, `main`).

### 2. Actions and Semantic Computation
Each grammar rule can have an associated **action**:
- **`$$`**: The value returned by the rule.
- **`$1, $2, ...`**: Values from the components of the rule.
- **Default Action**: `$$ = $1`.

### 3. Parser Algorithm: LR(1)
YACC generates an **LR(1) parser** (Left-to-Right, Rightmost derivation, 1-token lookahead).
- **Shift**: Read a token and push the current state onto a stack.
- **Reduce**: Apply a grammar rule backwards (replace RHS with LHS on the stack).
- **Goto**: Transitions between states based on nonterminals.

### 4. Ambiguity and Conflict Resolution
- **Shift/Reduce Conflict**: Parser can either shift a token or reduce a rule. Default: **Shift**.
- **Reduce/Reduce Conflict**: Parser can reduce by two different rules. Default: **First rule in spec**.
- **Precedence**: Use `%left`, `%right`, and `%nonassoc` to resolve expression ambiguities.

---

## 🚀 YACC Quick Reference (Cheatsheet)

### Minimal Template
```yacc
%{ #include <stdio.h> %}
%token TOKEN
%%
start : TOKEN { printf("Match\n"); };
%%
int main() { return yyparse(); }
```

### Common Declarations
- `%token <type> NAME`: Terminal symbol with a specific semantic value type.
- `%type <type> NAME`: Nonterminal with a specific return type.
- `%union { ... }`: Defines the types available on the value stack (`yylval` and `$$`).

### Error Recovery Pattern
```yacc
statement : valid_statement
          | error ';' { yyerrok; } /* Skip to next semicolon */
          ;
```
