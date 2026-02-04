#!/bin/bash
#
# TDD Red-Green-Refactor Harness
# Runs the unit and integration test suite for yaml_event.y
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
BIN_DIR="$BUILD_DIR/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_fail() {
    echo -e "${RED}✗ $1${NC}"
}

# Parse command
CMD="${1:-all}"

case "$CMD" in
    all)
        print_header "RED Phase: Unit Tests for yaml_event"
        cd "$PROJECT_DIR"
        if [ -f test_yaml_event ]; then
            ./test_yaml_event
            if [ $? -eq 0 ]; then
                print_pass "Unit tests passed"
            else
                print_fail "Unit tests failed"
                exit 1
            fi
        else
            print_fail "test_yaml_event not compiled"
            exit 1
        fi
        
        print_header "GREEN Phase: Integration Tests"
        python3 test_yaml_suite.py 2>&1 | tail -20
        ;;
        
    unit)
        print_header "Unit Tests Only"
        cd "$PROJECT_DIR"
        ./test_yaml_event
        ;;
        
    integration)
        print_header "Integration Tests (YAML Test Suite)"
        cd "$PROJECT_DIR"
        python3 test_yaml_suite.py
        ;;
        
    discover)
        print_header "Test Discovery"
        echo "Available tests:"
        echo "  • test_yaml_event (unit tests for event creation/printing)"
        echo "  • test_yaml_suite.py (integration with YAML test suite)"
        echo "  • test_single.py (single test debugging)"
        echo ""
        echo "Run with: make tdd"
        ;;
        
    clean)
        rm -f "$PROJECT_DIR/test_yaml_event"
        rm -f /tmp/test_*.txt
        print_pass "Test artifacts cleaned"
        ;;
        
    *)
        echo "Usage: $0 {all|unit|integration|discover|clean}"
        exit 1
        ;;
esac
