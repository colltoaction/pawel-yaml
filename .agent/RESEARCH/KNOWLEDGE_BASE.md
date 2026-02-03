# Knowledge Base: Research & History ⚛️

Archive project research, session logs, and technical deep-dives.

---

## 📓 Research Directory

### [Applied YAML Parsing](YACC/YACC_YAML_PARSING_GUIDE.md)
Explore mapping RML theory to YAML constructs.

### [YACC History & Concepts](YACC/YACC_COMPREHENSIVE_GUIDE.md)
Consolidate knowledge on YACC's origin and integration with Flex.

---

## 📅 Session Logs & Historical Context

### Session: Chaos Engineering & Infrastructure Recovery (Feb 1, 2026)
**Objective**: Establish a robust TDD infrastructure and recover the `yaml-test-suite` as the primary development target.

**Key Accomplishments**:
- **Infrastructure**: Created automated test discovery and chaos engineering logic (now consolidated in `.agent/tooling.sh`).
- **Test Discovery**: Configured logic to filter and execute 351 official YAML tests.
- **Pass Rate Baseline**: Established a 58% pass rate, identifying major blockers in multi-line scalars and flow context handling.
- **Build System**: Refactored `make clean` to be TDD-safe (preserves artifacts in `build/tmp/` and `build/lib/`).

**Architectural Findings**:
- Verified 15 core architectural elements (parser alternatives and lexer rules) as essential.
- Identified that shift/reduce and reduce/reduce conflicts were blocking flow mapping implementation (`5T43`).
- Determined that Multi-line Plain Scalars were a "High Impact" target for future cycles (~20 test cases).

**Strategic History**:
- **Macro Cycles**: Progressed from initial chaos to a stabilized "Growing" phase with GLR and AST-lite support.
- **Agentic TDD**: Successfully applied named-reference refactoring across the grammar to resolve positional reference technical debt.

---

## 🛠 Chaos Engineering Research & Results

### Overview
Chaos engineering in `pawel-yaml` is a systematic approach to verifying the necessity of grammar rules and lexer tokens. By intentionally removing code and measuring the impact on the `yaml-test-suite`, we ensure a 0% dead-code architecture.

### Methodology
1.  **Parser Chaos (`tooling.sh chaos:parsing`)**: Backup `src/mrl.y`, remove an alternative, rebuild, and run tests. If all pass, the code is **DEAD**.
2.  **Lexer Chaos (`tooling.sh chaos:lexing`)**: Backup `src/mrl.l`, disable a rule, and run tests.

### Findings Summary (February 2026)
**1. Parser Grammar Necessity**:
All major grammar alternatives verified as **ACTIVE**:
- `ALIAS` in `node_body`
- `ANCHOR` propagation
- `DOC_START` / `DOC_END` handling
- `BLOCK_KEY` explicit mappings
- `QUESTION` mark handling in maps
- Flow context delimiters

**2. Lexer Token Necessity**:
All 9 major lexer rules are **ACTIVE** and essential:
- **TAG**: `!tag` types.
- **ANCHOR**: `&anchor` definitions.
- **ALIAS**: `*alias` references.
- **QUOTED**: Double-quoted strings with escapes.
- **SINGLE**: Single-quoted strings.
- **BLOCK_SCALAR**: `|` and `>` multi-line content.
- **BLOCK_SEQ**: `- ` list indicators.
- **BLOCK_KEY**: `? ` explicit keys.
- **PLAIN_SCALAR**: Context-sensitive unquoted values (Critical complexity).

### Strategic Insights
- **Failures due to Missing Features**: Since no dead code exists, failures are primarily due to missing implementation (multi-line scalars, flow mappings) rather than redundant logic.
- **GLR Consistency**: The transition to GLR has maintained rule necessity while resolving ambiguities.

---

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

---

## 🎯 Case Study: Applied YAML Parsing
YAML's complexity (block vs. flow styles, indentation, anchors) requires a tight integration between Flex (Lexer) and YACC (Parser).

### 1. Hybrid Architecture
- **Flex (Lexer)**: Manages indentation stacks, block scalar accumulation, and tokenization.
- **YACC (Parser)**: Manages structural rules (maps, seqs) and semantic composition using **RML StringDiagram** morphisms.

### 2. Key YAML Patterns
- **Indentation**: Lexer emits `INDENT` and `DEDENT` tokens based on leading whitespace.
- **Morphisms**: `sd_compose(start, sd_compose(entries, end))` represents sequential composition of YAML containers.
- **Anchors**: Applied to the leftmost generator (the first component) of a StringDiagram structure.

---

## 🎓 Summary of Learning Objectives
- ✓ **LR(1) Mastery**: Understanding how YACC's state machine handles complex grammars.
- ✓ **Deterministic Recovery**: Using the `error` token to build resilient parsers.
- ✓ **Semantic Purity**: Using StringDiagrams to maintain composable, functional state.
- ✓ **Chaos Validation**: Ensuring every part of the grammar is essential.
