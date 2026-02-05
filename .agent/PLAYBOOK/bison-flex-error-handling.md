# Bison/Flex Error Handling Playbook

Based on IBM yacc/lex documentation and modern Bison practices. Reference: https://www.ibm.com/docs/en/zos/3.2.0?topic=yacc-error-handling

## Overview

Error handling in Bison (yacc) must be more sophisticated than in Flex (lex) because:
- **Flex**: Only detects erroneous input that can never have recognized meaning
- **Bison**: Must handle tokens that are individually valid but syntactically invalid in context
  - Example: `A = + * 5` — all tokens are valid, but the sequence is meaningless

## 1. The `error` Token (Error Recovery)

### Purpose
The `error` token is a special Bison symbol used to:
- Skip erroneous input and resume parsing at a sensible recovery point
- Discard tokens until a known synchronization point is reached
- Allow the parser to continue processing valid input after errors

### Basic Syntax

```bison
statement : IDENTIFIER '=' expression
          | error                          /* Skip bad input */
          ;

expression : term
           | expression '+' term
           | expression error term         /* Skip bad expression operators */
           ;
```

### How Error Recovery Works

1. **Error Detection**: Parser encounters unexpected token
2. **State Stack**: Parser looks back through its stack to find a state with `error` rule
3. **Token Discarding**: Discards lookahead token and input tokens until a valid reduction is possible
4. **Recovery**: Executes the `error` production rule
5. **Resumption**: Parser continues from the recovery point

### Common Error Recovery Patterns

#### Pattern 1: Skip to End of Statement

```bison
statement : expression ';'
          | error ';'              /* Skip to semicolon */
          | error NEWLINE          /* Skip to newline */
          ;
```

**Effect**: When parser encounters invalid input, it discards tokens until finding `;` or `\n`, then continues.

#### Pattern 2: Skip to End of Block

```bison
block : '{' statements '}'
      | error '}'                  /* Skip to closing brace */
      ;
```

#### Pattern 3: Skip Invalid Expression Components

```bison
expression : term
           | expression '+' term
           | expression error term     /* Skip bad operator/token */
           ;
```

## 2. The `yyerror()` Function

### Standard Function Signature

```c
void yyerror(const char *s)
{
    fprintf(stderr, "Error: %s\n", s);
}
```

### Advanced Usage with Location Tracking

```c
void yyerror(YYLTYPE *loc, const char *s)
{
    fprintf(stderr, "%s:%d.%d: Error: %s\n", 
            loc->first_line, loc->first_column, s);
}
```

### With Scanner Context (Flex Integration)

```c
void yyerror(const char *s, void *scanner)
{
    fprintf(stderr, "Lex: %d, Error: %s\n", yylineno, s);
}
```

### Return Codes Approach (Modern)

Instead of printing and continuing, return status:

```c
int yyerror(const char *s)
{
    fprintf(stderr, "Parse Error: %s\n", s);
    return 1;  /* Signal error to caller */
}
```

## 3. The `yyerrok` Macro

### Purpose
Clears the parser's error state to allow recovery to succeed.

### Usage Pattern

```bison
statement : KEYWORD expression
          | error KEYWORD                 /* Recovery point */
            {
                yyerrok;                  /* Clear error state */
                fprintf(stderr, "Recovered at KEYWORD\n");
            }
          ;
```

### What `yyerrok` Does

1. Clears the internal error flag
2. Allows the parser to accept the next token without error condition
3. Essential for successful recovery—without it, parser stays in error mode

### Critical: When Not to Use `yyerrok`

❌ **Wrong**: Calling `yyerrok` without consuming error recovery tokens
```bison
statement : expression
          | error
            {
                yyerrok;    /* WRONG: no tokens consumed */
            }
```

✅ **Right**: Using `yyerrok` after consuming synchronization tokens
```bison
statement : expression
          | error ';'      /* Consumed ';' */
            {
                yyerrok;    /* Now OK */
            }
```

## 4. Recovery Strategy Patterns

### Pattern A: Statement-Level Recovery

