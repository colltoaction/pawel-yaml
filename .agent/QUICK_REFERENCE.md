# Pawel-YAML Quick Reference

**Last Updated**: January 31, 2026

---

## 📊 Current Status at a Glance

| Metric | Value |
|--------|-------|
| **Pass Rate** | 8.3% (29/351) |
| **Passing Tests** | 29 |
| **Expected Failures** | 322 |
| **Regressions** | 0 |
| **Memory Leaks** | 0 |
| **Phase** | 2 Complete, 3 In Progress |

---

## 📁 Documentation Map

| File | Purpose | When to Read |
|------|---------|--------------|
| **README.md** | Quick overview | First time, quick status check |
| **CONSOLIDATED_STATUS.md** | Complete project status | Deep dive, onboarding |
| **TESTS_STATUS.md** | Test tracking | Check passing tests |
| **TEST_FAILURES.yaml** | Failing tests list | Pick next test to fix |
| **TEST_FAILURES_WORKFLOW.md** | TDD workflow | Learn the process |
| **THEORY_ALIGNED_SOLUTION.md** | Architecture | Understand design |
| **PHASE2_COMPLETION.md** | Phase 2 details | Historical reference |
| **CONSOLIDATION_SUMMARY.md** | Recent changes | See what was updated |

---

## 🚀 Common Commands

```bash
# Run full test suite
./test_yaml_suite.sh

# Save test results
./test_yaml_suite.sh > test_results.txt

# Count passing tests
grep "✓" test_results.txt | grep -v "expected failure" | wc -l

# Build project
make clean && make

# Run unit tests
make test

# Memory check
valgrind --leak-check=full ./build/pawel-yaml < test.yaml

# Start yaml-play environment
make yaml-play
```

---

## ✅ TDD Workflow (Quick)

1. Pick test from `TEST_FAILURES.yaml`
2. **RED**: Verify it fails
3. **GREEN**: Make it pass (minimal change)
4. **REFACTOR**: Clean up code
5. Run full test suite (ensure 0 regressions)
6. Commit: `feat: XXXX` (where XXXX = test ID)
7. Remove test from `TEST_FAILURES.yaml`
8. Update `TESTS_STATUS.md` and `README.md`

---

## 🎯 Current Priorities

1. **Block scalar support** (`>`, `|` indicators)
2. **Complex mapping keys** (`? key : value`)
3. **Better error messages**
4. **Target**: 50+ tests passing (14.2%)

---

## 📈 Progress Tracking

### Milestones
- [x] Phase 1: Core Parser (Complete)
- [x] Phase 2: RML Engine (Complete)
- [ ] Phase 3: Parser Completeness (In Progress)
  - [ ] 15% pass rate (53 tests)
  - [ ] 25% pass rate (88 tests)
  - [ ] 50% pass rate (176 tests)

### Recent Progress
- Jan 31: 29 tests passing (up from 24)
- Jan 30: Phase 2 complete
- Jan 30: Zero memory leaks achieved

---

## 🔧 File Locations

### Source Code
- `src/yaml_parser.c` - Main parser
- `src/yaml.y` - Bison grammar
- `src/lexer.l` - Flex lexer
- `src/mrl.c` - RML engine

### Tests
- `test_yaml_suite.sh` - Test runner
- `test_results.txt` - Latest results
- `src/test_mrl.c` - Unit tests

---

## 💡 Quick Tips

- **Always run full test suite before committing**
- **Never remove from TEST_FAILURES.yaml until test passes**
- **Keep documentation synchronized**
- **Use `make clean && make` to verify build**
- **Check for memory leaks with valgrind**

---

## 📞 Need More Info?

- Architecture → `THEORY_ALIGNED_SOLUTION.md`
- Complete Status → `CONSOLIDATED_STATUS.md`
- Test Details → `TESTS_STATUS.md`
- Workflow → `TEST_FAILURES_WORKFLOW.md`
