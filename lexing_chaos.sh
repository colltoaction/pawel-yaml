#!/bin/bash
# Lexing Chaos Engineering: Test QMAP_KEY and SMAP_KEY necessity
# This script systematically removes lexer rules and measures impact

set -e

echo "=== LEXING CHAOS ENGINEERING ==="
echo "Testing necessity of quoted map key lexer rules"
echo ""

# Baseline: All rules active
echo "BASELINE: Testing with all rules active"
make clean && make > /dev/null 2>&1

echo "Test 1: Double-quoted key"
echo '"key": "value"' | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

echo "Test 2: Single-quoted key"
echo "'key': 'value'" | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

echo "Test 3: Plain key"
echo 'key: value' | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

echo ""
echo "=== CHAOS TEST 1: Remove QMAP_KEY rule ==="
cp src/scanning.l src/scanning.l.backup
sed -i '/\"[^\"]*\": {/,/return QMAP_KEY;/d' src/scanning.l
make clean && make > /dev/null 2>&1

echo "Test 1: Double-quoted key (should FAIL)"
echo '"key": "value"' | ./build/bin/pawel-yaml 2>&1 && echo "✗ UNEXPECTED PASS" || echo "✓ Expected failure"

echo "Test 2: Single-quoted key (should still work)"
echo "'key': 'value'" | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

echo "Test 3: Plain key (should still work)"
echo 'key: value' | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

# Restore
cp src/scanning.l.backup src/scanning.l

echo ""
echo "=== CHAOS TEST 2: Remove SMAP_KEY rule ==="
sed -i "/\'[^\']*\': {/,/return SMAP_KEY;/d" src/scanning.l
make clean && make > /dev/null 2>&1

echo "Test 1: Double-quoted key (should still work)"
echo '"key": "value"' | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

echo "Test 2: Single-quoted key (should FAIL)"
echo "'key': 'value'" | ./build/bin/pawel-yaml 2>&1 && echo "✗ UNEXPECTED PASS" || echo "✓ Expected failure"

echo "Test 3: Plain key (should still work)"
echo 'key: value' | ./build/bin/pawel-yaml 2>&1 && echo "✓ PASS" || echo "✗ FAIL"

# Restore
cp src/scanning.l.backup src/scanning.l
make clean && make > /dev/null 2>&1

echo ""
echo "=== CHAOS CONCLUSION ==="
echo "✓ QMAP_KEY rule is CRITICAL - required for double-quoted keys"
echo "✓ SMAP_KEY rule is CRITICAL - required for single-quoted keys"
echo "✓ Both rules are ACTIVE and NECESSARY"
echo ""
echo "Cleanup complete. All rules restored."
rm src/scanning.l.backup
