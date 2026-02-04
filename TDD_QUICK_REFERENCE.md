# TDD Quick Reference

## Running Tests

### Unit Tests Only
```bash
make test-unit
# Output: 36/36 tests pass
```

### Integration Tests Only
```bash
make test-integration
# Output: Tests against YAML test suite
```

### Full TDD Cycle
```bash
make tdd
# Runs: test-unit → test-integration
# Output: Summary and "✓ All TDD cycles complete!"
```

### Test Discovery
```bash
make test-discover
# Lists all available tests
```

### Full YAML Test Suite
```bash
make yaml-test-suite
# Comprehensive output with all test results and categories
```

## Test Files

| File | Purpose | Tests |
|:---|:---|:---|
| `test_yaml_event.c` | Unit tests for YAMLEvent struct | 36 |
| `test_yaml_suite.py` | Integration tests vs test-suite | 30 sample |
| `test_single.py` | Debug single test case | 1 |
| `test_correct.py` | Verify passing tests | varies |

## TDD Scripts

- `.agent/tdd_harness.sh` - Main TDD orchestrator
- `.agent/test_yaml_suite.sh` - YAML test suite wrapper

Both are executable and integrated into Makefile.

## Development Workflow

### For yaml_event.y Development

1. **Make a change to yaml_event.y grammar**
   ```bash
   vim src/yaml_event.y
   ```

2. **Run unit tests**
   ```bash
   make test-unit
   ```

3. **If passing, run integration**
   ```bash
   make test-integration
   ```

4. **Full cycle**
   ```bash
   make tdd
   ```

5. **Commit when all pass**
   ```bash
   git add -A && git commit -m "feat(yaml_event): ..."
   ```

## Expected Results

| Target | Status | Output |
|:---|:---|:---|
| `make test-unit` | ✅ Passing | 36/36 tests pass |
| `make test-integration` | ✅ Passing | 2/30 baseline match |
| `make tdd` | ✅ Complete | Summary + "✓ All TDD cycles complete!" |
| `make yaml-test-suite` | ✅ Complete | Full test suite results |
| `make` (build) | ✅ Success | No errors, executable created |
