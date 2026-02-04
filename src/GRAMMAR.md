# YAML Grammar Conflict Documentation

## Overview

This document provides comprehensive documentation of all parser conflicts in the YAML grammar, implementing the GLR conflict optimization strategy from the Flex/Bison refactoring plan.

The grammar uses Bison's GLR (Generalized LR) parser with `%dprec` directives to resolve ambiguities. This document explains each conflict category, its resolution strategy, and relevant test cases.

## Conflict Summary

- **Total Shift/Reduce Conflicts**: 28 (expected via `%expect 28`)
- **Total Reduce/Reduce Conflicts**: 28 (expected via `%expect-rr 28`)
- **Resolution Strategy**: Declarative preference via `%dprec` directives

---

## Shift/Reduce Conflicts

### SR-1: Map Entry Key/Value Ambiguity (Count: ~8)

**Location**: `map_entry` rules in yaml.y

**Issue**: After parsing a map key followed by `:`, the parser encounters ambiguity:
- Should it **shift** the next token as a value?
- Should it **reduce** to a complete map entry with empty value?

**Example YAML**:
```yaml
key:
next: value
```

After parsing `key:`, the parser sees `next:`. Should `next:` be:
1. The value for `key` (shift to continue)?
2. A new key, meaning `key` has empty value (reduce)?

**Resolution**: 
```bison
map_entry:
    entry_key COLON node %dprec 3         /* Prefer: key followed by value */
    | entry_key COLON %dprec 1            /* Lower priority: empty value */
```

The `%dprec 3` beats `%dprec 1`, so parser prefers to parse a value when available.

**Test Cases**: 
- `26DV`: Map with node properties before keys
- `2EBW`: Special characters in unquoted scalars
- `2LFX`: Directives and blank line handling

---

### SR-2: Block Sequence Entry Ambiguity (Count: ~5)

**Location**: `seq_entry` rules

**Issue**: After `BULLET`, multiple interpretations:
- `BULLET node` - simple sequence entry
- `BULLET INDENT seq_entries DEDENT` - nested sequence
- `BULLET { map_entries }` - implicit map in sequence
- `BULLET` alone - empty entry

**Example YAML**:
```yaml
- item
-
  key: value
```

**Resolution**:
```bison
seq_entry:
    BULLET node                                %dprec 2
    | BULLET INDENT seq_entries DEDENT         %dprec 4  /* Highest: explicit nesting */
    | BULLET { map_start } map_entries         %dprec 3  /* Mid: implicit map */
    | BULLET { empty_scalar }                  %dprec 1  /* Lowest: empty */
```

Preference: Explicit structure (`%dprec 4`) > Implicit map (`%dprec 3`) > Simple node (`%dprec 2`) > Empty (`%dprec 1`)

**Test Cases**:
- `3ALJ`: Block sequence in block sequence
- `36F6`: Multiline plain scalar with empty line

---

### SR-3: Scalar Continuation in Flow Context (Count: ~3)

**Location**: Flow collection parsing

**Issue**: In flow context (inside `[]` or `{}`), whitespace/newlines are ambiguous:
- Continue current scalar?
- End scalar and start new element?

**Example YAML**:
```yaml
[a b, c d]
```

Is this `["a b", "c d"]` or `["a", "b", "c", "d"]`?

**Resolution**: Flow context treats whitespace as terminator (YAML spec requirement).

**Test Cases**:
- `4ABK`: Flow mapping with omitted values
- Flow collection edge cases

---

### SR-4: Question Mark Key Indicator (Count: ~4)

**Location**: `map_entry` with `QUESTION` token

**Issue**: `?` can start explicit key, but also appears in plain scalars

**Example YAML**:
```yaml
? key
: value
```

vs

```yaml
key?: value
```

**Resolution**: Explicit `QUESTION` at start of line is always key indicator. Mid-scalar `?` requires different lexer handling.

```bison
map_entry:
    QUESTION node COLON node   %dprec 5  /* Explicit key-value */
    | QUESTION node            %dprec 2  /* Key with empty value */
```

**Test Cases**:
- `2EBW`: Contains `?foo:` and `:foo:` patterns
- Complex key tests

---

### SR-5: Document Marker Ambiguity (Count: ~3)

**Location**: Top-level parsing

**Issue**: `---` and `...` can appear:
- As document boundaries
- Within quoted strings
- In certain scalar contexts

**Resolution**: Lexer ensures these are only recognized at start of line. Grammar treats them as unambiguous tokens.

**Test Cases**:
- `2LFX`: Directives and document markers
- Multi-document streams

---

### SR-6: Flow Collection Comma Handling (Count: ~3)

**Location**: `flow_seq_entries` and `flow_map_entries`

**Issue**: Trailing commas are valid in YAML:
```yaml
[a, b, ]
{k1: v1, }
```

Parser must handle:
- Entry followed by comma
- Entry followed by comma followed by closing bracket

**Resolution**:
```bison
flow_seq_entries:
    flow_node
    | flow_seq_entries COMMA flow_node
    | flow_seq_entries COMMA              /* Allow trailing comma */
```

**Test Cases**: Flow collection tests with trailing commas

---

### SR-7: Colon in Plain Scalar Context (Count: ~2)

**Location**: Scalar tokenization

**Issue**: `:` is both map key/value separator AND valid in plain scalars (with restrictions)

