#!/bin/sh
# chaos.sh - grammar chaos engineering helper
# Usage: chaos.sh <sed-delete-pattern>
# Example: chaos.sh '/implicit_document explicit_documents/d'

set -e

GRAMMAR=src/stream.y
BACKUP=${GRAMMAR}.orig
PATCH=${GRAMMAR}.chaos.patch

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sed-delete-pattern>"
    exit 1
fi
pattern="$1"

cp "$GRAMMAR" "$BACKUP"
# remove the matching lines in-place
sed -i "$pattern" "$GRAMMAR"
# record diff so we can reverse later
diff -u "$BACKUP" "$GRAMMAR" > "$PATCH"

# try building the project
if ! make -j4; then
    echo "[BUILD] -> essential (grammar invalid without component)"
    patch -R "$GRAMMAR" < "$PATCH" || true
    rm -f "$BACKUP" "$PATCH"
    exit 0
fi

# pick a handful of tests to exercise parser
failed=0
for id in $(./tests/legacy/scripts/tdd_harness.sh discover | shuf | head -10); do
    if ! ./tests/legacy/scripts/tdd_harness.sh test "$id"; then
        failed=1
        break
    fi
done

if [ "$failed" -eq 1 ]; then
    echo "[TEST] -> active (removal changes behavior)"
else
    echo "[TEST] -> dead code? (no failures)"
fi

# restore original grammar
patch -R "$GRAMMAR" < "$PATCH" || true
rm -f "$BACKUP" "$PATCH"
