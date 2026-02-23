#!/bin/sh
# lexing_chaos.sh - specifically test quoted map key rules (QMAP_KEY/SMAP_KEY)
# Usage: lexing_chaos.sh <TEST_ID> [<TEST_ID> ...]
# Removes rules from scanning.l and runs provided tests.

set -e

LEX=src/stream.l
BACKUP=${LEX}.orig

if [ $# -lt 1 ]; then
    echo "Usage: $0 <TEST_ID> [<TEST_ID> ...]"
    exit 1
fi

cp "$LEX" "$BACKUP"

# delete the lines containing the QMAP_KEY and SMAP_KEY return rules
sed -i '/QMAP_KEY/d; /SMAP_KEY/d' "$LEX"

echo "Rebuilding with quoted key rules removed..."
make -j4

for id in "$@"; do
    echo "Running test $id"
    ./tests/legacy/scripts/tdd_harness.sh test "$id" || echo "Test $id failed (expected)"
done

mv "$BACKUP" "$LEX"
echo "Restored original lexer file"
