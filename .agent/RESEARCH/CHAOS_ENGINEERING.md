# Chaos Engineering Research & Results

## Overview
Chaos engineering in `pawel-yaml` is a systematic approach to verifying the necessity of grammar rules and lexer tokens. By intentionally removing code and measuring the impact on the `yaml-test-suite`, we ensure a 0% dead-code architecture.

## Methodology

### Parser Chaos (`tooling.sh chaos:parsing`)
1. Backup `src/mrl.y`.
2. Remove a specific grammar alternative.
3. Attempt to rebuild and run a random sample of tests.
4. If all tests still pass, the code is **DEAD**. If any fail, the code is **ACTIVE**.
5. Restore backup.

### Lexer Chaos (`tooling.sh chaos:lexing`)
1. Backup `src/mrl.l`.
2. Disable a specific lexer rule (e.g., return statement).
3. Attempt to rebuild and run tests.
4. If tests pass, the rule is **DEAD**.
5. Restore backup.

## Findings Summary (February 2026)

### 1. Parser Grammar Necessity
All major grammar alternatives have been verified as **ACTIVE**:
- `ALIAS` in `node_body`
- `ANCHOR` propagation
- `DOC_START` / `DOC_END` handling
- `BLOCK_KEY` explicit mappings
- `QUESTION` mark handling in maps
- Flow context delimiters

### 2. Lexer Token Necessity
All 9 major lexer rules are **ACTIVE** and essential:
1. **TAG**: `!tag` types.
2. **ANCHOR**: `&anchor` definitions.
3. **ALIAS**: `*alias` references.
4. **QUOTED**: Double-quoted strings with escapes.
5. **SINGLE**: Single-quoted strings.
6. **BLOCK_SCALAR**: `|` and `>` multi-line content.
7. **BLOCK_SEQ**: `- ` list indicators.
8. **BLOCK_KEY**: `? ` explicit keys.
9. **PLAIN_SCALAR**: Context-sensitive unquoted values (Critical complexity).

## Baseline Metrics
- **Test Suite**: yaml-test-suite (351 tests).
- **Pass Rate**: Currently ~60% (Growing phase).
- **Dead Code**: 0 verified.

## Strategic Insights
- **Missing Features over Optimization**: Since no dead code exists, failures are primarily due to missing implementation (multi-line scalars, flow mappings, etc.) rather than redundant logic.
- **GLR Consistency**: The transition to GLR has maintained rule necessity while resolving ambiguities.
