#!/bin/bash
# Unified Cycle 9 management script - consolidates 6 separate scripts
# Usage: ./cycle9.sh [plan|rebase|replan|fresh|start|status]

set -e
cd /home/widip/titi-org/pawel-yaml

CYCLE=9
COST_MODEL="build/tmp/running_totals_cycle9.tsv"
BISECT_LOG="build/tmp/heavy_path_divide_cycle9.txt"
LEAF_FILE="build/tmp/heavy_path_root_cycle9.leaf"
TIP_FILE="build/tmp/tip_ref_cycle9.txt"
BRANCH="refactor/future-aware-cycle9"

# --- Helper Functions ---
load_refs() {
    [ -f "$LEAF_FILE" ] && LEAF=$(cat "$LEAF_FILE") || LEAF=""
    [ -f "$TIP_FILE" ] && TIP_REF=$(cat "$TIP_FILE") || TIP_REF=""
}

generate_cost_model() {
    echo "Generating cost model..."
    mkdir -p build/tmp
    git rev-list --reverse --topo-order HEAD | awk '
    BEGIN { OFS="\t"; running=0; i=0; print "idx","sha","commit_total","running_total" }
    {
      sha=$0
      cmd="git show --numstat --format=\"\" " sha
      total=0
      while ((cmd | getline line) > 0) {
        n=split(line,a,"\t")
        if (n >= 2 && a[1] ~ /^[0-9]+$/ && a[2] ~ /^[0-9]+$/) total += a[1] + a[2]
      }
      close(cmd)
      i += 1
      running += total
      print i, sha, total, running
    }' > "$COST_MODEL"
    echo "✓ Cost model: $COST_MODEL ($(wc -l < "$COST_MODEL") commits)"
}

# --- Subcommands ---

cmd_plan() {
    echo "=== CYCLE $CYCLE: PLANNING PHASE ==="
    B=$(git rev-list --max-parents=0 HEAD | tail -n1)
    echo "Branch root: $B"
    
    generate_cost_model
    
    echo "Running heavy-path bisect with exclusions..."
    python3 build/tmp/heavy_path_bisect_v2.py \
      --cost-file "$COST_MODEL" \
      --exclude 65 66 79 112 115 120 147 53 \
      2>&1 | tee "$BISECT_LOG"
    
    LEAF=$(grep "^Selected commit" "$BISECT_LOG" | awk '{print $3}')
    LEAF_SHA=$(awk -v idx="$LEAF" '$1 == idx {print $2}' "$COST_MODEL")
    TIP_REF=$(git rev-parse --verify HEAD)
    
    echo "$LEAF_SHA" > "$LEAF_FILE"
    echo "$TIP_REF" > "$TIP_FILE"
    
    echo "✓ Planning complete: Commit #$LEAF ($LEAF_SHA)"
}

cmd_replan() {
    echo "=== Regenerating cost model from master ==="
    git checkout master
    B=$(git rev-list --max-parents=0 HEAD | tail -n1)
    echo "Branch root: $B"
    
    generate_cost_model
    
    echo "Looking for target commit 49c712cc..."
    if grep -q "49c712cc" "$COST_MODEL"; then
        echo "✓ Found in cost model"
        grep "49c712cc" "$COST_MODEL"
    else
        echo "✗ Not found - showing recent commits:"
        git log --oneline --all | head -20
    fi
}

cmd_rebase() {
    load_refs
    [ -z "$LEAF" ] && { echo "Error: No leaf file. Run 'plan' first."; exit 1; }
    
    echo "=== CYCLE $CYCLE: REBASE EXECUTION ==="
    echo "Target: $LEAF"
    echo "TIP_REF: $TIP_REF"
    
    git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
    
    # Create editor script
    EDITOR_SCRIPT="build/tmp/rebase_editor_cycle9.sh"
    cat > "$EDITOR_SCRIPT" << 'EOF'
#!/bin/bash
TODO_FILE="$1"
awk '/^[a-z]/ {
  cmd=$1; sha=$2; rest=$0
  sub(/^[a-z]+ [^ ]+ /, "", rest)
  if (sha ~ /^49c712cc/) { print "edit " sha " " rest }
  else { print "pick " sha " " rest }
}
!/^[a-z]/ { print }' "$TODO_FILE" > "$TODO_FILE.new"
mv "$TODO_FILE.new" "$TODO_FILE"
EOF
    chmod +x "$EDITOR_SCRIPT"
    
    echo "Starting interactive rebase..."
    GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i --root
    echo "✓ Rebase paused at target commit"
}

cmd_fresh() {
    load_refs
    echo "=== Resetting to TIP_REF ($TIP_REF) ==="
    git reset --hard "$TIP_REF" 2>/dev/null || echo "Using current HEAD"
    echo "✓ Branch reset"
}

cmd_start() {
    load_refs
    [ -z "$LEAF" ] && { echo "Error: Run 'plan' first."; exit 1; }
    
    EDITOR_SCRIPT="build/tmp/rebase_editor_cycle9.sh"
    cat > "$EDITOR_SCRIPT" << 'EOF'
#!/bin/bash
TODO_FILE="$1"
awk '/^[a-z]/ { print ($2 ~ /^'$LEAF'/ ? "edit" : "pick") " " $0 }
!/^[a-z]/ { print }' "$TODO_FILE" > "$TODO_FILE.new"
mv "$TODO_FILE.new" "$TODO_FILE"
EOF
    chmod +x "$EDITOR_SCRIPT"
    GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i --root
}

cmd_status() {
    load_refs
    echo "=== CYCLE $CYCLE STATUS ==="
    echo "Branch: $BRANCH"
    echo "Leaf: ${LEAF:-Not set}"
    echo "TIP: ${TIP_REF:-Not set}"
    [ -f "$COST_MODEL" ] && echo "Cost model: ✓ ($(wc -l < "$COST_MODEL") commits)"
    [ -f "$BISECT_LOG" ] && echo "Bisect log: ✓"
    git branch --list "$BRANCH" && echo "Branch exists: ✓" || echo "Branch: Create with 'rebase'"
}

# --- Main ---
case "${1:-status}" in
    plan) cmd_plan ;;
    replan) cmd_replan ;;
    rebase) cmd_rebase ;;
    fresh) cmd_fresh ;;
    start) cmd_start ;;
    status) cmd_status ;;
    *) echo "Usage: $0 [plan|rebase|replan|fresh|start|status]"; exit 1 ;;
esac
