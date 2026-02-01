#!/bin/bash
# TDD Harness - Automated testing with yaml-test-suite
set -e

SUITE_DIR="build/lib/yaml-test-suite"
PARSER="./build/bin/pawel-yaml"
LOG_DIR="build/log"
WORK_DIR="build/tmp"

mkdir -p "$WORK_DIR" "$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

discover_tests() {
    if [[ ! -d "$SUITE_DIR" ]]; then
        echo -e "${RED}ERROR: yaml-test-suite not found${NC}"
        return 1
    fi
    if [[ ! -f TEST_FAILURES.yaml ]]; then
        echo -e "${RED}ERROR: TEST_FAILURES.yaml not found${NC}"
        return 1
    fi
    grep "^  - " TEST_FAILURES.yaml | sed 's/^  - //'
}

get_test_input() {
    local test_id="$1"
    python3 extract_test_yaml.py "$test_id" "$SUITE_DIR"
}

run_test() {
    local test_id="$1"
    local test_file="$WORK_DIR/${test_id}.yaml"
    
    if ! get_test_input "$test_id" > "$test_file" 2>/dev/null; then
        echo "SKIP: Test $test_id - input not found"
        return 2
    fi
    
    local should_fail=$(python3 extract_test_info.py "$test_id" "$SUITE_DIR" fail 2>/dev/null || echo "false")
    
    local output=$("$PARSER" < "$test_file" 2>&1) || true
    
    if echo "$output" | grep -qi "parse failed\|syntax error\|error"; then
        if [ "$should_fail" = "true" ]; then
            echo -e "${GREEN}PASS${NC}: $test_id"
            return 0
        else
            echo -e "${RED}FAIL${NC}: $test_id"
            return 1
        fi
    else
        if [ "$should_fail" = "true" ]; then
            echo -e "${RED}FAIL${NC}: $test_id"
            return 1
        else
            echo -e "${GREEN}PASS${NC}: $test_id"
            return 0
        fi
    fi
}

case "${1:-help}" in
    discover) discover_tests ;;
    test) run_test "$2" ;;
    *) echo "Usage: $0 {discover|test TEST_ID}" ;;
esac
