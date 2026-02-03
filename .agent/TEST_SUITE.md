# YAML Test Suite Integration & Infrastructure

## Status: ✅ FULLY OPERATIONAL
The official `yaml-test-suite` (351 tests) is the primary target for all TDD and chaos engineering operations.

## Components
- **yaml-test-suite**: 351 official compliance test cases.
- **yaml-runtimes**: Reference implementations for behavioral comparison.
- **yaml-play**: Interactive tool for exploring YAML structures.

## Test Discovery & Execution
Test operations are managed via the unified tooling script:
```bash
./.agent/tooling.sh tdd:discover     # Discover tests filtered by TEST_FAILURES.yaml
./.agent/tooling.sh tdd:test <ID>    # Run a specific test case
```

## Persistence Strategy
The build system is designed to preserve these critical directories across standard `make clean` cycles:
- `build/lib/yaml-test-suite/`: Official cases.
- `build/tmp/`: Extracted test inputs and intermediate parser outputs.
- `build/log/`: Historical test results and chaos reports.

## Integration Highlights
- **Automated Extraction**: Tests are dynamically extracted from the official suite to `build/tmp/` for execution.
- **Compliance Tracking**: Pass/fail status is tracked against the `TEST_FAILURES.yaml` manifest.
- **Chaos Verification**: The test suite is used to verify that every grammar rule and lexer token is necessary (Active Rule Analysis).

## Performance
- Discovery is sub-second.
- Individual test execution takes ~50ms.
- Full "Chaos" validation takes ~20s.
