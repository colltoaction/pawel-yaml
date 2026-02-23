# Chaos Engineering Procedures

Chaos engineering in this project aims to verify the necessity and health of every grammar rule and lexer token. By systematically removing or disabling components and measuring the impact on the `yaml-test-suite`, we ensure zero dead code and high structural integrity.

## 1. Parser Chaos Analysis

This procedure identifies dead or redundant grammar alternatives in `src/stream.y`.

### Procedure
1. **Target Identification**: Choose a specific grammar alternative or rule to test.
2. **Component Removal**: 
   - Backup `src/stream.y`.
   - Remove the target lines (e.g., using `sed` or manual edit).
3. **Build Validation**:
   - Run `make -j4`.
   - If the build fails, the component is **ESSENTIAL** (syntactically required for the grammar to be valid).
4. **Behavioral Validation**:
   - If the build succeeds, run a selection of tests (e.g., `./tests/legacy/scripts/tdd_harness.sh discover | shuf | head -10`).
   - If all tests pass despite the removal, the component is **DEAD CODE** or redundant.
   - If tests fail, the component is **ACTIVE** and necessary for correctness.
5. **Restoration**: Restore `src/stream.y` from backup.

## 2. Lexer Chaos Analysis

This procedure verifies that all lexer rules in `src/scanning.l` are necessary and correctly prioritized.

### Procedure
1. **Target Identification**: Select a lexer rule return (e.g., `return BULLET;`, `return TAG;`).
2. **Rule Disabling**:
   - Comment out or change the return statement in `src/scanning.l`.
   - Example: `// return TAG;`
3. **Impact Measurement**:
   - Run specific tests known to exercise that rule.
   - Use `./tests/legacy/scripts/tdd_harness.sh test <ID>` for known target cases.
4. **Conclusion**:
   - If the test fails as expected, the rule is **NECESSARY**.
   - If the test still passes, the rule might be shadowed by another rule or handled as a plain scalar incorrectly.

### Specific Test: Quoted Map Keys
To verify `QMAP_KEY` and `SMAP_KEY`:
1. Remove the specific rule for quoted keys in `src/scanning.l`.
2. Verify that ` "key": value ` or ` 'key': value ` fails to parse or is parsed incorrectly.
3. Restore rules to maintain compatibility with the YAML spec.

## 3. Automation Scripts
The following scripts (deprecated and consolidated here) provided the basis for these procedures:
- `chaos.sh`: Grammar alternative removal automation.
- `chaos_lexing.sh`: Lexer rule necessity reporting.
- `lexing_chaos.sh`: Targeted quoted-key necessity tests.
