# Test Suite Setup Guide

## Objective
Configure YAML test suite infrastructure for full verification testing of pawel-yaml parser.

## Architecture

### Test Suite Components
1. **YAML Test Suite**: Standard YAML 1.2 compliance tests (351 tests total)
2. **Test Runner**: `.agent/test_yaml_suite.sh` - Executes tests and reports results
3. **Verification Scripts**: `.agent/stage4_*.sh` - Full verification and analysis
4. **Parser**: `./build/bin/pawel-yaml` - Built from src/

### Current Status
- **Binary**: ✅ Builds successfully
- **Test Suite**: ⏳ Needs setup (expects at `build/lib/yaml-test-suite/src`)
- **Test Runner**: ✅ Scripts exist
- **Verification**: ⏳ Requires test suite

## Setup Instructions

### Option 1: Clone YAML Test Suite (Recommended)
```bash
# Create directory structure
mkdir -p build/lib
cd build/lib

# Clone official YAML test suite
git clone https://github.com/yaml/yaml-test-suite.git

# Verify structure
ls -la yaml-test-suite/src/
```

### Option 2: Download Specific Tests
```bash
# Download from YAML test suite repository
cd build/lib
wget -z yaml-test-suite.tar.gz https://github.com/yaml/yaml-test-suite/archive/refs/heads/main.tar.gz
tar xzf yaml-test-suite.tar.gz
mv yaml-test-suite-main/src yaml-test-suite/src
```

### Option 3: Manual Test File Setup
```bash
# Create minimal test directory with specific test cases
mkdir -p build/lib/yaml-test-suite/src
cd build/lib/yaml-test-suite/src

# Create test subdirectories
mkdir -p {26DV,229Q,etc}

# Add test files for each case:
# - data.yaml (YAML input)
# - meta.yaml (test metadata)
# - events.txt (expected events)
```

## Test Execution

### Build Test Suite Support
```bash
# Add to Makefile (if needed)
.PHONY: yaml-test-suite
yaml-test-suite:
	@echo "Setting up YAML test suite..."
	@mkdir -p build/lib
	@cd build/lib && git clone https://github.com/yaml/yaml-test-suite.git 2>/dev/null || true
```

### Run Full Verification
```bash
# Build parser
make clean && make

# Run test suite
bash ./.agent/test_yaml_suite.sh

# Full verification (requires test suite)
bash ./.agent/stage4_full_verification.sh
```

### Run Specific Test
```bash
# Test single case (e.g., 26DV - anchors on keys)
./build/bin/pawel-yaml < build/lib/yaml-test-suite/src/26DV/data.yaml
```

## Understanding Test Results

### Pass/Fail Criteria
- **PASS**: Parser output matches expected events exactly
- **FAIL**: Output differs or parser hangs/crashes
- **SKIP**: Test marked as optional or requires special handling

### Common Issues
1. **Test Suite Not Found**: Run setup steps above
2. **Parser Hangs**: Known issue on certain tests (e.g., 26DV) - fix pending Phase 10
3. **Event Mismatch**: May indicate parser correctness issues or event format differences

## Troubleshooting

### Error: "yaml-test-suite not found"
```bash
# Verify directory structure
ls -RT build/lib/yaml-test-suite/src | head -20

# If empty, run setup:
cd build/lib
git clone https://github.com/yaml/yaml-test-suite.git
```

### Parser Hangs During Testing
```bash
# Use timeout to prevent infinite loops
timeout 2 ./build/bin/pawel-yaml < test_file.yaml

# Or configure test runner with timeout:
# Edit .agent/test_yaml_suite.sh to add timeout wrapper
```

### Memory Issues During Full Suite Run
```bash
# Run tests in smaller batches
for dir in build/lib/yaml-test-suite/src/*/; do
    test_name=$(basename "$dir")
    timeout 2 ./build/bin/pawel-yaml < "$dir/data.yaml" > /tmp/out.txt 2>&1
    echo "Processed: $test_name"
done
```

## Git Integration

### Excluding Test Suite from Version Control
```bash
# Add to .gitignore (if not already present)
build/lib/yaml-test-suite/
build/tmp/

# Verify
git status build/lib/
```

### Persisting Test Results
```bash
# Commit test logs to repository
build/log/full_test_results.txt   # ✅ Track
build/log/test_failures.yaml      # ✅ Track
build/tmp/                        # ❌ Ignore (temporary)
```

## Next Steps
1. **Phase 10**: Use test suite to verify GLR conflict fixes
2. **Continuous Integration**: Automate test runs on commit
3. **Performance Monitoring**: Track pass rate improvements over time
4. **Regression Testing**: Ensure fixes don't break existing passes

## Resources
- Official YAML Test Suite: https://github.com/yaml/yaml-test-suite
- YAML 1.2 Specification: https://yaml.org/spec/1.2/spec.html
- Test Case Documentation: See individual test metadata files
