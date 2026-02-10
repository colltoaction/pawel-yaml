# Remaining Test Regressions

**Status as of 2026-02-10**

## Summary
- **Current**: 241/351 tests passing (68.66%)
- **Baseline**: 196/351 tests passing (55.84%)
- **Progress**: +45 tests fixed
- **True regressions remaining**: 21 valid YAML tests
- **Expected failures remaining**: 51 documented tasks

## Completed Fixes (3 TDD Cycles)

### Cycle 1: Unicode + Ambiguity
- Fixed extract_test_yaml.py Unicode character conversion (␣ → space, ———» → tab, ↵ → newline)
- Resolved GLR ambiguity in flow collections (removed %empty from flow_seq_entry/flow_map_entry)
- **Impact**: 196 → 221 tests (+25)

### Cycle 2: Composition Tags
- Extended composition.l tag pattern to support ! and % in tag handles  
- **Impact**: 221 → 237 tests (+6 + fixed ambiguity = +16 net)

### Cycle 3: Directive Placement
- Allow directives before DOC_START in explicit_document rule
- Restore implicit_document DOC_END patterns
- **Impact**: 237 → 241 tests (+4)

## Remaining Regression Categories

### 1. Plain Scalar Context (7 tests) - CH_RAW Issues
**Tests**: 5T43, 7T8X, 9JBA, C2DT, SU5Z, Y79Y, Z67P

**Root Cause**: Parser expects specific tokens but receives CH_RAW (plain scalar fragments) in:
- Flow map values after quoted keys: `{ "key":value }`
- Block scalars followed by content
- Comments without whitespace: `"value"#comment`
- Plain scalars in unexpected contexts

**Fix Strategy**: Requires lexer state management improvements for PLAIN_SCALAR_CONT mode in flow contexts, and potentially grammar adjustments to accept plain scalar construction (scalar_parts) in more contexts.

### 2. Anchor/Alias Handling (3 tests)
**Tests**: 4JVG, GT5M, SR86

- **4JVG**: Anchored map keys: `&k1 key1: val1` - parser rejects ANCHOR where MAP_KEY expected
- **GT5M**: Anchor between sequence items without BULLET
- **SR86**: Alias reference in unexpected position

**Fix Strategy**: Expand map_entry and seq_entry rules to accept ANCHOR/ALIAS tokens in key positions. May require entry_key rule restoration from old grammar.

### 3. End-of-File Handling (2 tests)
**Tests**: 98YD, LE5A

- **98YD**: File with only comment: `# Comment only.\n\n`
- **LE5A**: Sequence ending at EOF without newline

**Fix Strategy**: Adjust EOF handling in implicit_document and documents rules to allow empty content or trailing elements.

### 4. Colon Handling (2 tests)
**Tests**: LX3P, X8DW

- **LX3P**: Flow sequence as map key: `[flow]: block`
- **X8DW**: Complex key with comment: `---\n? key\n# comment\n: value`

**Fix Strategy**: Complex key parsing improvements, allow comments between ? and : in explicit complex keys.

### 5. Block Scalar Indentation Indicators (2 tests)
**Tests**: 2G84, X4QW

- **2G84**: `--- |0` - explicit indentation indicator "0"
- **X4QW**: `block: ># comment` - block scalar with comment on same line

**Fix Strategy**: Lexer improvements for block scalar modifier parsing (indentation + chomping indicators).

### 6. Edge Cases (5 tests)
- **P76L**: ',' after tag in explicit document: `%TAG !! ...\n---\n!!int 1 - 3`
- **N782**: DOC_START in flow sequence: `[\n--- ,\n...\n]`
- **6CA3**: Leading em-dash before flow: `—[` (tab character followed by bracket)
- **UDR7**: MAP_KEY token in unexpected position
- **Q5MG**: Tabs used for indentation (currently rejected, may need to accept if test expects pass)

**Fix Strategy**: Individual grammar adjustments for each edge case.

## Expected Failures (51 tests)

These are documented in TEST_FAILURES.yaml as known issues (features not yet implemented or deliberate limitations). They should be addressed after all regressions are fixed.

## Recommendations for Next Session

1. **Priority 1**: Fix plain scalar context handling (7 tests) - largest impact
   - Review old grammar's entry_key and flow value handling
   - Improve PLAIN_SCALAR_CONT lexer state management
   
2. **Priority 2**: Anchor/alias improvements (3 tests)
   - Restore entry_key flexibility from dd264d6 grammar
   
3. **Priority 3**: EOF and edge cases (9 tests)
   - Individual fixes, lower complexity

4. **Priority 4**: Expected failures (51 tasks)
   - Feature implementation work

## Technical Debt Notes

- GLR conflicts increased from 55 R/R to 52 R/R (acceptable range)
- Shift/reduce conflicts at 61 (up from 57)
- Consider refactoring documents/explicit_document rules to reduce ambiguity
- Lexer state machine (PLAIN_SCALAR_CONT, INITIAL, flow_level) needs review for consistency
