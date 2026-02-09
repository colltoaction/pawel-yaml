#!/bin/bash
#
# YAML Test Suite Runner
# Runs the Pawel-YAML parser against the YAML test suite
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_DIR/build/bin"
SUITE_DIR="$PROJECT_DIR/build/lib/yaml-test-suite/src"
if [ ! -d "$SUITE_DIR" ]; then
    SUITE_DIR="$PROJECT_DIR/.agent/lib/yaml-test-suite/src"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f "$BIN_DIR/pawel-yaml" ]; then
    echo -e "${RED}Error: Parser not built. Run 'make' first.${NC}"
    exit 1
fi

if [ ! -d "$SUITE_DIR" ]; then
    echo -e "${RED}Error: YAML test suite not found at build/lib/yaml-test-suite/src or .agent/lib/yaml-test-suite/src.${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Running YAML Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Run the Python test suite
cd "$PROJECT_DIR"
python3 test_yaml_suite.py "$@"
