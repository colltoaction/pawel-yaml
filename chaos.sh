#!/bin/bash
# Chaos Engineering: Remove grammar alternatives and measure test coverage

set -e
cd "$(dirname "$0")"

PARSER_FILE="src/parser.y"
LOG_FILE="build/log/chaos_dead_code.md"
BACKUP="src/parser.y.backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

mkdir -p build/log

cat > "$LOG_FILE" << 'EOF'
# Chaos Engineering: Dead Code Analysis

Remove grammar alternatives one-by-one and test if YAML parsing still works.
If tests pass after removal, the alternative is dead code.

## Results

EOF

test_suite() {
    # Quick 5-test sample
    local pass=0 fail=0
    for test in $(./tdd_harness.sh discover 2>/dev/null | shuf | head -5); do
        local result=$(timeout 3 ./tdd_harness.sh test "$test" 2>&1 | grep -oE "PASS|FAIL" | head -1)
        case "$result" in
            PASS) ((pass++)) ;;
            FAIL) ((fail++)) ;;
        esac
    done
    echo "$pass:$fail"
}

backup() {
    cp "$PARSER_FILE" "$BACKUP"
}

restore() {
    if [ -f "$BACKUP" ]; then
        cp "$BACKUP" "$PARSER_FILE"
    fi
}

test_removal() {
    local name="$1"
    local pattern="$2"
    
    echo -e "${MAGENTA}Testing: $name${NC}"
    backup
    
    # Remove matching lines
    sed -i "$pattern" "$PARSER_FILE"
    
    # Try to rebuild
    if ! make -j4 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Build failed (ESSENTIAL)${NC}"
        echo "- ⚠ ESSENTIAL: $name" >> "$LOG_FILE"
        restore
        make -j4 >/dev/null 2>&1
        return
    fi
    
    # Test
    local result=$(test_suite)
    local pass=$(echo "$result" | cut -d: -f1)
    local fail=$(echo "$result" | cut -d: -f2)
    
    restore
    make -j4 >/dev/null 2>&1
    
    if [ "$pass" -gt 0 ] && [ "$fail" -eq 0 ]; then
        echo -e "${RED}✗ DEAD CODE${NC} (5/5 pass)"
        echo "- ✗ DEAD CODE: $name (all tests pass without it)" >> "$LOG_FILE"
    else
        echo -e "${GREEN}✓ ACTIVE${NC} (p=$pass f=$fail)"
        echo "- ✓ ACTIVE: $name" >> "$LOG_FILE"
    fi
}

# Get baseline
echo -e "${BLUE}Building baseline...${NC}"
make -j4 >/dev/null 2>&1
baseline=$(test_suite)
base_pass=$(echo "$baseline" | cut -d: -f1)
base_fail=$(echo "$baseline" | cut -d: -f2)
echo "Baseline: ${GREEN}$base_pass PASS${NC}, ${RED}$base_fail FAIL${NC}"
echo "" >> "$LOG_FILE"
echo "Baseline: **$base_pass** PASS, **$base_fail** FAIL" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Test specific alternatives
echo ""
test_removal "ALIAS in simple_node" "/| ALIAS {/,/^\s*}$/d"
test_removal "ANCHOR node" "/| ANCHOR node {/,/^\s*}$/d"
test_removal "simple_node COLON" "/simple_node COLON {/,/^\s*}$/d"
test_removal "BLOCK_KEY alternatives" "/| BLOCK_KEY/,/^\s*}$/d"
test_removal "COLON node" "/| COLON node {/,/^\s*}$/d"
test_removal "flow_sequence COMMA" "/| flow_sequence_items COMMA/,/^\s*}$/d"

echo ""
echo "Report: $LOG_FILE"
cat "$LOG_FILE"
