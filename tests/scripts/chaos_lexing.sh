#!/bin/sh
# chaos_lexing.sh - lexer chaos helper
# Usage: chaos_lexing.sh <TOKEN_NAME> <TEST_ID>
# Disables the return for TOKEN_NAME in src/scanning.l, rebuilds, runs test, and restores.

set -e

LEX=src/stream.l
BACKUP=${LEX}.orig

if [ $# -lt 2 ]; then
    echo "Usage: $0 <TOKEN_NAME> <TEST_ID> [<TEST_ID> ...]"
    exit 1
fi

TOKEN="$1"
shift

echo "Backing up $LEX to $BACKUP"
cp "$LEX" "$BACKUP"

# comment out any return statement that returns the token using C-style comment
# (lex doesn't support '//' comments so we wrap the entire line)
sed -i "/return ${TOKEN};/s/^/\/\* /; s/$/ \*\//" "$LEX"

echo "Rebuilding project after disabling token $TOKEN..."
make -j4

for id in "$@"; do
    echo "Running test $id"
    ./tests/legacy/scripts/tdd_harness.sh test "$id" || echo "Test $id failed: $TOKEN is necessary"
done

# restore original lexer
mv "$BACKUP" "$LEX"
echo "Restored original lexer file"