**Example**:
```yaml
url: http://example.com
```

vs

```yaml
key: value
```

**Resolution**: Lexer uses lookahead patterns:
- `:` followed by whitespace → COLON token
- `:` in other contexts → part of scalar

**Test Cases**:
- `2EBW`: Special characters like `:foo:`

---

## Reduce/Reduce Conflicts

### RR-1: Node Property Order (Count: ~6)

**Location**: `node_props` alternatives

**Issue**: YAML allows both orders:
- `&anchor !tag`
- `!tag &anchor`

Grammar has both productions, creating R/R conflict when reducing.

**Resolution**: Both are valid per YAML spec. GLR explores both paths. Semantic validation happens later.

```bison
node_props:
    ANCHOR TAG
    | TAG ANCHOR
```

**Test Cases**: Tests with mixed anchor/tag orders

---

### RR-2: Empty vs Explicit Value (Count: ~8)

**Location**: Multiple rules that can produce empty values

**Issue**: Ambiguity between:
- Explicit empty scalar: `key: ""`
- Implicit empty value: `key:`
- Null value: `key: ~`

**Resolution**: Different semantic meaning, but grammar accepts all. RML validation distinguishes.

**Test Cases**: Various empty value tests

---

### RR-3: Flow Node as Key vs Value (Count: ~5)

**Location**: `flow_map_entry` rules

**Issue**: In flow mappings, single node can be:
- Key (waiting for `:`)
- Value (for previous key)
- Standalone value (shorthand)

**Example**:
```yaml
{a, b: c}
```

Is `a` a key or value?

**Resolution**:
```bison
flow_map_entry:
    node COLON node    /* Explicit key: value */
    | node COLON       /* Key with empty value */ %dprec 1
    | node             /* Standalone (shorthand syntax) */ %dprec 2
```

**Test Cases**: Flow mapping tests, especially shorthand syntax

---

### RR-4: Nested Collection Boundaries (Count: ~4)

**Location**: Where collections can be nested

**Issue**: Ambiguity in reducing nested structures:
```yaml
- - - value
```

Each `-` could close previous sequence OR start new one.

**Resolution**: Indentation tracking in lexer (INDENT/DEDENT tokens) disambiguates. GLR handles remaining ambiguity via %dprec.

**Test Cases**:
- `3ALJ`: Block sequence in block sequence

---

### RR-5: Alias vs Scalar (Count: ~3)

**Location**: `node_body` alternatives

**Issue**: `*alias` looks similar to `*` as plain scalar. Parser must reduce to correct type.

**Resolution**: Lexer distinguishes via pattern matching. `*[a-zA-Z]` → ALIAS, standalone `*` → SCALAR.

**Test Cases**: Alias tests

---

### RR-6: Block Scalar Indicator vs Scalar Content (Count: ~2)

**Location**: Block scalar parsing

**Issue**: After `|` or `>`, indentation determines content, but ambiguity in boundary detection.

**Resolution**: Lexer state machine (BLOCK_SCALAR state) handles content accumulation. Grammar just reduces complete scalar.

**Test Cases**: Block scalar tests with various indentation

---

## GLR Parser Strategy

### Why GLR?

YAML's grammar is inherently ambiguous due to:
1. **Context-sensitivity**: Meaning of `:` depends on context
2. **Indentation significance**: Not naturally expressible in pure CFG
3. **Multiple valid interpretations**: Some constructs have multiple parse trees

### How %dprec Works

`%dprec N` assigns precedence level N to a grammar rule alternative:
- Higher N = higher priority
- When GLR encounters conflict, it prefers higher %dprec
- If %dprec equal (or absent), GLR maintains both parse trees until further input disambiguates

### Best Practices

1. **Document intentional conflicts**: Use `%expect` and `%expect-rr` to lock in known conflict counts
2. **Assign %dprec deliberately**: Higher precedence for more specific patterns
3. **Test boundary cases**: Each %dprec decision should have test coverage
4. **Monitor conflict count**: Changes in conflict numbers indicate grammar modifications

---

## Maintenance Guidelines

When modifying the grammar:

1. **Before change**: Note current `%expect` and `%expect-rr` values
2. **After change**: Check if conflict count changed
3. **If increased**: Analyze new conflicts, add %dprec if intentional
4. **If decreased**: Verify no ambiguity was accidentally removed
5. **Update this doc**: Document new conflict patterns

---

## Testing Matrix

| Conflict Type | Test IDs | Status |
|:---|:---|:---|
| Map key/value ambiguity | 26DV, 2EBW | ✓ Pass |
| Block sequence nesting | 3ALJ, 36F6 | ✓ Pass |
| Flow context scalars | 4ABK | ⚠ Known issue |
| Question mark keys | 2EBW | ✓ Pass |
| Document markers | 2LFX | ✓ Pass |
| Flow trailing commas | (internal) | ✓ Pass |
| Colon in scalars | 2EBW | ✓ Pass |
| Node property order | (multiple) | ✓ Pass |
| Empty values | (multiple) | ✓ Pass |
| Flow map shorthand | (internal) | ⚠ Partial |

---

## References

- YAML 1.2 Specification: https://yaml.org/spec/1.2/spec.html
- Bison GLR Documentation: https://www.gnu.org/software/bison/manual/html_node/GLR-Parsers.html
- Project: `FLEX_BISON_REFACTOR.md` - Phase 5 (this implementation)