**Grammar:**
```bison
program : statements
        ;

statements : statement
           | statements statement
           ;

statement : expr ';'
          | PRINT expr ';'
          | error ';'
            {
                yyerror("Skipping to next statement");
                yyerrok;
            }
          ;
```

**Behavior**: Any syntax error skips tokens until finding `;`, then resumes

### Pattern B: Expression-Level Recovery

**Grammar:**
```bison
expression : term
           | expression '+' term
           | expression '-' term
           | expression error term
             {
                 yyerror("Invalid operator in expression");
                 $$ = $3;  /* Use right operand */
             }
           ;
```

**Behavior**: Parser skips bad tokens between operands

### Pattern C: Pragmatic Panic Mode

```bison
statement : expr ';'
          | definition ';'
          | error
            {
                /* Consume tokens until known recovery point */
                while (yylex() != SEMICOLON && yylex() != EOF) {
                    /* Skip */
                }
                yyerrok;
            }
          ;
```

**Behavior**: Manual token consumption in error handler

### Pattern D: Context-Aware Recovery

```bison
block : '{' stmts '}'
      | '{' error '}'
        {
            yyerror("Invalid block contents");
            yyerrok;
        }
      ;

nested_block : block
             | IF condition block ELSE block
             | IF condition block %prec LOWER
               error block
               {
                   yyerror("Missing ELSE clause");
                   $$ = $3;  /* Use IF block */
               }
             ;
```

## 5. Interaction Between Flex and Bison

### Flex-Level Error Handling

**Pattern 1: Skip Unknown Characters**
```flex
%%
[a-zA-Z]+     { return IDENTIFIER; }
[0-9]+        { return NUMBER; }
[ \t\n]       { /* Skip whitespace */ }
.             {
                fprintf(stderr, "Unknown character: %c\n", yytext[0]);
                /* Continue—don't return error token */
              }
%%
```

**Pattern 2: Flex Reporting to Bison**
```flex
%%
[a-zA-Z]+     { return IDENTIFIER; }
.             {
                yyerror("Invalid token");
                return 0;  /* Signal EOF or error */
              }
%%
```

### Coordinated Recovery

**Problem**: Flex can't know parser's recovery context

**Solution**: Use error token boundaries in Bison

```bison
statement : expr ';'
          | error ';'
            {
                /* Bison knows to look for ';' 
                   Flex just returns tokens until then */
                yyerrok;
            }
          ;
```

## 6. GLR (Generalized LR) Error Handling

### Special Considerations for GLR Parsers

**Default GLR behavior**: May continue exploring multiple parse paths before reporting error

```bison
%glr-parser

statement : expr SEMICOLON
          | error SEMICOLON
            {
                /* Recovery in GLR creates temporary parse trees */
                yyerrok;
            }
          ;
```

### Issues with GLR and Error Recovery

1. **Multiple Stack Branches**: Error recovery ambiguous across branches
2. **Deadlock Risk**: Conflicting recovery in different parse paths
3. **Performance**: GLR may try many recovery paths before succeeding

### GLR Error Handling Best Practices

✅ **DO**:
- Use `error` token sparingly in GLR grammars
- Provide clear synchronization points (semicolons, braces)
- Test error recovery extensively with GLR parsers
- Document which conflicts are intentional

❌ **DON'T**:
- Rely on complex error recovery in highly ambiguous grammars
- Mix `error` token across multiple similar productions
- Expect GLR error recovery to behave like LALR

## 7. Debugging Parser Hangs and Conflicts

### When Parser Hangs (Infinite Loop)

**Symptom**: Parser never completes, waits indefinitely

**Common Causes**:
1. Error recovery creates lookahead cycle
2. GLR conflict forces multiple parse paths with error rules
3. `yyerrok` called without sufficient token consumption

**Diagnosis**:
```bash
bison -v grammar.y  # Generates .output file
grep "S/R" grammar.y.output  # Find all shift/reduce conflicts
grep "R/R" grammar.y.output  # Find reduce/reduce conflicts
```

**Fix Strategies**:
1. **Add %dprec to disambiguate**:
   ```bison
   rule1 : something %dprec 1
         ;
   rule2 : something %dprec 2
         ;
   ```

