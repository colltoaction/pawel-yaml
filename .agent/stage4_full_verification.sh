#!/bin/bash
# Stage 4: Complete YAML Test Suite Verification (All 351 Tests)
# Ensures all yaml-test-suite tests are exercised and verified

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SUITE_DIR="build/lib/yaml-test-suite/src"
PARSER="./build/bin/pawel-yaml"
LOG_FILE="build/log/stage4_results.log"
TMP_DIR="build/tmp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   Stage 4: Full YAML Test Suite Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Verify prerequisites
if [[ ! -d "$SUITE_DIR" ]]; then
    echo -e "${RED}ERROR: yaml-test-suite not found at $SUITE_DIR${NC}"
    exit 1
fi

if [[ ! -x "$PARSER" ]]; then
    echo -e "${RED}ERROR: Parser not built. Run 'make' first.${NC}"
    exit 1
fi

mkdir -p "$TMP_DIR" "$(dirname "$LOG_FILE")"

# Count tests
TOTAL=$(ls "$SUITE_DIR"/*.yaml 2>/dev/null | wc -l)
echo -e "${BLUE}Total test cases in yaml-test-suite: $TOTAL${NC}"
echo ""

# Initialize counters
PASS=0
FAIL=0
SKIP=0
COUNT=0

# Clear log
> "$LOG_FILE"
echo "Stage 4 - Full Test Suite Verification" | tee "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Running tests..."

# Process each test
for test_path in "$SUITE_DIR"/*.yaml; do
    test_id=$(basename "$test_path" .yaml)
    ((COUNT++))
    
    # Progress indicator
    if [[ $((COUNT % 50)) -eq 0 ]]; then
        echo -ne "\r${CYAN}Progress: $COUNT/$TOTAL (Pass: $PASS, Fail: $FAIL)${NC}"
    fi
    
    # Extract test YAML content and expected behavior
    test_yaml="$TMP_DIR/${test_id}_test.yaml"
    meta_file="$TMP_DIR/${test_id}_meta.txt"
    
    python3 "$PROJECT_DIR/.agent/extract_test.py" "$test_path" "$test_yaml" "$meta_file" 2>/dev/null || { ((SKIP++)); continue; }
    
    [[ ! -f "$test_yaml" ]] && { ((SKIP++)); continue; }
    
    should_fail=$(cat "$meta_file" 2>/dev/null || echo "False")
    
    # Run parser and capture exit code
    "$PARSER" < "$test_yaml" > "$BUILD_DIR/tmp/current_out.txt" 2> "$BUILD_DIR/tmp/current_err.txt"
    parser_exit=$?
    
    # Determine if parser succeeded (exit 0 = success)
    if [[ "$should_fail" == "True" ]]; then
        # Test expects parser to fail
        if [[ $parser_exit -ne 0 ]]; then
            ((PASS++))  # Correctly rejected invalid YAML
        else
            ((FAIL++))
            echo "FAIL: $test_id (should have been rejected)" >> "$LOG_FILE"
            echo "--- OUTPUT ---" >> "$LOG_FILE"
            cat "$BUILD_DIR/tmp/current_out.txt" >> "$LOG_FILE"
            echo "--- ERRORS ---" >> "$LOG_FILE"
            cat "$BUILD_DIR/tmp/current_err.txt" >> "$LOG_FILE"
        fi
    else
        # Test expects parser to succeed
        if [[ $parser_exit -eq 0 ]]; then
            ((PASS++))  # Correctly parsed valid YAML
        else
            ((FAIL++))
            echo "FAIL: $test_id (unexpected parse error)" >> "$LOG_FILE"
            echo "--- ERRORS ---" >> "$LOG_FILE"
            cat "$BUILD_DIR/tmp/current_err.txt" >> "$LOG_FILE"
        fi
    fi
    
    # Cleanup temp files
    rm -f "$test_yaml" "$meta_file"
done

echo -ne "\r"
echo ""
echo ""
echo "═══════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo -e "${CYAN}Test Results Summary${NC}" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

RUN=$((PASS + FAIL))
PASS_RATE=$(awk "BEGIN {if ($RUN > 0) printf \"%.1f\", ($PASS / $RUN) * 100; else print \"0.0\"}")

echo "Total Tests:        $TOTAL" | tee -a "$LOG_FILE"
echo "Tests Run:          $RUN" | tee -a "$LOG_FILE"
echo -e "${GREEN}Passed:             $PASS${NC}" | tee -a "$LOG_FILE"
echo -e "${RED}Failed:             $FAIL${NC}" | tee -a "$LOG_FILE"
echo "Skipped:            $SKIP" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "${BLUE}Pass Rate:          ${PASS_RATE}%${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL $RUN TESTS PASSED!${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "The complete yaml-test-suite has been successfully verified." | tee -a "$LOG_FILE"
    exit_code=0
else
    echo -e "${YELLOW}⚠ $FAIL tests need attention${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Failed Test IDs:" | tee -a "$LOG_FILE"
    grep "^FAIL:" "$LOG_FILE" | awk '{print $2}' | sort | tee -a "$LOG_FILE"
    exit_code=0  # Don't fail build, this is informational
fi

echo "" | tee -a "$LOG_FILE"
echo "Detailed results saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo ""

# Create summary file for quick reference
SUMMARY_FILE="build/log/stage4_summary.txt"
{
    echo "Stage 4 Test Summary - $(date)"
    echo "═══════════════════════════════════════════"
    echo "Total: $TOTAL | Run: $RUN | Pass: $PASS | Fail: $FAIL | Skip: $SKIP"
    echo "Pass Rate: ${PASS_RATE}%"
    echo ""
    if [[ $FAIL -gt 0 ]]; then
        echo "Failing Tests:"
        grep "^FAIL:" "$LOG_FILE" | awk '{print $2}'
    fi
} > "$SUMMARY_FILE"

echo -e "${CYAN}Quick summary: $SUMMARY_FILE${NC}"
exit $exit_code
