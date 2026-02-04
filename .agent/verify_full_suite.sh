#!/bin/bash
# Comprehensive YAML Test Suite Verification
# Ensures all 351 tests from yaml-test-suite are exercised

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
echo -e "${CYAN}  YAML Test Suite Comprehensive Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
if [[ ! -d "$SUITE_DIR" ]]; then
    echo -e "${RED}ERROR: yaml-test-suite not found at $SUITE_DIR${NC}"
    exit 1
fi

if [[ ! -x "$PARSER" ]]; then
    echo -e "${RED}ERROR: Parser not found or not executable: $PARSER${NC}"
    echo "Please run 'make' first"
    exit 1
fi

# Create output directories
mkdir -p "$WORK_DIR" "$LOG_DIR"

# Count total tests
TOTAL_TESTS=$(ls "$SUITE_DIR"/*.yaml 2>/dev/null | wc -l)
echo -e "${BLUE}Total test cases found: $TOTAL_TESTS${NC}"
echo ""

# Initialize counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

# Clear results file
> "$RESULTS_FILE"

echo "Starting test execution..."
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"
echo "YAML Test Suite Results - $(date)" | tee -a "$RESULTS_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# Process each test
for test_file in "$SUITE_DIR"/*.yaml; do
    test_id=$(basename "$test_file" .yaml)
    test_yaml="$WORK_DIR/${test_id}_test.yaml"
    
    # Extract YAML content and expected result
    extract_result=$(python3 << EOF 2>&1
import yaml
import sys

try:
    with open('$test_file') as f:
        data = yaml.safe_load(f)
        if isinstance(data, list):
            data = data[0]
        
        # Extract test YAML content
        yaml_content = data.get('yaml', '')
        
        # Check if test should fail
        should_fail = data.get('fail', False)
        
        # Write test YAML to file
        with open('$test_yaml', 'w') as out:
            out.write(yaml_content)
        
        print(f"EXTRACTED|{should_fail}")
        sys.exit(0)
except Exception as e:
    print(f"EXTRACT_ERROR|{str(e)}", file=sys.stderr)
    sys.exit(1)
EOF
)
    
    # Check extraction status
    if [[ $? -ne 0 ]]; then
        echo -e "${YELLOW}SKIP${NC}: $test_id (extraction failed)"
        echo "SKIP: $test_id - Extraction failed" >> "$RESULTS_FILE"
        ((SKIP_COUNT++))
        continue
    fi
    
    # Parse extraction result
    should_fail=$(echo "$extract_result" | grep "EXTRACTED" | cut -d'|' -f2)
    
    # Run parser
    parser_output=$("$PARSER" < "$test_yaml" 2>&1) || true
    parser_exit=$?
    
    # Determine if parser failed
    parser_failed=false
    if [[ $parser_exit -ne 0 ]] || echo "$parser_output" | grep -qi "parse failed\|syntax error\|error\|ambiguous"; then
        parser_failed=true
    fi
    
    # Evaluate result
    if [[ "$should_fail" == "True" ]] || [[ "$should_fail" == "true" ]]; then
        # Test is expected to fail
        if $parser_failed; then
            echo -e "${GREEN}✓${NC} PASS: $test_id (correctly rejected)"
            echo "PASS: $test_id - Expected failure" >> "$RESULTS_FILE"
            ((PASS_COUNT++))
        else
            echo -e "${RED}✗${NC} FAIL: $test_id (should have failed)"
            echo "FAIL: $test_id - Should have been rejected" >> "$RESULTS_FILE"
            ((FAIL_COUNT++))
        fi
    else
        # Test should pass
        if $parser_failed; then
            echo -e "${RED}✗${NC} FAIL: $test_id (unexpected error)"
            echo "FAIL: $test_id - Unexpected parse error" >> "$RESULTS_FILE"
            # Log first few lines of error
            echo "$parser_output" | head -n 3 >> "$RESULTS_FILE"
            ((FAIL_COUNT++))
        else
            echo -e "${GREEN}✓${NC} PASS: $test_id"
            echo "PASS: $test_id" >> "$RESULTS_FILE"
            ((PASS_COUNT++))
        fi
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"
echo "Test Summary" | tee -a "$RESULTS_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

TOTAL_RUN=$((PASS_COUNT + FAIL_COUNT))
PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASS_COUNT / $TOTAL_RUN) * 100}")

echo "Total Tests:     $TOTAL_TESTS" | tee -a "$RESULTS_FILE"
echo "Tests Run:       $TOTAL_RUN" | tee -a "$RESULTS_FILE"
echo "Passed:          $PASS_COUNT" | tee -a "$RESULTS_FILE"
echo "Failed:          $FAIL_COUNT" | tee -a "$RESULTS_FILE"
echo "Skipped:         $SKIP_COUNT" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"
echo "Pass Rate:       ${PASS_RATE}%" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}" | tee -a "$RESULTS_FILE"
else
    echo -e "${YELLOW}⚠ ${FAIL_COUNT} tests failed${NC}" | tee -a "$RESULTS_FILE"
fi

echo ""
echo "Detailed results saved to: $RESULTS_FILE"

# Create a summary for easy viewing
SUMMARY_FILE="$LOG_DIR/test_summary.txt"
{
    echo "Quick Summary - $(date)"
    echo "Total: $TOTAL_TESTS | Run: $TOTAL_RUN | Pass: $PASS_COUNT | Fail: $FAIL_COUNT | Skip: $SKIP_COUNT"
    echo "Pass Rate: ${PASS_RATE}%"
    echo ""
    echo "Failed Tests:"
    grep "^FAIL:" "$RESULTS_FILE" | cut -d' ' -f2 | cut -d'-' -f1 | sort
} > "$SUMMARY_FILE"

echo ""
echo -e "${CYAN}Test verification complete!${NC}"
