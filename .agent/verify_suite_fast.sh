#!/bin/bash
# Fast YAML Test Suite Verification with Progress
# Tests all 351 cases with real-time progress updates

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SUITE_DIR="build/lib/yaml-test-suite/src"
PARSER="./build/bin/pawel-yaml"
WORK_DIR="build/tmp"
LOG_DIR="build/log"
RESULTS_FILE="$LOG_DIR/full_test_results.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  YAML Test Suite - Fast Verification (351 tests)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
if [[ ! -d "$SUITE_DIR" ]]; then
    echo -e "${RED}ERROR: yaml-test-suite not found${NC}"
    exit 1
fi

if [[ ! -x "$PARSER" ]]; then
    echo -e "${RED}ERROR: Parser not built. Run 'make' first${NC}"
    exit 1
fi

mkdir -p "$WORK_DIR" "$LOG_DIR"

# Count total tests
TOTAL_TESTS=$(ls "$SUITE_DIR"/*.yaml 2>/dev/null | wc -l)
echo -e "${BLUE}Total test cases: $TOTAL_TESTS${NC}"
echo ""

# Initialize counters
PASS=0
FAIL=0
SKIP=0
COUNT=0

# Clear results
> "$RESULTS_FILE"

echo "Running tests..." | tee -a "$RESULTS_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"

# Process tests with progress indicator
for test_file in "$SUITE_DIR"/*.yaml; do
    test_id=$(basename "$test_file" .yaml)
    ((COUNT++))
    
    # Progress every 25 tests
    if ((COUNT % 25 == 0)); then
        echo -ne "\r${CYAN}Progress: $COUNT/$TOTAL_TESTS tests (Pass: $PASS, Fail: $FAIL)${NC}"
    fi
    
    # Extract YAML and expected result
    test_yaml="$WORK_DIR/${test_id}_test.yaml"
    python3 -c "
import yaml, sys
try:
    with open('$test_file') as f:
        data = yaml.safe_load(f)
        if isinstance(data, list): data = data[0]
        with open('$test_yaml', 'w') as out:
            out.write(data.get('yaml', ''))
        print(data.get('fail', False))
except:
    sys.exit(1)
" > /tmp/should_fail.txt 2>/dev/null || { ((SKIP++)); continue; }
    
    should_fail=$(cat /tmp/should_fail.txt)
    
    # Run parser (suppress output for speed)
    if "$PARSER" < "$test_yaml" >/dev/null 2>&1; then
        parser_ok=true
    else
        parser_ok=false
    fi
    
    # Evaluate
    if [[ "$should_fail" == "True" ]]; then
        if $parser_ok; then
            echo "FAIL: $test_id (should reject)" >> "$RESULTS_FILE"
            ((FAIL++))
        else
            ((PASS++))
        fi
    else
        if $parser_ok; then
            ((PASS++))
        else
            echo "FAIL: $test_id (unexpected error)" >> "$RESULTS_FILE"
            ((FAIL++))
        fi
    fi
done

echo ""
echo ""
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"
echo -e "${CYAN}Test Summary${NC}" | tee -a "$RESULTS_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"

RUN=$((PASS + FAIL))
PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASS / $RUN) * 100}")

echo "" | tee -a "$RESULTS_FILE"
echo "Total Tests:     $TOTAL_TESTS" | tee -a "$RESULTS_FILE"
echo "Tests Run:       $RUN" | tee -a "$RESULTS_FILE"
echo -e "${GREEN}Passed:          $PASS${NC}" | tee -a "$RESULTS_FILE"
echo -e "${RED}Failed:          $FAIL${NC}" | tee -a "$RESULTS_FILE"
echo "Skipped:         $SKIP" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"
echo -e "${BLUE}Pass Rate:       ${PASS_RATE}%${NC}" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# Save failing test IDs for easy reference
if [[ $FAIL -gt 0 ]]; then
    echo "Failing Test IDs:" | tee -a "$RESULTS_FILE"
    grep "^FAIL:" "$RESULTS_FILE" | cut -d' ' -f2 | cut -d'(' -f1 | sort | tee -a "$RESULTS_FILE"
fi

echo ""
echo "Detailed results: $RESULTS_FILE"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ ${FAIL} tests need attention${NC}"
    exit 1
fi