2. **Refactor error recovery**:
   ```bison
   /* Before: ambiguous */
   statement : expr | error ;

   /* After: clear synchronization */
   statement : expr ';' | error ';' { yyerrok; } ;
   ```

3. **Simplify grammar** (e.g., flatten nested error rules)

### When Error Recovery Doesn't Trigger

**Symptom**: Parser keeps producing syntax errors instead of recovering

**Causes**:
1. `yyerrok` not called after recovery rule
2. Error token unreachable from parser state
3. Lookahead token doesn't match expected synchronizer

**Fix**:
```bison
/* Ensure error rule is reachable */
statement : valid_expr
          | error SEMICOLON  /* Explicit synchronizer */
            {
                yyerror("Statement skipped");
                yyerrok;      /* MUST call this */
            }
          ;
```

## 8. Return Codes and Error Propagation

### Modern Approach: Return Codes via `parse()` Function

Instead of calling `exit()`:

```c
/* In parser main function */
int main(void) {
    int result = yyparse();  /* Returns 0 = success, 1 = error */
    
    if (result == YYACCEPT) {
        /* Parse succeeded */
        return EXIT_SUCCESS;
    } else if (result == YYABORT) {
        /* Parse failed */
        return EXIT_FAILURE;
    } else {
        /* Parser error (rare) */
        return EXIT_FAILURE;
    }
}
```

### Custom Error Tracking

```c
typedef struct {
    int error_count;
    int warning_count;
    char last_error[256];
} ParseState;

static ParseState parse_state = {0};

void yyerror(const char *msg)
{
    parse_state.error_count++;
    strncpy(parse_state.last_error, msg, 255);
    fprintf(stderr, "Error: %s\n", msg);
}

int main(void) {
    int result = yyparse();
    
    if (parse_state.error_count > 0) {
        fprintf(stderr, "Failed with %d errors\n", parse_state.error_count);
        return 1;
    }
    return 0;
}
```

## 9. Testing Error Recovery

### Unit Test Template

```c
/* test_error_recovery.c */
int test_error_recovery(void) {
    const char *test_inputs[] = {
        "1 + + 2",        /* Missing operand */
        "5 * ;",          /* Unexpected terminator */
        "x = = 10",       /* Duplicate operator */
        NULL
    };
    
    for (int i = 0; test_inputs[i]; i++) {
        reset_parser();
        int result = parse_string(test_inputs[i]);
        
        assert(result != 0);  /* Should report error */
        assert(error_count > 0);
        
        /* Check recovery succeeded */
        assert(parser_state == STATE_RECOVERED);
    }
    return 0;
}
```

## 10. Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Missing `yyerrok` | Errors cascade indefinitely | Add `yyerrok;` after consuming recovery tokens |
| Error rule unreachable | No recovery happens | Ensure `error` production can be reached from error state |
| No synchronization tokens | Parser gets stuck | Add clear boundaries: `;`, `}`, `NEWLINE` |
| GLR ambiguity | Parser hangs on errors | Add `%dprec` or simplify grammar |
| Flex reports errors as tokens | Cascading parser errors | Handle unknown chars in Flex, not Bison |
| Manual token loop never exits | Infinite loop | Always have exit condition (EOF, specific token) |

## 11. Summary Checklist

**For implementing error recovery:**

- [ ] Define `error` productions at statement/expression level
- [ ] Implement `yyerror()` function (with/without return code)
- [ ] Call `yyerrok` after consuming synchronization tokens
- [ ] Use clear synchronization points (`;`, `}`, `\n`)
- [ ] Test error recovery with multiple invalid inputs
- [ ] Document expected error messages
- [ ] For GLR: Add `%dprec` directives to resolve conflicts
- [ ] Avoid calling `exit()` in parser—return codes instead
- [ ] Verify parser doesn't hang on malformed input
- [ ] Run `bison -v` to analyze conflicts

## References

- IBM Bison/Yacc Error Handling: https://www.ibm.com/docs/en/zos/3.2.0?topic=yacc-error-handling
- GNU Bison Manual: https://www.gnu.org/software/bison/manual/
- "lex & yacc" by O'Reilly (classic reference for error recovery patterns)
- GLR parser considerations: Bison manual section on GLR parsing
